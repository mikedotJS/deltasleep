import GlassKit
import SleepDebtCore
import SwiftUI

/// The mockup's `.phone` card (docs/IMPLEMENTATION_PLAN.md §5, P7) — the
/// app's home screen. Reuses the same `WidgetState` classification and
/// GlassKit components as the widget (P6), at the phone-card scale, so
/// the two surfaces can never disagree. First-run flow is out of scope
/// here (P8); this screen assumes P8's onboarding already ran.
struct MainScreenView: View {
    @State private var viewModel: MainScreenViewModel

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

    @ViewBuilder
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            Text("14 NUITS")
                .font(.system(size: 10, weight: .semibold))
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
            StateMessage(
                title: "Autoriser l'accès au sommeil",
                subtitle: "Réglages → Santé → Accès aux données"
            )
        case let .insufficientHistory(measured, required):
            VStack(alignment: .leading, spacing: 8) {
                Text("\(measured) nuits sur \(required)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Lecture à partir de \(required)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
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

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5))
                .foregroundStyle(.white.opacity(0.82))
            Spacer()
            Text(value)
                .font(.system(size: 13.5, weight: .bold))
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
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
        }
        .tint(.white)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let numerals = debt.wholeHoursAndMinutes
            DebtFigure(hours: numerals.hours, minutes: numerals.minutes, tint: tint, size: .phone)
            LiquidGauge(
                fillFraction: GaugeMapping.fraction(for: debt),
                ghostFraction: deltaSinceYesterday.map { GaugeMapping.fraction(for: debt - $0) },
                targetFraction: GaugeMapping.targetFraction,
                tint: tint,
                height: .tall
            )
            .padding(.top, 18)
            deltaRow
                .padding(.top, 12)
            if !nightBars.isEmpty {
                let bars = nightBars.map {
                    NightStrip.Bar(
                        isGap: $0.isGap, isAboveAxis: $0.isSurplus, fraction: $0.fraction
                    )
                }
                NightStrip(bars: bars, height: 92)
                .padding(.top, 24)
                HStack {
                    Text("14 nuits")
                    Spacer()
                    Text("cette nuit")
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 8)
            }
        }
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
        }
    }

    private func deltaChip(_ delta: SleepDuration, caption: String) -> some View {
        HStack(spacing: 4) {
            DeltaChip(
                direction: delta.seconds >= 0 ? .up : .down,
                text: DurationCopy.delta(SleepDuration(seconds: abs(delta.seconds)))
            )
            Text(caption)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
        }
    }
}
