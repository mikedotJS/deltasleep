import Foundation
import SleepDebtCore

/// Ties `SleepDataSource` and `SleepNightAggregator` together: fetch
/// exactly enough raw samples to cover `days`, then aggregate. The
/// caller (P3's SnapshotStore) shouldn't need to know about noon-window
/// math just to ask "give me Nights for these days."
public enum SleepIngestion {
    public static func nights(
        for days: [Date],
        from source: SleepDataSource,
        calendar: Calendar
    ) async throws -> [Night] {
        guard let earliest = days.min(), let latest = days.max() else {
            return []
        }
        let fetchStart = SleepNightAggregator
            .noonWindow(endingOn: earliest, calendar: calendar).lowerBound
        let fetchEnd = SleepNightAggregator
            .noonWindow(endingOn: latest, calendar: calendar).upperBound
        let samples = try await source.samples(from: fetchStart, to: fetchEnd)
        return SleepNightAggregator.nights(from: samples, forDays: days, calendar: calendar)
    }

    /// `count` consecutive calendar days (oldest first), ending on
    /// `date` — a plain "last N days" day-range for callers that don't
    /// want to assemble the array themselves. `nights(for:from:calendar:)`
    /// already accepts an arbitrary range, unbounded by the debt engine's
    /// 14-night window; the gap was only ever in how easy that range was
    /// to construct. Enables `HistoryView` (post-audit PLAN.md Phase 4)
    /// to browse further back than the rolling snapshot ever needs to —
    /// the confirmed "historique > 14 nuits" capability gap from
    /// `BUSINESS_RULES.md`.
    public static func days(count: Int, endingOn date: Date, calendar: Calendar) -> [Date] {
        guard count > 0 else { return [] }
        let today = calendar.startOfDay(for: date)
        return (0 ..< count)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .reversed()
    }
}
