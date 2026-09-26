import XCTest

final class PlayWakeUITests: XCTestCase {
    func testPlayWakesNappingPetAndStartsArcadeGame() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset", "--fast-hatch"]
        app.launch()

        tap("brine.classic", in: app)
        tap("brineStart", in: app)
        let name = app.textFields["petName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Wake Dill\n")

        tap("care.nap", in: app)
        XCTAssertEqual(app.buttons["care.nap"].label, "Wake your pickle")
        XCTAssertTrue(app.buttons["care.play"].isEnabled)
        tap("care.play", in: app)
        XCTAssertTrue(app.buttons["arcade.game.hunt"].waitForExistence(timeout: 5))
        tap("arcade.close", in: app)
        XCTAssertEqual(app.buttons["care.nap"].label, "Nap")

        tap("care.play", in: app)
        tap("arcade.game.hunt", in: app)
        XCTAssertTrue(app.buttons["arcade.jar.0"].waitForExistence(timeout: 10))
    }

    private func tap(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 10), id, file: file, line: line)
        for _ in 0..<10 where !button.isHittable {
            let scroll = app.scrollViews.firstMatch
            guard scroll.exists else { break }
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.75))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.3))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0)
        }
        XCTAssertTrue(button.isHittable, id, file: file, line: line)
        button.tap()
    }
}
