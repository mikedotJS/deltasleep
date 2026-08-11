import XCTest
@testable import SleepDebtCore

final class SleepDurationTests: XCTestCase {
    func testHoursMinutesConstruction() {
        let d = SleepDuration.hm(10, 26)
        XCTAssertEqual(d.seconds, 10 * 3600 + 26 * 60, accuracy: 0.001)
    }

    func testArithmetic() {
        let a = SleepDuration.hm(1, 30)
        let b = SleepDuration.hm(0, 45)
        XCTAssertEqual((a + b).seconds, SleepDuration.hm(2, 15).seconds, accuracy: 0.001)
        XCTAssertEqual((a - b).seconds, SleepDuration.hm(0, 45).seconds, accuracy: 0.001)
        XCTAssertEqual((-a).seconds, -a.seconds, accuracy: 0.001)
        XCTAssertEqual((a * 2).seconds, SleepDuration.hm(3, 0).seconds, accuracy: 0.001)
    }

    func testClampedLow() {
        let low = SleepDuration.hours(-1)
        XCTAssertEqual(SleepDuration.hours(-3).clamped(low: low).hours, -1, accuracy: 0.001)
        XCTAssertEqual(SleepDuration.hours(-0.5).clamped(low: low).hours, -0.5, accuracy: 0.001)
        XCTAssertEqual(SleepDuration.hours(2).clamped(low: low).hours, 2, accuracy: 0.001)
    }

    func testClampedLowHigh() {
        let clamped = SleepDuration.hours(30).clamped(low: .zero, high: .hours(24))
        XCTAssertEqual(clamped.hours, 24, accuracy: 0.001)
    }

    func testWholeHoursAndMinutesReproducesMockupFigures() {
        // 13h04 and 1h24 are the exact figures shown on the design mockup's
        // phone card (docs/design/mockup-liquid-glass-v02.html).
        XCTAssertTrue(SleepDuration.hm(13, 4).wholeHoursAndMinutes == (13, 4))
        XCTAssertTrue(SleepDuration.hm(1, 24).wholeHoursAndMinutes == (1, 24))
    }

    func testWholeHoursAndMinutesDropsSignAndRounds() {
        // Deltas are signed internally but displayed via a separate arrow
        // glyph (DeltaChip in the design mockup), so magnitude only here.
        let negative = SleepDuration(seconds: -(39 * 60))
        XCTAssertTrue(negative.wholeHoursAndMinutes == (0, 39))

        // 90.6 minutes should round to 91, i.e. 1h31, not floor to 1h30.
        let fractional = SleepDuration(seconds: 90.6 * 60)
        XCTAssertTrue(fractional.wholeHoursAndMinutes == (1, 31))
    }

    func testOrdering() {
        XCTAssertTrue(SleepDuration.hours(1) < SleepDuration.hours(2))
        XCTAssertFalse(SleepDuration.hours(2) < SleepDuration.hours(2))
    }
}
