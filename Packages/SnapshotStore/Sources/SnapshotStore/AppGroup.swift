import Foundation

/// The single App Group the app and the widget extension share — defined
/// once here (rather than duplicated as a string literal in each target)
/// so the two can never drift apart on which container they read and
/// write. Must match both targets' entitlements
/// (`App/DeltaSleep/DeltaSleep.entitlements`,
/// `Widget/DeltaSleepWidget/DeltaSleepWidget.entitlements`) and
/// `project.yml`'s App Group setting.
public enum AppGroup {
    public static let identifier = "group.com.mikedotjs.deltasleep"

    /// `nil` if the entitlement isn't present for the running process —
    /// true of a plain `swift test` host, which has no entitlements at
    /// all. Callers treat that the same as "no cache yet" rather than
    /// crash, since the placeholder bundle IDs in `project.yml` mean this
    /// can also be true of an unprovisioned debug build.
    public static func containerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
