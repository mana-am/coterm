// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermFeedback",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermFeedback",
            targets: ["CotermFeedback"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermFoundation"),
    ],
    targets: [
        .target(
            name: "CotermFeedback",
            dependencies: [
                "CotermFoundation",
            ],
            resources: [
                // Folded from CotermFeedbackUI: the composer's localized strings.
                .process("ComposerUI/Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermFeedbackTests",
            dependencies: ["CotermFeedback"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
