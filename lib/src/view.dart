import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';

/// Shows the player that [controller] controls: the native Wolvy player with the viewer
/// watermark, captions and (unless [showControls] is false) its controls.
///
/// Embedded with hybrid composition, the only way a hardware-protected (Widevine L1) picture
/// can be shown in Flutter: the texture layer draws native views into a texture, and a secure
/// surface cannot be drawn there (tested on phones, SDK plan phase 3 step 1).
///
/// While it is on screen the app's whole window is protected from capture (FLAG_SECURE).
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
  int? _viewId;

  @override
  void dispose() {
    final id = _viewId;
    if (id != null) widget.controller.detachView(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Center(child: Text('The Wolvy player runs on Android in this version.'));
    }
    return PlatformViewLink(
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
          creationParams: <String, Object?>{'showControls': widget.showControls},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener((id) {
            params.onPlatformViewCreated(id);
            _viewId = id;
            widget.controller.attachView(id);
          })
          ..create();
      },
    );
  }
}
