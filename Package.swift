// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BlinkNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BlinkNotchCore"),
        .executableTarget(name: "BlinkNotch", dependencies: ["BlinkNotchCore"]),
        .testTarget(name: "BlinkNotchCoreTests", dependencies: ["BlinkNotchCore"]),
    ],
    swiftLanguageModes: [.v5]
)
