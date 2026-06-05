import XCTest

final class LabAssistantUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(withExampleData: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        if withExampleData {
            app.launchArguments.append("-ui-testing-example-data")
        }
        app.launch()
        return app
    }

    func testAppStartsOnChemicalsAndCanSwitchTabs() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["No chemicals saved"].waitForExistence(timeout: 2))

        let darkroomTab = app.tabBars.buttons["Darkroom"]
        XCTAssertTrue(darkroomTab.waitForExistence(timeout: 2))
        darkroomTab.tap()

        XCTAssertTrue(app.staticTexts["No processes saved"].waitForExistence(timeout: 2))
    }

    func testChemicalsTabRemainsAccessibleAfterSwitchingAway() {
        let app = launchApp()

        let darkroomTab = app.tabBars.buttons["Darkroom"]
        XCTAssertTrue(darkroomTab.waitForExistence(timeout: 2))
        darkroomTab.tap()

        let chemicalsTab = app.tabBars.buttons["Chemicals"]
        XCTAssertTrue(chemicalsTab.waitForExistence(timeout: 2))
        chemicalsTab.tap()

        XCTAssertTrue(app.staticTexts["No chemicals saved"].waitForExistence(timeout: 2))
    }

    func testExampleDataLaunchShowsSeededChemicalsAndProcesses() {
        let app = launchApp(withExampleData: true)

        XCTAssertTrue(app.staticTexts["Water"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Ilfotec DD-X"].waitForExistence(timeout: 2))

        let darkroomTab = app.tabBars.buttons["Darkroom"]
        XCTAssertTrue(darkroomTab.waitForExistence(timeout: 2))
        darkroomTab.tap()

        XCTAssertTrue(app.staticTexts["HP5+ in DD-X"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["3 steps"].waitForExistence(timeout: 2))
    }
    
    func testProcessButtonsExist() {
        let app = launchApp(withExampleData: true)
        app.tabBars.buttons["Darkroom"].tap()
        
        let startButton = app.buttons["Start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        
        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2))
        
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        

    }
    
    func testNextAndEndButtons() {
        let app = launchApp(withExampleData: true)
        app.activate()
        app/*@START_MENU_TOKEN@*/.images["film.fill"]/*[[".buttons[\"Darkroom\"].images",".buttons",".images[\"movie\"]",".images[\"film.fill\"]"],[[[-1,3],[-1,2],[-1,1,1],[-1,0]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.firstMatch.tap()
        app.buttons["Start"].tap()
        let nextButton = app.buttons["next"]
        let endButton = app.buttons["end"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 2))
        nextButton.tap()
        nextButton.tap()
        XCTAssertTrue(endButton.waitForExistence(timeout: 2))
        endButton.tap()
        XCTAssertTrue(app.staticTexts["HP5+ in DD-X"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3 steps"].waitForExistence(timeout: 5))
    }
    
}
