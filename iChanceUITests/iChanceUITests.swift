import XCTest

final class iChanceUITests: XCTestCase {
    /// Drags the real slider: a half slide springs back, a full slide spins and lands on a win or a drop.
    func testSlideToSpin() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Try iChance"].tap()
        app.staticTexts["Features"].tap()

        let slider = app.buttons["Swipe to win"]
        XCTAssert(slider.waitForExistence(timeout: 5))
        let knob = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))

        // Held still before letting go, so there's no flick to carry it on.
        knob.press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssert(slider.isEnabled, "a half slide must spring back without spinning")

        knob.press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 0.5)))
        XCTAssert(app.buttons["keep"].waitForExistence(timeout: 15), "a full slide must spin, then ask: keep this or keep gambling")
        XCTAssert(app.buttons["keepGambling"].exists)
    }

    /// Product Tier: the first drop is free, the next costs $50 through Apple Pay, then the slider is back.
    func testProductTierDrop() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Try iChance"].tap()
        app.staticTexts["Products"].tap()

        let slider = app.buttons["Swipe to win"]
        XCTAssert(slider.waitForExistence(timeout: 5))
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 0.5)))
        let nothing = app.buttons["View Summary"]
        XCTAssert(app.buttons["keep"].waitForExistence(timeout: 15) || nothing.exists, "the ball must land and offer a choice")
        guard !nothing.exists else { return }  // landed on Nothing: the game is over
        sleep(1)
        let anotherTry = app.buttons["anotherTry"]
        guard anotherTry.exists else {
            // Landed on the best iPad: the next step is winning its features.
            app.buttons["gambleFeatures"].tap()
            XCTAssert(app.staticTexts["Features"].waitForExistence(timeout: 5))
            return
        }
        XCTAssertEqual(anotherTry.label, "$50 for another try")
        anotherTry.tap()
        let sheet = app.staticTexts["Double-Tap to Pay"]
        XCTAssert(sheet.waitForExistence(timeout: 5))
        sheet.doubleTap()
        XCTAssert(app.buttons["Swipe to win"].waitForExistence(timeout: 10), "paying must allow another drop")
    }

    /// Every 4 spins the slider gives way to the Apple Pay button; paying brings it back.
    func testPayForMoreSpins() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Try iChance"].tap()
        app.staticTexts["Features"].tap()

        for _ in 0..<4 {
            let slider = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Swipe to win'")).firstMatch
            XCTAssert(slider.waitForExistence(timeout: 5))
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 0.5)))
            XCTAssert(app.buttons["keepGambling"].waitForExistence(timeout: 15))
            sleep(1)  // a tap while the buttons are still fading in doesn't land
            app.buttons["keepGambling"].tap()
        }

        let pay = app.buttons["payForSpins"]
        XCTAssert(pay.waitForExistence(timeout: 5), "after 4 spins, more must be paid for")
        pay.tap()
        let sheet = app.staticTexts["Double-Tap to Pay"]
        XCTAssert(sheet.waitForExistence(timeout: 5))
        sheet.doubleTap()
        XCTAssert(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Swipe to win'")).firstMatch.waitForExistence(timeout: 10),
                  "paying must bring the slider back")
    }
}
