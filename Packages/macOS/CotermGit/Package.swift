// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermGit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermGit",
            targets: ["CotermGit"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
    ],
    targets: [
        .target(
            name: "CotermGit",
            dependencies: [
                .product(name: "CotermFoundation", package: "CotermFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermGitTests",
            dependencies: ["CotermGit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
