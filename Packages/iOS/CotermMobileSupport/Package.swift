// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileSupport",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileSupport",
            targets: ["CotermMobileSupport"]
        ),
    ],
    targets: [
        .target(
            name: "CotermMobileSupport",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileSupportTests",
            dependencies: ["CotermMobileSupport"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
