import Foundation
import Observation

/// Drives `OnboardingView` (docs/IMPLEMENTATION_PLAN.md §5, P8): the
/// first-run explainer shown once, before the HealthKit permission
/// prompt — not the silent auto-request P3 originally had.
@MainActor
@Observable
final class OnboardingViewModel {
    private static let didCompleteOnboardingKey = "didCompleteOnboarding"

    private(set) var hasCompletedOnboarding: Bool
    private(set) var isRequesting = false

    private let orchestrator: RefreshOrchestrator
    private let userDefaults: UserDefaults

    init(orchestrator: RefreshOrchestrator, userDefaults: UserDefaults = .standard) {
        self.orchestrator = orchestrator
        self.userDefaults = userDefaults
        hasCompletedOnboarding = userDefaults.bool(forKey: Self.didCompleteOnboardingKey)
    }

    /// Called from the "Autoriser l'accès au sommeil" button — triggers
    /// the real HealthKit prompt, then marks onboarding done regardless
    /// of the outcome (HealthKit never reports whether the user granted
    /// or denied; see `HealthAuthorizationState`). A denial is handled by
    /// the main screen's own noData state afterward, not by staying on
    /// this screen.
    func requestAccess() async {
        isRequesting = true
        await orchestrator.requestAuthorizationIfNeeded()
        userDefaults.set(true, forKey: Self.didCompleteOnboardingKey)
        hasCompletedOnboarding = true
        isRequesting = false
    }

    /// "Plus tard" (audit NOTE — the only visible forward action used to
    /// be the HealthKit prompt itself; declining it was only possible via
    /// the system sheet's own Cancel/Don't Allow, never explained in-app).
    /// Completes onboarding without ever triggering the system prompt —
    /// the main screen's `.noData` state already has its own "Autoriser
    /// l'accès" recovery action for whenever the user is ready.
    func skipForNow() {
        userDefaults.set(true, forKey: Self.didCompleteOnboardingKey)
        hasCompletedOnboarding = true
    }

    /// "Revoir l'explication" (post-audit PLAN.md Phase 2, closes one of
    /// the 3 confirmed capability gaps in BUSINESS_RULES.md — there was
    /// previously no way back to this screen once completed). Flips the
    /// flag `RootView` switches on; it re-renders `OnboardingView` on its
    /// own the moment this changes.
    func resetOnboarding() {
        userDefaults.set(false, forKey: Self.didCompleteOnboardingKey)
        hasCompletedOnboarding = false
    }
}
