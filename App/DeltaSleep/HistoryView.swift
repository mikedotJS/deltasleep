import SleepDebtCore
import SwiftUI

/// Phase 4 of the post-audit plan (PLAN.md): browse further back than
/// the debt engine's own 14-night window ever shows — read-only, no
/// action changes any of it.
struct HistoryView: View {
    let viewModel: HistoryViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.nights.isEmpty {
                // Audit's own edge-case grid (§B2): an empty state needs
                // an explanation, not a blank screen — same principle
                // already applied to `.insufficientHistory` on the main
                // screen (audit finding #18).
                emptyState
            } else {
                List(viewModel.nights, id: \.date) { night in
                    row(for: night)
                }
            }
        }
        .navigationTitle("Historique")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Aucun historique pour l'instant")
                .font(.headline)
            Text("Reviens une fois quelques nuits mesurées.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(for night: Night) -> some View {
        HStack {
            Text(night.date, style: .date)
            Spacer()
            if let asleep = night.asleep {
                Text(DurationCopy.delta(asleep))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text("Sans donnée")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
