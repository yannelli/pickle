import XCTest
@testable import LittleDill

final class ArenaExpressionTests:XCTestCase {
    private func player(_ hurt:Double? = nil) throws -> ArenaPlayer {
        var value:[String:Any] = ["id":"dill","name":"Dill","brine":"classic","outfit":"original","bot":false,
                                 "x":0,"y":0,"mass":100,"best":100,"kills":0,"alive":true,"shield":0,
                                 "dash":0,"cooldown":0,"respawn":0,"eatenBy":""]
        if let hurt {value["hurt"] = hurt}
        return try JSONDecoder().decode(ArenaPlayer.self,from:JSONSerialization.data(withJSONObject:value))
    }

    func testSadFaceUsesServerTimerAndLegacyPlayersDecode() throws {
        let sad = try player(2.4), calm = try player(0), legacy = try player()
        XCTAssertEqual(ArenaCanvas.mood(sad,cell:sad.pieces[0],pieces:[]),.sad)
        XCTAssertEqual(ArenaCanvas.mood(calm,cell:calm.pieces[0],pieces:[]),.calm)
        XCTAssertEqual(ArenaCanvas.mood(legacy,cell:legacy.pieces[0],pieces:[]),.calm)
        XCTAssertNil(legacy.hurt)
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
