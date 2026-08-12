import Foundation
import HealthSleepSource
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
    /// Audit finding #14: whether the most recent refresh attempt threw
    /// (as opposed to succeeding with no new data). Cleared on the next
    /// successful refresh.
    private(set) var lastRefreshFailed = false
    /// Only meaningful (non-nil) while `state == .noData` — resolved via
    /// P2's `HealthAuthorizationState` heuristic so `MainScreenView` can
    /// offer the right recovery action instead of always assuming
    /// "denied, go to Settings" (see `refreshAuthStateIfNeeded`).
    private(set) var authState: HealthAuthorizationState?
    var sleepNeedHours: Double

    private let store: SnapshotStoring
    private let needStore: SleepNeedStore
    private let orchestrator: RefreshOrchestrator
    /// Audit finding #12: coalesces the stepper's auto-repeat into one
    /// refresh instead of one per tick — see `updateSleepNeed`.
    private var pendingNeedUpdate: Task<Void, Never>?

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
        lastRefreshFailed = await orchestrator.lastRefreshFailed
        reloadFromCache(now: Date())
        await refreshAuthStateIfNeeded()
        isRefreshing = false
    }

    /// Called on every sleep-need stepper tick. Updates the displayed
    /// value immediately, but debounces the actual refresh (audit
    /// finding #12) — a held stepper's native auto-repeat used to fire a
    /// full HealthKit fetch + recompute + disk write + widget reload
    /// cycle per tick, never cancelled even when a newer value arrived
    /// right behind it.
    func updateSleepNeed(hours: Double) {
        sleepNeedHours = hours
        pendingNeedUpdate?.cancel()
        pendingNeedUpdate = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await commitSleepNeedUpdate(hours: hours)
        }
    }

    /// Persists the new value, then re-refreshes with
    /// `needChangedToday: true` so `Trend` freezes for today rather than
    /// the settings change alone painting the figure a colour (P1's
    /// freeze-on-need-change rule).
    private func commitSleepNeedUpdate(hours: Double) async {
        let changed = needStore.set(SleepNeed(.hours(hours)))
        isRefreshing = true
        await orchestrator.refreshNow(needChangedToday: changed)
        lastRefreshFailed = await orchestrator.lastRefreshFailed
        reloadFromCache(now: Date())
        await refreshAuthStateIfNeeded()
        isRefreshing = false
    }

    /// The "Autoriser l'accès au sommeil" recovery action on `.noData`
    /// (`MainScreenView`) — re-triggers the system prompt when
    /// `authState` says that can actually do something
    /// (`.needsPrompt`), then refreshes so a grant takes effect
    /// immediately rather than waiting for the next scene activation.
    ///
    /// Sets `isRefreshing` immediately (audit finding #13), before the
    /// system-prompt call even starts — `refresh()` below would only set
    /// it after `requestAuthorizationAgain()` already returned, leaving a
    /// window where a repeat tap could fire a second overlapping system
    /// prompt.
    func requestAccessAgain() async {
        isRefreshing = true
        await orchestrator.requestAuthorizationAgain()
        await refresh()
    }

    /// Only resolved while `.noData` — the two HealthKit status checks
    /// `resolveAuthorizationState()` makes aren't worth paying for on
    /// every refresh when no other state has any use for the result.
    private func refreshAuthStateIfNeeded() async {
        guard case .noData = state else {
            authState = nil
            return
        }
        authState = await orchestrator.resolveAuthorizationState()
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
        try? fixture.apply(store: store, reloader: WidgetCenterReloader(), need: needStore.current)
        reloadFromCache(now: Date())
    }
    #endif
}
