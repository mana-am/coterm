// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermNotifications",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermNotifications",
            targets: ["CotermNotifications"]
        ),
    ],
    targets: [
        .target(
            name: "CotermNotifications",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermNotificationsTests",
            dependencies: ["CotermNotifications"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
