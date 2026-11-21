package net.wolvy.player.flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Registers the `net.wolvy.player/view` platform view: one native Wolvy player per Flutter
 * WolvyPlayerView. Keeps the activity so the view can protect its window (FLAG_SECURE).
 */
class WolvyPlayerPlugin : FlutterPlugin, ActivityAware {
    private var factory: WolvyViewFactory? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val f = WolvyViewFactory(binding.binaryMessenger)
        factory = f
        binding.platformViewRegistry.registerViewFactory(VIEW_TYPE, f)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        factory = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { factory?.activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { factory?.activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { factory?.activity = binding.activity }
    override fun onDetachedFromActivity() { factory?.activity = null }

    companion object {
        const val VIEW_TYPE = "net.wolvy.player/view"
        const val VERSION = "0.1.0"
    }
}
