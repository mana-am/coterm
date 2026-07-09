// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileShellModel",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileShellModel",
            targets: ["CotermMobileShellModel"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
    ],
    targets: [
        .target(
            name: "CotermMobileShellModel",
            dependencies: [
                "CotermMobileCore",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileShellModelTests",
            dependencies: ["CotermMobileShellModel"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
