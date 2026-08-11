import Foundation
import SleepDebtCore

/// Persists the user's configured sleep need (the mockup's "Besoin
/// réglé", default 8h00) in `UserDefaults` — small enough not to need
/// the App Group snapshot machinery, and read by both
/// `RefreshOrchestrator` (to know what to compute against) and the main
/// screen (P7) to show and edit it.
final class SleepNeedStore: @unchecked Sendable {
    private static let key = "sleepNeedSeconds"
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

    /// Returns whether this call actually changed the stored value —
    /// `RefreshOrchestrator` uses this to decide `needChangedToday`,
    /// which freezes `Trend` rather than letting a settings change alone
    /// paint the figure green or red (P1's freeze-on-need-change rule,
    /// docs/IMPLEMENTATION_PLAN.md §1.1).
    @discardableResult
    func set(_ need: SleepNeed) -> Bool {
        let changed = need != current
        userDefaults.set(need.duration.seconds, forKey: Self.key)
        return changed
    }
}
