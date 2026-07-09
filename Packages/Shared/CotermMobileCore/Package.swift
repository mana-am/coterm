// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileCore",
            targets: ["CotermMobileCore"]
        ),
    ],
    targets: [
        .target(
            name: "CotermMobileCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CotermMobileCoreTests",
            dependencies: ["CotermMobileCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
