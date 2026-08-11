import Foundation

/// One calendar night's sleep data, or the absence of it.
///
/// Deliberately an enum-backed `Kind` rather than the literal
/// `(date, time asleep, source, isGap)` tuple sketched in
/// docs/IMPLEMENTATION_PLAN.md §3 — a bare `isGap: Bool` alongside an
/// `asleep: SleepDuration` can disagree with itself (gap=true but a
/// duration is still set); making "measured" and "gap" mutually exclusive
/// at the type level removes that possibility entirely instead of relying
/// on every call site to keep them in sync.
public struct Night: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case measured(asleep: SleepDuration)
        case gap
    }

    /// The sleep-day this night is attributed to (D3: noon → noon,
    /// resolved by P2's ingestion — this package only ever consumes
    /// already-attributed dates, never raw HealthKit samples).
    public let date: Date
    public let kind: Kind
    /// e.g. a HealthKit source bundle identifier. `nil` for gaps and for
    /// synthetic/fixture nights.
    public let source: String?

    public init(date: Date, kind: Kind, source: String? = nil) {
        self.date = date
        self.kind = kind
        self.source = source
    }

    public static func measured(date: Date, asleep: SleepDuration, source: String? = nil) -> Night {
        Night(date: date, kind: .measured(asleep: asleep), source: source)
    }

    public static func gap(date: Date) -> Night {
        Night(date: date, kind: .gap, source: nil)
    }

    public var isGap: Bool {
        if case .gap = kind { return true }
        return false
    }

    public var asleep: SleepDuration? {
        if case .measured(let duration) = kind { return duration }
        return nil
    }
}
