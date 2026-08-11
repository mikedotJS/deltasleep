import Foundation
import SleepDebtCore

/// A versioned envelope around `DebtSnapshot` — the schema version lets a
/// future build recognise (or safely discard) a snapshot written by an
/// older one, per P3's "must not crash a new widget" requirement
/// (docs/IMPLEMENTATION_PLAN.md §5, P3).
struct PersistedSnapshot: Codable {
    let schemaVersion: Int
    let snapshot: DebtSnapshot
}

/// Encoding/decoding plus the schema-migration seam. There's only ever
/// been one schema so far, so `decode` either matches it or gives up — but
/// the version field and the switch below exist now so a real migration
/// is a case added here later, not a redesign.
public enum SnapshotCodec {
    static let currentSchemaVersion = 1

    public static func encode(_ snapshot: DebtSnapshot) throws -> Data {
        let persisted = PersistedSnapshot(schemaVersion: currentSchemaVersion, snapshot: snapshot)
        return try JSONEncoder().encode(persisted)
    }

    /// `nil` rather than `throws` — a corrupt file or an unrecognised
    /// future schema version should read the same as "no snapshot yet,"
    /// not crash the widget. Callers fall back to whatever `WidgetState`
    /// derives from a `nil` snapshot.
    public static func decode(_ data: Data) -> DebtSnapshot? {
        guard let persisted = try? JSONDecoder().decode(PersistedSnapshot.self, from: data) else {
            return nil
        }
        switch persisted.schemaVersion {
        case currentSchemaVersion:
            return persisted.snapshot
        default:
            return nil
        }
    }
}
