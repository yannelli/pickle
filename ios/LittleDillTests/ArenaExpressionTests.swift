import XCTest
@testable import LittleDill

final class ArenaExpressionTests:XCTestCase {
    private func player(_ hurt:Double? = nil,tear:Double? = nil) throws -> ArenaPlayer {
        var value:[String:Any] = ["id":"dill","name":"Dill","brine":"classic","outfit":"original","bot":false,
                                 "x":0,"y":0,"mass":100,"best":100,"kills":0,"alive":true,"shield":0,
                                 "dash":0,"cooldown":0,"respawn":0,"eatenBy":""]
        if let hurt {value["hurt"] = hurt}
        if let tear {value["tear"] = tear}
        return try JSONDecoder().decode(ArenaPlayer.self,from:JSONSerialization.data(withJSONObject:value))
    }

    func testSadFaceUsesServerTimerAndLegacyPlayersDecode() throws {
        let sad = try player(2.4), calm = try player(0), legacy = try player()
        XCTAssertEqual(ArenaCanvas.mood(sad,cell:sad.pieces[0],pieces:[]),.sad)
        XCTAssertEqual(ArenaCanvas.mood(calm,cell:calm.pieces[0],pieces:[]),.calm)
        XCTAssertEqual(ArenaCanvas.mood(legacy,cell:legacy.pieces[0],pieces:[]),.calm)
        XCTAssertNil(legacy.hurt)
        XCTAssertNil(legacy.tear)
    }

    func testTearGlidesOnceAndReduceMotionKeepsItStill() throws {
        let sad = try player(15,tear:1.4)
        XCTAssertEqual(sad.tear,1.4)
        XCTAssertEqual(ArenaTear.pose(remaining:1.4,reduceMotion:false)?.offset,0)
        XCTAssertEqual(ArenaTear.pose(remaining:0.7,reduceMotion:false)?.offset,1.05)
        XCTAssertEqual(ArenaTear.pose(remaining:0.7,reduceMotion:false)?.alpha,0.425)
        XCTAssertEqual(ArenaTear.pose(remaining:0.7,reduceMotion:true)?.offset,0)
        XCTAssertNil(ArenaTear.pose(remaining:0,reduceMotion:false))
    }

    func testDensePickupsFadeAndRestResetWithoutAccumulatingSounds() {
        var cadence = ArenaPickupCadence()
        var cues:[ArenaPickupCadence.Cue] = []
        for frame in 0..<600 {
            if let cue = cadence.next(at:Double(frame)/60) {cues.append(cue)}
        }
        XCTAssertTrue((20...26).contains(cues.count))
        XCTAssertEqual(cues.prefix(5).map(\.index),[0,1,2,3,0])
        XCTAssertTrue(cues.dropFirst(5).allSatisfy {$0.volume < cues[0].volume})
        XCTAssertEqual(cadence.next(at:20)?.volume,0.7)
    }
}
