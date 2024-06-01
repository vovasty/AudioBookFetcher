// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AudioBookFetcher",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "AKniga",
            targets: ["AKniga"]
        ),
        .library(
            name: "AudioBookFetcher",
            targets: ["AudioBookFetcher"]
        ),
        .library(
            name: "WebViewSniffer",
            targets: ["WebViewSniffer"]
        ),
        .library(
            name: "SSWKURL",
            targets: ["SSWKURL"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.7.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "abookfetcher",
            dependencies: [
                "AudioBookFetcher",
                "AKniga",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "AudioBookFetcher",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "AKniga",
            dependencies: [
                "WebViewSniffer",
                "SwiftSoup",
                "AudioBookFetcher",
            ]
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
        .target(
            name: "WebViewSniffer",
            dependencies: [
                "SSWKURL",
            ]
        ),

        .testTarget(
            name: "WebViewSnifferTests",
            dependencies: [
                "WebViewSniffer",
            ]
        ),

        .target(
            name: "SSWKURL",
            dependencies: [
            ]
        ),
    ]
)
