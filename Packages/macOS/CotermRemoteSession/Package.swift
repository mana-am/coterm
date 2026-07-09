// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermRemoteSession",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermRemoteSession",
            targets: ["CotermRemoteSession"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
        .package(path: "../CotermCore"),
        .package(path: "../CotermRemoteDaemon"),
        .package(path: "../CotermRemoteWorkspace"),
        .package(path: "../CotermDebugLog"),
    ],
    targets: [
        .target(
            name: "CotermRemoteSession",
            dependencies: [
                .product(name: "CotermFoundation", package: "CotermFoundation"),
                .product(name: "CotermCore", package: "CotermCore"),
                .product(name: "CotermRemoteDaemon", package: "CotermRemoteDaemon"),
                .product(name: "CotermRemoteWorkspace", package: "CotermRemoteWorkspace"),
                .product(name: "CotermDebugLog", package: "CotermDebugLog"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermRemoteSessionTests",
            dependencies: [
                "CotermRemoteSession",
                .product(name: "CotermCore", package: "CotermCore"),
                .product(name: "CotermRemoteDaemon", package: "CotermRemoteDaemon"),
                .product(name: "CotermRemoteWorkspace", package: "CotermRemoteWorkspace"),
            ]
        ),
    ]
)
