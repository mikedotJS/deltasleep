/// Tunable constants for the weighted debt engine.
///
/// All three values here are marked resolved-pending-backtest in
/// docs/IMPLEMENTATION_PLAN.md (D1, D2, D10) — fit to the design mockup's
/// numbers plus RISE Science's published description, not independently
/// derived. Centralized here specifically so a retuned value from that
/// backtest is a one-line change, not a hunt through the engine.
public enum DebtEngineConstants {
    /// Geometric decay ratio. Puts the most recent night at very close to
    /// 15% of total weight over a 14-night window (half-life ≈ 5 nights) —
    /// see `SleepDebtEngine.weights(count:ratio:)`, whose actual output is
    /// what matters; this value was fit by hand against the mockup's
    /// stated "15% for last night," not solved for exactly.
    public static let weightRatio: Double = 0.873

    /// Rolling window length in nights (D8's minimum history requirement,
    /// and the `×14` scaling in the debt formula).
    public static let windowSize: Int = 14

    /// Per-night surplus-credit cap (D2): sleeping past `need` reduces
    /// that night's deficit below zero, but not by more than this. Caps
    /// the single-night swing on the headline debt figure to
    /// `windowSize × weight(0) × surplusCreditCap` ≈ 2h07 at the weights
    /// above, rather than letting one long night move it by hours.
    public static let surplusCreditCap = SleepDuration.hours(1)

    /// Minimum contiguous calendar nights of history required before a
    /// debt figure is shown at all (D8) — an onboarding condition,
    /// distinct from a single missing night within an otherwise
    /// established window (handled separately as the "night missing"
    /// state via gap carry-forward).
    public static let minimumHistoryNights: Int = windowSize
}
