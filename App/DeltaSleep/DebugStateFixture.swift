#if DEBUG
import Foundation
import SleepDebtCore
import SnapshotStore

/// P10's debug state switcher backend (docs/IMPLEMENTATION_PLAN.md §5,
/// P10): forces any of the seven states by writing synthetic data
/// through the exact same `SnapshotStoring` + `WidgetReloading` path a
/// real `RefreshCoordinator.refresh` uses — the widget needs no
/// debug-only code of its own, since it already renders whatever the
/// store holds. `#if DEBUG`-gated end to end, not just hidden behind a
/// UI toggle, so none of this reaches a release build.
enum DebugStateFixture: String, CaseIterable, Identifiable {
    case nominalFalling = "Nominal — en baisse"
    case nominalRising = "Nominal — en hausse"
    case zero = "Zéro"
    case cached = "En cache (ancien)"
    case noData = "Pas d'accès"
    case insufficientHistory = "Historique insuffisant"
    case nightMissing = "Nuit manquante"

    var id: String {
        rawValue
    }

    /// Writes this fixture, then reloads widget timelines — the same
    /// two effects a real refresh has, so both the app (on its next
    /// `refresh()`) and the widget pick it up exactly the way they'd
    /// pick up genuine data.
    ///
    /// `need` is the tester's *actually configured* sleep need (audit
    /// finding #93) — every fixture used to hard-code 8h00 regardless,
    /// so the "Besoin réglé" stat row and the Stepper right below it
    /// could disagree during a debug session, a mismatch that never
    /// happens with real data.
    func apply(
        store: SnapshotStoring, reloader: WidgetReloading, need: SleepNeed, now: Date = Date()
    ) throws {
        try store.writeHistoryAvailability(historyAvailability)
        if let snapshot = makeSnapshot(now: now, need: need) {
            try store.writeSnapshot(snapshot)
        }
        reloader.reloadAllTimelines()
    }

    private var historyAvailability: HistoryAvailability {
        switch self {
        case .noData: .none
        case .insufficientHistory: .insufficient(measuredNights: 6, requiredNights: 14)
        case .nominalFalling, .nominalRising, .zero, .cached, .nightMissing: .sufficient
        }
    }

    private static func bars(surplus: Bool) -> [NightStripMapping.Bar] {
        (0 ..< 14).map { index in
            NightStripMapping.Bar(
                isGap: index == 3, isSurplus: surplus, fraction: 0.3 + Double(index % 5) * 0.12
            )
        }
    }

    private func makeSnapshot(now: Date, need: SleepNeed) -> DebtSnapshot? {
        switch self {
        case .noData, .insufficientHistory:
            nil
        case .nominalFalling:
            Self.snapshot(
                now: now, need: need, debt: .hm(6, 30), trend: .falling,
                deltaSinceYesterday: .hm(-1, 0), deltaSinceMonday: .hm(-2, 15),
                lastNightIsGap: false, lastNightSleepDuration: .hm(8, 40), surplus: true
            )
        case .nominalRising:
            Self.snapshot(
                now: now, need: need, debt: .hm(13, 4), trend: .rising,
                deltaSinceYesterday: .hm(1, 10), deltaSinceMonday: .hm(2, 30),
                lastNightIsGap: false, lastNightSleepDuration: .hm(6, 12), surplus: false
            )
        case .zero:
            Self.snapshot(
                now: now, need: need, debt: .zero, trend: .falling,
                deltaSinceYesterday: .hm(0, 30), deltaSinceMonday: .hm(1, 0),
                lastNightIsGap: false, lastNightSleepDuration: .hm(8, 20), surplus: true
            )
        case .cached:
            Self.snapshot(
                now: now.addingTimeInterval(-StalenessPolicy.staleAfter - 3600), need: need,
                debt: .hm(9, 15), trend: .rising,
                deltaSinceYesterday: .hm(0, 45), deltaSinceMonday: .hm(1, 20),
                lastNightIsGap: false, lastNightSleepDuration: .hm(7, 10), surplus: false
            )
        case .nightMissing:
            Self.snapshot(
                now: now, need: need, debt: .hm(9, 40), trend: .unknown,
                deltaSinceYesterday: nil, deltaSinceMonday: nil,
                lastNightIsGap: true, lastNightSleepDuration: nil, surplus: false
            )
        }
    }

    private static func snapshot(
        now: Date,
        need: SleepNeed,
        debt: SleepDuration,
        trend: Trend,
        deltaSinceYesterday: SleepDuration?,
        deltaSinceMonday: SleepDuration?,
        lastNightIsGap: Bool,
        lastNightSleepDuration: SleepDuration?,
        surplus: Bool
    ) -> DebtSnapshot {
        DebtSnapshot(
            referenceDate: now,
            need: need,
            debt: debt,
            trend: trend,
            // Was hard-coded to .hm(8, 0) independently of `need` — a
            // second figure that could disagree with the tester's real
            // setting, on top of the one `need` itself used to be.
            breakEvenTarget: need.duration,
            deltaSinceYesterday: deltaSinceYesterday,
            deltaSinceMonday: deltaSinceMonday,
            fourteenNightAverage: .hm(7, 15),
            measuredNightCount: 13,
            gapCount: 1,
            lastNightIsGap: lastNightIsGap,
            lastNightSleepDuration: lastNightSleepDuration,
            nightBars: bars(surplus: surplus),
            computedAt: now
        )
    }
}
#endif
