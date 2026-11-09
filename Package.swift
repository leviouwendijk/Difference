// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Difference",
    products: [
        .executable(name: "t_graph_difference", targets: ["DifferenceGraphLayoutTests"]),
        .library(
            name: "Difference",
            targets: [
                "Difference",
            ]
        ),

        .executable(
            name: "t_diff",
            targets: [
                "DifferenceTests",
            ]
        ),
        .executable(name: "t_diff_inline", targets: ["DifferenceInlineTests"]),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Excerpt.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Schema.git",
            branch: "master"
        ),
    ],
    targets: [
        .executableTarget(
            name: "DifferenceGraphLayoutTests",
            dependencies: ["Difference", .product(name: "Primitives", package: "Primitives")],
            path: "Testing/DifferenceGraphLayoutTests"
        ),
        .target(
            name: "Difference",
            dependencies: [
                .product(name: "Position", package: "Position"),
                .product(name: "Primitives", package: "Primitives"),
                .product(
                    name: "ExcerptPresentation",
                    package: "Excerpt"
                ),
                .product(
                    name: "Schema",
                    package: "Schema"
                ),
            ]
        ),

        .executableTarget(
            name: "DifferenceInlineTests",
            dependencies: ["Difference"],
            path: "Testing/DifferenceInlineTests"
        ),
        .executableTarget(
            name: "DifferenceTests",
            dependencies: [
                "Difference",
                .product(name: "Primitives", package: "Primitives"),
            ],
            path: "Testing/DifferenceTests"
        ),
    ]
)
