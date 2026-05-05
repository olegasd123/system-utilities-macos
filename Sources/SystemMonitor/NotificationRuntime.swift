import Foundation

enum NotificationRuntime {
    static var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
            && Bundle.main.bundleIdentifier?.isEmpty == false
    }
}
