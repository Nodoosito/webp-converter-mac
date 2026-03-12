// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebPConverterMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WebPConverterMac", targets: ["WebPConverterMac"])
    ],
    targets: [
        .executableTarget(
            name: "WebPConverterMac",
            path: "Sources/WebPConverterMac"
        )
    ]
)
