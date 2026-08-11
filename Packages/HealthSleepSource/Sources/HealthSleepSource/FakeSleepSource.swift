import Foundation

/// A `SleepDataSource` backed by a fixed, in-memory sample list — for
/// tests, and for anything downstream that needs to exercise the
/// ingestion pipeline without a device or simulator.
public final class FakeSleepSource: SleepDataSource, @unchecked Sendable {
    private let allSamples: [RawSleepSample]

    public init(samples: [RawSleepSample]) {
        allSamples = samples
    }

    public func samples(from start: Date, to end: Date) async throws -> [RawSleepSample] {
        allSamples.filter { $0.startDate < end && $0.endDate > start }
    }
}
