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
}
