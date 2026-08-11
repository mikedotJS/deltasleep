import SwiftUI

/// The mockup's `.strip`: 14 bars diverging from a centre axis, plus a
/// last-night dot. A *raw* encoding, unrelated to the weighted debt
/// engine — see `SleepDebtCore.NightStripMapping`'s doc comment, which
/// this view's `Bar` type mirrors exactly (re-declared here rather than
/// imported, since GlassKit doesn't depend on SleepDebtCore).
public struct NightStrip: View {
    public struct Bar: Equatable, Sendable {
        public let isGap: Bool
        /// `true` = above the axis (slept more than need). Meaningless
        /// when `isGap` is true.
        public let isAboveAxis: Bool
        /// 0...1 of the strip's half-height.
        public let fraction: Double

        public init(isGap: Bool, isAboveAxis: Bool, fraction: Double) {
            self.isGap = isGap
            self.isAboveAxis = isAboveAxis
            self.fraction = fraction
        }
    }

    private let bars: [Bar]
    private let height: CGFloat

    public init(bars: [Bar], height: CGFloat = 88) {
        self.bars = bars
        self.height = height
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.24))
                .frame(height: 1)
            HStack(spacing: 4) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                    NightBarView(bar: bar, halfHeight: height / 2, isLast: index == bars.count - 1)
                }
            }
        }
        .frame(height: height)
    }
}

extension NightStrip.Bar {
    /// The bar's rendered length in points given the strip's half-height
    /// — pulled out of the view so the floor-at-3pt behaviour (never
    /// fully invisible, matching `NightStripMapping`'s own
    /// minimum-visible-fraction upstream) is independently testable.
    func barLength(halfHeight: Double) -> Double {
        max(3, halfHeight * fraction)
    }
}

private struct NightBarView: View {
    let bar: NightStrip.Bar
    let halfHeight: CGFloat
    let isLast: Bool

    var body: some View {
        VStack(spacing: 1) {
            topHalf
                .frame(height: halfHeight, alignment: .bottom)
            bottomHalf
                .frame(height: halfHeight, alignment: .top)
        }
        .overlay(alignment: .bottom) {
            if isLast {
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .shadow(color: .white.opacity(0.9), radius: 4)
                    .offset(y: halfHeight + 9)
            }
        }
    }

    @ViewBuilder
    private var topHalf: some View {
        if bar.isAboveAxis, !bar.isGap {
            coloredBar
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var bottomHalf: some View {
        if bar.isGap {
            gapBar
        } else if !bar.isAboveAxis {
            coloredBar
        } else {
            Color.clear
        }
    }

    private var gapBar: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white.opacity(0.3))
            .frame(height: 2)
    }

    private var coloredBar: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(barGradient)
            .frame(height: bar.barLength(halfHeight: halfHeight))
            .brightness(isLast ? 0.1 : 0)
            .saturation(isLast ? 1.2 : 1)
    }

    private var barGradient: LinearGradient {
        let colors = bar.isAboveAxis
            ? [
                RGBA(r255: 140, g255: 247, b255: 192).color,
                RGBA(r255: 15, g255: 191, b255: 122).color,
            ]
            : [
                RGBA(r255: 240, g255: 38, b255: 79).color,
                RGBA(r255: 255, g255: 154, b255: 107).color,
            ]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}
