// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermCanvas",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "CotermCanvas",
            targets: ["CotermCanvas"]
        ),
    ],
    targets: [
        .target(
            name: "CotermCanvas",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermCanvasTests",
            dependencies: [
                "CotermCanvas",
            ]
        ),
    ]
)
