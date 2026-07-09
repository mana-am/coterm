// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermSettingsUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermSettingsUI",
            targets: ["CotermSettingsUI"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
        .package(path: "../CotermSettings"),
    ],
    targets: [
        .target(
            name: "CotermSettingsUI",
            dependencies: [
                .product(name: "CotermFoundation", package: "CotermFoundation"),
                .product(name: "CotermSettings", package: "CotermSettings"),
            ]
        ),
        .testTarget(
            name: "CotermSettingsUITests",
            dependencies: ["CotermSettingsUI"]
        ),
    ]
)
