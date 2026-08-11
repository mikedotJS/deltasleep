import Foundation
import SleepDebtCore
import SnapshotStore
import SwiftUI
import WidgetKit

/// Reads the App Group snapshot (P3) and classifies it into a
/// `WidgetState` (P1) — the widget's own rendering (`WidgetContent.swift`,
/// P6) never touches the raw `DebtSnapshot`/`HistoryAvailability` split
/// itself, so every surface derives its state the same way.
struct Provider: TimelineProvider {
    private let store: SnapshotStoring = FileSnapshotStore(
        directory: AppGroup.containerURL() ?? FileManager.default.temporaryDirectory
    )

    func placeholder(in _: Context) -> SnapshotEntry {
        SnapshotEntry(
            date: Date(), state: .nominal(debt: .hm(10, 26), trend: .falling), snapshot: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(makeEntry(now: Date()))
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(now: now)
        // Refresh policy (P6 scope): re-check after D6's staleness
        // window rather than never — this is what actually moves the
        // widget into the "cached" state on its own if nothing else
        // triggers a reload first (docs/IMPLEMENTATION_PLAN.md §5, P6).
        let nextRefresh = now.addingTimeInterval(StalenessPolicy.staleAfter)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry(now: Date) -> SnapshotEntry {
        let snapshot = store.readSnapshot()
        // A nil cached availability (nothing has ever run a refresh
        // yet — a genuinely fresh install) reads the same as `.none`:
        // there's no data, for the same reason there'd be no data after
        // a real refresh found nothing.
        let availability = store.readHistoryAvailability() ?? .none
        let state = WidgetState.classify(
            history: availability,
            snapshot: snapshot,
            staleAfter: StalenessPolicy.staleAfter,
            now: now
        )
        return SnapshotEntry(date: now, state: state, snapshot: snapshot)
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
    let snapshot: DebtSnapshot?
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
