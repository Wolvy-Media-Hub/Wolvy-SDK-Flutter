import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';

/// Shows the player that [controller] owns: the native Wolvy player with the viewer watermark,
/// captions and (unless [showControls] is false) its controls.
///
/// The player belongs to the controller, not to this widget: when Flutter rebuilds the widget in
/// another place (fullscreen, any change of layout), playback goes on in the new one.
///
/// Android: embedded with hybrid composition, the only way a hardware-protected (Widevine L1)
/// picture can be shown in Flutter: the texture layer draws native views into a texture, and a
/// secure surface cannot be drawn there (tested on phones, SDK plan phase 3 step 1). While it is
/// on screen the app's whole window is protected from capture (FLAG_SECURE).
///
/// iOS: a UIKit view (FairPlay). iOS keeps the picture out of screenshots, recordings and
/// mirroring by itself. The view takes every touch in its area (its own controls).
class WolvyPlayerView extends StatefulWidget {
  const WolvyPlayerView({super.key, required this.controller, this.showControls = true});

  final WolvyPlayerController controller;

  /// False for a bare player: draw your own controls with the controller.
  final bool showControls;

  static const String viewType = 'net.wolvy.player/view';

  @override
  State<WolvyPlayerView> createState() => _WolvyPlayerViewState();
}

class _WolvyPlayerViewState extends State<WolvyPlayerView> {
  late Future<int> _playerId = widget.controller.playerId;

  @override
  void didUpdateWidget(WolvyPlayerView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) _playerId = widget.controller.playerId;
  }

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return const Center(child: Text('The Wolvy player runs on Android and iOS.'));
    }
    return FutureBuilder<int>(
      future: _playerId,
      builder: (context, snapshot) {
        final id = snapshot.data;
        if (id == null) return const ColoredBox(color: Color(0xFF000000));
        if (platform == TargetPlatform.iOS) {
          return UiKitView(
            key: ValueKey<int>(id),
            viewType: WolvyPlayerView.viewType,
            layoutDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
            creationParams: <String, Object?>{'playerId': id, 'showControls': widget.showControls},
            creationParamsCodec: const StandardMessageCodec(),
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          );
        }
        return PlatformViewLink(
          key: ValueKey<int>(id),
          viewType: WolvyPlayerView.viewType,
          surfaceFactory: (context, controller) => AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          ),
          onCreatePlatformView: (params) {
            // initExpensiveAndroidView = hybrid composition. Never initSurfaceAndroidView or
            // AndroidView: those use a texture, and a protected picture would be black.
            return PlatformViewsService.initExpensiveAndroidView(
              id: params.id,
              viewType: WolvyPlayerView.viewType,
              layoutDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
              creationParams: <String, Object?>{'playerId': id, 'showControls': widget.showControls},
              creationParamsCodec: const StandardMessageCodec(),
              onFocus: () => params.onFocusChanged(true),
            )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..create();
          },
        );
      },
    );
  }
}
