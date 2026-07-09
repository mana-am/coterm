// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermCore",
            targets: ["CotermCore"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
    ],
    targets: [
        .target(
            name: "CotermCore",
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
            name: "CotermCoreTests",
            dependencies: ["CotermCore"]
        ),
    ]
)
