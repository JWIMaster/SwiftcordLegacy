// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "SwiftcordLegacy",
    platforms: [
        .iOS("7.0")
    ],
    products: [
        .library(
            name: "SwiftcordLegacy",
            targets: ["SwiftcordLegacy"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/JWIMaster/FoundationCompatKit.git", branch: "master"),
        .package(url: "https://github.com/JWIMaster/NSJSONSerialization-for-Swift", branch: "master"),
    ],
    targets: [
        .target(
            name: "SwiftcordLegacy",
            dependencies: [
                .product(name: "FoundationCompatKit", package: "FoundationCompatKit"),
                .product(name: "NSJSONSerializationForSwift", package: "NSJSONSerialization-for-Swift"),
            ]
        ),
        .testTarget(
            name: "SwiftcordLegacyTests",
            dependencies: ["SwiftcordLegacy"]
        ),
    ]
)
