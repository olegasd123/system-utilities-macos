import AppCore
import CleanDriveCore
import XCTest

@MainActor
final class CleanDriveReminderServiceTests: XCTestCase {
    func testDisabledReminderDoesNotScanOrNotify() async {
        var settings = CleanDriveSettings.defaultValue
        settings.reminders.enabled = false
        settings.reminders.thresholdBytes = 100
        let settingsModel = SettingsModel<CleanDriveSettings>(initial: settings) { _ in }
        let scanner = SpyReminderScanner(bytes: 200)
        let sender = SpyReminderSender()
        let service = CleanDriveReminderService(
            settings: settingsModel,
            scanner: scanner,
            notificationSender: sender,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        await service.checkNow()

        XCTAssertEqual(scanner.callCount, 0)
        XCTAssertTrue(sender.notifications.isEmpty)
        XCTAssertNil(settingsModel.settings.lastReminderAt)
    }

    func testReminderDoesNotFireBelowThreshold() async {
        var settings = CleanDriveSettings.defaultValue
        settings.reminders.thresholdBytes = 500
        let settingsModel = SettingsModel<CleanDriveSettings>(initial: settings) { _ in }
        let scanner = SpyReminderScanner(bytes: 499)
        let sender = SpyReminderSender()
        let service = CleanDriveReminderService(
            settings: settingsModel,
            scanner: scanner,
            notificationSender: sender,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        await service.checkNow()

        XCTAssertEqual(scanner.callCount, 1)
        XCTAssertTrue(sender.notifications.isEmpty)
        XCTAssertNil(settingsModel.settings.lastReminderAt)
    }

    func testReminderFiresAtThresholdAndSavesLastReminderDate() async {
        var savedSettings: CleanDriveSettings?
        var settings = CleanDriveSettings.defaultValue
        settings.reminders.thresholdBytes = 500
        let now = Date(timeIntervalSince1970: 1_000)
        let settingsModel = SettingsModel<CleanDriveSettings>(
            initial: settings,
            onChange: { savedSettings = $0 }
        )
        let scanner = SpyReminderScanner(bytes: 500)
        let sender = SpyReminderSender()
        let service = CleanDriveReminderService(
            settings: settingsModel,
            scanner: scanner,
            notificationSender: sender,
            now: { now }
        )

        await service.checkNow()

        XCTAssertEqual(scanner.callCount, 1)
        XCTAssertEqual(sender.notifications.count, 1)
        XCTAssertEqual(sender.notifications.first?.identifier, "clean-drive-1000")
        XCTAssertEqual(sender.notifications.first?.title, "Clean Drive is ready")
        XCTAssertEqual(settingsModel.settings.lastReminderAt, now)
        XCTAssertEqual(savedSettings?.lastReminderAt, now)
    }

    func testRecentReminderThrottlesWithoutScanning() async {
        var settings = CleanDriveSettings.defaultValue
        settings.reminders.thresholdBytes = 100
        settings.reminders.minHoursBetweenReminders = 24
        settings.lastReminderAt = Date(timeIntervalSince1970: 1_000)
        let settingsModel = SettingsModel<CleanDriveSettings>(initial: settings) { _ in }
        let scanner = SpyReminderScanner(bytes: 200)
        let sender = SpyReminderSender()
        let service = CleanDriveReminderService(
            settings: settingsModel,
            scanner: scanner,
            notificationSender: sender,
            now: { Date(timeIntervalSince1970: 1_000 + 23 * 60 * 60) }
        )

        await service.checkNow()

        XCTAssertEqual(scanner.callCount, 0)
        XCTAssertTrue(sender.notifications.isEmpty)
        XCTAssertEqual(settingsModel.settings.lastReminderAt, settings.lastReminderAt)
    }

    func testOldReminderAllowsNextNotification() async {
        var settings = CleanDriveSettings.defaultValue
        settings.reminders.thresholdBytes = 100
        settings.reminders.minHoursBetweenReminders = 24
        settings.lastReminderAt = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 1_000 + 24 * 60 * 60)
        let settingsModel = SettingsModel<CleanDriveSettings>(initial: settings) { _ in }
        let scanner = SpyReminderScanner(bytes: 200)
        let sender = SpyReminderSender()
        let service = CleanDriveReminderService(
            settings: settingsModel,
            scanner: scanner,
            notificationSender: sender,
            now: { now }
        )

        await service.checkNow()

        XCTAssertEqual(scanner.callCount, 1)
        XCTAssertEqual(sender.notifications.count, 1)
        XCTAssertEqual(settingsModel.settings.lastReminderAt, now)
    }
}

private final class SpyReminderScanner: CleanDriveReminderScanning {
    var callCount = 0
    private let bytes: UInt64

    init(bytes: UInt64) {
        self.bytes = bytes
    }

    func reclaimableBytes(settings: CleanDriveSettings) async -> UInt64 {
        callCount += 1
        return bytes
    }
}

private final class SpyReminderSender: CleanDriveReminderNotificationSending {
    var notifications: [CleanDriveReminderNotification] = []

    func send(_ notification: CleanDriveReminderNotification) {
        notifications.append(notification)
    }
}
