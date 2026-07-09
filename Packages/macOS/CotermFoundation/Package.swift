// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermFoundation",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermFoundation",
            targets: ["CotermFoundation"]
        ),
    ],
    targets: [
        .target(
            name: "CotermFoundation",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermFoundationTests",
            dependencies: ["CotermFoundation"]
        ),
    ]
)
