import XCTest

final class WorldTVUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testApplicationLaunches() {
        let app = XCUIApplication()

        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 20),
            "WorldTV did not reach the foreground."
        )
    }

    #if os(tvOS)
    @MainActor
    func testHomeHeaderScrollsAwayWithContent() {
        let app = XCUIApplication()
        app.launch()

        let header = app.otherElements["home.header"]
        XCTAssertTrue(
            header.waitForExistence(timeout: 30),
            "The home header did not load."
        )

        for _ in 0..<6 {
            if !header.isHittable {
                break
            }
            XCUIRemote.shared.press(.down)
        }

        XCTAssertFalse(
            header.isHittable,
            "The home header remained fixed while focus moved down through the content."
        )
    }

    @MainActor
    func testChannelOpensFullscreenAndMenuRestoresFocus() {
        let app = XCUIApplication()
        app.launch()

        let channels = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'channel.'")
        )
        XCTAssertTrue(
            channels.firstMatch.waitForExistence(timeout: 30),
            "No channel became available on the home screen."
        )

        XCUIRemote.shared.press(.down)
        let focusedChannel = channels.allElementsBoundByIndex.first(where: \.hasFocus)
        XCTAssertNotNil(focusedChannel, "Down did not move focus from the tab bar to a channel.")

        XCUIRemote.shared.press(.select)
        let player = app.otherElements["player.fullscreen"]
        XCTAssertTrue(
            player.waitForExistence(timeout: 15),
            "Select did not open the full-screen player."
        )
        XCTAssertFalse(
            app.tabBars.firstMatch.isHittable,
            "The tab bar remains visible or interactive over the player."
        )

        XCUIRemote.shared.press(.menu)
        let playerDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: player
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [playerDismissed], timeout: 10),
            .completed,
            "Menu did not close the player."
        )
        XCTAssertTrue(
            channels.allElementsBoundByIndex.contains(where: \.hasFocus),
            "Focus was not restored to the channel shelf."
        )
    }
    #endif
}
