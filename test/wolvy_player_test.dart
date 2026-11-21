import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wolvy_player/wolvy_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const plugin = MethodChannel('net.wolvy.player');
  const channel = MethodChannel('net.wolvy.player/player_7');
  const codec = StandardMethodCodec();

  group('WolvyVideo', () {
    test('reads the embed_url that the API returns', () {
      final v = WolvyVideo.fromEmbedUrl('https://embed.wolvy.stream/a1b2c3d4e5f60718293a/NDI=?vt=eyJ2aWQiOiJ1In0.sig%2B');
      expect(v.videoId, 'a1b2c3d4e5f60718293a');
      expect(v.accountId, 42);
      expect(v.viewerToken, 'eyJ2aWQiOiJ1In0.sig+');
      expect(WolvyVideo.fromEmbedUrl('https://embed.wolvy.stream/v1/NDI?vt=x').accountId, 42); // unpadded
    });

    test('refuses URLs without the three values', () {
      expect(() => WolvyVideo.fromEmbedUrl('https://embed.wolvy.stream/v1/NDI='), throwsFormatException);
      expect(() => WolvyVideo.fromEmbedUrl('https://embed.wolvy.stream/v1?vt=x'), throwsFormatException);
      expect(() => WolvyVideo.fromEmbedUrl('https://embed.wolvy.stream/v1/bm90IGEgbnVtYmVy?vt=x'), throwsFormatException);
      expect(() => WolvyVideo(videoId: 'bad id!', accountId: 1, viewerToken: 't'), throwsArgumentError);
      expect(() => WolvyVideo(videoId: 'v', accountId: 1, viewerToken: ' '), throwsArgumentError);
    });

    test('toString never shows the token', () {
      expect(WolvyVideo(videoId: 'v', accountId: 7, viewerToken: 'secret-value').toString(), isNot(contains('secret')));
    });
  });

  group('WolvyPlayerController', () {
    late List<MethodCall> calls;
    late List<MethodCall> pluginCalls;
    late Object? Function(MethodCall) answer;

    setUp(() {
      calls = [];
      pluginCalls = [];
      answer = (_) => null;
      messenger.setMockMethodCallHandler(plugin, (call) async {
        pluginCalls.add(call);
        return call.method == 'create' ? 7 : null;
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return answer(call);
      });
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(plugin, null);
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('the controller creates its native player first, without waiting for a view', () async {
      final c = WolvyPlayerController();
      await c.load(WolvyVideo(videoId: 'vid', accountId: 42, viewerToken: 'tok'), autoplay: false);
      expect(pluginCalls.map((e) => e.method), ['create']);
      expect(calls.single.method, 'load');
      expect(calls.single.arguments,
          {'videoId': 'vid', 'accountId': 42, 'viewerToken': 'tok', 'hasTokenProvider': false, 'autoplay': false});
    });

    test('one native player for the life of the controller (views come and go)', () async {
      final c = WolvyPlayerController();
      expect(await c.playerId, 7);
      expect(await c.playerId, 7);
      await c.play();
      await c.pause();
      expect(pluginCalls.where((e) => e.method == 'create').length, 1);
    });

    test('maps the web API methods and their answers', () async {
      final c = WolvyPlayerController();
      answer = (call) => switch (call.method) {
            'seek' => 12.5,
            'getQualities' => {'available': [1080, 720], 'selected': null, 'playing': 720},
            'getProgress' => {'percent': 33.3, 'seconds': 40, 'duration': 120.0},
            'getCaptions' => {'available': [{'language': 'ar', 'label': 'Arabic'}], 'active': 'ar'},
            'getState' => {'currentTime': 3.0, 'duration': 120.0, 'paused': false, 'muted': true, 'volume': 0.5, 'playbackRate': 1.5},
            _ => null,
          };
      expect(await c.seek(12.5), 12.5);
      final q = await c.getQualities();
      expect(q.available, [1080, 720]);
      expect(q.selected, isNull);
      expect(q.playing, 720);
      expect((await c.getProgress()).percent, 33.3);
      expect((await c.getCaptions()).available.single.label, 'Arabic');
      final s = await c.getState();
      expect(s.muted, isTrue);
      expect(s.playbackRate, 1.5);
      await c.setQuality(null);
      await c.setCaptions('ar');
      await c.setPlaybackRate(1.25);
      expect(calls.map((e) => e.method), containsAllInOrder(['seek', 'getQualities', 'setQuality', 'setCaptions', 'setPlaybackRate']));
      expect(calls.firstWhere((e) => e.method == 'setQuality').arguments, {'height': null});
    });

    test('native errors become WolvyError with the web codes', () async {
      final c = WolvyPlayerController();
      answer = (_) => throw PlatformException(code: 'not_ready', message: 'not yet', details: {'reason': null});
      await expectLater(c.seek(3), throwsA(isA<WolvyError>().having((e) => e.code, 'code', WolvyErrorCode.notReady)));
      answer = (_) => throw PlatformException(code: 'playback_error', message: 'no', details: {'reason': 'app_not_allowed'});
      await expectLater(c.play(), throwsA(isA<WolvyError>().having((e) => e.reason, 'reason', 'app_not_allowed')));
    });

    Future<Object?> fromNative(String method, Object? args) async {
      Object? result;
      await messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall(method, args)), (data) {
        result = data == null ? null : codec.decodeEnvelope(data);
      });
      return result;
    }

    test('native events arrive typed on the stream', () async {
      final c = WolvyPlayerController();
      await c.playerId;
      final got = <WolvyEvent>[];
      c.events.listen(got.add);
      await fromNative('event', {'name': 'progress', 'data': {'percent': 90.0, 'seconds': 108, 'duration': 120.0}});
      await fromNative('event', {'name': 'error', 'data': {'code': 'device_not_supported', 'message': 'needs L1', 'reason': 'hardware_drm_required'}});
      await fromNative('event', {'name': 'qualitychange', 'data': {'available': [480, 360], 'selected': 480, 'playing': 480}});
      await fromNative('event', {'name': 'unknown', 'data': {}});
      await Future<void>.delayed(Duration.zero);
      expect(got.length, 3);
      expect((got[0] as WolvyProgressEvent).progress.percent, 90.0);
      final err = (got[1] as WolvyErrorEvent).error;
      expect(err.code, WolvyErrorCode.deviceNotSupported);
      expect(err.reason, 'hardware_drm_required');
      expect((got[2] as WolvyQualityChangeEvent).qualities.selected, 480);
    });

    test('the token provider answers the native player', () async {
      final c = WolvyPlayerController();
      final seen = <String>[];
      await c.load(WolvyVideo(videoId: 'vid', accountId: 42, viewerToken: 'old', tokenProvider: (v) async {
        seen.add(v.videoId);
        return 'fresh';
      }));
      expect(calls.single.arguments['hasTokenProvider'], isTrue);
      expect(await fromNative('fetchViewerToken', {'videoId': 'vid'}), 'fresh');
      expect(seen, ['vid']);
    });

    test('a failing token provider reaches the native side as an error', () async {
      final c = WolvyPlayerController();
      await c.load(WolvyVideo(videoId: 'vid', accountId: 42, viewerToken: 'old', tokenProvider: (_) async => throw StateError('server down')));
      await expectLater(fromNative('fetchViewerToken', {'videoId': 'vid'}), throwsA(isA<PlatformException>()));
    });

    test('dispose releases the native player, then every call is destroyed', () async {
      final c = WolvyPlayerController();
      await c.play();
      await c.dispose();
      expect(pluginCalls.last.method, 'dispose');
      expect(pluginCalls.last.arguments, {'playerId': 7});
      await expectLater(c.play(), throwsA(isA<WolvyError>().having((e) => e.code, 'code', WolvyErrorCode.destroyed)));
    });

    test('dispose before any use creates nothing', () async {
      final c = WolvyPlayerController();
      await c.dispose();
      expect(pluginCalls, isEmpty);
    });
  });

  test('the codes match the web Player API', () {
    expect(WolvyErrorCode.values.map((e) => e.value), [
      'network_error', 'playback_error', 'device_not_supported', 'not_ready', 'invalid_argument', 'destroyed', 'failed',
    ]);
    expect(jsonEncode(wolvyPlaybackRates), '[0.5,0.75,1.0,1.25,1.5,2.0]');
  });
}
