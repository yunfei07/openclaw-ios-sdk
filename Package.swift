// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenClawSDK",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "OpenClawProtocol", targets: ["OpenClawProtocol"]),
        .library(name: "OpenClawSDK", targets: ["OpenClawSDK"]),
    ],
    targets: [
        .target(
            name: "OpenClawProtocol",
            path: "Sources/OpenClawProtocol",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "OpenClawSDK",
            dependencies: ["OpenClawProtocol"],
            path: "Sources/OpenClawSDK",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "OpenClawSDKTests",
            dependencies: ["OpenClawSDK"],
            path: "Tests/OpenClawSDKTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]
        ),
    ]
)
