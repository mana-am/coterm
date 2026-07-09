// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CotermSidebarProviderKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermSidebarProviderKit",
            targets: ["CotermSidebarProviderKit"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
    ],
    targets: [
        .target(
            name: "CotermSidebarProviderKit",
            dependencies: ["CotermFoundation"]
        ),
    ]
)
