// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermExtensionSidebarExamples",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "CotermExtensionSidebarExamples",
            targets: ["CotermExtensionSidebarExamples"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/macOS/CotermSidebarProviderKit"),
    ],
    targets: [
        .target(
            name: "CotermExtensionSidebarExamples",
            dependencies: ["CotermSidebarProviderKit"]
        ),
        .testTarget(
            name: "CotermExtensionSidebarExamplesTests",
            dependencies: ["CotermExtensionSidebarExamples"]
        ),
    ]
)
