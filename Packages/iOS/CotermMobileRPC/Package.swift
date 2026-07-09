// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileRPC",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileRPC",
            targets: ["CotermMobileRPC"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
        .package(path: "../CotermMobileShellModel"),
        .package(path: "../CotermMobileSupport"),
    ],
    targets: [
        .target(
            name: "CotermMobileRPC",
            dependencies: [
                "CotermMobileCore",
                "CotermMobileShellModel",
                "CotermMobileSupport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileRPCTests",
            dependencies: [
                "CotermMobileRPC",
                "CotermMobileCore",
                "CotermMobileShellModel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
