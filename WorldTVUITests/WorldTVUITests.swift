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
}
