import Foundation
import XCTest
@testable import SleepDebtCore

/// Covers `WidgetState.classify`'s state-priority ordering — in particular
/// the audit fix for §32 (a missing last night must not be hidden behind a
/// "cached" reading just because the snapshot is also stale).
final class WidgetStateTests: XCTestCase {
    private func snapshot(
        lastNightIsGap: Bool,
        computedAt: Date,
        debt: SleepDuration = .hm(2, 0)
    ) -> DebtSnapshot {
        DebtSnapshot(
            referenceDate: computedAt,
            need: SleepNeed(.hm(8, 0)),
            debt: debt,
            trend: .falling,
            breakEvenTarget: .hm(8, 0),
            deltaSinceYesterday: nil,
            deltaSinceMonday: nil,
            fourteenNightAverage: .hm(7, 0),
            measuredNightCount: 13,
            gapCount: lastNightIsGap ? 1 : 0,
            lastNightIsGap: lastNightIsGap,
            lastNightSleepDuration: lastNightIsGap ? nil : .hm(7, 0),
            nightBars: [],
            computedAt: computedAt
        )
    }

    /// Le fait le plus important de cette suite : un snapshot à la fois
    /// périmé ET dont la dernière nuit est un gap doit se classer
    /// `.nightMissing`, jamais `.cached` — la nuit manquante prime.
    func testGapTakesPriorityOverStalenessWhenBothAreTrue() {
        let now = Date()
        let staleComputedAt = now.addingTimeInterval(-7 * 3600) // 7h ago, staleAfter = 6h
        let state = WidgetState.classify(
            history: .sufficient,
            snapshot: snapshot(lastNightIsGap: true, computedAt: staleComputedAt),
            staleAfter: 6 * 3600,
            now: now
        )
        guard case .nightMissing = state else {
            return XCTFail("expected .nightMissing, got \(state)")
        }
    }

    func testStaleWithoutGapStillClassifiesAsCached() {
        let now = Date()
        let staleComputedAt = now.addingTimeInterval(-7 * 3600)
        let state = WidgetState.classify(
            history: .sufficient,
            snapshot: snapshot(lastNightIsGap: false, computedAt: staleComputedAt),
            staleAfter: 6 * 3600,
            now: now
        )
        guard case .cached = state else {
            return XCTFail("expected .cached, got \(state)")
        }
    }

    func testFreshGapStillClassifiesAsNightMissing() {
        let now = Date()
        let freshComputedAt = now.addingTimeInterval(-1 * 3600)
        let state = WidgetState.classify(
            history: .sufficient,
            snapshot: snapshot(lastNightIsGap: true, computedAt: freshComputedAt),
            staleAfter: 6 * 3600,
            now: now
        )
        guard case .nightMissing = state else {
            return XCTFail("expected .nightMissing, got \(state)")
        }
    }

    func testFreshNonGapClassifiesAsNominal() {
        let now = Date()
        let state = WidgetState.classify(
            history: .sufficient,
            snapshot: snapshot(lastNightIsGap: false, computedAt: now),
            staleAfter: 6 * 3600,
            now: now
        )
        guard case .nominal = state else {
            return XCTFail("expected .nominal, got \(state)")
        }
    }
}
