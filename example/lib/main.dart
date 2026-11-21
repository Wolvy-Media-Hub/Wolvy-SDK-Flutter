// The Wolvy Flutter SDK's example: paste the embed_url that your server gets from
// POST /v1/videos/{id}/playback-tokens and press Play. In a real app the three values come from
// your own server, and the viewer token is never made in the app.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolvy_player/wolvy_player.dart';

void main() => runApp(const MaterialApp(title: 'Wolvy Flutter example', home: ExamplePage()));

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});
  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final _player = WolvyPlayerController();
  final _input = TextEditingController();
  final _log = <String>[];
  StreamSubscription<WolvyEvent>? _sub;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    _sub = _player.events.listen((e) {
      final line = switch (e) {
        WolvyReadyEvent(:final state) => 'ready, ${state.duration.toStringAsFixed(0)} s',
        WolvyProgressEvent(:final progress) => 'progress ${progress.percent} % (${progress.seconds} s)',
        WolvyQualityChangeEvent(:final qualities) =>
          'quality ${qualities.available}, picked ${qualities.selected ?? 'auto'}, playing ${qualities.playing}',
        WolvyErrorEvent(:final error) => 'error ${error.code.value} (${error.reason}): ${error.message}',
        WolvyFullscreenChangeEvent(:final fullscreen) => _setFullscreen(fullscreen),
        WolvyTimeUpdateEvent() || WolvyCaptionCueEvent() => null,
        _ => e.name,
      };
      if (line != null) _add(line);
    });
  }

  String _setFullscreen(bool on) {
    setState(() => _fullscreen = on);
    SystemChrome.setEnabledSystemUIMode(on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(
        on ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : DeviceOrientation.values);
    return 'fullscreen $on';
  }

  void _add(String line) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    setState(() => _log.insert(0, '$t  $line'));
  }

  Future<void> _play() async {
    try {
      // A real app passes tokenProvider: (video) => myServer.freshViewerToken(video.videoId)
      await _player.load(WolvyVideo.fromEmbedUrl(_input.text));
      _add('load ${_input.text.split('?').first}');
    } on FormatException catch (e) {
      _add('not an embed URL with a viewer token: ${e.message}');
    } on WolvyError catch (e) {
      _add('error ${e.code.value} (${e.reason}): ${e.message}');
    }
  }

  Future<void> _try(Future<Object?> Function() call, String label) async {
    try {
      final r = await call();
      _add(r == null ? label : '$label → $r');
    } on WolvyError catch (e) {
      _add('$label: ${e.code.value} ${e.message}');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerView = WolvyPlayerView(controller: _player);
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) _setFullscreen(false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(children: [
            if (!_fullscreen) ...[
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _input,
                  autocorrect: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'embed_url from your server (https://embed.wolvy.stream/…?vt=…)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Wrap(spacing: 8, children: [
                ElevatedButton(onPressed: _play, child: const Text('Play')),
                OutlinedButton(onPressed: () => _try(_player.pause, 'pause()'), child: const Text('Pause')),
                OutlinedButton(
                    onPressed: () => _try(() async => (await _player.getState()).currentTime, 'currentTime'),
                    child: const Text('Time')),
                OutlinedButton(
                    onPressed: () => _try(() async {
                          final s = await _player.getState();
                          return _player.seek(s.currentTime + 10);
                        }, 'seek +10'),
                    child: const Text('+10 s')),
              ]),
            ],
            Expanded(flex: _fullscreen ? 1 : 3, child: playerView),
            if (!_fullscreen)
              Expanded(
                flex: 2,
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [for (final l in _log) SelectableText(l, style: const TextStyle(color: Colors.white70, fontSize: 11))],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
