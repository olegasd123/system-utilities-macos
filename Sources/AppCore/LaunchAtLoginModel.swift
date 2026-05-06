import Foundation

@MainActor
public final class LaunchAtLoginModel: ObservableObject {
    @Published public private(set) var status: LaunchAtLoginStatus

    private let service: LaunchAtLoginService
    private let settingsModel: SettingsModel

    public init(
        service: LaunchAtLoginService = .standard,
        settingsModel: SettingsModel
    ) {
        self.service = service
        self.settingsModel = settingsModel

        var currentStatus = service.status()
        let loadResult = settingsModel.initialLoadResult
        if !loadResult.loadedFromDisk,
           loadResult.settings.launchAtLogin,
           currentStatus.canChange
        {
            currentStatus = service.setRegistered(true)
        }
        self.status = currentStatus

        if settingsModel.settings.launchAtLogin != currentStatus.isRegistered {
            settingsModel.settings.launchAtLogin = currentStatus.isRegistered
        }
    }

    public func setRegistered(_ isRegistered: Bool) {
        status = service.setRegistered(isRegistered)
        settingsModel.settings.launchAtLogin = status.isRegistered
    }

    public func openLoginItemsSettings() {
        service.openLoginItemsSettings()
        status = service.status()
        settingsModel.settings.launchAtLogin = status.isRegistered
    }
}
