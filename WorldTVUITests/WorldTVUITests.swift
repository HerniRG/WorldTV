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
        XCTAssertTrue(
            channels.allElementsBoundByIndex.contains(where: \.hasFocus),
            "Down did not move focus from the tab bar to a channel."
        )

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
            "Focus was not restored to the Home channel shelf."
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
        let selectionHeader = app.descendants(matching: .any).matching(
            identifier: "search.filter.selection.header"
        ).firstMatch
        XCTAssertTrue(
            selectionHeader.waitForExistence(timeout: 5),
            "The filter-selection header did not appear."
        )
        XCTAssertGreaterThanOrEqual(anyCountry.frame.minX, panel.frame.minX + 60)
        XCTAssertLessThanOrEqual(anyCountry.frame.maxX, panel.frame.maxX - 60)
        XCTAssertGreaterThanOrEqual(
            anyCountry.frame.minY,
            selectionHeader.frame.maxY + 24,
            "The first focused option is clipped against the selection header."
        )

        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10),
            "Menu left the filters modal instead of returning to its main list."
        )
        XCTAssertTrue(
            countryFilter.exists,
            "The main filter list did not return from the country options."
        )
        XCTAssertFalse(
            anyCountry.exists,
            "The country options remained visible after Menu."
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
    func testCountryDetailRestoresFocusToOriginCountry() {
        let app = XCUIApplication()
        app.launch()

        XCUIRemote.shared.press(.right)
        XCUIRemote.shared.press(.select)

        let countries = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'country.'")
        )
        XCTAssertTrue(
            countries.firstMatch.waitForExistence(timeout: 30),
            "The Countries grid did not load."
        )

        for _ in 0..<10 {
            if countries.allElementsBoundByIndex.contains(where: \.hasFocus) {
                break
            }
            XCUIRemote.shared.press(.down)
        }
        guard let focusedCountry = countries.allElementsBoundByIndex.first(
            where: \.hasFocus
        ) else {
            XCTFail("Focus did not enter the Countries grid.")
            return
        }
        let focusedCountryIdentifier = focusedCountry.identifier

        XCUIRemote.shared.press(.select)

        let channel = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'channel.'")
        ).firstMatch
        XCTAssertTrue(
            channel.waitForExistence(timeout: 30),
            "The selected country did not open its channel grid."
        )

        XCUIRemote.shared.press(.menu)

        let restoredCountry = app.buttons[focusedCountryIdentifier]
        XCTAssertTrue(
            restoredCountry.waitForExistence(timeout: 10),
            "Menu did not return to the Countries grid."
        )
        let countryFocusRestored = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.hasFocus == true
            },
            object: restoredCountry
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [countryFocusRestored], timeout: 10),
            .completed,
            "Focus was not restored to the country that opened the detail."
        )
    }

    @MainActor
    func testHomeCountrySelectsSearchTabWithCountryFilter() {
        let app = XCUIApplication()
        app.launch()

        let countries = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'home.open.country.'"
            )
        )
        let homeHeader = app.otherElements["home.header"]
        XCTAssertTrue(
            homeHeader.waitForExistence(timeout: 30),
            "Home did not load."
        )

        for _ in 0..<20 {
            if countries.firstMatch.exists,
               countries.allElementsBoundByIndex.contains(where: \.hasFocus) {
                break
            }
            XCUIRemote.shared.press(.down)
        }
        guard let focusedCountry = countries.allElementsBoundByIndex.first(
            where: \.hasFocus
        ) else {
            XCTFail("Focus did not enter the popular-countries grid on Home.")
            return
        }
        let focusedCountryIdentifier = focusedCountry.identifier
        let countryCode = String(
            focusedCountryIdentifier.dropFirst("home.open.country.".count)
        )

        XCUIRemote.shared.press(.select)

        let filtersButton = app.buttons["search.filters.button"]
        XCTAssertTrue(
            filtersButton.waitForExistence(timeout: 30),
            "The selected Home country did not open the Search tab."
        )
        XCTAssertTrue(
            app.tabBars.buttons["Buscar"].hasFocus,
            "The selected Home country did not select the Search tab."
        )
        XCTAssertEqual(
            filtersButton.value as? String,
            countryCode,
            "Search did not receive the country selected on Home."
        )
    }

    @MainActor
    func testChannelGridPlayerRestoresFocusToOriginChannel() {
        let app = XCUIApplication()
        app.launch()

        XCUIRemote.shared.press(.right)
        XCUIRemote.shared.press(.select)

        let countries = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'country.'")
        )
        XCTAssertTrue(countries.firstMatch.waitForExistence(timeout: 30))
        for _ in 0..<10 {
            if countries.allElementsBoundByIndex.contains(where: \.hasFocus) {
                break
            }
            XCUIRemote.shared.press(.down)
        }
        guard countries.allElementsBoundByIndex.contains(where: \.hasFocus) else {
            XCTFail("Focus did not enter the Countries grid.")
            return
        }

        XCUIRemote.shared.press(.select)

        let playableChannels = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH '.available'")
        )
        XCTAssertTrue(
            playableChannels.firstMatch.waitForExistence(timeout: 30),
            "The country channel grid did not load playable channels."
        )
        for _ in 0..<12 {
            if playableChannels.allElementsBoundByIndex.contains(where: \.hasFocus) {
                break
            }
            XCUIRemote.shared.press(.down)
        }
        guard let focusedChannel = playableChannels.allElementsBoundByIndex.first(
            where: \.hasFocus
        ) else {
            XCTFail("Focus did not enter the country channel grid.")
            return
        }
        let focusedChannelIdentifier = focusedChannel.identifier

        XCUIRemote.shared.press(.select)

        let player = app.otherElements["player.fullscreen"]
        XCTAssertTrue(
            player.waitForExistence(timeout: 15),
            "The channel grid did not open the player."
        )

        XCUIRemote.shared.press(.menu)

        let restoredChannel = app.buttons[focusedChannelIdentifier]
        let channelFocusRestored = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.hasFocus == true
            },
            object: restoredChannel
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [channelFocusRestored], timeout: 10),
            .completed,
            "Focus was not restored to the channel that opened the player."
        )
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

        app.typeKey(.escape, modifierFlags: [])

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
