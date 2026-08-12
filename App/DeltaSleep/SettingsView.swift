import SwiftUI

/// Phase 1 of the post-audit plan (PLAN.md): squelette only, no actions
/// wired — closes the three capability gaps `BUSINESS_RULES.md` confirmed
/// as real trous (revoir l'onboarding, historique > 14 nuits, effacer mes
/// données), one per row, over Phase 2 (onboarding + effacer) and Phase 4
/// (historique).
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                Label("Revoir l'explication", systemImage: "arrow.counterclockwise")
                Label("Historique", systemImage: "clock.arrow.circlepath")
                Label("Effacer mes données", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
