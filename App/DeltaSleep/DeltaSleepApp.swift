import Foundation
import SnapshotStore
import SwiftUI

@main
struct DeltaSleepApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let orchestrator: RefreshOrchestrator
    private let store: SnapshotStoring
    private let needStore: SleepNeedStore

    init() {
        // Falls back to a temp directory when the App Group entitlement
        // isn't resolvable (an unprovisioned debug build — project.yml's
        // bundle IDs are still placeholders) rather than crashing; the app
        // just behaves as if no snapshot has ever been cached.
        let directory = AppGroup.containerURL() ?? FileManager.default.temporaryDirectory
        let resolvedStore = FileSnapshotStore(directory: directory)
        let resolvedNeedStore = SleepNeedStore()
        store = resolvedStore
        needStore = resolvedNeedStore
        orchestrator = RefreshOrchestrator(store: resolvedStore, needStore: resolvedNeedStore)
    }

    var body: some Scene {
        WindowGroup {
            MainScreenView(
                viewModel: MainScreenViewModel(
                    store: store, needStore: needStore, orchestrator: orchestrator
                )
            )
            .task { await orchestrator.start() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await orchestrator.refreshNow() }
            }
        }
    }
}
