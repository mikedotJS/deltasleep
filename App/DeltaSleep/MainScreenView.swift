import GlassKit
import SleepDebtCore
import SwiftUI
import UIKit

/// The mockup's `.phone` card (docs/IMPLEMENTATION_PLAN.md §5, P7) — the
/// app's home screen. Reuses the same `WidgetState` classification and
/// GlassKit components as the widget (P6), at the phone-card scale, so
/// the two surfaces can never disagree. First-run flow is out of scope
/// here (P8); this screen assumes P8's onboarding already ran.
struct MainScreenView: View {
    @State private var viewModel: MainScreenViewModel

    // Dynamic Type (docs/IMPLEMENTATION_PLAN.md §5, P9): every body-copy
    // size this screen owns directly (GlassKit's own text scales itself
    // — see `DebtFigure`/`StateMessage`), so the phone screen honours
    // the full range through the accessibility sizes, unlike the
    // widget's clamped one.
    @ScaledMetric private var labelSize: CGFloat = 10
    @ScaledMetric private var bodySize: CGFloat = 13.5
    @ScaledMetric private var captionSize: CGFloat = 12.5
    @ScaledMetric private var bigNumberSize: CGFloat = 24
    @ScaledMetric private var smallSize: CGFloat = 13

    init(viewModel: MainScreenViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            GlassSurface(
                tint: AppTint.tint(for: viewModel.state),
                environment: .app,
                cornerRadius: GlassTokens.cornerRadiusPhone
            )
            .overlay {
                content
                    .padding(.horizontal, GlassTokens.phonePaddingHorizontal)
                    .padding(.vertical, GlassTokens.phonePaddingVertical)
            }
            .padding(24)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.refresh()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            stateBody
                .padding(.top, 20)
            if let snapshot = viewModel.snapshot {
                statRows(snapshot: snapshot)
                    .padding(.top, 20)
            }
            needStepper
                .padding(.top, 20)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("DETTE DE SOMMEIL")
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text("14 NUITS")
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    @ViewBuilder
    private var stateBody: some View {
        switch viewModel.state {
        case let .nominal(debt, _):
            PhoneFigureSection(
                debt: debt,
                tint: AppTint.tint(for: viewModel.state),
                deltaSinceYesterday: viewModel.snapshot?.deltaSinceYesterday,
                deltaSinceMonday: viewModel.snapshot?.deltaSinceMonday,
                subtitle: nil,
                nightBars: viewModel.snapshot?.nightBars ?? []
            )
        case .zero:
            PhoneFigureSection(
                debt: .zero,
                tint: .green,
                deltaSinceYesterday: viewModel.snapshot?.deltaSinceYesterday,
                deltaSinceMonday: viewModel.snapshot?.deltaSinceMonday,
                subtitle: nil,
                nightBars: viewModel.snapshot?.nightBars ?? []
            )
        case let .cached(computedAt):
            PhoneFigureSection(
                debt: viewModel.snapshot?.debt ?? .zero,
                tint: .neutral,
                deltaSinceYesterday: nil,
                deltaSinceMonday: nil,
                subtitle: "Mesure de \(DurationCopy.age(computedAt: computedAt, now: Date()))",
                nightBars: viewModel.snapshot?.nightBars ?? []
            )
        case .noData:
            VStack(alignment: .leading, spacing: 12) {
                StateMessage(
                    title: "Autoriser l'accès au sommeil",
                    subtitle: "Réglages → Santé → Accès aux données"
                )
                .accessibilityElement(children: .combine)
                Button("Ouvrir les réglages", action: openSettings)
                    .font(.system(size: smallSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case let .insufficientHistory(measured, required):
            VStack(alignment: .leading, spacing: 8) {
                Text("\(measured) nuits sur \(required)")
                    .font(.system(size: bigNumberSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Lecture à partir de \(required)")
                    .font(.system(size: smallSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                insufficientHistoryAccessibilityLabel(measured: measured, required: required)
            )
        case let .nightMissing(debt):
            PhoneFigureSection(
                debt: debt,
                tint: .amber,
                deltaSinceYesterday: nil,
                deltaSinceMonday: nil,
                subtitle: "Cette nuit non mesurée",
                nightBars: viewModel.snapshot?.nightBars ?? []
            )
        }
    }

    /// FR + EN strings (P9, D9) — this and the other dynamic accessibility
    /// labels below build their copy with `String(localized:)` rather than
    /// plain interpolation, so a translator working from the string
    /// catalog can retranslate them like any other user-facing text
    /// (unlike a plain `String`, which VoiceOver would speak in French
    /// regardless of the device's language).
    private func insufficientHistoryAccessibilityLabel(measured: Int, required: Int) -> String {
        String(
            localized: """
            Historique insuffisant : \(measured) nuits sur \(required). \
            Lecture à partir de \(required) nuits.
            """
        )
    }

    private func statRows(snapshot: DebtSnapshot) -> some View {
        VStack(spacing: 0) {
            statRow(
                "Cette nuit",
                value: snapshot.lastNightSleepDuration.map(DurationCopy.delta) ?? "—"
            )
            statRow("Besoin réglé", value: DurationCopy.delta(snapshot.need.duration))
            statRow(
                "Moyenne sur 14 nuits", value: DurationCopy.delta(snapshot.fourteenNightAverage)
            )
            statRow("Nuits sans donnée", value: "\(snapshot.gapCount)")
        }
    }

    // `label` is `LocalizedStringKey` (every call site passes a literal),
    // `value` stays plain `String` — it's already-formatted, genuinely
    // dynamic copy (a duration or a count), not translatable source text
    // (P9, D9; same reasoning as `StateMessage`'s fields).
    private func statRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: bodySize))
                .foregroundStyle(.white.opacity(0.82))
            Spacer()
            Text(value)
                .font(.system(size: bodySize, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.16)).frame(height: 1)
        }
    }

    private var needStepper: some View {
        Stepper(
            value: Binding(
                get: { viewModel.sleepNeedHours },
                set: { newValue in
                    Task { await viewModel.updateSleepNeed(hours: newValue) }
                }
            ),
            in: 4 ... 12,
            step: 0.25
        ) {
            Text("Besoin : \(DurationCopy.delta(.hours(viewModel.sleepNeedHours)))")
                .font(.system(size: captionSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
        }
        .tint(.white)
    }

    /// Deep-links to this app's Settings page (Réglages → Santé is one tap
    /// further, but iOS doesn't expose a direct link into another app's
    /// Health-access sub-screen) — the recovery action for the `.noData`
    /// state, when HealthKit access was denied or revoked after onboarding.
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// The figure + gauge + two delta chips + night strip block shared by
/// the nominal, zero, cached, and night-missing states — larger than the
/// widget's `FigureCard` (64pt figure, taller gauge) and always shows
/// the full strip, per the mockup's phone card.
private struct PhoneFigureSection: View {
    let debt: SleepDuration
    let tint: GlassTint
    let deltaSinceYesterday: SleepDuration?
    let deltaSinceMonday: SleepDuration?
    let subtitle: String?
    let nightBars: [NightStripMapping.Bar]

    @ScaledMetric private var captionSize: CGFloat = 13
    @ScaledMetric private var tinySize: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            figureAndGauge
            if !nightBars.isEmpty {
                nightStrip
                    .padding(.top, 24)
            }
        }
    }

    private var figureAndGauge: some View {
        VStack(alignment: .leading, spacing: 0) {
            let numerals = debt.wholeHoursAndMinutes
            DebtFigure(hours: numerals.hours, minutes: numerals.minutes, tint: tint, size: .phone)
            gauge
                .padding(.top, 18)
            deltaRow
                .padding(.top, 12)
        }
        // VoiceOver (docs/IMPLEMENTATION_PLAN.md §5, P9): one stop for the
        // figure, the gauge, and the delta context together — the plan's
        // "value + yesterday's reference + direction" for the gauge is
        // exactly what `deltaSinceYesterday` already carries, so this
        // reuses the same values the visual chips read, rather than
        // re-deriving anything gauge-specific.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(figureAccessibilityLabel)
    }

    private var gauge: some View {
        LiquidGauge(
            fillFraction: GaugeMapping.fraction(for: debt),
            ghostFraction: deltaSinceYesterday.map { GaugeMapping.fraction(for: debt - $0) },
            targetFraction: GaugeMapping.targetFraction,
            tint: tint,
            height: .tall
        )
    }

    /// Built from a handful of fixed, fully-formed sentence templates
    /// (one per real call-site combination — see `stateBody`: the two
    /// deltas are always passed together or not at all, alongside an
    /// optional subtitle) rather than concatenated fragments, since a
    /// string catalog translates whole sentences, not runtime-glued
    /// pieces (word order varies by language). `subtitle` itself is
    /// plain, already-French copy from the caller, not a further
    /// localized fragment — a known, documented gap (P9 status note).
    private var figureAccessibilityLabel: String {
        let (hours, minutes) = debt.wholeHoursAndMinutes
        if let deltaSinceYesterday, let deltaSinceMonday {
            let seconds = abs(deltaSinceYesterday.seconds)
            let yesterday = DurationCopy.delta(SleepDuration(seconds: seconds))
            let monday = DurationCopy.delta(SleepDuration(seconds: abs(deltaSinceMonday.seconds)))
            if deltaSinceYesterday.seconds >= 0 {
                return String(
                    localized: """
                    Dette de sommeil : \(hours) heures \(minutes) minutes, en hausse \
                    depuis hier, écart de \(yesterday). Écart de \(monday) depuis lundi.
                    """
                )
            }
            return String(
                localized: """
                Dette de sommeil : \(hours) heures \(minutes) minutes, en baisse \
                depuis hier, écart de \(yesterday). Écart de \(monday) depuis lundi.
                """
            )
        }
        if let subtitle {
            return String(
                localized: "Dette de sommeil : \(hours) heures \(minutes) minutes. \(subtitle)"
            )
        }
        return String(localized: "Dette de sommeil : \(hours) heures \(minutes) minutes.")
    }

    @ViewBuilder
    private var deltaRow: some View {
        if deltaSinceYesterday != nil || deltaSinceMonday != nil {
            HStack(spacing: 8) {
                if let deltaSinceYesterday {
                    deltaChip(deltaSinceYesterday, caption: "depuis hier")
                }
                if let deltaSinceMonday {
                    deltaChip(deltaSinceMonday, caption: "depuis lundi")
                }
            }
        } else if let subtitle {
            Text(subtitle)
                .font(.system(size: captionSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
        }
    }

    private func deltaChip(_ delta: SleepDuration, caption: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            DeltaChip(
                direction: delta.seconds >= 0 ? .up : .down,
                text: DurationCopy.delta(SleepDuration(seconds: abs(delta.seconds)))
            )
            Text(caption)
                .font(.system(size: captionSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
        }
    }

    private var nightStrip: some View {
        let bars = nightBars.map {
            NightStrip.Bar(isGap: $0.isGap, isAboveAxis: $0.isSurplus, fraction: $0.fraction)
        }
        return VStack(alignment: .leading, spacing: 0) {
            NightStrip(bars: bars, height: 92)
            HStack {
                Text("14 nuits")
                Spacer()
                Text("cette nuit")
            }
            .font(.system(size: tinySize))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 8)
        }
        // VoiceOver (P9): "the strip as a summarised series," not 14
        // individually-focusable bars a screen reader user would have to
        // swipe through one at a time to get anything out of.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(nightStripAccessibilityLabel)
    }

    private var nightStripAccessibilityLabel: String {
        let above = nightBars.filter { $0.isSurplus && !$0.isGap }.count
        let below = nightBars.filter { !$0.isSurplus && !$0.isGap }.count
        let gaps = nightBars.filter(\.isGap).count
        return String(
            localized: """
            14 dernières nuits : \(above) au-dessus du besoin, \
            \(below) en dessous, \(gaps) sans donnée.
            """
        )
    }
}
