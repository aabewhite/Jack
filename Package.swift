// swift-tools-version:5.5
import PackageDescription

#if canImport(Combine)
let hasCombine = true
#else
let hasCombine = false
#endif

let package = Package(
    name: "Jack",
    platforms: [ .macOS(.v11), .iOS(.v14), .tvOS(.v14) ],
    products: [
        .library(
            name: "Jack",
            targets: ["Jack"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jectivex/JXKit.git", from: "2.0.0"),
        hasCombine ? nil : .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.13.0"),
    ].compactMap({ $0 }),
    targets: [
        .target(
            name: "Jack",
            dependencies: [
                .product(name: "JXKit", package: "JXKit"),
                hasCombine ? nil : .product(name: "OpenCombineShim", package: "OpenCombine"),
            ].compactMap({ $0 }),
            resources: [.process("Resources")]),
        .testTarget(
            name: "JackTests",
            dependencies: ["Jack"],
            resources: [.copy("TestResources")]),
    ]
)
