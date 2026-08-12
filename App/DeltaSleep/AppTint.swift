import GlassKit
import SleepDebtCore

/// The app-target twin of the widget's `WidgetTint` — GlassKit can't
/// depend on SleepDebtCore (P4's constraint) and targets don't share
/// source beyond the packages, so this small mapping is intentionally
/// duplicated rather than shared. Colour comes from the debt
/// *derivative*, never its magnitude (docs/IMPLEMENTATION_PLAN.md §1.2).
enum AppTint {
    static func tint(for state: WidgetState) -> GlassTint {
        switch state {
        case let .nominal(_, trend):
            tint(for: trend)
        case .zero:
            .green
        case .nightMissing:
            .amber
        case .cached, .noData, .insufficientHistory:
            .neutral
        }
    }

    /// `.unknown` — either last night was incomparable, or (per `Trend`'s
    /// own doc comment) the sleep need changed today and the trend is
    /// deliberately frozen — must NOT fall through to `.green`: that
    /// would silently paint a settings change (or an incomparable night)
    /// as "debt fell," exactly what the freeze rule exists to prevent.
    private static func tint(for trend: Trend) -> GlassTint {
        switch trend {
        case .falling, .flat:
            .green
        case .rising:
            .red
        case .unknown:
            .neutral
        }
    }
}
