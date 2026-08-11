import XCTest
@testable import GlassKit

final class NightStripBarTests: XCTestCase {
    func testBarLengthScalesWithFraction() {
        let bar = NightStrip.Bar(isGap: false, isAboveAxis: true, fraction: 0.5)
        XCTAssertEqual(bar.barLength(halfHeight: 40), 20, accuracy: 0.001)
    }

    func testBarLengthFloorsAtThreePoints() {
        // A fraction small enough that halfHeight * fraction would be
        // under 3pt must still floor at 3 — never fully invisible,
        // mirroring NightStripMapping's own minimum-visible-fraction.
        let bar = NightStrip.Bar(isGap: false, isAboveAxis: true, fraction: 0.01)
        XCTAssertEqual(bar.barLength(halfHeight: 40), 3, accuracy: 0.001)
    }

    func testFullFractionFillsTheWholeHalfHeight() {
        let bar = NightStrip.Bar(isGap: false, isAboveAxis: false, fraction: 1)
        XCTAssertEqual(bar.barLength(halfHeight: 40), 40, accuracy: 0.001)
    }

    func testGapBarLengthIsUnaffectedByFraction() {
        // barLength doesn't special-case isGap — the view itself renders
        // gap bars as a fixed 2pt sliver regardless of this value — but
        // it should still compute sensibly rather than crash.
        let bar = NightStrip.Bar(isGap: true, isAboveAxis: false, fraction: 0)
        XCTAssertEqual(bar.barLength(halfHeight: 40), 3, accuracy: 0.001)
    }
}
