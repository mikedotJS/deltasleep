import Foundation
import HealthSleepSource
import SleepDebtCore
import XCTest
@testable import SnapshotStore

final class RefreshCoordinatorTests: XCTestCase {
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components)!
    }

    /// A sample ending at 07:00 on the calendar day `daysAgo` days before
    /// `referenceDate` — safely inside that day's noon-to-noon window.
    /// `hours` of sleep against an 8h need means every night in a
    /// same-`hours` fixture set has the same deficit, so the resulting
    /// debt is hand-verifiable (zero at `hours == 8`) regardless of the
    /// engine's exact weights — the fixture strategy P1 and P2 both used.
    private func sample(
        daysAgo: Int, hours: Double, referenceDate: Date, calendar: Calendar
    ) -> RawSleepSample {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
        let end = calendar.startOfDay(for: day).addingTimeInterval(7 * 3600)
        let start = end.addingTimeInterval(-hours * 3600)
        return RawSleepSample(
            stage: .asleepCore, startDate: start, endDate: end, sourceBundleID: "com.apple.health"
        )
    }

    private func fullHistorySamples(
        forDays count: Int, hours: Double, referenceDate: Date, calendar: Calendar
    ) -> [RawSleepSample] {
        (0 ..< count).map {
            sample(daysAgo: $0, hours: hours, referenceDate: referenceDate, calendar: calendar)
        }
    }

    private final class InMemorySnapshotStore: SnapshotStoring, @unchecked Sendable {
        private(set) var snapshot: DebtSnapshot?
        private(set) var writeCount = 0
        private(set) var historyAvailability: HistoryAvailability?

        func readSnapshot() -> DebtSnapshot? {
            snapshot
        }

        func writeSnapshot(_ snapshot: DebtSnapshot) throws {
            self.snapshot = snapshot
            writeCount += 1
        }

        func readHistoryAvailability() -> HistoryAvailability? {
            historyAvailability
        }

        func writeHistoryAvailability(_ availability: HistoryAvailability) throws {
            historyAvailability = availability
        }

        func clear() throws {
            snapshot = nil
            historyAvailability = nil
        }
    }

    /// Same as `InMemorySnapshotStore` but also records the order writes
    /// happen in, for the audit fix (#9) that requires the snapshot to
    /// land before availability flips to `.sufficient`.
    private final class OrderTrackingSnapshotStore: SnapshotStoring, @unchecked Sendable {
        private(set) var snapshot: DebtSnapshot?
        private(set) var historyAvailability: HistoryAvailability?
        private(set) var writeOrder: [String] = []

        func readSnapshot() -> DebtSnapshot? {
            snapshot
        }

        func writeSnapshot(_ snapshot: DebtSnapshot) throws {
            self.snapshot = snapshot
            writeOrder.append("snapshot")
        }

        func readHistoryAvailability() -> HistoryAvailability? {
            historyAvailability
        }

        func writeHistoryAvailability(_ availability: HistoryAvailability) throws {
            historyAvailability = availability
            writeOrder.append("availability")
        }

        func clear() throws {
            snapshot = nil
            historyAvailability = nil
            writeOrder.append("clear")
        }
    }

    private final class RecordingReloader: WidgetReloading, @unchecked Sendable {
        private(set) var reloadCount = 0

        func reloadAllTimelines() {
            reloadCount += 1
        }
    }

    func testFetchWindowReturnsTwentyOneConsecutiveDaysEndingOnReferenceDate() {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let window = RefreshCoordinator.fetchWindow(referenceDate: referenceDate, calendar: cal)
        XCTAssertEqual(window.count, 21)
        XCTAssertEqual(window.last, referenceDate)
        XCTAssertEqual(window.first, cal.date(byAdding: .day, value: -20, to: referenceDate))
    }

    func testRefreshWithSufficientHistoryComputesAndPersistsASnapshot() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let samples = fullHistorySamples(
            forDays: 21, hours: 8, referenceDate: referenceDate, calendar: cal
        )
        let store = InMemorySnapshotStore()
        let reloader = RecordingReloader()

        let outcome = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)),
            referenceDate: referenceDate,
            now: referenceDate,
            calendar: cal,
            source: FakeSleepSource(samples: samples),
            store: store,
            reloader: reloader
        )

        guard case let .refreshed(snapshot, reloadedWidgets) = outcome else {
            XCTFail("expected .refreshed, got \(outcome)")
            return
        }
        XCTAssertTrue(reloadedWidgets)
        XCTAssertEqual(snapshot.debt.seconds, 0, accuracy: 0.001)
        XCTAssertEqual(reloader.reloadCount, 1)
        XCTAssertEqual(store.writeCount, 1)
    }

    func testASecondRefreshWithUnchangedDataStillRewritesButDoesNotReloadWidgets() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let samples = fullHistorySamples(
            forDays: 21, hours: 8, referenceDate: referenceDate, calendar: cal
        )
        let source = FakeSleepSource(samples: samples)
        let store = InMemorySnapshotStore()
        let reloader = RecordingReloader()
        let need = SleepNeed(.hours(8))

        _ = try await RefreshCoordinator.refresh(
            need: need, referenceDate: referenceDate, now: referenceDate, calendar: cal,
            source: source, store: store, reloader: reloader
        )

        let laterNow = referenceDate.addingTimeInterval(3600)
        let secondOutcome = try await RefreshCoordinator.refresh(
            need: need, referenceDate: referenceDate, now: laterNow, calendar: cal,
            source: source, store: store, reloader: reloader
        )

        guard case let .refreshed(snapshot, reloadedWidgets) = secondOutcome else {
            XCTFail("expected .refreshed, got \(secondOutcome)")
            return
        }
        XCTAssertFalse(reloadedWidgets)
        XCTAssertEqual(reloader.reloadCount, 1, "still just the first refresh's reload")
        XCTAssertEqual(store.writeCount, 2, "computedAt must still advance on an unchanged refresh")
        XCTAssertEqual(snapshot.computedAt, laterNow)
    }

    func testRefreshWithFewerThanFourteenNightsReturnsInsufficientHistory() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let samples = fullHistorySamples(
            forDays: 5, hours: 8, referenceDate: referenceDate, calendar: cal
        )
        let store = InMemorySnapshotStore()

        let outcome = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)),
            referenceDate: referenceDate,
            now: referenceDate,
            calendar: cal,
            source: FakeSleepSource(samples: samples),
            store: store,
            reloader: RecordingReloader()
        )

        XCTAssertEqual(outcome, .insufficientHistory(measuredNights: 5, requiredNights: 14))
        XCTAssertEqual(
            store.readHistoryAvailability(), .insufficient(measuredNights: 5, requiredNights: 14)
        )
    }

    func testRefreshWithNoSamplesAtAllReturnsNoData() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let store = InMemorySnapshotStore()

        let outcome = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)),
            referenceDate: referenceDate,
            now: referenceDate,
            calendar: cal,
            source: FakeSleepSource(samples: []),
            store: store,
            reloader: RecordingReloader()
        )

        XCTAssertEqual(outcome, .noData)
        XCTAssertEqual(store.readHistoryAvailability(), HistoryAvailability.none)
    }

    func testRefreshWithSufficientHistoryWritesSufficientAvailability() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let samples = fullHistorySamples(
            forDays: 21, hours: 8, referenceDate: referenceDate, calendar: cal
        )
        let store = InMemorySnapshotStore()

        _ = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)),
            referenceDate: referenceDate,
            now: referenceDate,
            calendar: cal,
            source: FakeSleepSource(samples: samples),
            store: store,
            reloader: RecordingReloader()
        )

        XCTAssertEqual(store.readHistoryAvailability(), .sufficient)
    }

    /// Audit fix #1: a fetch that transiently returns zero measured nights
    /// must not wipe an already-established history back to `.none` — the
    /// prior snapshot and availability should survive untouched.
    func testEmptyFetchAfterEstablishedHistoryDoesNotWipeIt() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let samples = fullHistorySamples(
            forDays: 21, hours: 8, referenceDate: referenceDate, calendar: cal
        )
        let store = InMemorySnapshotStore()
        let reloader = RecordingReloader()

        _ = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)), referenceDate: referenceDate, now: referenceDate,
            calendar: cal, source: FakeSleepSource(samples: samples), store: store,
            reloader: reloader
        )
        XCTAssertEqual(store.readHistoryAvailability(), .sufficient)
        let establishedSnapshot = store.readSnapshot()
        XCTAssertNotNil(establishedSnapshot)

        // A later refresh's fetch comes back completely empty (transient
        // HealthKit hiccup, not a real "no data ever" situation).
        let outcome = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)),
            referenceDate: referenceDate.addingTimeInterval(3600),
            now: referenceDate.addingTimeInterval(3600),
            calendar: cal,
            source: FakeSleepSource(samples: []),
            store: store,
            reloader: reloader
        )

        XCTAssertEqual(outcome, .noData, "the caller still sees .noData for this refresh")
        XCTAssertEqual(
            store.readHistoryAvailability(), .sufficient,
            "but the previously-established history must survive, not be wiped to .none"
        )
        XCTAssertEqual(
            store.readSnapshot(), establishedSnapshot,
            "the prior snapshot must be untouched"
        )
    }

    /// Audit fix #1, fresh-install counterpart: with no prior history at
    /// all, an empty fetch must still correctly write `.none` — this is
    /// the one case where there's genuinely nothing to protect.
    func testEmptyFetchWithNoPriorHistoryStillWritesNone() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let store = InMemorySnapshotStore()

        let outcome = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)), referenceDate: referenceDate, now: referenceDate,
            calendar: cal, source: FakeSleepSource(samples: []), store: store,
            reloader: RecordingReloader()
        )

        XCTAssertEqual(outcome, .noData)
        XCTAssertEqual(store.readHistoryAvailability(), HistoryAvailability.none)
    }

    /// The reported symptom: the app showed "10 nuits sur 14" while the
    /// widget still said 9. Only the `.sufficient` branch used to reload
    /// timelines, so a changing insufficient-history count never reached
    /// WidgetKit until the widget's own 6h staleness policy fired.
    func testWidgetsReloadWhenTheInsufficientHistoryCountChanges() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let store = InMemorySnapshotStore()
        let reloader = RecordingReloader()
        let need = SleepNeed(.hours(8))

        _ = try await RefreshCoordinator.refresh(
            need: need, referenceDate: referenceDate, now: referenceDate, calendar: cal,
            source: FakeSleepSource(samples: fullHistorySamples(
                forDays: 9, hours: 8, referenceDate: referenceDate, calendar: cal
            )),
            store: store, reloader: reloader
        )
        XCTAssertEqual(reloader.reloadCount, 1, "first write of .insufficient(9) must reload")

        // A tenth night lands — the count on disk changes, so the widget
        // has to be told.
        let outcome = try await RefreshCoordinator.refresh(
            need: need, referenceDate: referenceDate, now: referenceDate, calendar: cal,
            source: FakeSleepSource(samples: fullHistorySamples(
                forDays: 10, hours: 8, referenceDate: referenceDate, calendar: cal
            )),
            store: store, reloader: reloader
        )

        XCTAssertEqual(outcome, .insufficientHistory(measuredNights: 10, requiredNights: 14))
        XCTAssertEqual(reloader.reloadCount, 2, "9 → 10 must reload the widget")
    }

    /// The other half of the same rule: WidgetKit's reload budget is finite
    /// and refreshes fire on every scene activation, so an unchanged count
    /// must NOT spend a reload.
    func testAnUnchangedInsufficientHistoryCountDoesNotReloadWidgets() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let samples = fullHistorySamples(
            forDays: 9, hours: 8, referenceDate: referenceDate, calendar: cal
        )
        let source = FakeSleepSource(samples: samples)
        let store = InMemorySnapshotStore()
        let reloader = RecordingReloader()
        let need = SleepNeed(.hours(8))

        _ = try await RefreshCoordinator.refresh(
            need: need, referenceDate: referenceDate, now: referenceDate, calendar: cal,
            source: source, store: store, reloader: reloader
        )
        _ = try await RefreshCoordinator.refresh(
            need: need, referenceDate: referenceDate, now: referenceDate, calendar: cal,
            source: source, store: store, reloader: reloader
        )

        XCTAssertEqual(reloader.reloadCount, 1, "still just the first write's reload")
    }

    /// Audit fix #9: the snapshot must be written before availability
    /// flips to `.sufficient`, so an interruption between the two writes
    /// never leaves `.sufficient` paired with a stale/missing snapshot.
    func testSnapshotIsWrittenBeforeAvailabilityFlipsToSufficient() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)
        let samples = fullHistorySamples(
            forDays: 21, hours: 8, referenceDate: referenceDate, calendar: cal
        )
        let store = OrderTrackingSnapshotStore()

        _ = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)), referenceDate: referenceDate, now: referenceDate,
            calendar: cal, source: FakeSleepSource(samples: samples), store: store,
            reloader: RecordingReloader()
        )

        XCTAssertEqual(store.writeOrder, ["snapshot", "availability"])
    }
}
