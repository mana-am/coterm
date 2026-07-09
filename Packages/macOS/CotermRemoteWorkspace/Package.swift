// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermRemoteWorkspace",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermRemoteWorkspace",
            targets: ["CotermRemoteWorkspace"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
        .package(path: "../CotermCore"),
        .package(path: "../CotermRemoteDaemon"),
        .package(path: "../CotermSettings"),
    ],
    targets: [
        .target(
            name: "CotermRemoteWorkspace",
            dependencies: [
                .product(name: "CotermFoundation", package: "CotermFoundation"),
                .product(name: "CotermCore", package: "CotermCore"),
                .product(name: "CotermRemoteDaemon", package: "CotermRemoteDaemon"),
                .product(name: "CotermSettings", package: "CotermSettings"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermRemoteWorkspaceTests",
            dependencies: ["CotermRemoteWorkspace"]
        ),
    ]
)
