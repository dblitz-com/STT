// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "STTDictate",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.7.2")
    ],
    targets: [
        .executableTarget(
            name: "STTDictate",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources"
        )
    ]
)