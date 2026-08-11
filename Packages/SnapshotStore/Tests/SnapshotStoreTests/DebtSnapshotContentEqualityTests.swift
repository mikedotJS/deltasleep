import Foundation
import SleepDebtCore
import XCTest
@testable import SnapshotStore

final class DebtSnapshotContentEqualityTests: XCTestCase {
    private func makeSnapshot(
        computedAt: Date,
        debtHours: Double = 2,
        nightBars: [NightStripMapping.Bar] = []
    ) -> DebtSnapshot {
        DebtSnapshot(
            referenceDate: Date(timeIntervalSince1970: 0),
            need: SleepNeed(.hours(8)),
            debt: .hours(debtHours),
            trend: .falling,
            breakEvenTarget: .hours(7),
            deltaSinceYesterday: .minutes(-15),
            deltaSinceMonday: nil,
            fourteenNightAverage: .hours(7),
            measuredNightCount: 14,
            gapCount: 0,
            lastNightIsGap: false,
            lastNightSleepDuration: .hm(6, 30),
            nightBars: nightBars,
            computedAt: computedAt
        )
    }

    func testIdenticalExceptComputedAtIsSameContent() {
        let a = makeSnapshot(computedAt: Date(timeIntervalSince1970: 0))
        let b = makeSnapshot(computedAt: Date(timeIntervalSince1970: 999_999))
        XCTAssertTrue(a.hasSameContent(as: b))
    }

    func testADifferentDebtIsNotSameContent() {
        let a = makeSnapshot(computedAt: Date(timeIntervalSince1970: 0), debtHours: 2)
        let b = makeSnapshot(computedAt: Date(timeIntervalSince1970: 0), debtHours: 3)
        XCTAssertFalse(a.hasSameContent(as: b))
    }

    func testDifferentNightBarsIsNotSameContent() {
        let bar = NightStripMapping.Bar(isGap: false, isSurplus: true, fraction: 0.5)
        let a = makeSnapshot(computedAt: Date(timeIntervalSince1970: 0), nightBars: [])
        let b = makeSnapshot(computedAt: Date(timeIntervalSince1970: 0), nightBars: [bar])
        XCTAssertFalse(a.hasSameContent(as: b))
    }
}
