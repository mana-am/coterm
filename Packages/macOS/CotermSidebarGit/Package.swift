// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermSidebarGit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermSidebarGit",
            targets: ["CotermSidebarGit"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermGit"),
        .package(path: "../CotermFoundation"),
    ],
    targets: [
        .target(
            name: "CotermSidebarGit",
            dependencies: [
                .product(name: "CotermGit", package: "CotermGit"),
                .product(name: "CotermFoundation", package: "CotermFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermSidebarGitTests",
            dependencies: [
                "CotermSidebarGit",
                .product(name: "CotermGit", package: "CotermGit"),
                .product(name: "CotermFoundation", package: "CotermFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
