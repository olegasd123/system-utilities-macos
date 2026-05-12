import AppCore
import Foundation
import UserNotifications

public struct CleanDriveReminderNotification: Equatable, Sendable {
    public var identifier: String
    public var title: String
    public var body: String

    public init(identifier: String, title: String, body: String) {
        self.identifier = identifier
        self.title = title
        self.body = body
    }
}

@MainActor
public protocol CleanDriveReminderNotificationSending {
    func send(_ notification: CleanDriveReminderNotification)
}

@MainActor
public protocol CleanDriveReminderScanning {
    func reclaimableBytes(settings: CleanDriveSettings) async -> UInt64
}

@MainActor
public final class CleanDriveReminderService {
    private let settingsModel: SettingsModel<CleanDriveSettings>
    private let scanner: any CleanDriveReminderScanning
    private let notificationSender: any CleanDriveReminderNotificationSending
    private let now: () -> Date
    private let scanInterval: TimeInterval
    private var timer: Timer?
    private var checkTask: Task<Void, Never>?

    public convenience init(
        settings: SettingsModel<CleanDriveSettings>,
        categories: [any ReclaimableCategory] = CleanDriveCategoryCatalog.defaultCategories(),
        scanContext: CleanDriveScanContext = CleanDriveScanContext(),
        scanInterval: TimeInterval = 60 * 60
    ) {
        self.init(
            settings: settings,
            scanner: CleanDriveReminderScanner(
                categories: categories,
                scanContext: scanContext
            ),
            notificationSender: UserNotificationCleanDriveReminderSender(),
            now: Date.init,
            scanInterval: scanInterval
        )
    }

    public init(
        settings: SettingsModel<CleanDriveSettings>,
        scanner: any CleanDriveReminderScanning,
        notificationSender: any CleanDriveReminderNotificationSending,
        now: @escaping () -> Date = Date.init,
        scanInterval: TimeInterval = 60 * 60
    ) {
        self.settingsModel = settings
        self.scanner = scanner
        self.notificationSender = notificationSender
        self.now = now
        self.scanInterval = scanInterval
    }

    public func start() {
        guard timer == nil else {
            return
        }
        if settingsModel.settings.reminders.enabled {
            NotificationPermissionService.requestPermission()
        }
        timer = Timer.scheduledTimer(
            withTimeInterval: scanInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkNow()
            }
        }
        timer?.tolerance = min(scanInterval * 0.1, 60)
        checkTask = Task { @MainActor [weak self] in
            await self?.checkNow()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        checkTask?.cancel()
        checkTask = nil
    }

    public func checkNow() async {
        let settings = settingsModel.settings
        guard shouldCheck(settings, at: now()) else {
            return
        }

        let reclaimableBytes = await scanner.reclaimableBytes(settings: settings)
        guard reclaimableBytes >= settings.reminders.thresholdBytes else {
            return
        }

        let sentAt = now()
        notificationSender.send(notification(bytes: reclaimableBytes, sentAt: sentAt))
        settingsModel.settings.lastReminderAt = sentAt
    }

    private func shouldCheck(_ settings: CleanDriveSettings, at date: Date) -> Bool {
        guard settings.reminders.enabled else {
            return false
        }
        guard let lastReminderAt = settings.lastReminderAt else {
            return true
        }
        let minimumGap = TimeInterval(settings.reminders.minHoursBetweenReminders * 60 * 60)
        return date.timeIntervalSince(lastReminderAt) >= minimumGap
    }

    private func notification(
        bytes: UInt64,
        sentAt: Date
    ) -> CleanDriveReminderNotification {
        CleanDriveReminderNotification(
            identifier: "clean-drive-\(Int(sentAt.timeIntervalSince1970))",
            title: "Clean Drive is ready",
            body: "\(Self.formattedBytes(bytes)) can be cleaned. Open the app to review it."
        )
    }

    private static func formattedBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        }

        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(bytes) / 1024
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return String(format: "%.1f %@", value, units[index])
    }
}

public struct CleanDriveReminderScanner: CleanDriveReminderScanning {
    private let categories: [any ReclaimableCategory]
    private let baseScanContext: CleanDriveScanContext

    public init(
        categories: [any ReclaimableCategory],
        scanContext: CleanDriveScanContext = CleanDriveScanContext()
    ) {
        self.categories = categories
        self.baseScanContext = scanContext
    }

    public func reclaimableBytes(settings: CleanDriveSettings) async -> UInt64 {
        var totalBytes: UInt64 = 0
        let context = scanContext(settings: settings)

        for category in categories where settings.isCategoryEnabled(
            category.id,
            defaultEnabled: category.defaultEnabled
        ) {
            do {
                let result = try await category.scan(context)
                totalBytes += result.totalBytes
                if totalBytes >= settings.reminders.thresholdBytes {
                    return totalBytes
                }
            } catch {
                continue
            }
        }

        return totalBytes
    }

    private func scanContext(settings: CleanDriveSettings) -> CleanDriveScanContext {
        CleanDriveScanContext(
            homeDirectory: baseScanContext.homeDirectory,
            userID: baseScanContext.userID,
            downloadsOlderThanDays: settings.reclaim.downloadsOlderThanDays,
            xcodeArchivesOlderThanDays: settings.reclaim.xcodeArchivesOlderThanDays
        )
    }
}

private struct UserNotificationCleanDriveReminderSender: CleanDriveReminderNotificationSending {
    func send(_ notification: CleanDriveReminderNotification) {
        guard NotificationRuntime.canUseUserNotifications else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: notification.identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
