import Foundation
import GlassKit
import SleepDebtCore
import SwiftUI
import WidgetKit

/// The real seven-state UI (docs/IMPLEMENTATION_PLAN.md §5, P6),
/// replacing P3's placeholder text now that P4 (GlassKit) and P5 (shared
/// components) exist. Exact pixel parity with the mockup isn't
/// achievable or independently verifiable without a device in this
/// environment (see issue #1's status note) — this is a structural
/// approximation built from GlassKit's components, compiler-verified via
/// CI, not screen-compared.
struct DeltaSleepWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        GlassSurface(
            tint: WidgetTint.tint(for: entry.state),
            environment: .widget,
            cornerRadius: GlassTokens.cornerRadiusWidget
        )
        .overlay {
            content
                .padding(GlassTokens.widgetPadding)
        }
        .widgetURL(URL(string: "deltasleep://open"))
        .containerBackground(for: .widget) {
            Color.clear
        }
        // Dynamic Type (docs/IMPLEMENTATION_PLAN.md §5, P9): GlassKit's
        // shared text (`DebtFigure`, `StateMessage`) scales with the
        // environment's type size, same as the phone screen — but a
        // widget's frame is fixed by its family, not scrollable, so
        // letting it grow all the way to the accessibility sizes would
        // overflow the card rather than reflow it. Clamped to a band
        // that still grows for readability without doing that; the
        // phone screen (`MainScreenView`) carries no such clamp.
        .dynamicTypeSize(.xSmall ... .xxxLarge)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case let .nominal(debt, trend):
            FigureCard(
                debt: debt,
                tint: WidgetTint.tint(for: entry.state),
                deltaSinceYesterday: entry.snapshot?.deltaSinceYesterday,
                subtitle: nil,
                nightBars: entry.snapshot?.nightBars ?? [],
                family: family
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(nominalLabel(debt: debt, trend: trend))
        case .zero:
            FigureCard(
                debt: .zero,
                tint: .green,
                deltaSinceYesterday: entry.snapshot?.deltaSinceYesterday,
                subtitle: nil,
                nightBars: entry.snapshot?.nightBars ?? [],
                family: family
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Dette de sommeil : zéro."))
        case let .cached(computedAt):
            FigureCard(
                debt: entry.snapshot?.debt ?? .zero,
                tint: .neutral,
                deltaSinceYesterday: nil,
                subtitle: "Mesure de \(Self.age(computedAt: computedAt, now: entry.date))",
                nightBars: entry.snapshot?.nightBars ?? [],
                family: family
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Donnée en cache, mesure ancienne."))
        case .noData:
            StateMessage(
                title: "Autoriser l'accès au sommeil",
                subtitle: "Ouvrir l'app pour l'activer"
            )
            .accessibilityElement(children: .combine)
        case let .insufficientHistory(measured, required):
            InsufficientHistoryContent(measured: measured, required: required)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    String(localized: "Historique insuffisant : \(measured) nuits sur \(required).")
                )
        case let .nightMissing(debt):
            FigureCard(
                debt: debt,
                tint: .amber,
                deltaSinceYesterday: nil,
                subtitle: "Cette nuit non mesurée",
                nightBars: entry.snapshot?.nightBars ?? [],
                family: family
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Nuit manquante, dette inchangée."))
        }
    }

    /// FR + EN strings (docs/IMPLEMENTATION_PLAN.md §5, P9, D9): two fixed
    /// sentence templates (one per `trend` case), each a single localized
    /// literal — same reasoning as `MainScreenView`'s
    /// `figureAccessibilityLabel` twin.
    private func nominalLabel(debt: SleepDuration, trend: Trend) -> String {
        let (hours, minutes) = debt.wholeHoursAndMinutes
        if trend == .rising {
            return String(
                localized: "Dette de sommeil : \(hours) heures \(minutes) minutes, en hausse."
            )
        }
        return String(
            localized: "Dette de sommeil : \(hours) heures \(minutes) minutes, en baisse."
        )
    }

    /// "7 h 40", matching the mockup's own `.stale` card copy ("Mesure de
    /// 7 h 40") — an elapsed duration, not a relative-time phrase.
    private static func age(computedAt: Date, now: Date) -> String {
        DurationCopy.delta(SleepDuration(seconds: max(0, now.timeIntervalSince(computedAt))))
    }
}

/// The label + figure + gauge + delta (or subtitle) card shared by the
/// nominal, zero, cached, and night-missing states — they differ only in
/// tint and what goes under the gauge, per the mockup's own cards.
private struct FigureCard: View {
    let debt: SleepDuration
    let tint: GlassTint
    let deltaSinceYesterday: SleepDuration?
    let subtitle: String?
    let nightBars: [NightStripMapping.Bar]
    let family: WidgetFamily

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            leftColumn
            if family == .systemMedium, !nightBars.isEmpty {
                rightColumn
            }
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DETTE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Spacer(minLength: 4)
            figureAndGauge
            bottomRow
        }
        .frame(width: family == .systemMedium ? 152 : nil, alignment: .leading)
    }

    private var figureAndGauge: some View {
        let numerals = debt.wholeHoursAndMinutes
        return VStack(alignment: .leading, spacing: 0) {
            DebtFigure(hours: numerals.hours, minutes: numerals.minutes, tint: tint, size: .widget)
            LiquidGauge(
                fillFraction: GaugeMapping.fraction(for: debt),
                ghostFraction: deltaSinceYesterday.map { GaugeMapping.fraction(for: debt - $0) },
                targetFraction: GaugeMapping.targetFraction,
                tint: tint,
                height: .compact
            )
            .padding(.top, 14)
        }
    }

    @ViewBuilder
    private var bottomRow: some View {
        if let deltaSinceYesterday {
            HStack(spacing: 4) {
                DeltaChip(
                    direction: deltaSinceYesterday.seconds >= 0 ? .up : .down,
                    text: DurationCopy.delta(
                        SleepDuration(seconds: abs(deltaSinceYesterday.seconds))
                    )
                )
                Text("depuis hier")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))
            }
            .padding(.top, 9)
        } else if let subtitle {
            Text(subtitle)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
                .padding(.top, 9)
        }
    }

    private var rightColumn: some View {
        VStack {
            Spacer()
            NightStrip(bars: nightBars.map {
                NightStrip.Bar(isGap: $0.isGap, isAboveAxis: $0.isSurplus, fraction: $0.fraction)
            })
            HStack {
                Text("14 nuits")
                Spacer()
                Text("cette nuit")
            }
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.5))
        }
    }
}

/// State 6's custom figure — "6 nuits / sur 14" rather than a duration,
/// and an empty gauge rather than a wrong one (the mockup's own framing).
private struct InsufficientHistoryContent: View {
    let measured: Int
    let required: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DETTE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Spacer(minLength: 4)
            Text("\(measured) nuits")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("sur \(required)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            LiquidGauge(
                fillFraction: GaugeMapping.minimumVisibleFraction,
                ghostFraction: nil,
                tint: .neutral,
                height: .compact
            )
            .padding(.top, 14)
            Text("Lecture à partir de \(required)")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
                .padding(.top, 9)
        }
    }
}
