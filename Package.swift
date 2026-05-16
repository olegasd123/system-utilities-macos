// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SystemUtilitiesMacOS",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SystemMonitor", targets: ["App"])
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                "AppCore",
                "AppUI",
                "AppUninstallerUI",
                "CleanDriveUI",
                "SystemMonitorUI"
            ]
        ),
        .target(
            name: "AppCore",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "AppUI",
            dependencies: ["AppCore"]
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
            name: "CleanDriveCore",
            dependencies: ["AppCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "CleanDriveUI",
            dependencies: ["AppCore", "AppUI", "CleanDriveCore"]
        ),
        .target(
            name: "AppUninstallerCore",
            dependencies: ["AppCore"]
        ),
        .target(
            name: "AppUninstallerUI",
            dependencies: ["AppCore", "AppUI", "AppUninstallerCore"]
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
            name: "CleanDriveCoreTests",
            dependencies: ["AppCore", "CleanDriveCore"]
        ),
        .testTarget(
            name: "AppUninstallerCoreTests",
            dependencies: ["AppCore", "AppUninstallerCore"]
        ),
        .testTarget(
            name: "SystemMonitorUITests",
            dependencies: ["AppCore", "AppUI", "SystemMonitorCore", "SystemMonitorUI"]
        )
    ]
)
