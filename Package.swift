// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Ejective",
    products: [
        .library(
            name: "Ejective",
            targets: ["Ejective"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Ejective",
            dependencies: []),
        .testTarget(
            name: "EjectiveTests",
            dependencies: ["Ejective"]),
    ]
)
