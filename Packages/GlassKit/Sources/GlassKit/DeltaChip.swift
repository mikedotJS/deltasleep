import SwiftUI

/// The mockup's `.chip`: an arrow glyph plus a duration in a translucent
/// pill. Direction is carried by the arrow's shape, not colour — the same
/// chip renders identically regardless of tint, which is what keeps
/// direction legible with colour removed (accessibility note in
/// docs/IMPLEMENTATION_PLAN.md's P9 scope).
public struct DeltaChip: View {
    public enum Direction: Sendable {
        case up
        case down

        var glyph: String {
            self == .up ? "▲" : "▼"
        }
    }

    private let direction: Direction
    private let text: String

    public init(direction: Direction, text: String) {
        self.direction = direction
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(direction.glyph)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.leading, 5)
        .padding(.trailing, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.white.opacity(0.18)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5))
    }
}
