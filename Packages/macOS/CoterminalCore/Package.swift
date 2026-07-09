// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoterminalCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CoterminalCore",
            targets: ["CoterminalCore"]
        ),
        // Re-vends the GhosttyKit binaryTarget so the Coterminal runtime
        // package can implement seam protocols whose signatures use ghostty C
        // types, without declaring a duplicate binary target for the one
        // xcframework.
        .library(
            name: "CotermGhosttyKit",
            targets: ["GhosttyKit"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
        .package(path: "../CotermDebugLog"),
    ],
    targets: [
        // The same libghostty the app links; the terminal core's value types and
        // FFI seam speak the ghostty C types directly so no translation layer
        // can drift from the runtime.
        .binaryTarget(
            name: "GhosttyKit",
            path: "../../../GhosttyKit.xcframework"
        ),
        .target(
            name: "CoterminalCore",
            dependencies: [
                "GhosttyKit",
                .product(name: "CotermFoundation", package: "CotermFoundation"),
                .product(name: "CotermDebugLog", package: "CotermDebugLog"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // Test-only stand-in for the @_silgen_name libghostty symbol bound by
        // GhosttyRuntimeCInterop: SwiftPM cannot link the GhosttyKit macOS
        // archive (its binary lacks the lib prefix), so the test runner
        // satisfies the link with a stub. The app links the real GhosttyKit.
        .target(
            name: "GhosttyRuntimeTestStubs",
            path: "Tests/GhosttyRuntimeTestStubs"
        ),
        .testTarget(
            name: "CoterminalCoreTests",
            dependencies: [
                "CoterminalCore",
                "GhosttyRuntimeTestStubs",
                .product(name: "CotermFoundation", package: "CotermFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
