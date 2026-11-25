// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Priorities",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Priorities", targets: ["PrioritiesApp"])],
    targets: [
        .target(name: "PrioritiesCore"),
        .executableTarget(name: "PrioritiesApp", dependencies: ["PrioritiesCore"]),
        .testTarget(name: "PrioritiesCoreTests", dependencies: ["PrioritiesCore"])
    ]
)
