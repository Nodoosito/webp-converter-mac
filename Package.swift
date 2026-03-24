// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "WebPConverterMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Orlo", targets: ["WebPConverterMac"])
    ],
    targets: [
        .target(
            name: "WebPConverterMac",
            path: "Sources/WebPConverterMac",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
