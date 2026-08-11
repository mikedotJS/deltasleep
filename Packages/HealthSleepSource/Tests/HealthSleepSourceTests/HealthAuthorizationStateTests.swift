import XCTest
@testable import HealthSleepSource

final class HealthAuthorizationStateTests: XCTestCase {
    func testNeverAskedAndHealthKitAgreesNeedsPrompt() {
        let state = HealthAuthorizationState.resolve(
            didRequestBefore: false, requestStatus: .shouldPromptAgain, hasAnySampleEver: false
        )
        XCTAssertEqual(state, .needsPrompt)
    }

    func testNeverAskedButHealthKitRemembersAGrantFallsThroughOnData() {
        // A reinstall over a prior grant: our own flag is gone, but
        // HealthKit's isn't. Should not re-prompt for access that's
        // already there — resolve from sample data instead.
        let withData = HealthAuthorizationState.resolve(
            didRequestBefore: false, requestStatus: .alreadyRequested, hasAnySampleEver: true
        )
        XCTAssertEqual(withData, .readableWithData)

        let withoutData = HealthAuthorizationState.resolve(
            didRequestBefore: false, requestStatus: .alreadyRequested, hasAnySampleEver: false
        )
        XCTAssertEqual(withoutData, .readableNoData)
    }

    func testAskedBeforeButHealthKitWantsANewPromptForANewlyAddedType() {
        let state = HealthAuthorizationState.resolve(
            didRequestBefore: true, requestStatus: .shouldPromptAgain, hasAnySampleEver: true
        )
        XCTAssertEqual(state, .needsPrompt)
    }

    func testAskedBeforeAndNoDataEverIsTheMergedNoDataState() {
        let state = HealthAuthorizationState.resolve(
            didRequestBefore: true, requestStatus: .alreadyRequested, hasAnySampleEver: false
        )
        XCTAssertEqual(state, .readableNoData)
    }

    func testAskedBeforeAndSomeDataExistsIsReadable() {
        let state = HealthAuthorizationState.resolve(
            didRequestBefore: true, requestStatus: .alreadyRequested, hasAnySampleEver: true
        )
        XCTAssertEqual(state, .readableWithData)
    }

    func testUnknownStatusAfterAskingFallsThroughOnDataRatherThanReprompting() {
        let state = HealthAuthorizationState.resolve(
            didRequestBefore: true, requestStatus: .unknown, hasAnySampleEver: true
        )
        XCTAssertEqual(state, .readableWithData)
    }

    func testUnknownStatusBeforeAskingIsConservativelyANeedsPrompt() {
        let state = HealthAuthorizationState.resolve(
            didRequestBefore: false, requestStatus: .unknown, hasAnySampleEver: false
        )
        XCTAssertEqual(state, .needsPrompt)
    }
}
