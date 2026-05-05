import Foundation
import UserNotifications

enum NotificationPermissionService {
    static func requestPermission() {
        guard NotificationRuntime.canUseUserNotifications else {
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
