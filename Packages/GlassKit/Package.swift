// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "GlassKit",
    // .macOS(.v14) so `swift test` (which builds for the macOS host) can
    // resolve modern SwiftUI APIs this package uses (Canvas, RadialGradient,
    // the #Preview macro) — an undeclared platform falls back to a much
    // older default deployment target under this tools version, which
    // would fail to compile them. Same reasoning as HealthSleepSource's
    // and SnapshotStore's Package.swift.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GlassKit", targets: ["GlassKit"]),
    ],
    targets: [
        .target(name: "GlassKit"),
        .testTarget(name: "GlassKitTests", dependencies: ["GlassKit"]),
    ]
)
