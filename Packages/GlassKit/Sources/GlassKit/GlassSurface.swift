import SwiftUI

/// The mockup's `.w` card, as a reusable SwiftUI surface: base gradient,
/// two-radial semantic bloom, rotated specular sweep, and grain overlay
/// (docs/design/mockup-liquid-glass-v02.html, §"verre"). One recipe drives
/// both the app and the widget — S1's finding (issue #1) is that a widget
/// can't sample the live wallpaper any more than the app can fake it, so
/// there's no separate "real glass" backend to switch to; only the outer
/// edge/shadow differs by `GlassEnvironment`, handled by `OuterChrome`.
///
/// Exact pixel parity with the CSS (gradient angles, radial-gradient
/// sizing keywords, `mix-blend-mode`) isn't achievable or verifiable
/// without a device — this is a structural approximation, not a
/// pixel-matched port. A real device pass is still owed before release
/// (see issue #1's status note).
public struct GlassSurface: View {
    private let tint: GlassTint
    private let environment: GlassEnvironment
    private let cornerRadius: Double

    public init(tint: GlassTint, environment: GlassEnvironment, cornerRadius: Double) {
        self.tint = tint
        self.environment = environment
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let palette = GlassTokens.palette(for: tint)
        ZStack {
            baseGradient
            bloom(palette: palette)
            specular
            GrainOverlay()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .modifier(OuterChrome(environment: environment, cornerRadius: cornerRadius))
    }

    private var baseGradient: some View {
        LinearGradient(
            colors: [
                GlassTokens.surfaceGradientStart.color,
                GlassTokens.surfaceGradientMid.color,
                GlassTokens.surfaceGradientEnd.color,
            ],
            startPoint: UnitPoint(x: 0.13, y: 0),
            endPoint: UnitPoint(x: 0.87, y: 1)
        )
    }

    private func bloom(palette: TintPalette) -> some View {
        GeometryReader { proxy in
            let radius = max(proxy.size.width, proxy.size.height) * 1.1
            ZStack {
                RadialGradient(
                    colors: [palette.bloom1.color, .clear],
                    center: UnitPoint(x: 0.16, y: 0.04),
                    startRadius: 0,
                    endRadius: radius
                )
                RadialGradient(
                    colors: [palette.bloom2.color, .clear],
                    center: UnitPoint(x: 0.92, y: 1.04),
                    startRadius: 0,
                    endRadius: radius
                )
            }
        }
        .opacity(0.9)
    }

    private var specular: some View {
        LinearGradient(
            colors: [
                RGBA(red: 1, green: 1, blue: 1, alpha: 0.30).color,
                RGBA(red: 1, green: 1, blue: 1, alpha: 0.05).color,
                .clear,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .rotationEffect(.degrees(-14))
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

/// The outer edge/shadow a `GlassSurface` adds for itself — everything
/// `.app` environments need and `.widget` environments already get for
/// free from the system's own Liquid Glass container (see
/// `GlassEnvironment`'s doc comment).
private struct OuterChrome: ViewModifier {
    let environment: GlassEnvironment
    let cornerRadius: Double

    func body(content: Content) -> some View {
        switch environment {
        case .widget:
            content
        case .app:
            content
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(edgeHighlight, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.42), radius: 22, x: 0, y: 22)
                .shadow(color: .black.opacity(0.24), radius: 5, x: 0, y: 2)
        }
    }

    private var edgeHighlight: LinearGradient {
        LinearGradient(
            colors: [
                RGBA(red: 1, green: 1, blue: 1, alpha: 0.62).color,
                RGBA(red: 1, green: 1, blue: 1, alpha: 0.16).color,
                RGBA(red: 1, green: 1, blue: 1, alpha: 0.22).color,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
