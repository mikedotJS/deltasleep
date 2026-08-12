import Foundation
import SleepDebtCore

/// Turns raw samples into `Night`s: attributes them to a calendar day
/// (D3), merges overlapping coverage — including from different sources
/// — by interval union rather than picking one source, and distinguishes
/// a night with genuinely zero recorded sleep from a night with no data
/// at all.
public enum SleepNightAggregator {
    /// Stages counted toward "asleep" time. `.inBed` and `.awake` are
    /// excluded — being in bed isn't being asleep, and HealthKit reports
    /// both as their own sample stages.
    static let asleepStages: Set<RawSleepSample.Stage> = [
        .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM,
    ]

    /// One `Night` per entry in `days`.
    ///
    /// D3 (sleep-day boundary): night `D`'s window is
    /// `[noon on the day before D, noon on D)`, and a sample belongs to
    /// night `D` if its *end* falls in that window — the normal case (a
    /// session ending at 7am) lands squarely inside; a session ending
    /// after noon (an unusually late riser) rolls forward into the next
    /// day's window rather than the one that just closed. That's a
    /// deliberate, documented trade-off for an edge case, not an
    /// oversight — a single, unambiguous rule beats a special case for
    /// "how late is too late."
    ///
    /// A day with *no* sample at all — not even `.inBed`/`.awake` — in
    /// its window becomes `.gap`. A day with samples whose asleep stages
    /// sum to zero becomes `.measured(asleep: .zero)`: a real, if
    /// extreme, data point (a night with no recorded sleep), distinct
    /// from having no data.
    public static func nights(
        from samples: [RawSleepSample],
        forDays days: [Date],
        calendar: Calendar
    ) -> [Night] {
        days.map { day in
            let window = noonWindow(endingOn: day, calendar: calendar)
            let inWindow = samples.filter { window.contains($0.endDate) }
            guard !inWindow.isEmpty else {
                return Night.gap(date: day)
            }

            let asleepIntervals = inWindow
                .filter { asleepStages.contains($0.stage) }
                // Audit finding #10: a malformed sample with
                // `startDate >= endDate` would otherwise crash `Range`'s
                // construction (`fatalError`, not a `throws` — `try?`
                // upstream can't catch it). HealthKit shouldn't produce
                // one, but a corrupted local cache or a misbehaving
                // third-party writer is enough to trigger a launch-time
                // crash loop; skipping the sample degrades gracefully
                // instead.
                .filter { $0.startDate < $0.endDate }
                .compactMap { clip($0.startDate ..< $0.endDate, to: window) }
            let totalSeconds = unionDuration(of: asleepIntervals)
            return Night.measured(date: day, asleep: SleepDuration(seconds: totalSeconds))
        }
    }

    /// `[noon on the day before `date`, noon on `date`)`.
    static func noonWindow(endingOn date: Date, calendar: Calendar) -> Range<Date> {
        let startOfDay = calendar.startOfDay(for: date)
        let noonToday = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
        let noonYesterday = calendar.date(byAdding: .day, value: -1, to: noonToday)!
        return noonYesterday ..< noonToday
    }

    /// Clips `interval` to `bounds`, or `nil` if they don't overlap.
    /// Guards against a single raw sample spanning a noon boundary from
    /// contributing time outside the window it was attributed to.
    static func clip(_ interval: Range<Date>, to bounds: Range<Date>) -> Range<Date>? {
        let start = max(interval.lowerBound, bounds.lowerBound)
        let end = min(interval.upperBound, bounds.upperBound)
        return start < end ? start ..< end : nil
    }

    /// Total duration covered by the union of possibly-overlapping
    /// intervals — the mechanism behind the cross-source merge: two
    /// sources reporting overlapping coverage of the same stretch of
    /// night contribute that stretch once, not twice.
    static func unionDuration(of intervals: [Range<Date>]) -> TimeInterval {
        guard !intervals.isEmpty else {
            return 0
        }
        let sorted = intervals.sorted { $0.lowerBound < $1.lowerBound }
        var total: TimeInterval = 0
        var currentStart = sorted[0].lowerBound
        var currentEnd = sorted[0].upperBound
        for interval in sorted.dropFirst() {
            if interval.lowerBound <= currentEnd {
                currentEnd = max(currentEnd, interval.upperBound)
            } else {
                total += currentEnd.timeIntervalSince(currentStart)
                currentStart = interval.lowerBound
                currentEnd = interval.upperBound
            }
        }
        total += currentEnd.timeIntervalSince(currentStart)
        return total
    }
}
