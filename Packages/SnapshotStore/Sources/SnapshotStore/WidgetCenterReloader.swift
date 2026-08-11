// Guarded the same way P2's HealthKitSleepSource.swift guards on
// canImport(HealthKit): WidgetKit isn't available on every build host this
// package might compile for (watchOS in particular). Per P2's finding,
// canImport(Framework) tends to evaluate true for Apple frameworks on this
// CI's macOS runner too — WidgetKit has shipped on macOS since Big Sur's
// Notification Center widgets — so this file is expected to be genuinely
// compiled and type-checked by `swift test`, not skipped.
#if canImport(WidgetKit)
import WidgetKit

/// The real `WidgetReloading` — thin enough that there's nothing here
/// worth unit testing directly; `RefreshCoordinator`'s tests exercise the
/// protocol via a fake instead.
public struct WidgetCenterReloader: WidgetReloading {
    public init() {}

    public func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
#endif
