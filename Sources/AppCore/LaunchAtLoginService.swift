import Foundation
import ServiceManagement

public struct LaunchAtLoginStatus: Equatable, Sendable {
    public var isRegistered: Bool
    public var isEnabled: Bool
    public var canChange: Bool
    public var needsApproval: Bool
    public var message: String?

    public init(
        isRegistered: Bool,
        isEnabled: Bool,
        canChange: Bool,
        needsApproval: Bool,
        message: String?
    ) {
        self.isRegistered = isRegistered
        self.isEnabled = isEnabled
        self.canChange = canChange
        self.needsApproval = needsApproval
        self.message = message
    }

    public static let unavailable = LaunchAtLoginStatus(
        isRegistered: false,
        isEnabled: false,
        canChange: false,
        needsApproval: false,
        message: "Open at login needs a signed app bundle."
    )
}

public struct LaunchAtLoginService: Sendable {
    public static let standard = LaunchAtLoginService()

    public init() {}

    public func status() -> LaunchAtLoginStatus {
        guard Self.canUseMainAppService else {
            return .unavailable
        }

        return status(from: SMAppService.mainApp.status)
    }

    public func setRegistered(_ isRegistered: Bool) -> LaunchAtLoginStatus {
        guard Self.canUseMainAppService else {
            return .unavailable
        }

        let service = SMAppService.mainApp

        do {
            if isRegistered {
                let status = status(from: service.status)
                if !status.isRegistered {
                    try service.register()
                }
            } else if status(from: service.status).isRegistered {
                try service.unregister()
            }

            return status(from: service.status)
        } catch {
            var currentStatus = status(from: service.status)
            currentStatus.message = "Could not update Open at login. Check the app signature."
            return currentStatus
        }
    }

    public func openLoginItemsSettings() {
        guard Self.canUseMainAppService else {
            return
        }

        SMAppService.openSystemSettingsLoginItems()
    }

    private static var canUseMainAppService: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
            && Bundle.main.bundleIdentifier?.isEmpty == false
    }

    private func status(from serviceStatus: SMAppService.Status) -> LaunchAtLoginStatus {
        switch serviceStatus {
        case .notRegistered:
            return LaunchAtLoginStatus(
                isRegistered: false,
                isEnabled: false,
                canChange: true,
                needsApproval: false,
                message: nil
            )
        case .enabled:
            return LaunchAtLoginStatus(
                isRegistered: true,
                isEnabled: true,
                canChange: true,
                needsApproval: false,
                message: nil
            )
        case .requiresApproval:
            return LaunchAtLoginStatus(
                isRegistered: true,
                isEnabled: false,
                canChange: true,
                needsApproval: true,
                message: "Allow System Monitor in Login Items."
            )
        case .notFound:
            return LaunchAtLoginStatus(
                isRegistered: false,
                isEnabled: false,
                canChange: false,
                needsApproval: false,
                message: "Login item was not found in this app."
            )
        @unknown default:
            return LaunchAtLoginStatus(
                isRegistered: false,
                isEnabled: false,
                canChange: false,
                needsApproval: false,
                message: "Open at login is not available."
            )
        }
    }
}
