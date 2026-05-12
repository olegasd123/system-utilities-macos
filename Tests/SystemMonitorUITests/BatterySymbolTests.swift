@testable import SystemMonitorUI
import SystemMonitorCore
import XCTest

final class BatterySymbolTests: XCTestCase {
    func testChargingBatteryUsesBoltSymbol() {
        XCTAssertEqual(
            BatterySymbol.name(for: battery(chargePercent: 10, state: .charging)),
            "battery.100.bolt"
        )
    }

    func testBatteryLevelSymbolsClampAndBucketPercentages() {
        XCTAssertEqual(BatterySymbol.name(for: battery(chargePercent: -1)), "battery.0")
        XCTAssertEqual(BatterySymbol.name(for: battery(chargePercent: 12.4)), "battery.0")
        XCTAssertEqual(BatterySymbol.name(for: battery(chargePercent: 12.5)), "battery.25")
        XCTAssertEqual(BatterySymbol.name(for: battery(chargePercent: 37.5)), "battery.50")
        XCTAssertEqual(BatterySymbol.name(for: battery(chargePercent: 62.5)), "battery.75")
        XCTAssertEqual(BatterySymbol.name(for: battery(chargePercent: 87.5)), "battery.100")
        XCTAssertEqual(BatterySymbol.name(for: battery(chargePercent: 120)), "battery.100")
    }

    private func battery(
        chargePercent: Double,
        state: BatteryState = .discharging
    ) -> BatterySample {
        BatterySample(
            chargePercent: chargePercent,
            state: state,
            timeToFullSecs: nil,
            timeToEmptySecs: nil
        )
    }
}
