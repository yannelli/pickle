import XCTest

final class LittleDillUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["--ui-testing","--reset","--fast-hatch"]; app.launch()
    }
    private func tap(_ id:String,file:StaticString = #filePath,line:UInt = #line) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout:10),"Missing button: \(id)",file:file,line:line)
        for _ in 0..<10 {
            if button.isHittable {break}
            let scroll = app.scrollViews.firstMatch
            guard scroll.exists else {break}
            let reverse = button.frame.midY < scroll.frame.minY
            let start = scroll.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:reverse ? 0.3 : 0.75))
            let end = scroll.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:reverse ? 0.75 : 0.3))
            start.press(forDuration:0.05,thenDragTo:end,withVelocity:.slow,thenHoldForDuration:0)
        }
        XCTAssertTrue(button.isHittable,"Button remains offscreen: \(id)",file:file,line:line)
        button.tap()
    }
    private func adopt(brine:String = "classic",name:String = "Dilly") {
        tap("brine.\(brine)"); tap("brineStart")
        let field = app.textFields["petName"]
        XCTAssertTrue(field.waitForExistence(timeout:10),"The brine never hatched")
        field.tap(); field.typeText(name + "\n")
        XCTAssertTrue(app.buttons["tab.Nest"].waitForExistence(timeout:5))
    }
    private func screenshot(_ name:String) {
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func completePlayer() {
        for _ in 0..<3 {tap("gameReady"); tap("gameCrunch"); tap("gameNext")}
    }
    func testAdoptionCareWardrobePersistenceAndSharing() {
        screenshot("01-welcome")
        adopt(); screenshot("02-nest")
        for action in ["feed","pet","wash","nap"] {tap("care.\(action)")}
        XCTAssertTrue(app.staticTexts["4/4 little acts of love today"].exists)
        tap("tab.Closet"); screenshot("03-closet"); tap("outfit.bow")
        app.alerts.buttons["Unlock for 30 coins"].tap()
        XCTAssertTrue(app.buttons["outfit.bow"].label.contains("wearing"))
        app.terminate(); app.launchArguments = ["--ui-testing","--fast-hatch"]; app.launch()
        tap("tab.Closet")
        XCTAssertTrue(app.buttons["outfit.bow"].label.contains("wearing"))
        tap("tab.Friends"); screenshot("04-friends"); tap("Share your pickle")
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout:5) || app.buttons["Copy"].waitForExistence(timeout:5))
        screenshot("05-native-sharing")
    }
    func testDailyChallengeAndPassAndPlay() {
        adopt(); tap("tab.Play"); screenshot("06-arcade"); tap("playDaily")
        screenshot("07-challenge"); completePlayer(); screenshot("08-scorecard")
        XCTAssertTrue(app.otherElements["finalScore"].exists || app.staticTexts["/ 300"].exists)
        tap("gameDone"); tap("passAndPlay"); tap("startParty")
        completePlayer(); tap("gameHandoff"); completePlayer(); screenshot("09-party-results")
        XCTAssertTrue(app.staticTexts["Player 1"].exists); XCTAssertTrue(app.staticTexts["Player 2"].exists)
    }
    func testOnlineArenaMovementAndReturn() {
        adopt(); tap("tab.Play"); tap("joinArena")
        let joystick = app.otherElements["arenaJoystick"]
        XCTAssertTrue(joystick.waitForExistence(timeout:20),"Online arena did not connect")
        XCTAssertTrue(app.staticTexts["arenaPopulation"].label.contains("in the garden"))
        XCTAssertFalse(app.staticTexts["arenaPopulation"].label.localizedCaseInsensitiveContains("bot"))
        screenshot("10-live-arena")
        let origin = joystick.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        let destination = joystick.coordinate(withNormalizedOffset:CGVector(dx:0.8,dy:0.3))
        origin.press(forDuration:0.1,thenDragTo:destination,withVelocity:.slow,thenHoldForDuration:2)
        screenshot("11-live-arena-movement")
        tap("arenaLeave"); app.buttons["Leave arena"].tap()
        XCTAssertTrue(app.buttons["tab.Nest"].waitForExistence(timeout:5))
    }
    func testArenaSplitControlsStayVisibleOnCompactScreen() {
        adopt(); tap("tab.Friends"); tap("createArenaRoom")
        let joystick = app.otherElements["arenaJoystick"]
        XCTAssertTrue(joystick.waitForExistence(timeout:20),"Online arena did not connect")
        let split = app.buttons["arenaSplit"], dash = app.buttons["arenaDash"]
        let regroup = app.staticTexts["arenaRegroup"]
        for element in [joystick,split,dash,regroup,app.buttons["arenaLeave"]] {
            XCTAssertTrue(element.exists)
            XCTAssertGreaterThan(element.frame.width,0)
            XCTAssertTrue(app.frame.insetBy(dx:-1,dy:-1).contains(element.frame),"Arena control extends outside the screen: \(element.identifier), \(element.frame)")
        }
        XCTAssertFalse(split.frame.intersects(dash.frame))
        XCTAssertFalse(joystick.frame.intersects(split.frame))
        XCTAssertEqual(split.label,"Split your pickle")
        screenshot("split-controls-compact")
        tap("arenaLeave"); app.buttons["Leave arena"].tap()
        XCTAssertTrue(app.buttons["tab.Friends"].waitForExistence(timeout:5))
    }
    func testDistinctCareScenesAndSoundSetting() {
        adopt()
        for action in ["feed","pet","wash","nap"] {
            tap("care.\(action)")
            XCTAssertTrue(app.otherElements["careScene.\(action)"].waitForExistence(timeout:2))
            screenshot("care-\(action)")
        }
        XCTAssertTrue(app.otherElements["careScene.sleeping"].waitForExistence(timeout:8))
        tap("care.nap")
        XCTAssertTrue(app.otherElements["careScene.idle"].waitForExistence(timeout:3))
        tap("Settings")
        let sound = app.switches["soundEffects"]
        XCTAssertTrue(sound.waitForExistence(timeout:5))
        if !sound.isHittable {app.swipeUp()}
        XCTAssertEqual(sound.value as? String,"1")
        sound.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)).tap()
        let muted = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == '0'"),object:sound)
        XCTAssertEqual(XCTWaiter.wait(for:[muted],timeout:3),.completed)
        screenshot("sound-setting")
        tap("Done")
        app.terminate(); app.launchArguments = ["--ui-testing","--fast-hatch"]; app.launch()
        tap("Settings"); XCTAssertTrue(sound.waitForExistence(timeout:5)); XCTAssertEqual(sound.value as? String,"0")
    }
    func testBriningSurvivesRelaunch() {
        app.terminate(); app.launchArguments = ["--ui-testing","--reset"]; app.launch()
        tap("brine.spicy"); tap("brineStart")
        XCTAssertTrue(app.progressIndicators["hatchProgress"].waitForExistence(timeout:5))
        screenshot("01b-brining")
        app.terminate(); app.launchArguments = ["--ui-testing"]; app.launch()
        XCTAssertTrue(app.progressIndicators["hatchProgress"].waitForExistence(timeout:5),"Brining restarted after relaunch")
        XCTAssertFalse(app.buttons["brineStart"].exists)
    }
    func testEatThePickleAndRestart() {
        adopt()
        let pickle = app.otherElements["careScene.idle"]
        XCTAssertTrue(pickle.waitForExistence(timeout:5))
        pickle.press(forDuration:1.2)
        XCTAssertTrue(app.otherElements["careScene.scared"].waitForExistence(timeout:3))
        XCTAssertEqual(app.buttons["care.wash"].label,"Take a bite")
        tap("care.wash"); tap("care.wash")
        screenshot("12-bitten")
        tap("care.wash")
        XCTAssertTrue(app.buttons["restart"].waitForExistence(timeout:3))
        XCTAssertTrue(app.otherElements["careScene.dead"].exists)
        screenshot("13-eaten")
        tap("restart")
        XCTAssertTrue(app.buttons["brineStart"].waitForExistence(timeout:5))
    }
}
