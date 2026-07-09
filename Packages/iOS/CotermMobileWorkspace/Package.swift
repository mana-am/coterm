// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileWorkspace",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileWorkspace",
            targets: ["CotermMobileWorkspace"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
        .package(path: "../CotermMobileShellModel"),
    ],
    targets: [
        .target(
            name: "CotermMobileWorkspace",
            dependencies: [
                "CotermMobileCore",
                "CotermMobileShellModel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileWorkspaceTests",
            dependencies: ["CotermMobileWorkspace"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
