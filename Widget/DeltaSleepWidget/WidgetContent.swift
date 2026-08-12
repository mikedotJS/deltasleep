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
        content
            .padding(GlassTokens.widgetPadding)
            // Restates the geometry the old `.overlay { content }` got for
            // free (an overlay centres and fills its base), now that the
            // surface no longer sits in this layer.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(URL(string: "deltasleep://open"))
            .containerBackground(for: .widget) { backdrop }
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

    /// The opaque dark base plus the glass, in the one layer WidgetKit
    /// guarantees reaches the widget's real edges.
    ///
    /// This was `Color.clear`, betting that iOS 26 composites a live system
    /// Liquid Glass container behind widget content (issue #1's S1 verdict,
    /// which flags itself as documented-capability analysis rather than
    /// on-device verification). A device falsified it: on a light wallpaper
    /// the widget rendered as a white square, because every `GlassSurface`
    /// layer is white-alpha and every label is white. The app hit the
    /// identical bug and fixed it at `RootView`'s
    /// `.preferredColorScheme(.dark)`; a widget has no colour scheme of its
    /// own — only a wallpaper of arbitrary luminance — so it paints its own.
    ///
    /// Two reasons this belongs in `containerBackground` rather than behind
    /// `content`:
    ///  - WidgetKit insets *content* by its default margins but never the
    ///    container background. A surface drawn in the content layer would
    ///    float inside a dark bezel instead of bleeding to the edges.
    ///  - The specular's `.plusLighter` and the grain's `.softLight` blend
    ///    against what is beneath them *in the same compositing group*. Here
    ///    that's the opaque colour directly below them; split across two
    ///    WidgetKit layers there is no defined base.
    ///
    /// It also means the glass participates correctly in background removal:
    /// StandBy and the Lock Screen strip the container background, so the
    /// translucent card goes with it rather than being left floating.
    ///
    /// `cornerRadius: 0` is deliberate — WidgetKit already clips the
    /// container to the platform's own shape, whose radius the app doesn't
    /// choose. A second 34pt clip here could only cut *inside* that shape and
    /// shave the corners, never round them further.
    ///
    /// Not handled, deliberately: iOS 18+ tinted/accented Home Screen modes.
    /// An all-white view tree collapses to a uniform block under `.accented`
    /// — same root cause, but a different pipeline (`\.widgetRenderingMode`)
    /// and a design decision (which elements are `.widgetAccentable`) rather
    /// than a bug fix. Tracked separately.
    private var backdrop: some View {
        ZStack {
            GlassTokens.backdrop.color
            GlassSurface(
                tint: WidgetTint.tint(for: entry.state),
                environment: .widget,
                cornerRadius: 0
            )
        }
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
            .accessibilityLabel(nominalLabel(debt: debt, trend: trend) + nightStripSuffix)
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
            .accessibilityLabel(Text("Dette de sommeil : zéro." + nightStripSuffix))
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
            .accessibilityLabel(Text("Donnée en cache, mesure ancienne." + nightStripSuffix))
        case .noData:
            StateMessage(
                title: "Autoriser l'accès au sommeil",
                subtitle: "Ouvrir l'app pour l'activer"
            )
            .accessibilityElement(children: .combine)
        case let .insufficientHistory(measured, required):
            InsufficientHistoryContent(measured: measured, required: required)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(insufficientHistoryLabel(
                    measured: measured,
                    required: required
                ))
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
            .accessibilityLabel(Text("Nuit manquante, dette inchangée." + nightStripSuffix))
        }
    }

    /// Audit finding #17: on `.systemMedium`, the night strip's
    /// above/below/gap distribution used to be entirely invisible to
    /// VoiceOver — every accessibility label described only the figure.
    /// Appended (not a full re-read of `MainScreenView`'s richer
    /// `nightStripAccessibilityLabel` — a widget label needs to stay
    /// short) to whichever state's label wins above.
    private var nightStripSuffix: String {
        guard family == .systemMedium else { return "" }
        let bars = entry.snapshot?.nightBars ?? []
        let gaps = bars.filter(\.isGap).count
        guard gaps > 0 else { return "" }
        return gaps == 1
            ? String(localized: " 1 nuit sans donnée.")
            : String(localized: " \(gaps) nuits sans données.")
    }

    private func insufficientHistoryLabel(measured: Int, required: Int) -> String {
        let nightsWord = measured == 1 ? "nuit" : "nuits"
        return String(
            localized: "Historique insuffisant : \(measured) \(nightsWord) sur \(required)."
        )
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
    ///
    /// Audit finding #19: `DurationCopy.delta` has no upper bound. After
    /// a long stretch without a successful refresh (permission revoked
    /// + HealthKit errors silently swallowed upstream) this could render
    /// as "Mesure de 2160 h 00" — unbounded text with no `.lineLimit` in
    /// the widget's fixed, non-scrollable frame. Past a day, switch to a
    /// day count instead of ever-growing hours.
    private static func age(computedAt: Date, now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(computedAt))
        let days = Int(elapsed / 86400)
        guard days >= 1 else {
            return DurationCopy.delta(SleepDuration(seconds: elapsed))
        }
        return days == 1 ? String(localized: "1 jour") : String(localized: "\(days) jours")
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

    /// Audit NOTE: an exactly-zero delta used to render as `.up` — a
    /// "rising" arrow for a value that didn't actually change. Same
    /// fix as `MainScreenView`'s twin helper.
    private static func direction(for delta: SleepDuration) -> DeltaChip.Direction {
        if delta.seconds == 0 {
            return .flat
        }
        return delta.seconds > 0 ? .up : .down
    }

    @ViewBuilder
    private var bottomRow: some View {
        if let deltaSinceYesterday {
            HStack(spacing: 4) {
                DeltaChip(
                    direction: Self.direction(for: deltaSinceYesterday),
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
            // Audit finding #11: same "1 nuits" mistake as the app's
            // equivalent screen — measured == 1 is real, the day after
            // install.
            // Shrink rather than truncate. Recovering WidgetKit's default
            // margins (see `DeltaSleepWidget`'s `.contentMarginsDisabled()`)
            // buys back ~32pt, but "9 nuits" at 34pt bold rounded is still
            // wider than a `systemSmall` card at larger Dynamic Type sizes —
            // and "9 n…" tells the user nothing. Same treatment `DebtFigure`
            // already carries for the same reason (audit finding #15).
            Text(measured == 1 ? "1 nuit" : "\(measured) nuits")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("sur \(required)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            LiquidGauge(
                fillFraction: GaugeMapping.minimumVisibleFraction,
                ghostFraction: nil,
                tint: .neutral,
                height: .compact
            )
            .padding(.top, 14)
            // Allowed to wrap to a second line rather than shrink: at 11.5pt
            // this is already the smallest copy on the card, and "Lecture à
            // part…" loses the one number that makes the sentence mean
            // anything.
            Text("Lecture à partir de \(required)")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.top, 9)
        }
    }
}
