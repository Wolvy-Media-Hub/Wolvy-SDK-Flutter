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
/// Commands sent before the view exists wait for it. Methods throw [WolvyError] with the web
/// Player API's codes.
class WolvyPlayerController {
  WolvyPlayerController();

  final StreamController<WolvyEvent> _events = StreamController<WolvyEvent>.broadcast();
  Completer<void> _attached = Completer<void>();
  MethodChannel? _channel;
  WolvyVideo? _video;
  bool _disposed = false;

  /// Player events. A broadcast stream: listen as many times as you like.
  Stream<WolvyEvent> get events => _events.stream;

  /// Loads [video] (the view must be in the tree, or the call waits for it).
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

  /// Closes [events]. The native player is released when the [WolvyPlayerView] leaves the tree.
  Future<void> dispose() async {
    _disposed = true;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    await _events.close();
  }

  // ---- for WolvyPlayerView ------------------------------------------------------------------

  /// Called by the view once its native player exists.
  void attachView(int viewId) {
    if (_disposed) return;
    final channel = MethodChannel('net.wolvy.player/view_$viewId');
    channel.setMethodCallHandler(_fromNative);
    _channel = channel;
    if (!_attached.isCompleted) _attached.complete();
  }

  /// Called by the view when it leaves the tree.
  void detachView(int viewId) {
    if (_channel?.name != 'net.wolvy.player/view_$viewId') return;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _attached = Completer<void>();
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
    await _attached.future;
    final channel = _channel;
    if (channel == null) throw const WolvyError(WolvyErrorCode.destroyed, 'The player view was removed.');
    try {
      return await channel.invokeMethod<Object?>(method, args);
    } on PlatformException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      throw WolvyError(WolvyErrorCode.fromValue(e.code), e.message ?? '', reason: details['reason'] as String?);
    }
  }
}
