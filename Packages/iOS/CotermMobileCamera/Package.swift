// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileCamera",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileCamera",
            targets: ["CotermMobileCamera"]
        ),
    ],
    targets: [
        .target(
            name: "CotermMobileCamera",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileCameraTests",
            dependencies: ["CotermMobileCamera"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
