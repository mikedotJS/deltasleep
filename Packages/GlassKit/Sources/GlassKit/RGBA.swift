/// A plain RGBA colour value. GlassKit's tokens are expressed in this
/// type rather than SwiftUI's `Color` directly, so the actual numbers —
/// transcribed from docs/design/mockup-liquid-glass-v02.html's CSS custom
/// properties — are testable; `Color` conversion is a one-line extension
/// elsewhere (`RGBA+Color.swift`) that doesn't need its own test.
public struct RGBA: Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Matches how the mockup's CSS expresses most of its semantic
    /// colours: `rgba(255, 60, 90, .46)` — 0–255 channels, 0–1 alpha.
    public init(r255: Double, g255: Double, b255: Double, alpha: Double = 1) {
        red = r255 / 255
        green = g255 / 255
        blue = b255 / 255
        self.alpha = alpha
    }

    /// Parses a `#RRGGBB` or `#RRGGBBAA` hex string (with or without the
    /// leading `#`), matching the mockup's CSS hex literals. `nil` for
    /// anything else rather than crashing — token definitions are the
    /// only caller, so a malformed literal is a typo worth catching in a
    /// test, not at runtime.
    public init?(hex: String) {
        var value = hex
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6 || value.count == 8 else { return nil }
        guard let intValue = UInt32(value, radix: 16) else { return nil }
        if value.count == 6 {
            self.init(
                r255: Double((intValue >> 16) & 0xFF),
                g255: Double((intValue >> 8) & 0xFF),
                b255: Double(intValue & 0xFF)
            )
        } else {
            self.init(
                r255: Double((intValue >> 24) & 0xFF),
                g255: Double((intValue >> 16) & 0xFF),
                b255: Double((intValue >> 8) & 0xFF),
                alpha: Double(intValue & 0xFF) / 255
            )
        }
    }
}
