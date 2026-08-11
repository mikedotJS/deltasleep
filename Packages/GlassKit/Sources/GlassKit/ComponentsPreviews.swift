import SwiftUI

// Assembles P5's components on a P4 GlassSurface, approximating the
// mockup's small green/red widget cards — a compiled, integration-level
// check that the pieces fit together, even without a device to look at
// them on (see issue #1's status note on what could and couldn't be
// verified in this environment).

#Preview("Small card — green, falling") {
    ZStack {
        Color.black
        GlassSurface(tint: .green, environment: .app, cornerRadius: GlassTokens.cornerRadiusWidget)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("DETTE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer()
                    DebtFigure(hours: 10, minutes: 26, tint: .green, size: .widget)
                    LiquidGauge(
                        fillFraction: 0.52,
                        ghostFraction: 0.554,
                        targetFraction: 0.375,
                        tint: .green,
                        height: .compact
                    )
                    .padding(.top, 14)
                    HStack(spacing: 4) {
                        DeltaChip(direction: .down, text: "39 min")
                        Text("depuis hier")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.74))
                    }
                    .padding(.top, 9)
                }
                .padding(18)
            }
            .frame(width: 176, height: 176)
    }
}

#Preview("Small card — insufficient history") {
    ZStack {
        Color.black
        GlassSurface(
            tint: .neutral, environment: .app, cornerRadius: GlassTokens.cornerRadiusWidget
        )
        .overlay {
            StateMessage(
                title: "Autoriser l'accès au sommeil",
                subtitle: "Ouvrir l'app pour l'activer"
            )
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(width: 176, height: 176)
    }
}

#Preview("Night strip") {
    ZStack {
        Color.black
        NightStrip(bars: [
            .init(isGap: false, isAboveAxis: false, fraction: 0.36),
            .init(isGap: false, isAboveAxis: false, fraction: 0.68),
            .init(isGap: false, isAboveAxis: true, fraction: 0.05),
            .init(isGap: false, isAboveAxis: false, fraction: 0.09),
            .init(isGap: false, isAboveAxis: false, fraction: 0.5),
            .init(isGap: false, isAboveAxis: false, fraction: 0.95),
            .init(isGap: false, isAboveAxis: false, fraction: 0.27),
            .init(isGap: false, isAboveAxis: true, fraction: 0.27),
            .init(isGap: false, isAboveAxis: false, fraction: 0.41),
            .init(isGap: true, isAboveAxis: false, fraction: 0),
            .init(isGap: false, isAboveAxis: false, fraction: 0.14),
            .init(isGap: false, isAboveAxis: false, fraction: 0),
            .init(isGap: false, isAboveAxis: false, fraction: 0.55),
            .init(isGap: false, isAboveAxis: false, fraction: 0.82),
        ])
        .padding(24)
    }
}
