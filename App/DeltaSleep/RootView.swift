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
        Group {
            if onboardingViewModel.hasCompletedOnboarding {
                // The app's first real navigation stack — Settings
                // (Phase 1 of the post-audit plan) is the first screen
                // that isn't a flat top-level toggle in RootView itself.
                NavigationStack {
                    MainScreenView(viewModel: mainScreenViewModel)
                }
            } else {
                OnboardingView(viewModel: onboardingViewModel)
            }
        }
        // Every GlassKit surface (translucent white gradients, a
        // white-opacity text ladder) is designed against a near-black
        // backdrop — OnboardingView already forces one locally
        // (Color.black.ignoresSafeArea()), but MainScreenView never did.
        // In system Light Mode the glass UI rendered on a light
        // background instead, reading as almost blank (audit finding
        // #3). Forcing dark here covers both screens from the one place
        // that actually roots the app.
        .preferredColorScheme(.dark)
    }
}
