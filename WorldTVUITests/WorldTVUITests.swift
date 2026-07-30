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
    func testChannelOpensFullscreenAndMenuHidesControlsBeforeClosing() {
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

        XCUIRemote.shared.press(.select)
        let nativeControls = app.cells["AVAudibleSettings"]
        XCTAssertTrue(
            nativeControls.waitForExistence(timeout: 5),
            "Select did not reveal the native playback controls."
        )
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(
            player.exists,
            "The first Menu press closed the player instead of hiding its controls."
        )
        Thread.sleep(forTimeInterval: 0.5)

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
            "Focus could not return to the filters button."
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
        let countryFilter = app.buttons["search.filter.country"]
        let categoryFilter = app.buttons["search.filter.category"]
        let qualityFilter = app.buttons["search.filter.quality"]
        XCTAssertTrue(countryFilter.isEnabled)
        XCTAssertTrue(categoryFilter.isEnabled)
        XCTAssertTrue(qualityFilter.isEnabled)
        for filter in [countryFilter, categoryFilter, qualityFilter] {
            XCTAssertGreaterThanOrEqual(filter.frame.minX, panel.frame.minX + 40)
            XCTAssertLessThanOrEqual(filter.frame.maxX, panel.frame.maxX - 40)
        }
        XCTAssertLessThanOrEqual(
            doneButton.frame.maxY,
            app.tables.firstMatch.frame.minY,
            "The filter list scrolls underneath the Done button."
        )

        XCUIRemote.shared.press(.select)

        let anyCountry = app.buttons["search.filter.option.any"]
        XCTAssertTrue(
            anyCountry.waitForExistence(timeout: 10),
            "The country options did not open."
        )
        XCTAssertGreaterThanOrEqual(anyCountry.frame.minX, panel.frame.minX + 40)
        XCTAssertLessThanOrEqual(anyCountry.frame.maxX, panel.frame.maxX - 40)

        XCUIRemote.shared.press(.menu)
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

        for _ in 0..<14 {
            XCUIRemote.shared.press(.down)
        }
        let filtersScrolledAway = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: filtersButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [filtersScrolledAway], timeout: 5),
            .completed,
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

    @MainActor
    func testMenuFromSecondaryContentFocusesItsTabBeforeReturningHome() {
        let app = XCUIApplication()
        app.launch()

        XCUIRemote.shared.press(.right)
        XCUIRemote.shared.press(.right)
        XCUIRemote.shared.press(.select)

        let filtersButton = app.buttons["search.filters.button"]
        XCTAssertTrue(
            filtersButton.waitForExistence(timeout: 30),
            "The Search tab did not open."
        )

        for _ in 0..<6 {
            if filtersButton.hasFocus {
                break
            }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(
            filtersButton.hasFocus,
            "Focus did not enter the Search content."
        )

        XCUIRemote.shared.press(.menu)

        XCTAssertTrue(
            app.tabBars.buttons["Buscar"].hasFocus,
            "The first Menu press did not return focus to the current Search tab."
        )
        XCTAssertTrue(
            filtersButton.exists,
            "The first Menu press left Search instead of preserving its content."
        )

        XCUIRemote.shared.press(.menu)

        let homeHeader = app.otherElements["home.header"]
        XCTAssertTrue(
            homeHeader.waitForExistence(timeout: 30),
            "Menu from the focused Search tab did not return to Home."
        )
        XCTAssertTrue(app.tabBars.buttons["Inicio"].hasFocus)
    }
    #elseif os(iOS)
    @MainActor
    func testChannelPlayerCoversTabBarAndCanClose() {
        let app = XCUIApplication()
        app.launch()

        let channel = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH '.available'")
        ).firstMatch
        XCTAssertTrue(
            channel.waitForExistence(timeout: 30),
            "No playable channel became available on iPhone."
        )

        channel.tap()

        let player = app.otherElements["player.fullscreen"]
        XCTAssertTrue(
            player.waitForExistence(timeout: 15),
            "The channel did not open the full-screen player."
        )
        let appFrame = app.windows.firstMatch.frame
        XCTAssertEqual(player.frame.minX, appFrame.minX, accuracy: 1)
        XCTAssertEqual(player.frame.minY, appFrame.minY, accuracy: 1)
        XCTAssertEqual(player.frame.maxX, appFrame.maxX, accuracy: 1)
        XCTAssertEqual(player.frame.maxY, appFrame.maxY, accuracy: 1)
        if app.tabBars.firstMatch.exists {
            XCTAssertFalse(
                app.tabBars.firstMatch.isHittable,
                "The iPhone tab bar remains interactive over the player."
            )
        }

        let closeButton = app.descendants(matching: .any)["player.close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        let playerDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: player
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [playerDismissed], timeout: 10),
            .completed,
            "The close button did not dismiss the iPhone player."
        )
        XCTAssertTrue(
            app.tabBars.firstMatch.isHittable
                || app.navigationBars.firstMatch.isHittable
        )
    }

    @MainActor
    func testPhoneHorizontalCarouselReachesScreenEdges() {
        let app = XCUIApplication()
        app.launch()

        guard app.tabBars.firstMatch.waitForExistence(timeout: 10) else {
            return
        }

        let carousel = app.scrollViews["home.channel.carousel"].firstMatch
        XCTAssertTrue(
            carousel.waitForExistence(timeout: 30),
            "The Home channel carousel did not load."
        )

        let appFrame = app.windows.firstMatch.frame
        XCTAssertEqual(carousel.frame.minX, appFrame.minX, accuracy: 1)
        XCTAssertEqual(carousel.frame.maxX, appFrame.maxX, accuracy: 1)

        let firstChannel = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH '.available'")
        ).firstMatch
        XCTAssertGreaterThanOrEqual(
            firstChannel.frame.minX,
            20
        )
    }
    #elseif os(macOS)
    @MainActor
    func testMacChannelPlayerOpensModalAndCloses() {
        let app = XCUIApplication()
        app.launch()

        let channel = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH '.available'")
        ).firstMatch
        XCTAssertTrue(
            channel.waitForExistence(timeout: 30),
            "No playable channel became available on Mac."
        )

        channel.click()

        let player = app.otherElements["player.fullscreen"]
        XCTAssertTrue(
            player.waitForExistence(timeout: 15),
            "The Mac player did not open in its modal presentation."
        )

        let closeButton = app.buttons["player.close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.click()

        let playerDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: player
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [playerDismissed], timeout: 10),
            .completed,
            "The Mac player did not close."
        )
    }
    #endif
}
