// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "GlassKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GlassKit", targets: ["GlassKit"]),
    ],
    targets: [
        .target(name: "GlassKit"),
        .testTarget(name: "GlassKitTests", dependencies: ["GlassKit"]),
    ]
)
