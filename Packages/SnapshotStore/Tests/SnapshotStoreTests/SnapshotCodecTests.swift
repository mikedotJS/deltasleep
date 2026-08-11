import Foundation
import SleepDebtCore
import XCTest
@testable import SnapshotStore

final class SnapshotCodecTests: XCTestCase {
    private func makeSnapshot(computedAt: Date = Date(timeIntervalSince1970: 0)) -> DebtSnapshot {
        DebtSnapshot(
            referenceDate: Date(timeIntervalSince1970: 0),
            need: SleepNeed(.hours(8)),
            debt: .hours(2),
            trend: .falling,
            breakEvenTarget: .hours(7),
            deltaSinceYesterday: .minutes(-15),
            deltaSinceMonday: nil,
            fourteenNightAverage: .hours(7),
            measuredNightCount: 14,
            gapCount: 0,
            lastNightIsGap: false,
            nightBars: [],
            computedAt: computedAt
        )
    }

    func testEncodeDecodeRoundTrips() throws {
        let original = makeSnapshot()
        let data = try SnapshotCodec.encode(original)
        let decoded = try XCTUnwrap(SnapshotCodec.decode(data))
        XCTAssertEqual(decoded, original)
    }

    func testDecodeReturnsNilForGarbageData() {
        let garbage = Data("not json".utf8)
        XCTAssertNil(SnapshotCodec.decode(garbage))
    }

    func testDecodeReturnsNilForAnUnrecognisedSchemaVersion() throws {
        let persisted = PersistedSnapshot(schemaVersion: 999, snapshot: makeSnapshot())
        let data = try JSONEncoder().encode(persisted)
        XCTAssertNil(SnapshotCodec.decode(data))
    }
}
