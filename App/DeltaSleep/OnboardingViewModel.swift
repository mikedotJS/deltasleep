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
}
