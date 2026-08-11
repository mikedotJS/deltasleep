import SwiftUI

/// The mockup's `.track`/`.fill`/`.ghost`: a liquid-look gradient gauge
/// with a glow, a "yesterday" ghost tick, and a static target tick.
///
/// Takes an already-computed `fillFraction` (0...1) rather than a raw
/// debt value — `SleepDebtCore.GaugeMapping` (P1) owns the two-segment
/// 0–8h/8–24h transfer function (D10); duplicating that math here would
/// both violate GlassKit's "no SleepDebtCore" constraint (P4's scope) and
/// split the one place D10's constants get retuned. Callers (P6/P7) call
/// `GaugeMapping.fraction(for:)` and pass the result in.
public struct LiquidGauge: View {
    public enum Height: Sendable {
        case compact
        case tall

        var trackHeight: CGFloat {
            self == .compact ? 9 : 11
        }

        var ghostHeight: CGFloat {
            self == .compact ? 17 : 21
        }
    }

    private let fillFraction: Double
    private let ghostFraction: Double?
    private let targetFraction: Double?
    private let tint: GlassTint
    private let height: Height

    public init(
        fillFraction: Double,
        ghostFraction: Double?,
        targetFraction: Double? = nil,
        tint: GlassTint,
        height: Height
    ) {
        self.fillFraction = fillFraction
        self.ghostFraction = ghostFraction
        self.targetFraction = targetFraction
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        let palette = GlassTokens.palette(for: tint)
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.26))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [palette.fillStart.color, palette.fillEnd.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * fillFraction)
                    .shadow(color: palette.fillGlow.color, radius: 7)
                if let targetFraction {
                    tick(
                        at: targetFraction, in: proxy.size.width, width: 1,
                        tickHeight: height.trackHeight, color: .white.opacity(0.4)
                    )
                }
                if let ghostFraction {
                    tick(
                        at: ghostFraction, in: proxy.size.width, width: 2,
                        tickHeight: height.ghostHeight, color: .white.opacity(0.82)
                    )
                    .shadow(color: .white.opacity(0.5), radius: 4)
                }
            }
        }
        .frame(height: height.trackHeight)
    }

    private func tick(
        at fraction: Double,
        in trackWidth: CGFloat,
        width: CGFloat,
        tickHeight: CGFloat,
        color: Color
    ) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: tickHeight)
            .offset(x: trackWidth * fraction - width / 2, y: -(tickHeight - height.trackHeight) / 2)
    }
}
