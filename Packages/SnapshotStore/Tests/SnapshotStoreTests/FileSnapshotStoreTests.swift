import Foundation
import SleepDebtCore
import XCTest
@testable import SnapshotStore

final class FileSnapshotStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSnapshotStoreTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    private func makeSnapshot(debtHours: Double) -> DebtSnapshot {
        DebtSnapshot(
            referenceDate: Date(timeIntervalSince1970: 0),
            need: SleepNeed(.hours(8)),
            debt: .hours(debtHours),
            trend: .rising,
            breakEvenTarget: .hours(8),
            deltaSinceYesterday: nil,
            deltaSinceMonday: nil,
            fourteenNightAverage: .hours(6),
            measuredNightCount: 14,
            gapCount: 0,
            lastNightIsGap: false,
            lastNightSleepDuration: .hm(6, 30),
            nightBars: [],
            computedAt: Date(timeIntervalSince1970: 1000)
        )
    }

    func testReadBeforeAnyWriteIsNil() {
        let store = FileSnapshotStore(directory: tempDirectory)
        XCTAssertNil(store.readSnapshot())
    }

    func testWriteThenReadRoundTrips() throws {
        let store = FileSnapshotStore(directory: tempDirectory)
        let snapshot = makeSnapshot(debtHours: 3)
        try store.writeSnapshot(snapshot)
        XCTAssertEqual(store.readSnapshot(), snapshot)
    }

    func testWriteCreatesIntermediateDirectories() throws {
        let nested = tempDirectory.appendingPathComponent("a/b/c")
        let store = FileSnapshotStore(directory: nested)
        try store.writeSnapshot(makeSnapshot(debtHours: 1))
        XCTAssertEqual(store.readSnapshot()?.debt, .hours(1))
    }

    func testASecondWriteReplacesTheFirst() throws {
        let store = FileSnapshotStore(directory: tempDirectory)
        try store.writeSnapshot(makeSnapshot(debtHours: 3))
        try store.writeSnapshot(makeSnapshot(debtHours: 5))
        XCTAssertEqual(store.readSnapshot()?.debt, .hours(5))
    }

    func testASeparateStoreInstanceOverTheSameDirectorySeesWhatWasWritten() throws {
        // Models a snapshot written by one process (the app) being read by
        // another (the widget extension) — the actual App Group use case.
        try FileSnapshotStore(directory: tempDirectory).writeSnapshot(makeSnapshot(debtHours: 4))
        let reader = FileSnapshotStore(directory: tempDirectory)
        XCTAssertEqual(reader.readSnapshot()?.debt, .hours(4))
    }

    func testHistoryAvailabilityReadBeforeAnyWriteIsNil() {
        let store = FileSnapshotStore(directory: tempDirectory)
        XCTAssertNil(store.readHistoryAvailability())
    }

    func testHistoryAvailabilityWriteThenReadRoundTrips() throws {
        let store = FileSnapshotStore(directory: tempDirectory)
        try store.writeHistoryAvailability(.insufficient(measuredNights: 6, requiredNights: 14))
        XCTAssertEqual(
            store.readHistoryAvailability(), .insufficient(measuredNights: 6, requiredNights: 14)
        )
    }

    func testHistoryAvailabilityIsStoredIndependentlyOfTheSnapshot() throws {
        let store = FileSnapshotStore(directory: tempDirectory)
        try store.writeSnapshot(makeSnapshot(debtHours: 2))
        try store.writeHistoryAvailability(.sufficient)
        XCTAssertNotNil(store.readSnapshot())
        XCTAssertEqual(store.readHistoryAvailability(), .sufficient)
    }

    /// "Effacer mes données" (post-audit PLAN.md Phase 2): both files
    /// must actually be gone, not just marked unavailable — real erasure,
    /// not a state flag.
    func testClearRemovesBothSnapshotAndHistoryAvailability() throws {
        let store = FileSnapshotStore(directory: tempDirectory)
        try store.writeSnapshot(makeSnapshot(debtHours: 2))
        try store.writeHistoryAvailability(.sufficient)

        try store.clear()

        XCTAssertNil(store.readSnapshot())
        XCTAssertNil(store.readHistoryAvailability())
    }

    func testClearOnAnEmptyStoreDoesNotThrow() {
        let store = FileSnapshotStore(directory: tempDirectory)
        XCTAssertNoThrow(try store.clear())
    }
}
