import SwiftUI

/// Renders `GrainTexture`'s fixed point set as small soft-light dots —
/// the closest practical SwiftUI stand-in for the mockup's
/// `mix-blend-mode: soft-light` noise overlay (see `GrainTexture`'s doc
/// comment; exact fractal-noise parity isn't achievable without a real
/// device pass, per S1's status note on issue #1).
struct GrainOverlay: View {
    private static let points = GrainTexture.points(count: 400, seed: 0x67_7261_696E)

    var body: some View {
        Canvas { context, size in
            for point in Self.points {
                let rect = CGRect(
                    x: point.x * size.width, y: point.y * size.height, width: 1.4, height: 1.4
                )
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(point.opacity)))
            }
        }
        .blendMode(.softLight)
        .opacity(0.34)
        .allowsHitTesting(false)
    }
}
