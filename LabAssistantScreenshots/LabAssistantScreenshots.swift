import XCTest

final class LabAssistantScreenshots: XCTestCase {
    @MainActor
    override func setUp() {
        XCUIDevice.shared.appearance = .dark
        super.setUp()
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-example-data"]
        setupSnapshot(app)
        app.launch()
    }
    
    @MainActor
    func testScreenshots() throws {
        XCUIDevice.shared.appearance = .dark
        let app = XCUIApplication()
        _ = app.waitForExistence(timeout: 2)
        snapshot("02-chemicals")
        app.buttons["Darkroom"].firstMatch.tap()
        app.buttons["Start"].tap()
        app.buttons["next"].tap()
        _ = app.waitForExistence(timeout: 3.25)
        snapshot("01-workflow")
        app.buttons["previous"].tap()
        app.buttons["end"].tap()
        snapshot("03-list")
        app.buttons["Edit"].tap()
        snapshot("03-edit")
        
    }
}
