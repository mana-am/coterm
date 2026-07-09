// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermCollaboration",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermCollaboration",
            targets: ["CotermCollaboration"]
        ),
    ],
    targets: [
        .target(
            name: "CotermCollaboration",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermCollaborationTests",
            dependencies: ["CotermCollaboration"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
