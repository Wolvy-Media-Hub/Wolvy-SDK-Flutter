import Flutter
import UIKit

/// The players live here, one per Dart WolvyPlayerController, created and disposed over the
/// `net.wolvy.player` channel. Views (`net.wolvy.player/view`) only show a player: when Flutter
/// replaces a view (fullscreen, any change of layout), the player goes on in the new one.
/// The same protocol as the Android side.
public final class WolvyPlayerPlugin: NSObject, FlutterPlugin {
    static let channelName = "net.wolvy.player"
    static let viewType = "net.wolvy.player/view"
    /// This package's version, sent to Wolvy in X-Wolvy-SDK.
    static let version = "0.2.0"

    private let messenger: FlutterBinaryMessenger
    private var players: [Int: WolvyFlutterPlayer] = [:]
    private var nextId = 1

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = WolvyPlayerPlugin(messenger: registrar.messenger())
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(WolvyViewFactory { [weak instance] id in instance?.players[id]?.player }, withId: viewType)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        MainActor.assumeIsolated {
            switch call.method {
            case "create":
                let id = nextId
                nextId += 1
                players[id] = WolvyFlutterPlayer(messenger: messenger, playerId: id)
                result(id)
            case "dispose":
                if let id = (call.arguments as? [String: Any])?["playerId"] as? Int {
                    players.removeValue(forKey: id)?.release()
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        MainActor.assumeIsolated {
            players.values.forEach { $0.release() }
            players.removeAll()
        }
    }
}

/// Makes the native views. A view shows the player its creation parameters name.
final class WolvyViewFactory: NSObject, FlutterPlatformViewFactory {
    private let lookup: @MainActor (Int) -> WolvyPlayer?

    init(lookup: @escaping @MainActor (Int) -> WolvyPlayer?) {
        self.lookup = lookup
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        MainActor.assumeIsolated {
            let params = args as? [String: Any]
            let view = WolvyPlayerView(frame: frame)
            view.showControls = params?["showControls"] as? Bool ?? true
            view.player = (params?["playerId"] as? Int).flatMap(lookup)
            return WolvyPlatformView(view)
        }
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

/// One native view. When Flutter drops it, only the view goes: the player stays with its controller.
final class WolvyPlatformView: NSObject, FlutterPlatformView {
    private let playerView: WolvyPlayerView

    init(_ playerView: WolvyPlayerView) {
        self.playerView = playerView
        super.init()
    }

    func view() -> UIView { playerView }
}
