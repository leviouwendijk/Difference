// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DifferenceTests",
    products: [
        .executable(name: "t_graph_difference", targets: ["DifferenceGraphLayoutTests"]),

        .executable(
            name: "t_diff",
            targets: [
                "DifferenceTests",
            ]
        ),
        .executable(name: "t_diff_inline", targets: ["DifferenceInlineTests"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-lco/Primitives.git",
            branch: "master"
        ),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "DifferenceGraphLayoutTests",
            dependencies: [.product(name: "Difference", package: "Difference"), .product(name: "Primitives", package: "Primitives")]
        ),

        .executableTarget(
            name: "DifferenceInlineTests",
            dependencies: [.product(name: "Difference", package: "Difference")]
        ),
        .executableTarget(
            name: "DifferenceTests",
            dependencies: [
                .product(name: "Difference", package: "Difference"),
                .product(name: "Primitives", package: "Primitives"),
            ]
        ),
    ]
)
