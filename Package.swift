// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AIVideoCaptionEditor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AIVideoCaptionEditor",
            targets: ["AIVideoCaptionEditor"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AIVideoCaptionEditor",
            path: "Sources/AIVideoCaptionEditor"
        )
    ]
)
