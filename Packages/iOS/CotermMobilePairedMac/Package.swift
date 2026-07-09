// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobilePairedMac",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobilePairedMac",
            targets: ["CotermMobilePairedMac"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
    ],
    targets: [
        .target(
            name: "CotermMobilePairedMac",
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
            name: "CotermMobilePairedMacTests",
            dependencies: ["CotermMobilePairedMac"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
