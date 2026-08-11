import Foundation
import SwiftUI

/// The mockup's `.fig`/`.p-fig`: the big gradient-clipped debt numerals —
/// "13" + a small "h" unit + "04" — at either the widget or phone-card
/// size. Takes plain hours/minutes rather than a `SleepDuration`; GlassKit
/// doesn't depend on SleepDebtCore (P4's scope constraint), so callers
/// (P6/P7) do that conversion themselves.
public struct DebtFigure: View {
    public enum Size: Sendable {
        case widget
        case phone

        var figureSize: CGFloat {
            switch self {
            case .widget: 47
            case .phone: 64
            }
        }

        var unitSize: CGFloat {
            switch self {
            case .widget: 20
            case .phone: 26
            }
        }
    }

    private let hours: Int
    private let minutes: Int
    private let tint: GlassTint
    private let size: Size

    public init(hours: Int, minutes: Int, tint: GlassTint, size: Size) {
        self.hours = hours
        self.minutes = minutes
        self.tint = tint
        self.size = size
    }

    public var body: some View {
        let palette = GlassTokens.palette(for: tint)
        let hoursText = Text("\(hours)")
            .font(numeralFont(pointSize: size.figureSize))
        let unitText = Text("h")
            .font(.system(size: size.unitSize, weight: .medium, design: .rounded))
        let minutesText = Text(Self.formattedMinutes(minutes))
            .font(numeralFont(pointSize: size.figureSize))
        (hoursText + unitText + minutesText)
            .foregroundStyle(figureGradient(figureEnd: palette.figureGradientEnd.color))
            .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 2)
    }

    private func numeralFont(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .bold, design: .rounded)
    }

    private func figureGradient(figureEnd: Color) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.42),
                .init(color: figureEnd, location: 1),
            ]),
            startPoint: UnitPoint(x: 0.2, y: 0),
            endPoint: UnitPoint(x: 0.8, y: 1)
        )
    }
}

extension DebtFigure {
    /// Zero-padded minutes matching the mockup's "13h04" style (never
    /// "13h4") — pulled out of the view body so it's testable on its own.
    static func formattedMinutes(_ minutes: Int) -> String {
        String(format: "%02d", minutes)
    }
}
