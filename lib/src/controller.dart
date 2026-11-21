import 'dart:async';

import 'package:flutter/services.dart';

import 'events.dart';
import 'models.dart';

/// Controls one [WolvyPlayerView]: the web Player API's methods, and its events on [events].
///
/// ```dart
/// final player = WolvyPlayerController();
/// player.events.listen((e) {
///   if (e is WolvyProgressEvent && e.progress.percent >= 90) markLessonComplete();
/// });
/// // build: WolvyPlayerView(controller: player)
/// await player.load(WolvyVideo(videoId: id, accountId: 42, viewerToken: tokenFromYourServer));
/// ```
///
/// The controller owns the native player: a [WolvyPlayerView] only shows it, so the video goes
/// on when the view is rebuilt elsewhere (fullscreen, any change of layout). Nothing plays until
/// a view is on screen (it confirms screen protection). Call [dispose] when you are done.
/// Methods throw [WolvyError] with the web Player API's codes.
class WolvyPlayerController {
  WolvyPlayerController();

  static const MethodChannel _plugin = MethodChannel('net.wolvy.player');

  final StreamController<WolvyEvent> _events = StreamController<WolvyEvent>.broadcast();
  Future<int>? _playerId;
  MethodChannel? _channel;
  WolvyVideo? _video;
  bool _disposed = false;

  /// Player events. A broadcast stream: listen as many times as you like.
  Stream<WolvyEvent> get events => _events.stream;

  /// Loads [video]. It starts playing once a [WolvyPlayerView] shows this controller.
  Future<void> load(WolvyVideo video, {bool autoplay = true}) async {
    _video = video;
    await _invoke('load', {
      'videoId': video.videoId,
      'accountId': video.accountId,
      'viewerToken': video.viewerToken,
      'hasTokenProvider': video.tokenProvider != null,
      'autoplay': autoplay,
    });
  }

  Future<void> play() => _invoke('play');
  Future<void> pause() => _invoke('pause');

  /// Jumps to [seconds]; returns the time jumped to.
  Future<double> seek(double seconds) async => ((await _invoke('seek', {'seconds': seconds})) as num).toDouble();

  Future<void> mute() => _invoke('mute');
  Future<void> unmute() => _invoke('unmute');

  /// [volume] from 0 to 1.
  Future<void> setVolume(double volume) => _invoke('setVolume', {'volume': volume});

  /// One of [wolvyPlaybackRates].
  Future<void> setPlaybackRate(double rate) => _invoke('setPlaybackRate', {'rate': rate});

  /// A height from [getQualities], or null for automatic.
  Future<void> setQuality(int? height) => _invoke('setQuality', {'height': height});

  /// A language from [getCaptions], or null to turn captions off.
  Future<void> setCaptions(String? language) => _invoke('setCaptions', {'language': language});

  /// After an error: try again from where playback stopped.
  Future<void> retry() => _invoke('retry');

  Future<WolvyState> getState() async => WolvyState.fromMap(await _invoke('getState') as Map);
  Future<WolvyQualities> getQualities() async => WolvyQualities.fromMap(await _invoke('getQualities') as Map);
  Future<WolvyCaptions> getCaptions() async => WolvyCaptions.fromMap(await _invoke('getCaptions') as Map);
  Future<WolvyProgress> getProgress() async => WolvyProgress.fromMap(await _invoke('getProgress') as Map);

  /// Chapters, highlights, viewer id and player colour; null before the video is loaded.
  Future<WolvyVideoInfo?> getVideoInfo() async {
    final m = await _invoke('getVideoInfo');
    return m == null ? null : WolvyVideoInfo.fromMap(m as Map);
  }

  /// Releases the native player and closes [events]. Remove the [WolvyPlayerView] first.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    final id = _playerId;
    if (id != null) {
      try {
        await _plugin.invokeMethod<void>('dispose', {'playerId': await id});
      } catch (_) {
        // The engine is going away: the plugin releases every player then.
      }
    }
    await _events.close();
  }

  /// The native player's id, created on first use. For [WolvyPlayerView].
  Future<int> get playerId => _playerId ??= _create();

  Future<int> _create() async {
    final id = await _plugin.invokeMethod<int>('create');
    if (id == null) throw const WolvyError(WolvyErrorCode.failed, 'The native player could not be created.');
    final channel = MethodChannel('net.wolvy.player/player_$id');
    channel.setMethodCallHandler(_fromNative);
    _channel = channel;
    return id;
  }

  Future<Object?> _fromNative(MethodCall call) async {
    switch (call.method) {
      case 'event':
        final e = WolvyEvent.fromMap(call.arguments as Map);
        if (e != null && !_events.isClosed) _events.add(e);
        return null;
      case 'fetchViewerToken':
        final video = _video;
        final provider = video?.tokenProvider;
        if (video == null || provider == null) return null;
        // A failure here reaches the native side as an error: the player reports
        // network_error with reason token_provider_failed.
        return provider(video);
    }
    throw MissingPluginException(call.method);
  }

  Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    if (_disposed) throw const WolvyError(WolvyErrorCode.destroyed, 'dispose() was called on this controller.');
    await playerId;
    final channel = _channel;
    if (channel == null || _disposed) {
      throw const WolvyError(WolvyErrorCode.destroyed, 'dispose() was called on this controller.');
    }
    try {
      return await channel.invokeMethod<Object?>(method, args);
    } on PlatformException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      throw WolvyError(WolvyErrorCode.fromValue(e.code), e.message ?? '', reason: details['reason'] as String?);
    }
  }
}
