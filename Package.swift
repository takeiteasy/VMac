// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "vmac",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "vmac", targets: ["vmac"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "vmac",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
    ]
)
