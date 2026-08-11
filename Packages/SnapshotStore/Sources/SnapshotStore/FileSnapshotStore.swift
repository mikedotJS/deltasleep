import Foundation
import SleepDebtCore

/// A `SnapshotStoring` backed by two small JSON files in a directory the
/// caller supplies — deliberately not App-Group-aware itself. The app and
/// widget each resolve their own
/// `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`
/// and hand the result in, so this type (and its tests) never need a real
/// App Group entitlement to be exercised.
public final class FileSnapshotStore: SnapshotStoring, @unchecked Sendable {
    private let snapshotURL: URL
    private let historyAvailabilityURL: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        snapshotURL = directory.appendingPathComponent("debt-snapshot.json")
        historyAvailabilityURL = directory.appendingPathComponent("history-availability.json")
        self.fileManager = fileManager
    }

    public func readSnapshot() -> DebtSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return SnapshotCodec.decode(data)
    }

    public func writeSnapshot(_ snapshot: DebtSnapshot) throws {
        let data = try SnapshotCodec.encode(snapshot)
        try write(data, to: snapshotURL)
    }

    public func readHistoryAvailability() -> HistoryAvailability? {
        guard let data = try? Data(contentsOf: historyAvailabilityURL) else { return nil }
        return try? JSONDecoder().decode(HistoryAvailability.self, from: data)
    }

    public func writeHistoryAvailability(_ availability: HistoryAvailability) throws {
        let data = try JSONEncoder().encode(availability)
        try write(data, to: historyAvailabilityURL)
    }

    private func write(_ data: Data, to url: URL) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
