import XCTest
@testable import LittleDill

final class ArcadeCircuitTests: XCTestCase {
    private let start = ISO8601DateFormatter().date(from: "2026-09-25T12:00:00Z")!

    private func defaults() -> UserDefaults {
        let name = "test.dill.circuit.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func living(at date: Date) -> PetState {
        var pet = PetState(now: date)
        pet.life.phase = .living
        pet.life.name = "Dilly"
        pet.life.bornAt = PetLife.ms(date)
        pet.life.hatchAt = PetLife.ms(date)
        pet.life.brinedAt = PetLife.ms(date) - PetLife.HATCH_MS
        return pet
    }

    @MainActor private func store(_ defaults: UserDefaults, _ clock: TestClock) -> DillStore {
        defaults.set(try! JSONEncoder().encode(living(at: clock.now)), forKey: "little-dill.native.v1")
        return DillStore(defaults: defaults, clock: { clock.now })
    }

    func testSeedsDependOnUTCDayAndGame() {
        let day = "2026-09-25"
        for game in ArcadeCircuit.games {
            XCTAssertEqual(ArcadeCircuit.seed(day: day, game: game), ArcadeCircuit.seed(day: day, game: game))
            XCTAssertNotEqual(ArcadeCircuit.seed(day: day, game: game), ArcadeCircuit.seed(day: "2026-09-26", game: game))
        }
        XCTAssertEqual(Set(ArcadeCircuit.games.map { ArcadeCircuit.seed(day: day, game: $0) }).count, 3)
        XCTAssertEqual(DailyChallenge.today(ISO8601DateFormatter().date(from: "2026-09-26T00:00:00Z")!), "2026-09-26")
    }

    func testPointsMedalsAndClamping() throws {
        var circuit = ArcadeCircuit(day: "2026-09-25")
        XCTAssertEqual(ArcadeCircuit.points(game: .hop, score: 6), 50)
        XCTAssertEqual(ArcadeCircuit.points(game: .chop, score: 15), 50)
        XCTAssertEqual(ArcadeCircuit.points(game: .toss, score: 4), 50)
        XCTAssertEqual(ArcadeCircuit.points(game: .hop, score: -8), 0)
        XCTAssertEqual(ArcadeCircuit.points(game: .hop, score: Int.max), 100)
        circuit.record(game: .hop, score: 12)
        XCTAssertNil(circuit.medal)
        XCTAssertEqual(circuit.nextGame, .chop)
        circuit.record(game: .chop, score: 30)
        circuit.record(game: .toss, score: 8)
        XCTAssertTrue(circuit.completed)
        XCTAssertEqual(circuit.total, 300)
        XCTAssertEqual(circuit.medal, "Gold")
        circuit.record(game: .hop, score: 1)
        XCTAssertEqual(circuit.scores["hop"], 12)
        XCTAssertEqual(ArcadeCircuit(day: circuit.day, scores: ["hop": -3, "chop": Int.max, "hunt": 5]).scores,
                       ["hop": 0, "chop": ArcadeCircuit.maxRawScore])
        let bronze = ArcadeCircuit(day: circuit.day, scores: ["hop": 12, "chop": 0, "toss": 0])
        XCTAssertEqual(bronze.medal, "Bronze")
        XCTAssertEqual(ArcadeCircuit(day: circuit.day, scores: ["hop": 12, "chop": 24, "toss": 0]).medal, "Silver")
        XCTAssertNil(ArcadeCircuit(day: circuit.day, scores: ["hop": 0, "chop": 0, "toss": 0]).medal)
        let decoded = try JSONDecoder().decode(ArcadeCircuit.self, from: Data("{\"day\":\"2026-09-25\",\"scores\":{\"hop\":-2,\"toss\":999999,\"hunt\":4}}".utf8))
        XCTAssertEqual(decoded.scores, ["hop": 0, "toss": ArcadeCircuit.maxRawScore])
    }

    @MainActor func testCompletionPersistsAndDoesNotAddCircuitReward() throws {
        let clock = TestClock(start), defaults = defaults(), first = store(defaults, clock)
        for (game, score) in [(ArcadeGame.hop, 12), (.chop, 30), (.toss, 0)] {
            XCTAssertEqual(first.startCircuit(game: game), "2026-09-25")
            first.finishArcade(game: game.rawValue, score: score, completed: true)
        }
        XCTAssertEqual(first.pet.arcadeCircuit?.scores, ["hop": 12, "chop": 30, "toss": 0])
        XCTAssertEqual(first.pet.arcadeCircuit?.total, 200)
        XCTAssertEqual(first.pet.arcadeCircuit?.medal, "Silver")
        XCTAssertEqual(first.pet.life.energy, 72)
        let reopened = DillStore(defaults: defaults, clock: { clock.now })
        XCTAssertEqual(reopened.circuitToday, first.pet.arcadeCircuit)
    }

    @MainActor func testAbandonAndDuplicateFinishDoNotCount() {
        let clock = TestClock(start), first = store(defaults(), clock)
        XCTAssertNil(first.startCircuit(game: .hunt))
        XCTAssertNil(first.pet.arcadeCircuit)
        XCTAssertEqual(first.startCircuit(game: .hop), "2026-09-25")
        first.finishArcade(game: "hop", score: 12, completed: false)
        XCTAssertNil(first.pet.arcadeCircuit)
        XCTAssertEqual(first.finishArcade(game: "hop", score: 12, completed: true), 0)
        XCTAssertEqual(first.startCircuit(game: .hop), "2026-09-25")
        first.finishArcade(game: "toss", score: 8, completed: true)
        XCTAssertNil(first.pet.arcadeCircuit)
        XCTAssertEqual(first.startCircuit(game: .hop), "2026-09-25")
        first.finishArcade(game: "hop", score: 0, completed: true)
        XCTAssertEqual(first.pet.arcadeCircuit?.scores["hop"], 0)
        XCTAssertEqual(first.finishArcade(game: "hop", score: 12, completed: true), 0)
        XCTAssertEqual(first.pet.arcadeCircuit?.scores["hop"], 0)
    }

    @MainActor func testMidnightCreditsStartDayAndOlderResultKeepsNewerDay() {
        let clock = TestClock(ISO8601DateFormatter().date(from: "2026-09-25T23:59:50Z")!)
        let first = store(defaults(), clock)
        XCTAssertEqual(first.startCircuit(game: .hop), "2026-09-25")
        clock.advance(20)
        first.finishArcade(game: "hop", score: 12, completed: true)
        XCTAssertEqual(first.pet.arcadeCircuit?.day, "2026-09-25")
        XCTAssertEqual(first.startCircuit(game: .toss), "2026-09-26")
        first.finishArcade(game: "toss", score: 8, completed: true)
        XCTAssertEqual(first.circuitToday.scores, ["toss": 8])
        clock.advance(-30)
        XCTAssertEqual(first.startCircuit(game: .chop), "2026-09-25")
        first.finishArcade(game: "chop", score: 30, completed: true)
        XCTAssertEqual(first.pet.arcadeCircuit?.day, "2026-09-26")
        XCTAssertEqual(first.pet.arcadeCircuit?.scores, ["toss": 8])
    }

    func testOldSaveAndNativeBackupRoundTrip() throws {
        var pet = living(at: start)
        pet.arcadeCircuit = ArcadeCircuit(day: "2026-09-25", scores: ["hop": 12, "toss": 0])
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(pet)) as? [String: Any])
        old.removeValue(forKey: "arcadeCircuit")
        XCTAssertNil(try JSONDecoder().decode(PetState.self, from: JSONSerialization.data(withJSONObject: old)).arcadeCircuit)
        let file = try DillBackup.encode(pet: pet.life, native: pet.native, savedAt: PetLife.ms(start))
        let restored = try XCTUnwrap(DillBackup.decode(file).native)
        XCTAssertEqual(restored.arcadeCircuit, pet.arcadeCircuit)
        var imported = living(at: start)
        imported.apply(restored)
        XCTAssertEqual(imported.arcadeCircuit, pet.arcadeCircuit)
        let corrupt = try JSONDecoder().decode(DillBackup.Native.self, from: Data("{\"arcadeCircuit\":{\"day\":\"invalid\",\"scores\":{\"hop\":12}}}".utf8))
        XCTAssertNil(corrupt.arcadeCircuit)
    }
}
