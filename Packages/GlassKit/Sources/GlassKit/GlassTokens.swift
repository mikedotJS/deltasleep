/// Design tokens transcribed by hand from
/// docs/design/mockup-liquid-glass-v02.html's CSS custom properties. Keep
/// the two in sync manually — there's no shared source of truth between
/// CSS and Swift, and no tooling here that would catch drift.
public enum GlassTokens {
    // MARK: - Corner radii (`--r` and `.phone`)

    public static let cornerRadiusWidget: Double = 34
    public static let cornerRadiusPhone: Double = 44

    // MARK: - Base surface gradient (`.w`'s `background`, same for every tint)

    public static let surfaceGradientStart = RGBA(red: 1, green: 1, blue: 1, alpha: 0.26)
    public static let surfaceGradientMid = RGBA(red: 1, green: 1, blue: 1, alpha: 0.07)
    public static let surfaceGradientEnd = RGBA(red: 1, green: 1, blue: 1, alpha: 0.13)

    // MARK: - Page backdrop (`body { background:#0B0A18 }`)

    /// The near-black the three `surfaceGradient*` stops above were sampled
    /// against — and the one mockup literal this file never transcribed,
    /// which is exactly how the widget shipped as a white square.
    ///
    /// Not decoration. Every layer `GlassSurface` draws is white-alpha, its
    /// specular blends `.plusLighter`, its grain `.softLight`, and the whole
    /// text ladder below is white: all of it only resolves to anything
    /// visible because something opaque and dark is painted underneath.
    /// Whoever hosts a `GlassSurface` owes it that backdrop — the app gets
    /// one from `RootView`'s `.preferredColorScheme(.dark)`, but a widget
    /// has no colour scheme of its own, only a wallpaper of arbitrary
    /// luminance, so it has to paint this itself.
    public static let backdrop = RGBA(r255: 11, g255: 10, b255: 24)

    // MARK: - Text opacity ladder (`--txt`, `--txt-dim`, `--txt-faint`)

    public static let textPrimary = RGBA(red: 1, green: 1, blue: 1, alpha: 1)
    public static let textDim = RGBA(red: 1, green: 1, blue: 1, alpha: 0.62)
    public static let textFaint = RGBA(red: 1, green: 1, blue: 1, alpha: 0.4)

    // MARK: - Spacing (padding values `.w`, `.phone` use)

    public static let widgetPadding: Double = 18
    public static let phonePaddingHorizontal: Double = 22
    public static let phonePaddingVertical: Double = 26

    /// Audit NOTE: a shared progression for the many one-off spacing
    /// literals scattered across `MainScreenView`/`WidgetContent` — not
    /// every literal in the app is migrated onto this (that'd be its own
    /// large, risky diff across working layout code), but new call sites
    /// should prefer these over another bespoke number.
    public enum Spacing {
        public static let xs: Double = 4
        public static let sm: Double = 8
        public static let md: Double = 12
        public static let lg: Double = 20
        public static let xl: Double = 24
    }

    // MARK: - Per-tint palettes

    public static func palette(for tint: GlassTint) -> TintPalette {
        switch tint {
        case .green:
            TintPalette(
                bloom1: RGBA(r255: 60, g255: 255, b255: 170, alpha: 0.42),
                bloom2: RGBA(r255: 20, g255: 190, b255: 255, alpha: 0.26),
                figureGradientEnd: RGBA(r255: 182, g255: 255, b255: 221),
                fillStart: RGBA(r255: 140, g255: 247, b255: 192),
                fillEnd: RGBA(r255: 15, g255: 191, b255: 122),
                fillGlow: RGBA(r255: 15, g255: 191, b255: 122, alpha: 0.55)
            )
        case .red:
            TintPalette(
                bloom1: RGBA(r255: 255, g255: 60, b255: 90, alpha: 0.46),
                bloom2: RGBA(r255: 255, g255: 140, b255: 60, alpha: 0.34),
                figureGradientEnd: RGBA(r255: 255, g255: 201, b255: 176),
                fillStart: RGBA(r255: 255, g255: 154, b255: 107),
                fillEnd: RGBA(r255: 240, g255: 38, b255: 79),
                fillGlow: RGBA(r255: 240, g255: 38, b255: 79, alpha: 0.6)
            )
        case .amber:
            TintPalette(
                bloom1: RGBA(r255: 255, g255: 190, b255: 70, alpha: 0.42),
                bloom2: RGBA(r255: 255, g255: 110, b255: 60, alpha: 0.26),
                figureGradientEnd: RGBA(r255: 255, g255: 230, b255: 168),
                fillStart: RGBA(r255: 255, g255: 224, b255: 138),
                fillEnd: RGBA(r255: 255, g255: 159, b255: 28),
                fillGlow: RGBA(r255: 255, g255: 159, b255: 28, alpha: 0.55)
            )
        case .neutral:
            TintPalette(
                bloom1: RGBA(r255: 255, g255: 255, b255: 255, alpha: 0.16),
                bloom2: RGBA(r255: 180, g255: 200, b255: 255, alpha: 0.14),
                figureGradientEnd: RGBA(r255: 255, g255: 255, b255: 255, alpha: 0.72),
                fillStart: RGBA(r255: 255, g255: 255, b255: 255, alpha: 0.6),
                fillEnd: RGBA(r255: 255, g255: 255, b255: 255, alpha: 0.34),
                fillGlow: RGBA(r255: 0, g255: 0, b255: 0, alpha: 0)
            )
        }
    }
}
