import AppCore
import XCTest

@MainActor
final class SettingsModelTests: XCTestCase {
    func testOnChangeRunsWhenValueChanges() {
        var changedValues: [GeneralSettings] = []
        let initial = GeneralSettings(temperatureUnit: .celsius, launchAtLogin: false)
        let updated = GeneralSettings(temperatureUnit: .fahrenheit, launchAtLogin: true)
        let model = SettingsModel(initial: initial) { changedValues.append($0) }

        model.settings = updated

        XCTAssertEqual(changedValues, [updated])
    }

    func testOnChangeDoesNotRunWhenValueIsUnchanged() {
        var changeCount = 0
        let initial = GeneralSettings(temperatureUnit: .celsius, launchAtLogin: false)
        let model = SettingsModel(initial: initial) { _ in changeCount += 1 }

        model.settings = initial

        XCTAssertEqual(changeCount, 0)
    }

    func testBindingUpdatesSettings() {
        var changedValues: [GeneralSettings] = []
        let initial = GeneralSettings(temperatureUnit: .celsius, launchAtLogin: false)
        let updated = GeneralSettings(temperatureUnit: .fahrenheit, launchAtLogin: false)
        let model = SettingsModel(initial: initial) { changedValues.append($0) }

        model.binding.wrappedValue = updated

        XCTAssertEqual(model.settings, updated)
        XCTAssertEqual(changedValues, [updated])
    }
}
