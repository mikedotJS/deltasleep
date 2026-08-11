import Foundation
import SleepDebtCore

/// The app-target twin of the widget's `DurationCopy` — see
/// `AppTint`'s doc comment for why this is duplicated rather than
/// shared. French duration copy matching the mockup's own strings
/// exactly — "39 min" under an hour, "1 h 24" at or past one.
enum DurationCopy {
    static func delta(_ duration: SleepDuration) -> String {
        let (hours, minutes) = duration.wholeHoursAndMinutes
        guard hours > 0 else {
            return "\(minutes) min"
        }
        return "\(hours) h \(String(format: "%02d", minutes))"
    }

    /// "7 h 40" — an elapsed duration since `computedAt`, matching the
    /// mockup's `.stale` card copy ("Mesure de 7 h 40").
    static func age(computedAt: Date, now: Date) -> String {
        delta(SleepDuration(seconds: max(0, now.timeIntervalSince(computedAt))))
    }
}
