package net.wolvy.player.flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import net.wolvy.player.AppRenderVideoSource
import net.wolvy.player.BuildConfig as CoreBuildConfig
import net.wolvy.player.Progress
import net.wolvy.player.Qualities
import net.wolvy.player.State
import net.wolvy.player.ViewerTokenProvider
import net.wolvy.player.WolvyError
import net.wolvy.player.WolvyPlayer
import net.wolvy.player.WolvyPlayerListener
import net.wolvy.player.WolvyPlayerView
import net.wolvy.player.WolvyVideo
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * One Flutter WolvyPlayerView: a native WolvyPlayer and WolvyPlayerView from the Wolvy Android
 * SDK, driven over the `net.wolvy.player/view_<id>` channel. No playback logic here: commands go
 * to the core, events and token requests come back.
 */
internal class WolvyFlutterView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    showControls: Boolean,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "net.wolvy.player/view_$viewId")
    private val player = WolvyPlayer(
        context,
        AppRenderVideoSource(
            context.packageName,
            "wolvy-flutter/${WolvyPlayerPlugin.VERSION}+android.${CoreBuildConfig.SDK_VERSION}",
        ),
    )
    private val view = WolvyPlayerView(context).also {
        it.player = player
        it.showControls = showControls
    }
    @Volatile private var disposed = false

    /** Asks Dart for a fresh viewer token; runs on the player's background thread. */
    private val tokenProvider = ViewerTokenProvider { video ->
        val answer = AtomicReference<Result<String?>>()
        val done = CountDownLatch(1)
        main.post {
            if (disposed) { answer.set(Result.failure(IOException("The view was removed."))); done.countDown(); return@post }
            channel.invokeMethod("fetchViewerToken", mapOf("videoId" to video.videoId), object : MethodChannel.Result {
                override fun success(result: Any?) { answer.set(Result.success(result as? String)); done.countDown() }
                override fun error(code: String, message: String?, details: Any?) {
                    answer.set(Result.failure(IOException("The app's token provider failed: ${message ?: code}"))); done.countDown()
                }
                override fun notImplemented() { answer.set(Result.failure(IOException("No token provider."))); done.countDown() }
            })
        }
        if (!done.await(30, TimeUnit.SECONDS)) throw IOException("The app's token provider did not answer in 30 s.")
        answer.get().getOrThrow()
    }

    private val events = object : WolvyPlayerListener {
        override fun onReady(state: State) = send("ready", state.toMap())
        override fun onPlay(currentTime: Double) = send("play", mapOf("currentTime" to currentTime))
        override fun onPause(currentTime: Double) = send("pause", mapOf("currentTime" to currentTime))
        override fun onEnded() = send("ended", emptyMap())
        override fun onSeeked(currentTime: Double) = send("seeked", mapOf("currentTime" to currentTime))
        override fun onTimeUpdate(currentTime: Double, duration: Double) =
            send("timeupdate", mapOf("currentTime" to currentTime, "duration" to duration))
        override fun onProgress(progress: Progress) = send("progress", progress.toMap())
        override fun onVolumeChange(volume: Float, muted: Boolean) =
            send("volumechange", mapOf("volume" to volume.toDouble(), "muted" to muted))
        override fun onRateChange(playbackRate: Float) = send("ratechange", mapOf("playbackRate" to playbackRate.toDouble()))
        override fun onQualityChange(qualities: Qualities) = send("qualitychange", qualities.toMap())
        override fun onCaptionsChange(active: String?) = send("captionschange", mapOf("active" to active))
        override fun onFullscreenChange(fullscreen: Boolean) = send("fullscreenchange", mapOf("fullscreen" to fullscreen))
        override fun onError(error: WolvyError) = send("error", error.toMap())
        override fun onCaptionCue(text: String?) = send("captioncue", mapOf("text" to text))
    }

    init {
        channel.setMethodCallHandler(this)
        player.addListener(events)
    }

    override fun getView(): View = view

    override fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        view.player = null
        player.release()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val value: Any? = when (call.method) {
                "load" -> {
                    val video = WolvyVideo(
                        call.argument<String>("videoId") ?: "",
                        (call.argument<Number>("accountId") ?: 0).toLong(),
                        call.argument<String>("viewerToken") ?: "",
                        if (call.argument<Boolean>("hasTokenProvider") == true) tokenProvider else null,
                    )
                    player.load(video, call.argument<Boolean>("autoplay") ?: true)
                    null
                }
                "play" -> { player.play(); null }
                "pause" -> { player.pause(); null }
                "seek" -> player.seek((call.argument<Number>("seconds") ?: 0).toDouble())
                "mute" -> { player.mute(); null }
                "unmute" -> { player.unmute(); null }
                "setVolume" -> { player.setVolume((call.argument<Number>("volume") ?: -1).toFloat()); null }
                "setPlaybackRate" -> { player.setPlaybackRate((call.argument<Number>("rate") ?: -1).toFloat()); null }
                "setQuality" -> { player.setQuality(call.argument<Number>("height")?.toInt()); null }
                "setCaptions" -> { player.setCaptions(call.argument<String>("language")); null }
                "retry" -> { player.retry(); null }
                "getState" -> player.getState().toMap()
                "getQualities" -> player.getQualities().toMap()
                "getCaptions" -> player.getCaptions().let { c ->
                    mapOf("available" to c.available.map { mapOf("language" to it.language, "label" to it.label) }, "active" to c.active)
                }
                "getProgress" -> player.getProgress().toMap()
                "getVideoInfo" -> player.videoInfo?.let { i ->
                    mapOf(
                        "chapters" to i.chapters.map { mapOf("start" to it.start, "end" to it.end, "title" to it.title) },
                        "moments" to i.moments.map { mapOf("timestamp" to it.timestamp, "label" to it.label) },
                        "viewerId" to i.viewerId,
                        "playerColor" to i.playerColor,
                        "poster" to i.poster,
                    )
                }
                else -> { result.notImplemented(); return }
            }
            result.success(value)
        } catch (e: WolvyError) {
            result.error(e.code.value, e.message, mapOf("reason" to e.reason))
        } catch (e: IllegalArgumentException) {
            result.error(WolvyError.Code.INVALID_ARGUMENT.value, e.message, null)
        }
    }

    private fun send(name: String, data: Map<String, Any?>) {
        if (!disposed) channel.invokeMethod("event", mapOf("name" to name, "data" to data))
    }

    private fun State.toMap() = mapOf(
        "currentTime" to currentTime, "duration" to duration, "paused" to paused,
        "muted" to muted, "volume" to volume.toDouble(), "playbackRate" to playbackRate.toDouble(),
    )
    private fun Qualities.toMap() = mapOf("available" to available, "selected" to selected, "playing" to playing)
    private fun Progress.toMap() = mapOf("percent" to percent, "seconds" to seconds, "duration" to duration)
    private fun WolvyError.toMap() = mapOf("code" to code.value, "message" to (message ?: ""), "reason" to reason)
}
