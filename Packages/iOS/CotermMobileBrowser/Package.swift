// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermMobileBrowser",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileBrowser",
            targets: ["CotermMobileBrowser"]
        ),
    ],
    dependencies: [
        // Localized-string helpers (`L10n`). `CotermMobileSupport` is a leaf with
        // no dependencies, so the browser package stays low in the DAG.
        .package(path: "../CotermMobileSupport"),
    ],
    targets: [
        // A self-contained, phone-local browser surface. P1 browser state never
        // touches the Mac, so this package sits low in the DAG: it depends only
        // on the leaf `CotermMobileSupport` and links Foundation/WebKit/SwiftUI.
        .target(
            name: "CotermMobileBrowser",
            dependencies: [
                "CotermMobileSupport",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileBrowserTests",
            dependencies: ["CotermMobileBrowser"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
