import SwiftUI

/// Switches between `OnboardingView` and `MainScreenView`
/// (docs/IMPLEMENTATION_PLAN.md §5, P8) — the app's actual root, so
/// first launch shows the explainer before anything tries to read
/// HealthKit data, and every later launch goes straight to the main
/// screen.
struct RootView: View {
    let onboardingViewModel: OnboardingViewModel
    let mainScreenViewModel: MainScreenViewModel

    var body: some View {
        if onboardingViewModel.hasCompletedOnboarding {
            MainScreenView(viewModel: mainScreenViewModel)
        } else {
            OnboardingView(viewModel: onboardingViewModel)
        }
    }
}
