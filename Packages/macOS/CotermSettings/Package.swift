// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermSettings",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermSettings",
            targets: ["CotermSettings"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
    ],
    targets: [
        .target(
            name: "CotermSettings",
            dependencies: [
                .product(name: "CotermFoundation", package: "CotermFoundation"),
            ]
        ),
        .testTarget(
            name: "CotermSettingsTests",
            dependencies: ["CotermSettings"]
        ),
    ]
)
