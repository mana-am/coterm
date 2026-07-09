// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CotermAuthCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermAuthCore",
            targets: ["CotermAuthCore"]
        ),
    ],
    targets: [
        .target(
            name: "CotermAuthCore"
        ),
        .testTarget(
            name: "CotermAuthCoreTests",
            dependencies: ["CotermAuthCore"]
        ),
    ]
)
