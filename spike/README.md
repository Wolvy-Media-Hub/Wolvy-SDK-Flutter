# Spike: Flutter host

App id `net.wolvy.spike.flutter`. The same native view as a Flutter platform view, with a switch between **Hybrid composition** (`PlatformViewsService.initExpensiveAndroidView`: the real Android view sits in the window) and **Texture layer** (the default `AndroidView`: the view is drawn into a texture). A secure surface cannot be read into a texture, so the second is expected to be black for protected video; the first is the question.

The three spikes share one native view, `SpikePlayerView` (Kotlin): it calls `https://wolvy.net/api/app_render_video` with the app's package name, plays the DASH manifest with Widevine through Media3 1.11 on a secure `SurfaceView` (CDN token and session id as headers, as Wolvy Player does), and shows the Widevine level, the decoder Media3 picked (`.secure` = hardware path), the resolution, frames drawn and errors. **Copy report** copies that without any token. The window has `FLAG_SECURE`.

Input: the `embed_url` from `POST /v1/videos/{id}/playback-tokens` (`https://embed.wolvy.stream/{video}/{base64 account}?vt=…`). The app id must be on the account's Allowed apps.

**Not the SDK.** A throwaway test bench for phase 3, step 1 of the SDK plan: can hardware-protected (Widevine L1) video be shown in this kind of app? The SDK itself comes next, in `Wolvy-SDK-Android`.

Build (Flutter 3.50, Android SDK 36): `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`. Native code: `android/app/src/main/kotlin/net/wolvy/spike/`.
