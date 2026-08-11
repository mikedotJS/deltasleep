import SleepDebtCore

/// Where the computed snapshot lives, and how it survives a round trip
/// through disk between now and the next app/widget launch.
public protocol SnapshotStoring: Sendable {
    func readSnapshot() -> DebtSnapshot?
    func writeSnapshot(_ snapshot: DebtSnapshot) throws
}
