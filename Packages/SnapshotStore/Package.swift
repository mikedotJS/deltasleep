// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SnapshotStore",
    // .macOS(.v14) matches SleepDebtCore's platform floor — see the same
    // note in Packages/HealthSleepSource/Package.swift.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SnapshotStore", targets: ["SnapshotStore"]),
    ],
    dependencies: [
        .package(path: "../SleepDebtCore"),
        .package(path: "../HealthSleepSource"),
    ],
    targets: [
        .target(name: "SnapshotStore", dependencies: ["SleepDebtCore", "HealthSleepSource"]),
        .testTarget(name: "SnapshotStoreTests", dependencies: ["SnapshotStore"]),
    ]
)
