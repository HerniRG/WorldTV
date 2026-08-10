import XCTest
@testable import WorldTV

final class PlayerPresentationStateMachineTests: XCTestCase {
    func testPlayDeepLinkCreatesPresentationForEveryPlatformEntryPoint() throws {
        let url = try XCTUnwrap(URL(string: "worldtv://play/channel-a"))
        let nonPlayURL = try XCTUnwrap(URL(string: "worldtv://channel/channel-a"))
        let presentation = try XCTUnwrap(PlayerPresentation(playURL: url))

        XCTAssertEqual(presentation.channelID, "channel-a")
        XCTAssertNil(presentation.feedID)
        XCTAssertNil(PlayerPresentation(playURL: nonPlayURL))
    }

    func testRepeatedChannelPresentationUsesANewIdentity() {
        let first = PlayerPresentation(channelID: "channel-a")
        let second = PlayerPresentation(channelID: "channel-a")

        XCTAssertNotEqual(first.id, second.id)
    }

    func testPictureInPictureRoundTripReturnsToPresented() {
        var machine = PlayerPresentationStateMachine()

        XCTAssertTrue(machine.didPresent())
        XCTAssertTrue(machine.willStartPictureInPicture())
        XCTAssertTrue(machine.preservesPlaybackWhenViewDisappears)
        XCTAssertTrue(machine.didStartPictureInPicture())
        XCTAssertTrue(machine.beginRestoration())
        XCTAssertTrue(machine.didRestore())

        XCTAssertEqual(machine.state, .presented)
        XCTAssertFalse(machine.preservesPlaybackWhenViewDisappears)
    }

    func testNormalDismissalIsDistinctFromPictureInPicture() {
        var machine = PlayerPresentationStateMachine()

        XCTAssertTrue(machine.didPresent())
        XCTAssertTrue(machine.beginDismissal())
        XCTAssertFalse(machine.preservesPlaybackWhenViewDisappears)
        XCTAssertTrue(machine.didDismiss())

        XCTAssertEqual(machine.state, .idle)
    }

    func testLatePictureInPictureTransitionsCannotReplacePresentedState() {
        var machine = PlayerPresentationStateMachine()

        XCTAssertTrue(machine.didPresent())
        XCTAssertTrue(machine.willStartPictureInPicture())
        XCTAssertTrue(machine.didStartPictureInPicture())
        XCTAssertTrue(machine.beginRestoration())
        XCTAssertTrue(machine.didRestore())

        XCTAssertFalse(machine.didStartPictureInPicture())
        XCTAssertFalse(machine.didRestore())
        XCTAssertEqual(machine.state, .presented)
    }

    func testFailedPictureInPictureStartKeepsPresentationVisible() {
        var machine = PlayerPresentationStateMachine()

        XCTAssertTrue(machine.didPresent())
        XCTAssertTrue(machine.willStartPictureInPicture())
        XCTAssertTrue(machine.pictureInPictureStartFailed())

        XCTAssertEqual(machine.state, .presented)
    }

    func testRestorationFailureReturnsToPictureInPicture() {
        var machine = PlayerPresentationStateMachine()

        XCTAssertTrue(machine.didPresent())
        XCTAssertTrue(machine.willStartPictureInPicture())
        XCTAssertTrue(machine.didStartPictureInPicture())
        XCTAssertTrue(machine.beginRestoration())
        XCTAssertTrue(machine.restorationFailed())

        XCTAssertEqual(machine.state, .inPiP)
        XCTAssertTrue(machine.preservesPlaybackWhenViewDisappears)
    }
}
