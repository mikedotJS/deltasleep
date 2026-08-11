import XCTest
@testable import GlassKit

final class GrainTextureTests: XCTestCase {
    func testProducesTheRequestedCount() {
        XCTAssertEqual(GrainTexture.points(count: 50, seed: 1).count, 50)
    }

    func testEveryPointIsWithinUnitBounds() {
        let points = GrainTexture.points(count: 200, seed: 42)
        for point in points {
            XCTAssertTrue((0 ... 1).contains(point.x))
            XCTAssertTrue((0 ... 1).contains(point.y))
            XCTAssertTrue((0.05 ... 0.35).contains(point.opacity))
        }
    }

    func testIsDeterministicForTheSameSeed() {
        let first = GrainTexture.points(count: 30, seed: 7)
        let second = GrainTexture.points(count: 30, seed: 7)
        XCTAssertEqual(first, second)
    }

    func testDifferentSeedsProduceDifferentPoints() {
        let first = GrainTexture.points(count: 30, seed: 1)
        let second = GrainTexture.points(count: 30, seed: 2)
        XCTAssertNotEqual(first, second)
    }

    func testZeroCountIsEmpty() {
        XCTAssertTrue(GrainTexture.points(count: 0, seed: 1).isEmpty)
    }
}
