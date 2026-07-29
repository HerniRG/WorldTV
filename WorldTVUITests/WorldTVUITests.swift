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

    @MainActor
    func testSearchFiltersScrollWithHeaderAndPickersRemainInteractive() {
        let app = XCUIApplication()
        app.launch()

        XCUIRemote.shared.press(.right)
        XCUIRemote.shared.press(.right)
        XCUIRemote.shared.press(.select)

        let filtersButton = app.buttons["search.filters.button"]
        XCTAssertTrue(
            filtersButton.waitForExistence(timeout: 30),
            "The filters button did not appear."
        )

        for _ in 0..<6 {
            if filtersButton.hasFocus {
                break
            }
            XCUIRemote.shared.press(.down)
        }
        for _ in 0..<6 {
            if filtersButton.hasFocus {
                break
            }
            XCUIRemote.shared.press(.right)
        }
        XCTAssertTrue(
            filtersButton.hasFocus,
            "Focus could not return to the fixed filters button."
        )
        XCUIRemote.shared.press(.select)

        let doneButton = app.buttons["search.filters.done"]
        let panel = app.otherElements["search.filters.panel"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "The filters modal did not open."
        )
        XCTAssertTrue(panel.exists, "The filters panel did not appear.")
        XCTAssertGreaterThanOrEqual(panel.frame.minX, 80)
        XCTAssertGreaterThanOrEqual(panel.frame.minY, 80)
        XCTAssertTrue(app.buttons["País"].isEnabled)
        XCTAssertTrue(app.buttons["Categoría"].isEnabled)
        XCTAssertTrue(app.buttons["Calidad mínima"].isEnabled)
        XCTAssertLessThanOrEqual(
            doneButton.frame.maxY,
            app.tables.firstMatch.frame.minY,
            "The filter list scrolls underneath the Done button."
        )

        XCUIRemote.shared.press(.menu)
        let modalDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: doneButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [modalDismissed], timeout: 10),
            .completed,
            "Menu did not close the filters modal."
        )

        for _ in 0..<7 {
            XCUIRemote.shared.press(.down)
        }
        XCTAssertFalse(
            filtersButton.isHittable,
            "The filters button remained fixed instead of scrolling with the title."
        )
    }

    @MainActor
    func testHomeFavoritesActionSelectsFavoritesTab() {
        let app = XCUIApplication()
        app.launch()

        let favoritesAction = app.buttons["home.open.favorites"]
        XCUIRemote.shared.press(.down)
        for _ in 0..<14 {
            if favoritesAction.exists && favoritesAction.hasFocus {
                break
            }
            XCUIRemote.shared.press(.down)
        }

        XCTAssertTrue(
            favoritesAction.hasFocus,
            "Focus did not reach the Home favorites action."
        )
        XCUIRemote.shared.press(.select)

        let favoritesScreen = app.descendants(matching: .any).matching(
            identifier: "favorites.screen"
        ).firstMatch
        XCTAssertTrue(
            favoritesScreen.waitForExistence(timeout: 10),
            "The Home favorites action pushed content inside Home instead of selecting its tab."
        )
        XCTAssertTrue(app.tabBars.buttons["Favoritos"].hasFocus)
    }
    #endif
}
