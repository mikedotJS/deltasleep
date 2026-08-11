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
    ],
    targets: [
        .target(name: "SnapshotStore", dependencies: ["SleepDebtCore"]),
        .testTarget(name: "SnapshotStoreTests", dependencies: ["SnapshotStore"]),
    ]
)
