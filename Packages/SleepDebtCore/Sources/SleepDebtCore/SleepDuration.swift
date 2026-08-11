import Foundation

/// A span of time, stored as seconds.
///
/// A small wrapper around `TimeInterval` rather than the standard library's
/// `Duration` type — this package has never been compiled (see
/// docs/IMPLEMENTATION_PLAN.md P1's status notes), and `Duration`'s exact
/// arithmetic surface (in particular, multiplying by a `Double` weight) on
/// an unverified future toolchain is not something worth guessing at.
/// `TimeInterval` is `Double`; every operation here is ordinary
/// floating-point arithmetic with no platform-specific behavior.
public struct SleepDuration: Hashable, Comparable, Codable, Sendable {
    public let seconds: TimeInterval

    public init(seconds: TimeInterval) {
        self.seconds = seconds
    }

    public static func hours(_ hours: Double) -> SleepDuration {
        SleepDuration(seconds: hours * 3600)
    }

    public static func minutes(_ minutes: Double) -> SleepDuration {
        SleepDuration(seconds: minutes * 60)
    }

    /// Convenience matching how fixtures read in the design mockup and
    /// this codebase's tests: `.hm(10, 26)` for "10h26".
    public static func hm(_ hours: Int, _ minutes: Int) -> SleepDuration {
        SleepDuration(seconds: Double(hours) * 3600 + Double(minutes) * 60)
    }

    public static let zero = SleepDuration(seconds: 0)

    public var hours: Double { seconds / 3600 }
    public var minutes: Double { seconds / 60 }

    /// Whole hours and remaining minutes of this duration's *magnitude*,
    /// for display — e.g. `(13, 4)` for 13h04, and `(1, 24)` for either
    /// +1h24 or -1h24. Deltas in this codebase are shown with a separate
    /// arrow glyph carrying direction (per the design mockup's `DeltaChip`),
    /// not a signed number, so this deliberately drops the sign — read
    /// `.seconds`'s sign directly if direction is needed. Rounds to the
    /// nearest minute.
    public var wholeHoursAndMinutes: (hours: Int, minutes: Int) {
        let totalMinutes = Int((abs(seconds) / 60).rounded())
        return (totalMinutes / 60, totalMinutes % 60)
    }

    public static func < (lhs: SleepDuration, rhs: SleepDuration) -> Bool {
        lhs.seconds < rhs.seconds
    }

    public static func + (lhs: SleepDuration, rhs: SleepDuration) -> SleepDuration {
        SleepDuration(seconds: lhs.seconds + rhs.seconds)
    }

    public static func - (lhs: SleepDuration, rhs: SleepDuration) -> SleepDuration {
        SleepDuration(seconds: lhs.seconds - rhs.seconds)
    }

    public static prefix func - (value: SleepDuration) -> SleepDuration {
        SleepDuration(seconds: -value.seconds)
    }

    public static func * (lhs: SleepDuration, rhs: Double) -> SleepDuration {
        SleepDuration(seconds: lhs.seconds * rhs)
    }

    /// Clamps to a lower bound — used by the debt engine's per-night
    /// surplus-credit cap (D2): `deficit.clamped(low: -cap)`.
    public func clamped(low: SleepDuration) -> SleepDuration {
        seconds < low.seconds ? low : self
    }

    public func clamped(low: SleepDuration, high: SleepDuration) -> SleepDuration {
        if seconds < low.seconds { return low }
        if seconds > high.seconds { return high }
        return self
    }
}
