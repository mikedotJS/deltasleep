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

        func readSnapshot() -> DebtSnapshot? { snapshot }

        func writeSnapshot(_ snapshot: DebtSnapshot) throws {
            self.snapshot = snapshot
            writeCount += 1
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

        let outcome = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)),
            referenceDate: referenceDate,
            now: referenceDate,
            calendar: cal,
            source: FakeSleepSource(samples: samples),
            store: InMemorySnapshotStore(),
            reloader: RecordingReloader()
        )

        XCTAssertEqual(outcome, .insufficientHistory(measuredNights: 5, requiredNights: 14))
    }

    func testRefreshWithNoSamplesAtAllReturnsNoData() async throws {
        let cal = utcCalendar()
        let referenceDate = date(2026, 8, 11, calendar: cal)

        let outcome = try await RefreshCoordinator.refresh(
            need: SleepNeed(.hours(8)),
            referenceDate: referenceDate,
            now: referenceDate,
            calendar: cal,
            source: FakeSleepSource(samples: []),
            store: InMemorySnapshotStore(),
            reloader: RecordingReloader()
        )

        XCTAssertEqual(outcome, .noData)
    }
}
