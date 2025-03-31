// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Summit",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "Summit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        )
    ]
)

