/// Design tokens, glass surfaces, and the shared components (figure, gauge,
/// chip, strip, message) the app and widget are both assembled from.
///
/// Deliberately has no dependency on SleepDebtCore — GlassKit knows how to
/// render a debt figure, not what sleep debt is.
///
/// Implementation lands in P4 and P5 (docs/IMPLEMENTATION_PLAN.md §5).
/// This file is a placeholder so the package has something to build and
/// test against from P0 onward.
public enum GlassKit {
    public static let packageName = "GlassKit"
}
