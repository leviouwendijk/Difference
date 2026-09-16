// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Difference",
    products: [
        .library(
            name: "Difference",
            targets: [
                "Difference",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Excerpt.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "Difference",
            dependencies: [
                .product(
                    name: "ExcerptPresentation",
                    package: "Excerpt"
                ),
            ]
        ),
        .executableTarget(
            name: "DifferenceTests",
            dependencies: [
                "Difference",
            ]
        ),
    ]
)
