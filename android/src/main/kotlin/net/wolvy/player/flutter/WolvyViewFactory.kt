package net.wolvy.player.flutter

import android.app.Activity
import android.content.Context
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import net.wolvy.player.WolvyPlayer
import net.wolvy.player.WolvyPlayerView

internal class WolvyViewFactory(private val lookup: (Int) -> WolvyPlayer?) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    var activity: Activity? = null

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        // The activity, when known: the view sets FLAG_SECURE on its window.
        val view = WolvyPlayerView(activity ?: context).apply {
            showControls = params?.get("showControls") as? Boolean ?: true
            player = (params?.get("playerId") as? Number)?.let { lookup(it.toInt()) }
        }
        return object : PlatformView {
            override fun getView(): View = view
            // Only the view goes: the player stays with its controller, maybe in a new view already.
            override fun dispose() { view.player = null }
        }
    }
}
