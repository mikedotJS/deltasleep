import XCTest
@testable import HealthSleepSource

final class HealthSleepSourceTests: XCTestCase {
    func testPackageLoads() {
        XCTAssertEqual(HealthSleepSource.packageName, "HealthSleepSource")
    }
}
