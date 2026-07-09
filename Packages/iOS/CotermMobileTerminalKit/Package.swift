// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileTerminalKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileTerminalKit",
            targets: ["CotermMobileTerminalKit"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
    ],
    targets: [
        .target(
            name: "CotermMobileTerminalKit",
            dependencies: [
                "CotermMobileCore",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileTerminalKitTests",
            dependencies: ["CotermMobileTerminalKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
