// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermWorkspaces",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermWorkspaces",
            targets: ["CotermWorkspaces"]
        ),
    ],
    dependencies: [
        // WorkspaceGroupNewPlacement (the typed setting value for new
        // in-group workspace placement) is owned by CotermSettings.
        .package(path: "../CotermSettings"),
        // Bonsplit drives the Window/ tmux pane-overlay geometry.
        .package(path: "../../../vendor/bonsplit"),
        // CotermDebugLog backs the Session/ snapshot-restore logging.
        .package(path: "../CotermDebugLog"),
        // CotermTestSupport backs FileOpen/ PreferredEditorService UI-test capture.
        .package(path: "../CotermTestSupport"),
    ],
    targets: [
        .target(
            name: "CotermWorkspaces",
            dependencies: [
                .product(name: "CotermSettings", package: "CotermSettings"),
                .product(name: "Bonsplit", package: "bonsplit"),
                .product(name: "CotermDebugLog", package: "CotermDebugLog"),
                .product(name: "CotermTestSupport", package: "CotermTestSupport"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermWorkspacesTests",
            dependencies: [
                "CotermWorkspaces",
                .product(name: "Bonsplit", package: "bonsplit"),
                .product(name: "CotermTestSupport", package: "CotermTestSupport"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
