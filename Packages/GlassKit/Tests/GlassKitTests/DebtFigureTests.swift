import XCTest
@testable import GlassKit

final class DebtFigureTests: XCTestCase {
    func testZeroPadsSingleDigitMinutes() {
        XCTAssertEqual(DebtFigure.formattedMinutes(4), "04")
    }

    func testDoesNotPadDoubleDigitMinutes() {
        XCTAssertEqual(DebtFigure.formattedMinutes(26), "26")
    }

    func testZeroMinutes() {
        XCTAssertEqual(DebtFigure.formattedMinutes(0), "00")
    }
}
