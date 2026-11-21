package net.wolvy.player.flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The players live here, one per Dart WolvyPlayerController, created and disposed over the
 * `net.wolvy.player` channel. Views (`net.wolvy.player/view`) only show a player: when Flutter
 * replaces a view (fullscreen, any change of layout), the player goes on in the new one.
 */
class WolvyPlayerPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var messenger: BinaryMessenger? = null
    private var appContext: Context? = null
    private val players = HashMap<Int, WolvyFlutterPlayer>()
    private var nextId = 1
    private var factory: WolvyViewFactory? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        messenger = binding.binaryMessenger
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { it.setMethodCallHandler(this) }
        val f = WolvyViewFactory { id -> players[id]?.player }
        factory = f
        binding.platformViewRegistry.registerViewFactory(VIEW_TYPE, f)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        players.values.forEach { it.release() }
        players.clear()
        factory = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                val id = nextId++
                players[id] = WolvyFlutterPlayer(appContext ?: return result.error("failed", "Not attached.", null), messenger!!, id)
                result.success(id)
            }
            "dispose" -> {
                call.argument<Int>("playerId")?.let { players.remove(it)?.release() }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { factory?.activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { factory?.activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { factory?.activity = binding.activity }
    override fun onDetachedFromActivity() { factory?.activity = null }

    companion object {
        const val CHANNEL = "net.wolvy.player"
        const val VIEW_TYPE = "net.wolvy.player/view"
        const val VERSION = "0.1.0"
    }
}
