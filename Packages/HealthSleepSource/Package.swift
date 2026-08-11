// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HealthSleepSource",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "HealthSleepSource", targets: ["HealthSleepSource"])
    ],
    dependencies: [
        .package(path: "../SleepDebtCore")
    ],
    targets: [
        .target(name: "HealthSleepSource", dependencies: ["SleepDebtCore"]),
        .testTarget(name: "HealthSleepSourceTests", dependencies: ["HealthSleepSource"])
    ]
)
