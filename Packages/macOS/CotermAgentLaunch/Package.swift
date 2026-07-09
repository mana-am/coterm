// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CotermAgentLaunch",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermAgentLaunch",
            targets: ["CotermAgentLaunch"]
        ),
    ],
    targets: [
        .target(
            name: "CotermAgentLaunch"
        ),
        .testTarget(
            name: "CotermAgentLaunchTests",
            dependencies: ["CotermAgentLaunch"]
        ),
    ]
)
