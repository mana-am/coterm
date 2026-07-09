// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermCommandPalette",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermCommandPalette",
            targets: ["CotermCommandPalette"]
        ),
    ],
    dependencies: [
        // CotermFoundation backs the FocusGuards/ command-palette focus-stealing
        // NSResponder/NSView guards.
        .package(path: "../CotermFoundation"),
    ],
    targets: [
        .target(
            name: "CotermCommandPalette",
            dependencies: [
                .product(name: "CotermFoundation", package: "CotermFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermCommandPaletteTests",
            dependencies: [
                "CotermCommandPalette",
                .product(name: "CotermFoundation", package: "CotermFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
