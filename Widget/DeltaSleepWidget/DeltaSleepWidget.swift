import Foundation
import SleepDebtCore
import SnapshotStore
import SwiftUI
import WidgetKit

/// Placeholder rendering — the real seven-state UI (§5, P6) replaces
/// `DeltaSleepWidgetEntryView` once P4 (GlassKit) and P5 (shared
/// components) land. This provider does read the real cached snapshot
/// from the App Group container via SnapshotStore (P3) already, so the
/// app → cache → widget round trip is genuinely exercised end to end,
/// not stubbed.
struct Provider: TimelineProvider {
    private let store: SnapshotStoring = FileSnapshotStore(
        directory: AppGroup.containerURL() ?? FileManager.default.temporaryDirectory
    )

    func placeholder(in _: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), snapshot: store.readSnapshot()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), snapshot: store.readSnapshot())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let snapshot: DebtSnapshot?
}

struct DeltaSleepWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        if let snapshot = entry.snapshot {
            let (hours, minutes) = snapshot.debt.wholeHoursAndMinutes
            Text("\(hours)h\(String(format: "%02d", minutes))")
        } else {
            Text("deltasleep")
        }
    }
}

struct DeltaSleepWidget: Widget {
    let kind: String = "DeltaSleepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DeltaSleepWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("deltasleep")
        .description("Dette de sommeil")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
