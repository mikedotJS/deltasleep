import Foundation
import HealthSleepSource
import SleepDebtCore

/// Ties `HealthSleepSource` ingestion, the `SleepDebtCore` engine, and
/// snapshot persistence together into the one operation the app performs
/// on every observer wake, launch, and scene activation
/// (docs/IMPLEMENTATION_PLAN.md §5, P3). Everything HealthKit- or
/// WidgetKit-specific stays behind the `SleepDataSource` /
/// `WidgetReloading` protocols passed in, so this type itself is fully
/// testable with fakes — no device or extension needed.
public enum RefreshCoordinator {
    /// How many days beyond the engine's own 14-night window to fetch:
    /// enough slack to cover the "since Monday" comparison (D7 can reach
    /// up to 6 days further back than today's own window) and a short run
    /// of gap-carry-forward nights. A gap streak longer than this
    /// genuinely exceeds what a "carried forward" figure can mean anyway
    /// — `historyAvailability` degrades to `.insufficient`/`.none` rather
    /// than this silently under-fetching being the only symptom.
    static let lookbackBufferDays = 7

    /// The consecutive calendar days (most-recent-last) `SleepIngestion`
    /// needs to fetch to compute a full snapshot for `referenceDate`.
    public static func fetchWindow(referenceDate: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: referenceDate)
        let totalDays = DebtEngineConstants.windowSize + lookbackBufferDays
        return (0 ..< totalDays)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .reversed()
    }

    public enum Outcome: Equatable, Sendable {
        /// A snapshot was computed and persisted. `reloadedWidgets` is
        /// false when the figures are unchanged from what was already
        /// cached — the snapshot is still rewritten (so `computedAt`
        /// stays current for D6 staleness), but no timeline reload was
        /// spent on it.
        case refreshed(snapshot: DebtSnapshot, reloadedWidgets: Bool)
        case insufficientHistory(measuredNights: Int, requiredNights: Int)
        case noData
    }

    public static func refresh(
        need: SleepNeed,
        needChangedToday: Bool = false,
        referenceDate: Date,
        now: Date,
        calendar: Calendar,
        source: SleepDataSource,
        store: SnapshotStoring,
        reloader: WidgetReloading
    ) async throws -> Outcome {
        let days = fetchWindow(referenceDate: referenceDate, calendar: calendar)
        let nights = try await SleepIngestion.nights(for: days, from: source, calendar: calendar)

        // D8's rule ("refuse a figure below 14 measured nights") is
        // enforced directly here, not via SleepDebtEngine.historyAvailability.
        // That function treats a *missing* lookup entry as "before
        // tracking began" and an explicit `.gap` as "tracked, but empty" —
        // but SleepIngestion.nights(forDays:) always returns an explicit
        // entry (gap or measured) for every requested day, tracked or
        // not, so its "insufficient" branch can never actually trigger
        // through this pipeline. Counting measured nights across the
        // fetched history directly is what the mockup's own "13h04, 1
        // gap" card implies: an occasional gap inside an otherwise
        // established history still gets a real figure (gap
        // carry-forward handles it); it's *elapsed tracked time* that
        // gates the insufficient-history state, not zero gaps in the
        // current window. This resolves D8's previously open sub-question
        // (docs/IMPLEMENTATION_PLAN.md, and issue #4's status note).
        // Every branch below has to reload widget timelines when it changes
        // what's on disk, not just the `.sufficient` one at the bottom. The
        // three early returns used to write and return without telling
        // WidgetKit anything, so a widget sitting in `.insufficientHistory`
        // kept rendering a stale count — the app showed "10 nuits sur 14"
        // while the widget still said 9, until the widget's own 6h staleness
        // policy happened to fire. Reload only on an actual change, though:
        // WidgetKit's reload budget is finite, and refreshes fire on every
        // scene activation and every HealthKit observer wake.
        let previousAvailability = store.readHistoryAvailability()
        let measuredCount = nights.filter { !$0.isGap }.count
        guard measuredCount > 0 else {
            // Audit finding #1: a single fetch returning zero measured
            // nights used to overwrite an already-established history
            // with `.none` unconditionally — indistinguishable from "never
            // had any data" even when this was a transient, empty
            // HealthKit response. Only degrade when there wasn't already
            // a cached history to protect; a genuinely fresh install (no
            // prior snapshot, no prior availability) still correctly
            // writes `.none`.
            let hadHistory = store.readSnapshot() != nil
                || (previousAvailability ?? .none) != .none
            if !hadHistory {
                try store.writeHistoryAvailability(.none)
                if previousAvailability != HistoryAvailability.none {
                    reloader.reloadAllTimelines()
                }
            }
            return .noData
        }
        guard measuredCount >= DebtEngineConstants.minimumHistoryNights else {
            let availability = HistoryAvailability.insufficient(
                measuredNights: measuredCount,
                requiredNights: DebtEngineConstants.minimumHistoryNights
            )
            try store.writeHistoryAvailability(availability)
            if previousAvailability != availability {
                reloader.reloadAllTimelines()
            }
            return .insufficientHistory(
                measuredNights: measuredCount,
                requiredNights: DebtEngineConstants.minimumHistoryNights
            )
        }

        guard let snapshot = SleepDebtEngine.snapshot(
            nights: nights,
            need: need,
            needChangedToday: needChangedToday,
            referenceDate: referenceDate,
            now: now,
            calendar: calendar
        ) else {
            // The measured-count gate above passed but the engine still
            // couldn't compute a window ending on referenceDate — defensive
            // fallback rather than a crash, matching WidgetState.classify's
            // own nil handling.
            try store.writeHistoryAvailability(.none)
            if previousAvailability != HistoryAvailability.none {
                reloader.reloadAllTimelines()
            }
            return .noData
        }

        // Audit finding #9: write the snapshot *before* flipping
        // availability to `.sufficient`. The two files aren't written
        // transactionally (a separate process — the widget — can read
        // between the two calls, or the app can be killed mid-write), so
        // if only one write lands it should be the snapshot: an
        // `.insufficient`/`.none` availability with a fresh snapshot
        // already on disk degrades harmlessly (classify ignores the
        // snapshot in that branch), whereas the old order could leave
        // `.sufficient` paired with a still-nil or stale snapshot, which
        // `WidgetState.classify` falls back to `.noData` for — a false
        // "access needed" screen on the very day history became sufficient.
        let previous = store.readSnapshot()
        let didChange = previous.map { !$0.hasSameContent(as: snapshot) } ?? true
        try store.writeSnapshot(snapshot)
        try store.writeHistoryAvailability(.sufficient)
        if didChange {
            reloader.reloadAllTimelines()
        }
        return .refreshed(snapshot: snapshot, reloadedWidgets: didChange)
    }
}
