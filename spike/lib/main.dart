// Phase 3, step 1 of the Wolvy SDK plan: does hardware-protected (Widevine L1) video show
// inside a Flutter platform view? Two ways to embed the same native view:
//   - Hybrid composition (PlatformViewsService.initExpensiveAndroidView): the real Android view
//     sits in the window. Expected to work.
//   - Texture layer (the default AndroidView): the view is drawn into a texture that Flutter
//     composites. A secure surface cannot be read into a texture, so expected black.
// Paste the embed_url from POST /v1/videos/{id}/playback-tokens, pick the mode, press Play.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wolvy spike (Flutter)',
        theme: ThemeData.dark(),
        home: const SpikePage(),
      );
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});
  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  final _input = TextEditingController();
  bool _hybrid = true;
  String? _url;
  int _generation = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _input,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Paste the embed_url from the API (https://embed.wolvy.stream/…?vt=…)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Row(children: [
              Switch(value: _hybrid, onChanged: (v) => setState(() => _hybrid = v)),
              Expanded(child: Text(_hybrid ? 'Hybrid composition' : 'Texture layer (default AndroidView)')),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _url = _input.text.trim();
                    _generation++;
                  }),
                  child: const Text('Play'),
                ),
              ),
            ]),
            Expanded(
              child: _url == null || _url!.isEmpty
                  ? const SizedBox.shrink()
                  : SpikeView(key: ValueKey('$_generation-$_hybrid'), url: _url!, hybrid: _hybrid),
            ),
          ]),
        ),
      );
}

class SpikeView extends StatelessWidget {
  const SpikeView({super.key, required this.url, required this.hybrid});
  final String url;
  final bool hybrid;
  static const viewType = 'wolvy-spike-view';

  @override
  Widget build(BuildContext context) {
    final params = <String, dynamic>{
      'embedUrl': url,
      'host': hybrid ? 'flutter (hybrid composition)' : 'flutter (texture layer, default AndroidView)',
    };
    if (!hybrid) {
      return AndroidView(
        viewType: viewType,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (p) => PlatformViewsService.initExpensiveAndroidView(
        id: p.id,
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onFocus: () => p.onFocusChanged(true),
      )
        ..addOnPlatformViewCreatedListener(p.onPlatformViewCreated)
        ..create(),
    );
  }
}
