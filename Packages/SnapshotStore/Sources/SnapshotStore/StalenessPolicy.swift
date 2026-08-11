import Foundation

/// D6's threshold, fed to `WidgetState.classify(staleAfter:)` by callers
/// (P6/P7). A provisional value, not a measured one — S2 (issue #2)
/// couldn't gather real background-delivery telemetry in this environment
/// (no device), so this is the plan's own documented-rationale default
/// rather than a derived number. Centralized here, as a plain constant
/// rather than baked into `SleepDebtCore`, specifically so it's a one-line
/// change once real usage data exists.
public enum StalenessPolicy {
    public static let staleAfter: TimeInterval = 6 * 3600
}
