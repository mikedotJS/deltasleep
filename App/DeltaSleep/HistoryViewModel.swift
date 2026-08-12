import Foundation
import Observation
import SleepDebtCore

/// Drives `HistoryView` (post-audit PLAN.md Phase 4) — the "historique
/// > 14 nuits" capability gap `BUSINESS_RULES.md` confirmed as a real
/// trou. Deliberately its own small view model rather than reusing
/// `MainScreenViewModel`: this reads live from HealthKit on demand
/// (`RefreshOrchestrator.history`), it doesn't touch the cached debt
/// snapshot or drive any of the seven `WidgetState` cases.
@MainActor
@Observable
final class HistoryViewModel {
    private(set) var nights: [Night] = []
    private(set) var isLoading = false

    private let orchestrator: RefreshOrchestrator
    private let daysBack: Int

    init(orchestrator: RefreshOrchestrator, daysBack: Int = 90) {
        self.orchestrator = orchestrator
        self.daysBack = daysBack
    }

    /// Most recent first for display — `RefreshOrchestrator.history`
    /// itself returns oldest-first (matching `SleepIngestion.days`).
    func load() async {
        isLoading = true
        nights = await Array(orchestrator.history(daysBack: daysBack).reversed())
        isLoading = false
    }
}
