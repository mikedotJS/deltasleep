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
    private func fourteenNights(endingOn date: Date, calendar: Calendar, asleep: SleepDuration) -> [Night] {
        (0..<14).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: date)!
            return Night.measured(date: day, asleep: asleep)
        }
    }

    // MARK: - Weights

    func testWeightsSumToOne() {
        let w = SleepDebtEngine.weights(count: 14)
        XCTAssertEqual(w.reduce(0, +), 1.0, accuracy: 1e-9)
    }

    func testWeightsAreMonotonicallyDecreasing() {
        let w = SleepDebtEngine.weights(count: 14)
        for i in 0..<(w.count - 1) {
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

    func testConstantDeficitProducesExactDebt() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 30)) // 1h30 deficit every night
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)
        XCTAssertNotNil(snapshot)
        // A constant per-night deficit makes the weighted mean equal to
        // that same constant regardless of the specific weights, so
        // debt = 14 × 1h30 = 21h00 exactly.
        XCTAssertEqual(snapshot!.debt.seconds, SleepDuration.hm(21, 0).seconds, accuracy: 1.0)
    }

    func testSurplusAtExactCapBoundaryFloorsDebtToZero() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // 9h asleep vs 8h need → deficit exactly -1h, at the cap boundary
        // (so the cap doesn't even need to engage). Weighted mean = -1h
        // exactly; debt = 14 × -1h < 0, floored to 0 (D2).
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(9, 0))
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot!.debt.seconds, 0, accuracy: 0.001)
    }

    func testMoreRecentNightsCarryMoreWeight() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))

        func nights(badNightOffset: Int) -> [Night] {
            (0..<14).map { offset in
                let day = cal.date(byAdding: .day, value: -offset, to: today)!
                let asleep: SleepDuration = offset == badNightOffset ? .hm(4, 0) : .hm(8, 0)
                return Night.measured(date: day, asleep: asleep)
            }
        }

        let badNightRecent = SleepDebtEngine.snapshot(
            nights: nights(badNightOffset: 0), need: need, referenceDate: today, now: today, calendar: cal
        )!
        let badNightOld = SleepDebtEngine.snapshot(
            nights: nights(badNightOffset: 13), need: need, referenceDate: today, now: today, calendar: cal
        )!

        // Same single bad night, different position in the window — this
        // only needs weights to be strictly decreasing by index (true by
        // construction), not any specific value, to hold.
        XCTAssertGreaterThan(badNightRecent.debt.seconds, badNightOld.debt.seconds)
    }

    // MARK: - Gap handling

    func testGapNightCarriesYesterdaysDebtForwardExactly() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))

        // 15 nights so yesterday's own window (offsets 1...14) is also
        // fully covered. Today's last night (offset 0) is a gap; every
        // other night is a constant 6h30 (1h30 deficit).
        var nights: [Night] = []
        for offset in 0..<15 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            nights.append(offset == 0 ? .gap(date: day) : .measured(date: day, asleep: .hm(6, 30)))
        }

        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)
        XCTAssertNotNil(snapshot)
        XCTAssertTrue(snapshot!.lastNightIsGap)
        XCTAssertEqual(snapshot!.trend, .unknown)
        // Yesterday's window is constant 6h30 throughout → 21h00 exactly;
        // today's gap should carry that forward unchanged.
        XCTAssertEqual(snapshot!.debt.seconds, SleepDuration.hm(21, 0).seconds, accuracy: 1.0)
    }

    func testConsecutiveGapsRecurseToTheLastRealComputation() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))

        // Last two nights are gaps; everything from 2 days ago back is a
        // constant 6h30. Two-days-ago's own window is then fully
        // populated and non-gap, so it resolves normally, and both gap
        // nights should carry that value forward.
        var nights: [Night] = []
        for offset in 0..<16 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            nights.append(offset < 2 ? .gap(date: day) : .measured(date: day, asleep: .hm(6, 30)))
        }

        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot!.debt.seconds, SleepDuration.hm(21, 0).seconds, accuracy: 1.0)
    }

    func testGapEntirelyOutsideHistoryReturnsNil() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // Only a gap on the most recent night and nothing before it —
        // there's no earlier real computation to carry forward.
        let nights = [Night.gap(date: today)]
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)
        XCTAssertNil(snapshot)
    }

    // MARK: - History availability (D8)

    func testHistoryAvailabilityNoneWhenNoMeasuredNightsEver() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let nights = (0..<20).map { offset in Night.gap(date: cal.date(byAdding: .day, value: -offset, to: today)!) }
        XCTAssertEqual(SleepDebtEngine.historyAvailability(endingOn: today, nights: nights, calendar: cal), .none)
    }

    func testHistoryAvailabilityInsufficientWithPartialHistory() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let nights = (0..<6).map { offset in
            Night.measured(date: cal.date(byAdding: .day, value: -offset, to: today)!, asleep: .hm(7, 0))
        }
        XCTAssertEqual(
            SleepDebtEngine.historyAvailability(endingOn: today, nights: nights, calendar: cal),
            .insufficient(measuredNights: 6, requiredNights: 14)
        )
    }

    func testHistoryAvailabilitySufficientWithFullWindow() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 0))
        XCTAssertEqual(SleepDebtEngine.historyAvailability(endingOn: today, nights: nights, calendar: cal), .sufficient)
    }

    func testHistoryAvailabilityNoneWhenFullWindowIsAllGaps() {
        // A full 14-day window exists, but literally none of it (nor
        // anything before it) was ever measured — this is the "no data"
        // condition, not "wait N more days," regardless of how many
        // calendar days have elapsed.
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let nights = (0..<14).map { offset in Night.gap(date: cal.date(byAdding: .day, value: -offset, to: today)!) }
        XCTAssertEqual(SleepDebtEngine.historyAvailability(endingOn: today, nights: nights, calendar: cal), .none)
    }

    // MARK: - Trend

    func testTrendFallingWhenLastNightBeatsWeightedAverage() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 0))
        nights[0] = .measured(date: today, asleep: .hm(9, 0))
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        XCTAssertEqual(snapshot.trend, .falling)
    }

    func testTrendRisingWhenLastNightWorseThanWeightedAverage() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 0))
        nights[0] = .measured(date: today, asleep: .hm(3, 0))
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        XCTAssertEqual(snapshot.trend, .rising)
    }

    func testTrendFrozenOnNeedChange() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 0))
        nights[0] = .measured(date: today, asleep: .hm(9, 0)) // would otherwise be .falling
        let snapshot = SleepDebtEngine.snapshot(
            nights: nights, need: need, needChangedToday: true, referenceDate: today, now: today, calendar: cal
        )!
        XCTAssertEqual(snapshot.trend, .unknown)
    }

    // MARK: - Break-even target

    func testBreakEvenTargetExcludesLastNight() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // Constant 7h for every night except last night, which is an
        // arbitrary outlier — breakEvenTarget is defined over indices
        // 1...13 only, so it must come out to exactly 7h regardless.
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 0))
        nights[0] = .measured(date: today, asleep: .hm(2, 0))
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        XCTAssertEqual(snapshot.breakEvenTarget.seconds, SleepDuration.hm(7, 0).seconds, accuracy: 1.0)
    }

    // MARK: - Deltas

    func testDeltaSinceYesterdayIsZeroForAConstantPattern() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = (0..<15).map { offset in
            Night.measured(date: cal.date(byAdding: .day, value: -offset, to: today)!, asleep: .hm(6, 30))
        }
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        XCTAssertNotNil(snapshot.deltaSinceYesterday)
        XCTAssertEqual(snapshot.deltaSinceYesterday!.seconds, 0, accuracy: 1.0)
    }

    func testDeltaSinceYesterdayNilWhenYesterdaysWindowIsInsufficient() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        // Exactly 14 nights — today's window is exactly satisfied, but
        // yesterday's would need one more day of history that isn't there.
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 30))
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        XCTAssertNil(snapshot.deltaSinceYesterday)
    }

    func testDeltaSinceMondayComputedWithEnoughHistory() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = (0..<30).map { offset in
            Night.measured(date: cal.date(byAdding: .day, value: -offset, to: today)!, asleep: .hm(6, 30))
        }
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        guard let delta = snapshot.deltaSinceMonday else {
            return XCTFail("expected deltaSinceMonday to be computable with 30 days of constant history")
        }
        // Constant pattern throughout → debt is the same on every date in
        // range, so the delta is exactly 0.
        XCTAssertEqual(delta.seconds, 0, accuracy: 1.0)
    }

    func testDeltaSinceMondayNilWhenFewerThanTwoMeasuredNightsSinceMonday() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        guard let monday = SleepDebtEngine.mostRecentMonday(onOrBefore: today, calendar: cal) else {
            return XCTFail("expected a most-recent Monday")
        }

        var nights = (0..<30).map { offset in
            Night.measured(date: cal.date(byAdding: .day, value: -offset, to: today)!, asleep: .hm(6, 30))
        }
        // Turn every night from Monday through today into a gap, except
        // leave last night measured so today's own window still resolves.
        var cursor = monday
        let todayStart = cal.startOfDay(for: today)
        while cursor <= todayStart {
            if !cal.isDate(cursor, inSameDayAs: today),
               let index = nights.firstIndex(where: { cal.isDate($0.date, inSameDayAs: cursor) }) {
                nights[index] = .gap(date: cursor)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        XCTAssertNil(snapshot.deltaSinceMonday)
    }

    // MARK: - Monday calculation itself

    func testMostRecentMondayIsAMondayWithinTheLastWeek() {
        let cal = utcCalendar()
        let reference = date(2026, 8, 11, calendar: cal)
        guard let monday = SleepDebtEngine.mostRecentMonday(onOrBefore: reference, calendar: cal) else {
            return XCTFail("expected a Monday")
        }
        XCTAssertEqual(cal.component(.weekday, from: monday), 2) // Gregorian: Monday = 2
        XCTAssertLessThanOrEqual(monday, reference)
        XCTAssertGreaterThan(monday, cal.date(byAdding: .day, value: -7, to: reference)!)
    }

    func testMostRecentMondayOfAMondayIsItself() {
        let cal = utcCalendar()
        let reference = date(2026, 8, 11, calendar: cal)
        guard let monday = SleepDebtEngine.mostRecentMonday(onOrBefore: reference, calendar: cal),
              let mondayOfMonday = SleepDebtEngine.mostRecentMonday(onOrBefore: monday, calendar: cal) else {
            return XCTFail("expected both calls to resolve")
        }
        XCTAssertEqual(cal.startOfDay(for: monday), cal.startOfDay(for: mondayOfMonday))
    }

    // MARK: - Averages and counts

    func testFourteenNightAverageIsAverageSleepNotAverageDeficit() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 15))
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        XCTAssertEqual(snapshot.fourteenNightAverage.seconds, SleepDuration.hm(7, 15).seconds, accuracy: 1.0)
    }

    func testMeasuredAndGapCountsReflectTheWindow() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(7, 0))
        // Make one non-last night (offset 5) a gap.
        let gapDay = cal.date(byAdding: .day, value: -5, to: today)!
        nights[5] = .gap(date: gapDay)
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        XCTAssertEqual(snapshot.measuredNightCount, 13)
        XCTAssertEqual(snapshot.gapCount, 1)
        XCTAssertFalse(snapshot.lastNightIsGap)
    }

    // MARK: - WidgetState classification

    func testWidgetStateNominalForAnOrdinaryReading() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 0))
        nights[0] = .measured(date: today, asleep: .hm(9, 0))
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        let state = WidgetState.classify(history: .sufficient, snapshot: snapshot, staleAfter: 6 * 3600, now: today)
        guard case .nominal(_, let trend) = state else { return XCTFail("expected .nominal, got \(state)") }
        XCTAssertEqual(trend, .falling)
    }

    func testWidgetStateZeroWhenDebtFloored() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(9, 0)) // floors to 0, see above
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        let state = WidgetState.classify(history: .sufficient, snapshot: snapshot, staleAfter: 6 * 3600, now: today)
        XCTAssertEqual(state, .zero)
    }

    func testWidgetStateCachedWhenStale() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        let nights = fourteenNights(endingOn: today, calendar: cal, asleep: .hm(6, 30))
        let staleAfter: TimeInterval = 6 * 3600
        let computedAt = today
        let snapshot = SleepDebtEngine.snapshot(
            nights: nights, need: need, referenceDate: today, now: computedAt, calendar: cal
        )!
        let laterNow = computedAt.addingTimeInterval(staleAfter + 1)
        let state = WidgetState.classify(history: .sufficient, snapshot: snapshot, staleAfter: staleAfter, now: laterNow)
        XCTAssertEqual(state, .cached(computedAt: computedAt))
    }

    func testWidgetStateNightMissing() {
        let cal = utcCalendar()
        let today = date(2026, 8, 11, calendar: cal)
        let need = SleepNeed(.hm(8, 0))
        var nights: [Night] = []
        for offset in 0..<15 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            nights.append(offset == 0 ? .gap(date: day) : .measured(date: day, asleep: .hm(6, 30)))
        }
        let snapshot = SleepDebtEngine.snapshot(nights: nights, need: need, referenceDate: today, now: today, calendar: cal)!
        let state = WidgetState.classify(history: .sufficient, snapshot: snapshot, staleAfter: 6 * 3600, now: today)
        guard case .nightMissing(let carriedDebt) = state else { return XCTFail("expected .nightMissing, got \(state)") }
        XCTAssertEqual(carriedDebt.seconds, snapshot.debt.seconds, accuracy: 0.001)
    }

    func testWidgetStateNoDataAndInsufficientHistory() {
        XCTAssertEqual(
            WidgetState.classify(history: .none, snapshot: nil, staleAfter: 3600, now: Date(timeIntervalSince1970: 0)),
            .noData
        )
        XCTAssertEqual(
            WidgetState.classify(
                history: .insufficient(measuredNights: 6, requiredNights: 14),
                snapshot: nil,
                staleAfter: 3600,
                now: Date(timeIntervalSince1970: 0)
            ),
            .insufficientHistory(measuredNights: 6, requiredNights: 14)
        )
    }
}
