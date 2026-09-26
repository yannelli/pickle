import XCTest
@testable import LittleDill

final class CrossPlatformParityTests: XCTestCase {
    func testNativeMatchesSharedWebGameplayFixtures() throws {
        let url = try XCTUnwrap(Bundle(for:Self.self).url(forResource:"arena-parity",withExtension:"json"))
        let fixture = try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:url))
        for row in fixture.splits {XCTAssertEqual(row.player.canSplit,row.enabled,row.name)}
        for row in fixture.radii {XCTAssertEqual(ArenaPlayer.radius(for:row.mass),row.radius,accuracy:1e-9)}
        for row in fixture.zoom {
            XCTAssertEqual(ArenaPlayer.easeZoom(current:row.current,target:row.target,dt:row.dt),row.result,accuracy:1e-9)
        }
        for row in fixture.food {
            XCTAssertEqual(row.snapshot.updatedFood(from:row.before) ?? row.before,row.after,row.name)
        }
        for look in PickleVariety.all {
            let shared = try XCTUnwrap(fixture.varieties[look.id])
            XCTAssertEqual(look.brine,shared.brine)
            XCTAssertEqual(look.color,UInt32(shared.color.dropFirst(),radix:16))
            XCTAssertEqual(look.light,UInt32(shared.light.dropFirst(),radix:16))
            XCTAssertEqual(look.dark,UInt32(shared.dark.dropFirst(),radix:16))
            XCTAssertEqual(look.shape.rawValue,shared.shape)
        }
        XCTAssertEqual(ArenaPlayer.eatOverlap,fixture.rules["eatOverlap"])
        for (variety,smile) in fixture.smiles {XCTAssertEqual(ArenaSmile(variety:variety).rawValue,smile)}
        var cadence = ArenaPickupCadence()
        for row in fixture.pickups {
            let cue = cadence.next(at:row.time)
            XCTAssertEqual(cue?.index,row.index)
            if let cue, let volume = row.volume {XCTAssertEqual(cue.volume,volume,accuracy:1e-9)}
        }
        for gadget in ArenaGadget.allCases {
            let period = try XCTUnwrap(fixture.gadgetPeriods[gadget.rawValue])
            XCTAssertEqual(gadget.drainSound.duration,period * 8,accuracy:1e-9)
        }
    }
    private struct Fixture: Decodable {
        let rules:[String:Double]
        let smiles:[String:String]
        let pickups:[Pickup]
        let splits: [Split]
        let radii: [Radius]
        let zoom: [Zoom]
        let food: [Food]
        let varieties: [String:Look]
        let gadgetPeriods: [String:Double]
    }
    private struct Pickup:Decodable {let time:Double; let index:Int?; let volume:Double?}
    private struct Split: Decodable { let name:String; let player:ArenaPlayer; let enabled:Bool }
    private struct Radius: Decodable { let mass:Double; let radius:Double }
    private struct Zoom: Decodable { let current:Double; let target:Double; let dt:Double; let result:Double }
    private struct Food: Decodable { let name:String; let before:[[Double]]; let snapshot:ArenaSnapshot; let after:[[Double]] }
    private struct Look: Decodable { let brine:String; let color:String; let light:String; let dark:String; let shape:String }
}
