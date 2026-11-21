package net.wolvy.spike.wolvy_spike

import android.content.Context
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import net.wolvy.spike.player.SpikePlayerView

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Screenshots and screen recordings of this window are black (what the SDK will do).
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory("wolvy-spike-view", SpikeViewFactory())
    }
}

/** The same native SpikePlayerView as the native and React Native spikes, as a platform view. */
class SpikeViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val m = args as? Map<*, *>
        val view = SpikePlayerView(context, (m?.get("host") as? String) ?: "flutter")
        (m?.get("embedUrl") as? String)?.takeIf { it.isNotBlank() }?.let { view.start(it) }
        return object : PlatformView {
            override fun getView(): View = view
            override fun dispose() = view.release()
        }
    }
}
