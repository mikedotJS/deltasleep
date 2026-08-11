/// What colour the widget shows. Deliberately encodes the *derivative*,
/// never the debt level itself — see docs/IMPLEMENTATION_PLAN.md §1.1.
///
/// Computed by comparing last night's sleep against the recency-weighted
/// average of the rest of the window (`SleepDebtEngine`'s
/// `breakEvenTarget`), not by subtracting yesterday's debt from today's.
/// The latter is tempting but wrong: a raw window-difference can flip
/// colour on a bad night purely because a *worse* night 14 days ago
/// rolled out of the window — an artifact the design can't afford, since
/// colour is the entire signal.
public enum Trend: Hashable, Codable, Sendable {
    /// Last night beat the weighted average of the rest of the window —
    /// green.
    case falling
    /// Last night fell short of the weighted average — red.
    case rising
    /// Last night matched the weighted average within a small epsilon.
    /// Not one of the mockup's named states; treated as `.falling` by
    /// callers that need a binary choice (matching sleep need exactly is
    /// not a regression).
    case flat
    /// No comparison was possible: last night is a gap (state 7, amber —
    /// handled as its own `WidgetState` case, not via `Trend`), or the
    /// sleep need changed today and the trend is deliberately frozen
    /// rather than let a settings change paint the widget green.
    case unknown
}
