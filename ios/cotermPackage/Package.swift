// swift-tools-version: 6.0

import PackageDescription

// `cotermFeature` is the iOS composition-root package, not a catch-all. After the
// 5079 refactor it holds only the runtime DI bundle (`CotermMobileRuntime`), the
// auth composition (`MobileAuthComposition` over `CotermAuthRuntime`), and the
// root scene (`CotermMobileRootScene`). The store, RPC, persistence, terminal,
// and view code were lifted into the focused packages it depends on below. See
// README.md for the per-type role table.
let package = Package(
    name: "cotermFeature",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "cotermFeature",
            targets: ["cotermFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/Shared/CotermAuthCore"),
        .package(path: "../../Packages/Shared/CotermAuthRuntime"),
        .package(path: "../../Packages/Shared/CotermMobileCore"),
        .package(path: "../../Packages/iOS/CotermMobileAnalytics"),
        .package(path: "../../Packages/iOS/CotermMobileBrowser"),
        .package(path: "../../Packages/iOS/CotermMobileCamera"),
        .package(path: "../../Packages/iOS/CotermMobileDiagnostics"),
        .package(path: "../../Packages/iOS/CotermMobilePairedMac"),
        .package(path: "../../Packages/iOS/CotermMobileRPC"),
        .package(path: "../../Packages/iOS/CotermMobileShell"),
        .package(path: "../../Packages/iOS/CotermMobileShellModel"),
        .package(path: "../../Packages/iOS/CotermMobileShellUI"),
        .package(path: "../../Packages/iOS/CotermMobileSupport"),
        .package(path: "../../Packages/iOS/CotermMobileTerminal"),
        .package(path: "../../Packages/iOS/CotermMobileTerminalKit"),
        .package(path: "../../Packages/iOS/CotermMobileTransport"),
        .package(path: "../../Packages/iOS/CotermMobileWorkspace"),
        .package(path: "../../vendor/stack-auth-swift-sdk-prerelease"),
    ],
    targets: [
        .target(
            name: "cotermFeature",
            dependencies: [
                "CotermAuthCore",
                "CotermAuthRuntime",
                "CotermMobileCore",
                "CotermMobileAnalytics",
                "CotermMobileBrowser",
                "CotermMobileCamera",
                "CotermMobileDiagnostics",
                "CotermMobilePairedMac",
                "CotermMobileRPC",
                "CotermMobileShell",
                "CotermMobileShellModel",
                "CotermMobileShellUI",
                "CotermMobileSupport",
                "CotermMobileTerminal",
                "CotermMobileTerminalKit",
                "CotermMobileTransport",
                "CotermMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("COTERM_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "cotermFeatureTests",
            dependencies: [
                "cotermFeature",
                "CotermAuthCore",
                "CotermAuthRuntime",
                "CotermMobileCore",
                "CotermMobileAnalytics",
                "CotermMobileBrowser",
                "CotermMobileCamera",
                "CotermMobileDiagnostics",
                "CotermMobilePairedMac",
                "CotermMobileRPC",
                "CotermMobileShell",
                "CotermMobileShellModel",
                "CotermMobileShellUI",
                "CotermMobileSupport",
                "CotermMobileTerminal",
                "CotermMobileTerminalKit",
                "CotermMobileTransport",
                "CotermMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("COTERM_DEV_AUTH", .when(configuration: .debug)),
            ]
        ),
    ]
)
