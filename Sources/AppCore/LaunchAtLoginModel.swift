import Foundation

@MainActor
public final class LaunchAtLoginModel: ObservableObject {
    @Published public private(set) var status: LaunchAtLoginStatus

    private let service: LaunchAtLoginService
    private let persist: (Bool) -> Void

    public init(
        service: LaunchAtLoginService = .standard,
        initiallyLoadedFromDisk: Bool,
        initialLaunchAtLogin: Bool,
        persist: @escaping (Bool) -> Void
    ) {
        self.service = service
        self.persist = persist

        var currentStatus = service.status()
        if !initiallyLoadedFromDisk,
           initialLaunchAtLogin,
           currentStatus.canChange
        {
            currentStatus = service.setRegistered(true)
        }
        self.status = currentStatus

        if initialLaunchAtLogin != currentStatus.isRegistered {
            persist(currentStatus.isRegistered)
        }
    }

    public func setRegistered(_ isRegistered: Bool) {
        status = service.setRegistered(isRegistered)
        persist(status.isRegistered)
    }

    public func openLoginItemsSettings() {
        service.openLoginItemsSettings()
        status = service.status()
        persist(status.isRegistered)
    }
}
