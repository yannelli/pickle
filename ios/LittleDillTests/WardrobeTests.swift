import XCTest
@testable import LittleDill

final class WardrobeTests: XCTestCase {
    func testNewLooksHaveStableIDsAndDrawableHats() {
        let ids = ["beanie", "beret", "headphones", "sunhat", "chef", "cowboy",
                   "pirate", "mushroom", "wizard", "rainhat", "halo", "helmet"]
        XCTAssertEqual(Outfit.allCases.count, 18)
        XCTAssertEqual(WardrobeArt.newOutfits.map(\.rawValue), ids)
        for outfit in WardrobeArt.newOutfits {
            XCTAssertNotNil(WardrobeArt.accent(outfit))
            XCTAssertFalse(PetArt.hat(outfit.rawValue).isEmpty, outfit.rawValue)
            XCTAssertGreaterThan(outfit.cost, 0)
            XCTAssertFalse(outfit.title.isEmpty)
        }
        XCTAssertEqual([Outfit.original, .sprout, .bow, .shades, .crown, .party].map(\.cost),
                       [0, 0, 30, 50, 90, 120])
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
