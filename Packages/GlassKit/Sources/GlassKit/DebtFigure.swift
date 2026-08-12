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

    /// Dynamic Type (P9): scales with the environment's type size, so the
    /// phone screen's figure grows through the accessibility sizes; a
    /// widget's own Dynamic Type range is clamped by its host view (see
    /// `WidgetContent`'s doc comment), which keeps this from overflowing
    /// the widget's fixed frame without this view needing to know it's
    /// inside one. `size` itself (widget vs. phone) is only needed here,
    /// to seed the starting point each scales from — the rendered body
    /// reads these, not the enum.
    @ScaledMetric private var figureSize: CGFloat
    @ScaledMetric private var unitSize: CGFloat

    public init(hours: Int, minutes: Int, tint: GlassTint, size: Size) {
        self.hours = hours
        self.minutes = minutes
        self.tint = tint
        _figureSize = ScaledMetric(wrappedValue: size.figureSize)
        _unitSize = ScaledMetric(wrappedValue: size.unitSize)
    }

    public var body: some View {
        let palette = GlassTokens.palette(for: tint)
        let hoursText = Text("\(hours)")
            .font(numeralFont(pointSize: figureSize))
        let unitText = Text("h")
            .font(.system(size: unitSize, weight: .medium, design: .rounded))
        let minutesText = Text(Self.formattedMinutes(minutes))
            .font(numeralFont(pointSize: figureSize))
        (hoursText + unitText + minutesText)
            .foregroundStyle(figureGradient(figureEnd: palette.figureGradientEnd.color))
            .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 2)
            // Audit finding #15: debt is never capped (only the gauge
            // saturates, at 24h) and can mathematically reach 3 digits of
            // hours. Without this, a long-enough debt combined with a
            // large Dynamic Type size had no fallback — clipped by
            // GlassSurface on the phone screen, or overflowing the
            // widget's fixed-width column.
            .lineLimit(1)
            .minimumScaleFactor(0.5)
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
    /// `nonisolated` because `View` conformance implicitly MainActor-isolates
    /// the whole type under newer Swift concurrency checking, but this is
    /// pure formatting with no UI state — DebtFigureTests calls it from a
    /// synchronous, non-isolated XCTest context (pre-existing failure,
    /// unrelated to the audit fixes in this commit; fixed incidentally
    /// because it blocked verifying them).
    nonisolated static func formattedMinutes(_ minutes: Int) -> String {
        String(format: "%02d", minutes)
    }
}
