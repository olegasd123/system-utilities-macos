// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SystemUtilitiesMacOS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SystemMonitor", targets: ["SystemMonitor"])
    ],
    targets: [
        .executableTarget(name: "SystemMonitor")
    ]
)
