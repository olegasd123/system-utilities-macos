import AppCore
import SystemMonitorCore
import XCTest

final class SystemFormattersTests: XCTestCase {
    func testBytesFormatsBinaryUnits() {
        XCTAssertEqual(SystemFormatters.bytes(42), "42 B")
        XCTAssertEqual(SystemFormatters.bytes(1536), "1.5 KB")
        XCTAssertEqual(SystemFormatters.bytes(1_048_576, decimals: 0), "1 MB")
        XCTAssertEqual(SystemFormatters.bytes(1_099_511_627_776), "1.0 TB")
    }

    func testRateFormatsBytesPerSecond() {
        XCTAssertEqual(SystemFormatters.rate(512), "512 B/s")
        XCTAssertEqual(SystemFormatters.rate(2048), "2.0 KB/s")
        XCTAssertEqual(SystemFormatters.rate(2 * 1024 * 1024), "2.0 MB/s")
    }

    func testTemperatureUsesSelectedUnit() {
        XCTAssertEqual(SystemFormatters.temperature(25.25, unit: .celsius), "25.2 C")
        XCTAssertEqual(SystemFormatters.temperature(25, unit: .fahrenheit), "77 F")
    }

    func testDurationUsesLargestUsefulUnits() {
        XCTAssertEqual(SystemFormatters.duration(45), "45s")
        XCTAssertEqual(SystemFormatters.duration(90), "1m")
        XCTAssertEqual(SystemFormatters.duration(3_900), "1h 5m")
        XCTAssertEqual(SystemFormatters.duration(86_400 + 3_600), "1d 1h")
    }

    func testCompactFormats() {
        XCTAssertEqual(SystemFormatters.compactBytes(512), "512B")
        XCTAssertEqual(SystemFormatters.compactBytes(2 * 1024), "2KB")
        XCTAssertEqual(SystemFormatters.compactBytes(1536 * 1024), "1.5MB")
        XCTAssertEqual(SystemFormatters.compactRate(2048, units: .bytesPerSecond), "2.0KB")
        XCTAssertEqual(SystemFormatters.compactRate(125_000, units: .bitsPerSecond), "1.0Mb")
    }
}
