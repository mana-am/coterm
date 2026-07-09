// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermBrowser",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermBrowser",
            targets: ["CotermBrowser"]
        ),
    ],
    dependencies: [
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "CotermBrowser",
            dependencies: [
                .product(name: "Bonsplit", package: "bonsplit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermBrowserTests",
            dependencies: ["CotermBrowser"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
