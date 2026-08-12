import Foundation
import SleepDebtCore

/// Persists the user's configured sleep need (the mockup's "Besoin
/// réglé", default 8h00) in `UserDefaults` — small enough not to need
/// the App Group snapshot machinery, and read by both
/// `RefreshOrchestrator` (to know what to compute against) and the main
/// screen (P7) to show and edit it.
final class SleepNeedStore: @unchecked Sendable {
    private static let key = "sleepNeedSeconds"
    private static let changedDateKey = "sleepNeedChangedDate"
    private static let defaultNeed = SleepNeed(.hours(8))

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var current: SleepNeed {
        let seconds = userDefaults.double(forKey: Self.key)
        guard seconds > 0 else { return Self.defaultNeed }
        return SleepNeed(SleepDuration(seconds: seconds))
    }

    /// The date `set(_:)` last actually changed the stored value, or
    /// `nil` if it never has. `RefreshOrchestrator` compares this against
    /// "today" on every refresh (audit finding #8) so `Trend` stays
    /// frozen for the rest of the calendar day a change happened on, not
    /// just the single refresh that immediately follows it.
    var lastChangedDate: Date? {
        userDefaults.object(forKey: Self.changedDateKey) as? Date
    }

    /// Returns whether this call actually changed the stored value —
    /// `RefreshOrchestrator` uses this to decide `needChangedToday`,
    /// which freezes `Trend` rather than letting a settings change alone
    /// paint the figure green or red (P1's freeze-on-need-change rule,
    /// docs/IMPLEMENTATION_PLAN.md §1.1).
    @discardableResult
    func set(_ need: SleepNeed, now: Date = Date()) -> Bool {
        let changed = need != current
        userDefaults.set(need.duration.seconds, forKey: Self.key)
        if changed {
            userDefaults.set(now, forKey: Self.changedDateKey)
        }
        return changed
    }
}
