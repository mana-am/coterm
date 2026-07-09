// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermTestSupport",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermTestSupport",
            targets: ["CotermTestSupport"]
        ),
    ],
    targets: [
        .target(
            name: "CotermTestSupport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermTestSupportTests",
            dependencies: ["CotermTestSupport"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
