/// The four semantic tints the mockup's glass cards use (`.g-red`,
/// `.g-green`, `.g-amber`, `.g-neut` in
/// docs/design/mockup-liquid-glass-v02.html). Colour encodes the debt
/// *derivative*, never its magnitude — see
/// docs/IMPLEMENTATION_PLAN.md §1.2 and P1's `Trend`.
public enum GlassTint: CaseIterable, Hashable, Sendable {
    case green
    case red
    case amber
    case neutral
}
