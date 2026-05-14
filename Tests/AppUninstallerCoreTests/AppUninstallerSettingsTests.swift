@testable import AppUninstallerCore
import XCTest

final class AppUninstallerSettingsTests: XCTestCase {
    func testDefaultSettingsUseExpectedJsonShape() throws {
        let data = try JSONEncoder().encode(AppUninstallerSettings.defaultValue)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["include_name_heuristic_matches"] as? Bool, false)
        XCTAssertEqual(object["include_system_library_paths"] as? Bool, true)
        XCTAssertEqual(object["include_user_home_paths"] as? Bool, false)
        XCTAssertEqual(object["default_reclaim_mode"] as? String, "moveToTrash")
    }

    func testMissingUserHomeSettingUsesDefault() throws {
        let data = Data(
            """
            {
              "include_name_heuristic_matches": true,
              "include_system_library_paths": false,
              "default_reclaim_mode": "moveToTrash"
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(AppUninstallerSettings.self, from: data)

        XCTAssertTrue(decoded.includeNameHeuristicMatches)
        XCTAssertFalse(decoded.includeSystemLibraryPaths)
        XCTAssertFalse(decoded.includeUserHomePaths)
        XCTAssertEqual(decoded.defaultReclaimMode, .moveToTrash)
    }
}
