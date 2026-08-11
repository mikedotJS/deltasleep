import XCTest
@testable import GlassKit

final class GlassTokensTests: XCTestCase {
    private func assertClose(
        _ a: Double, _ b: Double, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(a, b, accuracy: 0.001, file: file, line: line)
    }

    func testEveryTintHasAPalette() {
        // Not much of an assertion by itself, but it does mean
        // GlassTokens.palette(for:) is exhaustive over GlassTint —
        // a missing case here would be a compile error, not a test
        // failure, which is the point: this just documents the coverage.
        for tint in GlassTint.allCases {
            _ = GlassTokens.palette(for: tint)
        }
    }

    func testGreenBloomMatchesTheMockupsRgbaLiterals() {
        // .g-green { --tint-1: rgba(60,255,170,.42); --tint-2: rgba(20,190,255,.26) }
        let palette = GlassTokens.palette(for: .green)
        assertClose(palette.bloom1.red, 60.0 / 255.0)
        assertClose(palette.bloom1.green, 1)
        assertClose(palette.bloom1.blue, 170.0 / 255.0)
        assertClose(palette.bloom1.alpha, 0.42)
        assertClose(palette.bloom2.red, 20.0 / 255.0)
        assertClose(palette.bloom2.green, 190.0 / 255.0)
        assertClose(palette.bloom2.blue, 1)
        assertClose(palette.bloom2.alpha, 0.26)
    }

    func testRedFillMatchesTheMockupsHexLiterals() {
        // .g-red .fill { --f1:#FF9A6B; --f2:#F0264F; --f-glow:rgba(240,38,79,.6) }
        let palette = GlassTokens.palette(for: .red)
        assertClose(palette.fillStart.red, 1)
        assertClose(palette.fillStart.green, 154.0 / 255.0)
        assertClose(palette.fillStart.blue, 107.0 / 255.0)
        assertClose(palette.fillEnd.red, 240.0 / 255.0)
        assertClose(palette.fillEnd.green, 38.0 / 255.0)
        assertClose(palette.fillEnd.blue, 79.0 / 255.0)
        assertClose(palette.fillGlow.alpha, 0.6)
    }

    func testNeutralFillGlowIsFullyTransparent() {
        // .g-neut .fill { --f-glow: transparent } — the one tint with no
        // glow at all, since neutral states carry no colour signal.
        XCTAssertEqual(GlassTokens.palette(for: .neutral).fillGlow.alpha, 0)
    }

    func testCornerRadiiMatchTheMockupsRAndPhoneValues() {
        assertClose(GlassTokens.cornerRadiusWidget, 34)
        assertClose(GlassTokens.cornerRadiusPhone, 44)
    }
}
