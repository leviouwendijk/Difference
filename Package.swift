// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Difference",
    products: [
        // SwiftUI views for difference plans; Apple platforms only.
        .library(
            name: "DifferenceSwiftUI",
            targets: [
                "DifferenceSwiftUI",
            ]
        ),
        .library(
            name: "Difference",
            targets: [
                "Difference",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-lco/Position.git", branch: "master"),
        .package(
            url: "https://github.com/swift-lco/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swift-lco/Excerpt.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/swift-lco/Schema.git",
            branch: "master"
        ),
    ],
    targets: [
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
        .target(
            name: "DifferenceSwiftUI",
            dependencies: [
                "Difference",
            ]
        ),
    ]
)

for target in package.targets {
    switch target.type {
    case .regular, .executable, .test, .macro:
        var settings = target.swiftSettings ?? []

        settings.append(
            .treatAllWarnings(as: .error)
        )

        settings.append(
            .unsafeFlags(
                [
                    "-continue-building-after-errors"
                ]
            )
        )

        target.swiftSettings = settings

    case .plugin, .system, .binary:
        break

    @unknown default:
        break
    }
}
