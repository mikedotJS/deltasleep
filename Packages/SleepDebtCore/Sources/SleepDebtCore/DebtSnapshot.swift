import Foundation

/// The full computed result for one calendar day — everything a widget or
/// the main screen needs to render, with no further engine calls.
///
/// `Codable` because this is the value P3's SnapshotStore persists into the
/// App Group container; the other domain types (`Night`, `WidgetState`)
/// deliberately aren't — they're either raw input or a cheap-to-recompute
/// classification, not something that needs to survive a round trip.
public struct DebtSnapshot: Equatable, Codable, Sendable {
    /// The calendar day this snapshot describes ("today," from the
    /// caller's point of view).
    public let referenceDate: Date
    public let need: SleepNeed

    /// Always ≥ 0 (D2's floor). Carried forward unchanged from the prior
    /// day when `lastNightIsGap` is true, rather than recomputed over a
    /// shifted window — see `SleepDebtEngine`.
    public let debt: SleepDuration
    public let trend: Trend

    /// Tonight's target: the sleep duration that would make `trend`
    /// `.flat` if repeated — i.e. the recency-weighted average of the
    /// window excluding last night. Not shown as a state, but potentially
    /// useful copy (docs/IMPLEMENTATION_PLAN.md's P7 notes).
    public let breakEvenTarget: SleepDuration

    /// Signed; positive means debt rose. `nil` when yesterday's own window
    /// didn't have sufficient history to compute a comparable debt.
    public let deltaSinceYesterday: SleepDuration?

    /// Signed; `nil` when the most recent Monday's window was itself
    /// insufficient, or when fewer than 2 nights since Monday (inclusive)
    /// have been measured (D7) — a 1-night-old week isn't a meaningful
    /// comparison yet.
    public let deltaSinceMonday: SleepDuration?

    /// Average time *asleep* (not deficit) across measured nights in the
    /// window — the mockup's "Moyenne sur 14 nuits."
    public let fourteenNightAverage: SleepDuration

    public let measuredNightCount: Int
    public let gapCount: Int

    /// Whether last night specifically has no data — the trigger for
    /// state 7 (amber, "night missing") and for the gap carry-forward
    /// rule that made `debt` above equal yesterday's.
    public let lastNightIsGap: Bool

    /// The 14-night strip's raw per-night bars (`NightStripMapping.Bar`),
    /// oldest first, most recent last — persisted here rather than
    /// recomputed by P6/P7 from scratch, since neither the widget nor a
    /// cold-launched main screen has the raw `[Night]` history to derive
    /// it from (the widget never touches HealthKit at all; see P2/P3).
    /// Empty when there wasn't a full window to build bars from.
    public let nightBars: [NightStripMapping.Bar]

    /// When this snapshot was computed. Supplied by the caller (P3), never
    /// read from the system clock inside this package — see
    /// `SleepDebtEngine.snapshot(nights:need:referenceDate:now:calendar:)`.
    public let computedAt: Date

    public init(
        referenceDate: Date,
        need: SleepNeed,
        debt: SleepDuration,
        trend: Trend,
        breakEvenTarget: SleepDuration,
        deltaSinceYesterday: SleepDuration?,
        deltaSinceMonday: SleepDuration?,
        fourteenNightAverage: SleepDuration,
        measuredNightCount: Int,
        gapCount: Int,
        lastNightIsGap: Bool,
        nightBars: [NightStripMapping.Bar],
        computedAt: Date
    ) {
        self.referenceDate = referenceDate
        self.need = need
        self.debt = debt
        self.trend = trend
        self.breakEvenTarget = breakEvenTarget
        self.deltaSinceYesterday = deltaSinceYesterday
        self.deltaSinceMonday = deltaSinceMonday
        self.fourteenNightAverage = fourteenNightAverage
        self.measuredNightCount = measuredNightCount
        self.gapCount = gapCount
        self.lastNightIsGap = lastNightIsGap
        self.nightBars = nightBars
        self.computedAt = computedAt
    }
}
