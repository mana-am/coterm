// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermRemoteDaemon",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermRemoteDaemon",
            targets: ["CotermRemoteDaemon"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
        .package(path: "../CotermCore"),
    ],
    targets: [
        .target(
            name: "CotermRemoteDaemon",
            dependencies: [
                .product(name: "CotermFoundation", package: "CotermFoundation"),
                .product(name: "CotermCore", package: "CotermCore"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermRemoteDaemonTests",
            dependencies: [
                "CotermRemoteDaemon",
                .product(name: "CotermCore", package: "CotermCore"),
            ]
        ),
    ]
)
