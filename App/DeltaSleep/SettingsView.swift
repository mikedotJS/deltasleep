import SwiftUI

/// Phase 2 of the post-audit plan (PLAN.md): "Revoir l'explication" and
/// "Effacer mes données" are fully wired; "Historique" stays a placeholder
/// until Phase 4 builds the screen it links to.
struct SettingsView: View {
    let viewModel: SettingsViewModel
    @State private var showEraseConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Button {
                    viewModel.reviewOnboarding()
                } label: {
                    Label("Revoir l'explication", systemImage: "arrow.counterclockwise")
                }

                Label("Historique", systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
            }

            Section {
                // Error Prevention (audit's own design-principles pass):
                // destructive action gets a confirmation step, not an
                // immediate irreversible tap.
                Button(role: .destructive) {
                    showEraseConfirmation = true
                } label: {
                    if viewModel.isErasing {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Label("Effacer mes données", systemImage: "trash")
                    }
                }
                .disabled(viewModel.isErasing)
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Effacer toutes les données ?", isPresented: $showEraseConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Effacer", role: .destructive) {
                Task { await viewModel.eraseAllData() }
            }
        } message: {
            Text(
                """
                Ta dette de sommeil, ton besoin réglé et l'accès à Santé seront réinitialisés. \
                Cette action est irréversible.
                """
            )
        }
    }
}
