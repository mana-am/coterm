// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermSyncStore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermSyncStore",
            targets: ["CotermSyncStore"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermMobileCore"),
        .package(path: "../../iOS/CotermMobilePairedMac"),
        .package(path: "../../iOS/CotermMobileShellModel"),
    ],
    targets: [
        .target(
            name: "CotermSyncStore",
            dependencies: [
                "CotermMobileCore",
                "CotermMobilePairedMac",
                "CotermMobileShellModel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermSyncStoreTests",
            dependencies: ["CotermSyncStore", "CotermMobilePairedMac", "CotermMobileCore", "CotermMobileShellModel"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
