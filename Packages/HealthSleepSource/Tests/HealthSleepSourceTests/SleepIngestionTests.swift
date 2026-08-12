import Foundation
import SleepDebtCore
import XCTest
@testable import HealthSleepSource

final class SleepIngestionTests: XCTestCase {
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - days(count:endingOn:calendar:)

    /// Post-audit PLAN.md Phase 3: the "historique > 14 nuits" capability
    /// gap — a plain "last N days" range, not bounded by the debt
    /// engine's 14-night window.
    func testDaysReturnsCountConsecutiveDaysOldestFirst() {
        let cal = utcCalendar()
        let end = date(2026, 8, 11, calendar: cal)
        let days = SleepIngestion.days(count: 90, endingOn: end, calendar: cal)
        XCTAssertEqual(days.count, 90)
        XCTAssertEqual(days.last, end)
        XCTAssertEqual(days.first, cal.date(byAdding: .day, value: -89, to: end))
    }

    func testDaysWithZeroCountIsEmpty() {
        let cal = utcCalendar()
        let end = date(2026, 8, 11, calendar: cal)
        XCTAssertEqual(SleepIngestion.days(count: 0, endingOn: end, calendar: cal), [])
    }

    func testDaysWithCountOneIsJustTheEndDate() {
        let cal = utcCalendar()
        let end = date(2026, 8, 11, calendar: cal)
        XCTAssertEqual(SleepIngestion.days(count: 1, endingOn: end, calendar: cal), [end])
    }

    // MARK: - nights(for:from:calendar:) over a wide range

    /// Confirms the existing `nights(for:from:calendar:)` genuinely has
    /// no built-in bound — it's `days(count:endingOn:)`'s output that's
    /// new, not a new ceiling being lifted here.
    func testNightsHandlesARangeWiderThanTheDebtEngineWindow() async throws {
        let cal = utcCalendar()
        let end = date(2026, 8, 11, calendar: cal)
        let days = SleepIngestion.days(count: 90, endingOn: end, calendar: cal)
        let nights = try await SleepIngestion.nights(
            for: days,
            from: FakeSleepSource(samples: []),
            calendar: cal
        )
        XCTAssertEqual(nights.count, 90)
        XCTAssertTrue(nights.allSatisfy(\.isGap), "no samples supplied — every day is a gap")
    }
}
