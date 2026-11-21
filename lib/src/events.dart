import 'models.dart';

/// Player events, with the web Player API's names (see [name]).
sealed class WolvyEvent {
  const WolvyEvent(this.name);

  /// The web Player API's event name, e.g. `progress`.
  final String name;

  static WolvyEvent? fromMap(Map<dynamic, dynamic> m) {
    final data = (m['data'] as Map?) ?? const {};
    double d(String k) => (data[k] as num?)?.toDouble() ?? 0;
    switch (m['name']) {
      case 'ready':
        return WolvyReadyEvent(WolvyState.fromMap(data));
      case 'play':
        return WolvyPlayEvent(d('currentTime'));
      case 'pause':
        return WolvyPauseEvent(d('currentTime'));
      case 'ended':
        return const WolvyEndedEvent();
      case 'seeked':
        return WolvySeekedEvent(d('currentTime'));
      case 'timeupdate':
        return WolvyTimeUpdateEvent(d('currentTime'), d('duration'));
      case 'progress':
        return WolvyProgressEvent(WolvyProgress.fromMap(data));
      case 'volumechange':
        return WolvyVolumeChangeEvent(d('volume'), data['muted'] == true);
      case 'ratechange':
        return WolvyRateChangeEvent(d('playbackRate'));
      case 'qualitychange':
        return WolvyQualityChangeEvent(WolvyQualities.fromMap(data));
      case 'captionschange':
        return WolvyCaptionsChangeEvent(data['active'] as String?);
      case 'fullscreenchange':
        return WolvyFullscreenChangeEvent(data['fullscreen'] == true);
      case 'error':
        return WolvyErrorEvent(WolvyError.fromMap(data));
      case 'captioncue':
        return WolvyCaptionCueEvent(data['text'] as String?);
    }
    return null;
  }
}

/// The video is loaded and accepts every command. Once per load.
class WolvyReadyEvent extends WolvyEvent {
  const WolvyReadyEvent(this.state) : super('ready');
  final WolvyState state;
}

class WolvyPlayEvent extends WolvyEvent {
  const WolvyPlayEvent(this.currentTime) : super('play');
  final double currentTime;
}

class WolvyPauseEvent extends WolvyEvent {
  const WolvyPauseEvent(this.currentTime) : super('pause');
  final double currentTime;
}

class WolvyEndedEvent extends WolvyEvent {
  const WolvyEndedEvent() : super('ended');
}

class WolvySeekedEvent extends WolvyEvent {
  const WolvySeekedEvent(this.currentTime) : super('seeked');
  final double currentTime;
}

/// About 4 times a second while playing.
class WolvyTimeUpdateEvent extends WolvyEvent {
  const WolvyTimeUpdateEvent(this.currentTime, this.duration) : super('timeupdate');
  final double currentTime;
  final double duration;
}

/// As the share played changes, at most once a second, and once more at the end.
class WolvyProgressEvent extends WolvyEvent {
  const WolvyProgressEvent(this.progress) : super('progress');
  final WolvyProgress progress;
}

class WolvyVolumeChangeEvent extends WolvyEvent {
  const WolvyVolumeChangeEvent(this.volume, this.muted) : super('volumechange');
  final double volume;
  final bool muted;
}

class WolvyRateChangeEvent extends WolvyEvent {
  const WolvyRateChangeEvent(this.playbackRate) : super('ratechange');
  final double playbackRate;
}

class WolvyQualityChangeEvent extends WolvyEvent {
  const WolvyQualityChangeEvent(this.qualities) : super('qualitychange');
  final WolvyQualities qualities;
}

class WolvyCaptionsChangeEvent extends WolvyEvent {
  const WolvyCaptionsChangeEvent(this.active) : super('captionschange');
  final String? active;
}

/// The player's fullscreen button: your app resizes the view.
class WolvyFullscreenChangeEvent extends WolvyEvent {
  const WolvyFullscreenChangeEvent(this.fullscreen) : super('fullscreenchange');
  final bool fullscreen;
}

/// The video could not be loaded or played. After this, control methods throw the same error.
class WolvyErrorEvent extends WolvyEvent {
  const WolvyErrorEvent(this.error) : super('error');
  final WolvyError error;
}

/// Flutter/Android only: the caption text to show now, for apps that draw their own captions.
class WolvyCaptionCueEvent extends WolvyEvent {
  const WolvyCaptionCueEvent(this.text) : super('captioncue');
  final String? text;
}
