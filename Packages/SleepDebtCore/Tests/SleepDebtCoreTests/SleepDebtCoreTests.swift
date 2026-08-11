import XCTest
@testable import SleepDebtCore

final class SleepDebtCoreTests: XCTestCase {
    func testPackageLoads() {
        XCTAssertEqual(SleepDebtCore.packageName, "SleepDebtCore")
    }
}
