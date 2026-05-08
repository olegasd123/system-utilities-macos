// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SystemUtilitiesMacOS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SystemMonitor", targets: ["App"])
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: ["AppCore", "AppUI", "SystemMonitorUI"]
        ),
        .target(
            name: "AppCore"
        ),
        .target(
            name: "AppUI"
        ),
        .target(
            name: "SystemMonitorCore",
            dependencies: ["AppCore", "MacSensorBridge"]
        ),
        .target(
            name: "SystemMonitorUI",
            dependencies: ["AppCore", "AppUI", "SystemMonitorCore"]
        ),
        .target(
            name: "MacSensorBridge",
            linkerSettings: [
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"]
        ),
        .testTarget(
            name: "SystemMonitorCoreTests",
            dependencies: ["AppCore", "SystemMonitorCore"]
        ),
        .testTarget(
            name: "SystemMonitorUITests",
            dependencies: ["AppCore", "AppUI", "SystemMonitorCore", "SystemMonitorUI"]
        )
    ]
)
