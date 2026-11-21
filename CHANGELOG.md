## 0.3.0

- **App protection**, from the Wolvy Android SDK 0.2.0 and iOS SDK 0.2.0. When the account sets up protection for the app (dashboard: Settings → Protection → Allowed apps → Protection), the app proves it is genuine before playback: on Android with the customer's own Google Play Integrity, on iOS with Apple's App Attest. A proven app signs its requests and plays like Wolvy Player. Without the setup, or when the proof fails, it plays as before, unless the account only allows proven apps. There's nothing to code.
- `WolvyState.attested` (in `ready` and `getState()`). New error reasons: `attestation_required`, `device_compromised` (Android, `device_not_supported`), `app_not_genuine`, `attestation_failed`.
- iOS core copy: Wolvy-SDK-iOS 0.2.0 (`ios/wolvy_player/CORE_VERSION`).

## 0.2.0

- **iOS**: the same Dart API on the Wolvy iOS SDK 0.1.0 (AVPlayer and FairPlay), shown in a UIKit view. Works with Swift Package Manager and with CocoaPods; iOS 15 or later.
- The Wolvy iOS SDK's sources are carried in the package (`ios/wolvy_player/CORE_VERSION`), since CocoaPods trunk takes no new pods.
- `setQuality` on iOS sets a ceiling; captions, chapters, the watermark, fullscreen and the token provider work as on Android.

## 0.1.0

- `WolvyPlayerController` and `WolvyPlayerView` on the Wolvy Android SDK 0.1.0: Widevine playback through `app_render_video`, the web Player API's methods, events and error codes, a viewer-token provider for short-lived tokens, hybrid composition only.
- The player belongs to the controller, not the view: playback goes on when the view is rebuilt (fullscreen, a new layout).
- Android only.
