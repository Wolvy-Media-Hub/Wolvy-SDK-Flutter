import 'dart:convert';

/// Gets a fresh viewer token from **your server** (never signed in the app). See [WolvyVideo.tokenProvider].
typedef WolvyTokenProvider = Future<String?> Function(WolvyVideo video);

/// The three values a playback needs, the same ones the embed URL and the deep link carry.
class WolvyVideo {
  WolvyVideo({
    required this.videoId,
    required this.accountId,
    required this.viewerToken,
    this.tokenProvider,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(videoId)) {
      throw ArgumentError.value(videoId, 'videoId', 'must be 1 to 64 letters, digits, "-" or "_"');
    }
    if (accountId <= 0) throw ArgumentError.value(accountId, 'accountId', 'must be positive');
    if (viewerToken.trim().isEmpty) {
      throw ArgumentError.value('', 'viewerToken', 'is required: sign it on your server');
    }
  }

  final String videoId;
  final int accountId;

  /// Signed on your server: `POST /v1/videos/{id}/playback-tokens`, or `signViewerToken` in the
  /// PHP and Node SDKs. Keep it short-lived (minutes) and give a [tokenProvider].
  final String viewerToken;

  /// Asked for a fresh token when the one the player has expires within a minute, and once more
  /// if Wolvy refuses it. Fetch it from your server.
  final WolvyTokenProvider? tokenProvider;

  /// Reads the three values from the `embed_url` that `POST /v1/videos/{id}/playback-tokens`
  /// returns: `https://embed.wolvy.stream/{videoId}/{base64 accountId}?vt=…`.
  /// Throws [FormatException] when it is not such a URL.
  factory WolvyVideo.fromEmbedUrl(String url, {WolvyTokenProvider? tokenProvider}) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) throw const FormatException('Not a URL.');
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final vt = uri.queryParameters['vt'];
    if (parts.length < 2 || vt == null || vt.isEmpty) {
      throw const FormatException('Expected https://embed.wolvy.stream/{videoId}/{base64 accountId}?vt=…');
    }
    int? account;
    try {
      account = int.tryParse(utf8.decode(base64.decode(base64.normalize(parts[1].replaceAll('-', '+').replaceAll('_', '/')))).trim());
    } catch (_) {
      account = null;
    }
    if (account == null) throw const FormatException('The second part of the path is not a base64 account id.');
    return WolvyVideo(videoId: parts[0], accountId: account, viewerToken: vt, tokenProvider: tokenProvider);
  }

  /// No token: safe to log.
  @override
  String toString() => 'WolvyVideo(videoId: $videoId, accountId: $accountId)';
}

/// The web Player API's error codes.
enum WolvyErrorCode {
  networkError('network_error'),
  playbackError('playback_error'),
  deviceNotSupported('device_not_supported'),
  notReady('not_ready'),
  invalidArgument('invalid_argument'),
  destroyed('destroyed'),
  failed('failed');

  const WolvyErrorCode(this.value);
  final String value;

  static WolvyErrorCode fromValue(String? v) =>
      WolvyErrorCode.values.firstWhere((c) => c.value == v, orElse: () => WolvyErrorCode.failed);
}

/// An error from the player. [reason] is the server's code (`app_not_allowed`,
/// `viewer_token_required`, `update_required`…) or the device's (`hardware_drm_required`,
/// `screen_protection_unavailable`…).
class WolvyError implements Exception {
  const WolvyError(this.code, this.message, {this.reason});
  final WolvyErrorCode code;
  final String message;
  final String? reason;

  static WolvyError fromMap(Map<dynamic, dynamic> m) => WolvyError(
        WolvyErrorCode.fromValue(m['code'] as String?),
        (m['message'] as String?) ?? '',
        reason: m['reason'] as String?,
      );

  @override
  String toString() => 'WolvyError(${code.value}${reason == null ? '' : ', $reason'}): $message';
}

/// What `ready` carries and [WolvyPlayerController.getState] returns. Times in seconds.
class WolvyState {
  const WolvyState({
    required this.currentTime,
    required this.duration,
    required this.paused,
    required this.muted,
    required this.volume,
    required this.playbackRate,
    this.attested = false,
  });
  final double currentTime;
  final double duration;
  final bool paused;
  final bool muted;
  final double volume;
  final double playbackRate;

  /// The app proved itself to Wolvy for this video (app protection): it plays like Wolvy Player.
  final bool attested;

  static WolvyState fromMap(Map<dynamic, dynamic> m) => WolvyState(
        currentTime: _d(m['currentTime']),
        duration: _d(m['duration']),
        paused: m['paused'] == true,
        muted: m['muted'] == true,
        volume: _d(m['volume']),
        playbackRate: _d(m['playbackRate'], 1),
        attested: m['attested'] == true,
      );
}

/// [selected] is the picked height, or null for automatic; [playing] is the height on screen.
class WolvyQualities {
  const WolvyQualities({required this.available, this.selected, this.playing});
  final List<int> available;
  final int? selected;
  final int? playing;

  static WolvyQualities fromMap(Map<dynamic, dynamic> m) => WolvyQualities(
        available: ((m['available'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
        selected: (m['selected'] as num?)?.toInt(),
        playing: (m['playing'] as num?)?.toInt(),
      );
}

class WolvyCaptionTrack {
  const WolvyCaptionTrack(this.language, this.label);
  final String language;
  final String label;
}

/// [active] is the language shown, or null when captions are off.
class WolvyCaptions {
  const WolvyCaptions({required this.available, this.active});
  final List<WolvyCaptionTrack> available;
  final String? active;

  static WolvyCaptions fromMap(Map<dynamic, dynamic> m) => WolvyCaptions(
        available: ((m['available'] as List?) ?? const [])
            .map((e) => WolvyCaptionTrack((e as Map)['language'] as String, (e['label'] as String?) ?? ''))
            .toList(),
        active: m['active'] as String?,
      );
}

/// Seconds actually played, each counted once: the same numbers as the web player.
class WolvyProgress {
  const WolvyProgress({required this.percent, required this.seconds, required this.duration});
  final double percent;
  final int seconds;
  final double duration;

  static WolvyProgress fromMap(Map<dynamic, dynamic> m) => WolvyProgress(
        percent: _d(m['percent']),
        seconds: (m['seconds'] as num?)?.toInt() ?? 0,
        duration: _d(m['duration']),
      );
}

class WolvyChapter {
  const WolvyChapter(this.start, this.end, this.title);
  final double start;
  final double end;
  final String title;
}

class WolvyMoment {
  const WolvyMoment(this.timestamp, this.label);
  final double timestamp;
  final String label;
}

/// Chapters, highlights, the viewer id and the account's player colour, once loaded.
class WolvyVideoInfo {
  const WolvyVideoInfo({required this.chapters, required this.moments, this.viewerId, this.playerColor, this.poster});
  final List<WolvyChapter> chapters;
  final List<WolvyMoment> moments;
  final String? viewerId;

  /// 0xAARRGGBB, or null.
  final int? playerColor;
  final String? poster;

  static WolvyVideoInfo fromMap(Map<dynamic, dynamic> m) => WolvyVideoInfo(
        chapters: ((m['chapters'] as List?) ?? const [])
            .map((e) => WolvyChapter(_d((e as Map)['start']), _d(e['end']), (e['title'] as String?) ?? ''))
            .toList(),
        moments: ((m['moments'] as List?) ?? const [])
            .map((e) => WolvyMoment(_d((e as Map)['timestamp']), (e['label'] as String?) ?? ''))
            .toList(),
        viewerId: m['viewerId'] as String?,
        playerColor: (m['playerColor'] as num?)?.toInt(),
        poster: m['poster'] as String?,
      );
}

/// The speeds the player offers: the only values `setPlaybackRate` accepts.
const List<double> wolvyPlaybackRates = [0.5, 0.75, 1, 1.25, 1.5, 2];

double _d(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
