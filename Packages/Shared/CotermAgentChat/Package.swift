// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermAgentChat",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermAgentChat",
            targets: ["CotermAgentChat"]
        ),
    ],
    targets: [
        .target(
            name: "CotermAgentChat",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CotermAgentChatTests",
            dependencies: ["CotermAgentChat"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
