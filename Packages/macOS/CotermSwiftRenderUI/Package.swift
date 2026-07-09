// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermSwiftRenderUI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermSwiftRenderUI",
            targets: ["CotermSwiftRenderUI"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermSwiftRender"),
        .package(path: "../CotermSettings"),
        .package(path: "../CotermFoundation"),
    ],
    targets: [
        .target(
            name: "CotermSwiftRenderUI",
            dependencies: [
                .product(name: "CotermSwiftRender", package: "CotermSwiftRender"),
                .product(name: "CotermSettings", package: "CotermSettings"),
                .product(name: "CotermFoundation", package: "CotermFoundation"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "CotermSwiftRenderUITests",
            dependencies: ["CotermSwiftRenderUI"]
        ),
    ]
)
