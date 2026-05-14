import AppCore
import XCTest

final class AppLanguageTests: XCTestCase {
    func testGeneralSettingsDefaultToAutomaticLanguageWhenMissing() throws {
        let data = Data(
            """
            {
              "temperature_unit": "celsius",
              "launch_at_login": false
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(GeneralSettings.self, from: data)

        XCTAssertEqual(settings.language, .system)
    }

    func testGeneralSettingsDecodeSavedLanguage() throws {
        let data = Data(
            """
            {
              "temperature_unit": "celsius",
              "launch_at_login": false,
              "language": "fr"
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(GeneralSettings.self, from: data)

        XCTAssertEqual(settings.language, .french)
    }

    func testLocalizationFallsBackToEnglishForKnownKey() {
        let localization = AppLocalization(selection: .english)

        XCTAssertEqual(localization("Language"), "Language")
    }
}
