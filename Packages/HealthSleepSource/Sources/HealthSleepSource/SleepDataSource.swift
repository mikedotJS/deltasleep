import Foundation

/// Where raw sleep samples come from — `HealthKitSleepSource` for the
/// real app, `FakeSleepSource` for tests and for anything downstream
/// (P3's SnapshotStore) that needs to exercise the ingestion pipeline
/// without a device or simulator.
public protocol SleepDataSource: Sendable {
    /// Every sleep-analysis sample — any stage, any source — with an end
    /// date in `[start, end)`. No filtering, no merging, no attribution:
    /// that's `SleepNightAggregator`'s job, kept separate so it can be
    /// tested without touching HealthKit at all.
    func samples(from start: Date, to end: Date) async throws -> [RawSleepSample]
}
