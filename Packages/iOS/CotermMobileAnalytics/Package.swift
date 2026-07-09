// swift-tools-version: 6.0

import PackageDescription

// `CotermMobileAnalytics` is the concrete analytics infrastructure: the
// fire-and-forget `AnalyticsEmitter` actor, the pure sessionization and
// connection-edge throttle logic, and the HTTP capture client that posts batches
// to the coterm web analytics proxy. It conforms to the `AnalyticsEmitting` seam
// declared in `CotermMobileCore`, so it depends only on that base package and
// Foundation — keeping the package graph an acyclic DAG. Everything it touches
// (the opt-out gate, the clock, `UserDefaults`, reachability, the base URL) is
// injected at construction so the actor is testable without the app.
let package = Package(
    name: "CotermMobileAnalytics",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CotermMobileAnalytics",
            targets: ["CotermMobileAnalytics"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/CotermMobileCore"),
    ],
    targets: [
        .target(
            name: "CotermMobileAnalytics",
            dependencies: [
                "CotermMobileCore",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CotermMobileAnalyticsTests",
            dependencies: ["CotermMobileAnalytics"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
