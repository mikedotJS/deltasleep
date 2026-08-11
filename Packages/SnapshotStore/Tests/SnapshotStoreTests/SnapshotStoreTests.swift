import XCTest
@testable import SnapshotStore

final class SnapshotStoreTests: XCTestCase {
    func testPackageLoads() {
        XCTAssertEqual(SnapshotStore.packageName, "SnapshotStore")
    }
}
