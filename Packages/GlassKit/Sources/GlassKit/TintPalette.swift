/// The per-tint colours a `GlassSurface` and its contents need — the
/// `.g-red`/`.g-green`/`.g-amber`/`.g-neut` CSS custom-property groups in
/// docs/design/mockup-liquid-glass-v02.html, collected into one value.
public struct TintPalette: Hashable, Sendable {
    /// The two-stop semantic bloom behind the glass (`.w::before`'s
    /// `--tint-1`/`--tint-2`).
    public let bloom1: RGBA
    public let bloom2: RGBA

    /// The debt figure's gradient second stop (`--fig-2`). The mockup
    /// never gives `.g-neut` its own numerals — those states show a
    /// message or an insufficient-history figure instead — so this falls
    /// back to a dim white rather than a colour that's never actually
    /// used against neutral.
    public let figureGradientEnd: RGBA

    /// The liquid gauge's fill gradient and glow (`.fill`'s `--f1`/
    /// `--f2`/`--f-glow`).
    public let fillStart: RGBA
    public let fillEnd: RGBA
    public let fillGlow: RGBA
}
