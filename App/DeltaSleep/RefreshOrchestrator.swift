import Foundation
import HealthSleepSource
import SleepDebtCore
import SnapshotStore

/// The app's single owner of "keep the cached snapshot current." Wires
/// HealthKit's background observer and the app's own foreground refresh
/// points into one `RefreshCoordinator.refresh` call each, so there's
/// exactly one code path that fetches, computes, persists, and reloads
/// widget timelines (docs/IMPLEMENTATION_PLAN.md §5, P3).
///
/// Two things here are deliberate placeholders, not the finished feature:
/// the sleep-need value is hardcoded to the mockup's own default (8h) until
/// P7 adds real persistence and a settings screen, and requesting HealthKit
/// authorization here is only the minimum needed for the app to function
/// end to end before P8 builds the real first-run flow and copy.
final class RefreshOrchestrator: @unchecked Sendable {
    private static let didRequestAuthorizationKey = "didRequestHealthKitAuthorization"

    private let source: HealthKitSleepSource
    private let store: SnapshotStoring
    private let reloader: WidgetReloading
    private let calendar: Calendar
    private let userDefaults: UserDefaults

    init(
        store: SnapshotStoring,
        source: HealthKitSleepSource = HealthKitSleepSource(),
        reloader: WidgetReloading = WidgetCenterReloader(),
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard
    ) {
        self.source = source
        self.store = store
        self.reloader = reloader
        self.calendar = calendar
        self.userDefaults = userDefaults
    }

    /// Called once at app launch: requests HealthKit authorization the
    /// first time only, starts the background observer, then runs an
    /// initial foreground refresh.
    func start() async {
        if !userDefaults.bool(forKey: Self.didRequestAuthorizationKey) {
            try? await source.requestAuthorization()
            userDefaults.set(true, forKey: Self.didRequestAuthorizationKey)
        }
        source.startObservingChanges { [weak self] completion in
            let box = CompletionBox(completion)
            Task {
                await self?.refreshNow()
                box.call()
            }
        }
        await refreshNow()
    }

    /// Called on every scene activation, in addition to the background
    /// observer — foreground refresh is the correctness guarantee (see
    /// issue #2's S2 status note); background delivery is a latency
    /// optimisation on top of it, not a dependency of it.
    func refreshNow() async {
        let now = Date()
        _ = try? await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)),
            referenceDate: now,
            now: now,
            calendar: calendar,
            source: source,
            store: store,
            reloader: reloader
        )
    }
}

/// A `Sendable` box around HealthKit's completion closure, whose own type
/// isn't `@Sendable` in this SDK — see `HealthKitSleepSource
/// .startObservingChanges`'s doc comment. `Task {}`'s operation closure
/// must be `@Sendable`, so it can capture this box (a reference type we
/// vouch for manually) but not the raw closure directly.
private final class CompletionBox: @unchecked Sendable {
    private let completion: () -> Void

    init(_ completion: @escaping () -> Void) {
        self.completion = completion
    }

    func call() {
        completion()
    }
}
