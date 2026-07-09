// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermAuthRuntime",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermAuthRuntime",
            targets: ["CotermAuthRuntime"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermAuthCore"),
        .package(path: "../../../vendor/stack-auth-swift-sdk-prerelease"),
    ],
    targets: [
        .target(
            name: "CotermAuthRuntime",
            dependencies: [
                "CotermAuthCore",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("COTERM_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermAuthRuntimeTests",
            dependencies: ["CotermAuthRuntime"],
            swiftSettings: [
                .define("COTERM_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
