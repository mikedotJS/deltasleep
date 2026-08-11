import XCTest
@testable import GlassKit

final class GlassKitTests: XCTestCase {
    func testPackageLoads() {
        XCTAssertEqual(GlassKit.packageName, "GlassKit")
    }
}
