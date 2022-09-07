// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Jack",
    products: [
        .library(
            name: "Jack",
            targets: ["Jack"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jectivex/JXKit.git", branch: "HEAD"),
        .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.13.0"),
    ],
    targets: [
        .target(
            name: "Jack",
            dependencies: [
                .product(name: "JXKit", package: "JXKit"),
                .product(name: "OpenCombineShim", package: "OpenCombine"),
            ],
            resources: [.process("Resources")]),
        .testTarget(
            name: "JackTests",
            dependencies: ["Jack"],
            resources: [.copy("TestResources")]),
    ]
)
