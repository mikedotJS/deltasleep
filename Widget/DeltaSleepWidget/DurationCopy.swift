import Foundation
import SleepDebtCore

/// Duration copy matching the mockup's own strings exactly — "39 min"
/// under an hour, "1 h 24" at or past one (never "0 h 39"; never "84
/// min"). See docs/design/mockup-liquid-glass-v02.html's `.delta`
/// examples. FR + EN strings (P9, D9): built with `String(localized:)`
/// rather than plain interpolation — see the app target's twin of this
/// file for the same note.
enum DurationCopy {
    static func delta(_ duration: SleepDuration) -> String {
        let (hours, minutes) = duration.wholeHoursAndMinutes
        guard hours > 0 else {
            return String(localized: "\(minutes) min")
        }
        let paddedMinutes = String(format: "%02d", minutes)
        return String(localized: "\(hours) h \(paddedMinutes)")
    }
}
