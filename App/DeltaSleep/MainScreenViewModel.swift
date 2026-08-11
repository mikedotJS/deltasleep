import Foundation
import Observation
import SleepDebtCore
import SnapshotStore

/// Drives `MainScreenView` (docs/IMPLEMENTATION_PLAN.md §5, P7): reads
/// the same cached snapshot the widget does, through the same
/// `WidgetState.classify` call, so the two surfaces can never disagree
/// about what state they're in.
@MainActor
@Observable
final class MainScreenViewModel {
    private(set) var state: WidgetState = .noData
    private(set) var snapshot: DebtSnapshot?
    private(set) var isRefreshing = false
    var sleepNeedHours: Double

    private let store: SnapshotStoring
    private let needStore: SleepNeedStore
    private let orchestrator: RefreshOrchestrator

    init(store: SnapshotStoring, needStore: SleepNeedStore, orchestrator: RefreshOrchestrator) {
        self.store = store
        self.needStore = needStore
        self.orchestrator = orchestrator
        sleepNeedHours = needStore.current.duration.hours
        reloadFromCache(now: Date())
    }

    /// Called on pull-to-refresh and on first appearance.
    func refresh() async {
        isRefreshing = true
        await orchestrator.refreshNow()
        reloadFromCache(now: Date())
        isRefreshing = false
    }

    /// Called when the sleep-need stepper changes — persists the new
    /// value, then re-refreshes with `needChangedToday: true` so `Trend`
    /// freezes for today rather than the settings change alone painting
    /// the figure a colour (P1's freeze-on-need-change rule).
    func updateSleepNeed(hours: Double) async {
        sleepNeedHours = hours
        let changed = needStore.set(SleepNeed(.hours(hours)))
        isRefreshing = true
        await orchestrator.refreshNow(needChangedToday: changed)
        reloadFromCache(now: Date())
        isRefreshing = false
    }

    private func reloadFromCache(now: Date) {
        let cachedSnapshot = store.readSnapshot()
        let availability = store.readHistoryAvailability() ?? .none
        state = WidgetState.classify(
            history: availability,
            snapshot: cachedSnapshot,
            staleAfter: StalenessPolicy.staleAfter,
            now: now
        )
        snapshot = cachedSnapshot
    }

    #if DEBUG
    /// P10's debug state switcher (docs/IMPLEMENTATION_PLAN.md §5, P10):
    /// forces `fixture`'s data into the shared store, reloads widget
    /// timelines, then re-reads from cache the same way `refresh()`
    /// does — so the result renders through the exact same code path a
    /// real refresh would. `store` and `reloadFromCache` are `private`,
    /// not `fileprivate` — reachable from this extension only because
    /// it lives in the same file, kept here rather than in
    /// `DebugStateFixture.swift` for exactly that reason.
    func applyDebugFixture(_ fixture: DebugStateFixture) {
        try? fixture.apply(store: store, reloader: WidgetCenterReloader())
        reloadFromCache(now: Date())
    }
    #endif
}
