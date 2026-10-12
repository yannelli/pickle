import XCTest
@testable import LittleDill

final class WardrobeTests: XCTestCase {
    func testNewLooksHaveStableIDsAndDrawableHats() {
        let ids = ["beanie", "beret", "headphones", "sunhat", "chef", "cowboy",
                   "pirate", "mushroom", "wizard", "rainhat", "halo", "helmet",
                   "cap", "backcap", "headband", "antenna", "captain", "bonnet",
                   "deerstalker", "mortarboard", "witch", "tophat", "headset", "shako",
                   "viking", "tiara", "jester", "unicorn", "phoenix", "emperor"]
        XCTAssertEqual(Outfit.allCases.count, 36)
        XCTAssertEqual(WardrobeArt.newOutfits.map(\.rawValue), ids)
        for outfit in WardrobeArt.newOutfits {
            XCTAssertNotNil(WardrobeArt.accent(outfit))
            XCTAssertFalse(WardrobeArt.parts(outfit).isEmpty, outfit.rawValue)
            XCTAssertGreaterThan(outfit.cost, 0)
            XCTAssertFalse(outfit.title.isEmpty)
        }
        XCTAssertEqual([Outfit.original, .sprout, .bow, .shades, .crown, .party].map(\.cost),
                       [0, 0, 30, 50, 90, 120])
        XCTAssertEqual(WardrobeArt.premium, Array(Outfit.allCases.suffix(6)))
        XCTAssertEqual(WardrobeArt.premium.map(\.cost), [500, 1000, 1500, 2000, 2500, 3000])
        XCTAssertTrue(Outfit.allCases.dropLast(6).allSatisfy { $0.cost < 500 })
    }

    func testNewLooksPurchaseEquipAndDecode() throws {
        for outfit in WardrobeArt.newOutfits {
            var pet = PetState(now: Date(timeIntervalSince1970: 1_700_000_000))
            pet.coins = outfit.cost
            XCTAssertTrue(pet.equip(outfit), outfit.rawValue)
            XCTAssertEqual(pet.coins, 0)
            XCTAssertEqual(pet.outfit, outfit)
            XCTAssertTrue(pet.unlocked.contains(outfit))
            XCTAssertTrue(pet.equip(outfit))
            XCTAssertEqual(pet.coins, 0)
            let restored = try JSONDecoder().decode(PetState.self, from: JSONEncoder().encode(pet))
            XCTAssertEqual(restored.outfit, outfit)
            XCTAssertTrue(restored.unlocked.contains(outfit))
        }
    }
}
