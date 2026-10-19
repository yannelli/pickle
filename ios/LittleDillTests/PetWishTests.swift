import XCTest
@testable import LittleDill

final class PetWishTests: XCTestCase {
    private let t0 = ISO8601DateFormatter().date(from: "2026-09-17T12:00:00Z")!
    private var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private func ms(_ date: Date) -> Int64 { PetLife.ms(date) }
    private func living(at now: Date, variety: String = "garlic") -> PetState {
        var p = PetState(now: now)
        p.life.phase = .living; p.life.name = "Wishful"; p.life.variety = variety; p.life.brine = PickleVariety.of(variety).brine
        p.life.bornAt = ms(now) - 3 * PetLife.DAY; p.life.hatchAt = p.life.bornAt; p.life.brinedAt = p.life.bornAt - PetLife.HATCH_MS
        return p
    }
    private func wish(_ kind: String, _ target: String = "", at now: Date) -> PetWish {
        PetWish(kind: kind, target: target, issuedAt: ms(now), expiresAt: ms(now) + PetLife.WISH_MS)
    }

    func testNativeRulesMatchTheSharedPetFixture() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "pet-parity", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(PickleVariety.all.map(\.id).sorted(), fixture.favorites.keys.sorted())
        for (variety, favorite) in fixture.favorites {
            XCTAssertEqual(PetLife.favorite(variety).food, favorite.food, variety)
            XCTAssertEqual(PetLife.favorite(variety).game, favorite.game, variety)
        }
        XCTAssertEqual(PetLife.FAVORITE_BONUS, fixture.favoriteBonus)
        XCTAssertEqual(PetLife.FOODS, fixture.foods); XCTAssertEqual(FeedFood.allCases.map(\.rawValue), fixture.foods)
        XCTAssertEqual(PetLife.FOOD_NAMES, fixture.foodNames); XCTAssertEqual(FeedFood.allCases.map(\.name), fixture.foods.map { fixture.foodNames[$0]! })
        XCTAssertEqual(PetLife.GAMES, fixture.games); XCTAssertEqual(PetLife.GAME_NAMES, fixture.gameNames)
        XCTAssertEqual(PetLife.WISH_KINDS, fixture.wish.kinds); XCTAssertEqual(PetLife.WISH_MS, fixture.wish.ms)
        XCTAssertEqual(PetLife.WISHES_PER_DAY, fixture.wish.perDay); XCTAssertEqual(PetLife.WISH_HAPPINESS, fixture.wish.happiness)
        XCTAssertEqual(PetLife.WISH_COINS, fixture.wish.coins); XCTAssertEqual(PetLife.WISH_HOURS, fixture.wish.hours)
        XCTAssertEqual(PetLife.QUIET_HOUR, fixture.wish.quietHour)
        XCTAssertEqual(PetLife.MOMENTS, fixture.moments); XCTAssertEqual(PetLife.STREAK_STICKERS, fixture.streakStickers)
        XCTAssertEqual(PetLife.MAX_STREAK, fixture.maxStreak); XCTAssertEqual(PetState.maxStreak, fixture.maxStreak)
        for row in fixture.wishTexts { XCTAssertEqual(PetLife.wishText(row.wish), row.text) }
        for row in fixture.rolls {
            var pet = PetLife.fresh(now: row.now)
            pet.phase = .living; pet.name = "Parity"; pet.bornAt = row.pet.bornAt; pet.hygiene = row.pet.hygiene; pet.energy = row.pet.energy
            pet.sleeping = row.pet.sleeping; pet.dead = row.pet.dead; pet.diedAt = row.pet.dead ? row.now : 0
            pet.wish = row.pet.wish; pet.wishes = row.pet.wishes
            PetLife.rollWish(&pet, now: row.now, day: row.day, hour: row.hour, food: row.food)
            XCTAssertEqual(pet.wish, row.wish, row.name); XCTAssertEqual(pet.wishes, row.wishes, row.name)
        }
        for row in fixture.scrapbook {
            var pet = PetLife.fresh(now: row.pet.bornAt)
            pet.phase = .living; pet.name = "Parity"; pet.bornAt = row.pet.bornAt; pet.hatchAt = row.pet.hatchAt
            pet.dead = row.pet.dead; pet.diedAt = row.pet.diedAt; pet.events = row.pet.events
            let page = PetLife.scrapbook(pet, now: row.now, streak: row.streak)
            XCTAssertEqual(page.moments.map(\.id), row.moments.map(\.id), row.name)
            XCTAssertEqual(page.moments.map(\.at), row.moments.map(\.at), row.name)
            XCTAssertEqual(page.unlocked, row.unlocked, row.name)
            XCTAssertEqual(page.stickers.filter(\.earned).map(\.days), row.stickers, row.name)
            XCTAssertEqual(page.album.filter(\.unlocked).map(\.id), row.album.map { $0[0].string ?? "" }, row.name)
            XCTAssertEqual(page.album.filter(\.unlocked).map(\.at), row.album.map { $0[1].safeInteger ?? -1 }, row.name)
        }
        for row in fixture.visits {
            var streak = row.streak, last = row.lastVisitDay
            XCTAssertEqual(PetLife.visit(streak: &streak, lastVisitDay: &last, day: row.day, yesterday: row.yesterday), row.changed, row.name)
            XCTAssertEqual(streak, row.after.streak, row.name); XCTAssertEqual(last, row.after.lastVisitDay, row.name)
        }
    }

    func testRollWaitsForAwakeDaytimeAndCapsAtTwoADay() {
        let morning = utc.date(byAdding: .hour, value: -4, to: t0)!
        var p = living(at: morning)
        p.rollWish(at: morning, calendar: utc, food: "apple"); XCTAssertNil(p.life.wish, "8am is quiet")
        p.life.sleeping = true; p.rollWish(at: t0, calendar: utc, food: "apple"); XCTAssertNil(p.life.wish)
        p.life.sleeping = false; p.rollWish(at: t0, calendar: utc, food: "apple")
        let first = try? XCTUnwrap(p.life.wish)
        XCTAssertEqual(p.life.wishes, WishLog(day: "2026-09-17", count: 1))
        p.rollWish(at: t0.addingTimeInterval(4 * 3600), calendar: utc, food: "apple"); XCTAssertEqual(p.life.wish, first, "one wish at a time")
        p.rollWish(at: t0.addingTimeInterval(6 * 3600), calendar: utc, food: "apple")
        XCTAssertEqual(p.life.wishes?.count, 2, "the expired wish clears and the 3pm slot opens")
        p.life.wish = nil
        p.rollWish(at: t0.addingTimeInterval(8 * 3600), calendar: utc, food: "apple"); XCTAssertNil(p.life.wish, "two a day")
        p.rollWish(at: t0.addingTimeInterval(11 * 3600), calendar: utc, food: "apple"); XCTAssertNil(p.life.wish, "11pm is quiet")
        p.rollWish(at: t0.addingTimeInterval(24 * 3600), calendar: utc, food: "apple"); XCTAssertEqual(p.life.wishes?.count, 1)
    }

    func testFeedWishSurvivesRefusedFeedAndGrantsHappinessAndCoins() {
        var p = living(at: t0)
        p.life.fullness = 99.5; p.life.happiness = 40; p.life.wish = wish("feed", "carrot", at: t0)
        XCTAssertEqual(p.care(.feed, at: t0, food: "carrot").applied, false)
        XCTAssertNotNil(p.life.wish, "a refused feed keeps the wish")
        let later = t0.addingTimeInterval(3600), coins = p.coins
        let result = p.care(.feed, at: later, food: "carrot")
        XCTAssertEqual(result, CareResult(applied: true, coins: 10, message: "finest brine. +2 food, +3 happy. wish granted! +10 happy.", wish: true))
        XCTAssertEqual(p.coins, coins + 10); XCTAssertNil(p.life.wish)
        XCTAssertEqual(p.life.happiness, 52, accuracy: 1e-9); XCTAssertEqual(p.life.events?.wish, ms(later))
        XCTAssertEqual(p.care(.pet, at: later).message, "+8 happy. you’re my favorite human.", "no wish, no bonus")
    }

    func testCleanPetAndNapWishesGrantOnTheirCare() {
        var p = living(at: t0)
        p.life.hygiene = 50; p.life.wish = wish("clean", at: t0)
        XCTAssertTrue(p.care(.wash, at: t0).wish)
        p.life.wish = wish("pet", at: t0)
        XCTAssertFalse(p.care(.wash, at: t0).wish, "the wrong care leaves the wish")
        XCTAssertTrue(p.care(.pet, at: t0).wish)
        p.life.wish = wish("nap", at: t0); p.life.happiness = 50
        let nap = p.toggleSleep(at: t0)
        XCTAssertTrue(nap.wish); XCTAssertEqual(nap.coins, 10); XCTAssertTrue(nap.message.hasSuffix("wish granted! +10 happy."))
    }

    func testFavoritesAddFourHappinessForFoodAndGame() {
        var p = living(at: t0, variety: "dill")
        p.life.fullness = 10; p.life.happiness = 40
        let snack = p.care(.feed, at: t0, food: "strawberry")
        XCTAssertTrue(snack.favorite); XCTAssertEqual(snack.message, "my favorite snack! +40 food, +7 happy.")
        p.life.fullness = 10
        XCTAssertEqual(p.care(.feed, at: t0, food: "carrot").message, "finest brine. +40 food, +3 happy.")
        p.life.happiness = 40
        XCTAssertEqual(p.finishArcade(game: "catch", score: 0, completed: true, at: t0), 14)
        XCTAssertEqual(p.finishArcade(game: "hunt", score: 0, completed: true, at: t0), 10)
        XCTAssertEqual(p.life.events?.game, ms(t0))
        p.life.wish = wish("play", "memory", at: t0)
        XCTAssertEqual(p.finishArcade(game: "hunt", score: 0, completed: true, at: t0), 10, "play wishes need the named game")
        XCTAssertEqual(p.finishArcade(game: "memory", score: 0, completed: true, at: t0), 20)
        XCTAssertNil(p.life.wish)
    }

    func testSaveAndBackupRoundTripsWithAndWithoutNewFields() throws {
        var p = living(at: t0)
        p.life.wish = wish("play", "hunt", at: t0); p.life.wishes = WishLog(day: "2026-09-17", count: 1)
        p.life.events = PetEvents(game: ms(t0) - 1, wish: nil, arena: ms(t0) - 2)
        let decoded = try JSONDecoder().decode(PetState.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.life, p.life); XCTAssertTrue(decoded.isValid)
        let backup = try DillBackup.decode(DillBackup.encode(pet: p.life, native: p.native, savedAt: ms(t0)))
        XCTAssertEqual(backup.pet, .current(p.life))
        var old = living(at: t0)
        let oldJSON = try XCTUnwrap(String(data: JSONEncoder().encode(old), encoding: .utf8))
        XCTAssertFalse(oldJSON.contains("wish") || oldJSON.contains("events"))
        XCTAssertEqual(try JSONDecoder().decode(PetState.self, from: Data(oldJSON.utf8)).life, old.life)
        XCTAssertEqual(try DillBackup.decode(DillBackup.encode(pet: old.life, native: nil, savedAt: ms(t0))).pet, .current(old.life))
        old.life.wish = PetWish(kind: "dance", target: "", issuedAt: 0, expiresAt: 1)
        old.life.events = PetEvents(game: -1)
        let cleaned = try JSONDecoder().decode(PetState.self, from: JSONEncoder().encode(old))
        XCTAssertNil(cleaned.life.wish); XCTAssertNil(cleaned.life.events)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(p.life)) as? [String: Any])
        json["wish"] = ["kind": "feed", "target": "pizza", "issuedAt": 1, "expiresAt": 2]
        json["wishes"] = ["day": "2026-09-17", "count": 3]
        json["events"] = ["game": 5, "party": 6, "wish": 1.5]
        let lenient = try PetLife.validate(json: JSONValue.parse(JSONSerialization.data(withJSONObject: json)))
        XCTAssertNil(lenient.wish); XCTAssertNil(lenient.wishes); XCTAssertEqual(lenient.events, PetEvents(game: 5))
    }

    @MainActor func testStoreRollsWithTheRotationFoodAndRecordsTheFirstArenaRun() {
        let name = "test.wish.\(UUID())", defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        defaults.set(3, forKey: FeedFood.turnKey)
        var pet = living(at: t0)
        pet.life.updatedAt = ms(t0)
        defaults.set(try? JSONEncoder().encode(pet), forKey: "little-dill.native.v1")
        let store = DillStore(defaults: defaults, clock: { self.t0 })
        if let wish = store.pet.life.wish, wish.kind == "feed" { XCTAssertEqual(wish.target, "apple") }
        XCTAssertNil(store.pet.life.events?.arena)
        store.recordArena(earnedMass: 10, session: "public-1:a")
        XCTAssertEqual(store.pet.life.events?.arena, ms(t0))
        store.recordArena(earnedMass: 20, session: "public-1:a")
        XCTAssertEqual(DillStore(defaults: defaults, clock: { self.t0 }).pet.life.events?.arena, ms(t0))
    }

    private struct Fixture: Decodable {
        struct Favorite: Decodable { let food: String, game: String }
        struct Wish: Decodable { let kinds: [String]; let ms: Int64; let perDay: Int; let happiness: Double; let coins: Int; let hours: [Int]; let quietHour: Int }
        struct Text: Decodable { let wish: PetWish; let text: String }
        struct RollPet: Decodable { let bornAt: Int64; let hygiene: Double; let energy: Double; let sleeping: Bool; let dead: Bool; let wish: PetWish?; let wishes: WishLog? }
        struct Roll: Decodable { let name: String; let pet: RollPet; let now: Int64; let day: String; let hour: Int; let food: String; let wish: PetWish?; let wishes: WishLog? }
        struct PagePet: Decodable { let hatchAt: Int64; let bornAt: Int64; let dead: Bool; let diedAt: Int64; let events: PetEvents? }
        struct Moment: Decodable { let id: String; let at: Int64 }
        struct Page: Decodable { let name: String; let pet: PagePet; let now: Int64; let streak: Int; let moments: [Moment]; let unlocked: Int; let stickers: [Int]; let album: [[JSONValue]] }
        struct Record: Decodable { let streak: Int; let lastVisitDay: String }
        struct Visit: Decodable { let name: String; let streak: Int; let lastVisitDay: String; let day: String; let yesterday: String; let changed: Bool; let after: Record }
        let favorites: [String: Favorite]
        let favoriteBonus: Double
        let foods: [String], foodNames: [String: String], games: [String], gameNames: [String: String]
        let wish: Wish
        let wishTexts: [Text]
        let moments: [String: String]
        let streakStickers: [Int]
        let maxStreak: Int
        let rolls: [Roll], scrapbook: [Page], visits: [Visit]
    }
}
