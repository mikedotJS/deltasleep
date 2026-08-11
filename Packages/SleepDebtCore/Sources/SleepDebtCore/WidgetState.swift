import Foundation

/// Whether there's enough raw history to attempt a snapshot at all, and if
/// not, why.
///
/// Authorization status specifically is *not* represented here on purpose:
/// HealthKit can't disambiguate "access denied" from "access granted,
/// nothing written yet" (see P2's authorization heuristic in
/// docs/IMPLEMENTATION_PLAN.md), so that heuristic lives in
/// HealthSleepSource, not in this HealthKit-agnostic package. This type
/// only distinguishes "some history exists, just not 14 nights of it"
/// from "no sleep data has ever been observed" — the caller (the app, via
/// P2 + P3) is responsible for deciding which of those is true before
/// asking for a `WidgetState`.
public enum HistoryAvailability: Equatable, Sendable {
    case sufficient
    case insufficient(measuredNights: Int, requiredNights: Int)
    case none
}

/// The seven states the design defines (docs/IMPLEMENTATION_PLAN.md §5,
/// P6). Computed once here so every surface — widget and main screen
/// alike — derives its state the same way instead of each view
/// re-deriving it from a raw snapshot.
public enum WidgetState: Equatable, Sendable {
    /// States 1 & 3: a normal, trustworthy reading. Colour comes from
    /// `trend`, never from `debt`'s magnitude — 24h+ of debt showing green
    /// is correct and intended (docs/IMPLEMENTATION_PLAN.md §1.2).
    case nominal(debt: SleepDuration, trend: Trend)

    /// State 2: debt is at (or below, after flooring) zero. Kept as its
    /// own case rather than `.nominal(debt: .zero, trend: .falling)`
    /// because the UI treats it specially — gauge floor stub, no
    /// celebratory copy — regardless of which trend produced it.
    case zero

    /// State 4: a snapshot exists but is older than the app trusts (D6).
    case cached(computedAt: Date)

    /// State 5, recast from the mockup's literal "authorization missing"
    /// copy: no sleep data has been observed at all. Deliberately doesn't
    /// claim *why* the widget renders the same way whether access was
    /// never granted or was granted to a phone with no Watch and nothing
    /// else writing sleep data.
    case noData

    /// State 6: fewer than `requiredNights` contiguous calendar nights of
    /// history exist yet (onboarding).
    case insufficientHistory(measuredNights: Int, requiredNights: Int)

    /// State 7: last night has no data. `debt` here is the carried-forward
    /// value from the prior day (see `SleepDebtEngine`'s gap
    /// carry-forward), not a fresh computation.
    case nightMissing(debt: SleepDuration)

    /// Classifies a computed snapshot (or the lack of one) into exactly
    /// one of the seven states.
    ///
    /// - Parameters:
    ///   - history: whether there was enough raw history to even attempt
    ///     a computation, from P2/P3's authorization + ingestion layer.
    ///   - snapshot: the engine's result. Expected non-nil exactly when
    ///     `history == .sufficient`; a nil snapshot despite sufficient
    ///     history falls back to `.noData` defensively rather than
    ///     crashing, since that combination shouldn't occur if the
    ///     caller is internally consistent.
    ///   - staleAfter: D6's threshold.
    ///   - now: read once by the caller, not by this package — see
    ///     `DebtSnapshot.computedAt`'s doc comment.
    public static func classify(
        history: HistoryAvailability,
        snapshot: DebtSnapshot?,
        staleAfter: TimeInterval,
        now: Date
    ) -> WidgetState {
        switch history {
        case .none:
            return .noData
        case let .insufficient(measured, required):
            return .insufficientHistory(measuredNights: measured, requiredNights: required)
        case .sufficient:
            guard let snapshot else { return .noData }
            if now.timeIntervalSince(snapshot.computedAt) > staleAfter {
                return .cached(computedAt: snapshot.computedAt)
            }
            if snapshot.lastNightIsGap {
                return .nightMissing(debt: snapshot.debt)
            }
            if snapshot.debt.seconds <= .ulpOfOne {
                return .zero
            }
            return .nominal(debt: snapshot.debt, trend: snapshot.trend)
        }
    }
}
