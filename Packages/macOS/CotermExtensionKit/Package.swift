// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CotermExtensionKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermExtensionKit",
            targets: ["CotermExtensionKit"]
        ),
    ],
    targets: [
        .target(
            name: "CotermExtensionKit"
        ),
        .testTarget(
            name: "CotermExtensionKitTests",
            dependencies: ["CotermExtensionKit"]
        ),
    ]
)
