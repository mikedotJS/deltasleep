/// Resolves the ambiguity HealthKit itself won't: `HKAuthorizationStatus`
/// can't tell "read access denied" from "read access granted, nothing
/// written yet" — Apple withholds that distinction deliberately, for
/// privacy. This type collapses the three signals that *are* available
/// into one definitive state, instead of leaving each caller to
/// re-derive the same heuristic. See docs/IMPLEMENTATION_PLAN.md P2.
public enum HealthAuthorizationState: Equatable, Sendable {
    /// Never asked (or a newly-added read type needs a fresh prompt) —
    /// show the onboarding CTA.
    case needsPrompt
    /// Asked (or an existing grant survived a reinstall), and HealthKit
    /// has at least one sleep sample, ever. Proceed to history
    /// availability (`SleepDebtCore.HistoryAvailability`).
    case readableWithData
    /// Asked, and HealthKit has never seen a single sleep sample. The
    /// merged "no data" condition (`WidgetState.noData`) — whether
    /// that's an outright denial or a phone with nothing writing sleep
    /// data isn't knowable, and the UI doesn't claim to know either.
    case readableNoData

    /// A HealthKit-free mirror of `HKAuthorizationRequestStatus`, so this
    /// whole type stays testable without `import HealthKit`.
    public enum RequestStatus: Equatable, Sendable {
        case shouldPromptAgain
        case alreadyRequested
        case unknown
    }

    /// - Parameters:
    ///   - didRequestBefore: this app's *own* persisted record of having
    ///     triggered the system prompt for `sleepAnalysis` — not
    ///     HealthKit's memory of it, since that's exactly what can't
    ///     distinguish denial. Persisting and reading this flag is a
    ///     caller concern (P3/P8), not this package's.
    ///   - requestStatus: HealthKit's own record of whether it's already
    ///     been asked.
    ///   - hasAnySampleEver: whether an existence query found at least
    ///     one sleep sample across all time, regardless of date range.
    public static func resolve(
        didRequestBefore: Bool,
        requestStatus: RequestStatus,
        hasAnySampleEver: Bool
    ) -> HealthAuthorizationState {
        if !didRequestBefore, requestStatus != .alreadyRequested {
            return .needsPrompt
        }
        if !didRequestBefore, requestStatus == .alreadyRequested {
            // A reinstall over a prior grant: our own flag was lost with
            // the app's storage, but HealthKit's memory of the grant
            // wasn't. Fall through on sample data instead of re-prompting
            // for access that's already there.
            return hasAnySampleEver ? .readableWithData : .readableNoData
        }
        if requestStatus == .shouldPromptAgain {
            // A new read type was added since we last asked.
            return .needsPrompt
        }
        return hasAnySampleEver ? .readableWithData : .readableNoData
    }
}
