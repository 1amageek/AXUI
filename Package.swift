// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AXUI",
    platforms: [.macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AXUI",
            targets: ["AXUI"]),
        .executable(
            name: "axon",
            targets: ["axon"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "AXUI"),
        .executableTarget(
            name: "axon",
            dependencies: [
                "AXUI",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "AXONTests",
            dependencies: [
                "AXUI"
            ]
        ),
    ]
)
