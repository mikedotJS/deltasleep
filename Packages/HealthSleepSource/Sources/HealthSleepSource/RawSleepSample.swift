import Foundation

/// One sleep-analysis sample, translated out of HealthKit's own types
/// into something this package's aggregation logic can be built and
/// tested against without `import HealthKit` at all — `HKCategorySample`
/// only exists where the HealthKit framework does (see
/// `HealthKitSleepSource`'s `#if canImport(HealthKit)` guard), but the
/// logic that turns samples into nights doesn't need to know that.
public struct RawSleepSample: Hashable, Sendable {
    /// Mirrors `HKCategoryValueSleepAnalysis`'s cases.
    public enum Stage: Hashable, Sendable {
        case inBed
        case asleepUnspecified
        case asleepCore
        case asleepDeep
        case asleepREM
        case awake
    }

    public let stage: Stage
    public let startDate: Date
    public let endDate: Date
    /// e.g. `com.apple.health.<uuid>` for the Health app itself, or a
    /// third-party app's bundle identifier — whatever
    /// `HKSource.bundleIdentifier` reports.
    public let sourceBundleID: String

    public init(stage: Stage, startDate: Date, endDate: Date, sourceBundleID: String) {
        self.stage = stage
        self.startDate = startDate
        self.endDate = endDate
        self.sourceBundleID = sourceBundleID
    }
}
