/// Maps a debt value to a gauge fill fraction (0...1).
///
/// D10, resolved pending backtest (docs/IMPLEMENTATION_PLAN.md §1.2):
/// two linear segments rather than the mockup's literal 0–20h reading.
/// RISE Science's own target ("aim for ≤5h of debt") only makes sense as
/// a real goal if the band around it has real resolution — a plain
/// linear 0–20h scale compresses the whole 0–8h band, where that target
/// and most day-to-day improvement actually live, into its bottom 40%.
public enum GaugeMapping {
    /// Everything from 0 to this maps across `firstSegmentFraction` of
    /// the track.
    public static let firstSegmentCap = SleepDuration.hours(8)
    public static let firstSegmentFraction = 0.6

    /// The fill fraction saturates at 1.0 by this debt value. The stored
    /// `DebtSnapshot.debt` itself is never capped — only this mapping
    /// saturates, so a chronic short sleeper's gauge sits pegged near
    /// full rather than the headline number lying about their debt.
    public static let saturationPoint = SleepDuration.hours(24)

    /// The mockup's own minimum-visible-fill stub at zero debt — an
    /// empty-looking track doesn't read as "a gauge" at all.
    public static let minimumVisibleFraction = 0.015

    /// RISE Science's stated target. Marked on the track alongside the
    /// ghost tick (docs/IMPLEMENTATION_PLAN.md §1.2).
    public static let targetDebt = SleepDuration.hours(5)

    /// Fill fraction for `debt`, clamped to `[minimumVisibleFraction, 1]`.
    public static func fraction(for debt: SleepDuration) -> Double {
        let seconds = max(0, debt.seconds)
        let capSeconds = firstSegmentCap.seconds
        let saturationSeconds = saturationPoint.seconds

        let raw: Double
        if seconds <= capSeconds {
            raw = capSeconds > 0 ? (seconds / capSeconds) * firstSegmentFraction : firstSegmentFraction
        } else {
            let secondSegmentSeconds = saturationSeconds - capSeconds
            let progress = secondSegmentSeconds > 0
                ? min(1, (seconds - capSeconds) / secondSegmentSeconds)
                : 1
            raw = firstSegmentFraction + progress * (1 - firstSegmentFraction)
        }
        return max(minimumVisibleFraction, min(1, raw))
    }

    /// Where the 5h target mark sits on the track — a fixed position,
    /// computed once rather than recomputed by every caller.
    public static let targetFraction = fraction(for: targetDebt)
}
