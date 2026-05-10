import CleanDriveCore
import XCTest

final class CleanDriveSettingsTests: XCTestCase {
    func testDefaultSettingsUsePlannedJsonShape() throws {
        let data = try JSONEncoder().encode(CleanDriveSettings.defaultValue)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        let categories = try XCTUnwrap(object["categories"] as? [String: Any])
        let userCaches = try XCTUnwrap(categories["user-caches"] as? [String: Any])
        let trash = try XCTUnwrap(categories["trash"] as? [String: Any])
        let reminders = try XCTUnwrap(object["reminders"] as? [String: Any])
        let reclaim = try XCTUnwrap(object["reclaim"] as? [String: Any])

        XCTAssertEqual(userCaches["enabled"] as? Bool, true)
        XCTAssertEqual(trash["enabled"] as? Bool, false)
        XCTAssertEqual(reminders["enabled"] as? Bool, true)
        XCTAssertEqual(reminders["threshold_bytes"] as? Int, 5_368_709_120)
        XCTAssertEqual(reminders["min_hours_between_reminders"] as? Int, 24)
        XCTAssertEqual(reclaim["permanently_delete"] as? Bool, false)
        XCTAssertEqual(reclaim["downloads_older_than_days"] as? Int, 30)
        XCTAssertEqual(reclaim["xcode_archives_older_than_days"] as? Int, 60)
    }

    func testSettingsRoundTrip() throws {
        var settings = CleanDriveSettings.defaultValue
        settings.setCategoryEnabled(false, id: .userCaches)
        settings.reminders.thresholdBytes = 2 * 1_024 * 1_024 * 1_024
        settings.reclaim.permanentlyDelete = true
        settings.reclaim.downloadsOlderThanDays = 14

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(CleanDriveSettings.self, from: encoded)

        XCTAssertEqual(decoded, settings)
    }

    func testMissingSettingsKeysUseDefaults() throws {
        let data = Data(#"{"categories":{"trash":{"enabled":true}}}"#.utf8)

        let decoded = try JSONDecoder().decode(CleanDriveSettings.self, from: data)

        XCTAssertEqual(decoded.categories[.trash]?.enabled, true)
        XCTAssertEqual(decoded.categories[.userCaches]?.enabled, true)
        XCTAssertEqual(decoded.reminders, .defaultValue)
        XCTAssertEqual(decoded.reclaim, .defaultValue)
    }
}
