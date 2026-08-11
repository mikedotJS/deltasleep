import SleepDebtCore

/// Where the computed snapshot lives, and how it survives a round trip
/// through disk between now and the next app/widget launch.
///
/// `HistoryAvailability` is cached alongside the snapshot, not just the
/// snapshot itself, because the widget — a separate process that never
/// touches HealthKit (P2/P3) — otherwise has no way to tell "never had any
/// data," "not enough history yet," and "the cache is simply empty" apart:
/// `readSnapshot() == nil` looks identical in all three. Written on every
/// refresh, whether or not that refresh also produced a snapshot.
public protocol SnapshotStoring: Sendable {
    func readSnapshot() -> DebtSnapshot?
    func writeSnapshot(_ snapshot: DebtSnapshot) throws
    func readHistoryAvailability() -> HistoryAvailability?
    func writeHistoryAvailability(_ availability: HistoryAvailability) throws
}
