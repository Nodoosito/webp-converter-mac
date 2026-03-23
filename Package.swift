// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "WebPConverterMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Orlo", targets: ["WebPConverterMac"])
    ],
    targets: [
        .executableTarget(
            name: "WebPConverterMac",
            path: "Sources/WebPConverterMac"
        )
    ]
)
