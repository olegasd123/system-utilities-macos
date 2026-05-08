import AppCore
import XCTest

private struct TestFeatureSettings: FeatureSettings, Equatable {
    static let featureId = "test-feature"
    static let defaultValue = TestFeatureSettings(isEnabled: false, label: "Default")

    var isEnabled: Bool
    var label: String
}

final class RawAppSettingsTests: XCTestCase {
    func testValueReturnsDefaultWhenFeatureIsMissing() {
        let settings = RawAppSettings.defaultValue

        XCTAssertEqual(settings.value(for: TestFeatureSettings.self), .defaultValue)
    }

    func testSetValueStoresFeatureByFeatureId() {
        var settings = RawAppSettings.defaultValue
        let feature = TestFeatureSettings(isEnabled: true, label: "Custom")

        settings.setValue(feature)

        XCTAssertEqual(settings.value(for: TestFeatureSettings.self), feature)
        XCTAssertNotNil(settings.features[TestFeatureSettings.featureId])
    }

    func testValueReturnsDefaultWhenFeatureDataIsInvalid() {
        let settings = RawAppSettings(
            general: .defaultValue,
            features: [TestFeatureSettings.featureId: Data("bad-json".utf8)]
        )

        XCTAssertEqual(settings.value(for: TestFeatureSettings.self), .defaultValue)
    }
}
