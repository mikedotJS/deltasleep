import Foundation
@testable import HealthSleepSource
import SleepDebtCore
import XCTest

final class SleepNightAggregatorTests: XCTestCase {
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, calendar: Calendar
    ) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour)
        return calendar.date(from: components)!
    }

    /// Hours to seconds — keeps fixture math readable and its expected
    /// values exactly comparable to what a test asserts.
    private func h(_ hours: Double) -> TimeInterval {
        hours * 3600
    }

    /// `hours` after `start` — shorthand for the repeated
    /// `start.addingTimeInterval(h(_:))` pattern in multi-sample fixtures.
    private func at(_ start: Date, _ hours: Double) -> Date {
        start.addingTimeInterval(h(hours))
    }

    private func sample(
        _ stage: RawSleepSample.Stage,
        from start: Date,
        to end: Date,
        source: String = "com.apple.health"
    ) -> RawSleepSample {
        RawSleepSample(stage: stage, startDate: start, endDate: end, sourceBundleID: source)
    }

    // MARK: - noonWindow

    func testNoonWindowSpansNoonToNoon() {
        let cal = utcCalendar()
        let day = date(2026, 8, 11, 0, calendar: cal)
        let window = SleepNightAggregator.noonWindow(endingOn: day, calendar: cal)
        XCTAssertEqual(window.lowerBound, date(2026, 8, 10, 12, calendar: cal))
        XCTAssertEqual(window.upperBound, date(2026, 8, 11, 12, calendar: cal))
    }

    func testASampleEndingAtSevenAMFallsInTheWindowEndingThatDay() {
        let cal = utcCalendar()
        let day = date(2026, 8, 11, 0, calendar: cal)
        let window = SleepNightAggregator.noonWindow(endingOn: day, calendar: cal)
        XCTAssertTrue(window.contains(date(2026, 8, 11, 7, calendar: cal)))
    }

    func testExactlyNoonBelongsToTheNextWindowNotThisOne() {
        // Half-open at the upper bound — a sample ending exactly at noon
        // belongs to the *next* day's window, never both.
        let cal = utcCalendar()
        let day = date(2026, 8, 11, 0, calendar: cal)
        let window = SleepNightAggregator.noonWindow(endingOn: day, calendar: cal)
        XCTAssertFalse(window.contains(window.upperBound))
    }

    // MARK: - clip

    func testClipInsideBoundsIsUnchanged() {
        let cal = utcCalendar()
        let noon = date(2026, 8, 10, 12, calendar: cal)
        let bounds = noon ..< noon.addingTimeInterval(h(24))
        let interval = date(2026, 8, 10, 23, calendar: cal) ..< date(2026, 8, 11, 7, calendar: cal)
        XCTAssertEqual(SleepNightAggregator.clip(interval, to: bounds), interval)
    }

    func testClipTrimsAStartBeforeBounds() throws {
        let cal = utcCalendar()
        let noon = date(2026, 8, 10, 12, calendar: cal)
        let bounds = noon ..< noon.addingTimeInterval(h(24))
        // Starts before the window opens, ends within it.
        let start = noon.addingTimeInterval(-h(0.25)) // 11:45
        let end = date(2026, 8, 11, 1, calendar: cal)
        let clipped = try XCTUnwrap(SleepNightAggregator.clip(start ..< end, to: bounds))
        XCTAssertEqual(clipped.lowerBound, bounds.lowerBound)
        XCTAssertEqual(clipped.upperBound, end)
    }

    func testClipReturnsNilForNoOverlap() {
        let cal = utcCalendar()
        let noon = date(2026, 8, 10, 12, calendar: cal)
        let bounds = noon ..< noon.addingTimeInterval(h(24))
        let interval = date(2026, 8, 9, 1, calendar: cal) ..< date(2026, 8, 9, 5, calendar: cal)
        XCTAssertNil(SleepNightAggregator.clip(interval, to: bounds))
    }

    // MARK: - unionDuration

    func testUnionDurationOfEmptyIsZero() {
        XCTAssertEqual(SleepNightAggregator.unionDuration(of: []), 0)
    }

    func testUnionDurationOfASingleInterval() {
        let cal = utcCalendar()
        let start = date(2026, 8, 10, 23, calendar: cal)
        let interval = start ..< start.addingTimeInterval(h(8))
        XCTAssertEqual(SleepNightAggregator.unionDuration(of: [interval]), h(8), accuracy: 0.001)
    }

    func testUnionDurationMergesFullyOverlappingDuplicates() {
        // Two sources reporting the identical 4h stretch — the point of
        // interval union over "prefer one source": this must count once.
        let cal = utcCalendar()
        let start = date(2026, 8, 10, 23, calendar: cal)
        let interval = start ..< start.addingTimeInterval(h(4))
        let total = SleepNightAggregator.unionDuration(of: [interval, interval])
        XCTAssertEqual(total, h(4), accuracy: 0.001)
    }

    func testUnionDurationMergesPartiallyOverlappingIntervals() {
        // A: 23:00-02:00 (3h), B: 01:00-04:00 (3h), overlap 01:00-02:00.
        // Naive sum would be 6h; the union is 23:00-04:00 = 5h.
        let cal = utcCalendar()
        let start = date(2026, 8, 10, 23, calendar: cal)
        let a = start ..< start.addingTimeInterval(h(3))
        let b = start.addingTimeInterval(h(2)) ..< start.addingTimeInterval(h(5))
        XCTAssertEqual(SleepNightAggregator.unionDuration(of: [a, b]), h(5), accuracy: 0.001)
    }

    func testUnionDurationMergesExactlyAdjacentIntervals() {
        let cal = utcCalendar()
        let start = date(2026, 8, 10, 23, calendar: cal)
        let a = start ..< start.addingTimeInterval(h(2))
        let b = start.addingTimeInterval(h(2)) ..< start.addingTimeInterval(h(4))
        XCTAssertEqual(SleepNightAggregator.unionDuration(of: [a, b]), h(4), accuracy: 0.001)
    }

    func testUnionDurationKeepsDisjointIntervalsSeparate() {
        // A real 30-minute gap between two asleep intervals must not be
        // bridged — the union should be exactly the sum, not the span.
        let cal = utcCalendar()
        let start = date(2026, 8, 10, 23, calendar: cal)
        let a = start ..< start.addingTimeInterval(h(2)) // 2h
        let b = start.addingTimeInterval(h(2.5)) ..< start.addingTimeInterval(h(5)) // 2.5h
        XCTAssertEqual(SleepNightAggregator.unionDuration(of: [a, b]), h(4.5), accuracy: 0.001)
    }

    func testUnionDurationSortsUnorderedInput() {
        let cal = utcCalendar()
        let start = date(2026, 8, 10, 23, calendar: cal)
        let a = start.addingTimeInterval(h(2)) ..< start.addingTimeInterval(h(4))
        let b = start ..< start.addingTimeInterval(h(2))
        // Passed out of order — result must not depend on input order.
        XCTAssertEqual(SleepNightAggregator.unionDuration(of: [a, b]), h(4), accuracy: 0.001)
    }

    // MARK: - nights: gap vs. zero vs. measured

    func testNoSamplesAtAllIsAGap() {
        let cal = utcCalendar()
        let day = date(2026, 8, 11, 0, calendar: cal)
        let nights = SleepNightAggregator.nights(from: [], forDays: [day], calendar: cal)
        XCTAssertEqual(nights.count, 1)
        XCTAssertTrue(nights[0].isGap)
    }

    func testSamplesPresentButNoAsleepStageIsMeasuredZeroNotAGap() {
        // Only inBed/awake — HealthKit *has* data for this night, it's
        // just a night with no recorded sleep. A real, if extreme, value.
        let cal = utcCalendar()
        let day = date(2026, 8, 11, 0, calendar: cal)
        let start = date(2026, 8, 10, 23, calendar: cal)
        let samples = [
            sample(.inBed, from: start, to: at(start, 7)),
            sample(.awake, from: at(start, 7), to: at(start, 7.5)),
        ]
        let nights = SleepNightAggregator.nights(from: samples, forDays: [day], calendar: cal)
        XCTAssertFalse(nights[0].isGap)
        XCTAssertEqual(nights[0].asleep?.seconds, 0, accuracy: 0.001)
    }

    func testSimpleSingleSourceNight() {
        let cal = utcCalendar()
        let day = date(2026, 8, 11, 0, calendar: cal)
        let start = date(2026, 8, 10, 23, calendar: cal)
        let samples = [sample(.asleepCore, from: start, to: at(start, 8))]
        let nights = SleepNightAggregator.nights(from: samples, forDays: [day], calendar: cal)
        XCTAssertEqual(nights[0].asleep?.seconds, h(8), accuracy: 0.001)
    }

    func testExcludesInBedAndAwakeFromTheAsleepTotal() {
        let cal = utcCalendar()
        let day = date(2026, 8, 11, 0, calendar: cal)
        let start = at(date(2026, 8, 10, 22, calendar: cal), 0.5) // 22:30
        let samples = [
            sample(.inBed, from: start, to: at(start, 0.5)),
            sample(.asleepCore, from: at(start, 0.5), to: at(start, 3.5)),
            sample(.awake, from: at(start, 3.5), to: at(start, 3.75)),
            sample(.asleepREM, from: at(start, 3.75), to: at(start, 7.5)),
        ]
        let nights = SleepNightAggregator.nights(from: samples, forDays: [day], calendar: cal)
        // 3h core + 3h45 REM = 6h45, excluding the 30min inBed and 15min awake.
        XCTAssertEqual(nights[0].asleep?.seconds, h(6.75), accuracy: 0.001)
    }

    func testCrossSourceOverlapDoesNotDoubleCount() {
        let cal = utcCalendar()
        let day = date(2026, 8, 11, 0, calendar: cal)
        let start = date(2026, 8, 10, 23, calendar: cal)
        let end = start.addingTimeInterval(h(4))
        let samples = [
            sample(.asleepCore, from: start, to: end, source: "com.apple.health"),
            sample(.asleepCore, from: start, to: end, source: "com.thirdparty.sleeptracker"),
        ]
        let nights = SleepNightAggregator.nights(from: samples, forDays: [day], calendar: cal)
        XCTAssertEqual(nights[0].asleep?.seconds, h(4), accuracy: 0.001)
    }

    func testMultipleDaysEachGetTheirOwnNight() {
        let cal = utcCalendar()
        let day1 = date(2026, 8, 10, 0, calendar: cal)
        let day2 = date(2026, 8, 11, 0, calendar: cal)
        let start1 = date(2026, 8, 9, 23, calendar: cal)
        let start2 = date(2026, 8, 10, 23, calendar: cal)
        let samples = [
            sample(.asleepCore, from: start1, to: start1.addingTimeInterval(h(7))),
            sample(.asleepCore, from: start2, to: start2.addingTimeInterval(h(8))),
        ]
        let nights = SleepNightAggregator.nights(
            from: samples, forDays: [day1, day2], calendar: cal
        )
        XCTAssertEqual(nights.count, 2)
        XCTAssertEqual(nights[0].asleep?.seconds, h(7), accuracy: 0.001)
        XCTAssertEqual(nights[1].asleep?.seconds, h(8), accuracy: 0.001)
    }
}
