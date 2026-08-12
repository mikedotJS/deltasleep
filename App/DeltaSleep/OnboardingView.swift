import GlassKit
import SwiftUI

/// The first-run explainer (docs/IMPLEMENTATION_PLAN.md §5, P8): what the
/// app does and why it needs Health access, shown once, before the
/// system permission prompt — not the app silently asking on launch.
struct OnboardingView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Text("deltasleep")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(explainerText)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button {
                    Task { await viewModel.requestAccess() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Autoriser l'accès au sommeil")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(RGBA(r255: 15, g255: 191, b255: 122).color)
                .disabled(viewModel.isRequesting)
                // Audit NOTE: the only visible forward action was the
                // system-prompt trigger itself — declining was only
                // possible via the system sheet's own Cancel/Don't Allow,
                // never explained or offered in-app.
                Button("Plus tard") {
                    viewModel.skipForNow()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .disabled(viewModel.isRequesting)
                .frame(maxWidth: .infinity)
            }
            .padding(32)
        }
    }

    /// FR + EN strings (P9, D9): `LocalizedStringKey`, not `String` — a
    /// plain `String` here would always display in French, catalog or
    /// not (same reasoning as `StateMessage`'s fields).
    private var explainerText: LocalizedStringKey {
        """
        deltasleep lit tes nuits de sommeil dans Santé pour calculer ta dette de \
        sommeil — un chiffre qui monte ou descend selon que tu dors plus ou moins \
        que ton besoin. Rien ne quitte ton appareil.
        """
    }
}
