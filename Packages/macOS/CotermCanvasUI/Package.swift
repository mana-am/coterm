// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermCanvasUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermCanvasUI",
            targets: ["CotermCanvasUI"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermCanvas"),
        .package(path: "../CotermFoundation"),
    ],
    targets: [
        .target(
            name: "CotermCanvasUI",
            dependencies: [
                "CotermCanvas",
                "CotermFoundation",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermCanvasUITests",
            dependencies: [
                "CotermCanvasUI",
            ]
        ),
    ]
)
