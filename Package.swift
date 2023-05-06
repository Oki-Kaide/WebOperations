// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebOperations",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "WebOperations",
            targets: ["WebOperations"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "WebOperations",
            dependencies: []),
        .testTarget(
            name: "WebOperationsTests",
            dependencies: ["WebOperations"])
    ]
)
