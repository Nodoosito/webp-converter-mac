// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebPConverterMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "WebPConverterMac", targets: ["WebPConverterMac"]) // ← library
    ],
    targets: [
        .target(                          // ← .target au lieu de .executableTarget
            name: "WebPConverterMac",
            path: "Sources/WebPConverterMac",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
