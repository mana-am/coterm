// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileTerminal",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "CotermMobileTerminal",
            targets: ["CotermMobileTerminal"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
        .package(path: "../CotermMobileDiagnostics"),
        .package(path: "../CotermMobileSupport"),
        .package(path: "../CotermMobileTerminalKit"),
    ],
    targets: [
        // The same libghostty the Mac links; iOS feeds raw PTY bytes straight
        // into ghostty_surface_* so the phone runs the identical terminal core.
        .binaryTarget(
            name: "GhosttyKit",
            path: "../../../GhosttyKit.xcframework"
        ),
        .target(
            name: "CotermMobileTerminal",
            dependencies: [
                "CotermMobileCore",
                "CotermMobileDiagnostics",
                "CotermMobileSupport",
                "CotermMobileTerminalKit",
                "GhosttyKit",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
