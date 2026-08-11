import XCTest
@testable import GlassKit

final class RGBATests: XCTestCase {
    private func assertClose(
        _ a: Double, _ b: Double, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(a, b, accuracy: 0.001, file: file, line: line)
    }

    func testR255ConstructorDividesByTwoFiftyFive() {
        let color = RGBA(r255: 255, g255: 0, b255: 128, alpha: 0.5)
        assertClose(color.red, 1)
        assertClose(color.green, 0)
        assertClose(color.blue, 128.0 / 255.0)
        assertClose(color.alpha, 0.5)
    }

    func testR255ConstructorDefaultsAlphaToOne() {
        let color = RGBA(r255: 0, g255: 0, b255: 0)
        assertClose(color.alpha, 1)
    }

    func testHexParsesSixDigitOpaqueColor() throws {
        // #B6FFDD — the green tint's figure-gradient end, hand-converted:
        // B6=182, FF=255, DD=221.
        let color = try XCTUnwrap(RGBA(hex: "#B6FFDD"))
        assertClose(color.red, 182.0 / 255.0)
        assertClose(color.green, 1)
        assertClose(color.blue, 221.0 / 255.0)
        assertClose(color.alpha, 1)
    }

    func testHexParsesWithoutALeadingHash() throws {
        let withHash = try XCTUnwrap(RGBA(hex: "#FF9A6B"))
        let withoutHash = try XCTUnwrap(RGBA(hex: "FF9A6B"))
        XCTAssertEqual(withHash, withoutHash)
    }

    func testHexParsesEightDigitWithAlpha() throws {
        // FF000080 — opaque-channel red, half alpha (0x80 / 255 ≈ .502).
        let color = try XCTUnwrap(RGBA(hex: "FF000080"))
        assertClose(color.red, 1)
        assertClose(color.green, 0)
        assertClose(color.blue, 0)
        assertClose(color.alpha, 128.0 / 255.0)
    }

    func testHexIsCaseInsensitive() throws {
        let lower = try XCTUnwrap(RGBA(hex: "ff9a6b"))
        let upper = try XCTUnwrap(RGBA(hex: "FF9A6B"))
        XCTAssertEqual(lower, upper)
    }

    func testHexReturnsNilForWrongLength() {
        XCTAssertNil(RGBA(hex: "#FFF"))
        XCTAssertNil(RGBA(hex: "#FF00"))
    }

    func testHexReturnsNilForNonHexCharacters() {
        XCTAssertNil(RGBA(hex: "#GGGGGG"))
    }
}
