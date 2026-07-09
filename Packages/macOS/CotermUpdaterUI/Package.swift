// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermUpdaterUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermUpdaterUI",
            targets: ["CotermUpdaterUI"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
        .package(path: "../CotermUpdater"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(
            name: "CotermUpdaterUI",
            dependencies: [
                "CotermFoundation",
                "CotermUpdater",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermUpdaterUITests",
            dependencies: ["CotermUpdaterUI"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
