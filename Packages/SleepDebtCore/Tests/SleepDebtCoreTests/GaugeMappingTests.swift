import XCTest
@testable import SleepDebtCore

final class GaugeMappingTests: XCTestCase {
    func testZeroDebtSitsAtTheFloor() {
        XCTAssertEqual(
            GaugeMapping.fraction(for: .zero), GaugeMapping.minimumVisibleFraction, accuracy: 0.0001
        )
    }

    func testFirstSegmentCapIsExactlySixtyPercent() {
        XCTAssertEqual(
            GaugeMapping.fraction(for: GaugeMapping.firstSegmentCap), 0.6, accuracy: 0.0001
        )
    }

    func testSaturationPointIsFull() {
        XCTAssertEqual(
            GaugeMapping.fraction(for: GaugeMapping.saturationPoint), 1.0, accuracy: 0.0001
        )
    }

    func testBeyondSaturationStaysAtOne() {
        XCTAssertEqual(GaugeMapping.fraction(for: .hours(40)), 1.0, accuracy: 0.0001)
    }

    func testMonotonicallyIncreasing() {
        let a = GaugeMapping.fraction(for: .hours(2))
        let b = GaugeMapping.fraction(for: .hours(6))
        let c = GaugeMapping.fraction(for: .hours(12))
        let d = GaugeMapping.fraction(for: .hours(20))
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
        XCTAssertLessThan(c, d)
    }

    func testTargetFractionMatchesFiveHours() {
        XCTAssertEqual(
            GaugeMapping.targetFraction, GaugeMapping.fraction(for: .hours(5)), accuracy: 0.0001
        )
    }

    func testNegativeDebtIsTreatedAsZero() {
        // The engine floors debt at 0 itself (D2), but the gauge shouldn't
        // misbehave if ever handed a negative value directly.
        XCTAssertEqual(
            GaugeMapping.fraction(for: .hours(-3)),
            GaugeMapping.minimumVisibleFraction,
            accuracy: 0.0001
        )
    }

    func testMockupReferenceValueLandsInTheExpectedRange() {
        // The design mockup draws 10h26 at 52% under its own literal
        // linear 0-20h reading; D10 supersedes that scale (see
        // docs/IMPLEMENTATION_PLAN.md §1.2) but should still land in a
        // broadly similar, plausible region rather than somewhere wild.
        let fraction = GaugeMapping.fraction(for: .hm(10, 26))
        XCTAssertGreaterThan(fraction, 0.55)
        XCTAssertLessThan(fraction, 0.75)
    }
}
