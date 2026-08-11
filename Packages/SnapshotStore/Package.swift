// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SnapshotStore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "SnapshotStore", targets: ["SnapshotStore"])
    ],
    dependencies: [
        .package(path: "../SleepDebtCore")
    ],
    targets: [
        .target(name: "SnapshotStore", dependencies: ["SleepDebtCore"]),
        .testTarget(name: "SnapshotStoreTests", dependencies: ["SnapshotStore"])
    ]
)
