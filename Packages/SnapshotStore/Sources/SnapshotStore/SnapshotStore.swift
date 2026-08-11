/// App Group cache for the computed `DebtSnapshot`, plus the background
/// refresh orchestration (HealthKit observer → recompute → write snapshot →
/// reload widget timelines). The widget only ever reads from here — it
/// never touches HealthKit directly.
///
/// Implementation lands in P3 (docs/IMPLEMENTATION_PLAN.md §5).
/// This file is a placeholder so the package has something to build and
/// test against from P0 onward.
public enum SnapshotStore {
    public static let packageName = "SnapshotStore"
}
