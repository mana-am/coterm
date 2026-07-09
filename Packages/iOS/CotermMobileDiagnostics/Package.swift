// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileDiagnostics",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileDiagnostics",
            targets: ["CotermMobileDiagnostics"]
        ),
    ],
    targets: [
        .target(
            name: "CotermMobileDiagnostics",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileDiagnosticsTests",
            dependencies: ["CotermMobileDiagnostics"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
