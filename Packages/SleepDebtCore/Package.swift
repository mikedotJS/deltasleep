// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SleepDebtCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SleepDebtCore", targets: ["SleepDebtCore"]),
    ],
    targets: [
        .target(name: "SleepDebtCore"),
        .testTarget(name: "SleepDebtCoreTests", dependencies: ["SleepDebtCore"]),
    ]
)
