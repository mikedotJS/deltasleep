import GlassKit
import SleepDebtCore

/// The one place `WidgetState` (SleepDebtCore) turns into `GlassTint`
/// (GlassKit) — colour comes from the debt *derivative*, never its
/// magnitude (docs/IMPLEMENTATION_PLAN.md §1.2): 13h of debt can still be
/// green if it's falling. GlassKit doesn't know about `WidgetState` at
/// all (P4's no-SleepDebtCore constraint), so this mapping has to live
/// here, in the target that imports both.
enum WidgetTint {
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
