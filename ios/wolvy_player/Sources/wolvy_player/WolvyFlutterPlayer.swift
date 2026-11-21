import Flutter
import Foundation

/// One Dart WolvyPlayerController: a WolvyPlayer from the Wolvy iOS SDK, driven over the
/// `net.wolvy.player/player_<id>` channel. No playback logic here: commands go to the core, events
/// and token requests come back, with the same names and data as on Android.
@MainActor
final class WolvyFlutterPlayer: WolvyPlayerListener {
    let player: WolvyPlayer
    private let channel: FlutterMethodChannel
    private var disposed = false

    init(messenger: FlutterBinaryMessenger, playerId: Int) {
        channel = FlutterMethodChannel(name: "net.wolvy.player/player_\(playerId)", binaryMessenger: messenger)
        player = WolvyPlayer(source: WolvyAppRenderVideoSource(
            sdk: "wolvy-flutter/\(WolvyPlayerPlugin.version)+ios.\(WolvyPlayer.sdkVersion)"))
        player.addListener(self)
        channel.setMethodCallHandler { [weak self] call, result in
            MainActor.assumeIsolated { self?.handle(call, result) }
        }
    }

    func release() {
        guard !disposed else { return }
        disposed = true
        channel.setMethodCallHandler(nil)
        player.release()
    }

    // MARK: - Commands

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        do {
            let value: Any?
            switch call.method {
            case "load":
                let video = try WolvyVideo(
                    videoId: args["videoId"] as? String ?? "",
                    accountId: Int64(truncating: args["accountId"] as? NSNumber ?? 0),
                    viewerToken: args["viewerToken"] as? String ?? "",
                    tokenProvider: (args["hasTokenProvider"] as? Bool ?? false) ? tokenProvider() : nil)
                try player.load(video, autoplay: args["autoplay"] as? Bool ?? true)
                value = nil
            case "play": try player.play(); value = nil
            case "pause": try player.pause(); value = nil
            case "seek": value = try player.seek((args["seconds"] as? NSNumber)?.doubleValue ?? 0)
            case "mute": try player.mute(); value = nil
            case "unmute": try player.unmute(); value = nil
            case "setVolume": try player.setVolume((args["volume"] as? NSNumber)?.floatValue ?? -1); value = nil
            case "setPlaybackRate": try player.setPlaybackRate((args["rate"] as? NSNumber)?.floatValue ?? -1); value = nil
            case "setQuality": try player.setQuality((args["height"] as? NSNumber)?.intValue); value = nil
            case "setCaptions": try player.setCaptions(args["language"] as? String); value = nil
            case "retry": try player.retry(); value = nil
            case "getState": value = Self.map(player.getState())
            case "getQualities": value = Self.map(player.getQualities())
            case "getCaptions":
                let c = player.getCaptions()
                value = ["available": c.available.map { ["language": $0.language, "label": $0.label] }, "active": Self.null(c.active)]
            case "getProgress": value = Self.map(player.getProgress())
            case "getVideoInfo": value = player.videoInfo.map(Self.map) ?? NSNull()
            default:
                result(FlutterMethodNotImplemented)
                return
            }
            result(value)
        } catch let error as WolvyError {
            result(FlutterError(code: error.code.rawValue, message: error.message, details: ["reason": Self.null(error.reason)]))
        } catch {
            result(FlutterError(code: WolvyError.Code.failed.rawValue, message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - Short tokens: asks Dart

    private struct TokenError: LocalizedError {
        let errorDescription: String?
    }

    /// Asks Dart's tokenProvider for a fresh viewer token (30 s at most).
    private func tokenProvider() -> WolvyViewerTokenProvider {
        { [weak self] video in
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) in
                Task { @MainActor in
                    guard let self, !self.disposed else {
                        continuation.resume(throwing: TokenError(errorDescription: "The player was disposed."))
                        return
                    }
                    var answered = false
                    let timeout = DispatchWorkItem {
                        guard !answered else { return }
                        answered = true
                        continuation.resume(throwing: TokenError(errorDescription: "The app's token provider did not answer in 30 s."))
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
                    self.channel.invokeMethod("fetchViewerToken", arguments: ["videoId": video.videoId]) { reply in
                        guard !answered else { return }
                        answered = true
                        timeout.cancel()
                        if let error = reply as? FlutterError {
                            continuation.resume(throwing: TokenError(errorDescription: "The app's token provider failed: \(error.message ?? error.code)"))
                        } else if let marker = reply as? NSObject, marker === FlutterMethodNotImplemented {
                            continuation.resume(throwing: TokenError(errorDescription: "No token provider."))
                        } else {
                            continuation.resume(returning: reply as? String)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Events

    private func send(_ name: String, _ data: [String: Any]) {
        guard !disposed else { return }
        channel.invokeMethod("event", arguments: ["name": name, "data": data])
    }

    func onReady(_ state: WolvyState) { send("ready", Self.map(state)) }
    func onPlay(_ currentTime: Double) { send("play", ["currentTime": currentTime]) }
    func onPause(_ currentTime: Double) { send("pause", ["currentTime": currentTime]) }
    func onEnded() { send("ended", [:]) }
    func onSeeked(_ currentTime: Double) { send("seeked", ["currentTime": currentTime]) }
    func onTimeUpdate(_ currentTime: Double, duration: Double) { send("timeupdate", ["currentTime": currentTime, "duration": duration]) }
    func onProgress(_ progress: WolvyProgress) { send("progress", Self.map(progress)) }
    func onVolumeChange(_ volume: Float, muted: Bool) { send("volumechange", ["volume": Double(volume), "muted": muted]) }
    func onRateChange(_ playbackRate: Float) { send("ratechange", ["playbackRate": Double(playbackRate)]) }
    func onQualityChange(_ qualities: WolvyQualities) { send("qualitychange", Self.map(qualities)) }
    func onCaptionsChange(_ active: String?) { send("captionschange", ["active": Self.null(active)]) }
    func onFullscreenChange(_ fullscreen: Bool) { send("fullscreenchange", ["fullscreen": fullscreen]) }
    func onError(_ error: WolvyError) {
        send("error", ["code": error.code.rawValue, "message": error.message, "reason": Self.null(error.reason)])
    }
    func onCaptionCue(_ text: String?) { send("captioncue", ["text": Self.null(text)]) }

    // MARK: - Maps for the standard codec (nil is NSNull)

    static func null(_ value: Any?) -> Any { value ?? NSNull() }

    static func map(_ s: WolvyState) -> [String: Any] {
        ["currentTime": s.currentTime, "duration": s.duration, "paused": s.paused,
         "muted": s.muted, "volume": Double(s.volume), "playbackRate": Double(s.playbackRate)]
    }

    static func map(_ q: WolvyQualities) -> [String: Any] {
        ["available": q.available, "selected": null(q.selected), "playing": null(q.playing)]
    }

    static func map(_ p: WolvyProgress) -> [String: Any] {
        ["percent": p.percent, "seconds": p.seconds, "duration": p.duration]
    }

    static func map(_ i: WolvyVideoInfo) -> [String: Any] {
        [
            "chapters": i.chapters.map { ["start": $0.start, "end": $0.end, "title": $0.title] },
            "moments": i.moments.map { ["timestamp": $0.timestamp, "label": $0.label] },
            "viewerId": null(i.viewerId),
            // Dart reads the colour as 0xAARRGGBB, as Android sends it.
            "playerColor": null(i.playerColor.flatMap(argb)),
            "poster": null(i.poster?.absoluteString),
        ]
    }

    /// "#RRGGBB" as 0xFFRRGGBB.
    static func argb(_ hex: String) -> Int? {
        guard hex.count == 7, hex.hasPrefix("#"), let rgb = Int(hex.dropFirst(), radix: 16) else { return nil }
        return 0xFF00_0000 | rgb
    }
}
