# Wolvy Flutter SDK (`wolvy_player`)

**0.2.0.** Android and iOS.

Plays Wolvy's DRM-protected video in Flutter apps with the viewer watermark, screen-capture protection and the account's quality rules, and the same methods and events as Wolvy's web Player API. Built on the [Wolvy Android SDK](https://github.com/Wolvy-Media-Hub/Wolvy-SDK-Android) (Widevine) and the [Wolvy iOS SDK](https://github.com/Wolvy-Media-Hub/Wolvy-SDK-iOS) (FairPlay): this package holds no playback logic of its own, and the same Dart code runs on both.

- Your app's package name (Android) and bundle id (iOS) must be on your account's **Allowed apps** (Wolvy dashboard → Settings → Protection), each with its platform.
- The viewer token is signed on **your server** (`POST /v1/videos/{id}/playback-tokens`, or the [PHP](https://github.com/Wolvy-Media-Hub/Wolvy-SDK-PHP) and [Node.js](https://github.com/Wolvy-Media-Hub/Wolvy-SDK-Node) SDKs). Keep it short-lived and give a `tokenProvider`.

## Install

```bash
flutter pub add wolvy_player
```

- **Android:** the Wolvy Android SDK (`net.wolvy:wolvy-player`) comes from Maven Central with it. `minSdk` 24.
- **iOS:** iOS 15 or later (with CocoaPods, `platform :ios, '15.0'` in `ios/Podfile`). The Wolvy iOS SDK is inside the package (a pinned copy of its sources, see `ios/wolvy_player/CORE_VERSION`), so it works with Swift Package Manager and with CocoaPods alike.

## Use

```dart
final player = WolvyPlayerController();

player.events.listen((e) {
  switch (e) {
    case WolvyProgressEvent(:final progress) when progress.percent >= 90:
      markLessonComplete();               // seconds actually watched, each once
    case WolvyErrorEvent(:final error):
      log('${error.code.value} ${error.reason}');
    default:
  }
});

// In build():
WolvyPlayerView(controller: player)

// Then:
await player.load(WolvyVideo(
  videoId: videoId,
  accountId: accountId,
  viewerToken: tokenFromYourServer,
  tokenProvider: (video) => myServer.freshViewerToken(video.videoId),
));
```

`WolvyVideo.fromEmbedUrl(url)` reads the three values from the `embed_url` that the playback-tokens call returns.

| Controller | |
|---|---|
| `load(video, autoplay: true)` | |
| `play()`, `pause()`, `seek(seconds)`, `mute()`, `unmute()`, `setVolume(0..1)` | |
| `setPlaybackRate(rate)` | 0.5, 0.75, 1, 1.25, 1.5 or 2 |
| `setQuality(height or null)`, `setCaptions(language or null)` | null = automatic / off |
| `getState()`, `getQualities()`, `getCaptions()`, `getProgress()`, `getVideoInfo()` | |
| `retry()` | after an error |
| `events` | `WolvyReadyEvent`, `WolvyPlayEvent`, `WolvyPauseEvent`, `WolvyEndedEvent`, `WolvySeekedEvent`, `WolvyTimeUpdateEvent`, `WolvyProgressEvent`, `WolvyVolumeChangeEvent`, `WolvyRateChangeEvent`, `WolvyQualityChangeEvent`, `WolvyCaptionsChangeEvent`, `WolvyFullscreenChangeEvent`, `WolvyErrorEvent`, `WolvyCaptionCueEvent` |

Errors are `WolvyError` with the web codes (`network_error`, `playback_error`, `device_not_supported`, `not_ready`, `invalid_argument`, `destroyed`, `failed`) and a `reason` (`app_not_allowed`, `viewer_token_required`, `hardware_drm_required`…).

## Good to know

- **Android: hybrid composition.** `WolvyPlayerView` embeds the native player with hybrid composition, the only way a hardware-protected (Widevine L1) picture shows in Flutter: the default texture layer draws native views into a texture, and a protected picture there is black (tested on phones). Scrolling a page around the player costs a little more on older Android versions.
- **iOS: a UIKit view.** The view takes every touch in its area for its own controls. FairPlay needs a real iPhone or iPad: the simulator shows the steps up to the licence only.
- **The controller owns the player.** `WolvyPlayerView` only shows it, so playback goes on when Flutter rebuilds the view in another place (fullscreen, a new layout). On Android nothing plays until a view is on screen. Call `controller.dispose()` when you are done (it releases the native player).
- **Screen capture.** Android: the whole window is protected from screenshots and recordings while a player view is on screen (FLAG_SECURE). iOS: iOS keeps the FairPlay picture out of screenshots, recordings and mirroring by itself (the picture is black there).
- **Quality.** Android follows Wolvy's licence server: hardware DRM gets every quality, software DRM 480p and below, and nothing at all when the account has App-Only on. iOS has hardware DRM on every device; `setQuality` sets a ceiling there (AVPlayer adapts below it).
- **Fullscreen**: the player's button sends `WolvyFullscreenChangeEvent`; your app resizes the view (the example shows how).

## Develop

Run `flutter test`, and in `example/`: `flutter build apk --release` (Android) or `flutter build ios --simulator` / `flutter build ios --release --no-codesign` (iOS). Add `net.wolvy.player.flutter.example` to a test account's Allowed apps, platform Android and platform iOS.

To update the Wolvy iOS SDK inside the package: `tool/sync_ios_core.sh ../Wolvy-SDK-iOS` (a checkout at the wanted tag), then build and test; CI checks the copy against the commit in `ios/wolvy_player/CORE_VERSION`. `spike/` (on its own branch) is the phase 3 step 1 test app.

To try changes to the Wolvy Android SDK, build it into your local Maven repository and set `wolvy.useMavenLocal=true` in the app's `android/gradle.properties`:

```bash
git clone https://github.com/Wolvy-Media-Hub/Wolvy-SDK-Android && cd Wolvy-SDK-Android && ./gradlew :wolvy-player:publishToMavenLocal
```

## Licence

Apache License 2.0 ([LICENSE](LICENSE)).
