// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileTransport",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileTransport",
            targets: ["CotermMobileTransport"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
    ],
    targets: [
        .target(
            name: "CotermMobileTransport",
            dependencies: ["CotermMobileCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileTransportTests",
            dependencies: ["CotermMobileTransport", "CotermMobileCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
