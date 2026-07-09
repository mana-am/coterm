// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermPanes",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermPanes",
            targets: ["CotermPanes"]
        ),
    ],
    dependencies: [
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "CotermPanes",
            dependencies: [
                .product(name: "Bonsplit", package: "bonsplit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermPanesTests",
            dependencies: ["CotermPanes"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
