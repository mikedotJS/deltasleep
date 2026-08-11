/// HealthKit ingestion: raw `HKCategorySample` sleep data in, `[Night]` out,
/// behind a `SleepDataSource` protocol so the engine and the app can be
/// tested against a fake source with no device/simulator involved.
///
/// Implementation lands in P2 (docs/IMPLEMENTATION_PLAN.md §5).
/// This file is a placeholder so the package has something to build and
/// test against from P0 onward.
public enum HealthSleepSource {
    public static let packageName = "HealthSleepSource"
}
