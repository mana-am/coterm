// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermAgentChatUI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermAgentChatUI",
            targets: ["CotermAgentChatUI"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermAgentChat"),
        .package(path: "../CotermMobileSupport"),
    ],
    targets: [
        .target(
            name: "CotermAgentChatUI",
            dependencies: [
                "CotermAgentChat",
                "CotermMobileSupport",
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CotermAgentChatUITests",
            dependencies: ["CotermAgentChatUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
