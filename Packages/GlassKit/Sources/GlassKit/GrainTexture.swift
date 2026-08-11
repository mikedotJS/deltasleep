/// A fixed set of grain-texture points, standing in for the mockup's SVG
/// `feTurbulence` noise (`.grain`/`.bg-grain` in
/// docs/design/mockup-liquid-glass-v02.html) — SwiftUI has no direct
/// equivalent, so `GrainOverlay` draws this point set instead of
/// reproducing the exact fractal-noise algorithm. Computed once from a
/// seeded generator, not regenerated per frame, so the texture is stable
/// across redraws rather than flickering.
public enum GrainTexture {
    public struct Point: Hashable, Sendable {
        public let x: Double
        public let y: Double
        public let opacity: Double
    }

    /// `x`/`y` are unit coordinates (0...1, fractional position within
    /// whatever frame the caller draws into); `opacity` is bounded to a
    /// range subtle enough to read as grain rather than static.
    public static func points(count: Int, seed: UInt64) -> [Point] {
        var generator = SeededGenerator(seed: seed)
        return (0 ..< count).map { _ in
            Point(
                x: Double.random(in: 0 ... 1, using: &generator),
                y: Double.random(in: 0 ... 1, using: &generator),
                opacity: Double.random(in: 0.05 ... 0.35, using: &generator)
            )
        }
    }
}
