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
              "language": "es"
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(GeneralSettings.self, from: data)

        XCTAssertEqual(settings.language, .spanish)
    }

    func testLocalizationFallsBackToEnglishForKnownKey() {
        let localization = AppLocalization(selection: .english)

        XCTAssertEqual(localization("Language"), "Language")
    }

    func testUkrainianLocalizationLoadsKnownKey() {
        let localization = AppLocalization(selection: .ukrainian)

        XCTAssertEqual(localization("Language"), "Мова")
    }

    func testSpanishLocalizationLoadsKnownKey() {
        let localization = AppLocalization(selection: .spanish)

        XCTAssertEqual(localization("Language"), "Idioma")
    }

    func testGermanLocalizationLoadsKnownKey() {
        let localization = AppLocalization(selection: .german)

        XCTAssertEqual(localization("Language"), "Sprache")
    }

    func testLanguageNamesUseNativeLabels() {
        XCTAssertEqual(AppLanguage.english.nativeDisplayName, "English")
        XCTAssertEqual(AppLanguage.german.nativeDisplayName, "Deutsch")
        XCTAssertEqual(AppLanguage.spanish.nativeDisplayName, "Español")
        XCTAssertEqual(AppLanguage.french.nativeDisplayName, "Français")
        XCTAssertEqual(AppLanguage.russian.nativeDisplayName, "Русский")
        XCTAssertEqual(AppLanguage.ukrainian.nativeDisplayName, "Українська")
    }
}
