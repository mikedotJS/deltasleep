import Foundation
import SleepDebtCore

/// French duration copy matching the mockup's own strings exactly — "39
/// min" under an hour, "1 h 24" at or past one (never "0 h 39"; never
/// "84 min"). See docs/design/mockup-liquid-glass-v02.html's `.delta`
/// examples.
enum DurationCopy {
    static func delta(_ duration: SleepDuration) -> String {
        let (hours, minutes) = duration.wholeHoursAndMinutes
        guard hours > 0 else {
            return "\(minutes) min"
        }
        return "\(hours) h \(String(format: "%02d", minutes))"
    }
}
