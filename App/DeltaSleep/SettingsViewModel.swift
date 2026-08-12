import Foundation
import Observation
import SnapshotStore

/// Drives `SettingsView` (post-audit PLAN.md Phase 2) — closes 2 of the
/// 3 capability gaps `BUSINESS_RULES.md` confirmed as real trous
/// (revoir l'onboarding, effacer mes données; the third, historique
/// étendu, is Phase 3-4).
@MainActor
@Observable
final class SettingsViewModel {
    private(set) var isErasing = false

    private let store: SnapshotStoring
    private let needStore: SleepNeedStore
    private let orchestrator: RefreshOrchestrator
    private let onboardingViewModel: OnboardingViewModel

    init(
        store: SnapshotStoring,
        needStore: SleepNeedStore,
        orchestrator: RefreshOrchestrator,
        onboardingViewModel: OnboardingViewModel
    ) {
        self.store = store
        self.needStore = needStore
        self.orchestrator = orchestrator
        self.onboardingViewModel = onboardingViewModel
    }

    /// "Revoir l'explication" — a pure informational replay. Doesn't
    /// touch HealthKit authorization or any cached data: the user
    /// already granted (or was asked about) access, this just shows the
    /// explainer again. `RootView` reacts to `onboardingViewModel`
    /// changing and swaps `SettingsView`'s whole navigation stack out
    /// for `OnboardingView` on its own.
    func reviewOnboarding() {
        onboardingViewModel.resetOnboarding()
    }

    /// "Effacer mes données" — genuine erasure, not just a state flag:
    /// removes the cached snapshot/history files from disk (`store.clear()`,
    /// not `writeHistoryAvailability(.none)` — see that method's doc
    /// comment for why those aren't equivalent), resets the sleep-need
    /// setting to its default, clears the "did we ask HealthKit" flag so
    /// a future onboarding replay re-prompts for real, and sends the
    /// user back through onboarding — the closest native equivalent to
    /// "log out" for an app with no account system.
    func eraseAllData() async {
        isErasing = true
        try? store.clear()
        needStore.reset()
        await orchestrator.resetAuthorizationRequestFlag()
        onboardingViewModel.resetOnboarding()
        isErasing = false
    }
}
