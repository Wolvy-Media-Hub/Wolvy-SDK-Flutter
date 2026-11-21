package net.wolvy.player.flutter

import android.app.Activity
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class WolvyViewFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    var activity: Activity? = null

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        // The activity, when known: the view sets FLAG_SECURE on its window.
        return WolvyFlutterView(activity ?: context, messenger, viewId, params?.get("showControls") as? Boolean ?: true)
    }
}
