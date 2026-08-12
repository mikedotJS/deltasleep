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
        /// Audit NOTE: an exactly-zero delta used to render with `.up`'s
        /// glyph at every call site (`delta.seconds >= 0 ? .up : .down`)
        /// — a "rising" arrow for a value that didn't move. `.flat` gives
        /// callers a real third option instead of defaulting to `.up`.
        case flat

        var glyph: String {
            switch self {
            case .up: "▲"
            case .down: "▼"
            case .flat: "–"
            }
        }

        var accessibilityDescription: String {
            switch self {
            case .up: "en hausse"
            case .down: "en baisse"
            case .flat: "stable"
            }
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
        // Audit NOTE: a sensible default for a caller that uses this chip
        // outside its usual parent-supplied `.combine` wrapper — without
        // this, VoiceOver reads the bare glyph literally ("triangle plein
        // pointe en haut"). A parent that already sets its own
        // `.accessibilityLabel` after combining children overrides this,
        // so it's additive, never conflicting.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(direction.accessibilityDescription), \(text)")
    }
}
