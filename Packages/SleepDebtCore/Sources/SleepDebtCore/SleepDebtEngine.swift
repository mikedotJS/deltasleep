import Foundation

/// The weighted sleep-debt computation. See docs/IMPLEMENTATION_PLAN.md
/// §1.1 for the derivation and the constants' provenance.
///
/// Two public entry points: `historyAvailability`, which the caller
/// should check first, and `snapshot`, which computes the full result once
/// history is known to be sufficient. Everything else here is an
/// implementation detail, `internal` rather than `public` but reachable
/// from tests via `@testable import`.
public enum SleepDebtEngine {

    // MARK: - Weights

    /// Position-based weights for a window of `count` nights, index 0 =
    /// most recent. Sums to 1 by construction — true regardless of
    /// `ratio`'s exact value, since this is just geometric-series
    /// normalization.
    static func weights(count: Int, ratio: Double = DebtEngineConstants.weightRatio) -> [Double] {
        guard count > 0 else { return [] }
        let raw = (0..<count).map { pow(ratio, Double($0)) }
        let total = raw.reduce(0, +)
        guard total > 0 else { return Array(repeating: 1.0 / Double(count), count: count) }
        return raw.map { $0 / total }
    }

    // MARK: - Per-night deficit

    /// `need - asleep`, credited (made more negative) by surplus sleep but
    /// capped at `DebtEngineConstants.surplusCreditCap` (D2) — one long
    /// night pays down at most that much of a night's debt. Deficit
    /// itself is uncapped above; an unusually short night isn't limited.
    static func deficit(asleep: SleepDuration, need: SleepNeed) -> SleepDuration {
        let raw = need.duration - asleep
        return raw.clamped(low: -DebtEngineConstants.surplusCreditCap)
    }

    // MARK: - Windowing

    /// Exactly `DebtEngineConstants.windowSize` nights ending on `date`
    /// (inclusive), index 0 = `date` itself, most-recent-first. `nil` if
    /// any of those calendar days has no `Night` entry — the caller (P2)
    /// is expected to supply an explicit `.gap` night for a genuinely
    /// missing day, so a missing dictionary entry means insufficient
    /// history, not a gap.
    static func window(
        endingOn date: Date,
        lookup: [Date: Night],
        calendar: Calendar
    ) -> [Night]? {
        var result: [Night] = []
        result.reserveCapacity(DebtEngineConstants.windowSize)
        for offset in 0..<DebtEngineConstants.windowSize {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            guard let night = lookup[calendar.startOfDay(for: day)] else { return nil }
            result.append(night)
        }
        return result
    }

    /// Whether there's enough history ending on `date` to compute a
    /// snapshot, and if not, why.
    ///
    /// A window with zero measured nights *ever* — not just within this
    /// 14-day slice — classifies as `.none`, not `.insufficient`: waiting
    /// longer won't help someone whose phone has nothing writing sleep
    /// data, so that's the same "no data" condition as a fresh install,
    /// not an onboarding-in-progress one.
    public static func historyAvailability(
        endingOn date: Date,
        nights: [Night],
        calendar: Calendar
    ) -> HistoryAvailability {
        var lookup: [Date: Night] = [:]
        for night in nights {
            lookup[calendar.startOfDay(for: night.date)] = night
        }
        let totalMeasured = lookup.values.filter { !$0.isGap }.count
        guard totalMeasured > 0 else { return .none }

        guard let win = window(endingOn: date, lookup: lookup, calendar: calendar),
              win.contains(where: { !$0.isGap }) else {
            return .insufficient(measuredNights: totalMeasured, requiredNights: DebtEngineConstants.minimumHistoryNights)
        }
        return .sufficient
    }

    // MARK: - Debt, with gap carry-forward

    /// Debt as of `date`, per the weighted formula — unless last night
    /// (window index 0) is a gap, in which case this returns whatever
    /// debt was as of the most recent date that resolved to a real
    /// computation, unchanged (recurses backward through a run of
    /// consecutive gap nights; bounded by however much history exists).
    static func debtSeconds(
        endingOn date: Date,
        lookup: [Date: Night],
        need: SleepNeed,
        calendar: Calendar
    ) -> Double? {
        guard let win = window(endingOn: date, lookup: lookup, calendar: calendar) else { return nil }
        guard win.contains(where: { !$0.isGap }) else { return nil }

        if win[0].isGap {
            guard let priorDate = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
            return debtSeconds(endingOn: priorDate, lookup: lookup, need: need, calendar: calendar)
        }

        let w = weights(count: win.count)
        var presentWeight = 0.0
        var weightedDeficit = 0.0
        for (index, night) in win.enumerated() {
            guard let asleep = night.asleep else { continue }
            presentWeight += w[index]
            weightedDeficit += w[index] * deficit(asleep: asleep, need: need).seconds
        }
        guard presentWeight > 0 else { return nil }
        let meanDeficit = weightedDeficit / presentWeight
        return max(0, Double(DebtEngineConstants.windowSize) * meanDeficit)
    }

    // MARK: - Trend and break-even

    /// The recency-weighted average sleep across window indices 1...13
    /// (everything except last night), renormalized among themselves.
    /// `nil` if none of those nights are measured.
    static func impliedAverageSleepSeconds(window: [Night]) -> Double? {
        guard window.count > 1 else { return nil }
        let w = weights(count: window.count)
        var presentWeight = 0.0
        var weightedSleep = 0.0
        for index in 1..<window.count {
            guard let asleep = window[index].asleep else { continue }
            presentWeight += w[index]
            weightedSleep += w[index] * asleep.seconds
        }
        guard presentWeight > 0 else { return nil }
        return weightedSleep / presentWeight
    }

    private static let trendEpsilonSeconds: Double = 30

    // MARK: - Calendar helpers

    static func mostRecentMonday(onOrBefore date: Date, calendar: Calendar) -> Date? {
        // Gregorian `.weekday`: Sunday = 1 ... Saturday = 7, so Monday = 2.
        let weekday = calendar.component(.weekday, from: date)
        let daysSinceMonday = (weekday - 2 + 7) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: date)
    }

    static func countMeasuredNights(
        from start: Date,
        through end: Date,
        lookup: [Date: Night],
        calendar: Calendar
    ) -> Int {
        var count = 0
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while cursor <= last {
            if let night = lookup[cursor], !night.isGap { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return count
    }

    // MARK: - Public entry point

    /// Computes the full snapshot for `referenceDate`, or `nil` if there
    /// isn't a sufficient contiguous 14-night window ending there. Call
    /// `historyAvailability` first — this function doesn't distinguish
    /// "insufficient" from "none" the way that one does.
    ///
    /// `nights` needs an explicit entry (measured or `.gap`) for every
    /// calendar day back through the earlier of "14 days before
    /// `referenceDate`" and "14 days before the most recent Monday" —
    /// a day with no entry at all is treated as missing history, not a
    /// gap. Order doesn't matter; duplicates for the same calendar day
    /// take the last one seen.
    ///
    /// `now` and `calendar` are required, not defaulted, so this stays
    /// fully deterministic given its inputs — this package has never been
    /// compiled, only reasoned about, so nothing here reads the system
    /// clock or `Calendar.current` implicitly.
    public static func snapshot(
        nights: [Night],
        need: SleepNeed,
        needChangedToday: Bool = false,
        referenceDate: Date,
        now: Date,
        calendar: Calendar
    ) -> DebtSnapshot? {
        var lookup: [Date: Night] = [:]
        for night in nights {
            lookup[calendar.startOfDay(for: night.date)] = night
        }
        let today = calendar.startOfDay(for: referenceDate)

        guard let todayDebtSeconds = debtSeconds(endingOn: today, lookup: lookup, need: need, calendar: calendar),
              let todayWindow = window(endingOn: today, lookup: lookup, calendar: calendar) else {
            return nil
        }

        let lastNightIsGap = todayWindow[0].isGap

        var trend: Trend = .unknown
        var breakEven = SleepDuration.zero
        if let implied = impliedAverageSleepSeconds(window: todayWindow) {
            breakEven = SleepDuration(seconds: implied)
            if !needChangedToday, !lastNightIsGap, let lastNight = todayWindow[0].asleep {
                let delta = lastNight.seconds - implied
                if delta > trendEpsilonSeconds {
                    trend = .falling
                } else if delta < -trendEpsilonSeconds {
                    trend = .rising
                } else {
                    trend = .flat
                }
            }
        }

        let measuredNights = todayWindow.filter { !$0.isGap }
        let measuredCount = measuredNights.count
        let gapCount = todayWindow.count - measuredCount
        let totalSleepSeconds = measuredNights.reduce(0.0) { $0 + ($1.asleep?.seconds ?? 0) }
        let averageSleepSeconds = measuredCount > 0 ? totalSleepSeconds / Double(measuredCount) : 0

        var deltaSinceYesterday: SleepDuration?
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           let yesterdaySeconds = debtSeconds(endingOn: yesterday, lookup: lookup, need: need, calendar: calendar) {
            deltaSinceYesterday = SleepDuration(seconds: todayDebtSeconds - yesterdaySeconds)
        }

        var deltaSinceMonday: SleepDuration?
        if let monday = mostRecentMonday(onOrBefore: today, calendar: calendar) {
            let measuredSinceMonday = countMeasuredNights(from: monday, through: today, lookup: lookup, calendar: calendar)
            if measuredSinceMonday >= 2,
               let mondaySeconds = debtSeconds(endingOn: monday, lookup: lookup, need: need, calendar: calendar) {
                deltaSinceMonday = SleepDuration(seconds: todayDebtSeconds - mondaySeconds)
            }
        }

        return DebtSnapshot(
            referenceDate: today,
            need: need,
            debt: SleepDuration(seconds: todayDebtSeconds),
            trend: trend,
            breakEvenTarget: breakEven,
            deltaSinceYesterday: deltaSinceYesterday,
            deltaSinceMonday: deltaSinceMonday,
            fourteenNightAverage: SleepDuration(seconds: averageSleepSeconds),
            measuredNightCount: measuredCount,
            gapCount: gapCount,
            lastNightIsGap: lastNightIsGap,
            computedAt: now
        )
    }
}
