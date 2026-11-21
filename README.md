# Wolvy Flutter SDK (`wolvy_player`)

**0.1.0, ready for pub.dev (publisher wolvy.net; not released yet).** Android only in this version; iOS comes with the iOS SDK.

Plays Wolvy's DRM-protected video in Flutter apps with the viewer watermark, screen-capture protection and the account's quality rules, and the same methods and events as Wolvy's web Player API. Built on the [Wolvy Android SDK](https://github.com/Wolvy-Media-Hub/Wolvy-SDK-Android): this package holds no playback logic of its own.

- Your app's package name must be on your account's **Allowed apps** (Wolvy dashboard → Settings → Protection).
- The viewer token is signed on **your server** (`POST /v1/videos/{id}/playback-tokens`, or the [PHP](https://github.com/Wolvy-Media-Hub/Wolvy-SDK-PHP) and [Node.js](https://github.com/Wolvy-Media-Hub/Wolvy-SDK-Node) SDKs). Keep it short-lived and give a `tokenProvider`.

## Install

Once released (not yet), with the Wolvy Android SDK on Maven Central:

```bash
flutter pub add wolvy_player
```

`minSdk` 24. Add your app's package name to Allowed apps.

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

- **Hybrid composition.** `WolvyPlayerView` embeds the native player with hybrid composition, the only way a hardware-protected (Widevine L1) picture shows in Flutter: the default texture layer draws native views into a texture, and a protected picture there is black (tested on phones). Scrolling a page around the player costs a little more on older Android versions.
- **The controller owns the player.** `WolvyPlayerView` only shows it, so playback goes on when Flutter rebuilds the view in another place (fullscreen, a new layout). Nothing plays until a view is on screen. Call `controller.dispose()` when you are done (it releases the native player).
- **The whole window is protected** from screenshots and recordings while the player is on screen (FLAG_SECURE), as long as any player view is on it.
- **Quality** follows Wolvy's licence server: hardware DRM gets every quality, software DRM 480p and below, and nothing at all when the account has App-Only on.
- **Fullscreen**: the player's button sends `WolvyFullscreenChangeEvent`; your app resizes the view (the example shows how).

## Develop

Until the Android SDK is on Maven Central, build it into your local Maven repository first and set `wolvy.useMavenLocal=true` in the app's `android/gradle.properties` (the example does):

```bash
git clone https://github.com/Wolvy-Media-Hub/Wolvy-SDK-Android && cd Wolvy-SDK-Android && ./gradlew :wolvy-player:publishToMavenLocal
```

Then `flutter test`, and in `example/`: `flutter build apk --release`. Add `net.wolvy.player.flutter.example` to a test account's Allowed apps. `spike/` (on its own branch) is the phase 3 step 1 test app.

## Licence

Apache License 2.0 ([LICENSE](LICENSE)).
