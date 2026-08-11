/// Maps a single night to a bar in the 14-night strip.
///
/// Deliberately a *raw* encoding, unrelated to the weighted debt engine:
/// above the axis means that night's sleep exceeded `need`, below means it
/// didn't — no weighting, no surplus cap, no clamping. The strip and the
/// headline debt figure are reading different things on purpose (design
/// mockup's own framing: "dans la bande des 14 nuits... le code est
/// brut").
public enum NightStripMapping {
    /// Clamp reference matching the mockup's own JS (`max=2.2`): a
    /// deviation from `need` at or beyond this magnitude fills the bar's
    /// full half-height.
    public static let maxMagnitude = SleepDuration.hours(2.2)

    /// The mockup's own floor (`Math.max(3, ...)` against a 38px
    /// half-height ≈ 8%) — a bar at exactly `need` is still visible as a
    /// sliver, not invisible.
    public static let minimumVisibleFraction = 0.08

    public struct Bar: Equatable, Codable, Sendable {
        public let isGap: Bool
        /// `true` = above the axis (slept more than `need`). Meaningless
        /// when `isGap` is true.
        public let isSurplus: Bool
        /// 0...1 of the strip's half-height. Always 0 for a gap.
        public let fraction: Double

        // The compiler's synthesized `init(from:)` (for Codable) counts
        // as "this type declares an initializer," which suppresses the
        // automatic memberwise init — so it has to be spelled out here
        // now, not just implied by the stored properties above.
        public init(isGap: Bool, isSurplus: Bool, fraction: Double) {
            self.isGap = isGap
            self.isSurplus = isSurplus
            self.fraction = fraction
        }
    }

    public static func bar(for night: Night, need: SleepNeed) -> Bar {
        guard let asleep = night.asleep else {
            return Bar(isGap: true, isSurplus: false, fraction: 0)
        }
        let deltaSeconds = asleep.seconds - need.duration.seconds
        let magnitude = maxMagnitude.seconds > 0
            ? min(1, abs(deltaSeconds) / maxMagnitude.seconds)
            : 1
        let fraction = max(minimumVisibleFraction, magnitude)
        return Bar(isGap: false, isSurplus: deltaSeconds > 0, fraction: fraction)
    }
}
