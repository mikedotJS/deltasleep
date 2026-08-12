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
/// An `actor`, not a plain class: `refreshNow` can legitimately be
/// triggered concurrently from more than one place (the background
/// HealthKit observer callback in `start()`, and every scene-activation
/// or user-initiated refresh) — actor isolation is what makes
/// `lastRefresh` itself safe to read and mutate from those overlapping
/// callers; see `refreshNow`'s own doc comment for why that alone still
/// isn't enough and the chaining exists too.
actor RefreshOrchestrator {
    private static let didRequestAuthorizationKey = "didRequestHealthKitAuthorization"

    private let source: HealthKitSleepSource
    private let store: SnapshotStoring
    private let reloader: WidgetReloading
    private let needStore: SleepNeedStore
    private let calendar: Calendar
    private let userDefaults: UserDefaults

    /// The most recently requested refresh, kept only so the next call
    /// can chain onto it — see `refreshNow`.
    private var lastRefresh: Task<Void, Never>?

    /// Audit finding #16: keeps the app self-refreshing at the boundary
    /// that actually matters ("cette nuit"/"depuis lundi" pivot on noon,
    /// not midnight — see `SleepNightAggregator`'s D3 rule), not just on
    /// scene activation/launch/pull-to-refresh/background observer.
    private var noonRefreshTask: Task<Void, Never>?

    /// Audit finding #14: whether the most recent `performRefresh` threw.
    /// `MainScreenViewModel` surfaces this as a lightweight banner —
    /// distinct from "succeeded with nothing new" — instead of a silent
    /// no-op the user can't tell apart from a real failure.
    private(set) var lastRefreshFailed = false

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
        scheduleNoonBoundaryRefresh()
        await refreshNow()
    }

    /// Audit finding #16: self-reschedules a refresh at every local noon
    /// — the boundary "cette nuit"/"depuis lundi" actually pivot on
    /// (`SleepNightAggregator`'s D3 noon-to-noon window), not midnight.
    /// Without this, an app kept in the foreground across noon showed
    /// stale labels until the next scene activation or manual
    /// pull-to-refresh.
    private func scheduleNoonBoundaryRefresh() {
        noonRefreshTask?.cancel()
        noonRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let next = await nextNoon(after: Date()) else { return }
                let interval = max(next.timeIntervalSinceNow, 1)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await refreshNow()
            }
        }
    }

    private func nextNoon(after date: Date) -> Date? {
        let startOfToday = calendar.startOfDay(for: date)
        guard let noonToday = calendar.date(byAdding: .hour, value: 12, to: startOfToday) else {
            return nil
        }
        return noonToday > date ? noonToday : calendar.date(byAdding: .day, value: 1, to: noonToday)
    }

    /// Requests HealthKit authorization the first time only — called
    /// explicitly by `OnboardingViewModel` once the user taps through the
    /// first-run explainer (P8).
    func requestAuthorizationIfNeeded() async {
        guard !userDefaults.bool(forKey: Self.didRequestAuthorizationKey) else { return }
        try? await source.requestAuthorization()
        userDefaults.set(true, forKey: Self.didRequestAuthorizationKey)
    }

    /// Unconditionally re-triggers the system prompt — unlike
    /// `requestAuthorizationIfNeeded()`, which only ever asks once.
    /// `resolveAuthorizationState()`'s `.needsPrompt` case can recur
    /// after the very first ask (HealthKit reports
    /// `.shouldPromptAgain` when a new read type needs fresh consent),
    /// so `MainScreenViewModel`'s recovery action needs a way to ask
    /// again that the once-only guard above would otherwise block.
    func requestAuthorizationAgain() async {
        try? await source.requestAuthorization()
        userDefaults.set(true, forKey: Self.didRequestAuthorizationKey)
    }

    /// "Effacer mes données" (post-audit PLAN.md Phase 2): clears the
    /// "did we ever ask" flag so a subsequent onboarding replay behaves
    /// like a genuine first run — without this, `requestAuthorizationIfNeeded`
    /// would silently skip the actual system prompt on replay, since it
    /// only ever fires once per install by design.
    func resetAuthorizationRequestFlag() {
        userDefaults.removeObject(forKey: Self.didRequestAuthorizationKey)
    }

    /// Read-only history fetch for `HistoryView` (post-audit PLAN.md
    /// Phase 4) — goes straight to HealthKit via `SleepIngestion.days`/
    /// `nights(for:from:calendar:)`, entirely separate from the debt
    /// engine's own 21-day rolling window (`RefreshCoordinator.fetchWindow`)
    /// and its cached snapshot. Never writes anything — browsing history
    /// shouldn't perturb the cached debt figure or trigger a widget
    /// reload. Returns oldest-first, matching `SleepIngestion.days`.
    func history(daysBack: Int, endingOn date: Date = Date()) async -> [Night] {
        let days = SleepIngestion.days(count: daysBack, endingOn: date, calendar: calendar)
        return await (try? SleepIngestion.nights(for: days, from: source, calendar: calendar)) ?? []
    }

    /// The full denial-ambiguity heuristic (P2's `HealthAuthorizationState`)
    /// — combines the app's own "did we ask" flag with two live HealthKit
    /// checks. Used by P8 to tell "never asked yet" apart from "asked, and
    /// still nothing — probably denied" so the main screen can offer the
    /// right recovery action.
    func resolveAuthorizationState() async -> HealthAuthorizationState {
        let didRequestBefore = userDefaults.bool(forKey: Self.didRequestAuthorizationKey)
        let requestStatus = await (try? source.requestStatus()) ?? .unknown
        let hasAnySample = await (try? source.hasAnySampleEver()) ?? false
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
    ///
    /// Chains onto any refresh already in flight instead of running
    /// concurrently with it. Without this, two overlapping calls — the
    /// realistic pair is the background observer's callback and a
    /// scene-activation refresh landing at nearly the same moment — can
    /// *finish* in a different order than they were *requested* in:
    /// `RefreshCoordinator.refresh` always writes unconditionally (so
    /// `computedAt` stays current even when content doesn't change), so
    /// whichever call finishes last wins the write, even if it started
    /// first and read older source data as its own "previous" for the
    /// change diff. That could silently overwrite an already-displayed,
    /// more current snapshot with a stale one and no reload to fix it.
    /// Chaining makes "requested" and "finished" the same order, so the
    /// last call to finish is always also the one with the freshest
    /// data.
    func refreshNow(needChangedToday: Bool = false) async {
        let previous = lastRefresh
        let task = Task {
            _ = await previous?.value
            await self.performRefresh(needChangedToday: needChangedToday)
        }
        lastRefresh = task
        await task.value
    }

    private func performRefresh(needChangedToday: Bool) async {
        let now = Date()
        // Audit finding #8: `needChangedToday` used to be a one-shot flag
        // only the refresh immediately following a sleep-need edit ever
        // saw true — every later refresh that same day (background
        // observer, scene activation) passed `false` again, so `Trend`
        // could un-freeze and paint green/red within minutes of a
        // settings change, despite the intent (documented above, and in
        // SleepDebtEngine) being to freeze it for the rest of the day.
        // Deriving it from the persisted last-changed date instead makes
        // every refresh that day agree, not just the first one.
        let changedToday = needChangedToday
            || needStore.lastChangedDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        do {
            _ = try await RefreshCoordinator.refresh(
                need: needStore.current,
                needChangedToday: changedToday,
                referenceDate: now,
                now: now,
                calendar: calendar,
                source: source,
                store: store,
                reloader: reloader
            )
            lastRefreshFailed = false
        } catch {
            // Audit finding #14: previously `try?` discarded this
            // entirely — a real HealthKit/disk error and "nothing new"
            // were indistinguishable to the user.
            lastRefreshFailed = true
        }
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
