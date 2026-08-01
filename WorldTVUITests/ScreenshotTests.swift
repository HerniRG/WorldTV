import XCTest

#if os(iOS)
import UIKit
#endif

// These tests capture App Store screenshots and attach them to the test result
// (XCTAttachment, lifetime .keepAlways). The attachment name is
// "<platform>--<name>" so `scripts/capture-screenshots.sh` can export the PNGs
// from the xcresult bundle and sort them into the store folders. They only run
// when explicitly targeted (`-only-testing:WorldTVUITests/ScreenshotTests`).
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func waitForHome(_ app: XCUIApplication) {
        let header = app.otherElements["home.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 30), "Home did not load.")
        let channel = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH '.available'")
        ).firstMatch
        if !channel.exists {
            _ = channel.waitForExistence(timeout: 30)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }

    @MainActor
    private func waitForHittable(
        _ query: XCUIElementQuery,
        timeout: TimeInterval = 30
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for element in query.allElementsBoundByIndex where element.exists {
                if element.isHittable {
                    return element
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        return nil
    }

    @MainActor
    private func save(
        _ screenshot: XCUIScreenshot,
        _ name: String,
        platform: String
    ) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(platform)--\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("WORLDTV_SCREENSHOT:\(platform)--\(name)")
    }

    #if !os(tvOS)
    @MainActor
    private func selectSection(_ app: XCUIApplication, _ name: String) {
        if app.tabBars.firstMatch.exists {
            let button = app.tabBars.buttons[name]
            XCTAssertTrue(button.waitForExistence(timeout: 15), "Tab '\(name)' not found.")
            button.activate()
            return
        }
        let candidates = [
            app.buttons[name],
            app.cells[name],
            app.staticTexts[name]
        ]
        for candidate in candidates where candidate.waitForExistence(timeout: 5) {
            candidate.activate()
            return
        }
        XCTFail("Sidebar section '\(name)' not found.")
    }
    #endif

    #if os(iOS)
    @MainActor
    func testCaptureHome() {
        let app = makeApp()
        waitForHome(app)
        save(XCUIScreen.main.screenshot(), "01_home", platform: platformFolder)
    }

    @MainActor
    func testCaptureSearch() {
        let app = makeApp()
        waitForHome(app)
        selectSection(app, "Search")
        let filters = app.buttons["search.filters.button"]
        XCTAssertTrue(filters.waitForExistence(timeout: 30), "Search did not open.")
        save(XCUIScreen.main.screenshot(), "02_search", platform: platformFolder)
    }

    @MainActor
    func testCaptureCountries() {
        let app = makeApp()
        waitForHome(app)
        selectSection(app, "Countries")
        let country = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'country.'")
        ).firstMatch
        XCTAssertTrue(country.waitForExistence(timeout: 30), "Countries did not open.")
        save(XCUIScreen.main.screenshot(), "03_countries", platform: platformFolder)
    }

    @MainActor
    func testCaptureChannelDetail() {
        let app = makeApp()
        waitForHome(app)
        guard let infoButton = waitForHittable(
            app.buttons.matching(identifier: "Channel Details")
        ) else {
            XCTFail("No hittable channel info button on Home.")
            return
        }
        infoButton.tap()
        let playButton = app.buttons["channel.detail.play"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 30), "Channel detail did not open.")
        save(XCUIScreen.main.screenshot(), "04_channel_detail", platform: platformFolder)
    }

    @MainActor
    func testCapturePlayer() {
        let app = makeApp()
        waitForHome(app)
        guard let channel = waitForHittable(
            app.buttons.matching(NSPredicate(format: "identifier ENDSWITH '.available'"))
        ) else {
            XCTFail("No hittable playable channel on Home.")
            return
        }
        channel.tap()
        let player = app.otherElements["player.fullscreen"]
        XCTAssertTrue(player.waitForExistence(timeout: 20), "Player did not open.")
        save(XCUIScreen.main.screenshot(), "05_player", platform: platformFolder)
        let close = app.buttons["player.close"]
        if close.waitForExistence(timeout: 5) {
            close.tap()
        }
    }

    @MainActor
    private var platformFolder: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "ios-ipad" : "ios-iphone"
    }
    #elseif os(tvOS)
    @MainActor
    func testCaptureHome() {
        let app = makeApp()
        let header = app.otherElements["home.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 30), "Home did not load.")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        save(XCUIScreen.main.screenshot(), "01_home", platform: "tvos")
    }

    @MainActor
    func testCaptureSearch() {
        let app = makeApp()
        let header = app.otherElements["home.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 30), "Home did not load.")
        XCUIRemote.shared.press(.right)
        XCUIRemote.shared.press(.right)
        XCUIRemote.shared.press(.select)
        let filters = app.buttons["search.filters.button"]
        XCTAssertTrue(filters.waitForExistence(timeout: 30), "Search did not open.")
        save(XCUIScreen.main.screenshot(), "02_search", platform: "tvos")
    }

    @MainActor
    func testCaptureCountries() {
        let app = makeApp()
        let header = app.otherElements["home.header"]
        XCTAssertTrue(header.waitForExistence(timeout: 30), "Home did not load.")
        XCUIRemote.shared.press(.right)
        XCUIRemote.shared.press(.select)
        let country = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'country.'")
        ).firstMatch
        XCTAssertTrue(country.waitForExistence(timeout: 30), "Countries did not open.")
        save(XCUIScreen.main.screenshot(), "03_countries", platform: "tvos")
    }

    @MainActor
    func testCapturePlayer() {
        let app = makeApp()
        let channels = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'channel.'")
        )
        XCTAssertTrue(channels.firstMatch.waitForExistence(timeout: 30), "No channels loaded.")
        for _ in 0..<6 {
            if channels.allElementsBoundByIndex.contains(where: \.hasFocus) {
                break
            }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(
            channels.allElementsBoundByIndex.contains(where: \.hasFocus),
            "Focus did not reach a channel."
        )
        XCUIRemote.shared.press(.select)
        let player = app.otherElements["player.fullscreen"]
        XCTAssertTrue(player.waitForExistence(timeout: 20), "Player did not open.")
        save(XCUIScreen.main.screenshot(), "05_player", platform: "tvos")
    }
    #elseif os(macOS)
    @MainActor
    func testCaptureHome() {
        let app = makeApp()
        waitForHome(app)
        resizeMacWindow(app, to: CGSize(width: 1440, height: 900))
        save(app.windows.firstMatch.screenshot(), "01_home", platform: "mac")
    }

    @MainActor
    func testCaptureSearch() {
        let app = makeApp()
        waitForHome(app)
        resizeMacWindow(app, to: CGSize(width: 1440, height: 900))
        selectSection(app, "Search")
        let filters = app.buttons["search.filters.button"]
        XCTAssertTrue(filters.waitForExistence(timeout: 30), "Search did not open.")
        save(app.windows.firstMatch.screenshot(), "02_search", platform: "mac")
    }

    @MainActor
    func testCaptureCountries() {
        let app = makeApp()
        waitForHome(app)
        resizeMacWindow(app, to: CGSize(width: 1440, height: 900))
        selectSection(app, "Countries")
        let country = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'country.'")
        ).firstMatch
        XCTAssertTrue(country.waitForExistence(timeout: 30), "Countries did not open.")
        save(app.windows.firstMatch.screenshot(), "03_countries", platform: "mac")
    }

    @MainActor
    func testCaptureChannelDetail() {
        let app = makeApp()
        waitForHome(app)
        resizeMacWindow(app, to: CGSize(width: 1440, height: 900))
        guard let infoButton = waitForHittable(
            app.buttons.matching(identifier: "Channel Details")
        ) else {
            XCTFail("No hittable channel info button on Home.")
            return
        }
        infoButton.click()
        let playButton = app.buttons["channel.detail.play"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 30), "Channel detail did not open.")
        save(app.windows.firstMatch.screenshot(), "04_channel_detail", platform: "mac")
    }

    @MainActor
    func testCapturePlayer() {
        let app = makeApp()
        waitForHome(app)
        resizeMacWindow(app, to: CGSize(width: 1440, height: 900))
        guard let channel = waitForHittable(
            app.buttons.matching(NSPredicate(format: "identifier ENDSWITH '.available'"))
        ) else {
            XCTFail("No hittable playable channel on Home.")
            return
        }
        channel.click()
        let player = app.otherElements["player.fullscreen"]
        XCTAssertTrue(player.waitForExistence(timeout: 20), "Player did not open.")
        save(player.screenshot(), "05_player", platform: "mac")
        let close = app.buttons["player.close"]
        if close.waitForExistence(timeout: 5) {
            close.click()
        }
    }

    private func resizeMacWindow(_ app: XCUIApplication, to size: CGSize) {
        let window = app.windows.firstMatch
        guard window.exists else { return }
        let frame = window.frame
        guard frame.width > 0, frame.height > 0 else { return }
        let handle = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
        let delta = CGVector(dx: size.width - frame.width, dy: size.height - frame.height)
        let target = handle.withOffset(delta)
        handle.press(forDuration: 0.1, thenDragTo: target)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }
    #endif
}

#if !os(tvOS)
private extension XCUIElement {
    func activate() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}
#endif
