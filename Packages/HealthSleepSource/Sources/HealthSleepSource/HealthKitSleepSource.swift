// HealthKit doesn't exist on plain macOS — only iOS/watchOS (and Mac
// Catalyst). CI's `swift test` step for this package builds for the
// macOS *host*, not iOS, so this entire file has to compile away to
// nothing there. `#if canImport(HealthKit)` does exactly that: on
// macOS it's false and the file contributes nothing to the module: on
// iOS (via the `xcodebuild` step, which does build for iOS Simulator)
// it's true and this is the real implementation. That split is also why
// none of this is unit tested directly — it can't be, without a device
// or simulator — everything it delegates to (`SleepNightAggregator`,
// `HealthAuthorizationState`) is tested instead.
#if canImport(HealthKit)
import Foundation

// @preconcurrency: HKObserverQuery's completion handler
// (HKObserverQueryCompletionHandler) isn't @Sendable-annotated in this
// SDK, but startObservingChanges forwards it into a caller-supplied
// @Sendable closure (RefreshOrchestrator bridges it across a `Task {}`)
// — without this, the compiler rejects passing that non-Sendable
// completion handler where a @Sendable one is expected.
@preconcurrency import HealthKit

public final class HealthKitSleepSource: SleepDataSource, @unchecked Sendable {
    private let healthStore: HKHealthStore
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

    /// `HKObserverQuery` must be kept alive by the caller for as long as
    /// observation should continue — HealthKit doesn't retain it. Storing
    /// it here means `startObservingChanges` callers (P3's
    /// `RefreshOrchestrator`) don't have to manage that lifetime
    /// themselves.
    private var observerQuery: HKObserverQuery?

    public init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    public static var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
    }

    /// Registers a long-lived `HKObserverQuery` on sleep-analysis data and
    /// requests immediate background delivery (P3,
    /// docs/IMPLEMENTATION_PLAN.md §5) — "the number is right when you
    /// glance at the widget after waking" depends on this firing shortly
    /// after a night syncs, though S2 (issue #2) found no platform
    /// guarantee on exactly how shortly.
    ///
    /// `onUpdate` runs on HealthKit's own background queue every time new
    /// sleep-analysis data is written, and is passed a completion closure
    /// it must call once its own refresh work is done — `HKObserverQuery`
    /// requires that acknowledgement to avoid the app being throttled for
    /// unresponsive background delivery.
    ///
    /// The completion closure's type isn't `@Sendable` (HealthKit doesn't
    /// annotate `HKObserverQueryCompletionHandler` as one in this SDK),
    /// so a caller that needs to call it after `await`ing async work
    /// (crossing into a `Task {}`, which requires a `@Sendable` capture)
    /// has to bridge it through something like an `@unchecked Sendable`
    /// wrapper — see `RefreshOrchestrator`.
    ///
    /// `onUpdate` itself is `@Sendable` because `HKObserverQuery`'s own
    /// update handler is — it's called from HealthKit's background
    /// queue, not the queue `startObservingChanges` was called from.
    public func startObservingChanges(
        onUpdate: @escaping @Sendable (@escaping () -> Void) -> Void
    ) {
        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { _, completion, error in
            guard error == nil else {
                completion()
                return
            }
            onUpdate(completion)
        }
        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { _, _ in }
    }

    /// HealthKit's own record of whether `sleepAnalysis` read access has
    /// already been requested — not whether it was *granted*, which
    /// HealthKit deliberately never reveals for read-only types. See
    /// `HealthAuthorizationState`.
    public func requestStatus() async throws -> HealthAuthorizationState.RequestStatus {
        let status: HKAuthorizationRequestStatus
        status = try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(
                toShare: [], read: [sleepType]
            ) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
        switch status {
        case .shouldRequest:
            return .shouldPromptAgain
        case .unnecessary:
            return .alreadyRequested
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    /// Whether HealthKit has *any* sleep-analysis sample, ever, across
    /// every source — the other half of `HealthAuthorizationState`'s
    /// input, alongside `requestStatus()`.
    public func hasAnySampleEver() async throws -> Bool {
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil, options: [])
        let samples = try await fetchSamples(matching: predicate, limit: 1)
        return !samples.isEmpty
    }

    public func samples(from start: Date, to end: Date) async throws -> [RawSleepSample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: [.strictStartDate, .strictEndDate]
        )
        let hkSamples = try await fetchSamples(matching: predicate, limit: HKObjectQueryNoLimit)
        return hkSamples.compactMap(RawSleepSample.init(healthKitSample:))
    }

    private func fetchSamples(
        matching predicate: NSPredicate,
        limit: Int
    ) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true),
                ]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
            }
            healthStore.execute(query)
        }
    }
}

extension RawSleepSample {
    init?(healthKitSample sample: HKCategorySample) {
        guard let stage = Stage(healthKitValue: sample.value) else {
            return nil
        }
        self.init(
            stage: stage,
            startDate: sample.startDate,
            endDate: sample.endDate,
            sourceBundleID: sample.sourceRevision.source.bundleIdentifier
        )
    }
}

extension RawSleepSample.Stage {
    init?(healthKitValue value: Int) {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed:
            self = .inBed
        case .asleepUnspecified:
            self = .asleepUnspecified
        case .asleepCore:
            self = .asleepCore
        case .asleepDeep:
            self = .asleepDeep
        case .asleepREM:
            self = .asleepREM
        case .awake:
            self = .awake
        default:
            return nil
        }
    }
}
#endif
