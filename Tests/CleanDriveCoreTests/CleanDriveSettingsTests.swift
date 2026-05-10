import CleanDriveCore
import XCTest

final class CleanDriveSettingsTests: XCTestCase {
    func testDefaultSettingsAreEmpty() throws {
        let data = try JSONEncoder().encode(CleanDriveSettings.defaultValue)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object.count, 0)
    }

    func testSettingsRoundTrip() throws {
        let encoded = try JSONEncoder().encode(CleanDriveSettings.defaultValue)
        let decoded = try JSONDecoder().decode(CleanDriveSettings.self, from: encoded)

        XCTAssertEqual(decoded, CleanDriveSettings.defaultValue)
    }
}
