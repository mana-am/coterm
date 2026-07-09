// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileShellUI",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "CotermMobileShellUI",
            targets: ["CotermMobileShellUI"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
        .package(path: "../../Shared/CotermAgentChat"),
        .package(path: "../CotermAgentChatUI"),
        .package(path: "../../Shared/CotermAuthRuntime"),
        .package(path: "../CotermMobileBrowser"),
        .package(path: "../CotermMobileCamera"),
        .package(path: "../CotermMobileDiagnostics"),
        .package(path: "../CotermMobilePairedMac"),
        .package(path: "../CotermMobileShell"),
        .package(path: "../CotermMobileShellModel"),
        .package(path: "../CotermMobileSupport"),
        .package(path: "../CotermMobileTerminal"),
        .package(path: "../CotermMobileTerminalKit"),
        .package(path: "../CotermMobileWorkspace"),
        .package(path: "../../../vendor/stack-auth-swift-sdk-prerelease"),
    ],
    targets: [
        .target(
            name: "CotermMobileShellUI",
            dependencies: [
                "CotermMobileCore",
                "CotermAgentChat",
                "CotermAgentChatUI",
                "CotermAuthRuntime",
                "CotermMobileBrowser",
                "CotermMobileCamera",
                "CotermMobileDiagnostics",
                "CotermMobilePairedMac",
                "CotermMobileShell",
                "CotermMobileShellModel",
                "CotermMobileSupport",
                "CotermMobileTerminal",
                "CotermMobileTerminalKit",
                "CotermMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("COTERM_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "CotermMobileShellUITests",
            dependencies: [
                "CotermMobileCore",
                "CotermMobilePairedMac",
                "CotermMobileShellUI",
                "CotermAgentChat",
                "CotermMobileShell",
                "CotermMobileShellModel",
                "CotermMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("COTERM_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
