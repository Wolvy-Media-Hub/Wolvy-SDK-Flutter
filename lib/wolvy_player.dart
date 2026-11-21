/// Plays Wolvy's DRM-protected video in Flutter apps: Widevine through the native Wolvy
/// Android SDK, with the viewer watermark, screen-capture protection and the account's quality
/// rules, and the same methods and events as Wolvy's web Player API.
///
/// Android only in this version (iOS comes with the iOS SDK).
library;

export 'src/controller.dart' show WolvyPlayerController;
export 'src/events.dart';
export 'src/models.dart';
export 'src/view.dart' show WolvyPlayerView;
