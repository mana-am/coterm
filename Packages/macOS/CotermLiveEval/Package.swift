// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermLiveEval",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermLiveEval",
            targets: ["CotermLiveEval"]
        ),
        .executable(
            name: "LiveEvalDemo",
            targets: ["LiveEvalDemo"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermSwiftRender"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .target(
            name: "CotermLiveEval",
            dependencies: [
                .product(name: "CotermSwiftRender", package: "CotermSwiftRender"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "LiveEvalDemo",
            dependencies: ["CotermLiveEval"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "CotermLiveEvalTests",
            dependencies: ["CotermLiveEval"]
        ),
    ]
)
