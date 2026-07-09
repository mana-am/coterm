// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermAppKitSupportUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermAppKitSupportUI",
            targets: ["CotermAppKitSupportUI"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
        .package(path: "../CotermWorkspaces"),
    ],
    targets: [
        .target(
            name: "CotermAppKitSupportUI",
            dependencies: [
                "CotermFoundation",
                "CotermWorkspaces",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermAppKitSupportUITests",
            dependencies: ["CotermAppKitSupportUI"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
