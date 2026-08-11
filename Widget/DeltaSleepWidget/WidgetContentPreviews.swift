import SleepDebtCore
import SwiftUI
import WidgetKit

/// A gallery of all seven states (docs/IMPLEMENTATION_PLAN.md §5, P10) —
/// the closest thing to the plan's "screenshot fixtures" this environment
/// can produce: no simulator runtime here to boot and diff real
/// screenshots against, so this is a compiled, visually-inspectable
/// gallery for a real device/Xcode session, not automated pixel-diffing
/// (see issue #1's status note on the same limitation). Covers both
/// families for the states that render differently between them.
private enum PreviewFixture {
    static let need = SleepNeed(.hm(8, 0))

    static func bars(surplus: Bool) -> [NightStripMapping.Bar] {
        (0 ..< 14).map { index in
            NightStripMapping.Bar(
                isGap: index == 3, isSurplus: surplus, fraction: 0.3 + Double(index % 5) * 0.12
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    static func snapshot(
        debt: SleepDuration,
        trend: Trend,
        deltaSinceYesterday: SleepDuration?,
        lastNightIsGap: Bool,
        lastNightSleepDuration: SleepDuration?,
        surplus: Bool,
        computedAt: Date = Date()
    ) -> DebtSnapshot {
        DebtSnapshot(
            referenceDate: computedAt,
            need: need,
            debt: debt,
            trend: trend,
            breakEvenTarget: .hm(8, 0),
            deltaSinceYesterday: deltaSinceYesterday,
            deltaSinceMonday: deltaSinceYesterday,
            fourteenNightAverage: .hm(7, 15),
            measuredNightCount: 13,
            gapCount: 1,
            lastNightIsGap: lastNightIsGap,
            lastNightSleepDuration: lastNightSleepDuration,
            nightBars: bars(surplus: surplus),
            computedAt: computedAt
        )
    }

    static func entry(_ state: WidgetState, snapshot: DebtSnapshot? = nil) -> SnapshotEntry {
        SnapshotEntry(date: Date(), state: state, snapshot: snapshot)
    }

    static let nominalFalling = entry(
        .nominal(debt: .hm(6, 30), trend: .falling),
        snapshot: snapshot(
            debt: .hm(6, 30), trend: .falling, deltaSinceYesterday: .hm(-1, 0),
            lastNightIsGap: false, lastNightSleepDuration: .hm(8, 40), surplus: true
        )
    )

    static let nominalRising = entry(
        .nominal(debt: .hm(13, 4), trend: .rising),
        snapshot: snapshot(
            debt: .hm(13, 4), trend: .rising, deltaSinceYesterday: .hm(1, 10),
            lastNightIsGap: false, lastNightSleepDuration: .hm(6, 12), surplus: false
        )
    )

    static let zero = entry(
        .zero,
        snapshot: snapshot(
            debt: .zero, trend: .falling, deltaSinceYesterday: .hm(0, 30),
            lastNightIsGap: false, lastNightSleepDuration: .hm(8, 20), surplus: true
        )
    )

    static let cached = entry(
        .cached(computedAt: Date().addingTimeInterval(-StalenessPolicy.staleAfter - 3600)),
        snapshot: snapshot(
            debt: .hm(9, 15), trend: .rising, deltaSinceYesterday: .hm(0, 45),
            lastNightIsGap: false, lastNightSleepDuration: .hm(7, 10), surplus: false,
            computedAt: Date().addingTimeInterval(-StalenessPolicy.staleAfter - 3600)
        )
    )

    static let noData = entry(.noData)

    static let insufficientHistory = entry(
        .insufficientHistory(measuredNights: 6, requiredNights: 14)
    )

    static let nightMissing = entry(
        .nightMissing(debt: .hm(9, 40)),
        snapshot: snapshot(
            debt: .hm(9, 40), trend: .unknown, deltaSinceYesterday: nil,
            lastNightIsGap: true, lastNightSleepDuration: nil, surplus: false
        )
    )
}

#Preview("1 — Nominal, falling", as: .systemSmall) {
    DeltaSleepWidget()
} timeline: {
    PreviewFixture.nominalFalling
}

#Preview("1 — Nominal, falling (medium)", as: .systemMedium) {
    DeltaSleepWidget()
} timeline: {
    PreviewFixture.nominalFalling
}

#Preview("1/3 — Nominal, rising", as: .systemSmall) {
    DeltaSleepWidget()
} timeline: {
    PreviewFixture.nominalRising
}

#Preview("2 — Zero", as: .systemSmall) {
    DeltaSleepWidget()
} timeline: {
    PreviewFixture.zero
}

#Preview("4 — Cached (stale)", as: .systemSmall) {
    DeltaSleepWidget()
} timeline: {
    PreviewFixture.cached
}

#Preview("5 — No access", as: .systemSmall) {
    DeltaSleepWidget()
} timeline: {
    PreviewFixture.noData
}

#Preview("6 — Insufficient history", as: .systemSmall) {
    DeltaSleepWidget()
} timeline: {
    PreviewFixture.insufficientHistory
}

#Preview("7 — Night missing", as: .systemSmall) {
    DeltaSleepWidget()
} timeline: {
    PreviewFixture.nightMissing
}

#Preview("7 — Night missing (medium)", as: .systemMedium) {
    DeltaSleepWidget()
} timeline: {
    PreviewFixture.nightMissing
}
