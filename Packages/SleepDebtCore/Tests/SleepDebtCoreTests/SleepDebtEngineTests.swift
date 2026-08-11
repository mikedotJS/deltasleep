import Foundation
import XCTest
@testable import SleepDebtCore

/// This package has never been compiled (see docs/IMPLEMENTATION_PLAN.md's
/// P1 status notes) — CI is the first real verification. These fixtures
/// are deliberately built so their expected values are exact by
/// construction wherever possible (constant sleep across the whole
/// window, so the specific weight distribution cancels out of the
/// answer), rather than requiring precise by-hand arithmetic on the
/// geometric weights that this file's author couldn't run to check.
final class SleepDebtEngineTests: XCTestCase {
    // MARK: - Fixture helpers

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// 14 consecutive nights ending on `date`, all with the same
    /// `asleep` duration.
    private func fourteenNights(
        endingOn date: Date, calendar: Calendar, asleep: SleepDuration
    ) -> [Night] {
        (0 ..< 14).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: date)!
            return Night.measured(date: day, asleep: asleep)
        }
    }

    /// `offset` calendar days before `date`. Lives outside any `test...`
    /// method so its `XCTUnwrap` (rather than a bare `!`) reads plainly —
    /// `Calendar.date(byAdding:...)` essentially can't fail for these
    /// small, in-range offsets, but the project's SwiftFormat config bans
    /// force-unwraps inside test methods regardless.
    private func day(offset: Int, before date: Date, calendar: Calendar) throws -> Date {
        try XCTUnwrap(calendar.date(byAdding: .day, value: -offset, to: date))
    }

    /// Thin wrapper over `SleepDebtEngine.snapshot` for tests where
    /// `now == referenceDate`, which is nearly all of them — keeps call
    /// sites short.
    private func snapshot(
        nights: [Night],
        need: SleepNeed,
        needChangedToday: Bool = false,
        referenceDate: Date,
        calendar: Calendar
    ) -> DebtSnapshot? {
        SleepDebtEngine.snapshot(
            nights: nights,
            need: need,
            needChangedToday: needChangedToday,
            referenceDate: referenceDate,
            now: referenceDate,
            calendar: calendar
        )
    }

    // MARK: - Weights

    func testWeightsSumToOne() {
        let w = SleepDebtEngine.weights(count: 14)
        XCTAssertEqual(w.reduce(0, +), 1.0, accuracy: 1e-9)
    }

    func testWeightsAreMonotonicallyDecreasing() {
        let w = SleepDebtEngine.weights(count: 14)
        for i in 0 ..< (w.count - 1) {
            XCTAssertGreaterThan(w[i], w[i + 1])
        }
    }

    func testMostRecentWeightIsApproximatelyFifteenPercent() {
        // Fit by hand against the design's "15% for last night" framing
        // (docs/IMPLEMENTATION_PLAN.md §1.1) — generous tolerance, since
        // the fit was done without being able to run this computation.
        let w = SleepDebtEngine.weights(count: 14)
        XCTAssertEqual(w[0], 0.15, accuracy: 0.015)
    }

    func testWeightsOfEmptyWindowIsEmpty() {
        XCTAssertEqual(SleepDebtEngine.weights(count: 0), [])
    }

    // MARK: - Per-night deficit and the surplus-credit cap (D2)

    func testDeficitWithNoSurplusOrDeficit() {
        let need = SleepNeed(.hm(8, 0))
        let d = SleepDebtEngine.deficit(asleep: .hm(8, 0), need: need)
        XCTAssertEqual(d.seconds, 0, accuracy: 0.001)
    }

    func testDeficitUncappedOnTheShortfallSide() {
        let need = SleepNeed(.hm(8, 0))
        // 3h asleep vs 8h need → +5h deficit, no cap on this side.
        let d = SleepDebtEngine.deficit(asleep: .hm(3, 0), need: need)
        XCTAssertEqual(d.seconds, SleepDuration.hours(5).seconds, accuracy: 0.001)
    }

    func testDeficitBelowCapIsUnaffected() {
        let need = SleepNeed(.hm(8, 0))
        // 8h30 vs 8h need → -30min surplus, well within the 1h cap.
        let d = SleepDebtEngine.deficit(asleep: .hm(8, 30), need: need)
        XCTAssertEqual(d.seconds, SleepDuration.minutes(-30).seconds, accuracy: 0.001)
    }

    func testDeficitSurplusCappedAtOneHour() {
        let need = SleepNeed(.hm(8, 0))
        // 11h vs 8h need → raw surplus credit would be -3h; D2 caps it at -1h.
        let d = SleepDebtEngine.deficit(asleep: .hm(11, 0), need: need)
        XCTAssertEqual(d.seconds, SleepDuration.hours(-1).seconds, accuracy: 0.001)
    }

    // MARK: - Debt formula: exact fixtures (constant sleep across the window)

    func testConstantDeficitProducesExactDebt() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 30))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        // A constant per-night deficit makes the weighted mean equal to
        // that same constant regardless of the specific weights, so
        // debt = 14 × 1h30 = 21h00 exactly.
        XCTAssertEqual(result.debt.seconds, SleepDuration.hm(21, 0).seconds, accuracy: 1.0)
    }

    func testSurplusAtExactCapBoundaryFloorsDebtToZero() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // 9h asleep vs 8h need → deficit exactly -1h, at the cap boundary
        // (so the cap doesn't even need to engage). Weighted mean = -1h
        // exactly; debt = 14 × -1h < 0, floored to 0 (D2).
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(9, 0))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertEqual(result.debt.seconds, 0, accuracy: 0.001)
    }

    func testMoreRecentNightsCarryMoreWeight() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))

        func nights(badNightOffset: Int) throws -> [Night] {
            try (0 ..< 14).map { offset in
                let day = try day(offset: offset, before: today, calendar: cal)
                let asleep: SleepDuration = offset == badNightOffset ? .hm(4, 0) : .hm(8, 0)
                return Night.measured(date: day, asleep: asleep)
            }
        }

        let recentNights = try nights(badNightOffset: 0)
        let oldNights = try nights(badNightOffset: 13)
        let badNightRecent = try XCTUnwrap(
            snapshot(nights: recentNights, need: need, referenceDate: today, calendar: cal)
        )
        let badNightOld = try XCTUnwrap(
            snapshot(nights: oldNights, need: need, referenceDate: today, calendar: cal)
        )

        // Same single bad night, different position in the window — this
        // only needs weights to be strictly decreasing by index (true by
        // construction), not any specific value, to hold.
        XCTAssertGreaterThan(badNightRecent.debt.seconds, badNightOld.debt.seconds)
    }

    // MARK: - Gap handling

    func testGapNightCarriesYesterdaysDebtForwardExactly() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))

        // 15 nights so yesterday's own window (offsets 1...14) is also
        // fully covered. Today's last night (offset 0) is a gap; every
        // other night is a constant 6h30 (1h30 deficit).
        var nights: [Night] = []
        for offset in 0 ..< 15 {
            let day = try day(offset: offset, before: today, calendar: cal)
            nights.append(offset == 0 ? .gap(date: day) : .measured(date: day, asleep: .hm(6, 30)))
        }

        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertTrue(result.lastNightIsGap)
        XCTAssertEqual(result.trend, .unknown)
        // Yesterday's window is constant 6h30 throughout → 21h00 exactly;
        // today's gap should carry that forward unchanged.
        XCTAssertEqual(result.debt.seconds, SleepDuration.hm(21, 0).seconds, accuracy: 1.0)
    }

    func testConsecutiveGapsRecurseToTheLastRealComputation() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))

        // Last two nights are gaps; everything from 2 days ago back is a
        // constant 6h30. Two-days-ago's own window is then fully
        // populated and non-gap, so it resolves normally, and both gap
        // nights should carry that value forward.
        var nights: [Night] = []
        for offset in 0 ..< 16 {
            let day = try day(offset: offset, before: today, calendar: cal)
            nights.append(offset < 2 ? .gap(date: day) : .measured(date: day, asleep: .hm(6, 30)))
        }

        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertEqual(result.debt.seconds, SleepDuration.hm(21, 0).seconds, accuracy: 1.0)
    }

    func testGapEntirelyOutsideHistoryReturnsNil() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // Only a gap on the most recent night and nothing before it —
        // there's no earlier real computation to carry forward.
        let nights = [Night.gap(date: today)]
        let result = snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        XCTAssertNil(result)
    }

    // MARK: - History availability (D8)

    func testHistoryAvailabilityNoneWhenNoMeasuredNightsEver() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let nights = try (0 ..< 20).map { offset in
            try Night.gap(date: day(offset: offset, before: today, calendar: cal))
        }
        let availability = SleepDebtEngine.historyAvailability(
            endingOn: today, nights: nights, calendar: cal
        )
        XCTAssertEqual(availability, .none)
    }

    func testHistoryAvailabilityInsufficientWithPartialHistory() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let nights = try (0 ..< 6).map { offset in
            try Night.measured(
                date: day(offset: offset, before: today, calendar: cal), asleep: .hm(7, 0)
            )
        }
        let availability = SleepDebtEngine.historyAvailability(
            endingOn: today, nights: nights, calendar: cal
        )
        XCTAssertEqual(availability, .insufficient(measuredNights: 6, requiredNights: 14))
    }

    func testHistoryAvailabilitySufficientWithFullWindow() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 0))
        let availability = SleepDebtEngine.historyAvailability(
            endingOn: today, nights: nights, calendar: cal
        )
        XCTAssertEqual(availability, .sufficient)
    }

    func testHistoryAvailabilityNoneWhenFullWindowIsAllGaps() throws {
        // A full 14-day window exists, but literally none of it (nor
        // anything before it) was ever measured — this is the "no data"
        // condition, not "wait N more days," regardless of how many
        // calendar days have elapsed.
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let nights = try (0 ..< 14).map { offset in
            try Night.gap(date: day(offset: offset, before: today, calendar: cal))
        }
        let availability = SleepDebtEngine.historyAvailability(
            endingOn: today, nights: nights, calendar: cal
        )
        XCTAssertEqual(availability, .none)
    }

    // MARK: - Trend

    func testTrendFallingWhenLastNightBeatsWeightedAverage() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 0))
        nights[0] = .measured(date: today, asleep: .hm(9, 0))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertEqual(result.trend, .falling)
    }

    func testTrendRisingWhenLastNightWorseThanWeightedAverage() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 0))
        nights[0] = .measured(date: today, asleep: .hm(3, 0))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertEqual(result.trend, .rising)
    }

    func testTrendFrozenOnNeedChange() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 0))
        nights[0] = .measured(date: today, asleep: .hm(9, 0)) // would otherwise be .falling
        let result = try XCTUnwrap(
            snapshot(
                nights: nights,
                need: need,
                needChangedToday: true,
                referenceDate: today,
                calendar: cal
            )
        )
        XCTAssertEqual(result.trend, .unknown)
    }

    // MARK: - Break-even target

    func testBreakEvenTargetExcludesLastNight() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // Constant 7h for every night except last night, which is an
        // arbitrary outlier — breakEvenTarget is defined over indices
        // 1...13 only, so it must come out to exactly 7h regardless.
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 0))
        nights[0] = .measured(date: today, asleep: .hm(2, 0))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertEqual(
            result.breakEvenTarget.seconds, SleepDuration.hm(7, 0).seconds, accuracy: 1.0
        )
    }

    // MARK: - Deltas

    func testDeltaSinceYesterdayIsZeroForAConstantPattern() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = try (0 ..< 15).map { offset in
            try Night.measured(
                date: day(offset: offset, before: today, calendar: cal), asleep: .hm(6, 30)
            )
        }
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        let delta = try XCTUnwrap(result.deltaSinceYesterday)
        XCTAssertEqual(delta.seconds, 0, accuracy: 1.0)
    }

    func testDeltaSinceYesterdayNilWhenYesterdaysWindowIsInsufficient() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // Exactly 14 nights — today's window is exactly satisfied, but
        // yesterday's would need one more day of history that isn't there.
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 30))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertNil(result.deltaSinceYesterday)
    }

    func testDeltaSinceMondayComputedWithEnoughHistory() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = try (0 ..< 30).map { offset in
            try Night.measured(
                date: day(offset: offset, before: today, calendar: cal), asleep: .hm(6, 30)
            )
        }
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        let delta = try XCTUnwrap(
            result.deltaSinceMonday,
            "expected deltaSinceMonday to be computable with 30 days of constant history"
        )
        // Constant pattern throughout → debt is the same on every date in
        // range, so the delta is exactly 0.
        XCTAssertEqual(delta.seconds, 0, accuracy: 1.0)
    }

    func testDeltaSinceMondayNilWhenFewerThanTwoMeasuredNightsSinceMonday() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let monday = try XCTUnwrap(
            SleepDebtEngine.mostRecentMonday(onOrBefore: today, calendar: cal)
        )

        var nights = try (0 ..< 30).map { offset in
            try Night.measured(
                date: day(offset: offset, before: today, calendar: cal), asleep: .hm(6, 30)
            )
        }
        // Turn every night from Monday through today into a gap, except
        // leave last night measured so today's own window still resolves.
        var cursor = monday
        let todayStart = cal.startOfDay(for: today)
        while cursor <= todayStart {
            if
                !cal.isDate(cursor, inSameDayAs: today),
                let index = nights.firstIndex(where: { cal.isDate($0.date, inSameDayAs: cursor) })
            {
                nights[index] = .gap(date: cursor)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertNil(result.deltaSinceMonday)
    }

    // MARK: - Monday calculation itself

    func testMostRecentMondayIsAMondayWithinTheLastWeek() throws {
        let cal = utcCalendar()
        let reference = date(2026, 8, 11, calendar: cal)
        let monday = try XCTUnwrap(
            SleepDebtEngine.mostRecentMonday(onOrBefore: reference, calendar: cal)
        )
        XCTAssertEqual(cal.component(.weekday, from: monday), 2) // Gregorian: Monday = 2
        XCTAssertLessThanOrEqual(monday, reference)
        let aWeekBefore = try XCTUnwrap(cal.date(byAdding: .day, value: -7, to: reference))
        XCTAssertGreaterThan(monday, aWeekBefore)
    }

    func testMostRecentMondayOfAMondayIsItself() throws {
        let cal = utcCalendar()
        let reference = date(2026, 8, 11, calendar: cal)
        let monday = try XCTUnwrap(
            SleepDebtEngine.mostRecentMonday(onOrBefore: reference, calendar: cal)
        )
        let mondayOfMonday = try XCTUnwrap(
            SleepDebtEngine.mostRecentMonday(onOrBefore: monday, calendar: cal)
        )
        XCTAssertEqual(cal.startOfDay(for: monday), cal.startOfDay(for: mondayOfMonday))
    }

    // MARK: - Averages and counts

    func testFourteenNightAverageIsAverageSleepNotAverageDeficit() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 15))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertEqual(
            result.fourteenNightAverage.seconds, SleepDuration.hm(7, 15).seconds, accuracy: 1.0
        )
    }

    func testMeasuredAndGapCountsReflectTheWindow() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 0))
        // Make one non-last night (offset 5) a gap.
        let gapDay = try day(offset: 5, before: today, calendar: cal)
        nights[5] = .gap(date: gapDay)
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertEqual(result.measuredNightCount, 13)
        XCTAssertEqual(result.gapCount, 1)
        XCTAssertFalse(result.lastNightIsGap)
    }

    // MARK: - Last night's raw sleep duration (P7's "Cette nuit" stat row)

    func testLastNightSleepDurationIsLastNightsRawAsleepTime() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 0))
        nights[0] = .measured(date: today, asleep: .hm(6, 12))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        let lastNight = try XCTUnwrap(result.lastNightSleepDuration)
        XCTAssertEqual(lastNight.seconds, SleepDuration.hm(6, 12).seconds, accuracy: 0.001)
    }

    func testLastNightSleepDurationIsNilWhenLastNightIsAGap() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights: [Night] = []
        for offset in 0 ..< 15 {
            let day = try day(offset: offset, before: today, calendar: cal)
            nights.append(offset == 0 ? .gap(date: day) : .measured(date: day, asleep: .hm(7, 0)))
        }
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertNil(result.lastNightSleepDuration)
    }

    // MARK: - Night strip bars (P6's widget-strip data)

    func testNightBarsHasOneEntryPerWindowNight() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(8, 0))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertEqual(result.nightBars.count, 14)
    }

    func testNightBarsAreOrderedOldestFirstMostRecentLast() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // Every night sleeps exactly at need (a flat, un-telling fixture)
        // except last night, which surpluses hard — since surplus/deficit
        // is what a bar's isSurplus encodes, this pins which end of the
        // array is "last night" unambiguously.
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(8, 0))
        nights[0] = .measured(date: today, asleep: .hm(10, 0))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        XCTAssertTrue(result.nightBars.last?.isSurplus ?? false)
        for bar in result.nightBars.dropLast() {
            XCTAssertFalse(bar.isSurplus)
        }
    }

    func testNightBarsMarksGapNightsAsGaps() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 0))
        let gapDay = try day(offset: 5, before: today, calendar: cal)
        nights[5] = .gap(date: gapDay)
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        // offset 5 before today lands at index (14 - 1 - 5) = 8 once
        // reversed to oldest-first.
        XCTAssertTrue(result.nightBars[8].isGap)
        XCTAssertEqual(result.nightBars.filter(\.isGap).count, 1)
    }

    // MARK: - WidgetState classification

    func testWidgetStateNominalForAnOrdinaryReading() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 0))
        nights[0] = .measured(date: today, asleep: .hm(9, 0))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        let state = WidgetState.classify(
            history: .sufficient, snapshot: result, staleAfter: 6 * 3600, now: today
        )
        guard case let .nominal(_, trend) = state else {
            return XCTFail("expected .nominal, got \(state)")
        }
        XCTAssertEqual(trend, .falling)
    }

    func testWidgetStateZeroWhenDebtFloored() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // 9h asleep vs 8h need floors debt to 0, as in the exact-fixture test above.
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(9, 0))
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        let state = WidgetState.classify(
            history: .sufficient, snapshot: result, staleAfter: 6 * 3600, now: today
        )
        XCTAssertEqual(state, .zero)
    }

    func testWidgetStateCachedWhenStale() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 30))
        let staleAfter: TimeInterval = 6 * 3600
        let computedAt = today
        let result = try XCTUnwrap(
            SleepDebtEngine.snapshot(
                nights: nights, need: need, referenceDate: today, now: computedAt, calendar: cal
            )
        )
        let laterNow = computedAt.addingTimeInterval(staleAfter + 1)
        let state = WidgetState.classify(
            history: .sufficient, snapshot: result, staleAfter: staleAfter, now: laterNow
        )
        XCTAssertEqual(state, .cached(computedAt: computedAt))
    }

    func testWidgetStateNightMissing() throws {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights: [Night] = []
        for offset in 0 ..< 15 {
            let day = try day(offset: offset, before: today, calendar: cal)
            nights.append(offset == 0 ? .gap(date: day) : .measured(date: day, asleep: .hm(6, 30)))
        }
        let result = try XCTUnwrap(
            snapshot(nights: nights, need: need, referenceDate: today, calendar: cal)
        )
        let state = WidgetState.classify(
            history: .sufficient, snapshot: result, staleAfter: 6 * 3600, now: today
        )
        guard case let .nightMissing(carriedDebt) = state else {
            return XCTFail("expected .nightMissing, got \(state)")
        }
        XCTAssertEqual(carriedDebt.seconds, result.debt.seconds, accuracy: 0.001)
    }

    func testWidgetStateNoDataAndInsufficientHistory() {
        let epoch = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(
            WidgetState.classify(history: .none, snapshot: nil, staleAfter: 3600, now: epoch),
            .noData
        )
        XCTAssertEqual(
            WidgetState.classify(
                history: .insufficient(measuredNights: 6, requiredNights: 14),
                snapshot: nil,
                staleAfter: 3600,
                now: epoch
            ),
            .insufficientHistory(measuredNights: 6, requiredNights: 14)
        )
    }
}
