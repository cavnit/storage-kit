// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "StorageKit",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "StorageKit",
            targets: ["StorageKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
    ],
    targets: [
        .target(
            name: "StorageKit",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "StorageKitTests",
            dependencies: ["StorageKit"]
        ),
    ]
)
