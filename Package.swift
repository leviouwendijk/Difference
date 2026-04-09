// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Difference",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "Difference",
            targets: ["Difference"]
        ),
        .library(
            name: "DifferenceTerminal",
            targets: ["DifferenceTerminal"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Terminal", branch: "master"),
    ],
    targets: [
        .target(
            name: "Difference"
        ),
        .target(
            name: "DifferenceTerminal",
            dependencies: [
                "Difference",
                .product(name: "Terminal", package: "Terminal"),
            ]
        ),
        .testTarget(
            name: "DifferenceTests",
            dependencies: ["Difference"]
        ),
    ]
)
