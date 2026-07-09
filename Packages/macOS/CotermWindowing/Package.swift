// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermWindowing",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermWindowing",
            targets: ["CotermWindowing"]
        ),
    ],
    targets: [
        .target(
            name: "CotermWindowing",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermWindowingTests",
            dependencies: ["CotermWindowing"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
