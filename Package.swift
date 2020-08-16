// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AudioBookFetcher",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "abookfetcher", targets: ["abookfetcher"]),
        .library(
            name: "AudioBookFetcher",
            targets: ["AudioBookFetcher"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.2.2"),
    ],
    targets: [
        .target(
            name: "abookfetcher",
            dependencies: ["AudioBookFetcher", "AKniga", .product(name: "ArgumentParser", package: "swift-argument-parser")]
        ),
        .target(
            name: "AudioBookFetcher",
            dependencies: []
        ),
        .target(
            name: "AKniga",
            dependencies: ["SwiftSoup"]
        ),
        .testTarget(
            name: "AudioBookFetcherTests",
            dependencies: ["AudioBookFetcher"]
        ),
        .testTarget(
            name: "AKnigaTests",
            dependencies: ["AKniga", "AudioBookFetcher"],
            resources: [Resource.copy("Resources")]
        ),
    ]
)
