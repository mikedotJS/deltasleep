import Foundation
import HealthSleepSource
import SleepDebtCore
import SnapshotStore

/// The app's single owner of "keep the cached snapshot current." Wires
/// HealthKit's background observer and the app's own foreground refresh
/// points into one `RefreshCoordinator.refresh` call each, so there's
/// exactly one code path that fetches, computes, persists, and reloads
/// widget timelines (docs/IMPLEMENTATION_PLAN.md §5, P3).
final class RefreshOrchestrator: @unchecked Sendable {
    private static let didRequestAuthorizationKey = "didRequestHealthKitAuthorization"

    private let source: HealthKitSleepSource
    private let store: SnapshotStoring
    private let reloader: WidgetReloading
    private let needStore: SleepNeedStore
    private let calendar: Calendar
    private let userDefaults: UserDefaults

    init(
        store: SnapshotStoring,
        needStore: SleepNeedStore = SleepNeedStore(),
        source: HealthKitSleepSource = HealthKitSleepSource(),
        reloader: WidgetReloading = WidgetCenterReloader(),
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard
    ) {
        self.source = source
        self.store = store
        self.reloader = reloader
        self.needStore = needStore
        self.calendar = calendar
        self.userDefaults = userDefaults
    }

    /// Called once at app launch: starts the background observer, then
    /// runs an initial foreground refresh. Deliberately does *not* request
    /// HealthKit authorization — P8's onboarding flow does that
    /// explicitly, after the user has seen why the app wants it, not
    /// silently on first launch.
    func start() async {
        source.startObservingChanges { [weak self] completion in
            let box = CompletionBox(completion)
            Task {
                await self?.refreshNow()
                box.call()
            }
        }
        await refreshNow()
    }

    /// Requests HealthKit authorization the first time only — called
    /// explicitly by `OnboardingViewModel` once the user taps through the
    /// first-run explainer (P8).
    func requestAuthorizationIfNeeded() async {
        guard !userDefaults.bool(forKey: Self.didRequestAuthorizationKey) else { return }
        try? await source.requestAuthorization()
        userDefaults.set(true, forKey: Self.didRequestAuthorizationKey)
    }

    /// The full denial-ambiguity heuristic (P2's `HealthAuthorizationState`)
    /// — combines the app's own "did we ask" flag with two live HealthKit
    /// checks. Used by P8 to tell "never asked yet" apart from "asked, and
    /// still nothing — probably denied" so the main screen can offer the
    /// right recovery action.
    func resolveAuthorizationState() async -> HealthAuthorizationState {
        let didRequestBefore = userDefaults.bool(forKey: Self.didRequestAuthorizationKey)
        let requestStatus = (try? await source.requestStatus()) ?? .unknown
        let hasAnySample = (try? await source.hasAnySampleEver()) ?? false
        return HealthAuthorizationState.resolve(
            didRequestBefore: didRequestBefore,
            requestStatus: requestStatus,
            hasAnySampleEver: hasAnySample
        )
    }

    /// Called on every scene activation, in addition to the background
    /// observer — foreground refresh is the correctness guarantee (see
    /// issue #2's S2 status note); background delivery is a latency
    /// optimisation on top of it, not a dependency of it.
    ///
    /// `needChangedToday` is passed straight through to
    /// `RefreshCoordinator.refresh` — set it when this refresh is the one
    /// immediately following a sleep-need edit (P7), so `Trend` freezes
    /// for today rather than a settings change alone painting the figure
    /// green or red.
    func refreshNow(needChangedToday: Bool = false) async {
        let now = Date()
        _ = try? await RefreshCoordinator.refresh(
            need: needStore.current,
            needChangedToday: needChangedToday,
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
