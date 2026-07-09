// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermSidebar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermSidebar",
            targets: ["CotermSidebar"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
        .package(path: "../CotermSwiftRender"),
        // CotermExtensionKit backs the ExtensionHost/ sidebar-extension host view
        // and browser presenter.
        .package(path: "../CotermExtensionKit"),
    ],
    targets: [
        .target(
            name: "CotermSidebar",
            dependencies: [
                .product(name: "CotermFoundation", package: "CotermFoundation"),
                .product(name: "CotermSwiftRender", package: "CotermSwiftRender"),
                .product(name: "CotermExtensionKit", package: "CotermExtensionKit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermSidebarTests",
            dependencies: [
                "CotermSidebar",
                .product(name: "CotermFoundation", package: "CotermFoundation"),
                .product(name: "CotermSwiftRender", package: "CotermSwiftRender"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
