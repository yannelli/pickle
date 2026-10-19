import XCTest
@testable import LittleDill

final class ArenaEventsTests: XCTestCase {
    private func snapshot(extra:String = "",player:String = "") throws -> ArenaSnapshot {
        let json = """
        {"tick":1,"time":1,"width":8400,"height":6300,"humans":1,"bots":0\(extra),
         "players":[{"id":"you","name":"Dilly","brine":"classic","outfit":"sprout","bot":false,"x":1,"y":2,"mass":640,
          "best":640,"kills":0,"alive":true,"shield":0,"dash":0,"cooldown":0,"respawn":0,"eatenBy":""\(player)}]}
        """
        return try JSONDecoder().decode(ArenaSnapshot.self,from:Data(json.utf8))
    }

    func testMalformedOptionalFieldsFallBackWithoutFailingTheSnapshot() throws {
        let state = try snapshot(extra:#","jar":{"x":"left","y":2},"bounty":7"#,
                                 player:#","goals":[["eat",2,1],["mass","lots",0],7,["jar",1,1]],"goalsDone":"four","run":[1,2]"#)
        XCTAssertNil(state.jar)
        XCTAssertNil(state.bounty)
        let me = try XCTUnwrap(state.players.first)
        XCTAssertEqual(me.goals,[ArenaGoal(kind:"eat",target:2,progress:1),ArenaGoal(kind:"jar",target:1,progress:1)])
        XCTAssertEqual(me.goalsDone,0)
        XCTAssertNil(me.run)
        let nulls = try snapshot(extra:#","jar":null,"bounty":null"#,player:#","goals":null,"goalsDone":null,"run":null"#)
        XCTAssertNil(nulls.jar)
        XCTAssertEqual(nulls.players.first?.goals,[])
        XCTAssertEqual(nulls.players.first?.goalsDone,0)
    }

    func testJarSpillFiresOnceWhenTheWarningReachesZero() {
        let warning = ArenaJar(x:1,y:2,warn:0.1), spilled = ArenaJar(x:1,y:2,warn:0)
        XCTAssertTrue(ArenaJar.spilled(from:warning,to:spilled))
        XCTAssertFalse(ArenaJar.spilled(from:spilled,to:spilled))
        XCTAssertFalse(ArenaJar.spilled(from:nil,to:spilled))
        XCTAssertFalse(ArenaJar.spilled(from:warning,to:nil))
        XCTAssertFalse(ArenaJar.spilled(from:ArenaJar(x:1,y:2,warn:5),to:warning))
    }

    func testJarClockTimesTheSpillAndResetsForANewJar() {
        let clock = ArenaJarClock(), start = Date(timeIntervalSinceReferenceDate:100)
        XCTAssertNil(clock.spillAge(ArenaJar(x:1,y:2,warn:3),at:start))
        XCTAssertEqual(clock.spillAge(ArenaJar(x:1,y:2,warn:0),at:start),0)
        XCTAssertEqual(clock.spillAge(ArenaJar(x:1,y:2,warn:0),at:start + 2),2)
        XCTAssertEqual(clock.spillAge(ArenaJar(x:9,y:2,warn:0),at:start + 3),0)
        XCTAssertNil(clock.spillAge(nil,at:start + 4))
        XCTAssertEqual(ArenaEventArt.tip(spilled:true,spillAge:0.3,still:false),0.5,accuracy:1e-9)
        XCTAssertEqual(ArenaEventArt.tip(spilled:true,spillAge:0,still:true),1)
        XCTAssertEqual(ArenaEventArt.tip(spilled:false,spillAge:nil,still:false),0)
    }

    func testWarningRingPulsesBetweenThreeAndSixPointsUnlessMotionIsReduced() {
        let widths = stride(from:0.0,to:1,by:0.05).map {ArenaEventArt.ringWidth(time:$0,still:false)}
        XCTAssertEqual(widths.min() ?? 0,3,accuracy:0.05)
        XCTAssertEqual(widths.max() ?? 0,6,accuracy:0.05)
        XCTAssertEqual(ArenaEventArt.ringWidth(time:0.25,still:false),ArenaEventArt.ringWidth(time:1.25,still:false),accuracy:1e-9)
        XCTAssertEqual(ArenaEventArt.ringWidth(time:0.25,still:true),ArenaEventArt.ringWidth(time:0.75,still:true))
    }

    func testBountyCrownSitsOnTheHoldersLargestPiece() throws {
        let state = try snapshot(extra:#","bounty":"you""#,
                                 player:#","cells":[{"id":"a","x":1,"y":2,"mass":100},{"id":"b","x":5,"y":6,"mass":540}]"#)
        XCTAssertEqual(ArenaEventArt.bountyPiece(players:state.players,bounty:state.bounty)?.id,"b")
        XCTAssertNil(ArenaEventArt.bountyPiece(players:state.players,bounty:"someone"))
        XCTAssertNil(ArenaEventArt.bountyPiece(players:state.players,bounty:nil))
    }

    func testRecapUsesTheRunAndThisLifesGoals() throws {
        let state = try snapshot(player:#","goals":[["eat",1,1],["food",40,12],["survive",90,95]],"goalsDone":7,"run":[1830.4,3,95.8,2]"#)
        let recap = try XCTUnwrap(ArenaRunRecap(player:state.players.first))
        XCTAssertEqual(recap,ArenaRunRecap(peakMass:1830,kills:3,seconds:95,rank:2,goalsDone:2,goalCount:3))
        XCTAssertEqual(recap.timeText,"1:35")
        XCTAssertEqual(recap.rankText,"#2")
        XCTAssertEqual(recap.goalsText,"2/3")
        XCTAssertEqual(recap.summary,"Best rank #2 · 3 crunched · 1:35 alive · 2/3 goals")
        let unknown = ArenaRunRecap(peakMass:80,kills:0,seconds:42,rank:0,goalsDone:0,goalCount:0)
        XCTAssertEqual(unknown.timeText,"42s")
        XCTAssertEqual(unknown.rankText,"–")
        XCTAssertNil(unknown.goalsText)
        XCTAssertNil(ArenaRunRecap(player:try snapshot().players.first))
    }

    func testGoalToastsFireOnceWhenAGoalCompletesAfterThePrimingSnapshot() {
        var watch = ArenaGoalWatch()
        let open = [ArenaGoal(kind:"eat",target:2,progress:1),ArenaGoal(kind:"food",target:40,progress:39)]
        let done = [ArenaGoal(kind:"eat",target:2,progress:2),ArenaGoal(kind:"food",target:40,progress:40)]
        XCTAssertEqual(watch.completed(done),[])
        XCTAssertEqual(watch.completed(done),[])
        watch.reset()
        XCTAssertEqual(watch.completed(open),[])
        XCTAssertEqual(watch.completed(done),done)
        XCTAssertEqual(watch.completed(done),[])
        let respawned = [ArenaGoal(kind:"mass",target:2,progress:2),ArenaGoal(kind:"food",target:40,progress:0)]
        XCTAssertEqual(watch.completed(open),[])
        XCTAssertEqual(watch.completed(respawned),[])
        XCTAssertEqual(ArenaGoalWatch.toast(done[0],coins:true),"✓ Crunch 2 pickles · +5 coins")
        XCTAssertEqual(ArenaGoalWatch.toast(done[1],coins:false),"✓ Eat 40 pellets")
    }

    func testGoalLabelsFallBackAndClampProgress() {
        XCTAssertEqual(ArenaGoal(kind:"juggle",target:3,progress:0).label,"Complete a goal")
        XCTAssertEqual(ArenaGoal(kind:"mass",target:12000,progress:0).label,"Reach 12000 mass")
        XCTAssertEqual(ArenaGoal(kind:"survive",target:120,progress:150).progressText,"120/120s")
        XCTAssertEqual(ArenaGoal(kind:"food",target:40,progress:12).progressText,"12/40")
        XCTAssertTrue(ArenaGoal(kind:"food",target:40,progress:40).done)
        XCTAssertFalse(ArenaGoal(kind:"food",target:40,progress:39).done)
    }
}
