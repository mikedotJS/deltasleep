import Foundation
import XCTest
@testable import SleepDebtCore

final class NightStripMappingTests: XCTestCase {
    private let need = SleepNeed(.hm(8, 0))
    private let anyDate = Date(timeIntervalSince1970: 0)

    func testGapNightIsMarkedAndHasZeroFraction() {
        let bar = NightStripMapping.bar(for: .gap(date: anyDate), need: need)
        XCTAssertTrue(bar.isGap)
        XCTAssertEqual(bar.fraction, 0, accuracy: 0.0001)
    }

    func testSurplusNightIsAboveTheAxis() {
        let night = Night.measured(date: anyDate, asleep: .hm(9, 0))
        let bar = NightStripMapping.bar(for: night, need: need)
        XCTAssertFalse(bar.isGap)
        XCTAssertTrue(bar.isSurplus)
    }

    func testDeficitNightIsBelowTheAxis() {
        let night = Night.measured(date: anyDate, asleep: .hm(6, 0))
        let bar = NightStripMapping.bar(for: night, need: need)
        XCTAssertFalse(bar.isSurplus)
    }

    func testExactlyAtNeedIsStillVisible() {
        // The mockup's own floor (Math.max(3, ...)) — a night that hit
        // its need exactly is a sliver, not invisible.
        let night = Night.measured(date: anyDate, asleep: .hm(8, 0))
        let bar = NightStripMapping.bar(for: night, need: need)
        XCTAssertEqual(bar.fraction, NightStripMapping.minimumVisibleFraction, accuracy: 0.0001)
    }

    func testMagnitudeAtOrBeyondClampFillsFully() {
        // 6h below an 8h need — beyond the mockup's 2.2h clamp reference.
        let night = Night.measured(date: anyDate, asleep: .hm(2, 0))
        let bar = NightStripMapping.bar(for: night, need: need)
        XCTAssertEqual(bar.fraction, 1.0, accuracy: 0.0001)
    }

    func testStripIsARawEncodingIndependentOfTheDebtEngine() {
        // No surplus cap here, unlike the debt engine's per-night deficit
        // (D2) — an 11h night is 3h above need, not clamped to 1h.
        let night = Night.measured(date: anyDate, asleep: .hm(11, 0))
        let bar = NightStripMapping.bar(for: night, need: need)
        XCTAssertTrue(bar.isSurplus)
        XCTAssertEqual(bar.fraction, 1.0, accuracy: 0.0001) // 3h > the 2.2h clamp, so fully filled
    }
}
