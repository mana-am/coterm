// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermControlSocket",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermControlSocket",
            targets: ["CotermControlSocket"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermSettings"),
    ],
    targets: [
        .target(
            name: "CotermControlSocket",
            dependencies: [
                .product(name: "CotermSettings", package: "CotermSettings"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermControlSocketTests",
            dependencies: [
                "CotermControlSocket",
                .product(name: "CotermSettings", package: "CotermSettings"),
            ]
        ),
    ]
)
