// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CotermProjectModel",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermProjectModel",
            targets: ["CotermProjectModel"]
        ),
        .executable(
            name: "coterm-project-dump",
            targets: ["CotermProjectDump"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/tuist/XcodeProj.git",
            from: "9.0.0"
        ),
    ],
    targets: [
        .target(
            name: "CotermProjectModel",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
            ]
        ),
        .executableTarget(
            name: "CotermProjectDump",
            dependencies: ["CotermProjectModel"]
        ),
        .testTarget(
            name: "CotermProjectModelTests",
            dependencies: ["CotermProjectModel"]
        ),
    ]
)
