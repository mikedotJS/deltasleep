import Foundation
import SleepDebtCore

/// A `SnapshotStoring` backed by a single JSON file in a directory the
/// caller supplies — deliberately not App-Group-aware itself. The app and
/// widget each resolve their own
/// `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`
/// and hand the result in, so this type (and its tests) never need a real
/// App Group entitlement to be exercised.
public final class FileSnapshotStore: SnapshotStoring, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        fileURL = directory.appendingPathComponent("debt-snapshot.json")
        self.fileManager = fileManager
    }

    public func readSnapshot() -> DebtSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return SnapshotCodec.decode(data)
    }

    public func writeSnapshot(_ snapshot: DebtSnapshot) throws {
        let data = try SnapshotCodec.encode(snapshot)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
