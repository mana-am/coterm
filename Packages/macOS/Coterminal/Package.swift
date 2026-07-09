// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Coterminal",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Coterminal",
            targets: ["Coterminal"]
        ),
    ],
    dependencies: [
        .package(path: "../CoterminalCore"),
        .package(path: "../CotermDebugLog"),
        .package(path: "../CotermAgentLaunch"),
        .package(path: "../../Shared/CotermMobileCore"),
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "Coterminal",
            dependencies: [
                .product(name: "CoterminalCore", package: "CoterminalCore"),
                .product(name: "CotermGhosttyKit", package: "CoterminalCore"),
                .product(name: "CotermDebugLog", package: "CotermDebugLog"),
                .product(name: "CotermAgentLaunch", package: "CotermAgentLaunch"),
                .product(name: "CotermMobileCore", package: "CotermMobileCore"),
                .product(name: "Bonsplit", package: "bonsplit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // Test-only stand-in for the @_silgen_name libghostty symbol bound by
        // CoterminalCore's GhosttyRuntimeCInterop: SwiftPM cannot link the
        // GhosttyKit macOS archive (its binary lacks the lib prefix), so the
        // test runner satisfies the link with a stub. The app links the real
        // GhosttyKit.
        .target(
            name: "GhosttyRuntimeTestStubs",
            path: "Tests/GhosttyRuntimeTestStubs"
        ),
        .testTarget(
            name: "CoterminalTests",
            dependencies: [
                "Coterminal",
                "GhosttyRuntimeTestStubs",
                .product(name: "CoterminalCore", package: "CoterminalCore"),
                .product(name: "CotermGhosttyKit", package: "CoterminalCore"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
