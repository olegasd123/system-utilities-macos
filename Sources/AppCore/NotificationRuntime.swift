import Foundation

public enum NotificationRuntime {
    public static var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
            && Bundle.main.bundleIdentifier?.isEmpty == false
    }
}
