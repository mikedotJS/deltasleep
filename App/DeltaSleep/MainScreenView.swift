import GlassKit
import HealthSleepSource
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
    let onboardingViewModel: OnboardingViewModel

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

    // Audit NOTE: the Stepper's 0.25h step is fine for small nudges but
    // slow for jumping far from the current value — direct numeric entry
    // alongside it, not instead of it.
    @State private var showNeedEntry = false
    @State private var needEntryText = ""

    init(viewModel: MainScreenViewModel, onboardingViewModel: OnboardingViewModel) {
        _viewModel = State(initialValue: viewModel)
        self.onboardingViewModel = onboardingViewModel
    }

    var body: some View {
        ScrollView {
            // The content sizes the card, not the other way round.
            // `GlassSurface` has no intrinsic size — every layer it draws is
            // infinitely flexible — so as the *base* of the composition, with
            // all the content in a (layout-neutral) `.overlay`, it had no
            // height to adopt: a vertical `ScrollView` proposes an
            // unspecified height, the surface collapsed to SwiftUI's ~10pt
            // default, and the 44pt corner radius clipped into that strip
            // rendered as a thin bar drawn across the content, which itself
            // spilled outside the surface's bounds. As a `.background` the
            // surface is proposed the content's already-resolved size
            // instead, so the card wraps its content in every state and at
            // every Dynamic Type size.
            //
            // Padding order is load-bearing: the card's inner padding sits
            // *inside* the background so the surface covers it, the 24pt
            // screen margin *outside* so it stays a gap between card and
            // screen edge. `maxWidth: .infinity` keeps the card's width
            // constant across states — `header`/`statRow` contain a
            // `Spacer()` but the `.insufficientHistory`/`.noData` branches
            // don't, so without it the card would shrink-wrap the widest
            // text and change width per state.
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GlassTokens.phonePaddingHorizontal)
                .padding(.vertical, GlassTokens.phonePaddingVertical)
                .background {
                    GlassSurface(
                        tint: AppTint.tint(for: viewModel.state),
                        environment: .app,
                        cornerRadius: GlassTokens.cornerRadiusPhone
                    )
                }
                .padding(24)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.refresh()
        }
        // The card carries its own header row ("DETTE DE SOMMEIL" /
        // "14 NUITS"), so the bar deliberately shows no title text — but it
        // must still exist. Without a `navigationTitle`, `NavigationStack`
        // reserves no bar height at all and the toolbar's gear renders on top
        // of the card, in the exact corner "14 NUITS" occupies. `.inline`
        // reserves the 44pt strip rather than the large title's 96pt.
        //
        // Deliberately *not* adding `.toolbarBackground(.hidden, …)`: audit
        // finding #23 records that this top-trailing corner is the bloom
        // gradient's most saturated region, and the bar's material is what
        // keeps the white gear legible once the bright card scrolls under it.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Phase 1-2 of the post-audit plan (PLAN.md): the app's first
        // navigable screen beyond the flat onboarding/main-screen toggle.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(
                        viewModel: viewModel.makeSettingsViewModel(
                            onboardingViewModel: onboardingViewModel
                        )
                    )
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.white.opacity(0.8))
                }
                // Without this VoiceOver reads the SF Symbol's own name.
                .accessibilityLabel("Réglages")
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            // Audit finding #14: refresh failures were entirely silent —
            // a real HealthKit error and "nothing new since last time"
            // were indistinguishable to the user. This doesn't try to
            // explain *why* (the underlying error still isn't surfaced
            // in detail), just that the last attempt didn't succeed.
            if viewModel.lastRefreshFailed {
                Text("Dernier rafraîchissement échoué")
                    .font(.system(size: captionSize, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.top, GlassTokens.Spacing.sm)
            }
            stateBody
                .padding(.top, GlassTokens.Spacing.lg)
            if let snapshot = viewModel.snapshot {
                statRows(snapshot: snapshot)
                    .padding(.top, GlassTokens.Spacing.lg)
            }
            // Audit finding #24: this is the only interactive,
            // data-changing control on the screen, but used to follow the
            // exact same padding rhythm and comparable opacity as the
            // read-only stat rows above it — nothing marked the
            // transition from "information" to "setting."
            needStepper
                .padding(.top, GlassTokens.Spacing.xl)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.16)).frame(height: 1)
                }
            #if DEBUG
            debugStateMenu
                .padding(.top, GlassTokens.Spacing.lg)
            #endif
        }
    }

    #if DEBUG
    /// P10's debug state switcher (docs/IMPLEMENTATION_PLAN.md §5, P10) —
    /// forces any of the seven states through the real store + widget
    /// reload path (`DebugStateFixture`), so both this screen and the
    /// widget can be checked against every state without waiting on real
    /// HealthKit data. `#if DEBUG`-gated end to end; compiled out of
    /// release builds entirely.
    private var debugStateMenu: some View {
        Menu {
            ForEach(DebugStateFixture.allCases) { fixture in
                Button(fixture.rawValue) {
                    viewModel.applyDebugFixture(fixture)
                }
            }
        } label: {
            // Audit NOTE: plain text with no menu affordance — DEBUG-only,
            // but a chevron costs nothing and matches the system's own
            // menu-trigger convention.
            HStack(spacing: 4) {
                Text("État de débogage")
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: smallSize * 0.7, weight: .semibold))
            }
            .font(.system(size: smallSize, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
        }
    }
    #endif

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            // Audit finding #23: this header sits directly in
            // GlassSurface's bloom gradient's highest-saturation corner.
            // Nudged opacity up as a safe, contrast-only-improves
            // mitigation — exact on-device measurement across all 4
            // tints is still open (see AUDIT_FINDINGS.md's
            // "cas non vérifiables statiquement").
            Text("DETTE DE SOMMEIL")
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("14 NUITS")
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
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
            noDataBody
        case let .insufficientHistory(measured, required):
            VStack(alignment: .leading, spacing: 8) {
                // Audit finding #11: "1 nuits" is a real French plural
                // mistake, not a hypothetical — measured == 1 happens the
                // day after install.
                Text(measured == 1 ? "1 nuit sur \(required)" : "\(measured) nuits sur \(required)")
                    .font(.system(size: bigNumberSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Lecture à partir de \(required)")
                    .font(.system(size: smallSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                // Audit finding #18: the only one of the 7 states with no
                // actionable copy at all — this explains there's nothing
                // to do but keep the phone/Watch tracking sleep as usual.
                Text(
                    """
                    Continue de porter ta montre ou de dormir avec ton iPhone à proximité \
                    — la lecture s'activera automatiquement.
                    """
                )
                .font(.system(size: captionSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, GlassTokens.Spacing.xs)
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
        let nightsWord = measured == 1 ? "nuit" : "nuits"
        return String(
            localized: """
            Historique insuffisant : \(measured) \(nightsWord) sur \(required). \
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

    /// `label` is `LocalizedStringKey` (every call site passes a literal),
    /// `value` stays plain `String` — it's already-formatted, genuinely
    /// dynamic copy (a duration or a count), not translatable source text
    /// (P9, D9; same reasoning as `StateMessage`'s fields).
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
        // Audit finding #20: every other block on this screen groups
        // into one VoiceOver stop; statRow didn't, doubling the swipes
        // needed to get through the four stat rows.
        .accessibilityElement(children: .combine)
    }

    private var needStepper: some View {
        Stepper(
            value: Binding(
                get: { viewModel.sleepNeedHours },
                // Audit finding #12: updateSleepNeed itself debounces the
                // actual HealthKit refresh (see MainScreenViewModel) — a
                // held stepper's auto-repeat no longer fires a full
                // refresh cycle per tick.
                set: { newValue in viewModel.updateSleepNeed(hours: newValue) }
            ),
            in: 4 ... 12,
            step: 0.25
        ) {
            HStack {
                Button {
                    needEntryText = String(format: "%.2f", viewModel.sleepNeedHours)
                    showNeedEntry = true
                } label: {
                    Text("Besoin : \(DurationCopy.delta(.hours(viewModel.sleepNeedHours)))")
                        .font(.system(size: captionSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.74))
                        .underline()
                }
                .buttonStyle(.plain)
                if viewModel.isRefreshing {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                }
            }
        }
        .tint(.white)
        .alert("Besoin de sommeil", isPresented: $showNeedEntry) {
            TextField("Heures (4–12)", text: $needEntryText)
                .keyboardType(.decimalPad)
            Button("Annuler", role: .cancel) {}
            Button("Valider") {
                guard let hours = Double(needEntryText.replacingOccurrences(of: ",", with: "."))
                else {
                    return
                }
                viewModel.updateSleepNeed(hours: min(max(hours, 4), 12))
            }
        } message: {
            Text("Entre une valeur entre 4 et 12 heures.")
        }
    }

    /// Deep-links to this app's Settings page (Réglages → Santé is one tap
    /// further, but iOS doesn't expose a direct link into another app's
    /// Health-access sub-screen) — the recovery action for the `.noData`
    /// state, when HealthKit access was denied or revoked after onboarding.
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// `.noData`'s recovery action isn't one-size-fits-all:
    /// `viewModel.authState` (P2's `HealthAuthorizationState`, resolved
    /// only while this state is showing) tells `.needsPrompt` — where
    /// re-triggering the system prompt can actually grant access — apart
    /// from everything else, where it's already been asked and only
    /// Settings can change the answer. Defaults to the Settings action
    /// (the safe, always-correct fallback) while `authState` hasn't
    /// resolved yet or reads as anything other than `.needsPrompt`.
    private var noDataBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            StateMessage(
                title: "Autoriser l'accès au sommeil",
                subtitle: noDataSubtitle
            )
            .accessibilityElement(children: .combine)
            // Audit findings #5/#13: this is the *only* recovery path out
            // of .noData, and it used to be plain text with no button
            // chrome, no loading feedback, and no protection against a
            // repeat tap firing overlapping requests. Matches
            // OnboardingView's CTA treatment now.
            if viewModel.authState == .needsPrompt {
                Button {
                    Task { await viewModel.requestAccessAgain() }
                } label: {
                    HStack {
                        if viewModel.isRefreshing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Autoriser l'accès")
                                .font(.system(size: smallSize, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(RGBA(r255: 15, g255: 191, b255: 122).color)
                .disabled(viewModel.isRefreshing)
            } else {
                Button(action: openSettings) {
                    Text("Ouvrir les réglages")
                        .font(.system(size: smallSize, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(RGBA(r255: 15, g255: 191, b255: 122).color)
                .disabled(viewModel.isRefreshing)
            }
        }
    }

    private var noDataSubtitle: LocalizedStringKey {
        viewModel.authState == .needsPrompt
            ? "Aucune demande d'accès n'a encore abouti"
            : "Réglages → Santé → Accès aux données"
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
    /// Audit finding #22: no legend anywhere for the gauge's ticks or the
    /// night strip's encoding — a persistent, always-available "?" rather
    /// than a one-time coach-mark (simpler, no state to persist, always
    /// there if the user forgets).
    @State private var showLegend = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            figureAndGauge
            if !nightBars.isEmpty {
                nightStrip
                    .padding(.top, GlassTokens.Spacing.xl)
            }
        }
    }

    private var figureAndGauge: some View {
        VStack(alignment: .leading, spacing: 0) {
            let numerals = debt.wholeHoursAndMinutes
            DebtFigure(hours: numerals.hours, minutes: numerals.minutes, tint: tint, size: .phone)
            HStack(spacing: GlassTokens.Spacing.sm) {
                gauge
                legendButton
            }
            .padding(.top, 18)
            deltaRow
                .padding(.top, GlassTokens.Spacing.md)
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

    private var legendButton: some View {
        Button {
            showLegend = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Légende de la jauge et de la bande de nuits")
        .popover(isPresented: $showLegend) {
            legendContent
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }

    private var legendContent: some View {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.sm) {
            legendRow(symbol: "circle.dashed", text: "Trait pointillé : objectif (5h de dette)")
            legendRow(symbol: "minus", text: "Trait plein clair : dette d'hier")
            legendRow(symbol: "arrow.up.arrow.down", text: "▲/▼ : évolution depuis hier/lundi")
            legendRow(
                symbol: "rectangle.split.3x1",
                text: "Bande : nuits au-dessus/en dessous du besoin, 14 dernières"
            )
        }
        .font(.caption)
        .frame(maxWidth: 260, alignment: .leading)
    }

    private func legendRow(symbol: String, text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
        }
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
        // Audit finding #4: `deltaSinceMonday` is routinely nil (fewer
        // than 2 nights measured since Monday — the common case on
        // Monday/Tuesday) while `deltaSinceYesterday` is available.
        // Without these branches VoiceOver fell all the way through to
        // the generic sentence below even though the visual delta chip
        // was showing — the spoken and visible content diverged.
        if let deltaSinceYesterday {
            let seconds = abs(deltaSinceYesterday.seconds)
            let yesterday = DurationCopy.delta(SleepDuration(seconds: seconds))
            let direction = deltaSinceYesterday.seconds >= 0 ? "en hausse" : "en baisse"
            return String(
                localized: """
                Dette de sommeil : \(hours) heures \(minutes) minutes, \(direction) \
                depuis hier, écart de \(yesterday).
                """
            )
        }
        if let deltaSinceMonday {
            let monday = DurationCopy.delta(SleepDuration(seconds: abs(deltaSinceMonday.seconds)))
            let direction = deltaSinceMonday.seconds >= 0 ? "en hausse" : "en baisse"
            return String(
                localized: """
                Dette de sommeil : \(hours) heures \(minutes) minutes, \(direction) \
                depuis lundi, écart de \(monday).
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

    /// Audit NOTE: an exactly-zero delta used to render as `.up` — a
    /// "rising" arrow for a value that didn't actually change.
    private static func direction(for delta: SleepDuration) -> DeltaChip.Direction {
        if delta.seconds == 0 {
            return .flat
        }
        return delta.seconds > 0 ? .up : .down
    }

    private func deltaChip(_ delta: SleepDuration, caption: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            DeltaChip(
                direction: Self.direction(for: delta),
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
            .padding(.top, GlassTokens.Spacing.sm)
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
