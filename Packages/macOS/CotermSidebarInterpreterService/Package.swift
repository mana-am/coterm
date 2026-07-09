// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CotermSidebarInterpreterService",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Host-side client + wire protocol the app links against.
        .library(
            name: "CotermSidebarInterpreterClient",
            targets: ["CotermSidebarInterpreterClient"]
        ),
        // The out-of-process worker that runs the untrusted interpreter.
        .executable(
            name: "coterm-sidebar-interpreter",
            targets: ["coterm-sidebar-interpreter"]
        ),
        // Headless protocol fixture for RenderWorkerClient supervision tests.
        .executable(
            name: "coterm-sidebar-render-fixture",
            targets: ["coterm-sidebar-render-fixture"]
        ),
        // Remote rendering: the faceless render-worker loop and the host-side
        // layer-hosting sidebar surface.
        .library(
            name: "CotermSidebarRemoteRender",
            targets: ["CotermSidebarRemoteRender"]
        ),
    ],
    dependencies: [
        .package(path: "../CotermSwiftRender"),
        .package(path: "../CotermSwiftRenderUI"),
    ],
    targets: [
        .target(
            name: "CotermSidebarInterpreterClient",
            dependencies: ["CotermSwiftRender"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "coterm-sidebar-interpreter",
            dependencies: ["CotermSidebarInterpreterClient"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "coterm-sidebar-render-fixture",
            dependencies: ["CotermSidebarInterpreterClient"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "CotermSidebarRemoteRender",
            dependencies: [
                "CotermSidebarInterpreterClient",
                .product(name: "CotermSwiftRenderUI", package: "CotermSwiftRenderUI"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "CotermSidebarInterpreterClientTests",
            dependencies: ["CotermSidebarInterpreterClient"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "CotermSidebarRemoteRenderTests",
            dependencies: ["CotermSidebarRemoteRender"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
