// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BenchGraph",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "BenchGraphKit", targets: ["BenchGraphKit"]),
        .executable(name: "benchgraph", targets: ["benchgraph"]),
        .executable(name: "BenchGraphApp", targets: ["BenchGraphApp"])
    ],
    targets: [
        .target(
            name: "BenchGraphKit"
        ),
        .executableTarget(
            name: "benchgraph",
            dependencies: ["BenchGraphKit"]
        ),
        .executableTarget(
            name: "BenchGraphApp",
            dependencies: ["BenchGraphKit"]
        ),
        .testTarget(
            name: "BenchGraphKitTests",
            dependencies: ["BenchGraphKit"]
        )
    ]
)
