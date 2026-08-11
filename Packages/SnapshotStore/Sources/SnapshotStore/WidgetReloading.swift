/// Abstracts `WidgetCenter.shared.reloadAllTimelines()` so
/// `RefreshCoordinator` can be tested without WidgetKit or a real widget
/// extension involved.
public protocol WidgetReloading: Sendable {
    func reloadAllTimelines()
}

/// A `WidgetReloading` that does nothing — for tests, previews, and any
/// call site that hasn't opted into live widget reloads.
public struct NoopWidgetReloader: WidgetReloading {
    public init() {}

    public func reloadAllTimelines() {}
}
