@testable import SystemMonitorCore
import XCTest

final class NetworkCollectorTests: XCTestCase {
    func testConnectionTypeUsesNetworkServiceType() {
        XCTAssertEqual(
            NetworkCollector.connectionType(for: "en1", serviceType: "IEEE80211"),
            "Wi-Fi"
        )
        XCTAssertEqual(
            NetworkCollector.connectionType(for: "en0", serviceType: "Ethernet"),
            "Ethernet"
        )
        XCTAssertEqual(
            NetworkCollector.connectionType(for: "utun0", serviceType: "L2TP"),
            "VPN"
        )
    }

    func testConnectionTypeFallsBackToInterfaceName() {
        XCTAssertEqual(NetworkCollector.connectionType(for: "en0", serviceType: nil), "Wi-Fi")
        XCTAssertEqual(NetworkCollector.connectionType(for: "en5", serviceType: nil), "Ethernet")
        XCTAssertEqual(NetworkCollector.connectionType(for: "utun3", serviceType: nil), "VPN")
    }
}
