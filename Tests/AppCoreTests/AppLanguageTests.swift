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

    func testGeneralSettingsDecodeSavedBrazilianPortugueseLanguage() throws {
        let data = Data(
            """
            {
              "temperature_unit": "celsius",
              "launch_at_login": false,
              "language": "pt-BR"
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(GeneralSettings.self, from: data)

        XCTAssertEqual(settings.language, .portugueseBrazil)
    }

    func testGeneralSettingsDecodeSavedSimplifiedChineseLanguage() throws {
        let data = Data(
            """
            {
              "temperature_unit": "celsius",
              "launch_at_login": false,
              "language": "zh-Hans"
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(GeneralSettings.self, from: data)

        XCTAssertEqual(settings.language, .simplifiedChinese)
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

    func testBrazilianPortugueseLocalizationLoadsKnownKey() {
        let localization = AppLocalization(selection: .portugueseBrazil)

        XCTAssertEqual(localization("Language"), "Idioma")
    }

    func testJapaneseLocalizationLoadsKnownKey() {
        let localization = AppLocalization(selection: .japanese)

        XCTAssertEqual(localization("Language"), "言語")
        XCTAssertEqual(localization("System Monitor"), "システムモニター")
    }

    func testSimplifiedChineseLocalizationLoadsKnownKey() {
        let localization = AppLocalization(selection: .simplifiedChinese)

        XCTAssertEqual(localization("Language"), "语言")
        XCTAssertEqual(localization("System Monitor"), "系统监控")
    }

    func testLanguageNamesUseNativeLabels() {
        XCTAssertEqual(AppLanguage.english.nativeDisplayName, "English")
        XCTAssertEqual(AppLanguage.german.nativeDisplayName, "Deutsch")
        XCTAssertEqual(AppLanguage.spanish.nativeDisplayName, "Español")
        XCTAssertEqual(AppLanguage.french.nativeDisplayName, "Français")
        XCTAssertEqual(AppLanguage.japanese.nativeDisplayName, "日本語")
        XCTAssertEqual(AppLanguage.portugueseBrazil.nativeDisplayName, "Português (Brasil)")
        XCTAssertEqual(AppLanguage.russian.nativeDisplayName, "Русский")
        XCTAssertEqual(AppLanguage.simplifiedChinese.nativeDisplayName, "简体中文")
        XCTAssertEqual(AppLanguage.ukrainian.nativeDisplayName, "Українська")
    }
}
