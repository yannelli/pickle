import XCTest

final class ContinuityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing","--reset","--fast-hatch"]
        app.launch()
        tap("brine.classic"); tap("brineStart")
        let name = app.textFields["petName"]
        XCTAssertTrue(name.waitForExistence(timeout:10))
        name.tap(); name.typeText("Continuity Dill\n")
        XCTAssertTrue(app.buttons["tab.Nest"].waitForExistence(timeout:5))
    }

    func testDailyCircuitProgressAndNextGameOnCompactPhone() {
        tap("care.play")
        let play = app.buttons["arcade.circuit.play"]
        XCTAssertTrue(play.waitForExistence(timeout:5))
        XCTAssertTrue(play.isEnabled)
        capture("circuit-menu")
        tap("arcade.circuit.play")
        XCTAssertTrue(app.otherElements["arcade.hop.board"].waitForExistence(timeout:5))
        app.otherElements["arcade.hop.board"].tap()
        let next = app.buttons["arcade.circuit.next"]
        XCTAssertTrue(next.waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["arcade.circuit.result"].exists)
        capture("circuit-first-result")
        tap("arcade.circuit.next")
        XCTAssertTrue(app.otherElements["arcade.chop.board"].waitForExistence(timeout:5))
        tap("arcade.close")
        tap("care.play")
        XCTAssertTrue(play.waitForExistence(timeout:5))
        XCTAssertTrue(play.label.contains("Continue"))
        app.terminate()
        app.launchArguments = ["--ui-testing","--fast-hatch"]
        app.launch()
        tap("care.play")
        XCTAssertTrue(play.waitForExistence(timeout:5))
        XCTAssertTrue(play.label.contains("Continue"))
        capture("circuit-persisted")
    }

    func testCountertopEscapeHasAPlayableFullScreenBoard() {
        tap("care.play"); tap("arcade.circuit.play")
        let board = app.otherElements["arcade.hop.board"]
        XCTAssertTrue(board.waitForExistence(timeout:5))
        XCTAssertTrue(board.label.contains("Countertop escape"))
        XCTAssertTrue(board.isHittable)
        capture("escape-ready-phone")
        board.tap()
        Thread.sleep(forTimeInterval:1)
        board.tap()
        capture("escape-jump-phone")
        let next = app.buttons["arcade.circuit.next"]
        XCTAssertTrue(next.waitForExistence(timeout:12))
        capture("escape-result-phone")
        XCTAssertTrue(next.isHittable)
    }

    func testArenaRestoresControlsAfterBackground() {
        tap("tab.Friends"); tap("createArenaRoom")
        let joystick = app.otherElements["arenaJoystick"]
        XCTAssertTrue(joystick.waitForExistence(timeout:20))
        XCTAssertTrue(app.staticTexts["arenaPopulation"].label.contains("in the garden"))
        capture("arena-before-background")
        XCUIDevice.shared.press(.home)
        app.activate()
        let connected = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS 'in the garden'"),object:app.staticTexts["arenaPopulation"])
        XCTAssertEqual(XCTWaiter.wait(for:[connected],timeout:15),.completed)
        XCTAssertTrue(joystick.isHittable)
        XCTAssertFalse(app.buttons["arenaReconnect"].exists)
        capture("arena-restored")
        tap("arenaLeave"); app.buttons["Leave arena"].tap()
        XCTAssertTrue(app.buttons["tab.Friends"].waitForExistence(timeout:5))
    }

    func testArenaThumbControlsSwapAndPersistOnCompactPhone() {
        tap("tab.Friends"); tap("createArenaRoom")
        let joystick = app.otherElements["arenaJoystick"]
        XCTAssertTrue(joystick.waitForExistence(timeout:20))
        let split = app.buttons["arenaSplit"], dash = app.buttons["arenaDash"]
        let initiallyLeft = joystick.frame.midX < split.frame.midX
        tap("arenaSwapControls")
        XCTAssertEqual(joystick.frame.midX < split.frame.midX,!initiallyLeft)
        for item in [joystick,split,dash,app.buttons["arenaSwapControls"]] {
            XCTAssertTrue(app.frame.insetBy(dx:-1,dy:-1).contains(item.frame))
        }
        XCTAssertFalse(split.frame.intersects(dash.frame))
        capture("arena-swapped-controls")
        tap("arenaLeave"); app.buttons["Leave arena"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing","--fast-hatch"]
        app.launch()
        tap("tab.Friends"); tap("createArenaRoom")
        XCTAssertTrue(joystick.waitForExistence(timeout:20))
        XCTAssertEqual(joystick.frame.midX < split.frame.midX,!initiallyLeft)
        let center = joystick.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        let edge = joystick.coordinate(withNormalizedOffset:CGVector(dx:0.8,dy:0.3))
        center.press(forDuration:0.1,thenDragTo:edge,withVelocity:.slow,thenHoldForDuration:0.2)
        tap("arenaSwapControls")
        XCTAssertEqual(joystick.frame.midX < split.frame.midX,initiallyLeft)
        capture("arena-default-controls")
        tap("arenaLeave"); app.buttons["Leave arena"].tap()
    }

    private func tap(_ id:String,file:StaticString = #filePath,line:UInt = #line) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout:10),id,file:file,line:line)
        for _ in 0..<10 {
            if button.isHittable {break}
            let scroll = app.scrollViews.firstMatch
            guard scroll.exists else {break}
            let reverse = button.frame.midY < scroll.frame.minY
            let start = scroll.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:reverse ? 0.3 : 0.75))
            let end = scroll.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:reverse ? 0.75 : 0.3))
            start.press(forDuration:0.05,thenDragTo:end,withVelocity:.slow,thenHoldForDuration:0)
        }
        XCTAssertTrue(button.isHittable,id,file:file,line:line)
        button.tap()
    }

    private func capture(_ name:String) {
        let screenshot = XCTAttachment(screenshot:app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
