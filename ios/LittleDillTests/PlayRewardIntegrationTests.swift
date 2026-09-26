import XCTest
@testable import LittleDill

final class PlayRewardIntegrationTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_790_381_000)

    private func sleeping(energy: Double = 50) -> PetState {
        var pet = PetState(now: now)
        pet.life.phase = .living
        pet.life.name = "Sleepy"
        pet.life.brinedAt = PetLife.ms(now) - PetLife.HATCH_MS
        pet.life.hatchAt = PetLife.ms(now)
        pet.life.bornAt = PetLife.ms(now)
        pet.life.sleeping = true
        pet.life.energy = energy
        return pet
    }

    func testOpeningPlayWakesWithoutSpendingEnergyOrAwardingCareCoins() {
        var pet = sleeping()
        let coins = pet.coins
        XCTAssertTrue(pet.prepareArcade(at: now))
        XCTAssertFalse(pet.life.sleeping)
        XCTAssertEqual(pet.life.energy, 50)
        XCTAssertEqual(pet.coins, coins)
        XCTAssertFalse(pet.dailyCare.contains("nap"))
        XCTAssertTrue(pet.startArcade(at: now))
        XCTAssertEqual(pet.life.energy, 44)
        var tired = sleeping(energy: 5)
        XCTAssertFalse(tired.startArcade(at: now))
        XCTAssertFalse(tired.life.sleeping)
        XCTAssertEqual(tired.life.energy, 5)
        var egg = PetState(now: now)
        XCTAssertFalse(egg.prepareArcade(at: now))
        pet.life.dead = true
        XCTAssertFalse(pet.prepareArcade(at: now))
    }

    @MainActor func testRewardWalletPersistsAndReplayedSnapshotsDoNotPayAgain() throws {
        let suite = "dill-rewards-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DillStore(defaults: defaults, clock: { self.now })
        let coins = store.pet.coins
        XCTAssertEqual(store.recordArena(earnedMass: 100_000, session: "public-1:player"), 100)
        XCTAssertEqual(store.pet.coins, coins + 100)
        XCTAssertEqual(store.arenaCoinsToday, 100)
        let resumed = DillStore(defaults: defaults, clock: { self.now })
        XCTAssertEqual(resumed.recordArena(earnedMass: 100_000, session: "public-1:player"), 0)
        XCTAssertEqual(resumed.pet.coins, coins + 100)
        XCTAssertEqual(resumed.recordArena(earnedMass: 1_500_000, session: "public-1:player"), 900)
        XCTAssertEqual(resumed.pet.coins, coins + 1_000)
        XCTAssertEqual(resumed.recordArena(earnedMass: 2_000_000, session: "public-1:player"), 0)
        XCTAssertEqual(resumed.arenaCoinsToday, 1_000)
    }

    func testBackupKeepsCoinProgressAndLegacySavesStillDecode() throws {
        var pet = sleeping()
        XCTAssertEqual(pet.recordArena(earnedMass: 123_456.7, session: "public-2:player", at: now), 123)
        let data = try DillBackup.encode(pet: pet.life, native: pet.native, savedAt: PetLife.ms(now))
        let backup = try DillBackup.decode(data)
        var restored = PetState(now: now)
        restored.apply(try XCTUnwrap(backup.native))
        XCTAssertEqual(restored.arenaEarnings, pet.arenaEarnings)
        XCTAssertEqual(restored.coins, pet.coins)
        XCTAssertEqual(restored.recordArena(earnedMass: 123_456.7, session: "public-2:player", at: now), 0)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(pet)) as? [String: Any])
        legacy.removeValue(forKey: "arenaEarnings")
        let decoded = try JSONDecoder().decode(PetState.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(decoded.arenaEarnings)
        XCTAssertEqual(decoded.coins, pet.coins)
    }

    func testOlderArenaSnapshotsHaveNoRewardCounter() throws {
        var value: [String: Any] = ["id": "dill", "name": "Dill", "brine": "classic", "outfit": "original",
            "bot": false, "x": 0, "y": 0, "mass": 100, "best": 100, "kills": 0, "alive": true,
            "shield": 0, "dash": 0, "cooldown": 0, "respawn": 0, "eatenBy": ""]
        let old = try JSONDecoder().decode(ArenaPlayer.self, from: JSONSerialization.data(withJSONObject: value))
        XCTAssertNil(old.earnedMass)
        value["earnedMass"] = 12_345.6
        let current = try JSONDecoder().decode(ArenaPlayer.self, from: JSONSerialization.data(withJSONObject: value))
        XCTAssertEqual(current.earnedMass, 12_345.6)
    }
}
