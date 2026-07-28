import XCTest

final class WorldTVUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchScreenshot() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "WorldTV launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
