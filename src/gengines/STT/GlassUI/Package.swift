// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlassUI",
    platforms: [
        .macOS(.v13) // Required for Grid components
    ],
    products: [
        .library(
            name: "GlassUI",
            targets: ["GlassUI"]
        ),
        .executable(
            name: "ZeusVLAGlass",
            targets: ["ZeusVLAGlass"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "GlassUI",
            dependencies: []
        ),
        .executableTarget(
            name: "ZeusVLAGlass",
            dependencies: ["GlassUI"]
        ),
        .testTarget(
            name: "GlassUITests",
            dependencies: ["GlassUI"]
        )
    ]
)