// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileShell",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileShell",
            targets: ["CotermMobileShell"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
        .package(path: "../../Shared/CotermAgentChat"),
        .package(path: "../CotermMobileDiagnostics"),
        .package(path: "../CotermMobilePairedMac"),
        .package(path: "../CotermMobileRPC"),
        .package(path: "../CotermMobileShellModel"),
        .package(path: "../CotermMobileSupport"),
        .package(path: "../CotermMobileTransport"),
    ],
    targets: [
        .target(
            name: "CotermMobileShell",
            dependencies: [
                "CotermMobileCore",
                "CotermAgentChat",
                "CotermMobileDiagnostics",
                "CotermMobilePairedMac",
                "CotermMobileRPC",
                "CotermMobileShellModel",
                "CotermMobileSupport",
                "CotermMobileTransport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileShellTests",
            dependencies: [
                "CotermMobileShell",
                "CotermMobileCore",
                "CotermAgentChat",
                "CotermMobilePairedMac",
                "CotermMobileRPC",
                "CotermMobileShellModel",
                "CotermMobileTransport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
