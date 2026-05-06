import Foundation
import UserNotifications

public enum NotificationPermissionService {
    public static func requestPermission() {
        guard NotificationRuntime.canUseUserNotifications else {
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
