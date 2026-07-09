// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermUpdater",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermUpdater",
            targets: ["CotermUpdater"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(
            name: "CotermUpdater",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermUpdaterTests",
            dependencies: [
                "CotermUpdater",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
