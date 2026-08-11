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
            trend == .rising ? .red : .green
        case .zero:
            .green
        case .nightMissing:
            .amber
        case .cached, .noData, .insufficientHistory:
            .neutral
        }
    }
}
