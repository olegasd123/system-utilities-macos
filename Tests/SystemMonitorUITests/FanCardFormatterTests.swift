@testable import SystemMonitorUI
import AppCore
import SystemMonitorCore
import XCTest

final class FanCardFormatterTests: XCTestCase {
    func testValueLocalizesRussianFanCount() {
        XCTAssertEqual(
            FanCardFormatter.value(
                fans: [
                    FanSample(label: "Fan 1", rpm: 1_200),
                    FanSample(label: "Fan 2", rpm: 900)
                ],
                localization: AppLocalization(selection: .russian)
            ),
            "2 вентилятора"
        )
    }

    func testValueLocalizesUkrainianFanCount() {
        XCTAssertEqual(
            FanCardFormatter.value(
                fans: [
                    FanSample(label: "Fan 1", rpm: 1_200),
                    FanSample(label: "Fan 2", rpm: 900)
                ],
                localization: AppLocalization(selection: .ukrainian)
            ),
            "2 вентилятори"
        )
    }

    func testValueUsesNoFanDataWhenFansAreEmpty() {
        XCTAssertEqual(
            FanCardFormatter.value(fans: []),
            "No fan data"
        )
    }

    func testSubtitleLocalizesFanLabelsAndUnit() {
        let subtitle = FanCardFormatter.subtitle(
            fans: [
                FanSample(label: "Fan 1", rpm: 1_200),
                FanSample(label: "Fan 2", rpm: 900)
            ],
            localization: AppLocalization(selection: .russian)
        )

        XCTAssertEqual(subtitle, [
            "Вентилятор 1:  1200 об/мин",
            "Вентилятор 2:  900 об/мин"
        ].joined(separator: "\n"))
    }

    func testSubtitleUsesUnavailableTextWhenFansAreEmpty() {
        XCTAssertEqual(
            FanCardFormatter.subtitle(fans: []),
            "Unavailable"
        )
    }
}
