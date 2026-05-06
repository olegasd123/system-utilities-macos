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
            dependencies: ["AppCore", "AppUI", "SystemMonitor"]
        ),
        .target(
            name: "AppCore"
        ),
        .target(
            name: "AppUI"
        ),
        .target(
            name: "SystemMonitor",
            dependencies: ["AppCore", "AppUI", "MacSensorBridge"]
        ),
        .target(
            name: "MacSensorBridge",
            linkerSettings: [
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
