import SleepDebtCore

extension DebtSnapshot {
    /// Equality ignoring `computedAt` — a fresh computation from unchanged
    /// underlying data produces a new timestamp but identical figures.
    /// `RefreshCoordinator` uses this to decide whether a widget reload is
    /// actually necessary (refresh-budget discipline,
    /// docs/IMPLEMENTATION_PLAN.md §5, P3), while still rewriting the
    /// cached snapshot on every successful refresh so `computedAt` (and
    /// therefore D6 staleness) stays accurate.
    func hasSameContent(as other: DebtSnapshot) -> Bool {
        referenceDate == other.referenceDate
            && need == other.need
            && debt == other.debt
            && trend == other.trend
            && breakEvenTarget == other.breakEvenTarget
            && deltaSinceYesterday == other.deltaSinceYesterday
            && deltaSinceMonday == other.deltaSinceMonday
            && fourteenNightAverage == other.fourteenNightAverage
            && measuredNightCount == other.measuredNightCount
            && gapCount == other.gapCount
            && lastNightIsGap == other.lastNightIsGap
            && nightBars == other.nightBars
    }
}
