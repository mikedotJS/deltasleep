// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HealthSleepSource",
    // .macOS(.v14) matches SleepDebtCore's platform floor — `swift test`
    // builds for the macOS host, so anything depending on SleepDebtCore
    // must declare a macOS minimum at least as high or SwiftPM refuses
    // to resolve the graph.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HealthSleepSource", targets: ["HealthSleepSource"]),
    ],
    dependencies: [
        .package(path: "../SleepDebtCore"),
    ],
    targets: [
        .target(name: "HealthSleepSource", dependencies: ["SleepDebtCore"]),
        .testTarget(name: "HealthSleepSourceTests", dependencies: ["HealthSleepSource"]),
    ]
)
