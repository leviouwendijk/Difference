// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Difference",
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
        .package(url: "https://github.com/leviouwendijk/ANSI", branch: "master"),
    ],
    targets: [
        .target(
            name: "Difference"
        ),
        .target(
            name: "DifferenceTerminal",
            dependencies: [
                "Difference",
                .product(name: "ANSI", package: "ANSI"),
            ]
        ),
        .testTarget(
            name: "DifferenceTests",
            dependencies: ["Difference"]
        ),
    ]
)
