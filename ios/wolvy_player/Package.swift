// swift-tools-version: 5.9
// The Wolvy Flutter SDK on iOS, for apps that build plugins with Swift Package Manager.
// The Wolvy iOS SDK's sources are carried in Sources/wolvy_player/WolvyCore (see CORE_VERSION).
import PackageDescription

let package = Package(
    name: "wolvy_player",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "wolvy-player", targets: ["wolvy_player"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "wolvy_player",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
