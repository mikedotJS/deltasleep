import WidgetKit
import SwiftUI

/// Placeholder timeline provider. The real provider (§5, P6) reads
/// `DebtSnapshot` from the App Group container via SnapshotStore once
/// P3 lands — this one just proves the extension builds and appears in
/// the widget gallery.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: Date())], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct DeltaSleepWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        Text("deltasleep")
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
