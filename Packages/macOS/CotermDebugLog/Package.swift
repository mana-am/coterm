// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CotermDebugLog",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CotermDebugLog",
            targets: ["CotermDebugLog"]
        ),
    ],
    targets: [
        .target(
            name: "CotermDebugLog",
            path: "Sources/CotermDebugLog"
        ),
        .testTarget(
            name: "CotermDebugLogTests",
            dependencies: ["CotermDebugLog"],
            path: "Tests/CotermDebugLogTests"
        ),
    ]
)
