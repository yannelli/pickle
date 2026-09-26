import Foundation
import SwiftUI

// Pet rules come from PetLife.swift (the web game's pet-life.js). The online arena runs its own authoritative server simulation.
enum Brine: String, Codable, CaseIterable, Identifiable {
    case classic, garlic, spicy
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self { case .classic: return "Sweet little soul"; case .garlic: return "A little extra"; case .spicy: return "Tiny chaos agent" }
    }
    var color: Color {
        switch self { case .classic: return Color(hex: 0x91B65A); case .garlic: return Color(hex: 0xB7BB70); case .spicy: return Color(hex: 0xD6A05B) }
    }
    var varieties: [PickleVariety] { PickleVariety.all.filter { $0.brine == rawValue } }
}

enum Outfit: String, Codable, CaseIterable, Identifiable {
    case original, sprout, bow, shades, crown, party
    case beanie, beret, headphones, sunhat, chef, cowboy
    case pirate, mushroom, wizard, rainhat, halo, helmet
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Au naturel"
        case .sprout: return "Plant parent"
        case .bow: return "Sweet thing"
        case .shades: return "Off duty"
        case .crown: return "Big dill"
        case .party: return "Party pickle"
        case .beanie: return "Cozy knit"
        case .beret: return "Art house"
        case .headphones: return "In my zone"
        case .sunhat: return "Sunny side"
        case .chef: return "Little chef"
        case .cowboy: return "Wild west"
        case .pirate: return "Captain crunch"
        case .mushroom: return "Forest friend"
        case .wizard: return "Spellbound"
        case .rainhat: return "Rainy day"
        case .halo: return "Sweet angel"
        case .helmet: return "Space cadet"
        }
    }
    var symbol: String {
        switch self {
        case .original: return "heart"
        case .sprout: return "leaf.fill"
        case .bow: return "gift.fill"
        case .shades: return "sunglasses.fill"
        case .crown: return "crown.fill"
        case .party: return "party.popper.fill"
        case .beanie: return "snowflake"
        case .beret: return "paintpalette.fill"
        case .headphones: return "headphones"
        case .sunhat: return "sun.max.fill"
        case .chef: return "fork.knife"
        case .cowboy: return "star.fill"
        case .pirate: return "sailboat.fill"
        case .mushroom: return "leaf.circle.fill"
        case .wizard: return "sparkles"
        case .rainhat: return "cloud.rain.fill"
        case .halo: return "circle.dashed"
        case .helmet: return "moon.stars.fill"
        }
    }
    var cost: Int {
        switch self {
        case .original, .sprout: return 0
        case .bow: return 30
        case .shades: return 50
        case .crown: return 90
        case .party: return 120
        case .beanie: return 35
        case .beret: return 45
        case .headphones: return 55
        case .sunhat: return 60
        case .chef: return 65
        case .cowboy: return 80
        case .pirate: return 90
        case .mushroom: return 95
        case .wizard: return 110
        case .rainhat: return 70
        case .halo: return 130
        case .helmet: return 140
        }
    }
}

enum Care: String, CaseIterable, Identifiable {
    case feed, pet, wash, nap
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self { case .feed: return "carrot.fill"; case .pet: return "hand.wave.fill"; case .wash: return "drop.fill"; case .nap: return "moon.stars.fill" }
    }
    var message: String {
        switch self { case .feed: return "A snack? For moi?"; case .pet: return "emotionally attached? same."; case .wash: return "Fresh out of the brine."; case .nap: return "Five more minutes, please." }
    }
}

struct CareResult: Equatable {
    var applied: Bool
    var coins: Int
    var message: String
}

struct ScoreEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var day: String
    var score: Int
    var date: Date
}

struct PetState: Codable {
    static let arcadeGames = ["hunt", "memory", "catch", "hop", "chop", "toss"]
    static let nowKey = CodingUserInfoKey(rawValue: "little-dill.now")!
    static let maxCoins = 1_000_000
    static let maxStreak = 100_000
    var version = 2
    var life: WebPet
    var outfit: Outfit = .sprout
    var coins = 20
    var unlocked: Set<Outfit> = [.original, .sprout]
    var careDay = ""
    var dailyCare: Set<String> = []
    var streak = 0
    var lastVisitDay = ""
    var scores: [ScoreEntry] = []
    var rewardedDays: Set<String> = []
    var haptics = true
    var soundEnabled: Bool?
    var arenaBest: Int?
    var arenaEarnings: ArenaEarnings?
    var arcadeRecords: [String: Int] = [:]
    var arcadeCircuit: ArcadeCircuit?
    var lastPetAt: Int64?

    init(now: Date = Date()) { life = PetLife.fresh(now: PetLife.ms(now)) }

    var sounds: Bool { soundEnabled ?? true }
    var adopted: Bool { life.phase == .living }
    var brine: Brine { Brine(rawValue: life.brine) ?? .classic }
    var name: String { life.name }
    var variety: PickleVariety { PickleVariety.of(life.variety) }
    var food: Double { life.fullness }
    var joy: Double { life.happiness }
    var clean: Double { life.hygiene }
    var energy: Double { life.energy }
    var birthday: Date { PetLife.date(life.bornAt) }
    func stage(at now: Date = Date()) -> LifeStage { PetLife.stage(life, now: PetLife.ms(now)) }
    func teen(at now: Date = Date()) -> TeenLook? { PetLife.teen(life, now: PetLife.ms(now)) }
    func elder(at now: Date = Date()) -> ElderLook? { PetLife.elder(life, now: PetLife.ms(now)) }
    func ageDays(at now: Date = Date()) -> Int { Int(PetLife.age(life, now: PetLife.ms(now)) / PetLife.DAY) }
    func nextCareAt(after now: Date = Date()) -> Date { Date(timeIntervalSince1970: PetLife.nextCareAt(life, now: PetLife.ms(now)) / 1000) }

    private enum CodingKeys: String, CodingKey {
        case version, life, outfit, coins, unlocked, careDay, dailyCare, streak, lastVisitDay, scores, rewardedDays, haptics, soundEnabled, arenaBest, arenaEarnings, arcadeRecords, arcadeCircuit
        case name, brine, adopted, birthday, food, joy, clean, energy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        outfit = try c.decode(Outfit.self, forKey: .outfit)
        coins = try c.decode(Int.self, forKey: .coins)
        unlocked = try c.decode(Set<Outfit>.self, forKey: .unlocked)
        careDay = try c.decode(String.self, forKey: .careDay)
        dailyCare = try c.decode(Set<String>.self, forKey: .dailyCare)
        streak = try c.decode(Int.self, forKey: .streak)
        lastVisitDay = try c.decode(String.self, forKey: .lastVisitDay)
        scores = try c.decode([ScoreEntry].self, forKey: .scores)
        rewardedDays = try c.decode(Set<String>.self, forKey: .rewardedDays)
        haptics = try c.decode(Bool.self, forKey: .haptics)
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled)
        arenaBest = try c.decodeIfPresent(Int.self, forKey: .arenaBest)
        arenaEarnings = try? c.decodeIfPresent(ArenaEarnings.self, forKey: .arenaEarnings)
        arcadeRecords = try c.decodeIfPresent([String: Int].self, forKey: .arcadeRecords) ?? [:]
        arcadeCircuit = try? c.decodeIfPresent(ArcadeCircuit.self, forKey: .arcadeCircuit)
        switch version {
        case 2: life = try c.decode(WebPet.self, forKey: .life)
        case 1:
            // Native v1 saves keep their pickle and restart the care clock at the moment of migration.
            let now = PetLife.ms(decoder.userInfo[Self.nowKey] as? Date ?? Date())
            life = PetLife.fresh(now: now)
            version = 2
            guard try c.decode(Bool.self, forKey: .adopted) else { return }
            let brine = try c.decode(Brine.self, forKey: .brine)
            let bornAt = min(now, max(0, PetLife.ms(try c.decode(Date.self, forKey: .birthday))))
            life.phase = .living
            life.name = Self.migratedName(try c.decode(String.self, forKey: .name))
            life.brine = brine.rawValue
            life.variety = PickleVariety.first(brine: brine.rawValue).id
            life.fullness = try c.decode(Double.self, forKey: .food)
            life.happiness = try c.decode(Double.self, forKey: .joy)
            life.hygiene = try c.decode(Double.self, forKey: .clean)
            life.energy = try c.decode(Double.self, forKey: .energy)
            life.bornAt = bornAt; life.hatchAt = bornAt; life.brinedAt = max(0, bornAt - PetLife.HATCH_MS)
        default: throw DecodingError.dataCorruptedError(forKey: .version, in: c, debugDescription: "Unknown save version")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(life, forKey: .life)
        try c.encode(outfit, forKey: .outfit)
        try c.encode(coins, forKey: .coins)
        try c.encode(unlocked, forKey: .unlocked)
        try c.encode(careDay, forKey: .careDay)
        try c.encode(dailyCare, forKey: .dailyCare)
        try c.encode(streak, forKey: .streak)
        try c.encode(lastVisitDay, forKey: .lastVisitDay)
        try c.encode(scores, forKey: .scores)
        try c.encode(rewardedDays, forKey: .rewardedDays)
        try c.encode(haptics, forKey: .haptics)
        try c.encodeIfPresent(soundEnabled, forKey: .soundEnabled)
        try c.encodeIfPresent(arenaBest, forKey: .arenaBest)
        try c.encodeIfPresent(arenaEarnings, forKey: .arenaEarnings)
        try c.encode(arcadeRecords, forKey: .arcadeRecords)
        try c.encodeIfPresent(arcadeCircuit, forKey: .arcadeCircuit)
    }

    static func migratedName(_ name: String) -> String {
        let visible = String(String.UnicodeScalarView(name.unicodeScalars.filter { !PetLife.hasControl(String($0)) }))
        let collapsed = PetLife.cleanName(visible) ?? PetLife.trim(visible)
        return PetLife.cleanName(String(String.UnicodeScalarView(collapsed.unicodeScalars.prefix(24)))) ?? name
    }

    static var localCalendar: Calendar { var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current; return calendar }

    static func dayKey(_ date: Date, calendar: Calendar = PetState.localCalendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    mutating func refresh(at now: Date, calendar: Calendar = PetState.localCalendar) {
        PetLife.advance(&life, now: PetLife.ms(now))
        let day = Self.dayKey(now, calendar: calendar)
        if careDay < day { careDay = day; dailyCare = [] }
        guard adopted, lastVisitDay != day, day > lastVisitDay else { return }
        let yesterday = Self.dayKey(calendar.date(byAdding: .day, value: -1, to: now) ?? now, calendar: calendar)
        streak = lastVisitDay == yesterday ? min(streak, Self.maxStreak - 1) + 1 : 1
        lastVisitDay = day
    }

    private mutating func addHappy(_ amount: Double) -> Int {
        let before = life.happiness
        life.happiness = PetLife.clamp(before + amount)
        return Int((life.happiness - before).rounded(.toNearestOrAwayFromZero))
    }

    private mutating func reward(_ action: Care) -> Int {
        addCoins(dailyCare.insert(action.rawValue).inserted ? 5 : 0)
    }

    private mutating func addCoins(_ amount: Int) -> Int {
        let before = coins
        coins = min(Self.maxCoins, coins + amount)
        return coins - before
    }

    private var restingMessage: String {
        life.dead ? (life.eaten == true ? "you ate \(life.name). it was delicious. you monster." : "a good dill. gone, but not forgotten.") : ""
    }

    // Mirrors the web care(), petPickle() and toggleSleep() handlers. Wash follows the web Clean rules.
    @discardableResult mutating func care(_ action: Care, at now: Date = Date()) -> CareResult {
        if action == .nap { return toggleSleep(at: now) }
        refresh(at: now)
        guard life.phase == .living, !life.dead else { return CareResult(applied: false, coins: 0, message: restingMessage) }
        if life.sleeping {
            if action == .pet { return setSleeping(false, at: now, rewarding: .pet) }
            return CareResult(applied: false, coins: 0, message: "zzZ... use Wake to rise & brine.")
        }
        let ms = PetLife.ms(now)
        var applied = true, message = ""
        switch action {
        case .feed:
            if life.fullness >= 99 { applied = false; message = "full to the brim. try a little pet!" }
            else {
                let added = min(40, 100 - life.fullness)
                life.fullness = PetLife.clamp(life.fullness + 40)
                message = "finest brine. +\(Int(added.rounded(.toNearestOrAwayFromZero))) food, +\(addHappy(3)) happy."
            }
        case .pet:
            if let last = lastPetAt, ms - last < 2000 { return CareResult(applied: false, coins: 0, message: "so loved. another pet in a moment. ♥") }
            lastPetAt = ms
            let added = addHappy(8)
            message = added > 0 ? "+\(added) happy. you’re my favorite human." : "100% happy. maximum pickle joy!"
        case .wash:
            if life.hygiene >= 99 { applied = false; message = "already sparkling. how about a game?" }
            else { life.hygiene = 100; message = "a sudsy little bath. +\(addHappy(4)) happy, too." }
        case .nap: break
        }
        PetLife.assess(&life)
        life.lastCareAt = ms
        return CareResult(applied: applied, coins: applied ? reward(action) : 0, message: message)
    }

    @discardableResult mutating func toggleSleep(at now: Date = Date()) -> CareResult { setSleeping(!life.sleeping, at: now) }

    @discardableResult mutating func setSleeping(_ sleeping: Bool, at now: Date = Date(), rewarding action: Care = .nap) -> CareResult {
        refresh(at: now)
        guard life.phase == .living, !life.dead else { return CareResult(applied: false, coins: 0, message: restingMessage) }
        life.sleeping = sleeping
        life.lastCareAt = PetLife.ms(now)
        return CareResult(applied: true, coins: reward(action), message: sleeping ? "night night. don’t let the dill bugs bite." : "rise & brine, sleepyhead.")
    }

    mutating func prepareArcade(at now: Date = Date()) -> Bool {
        refresh(at: now)
        guard life.phase == .living, !life.dead else { return false }
        if life.sleeping {
            life.sleeping = false
            life.lastCareAt = PetLife.ms(now)
        }
        return true
    }

    mutating func startArcade(at now: Date = Date()) -> Bool {
        guard prepareArcade(at: now), life.energy >= 6 else { return false }
        life.energy = PetLife.clamp(life.energy - 6)
        return true
    }

    @discardableResult mutating func recordArena(earnedMass: Double, session: String, at now: Date = Date()) -> Int {
        var progress = arenaEarnings ?? ArenaEarnings()
        let earned = progress.record(session: session, earnedMass: earnedMass, day: DailyChallenge.today(now))
        arenaEarnings = progress
        return addCoins(earned)
    }

    // Web rewards: hunt 10 + 8 per heart, memory 10 + 4 per level (34 for all five), catch 10 + 2 per point up to 34.
    // iOS only: hop and toss 10 + 2 per point, chop 10 + 1 per two cukes, each up to 34.
    static func arcadeReward(game: String, score: Int) -> Int {
        let score = max(0, score)
        switch game {
        case "hunt": return 10 + min(3, score) * 8
        case "memory": return score >= 5 ? 34 : 10 + score * 4
        case "catch", "hop", "toss": return 10 + min(24, score * 2)
        case "chop": return 10 + min(24, score / 2)
        default: return 0
        }
    }

    mutating func finishArcade(game: String, score: Int, completed: Bool, at now: Date = Date()) -> Int {
        refresh(at: now)
        guard completed, Self.arcadeGames.contains(game), life.phase == .living, !life.dead else { return 0 }
        let added = addHappy(Double(Self.arcadeReward(game: game, score: score)))
        arcadeRecords[game] = max(arcadeRecords[game] ?? 0, max(0, score))
        PetLife.assess(&life)
        life.lastCareAt = PetLife.ms(now)
        return added
    }

    @discardableResult mutating func record(score: Int, day: String, at now: Date = Date()) -> Int {
        guard (0...300).contains(score), DailyChallenge.validDay(day) else { return 0 }
        if let i = scores.firstIndex(where: { $0.day == day }) {
            if score > scores[i].score { scores[i].score = score; scores[i].date = now }
        } else { scores.append(ScoreEntry(day: day, score: score, date: now)) }
        scores = Array(scores.sorted { $0.day > $1.day }.prefix(90))
        // Replays improve a best score. Only today's challenge earns a daily reward.
        let reward = addCoins(day == DailyChallenge.today(now) && rewardedDays.insert(day).inserted ? 25 : 0)
        rewardedDays = Set(rewardedDays.sorted().suffix(120))
        refresh(at: now)
        if adopted && !life.dead { _ = addHappy(12); PetLife.assess(&life) }
        return reward
    }

    mutating func equip(_ outfit: Outfit) -> Bool {
        if !unlocked.contains(outfit) {
            guard coins >= outfit.cost else { return false }
            coins -= outfit.cost
            unlocked.insert(outfit)
        }
        self.outfit = outfit
        return true
    }

    var native: DillBackup.Native {
        var native = progress
        native.rewardedDays = Array(native.rewardedDays.suffix(30))
        native.scores = Array(native.scores.prefix(20))
        return native
    }

    private var progress: DillBackup.Native {
        DillBackup.Native(coins: coins, outfit: outfit.rawValue, unlocked: Outfit.allCases.filter { unlocked.contains($0) }.map(\.rawValue),
                          streak: streak, lastVisitDay: lastVisitDay, careDay: careDay, dailyCare: dailyCare.sorted(),
                          rewardedDays: rewardedDays.sorted(),
                          scores: scores.sorted { $0.day > $1.day }.map { DillBackup.Score(d: $0.day, s: $0.score, t: PetLife.ms($0.date)) },
                          arenaBest: arenaBest, arenaEarnings: arenaEarnings, arcade: arcadeRecords, arcadeCircuit: arcadeCircuit, haptics: haptics, sounds: soundEnabled)
    }

    /// Runs a save that decoded but failed `isValid` through the backup import clamps.
    /// Returns false when the pickle itself was invalid and became a new egg; coins, outfits and scores stay either way.
    @discardableResult mutating func repair(now: Date) -> Bool {
        apply(progress)
        guard (try? PetLife.validate(life)) == nil else { return true }
        life = PetLife.fresh(now: PetLife.ms(now)); lastPetAt = nil
        return false
    }

    mutating func apply(_ native: DillBackup.Native) {
        coins = min(Self.maxCoins, max(0, native.coins))
        unlocked = Set(native.unlocked.compactMap(Outfit.init(rawValue:))).union([.original, .sprout])
        outfit = Outfit(rawValue: native.outfit).flatMap { unlocked.contains($0) ? $0 : nil } ?? .sprout
        streak = min(Self.maxStreak, max(0, native.streak))
        lastVisitDay = DailyChallenge.validDay(native.lastVisitDay) ? native.lastVisitDay : ""
        careDay = DailyChallenge.validDay(native.careDay) ? native.careDay : ""
        dailyCare = Set(native.dailyCare.filter { Care(rawValue: $0) != nil })
        rewardedDays = Set(native.rewardedDays.filter(DailyChallenge.validDay))
        var best: [String: DillBackup.Score] = [:]
        for score in native.scores where (0...300).contains(score.s) && DailyChallenge.validDay(score.d) && PetLife.isTimestamp(score.t) {
            if score.s > best[score.d]?.s ?? -1 { best[score.d] = score }
        }
        scores = Array(best.values.sorted { $0.d > $1.d }.prefix(90).map { ScoreEntry(day: $0.d, score: $0.s, date: PetLife.date($0.t)) })
        arenaBest = native.arenaBest.map { max(0, $0) }
        arenaEarnings = native.arenaEarnings?.normalized()
        arcadeRecords = native.arcade.filter { Self.arcadeGames.contains($0.key) && $0.value >= 0 }
        arcadeCircuit = native.arcadeCircuit.flatMap {
            DailyChallenge.validDay($0.day) ? ArcadeCircuit(day: $0.day, scores: $0.scores) : nil
        }
        haptics = native.haptics
        soundEnabled = native.sounds
    }

    var isValid: Bool {
        version == 2 && (try? PetLife.validate(life)) != nil &&
        (0...Self.maxCoins).contains(coins) && (0...Self.maxStreak).contains(streak) && unlocked.contains(outfit) &&
        scores.count <= 90 && scores.allSatisfy { (0...300).contains($0.score) && DailyChallenge.validDay($0.day) } &&
        arcadeRecords.allSatisfy { Self.arcadeGames.contains($0.key) && $0.value >= 0 } &&
        arcadeCircuit.map { DailyChallenge.validDay($0.day) } ?? true
    }
}

struct DailyChallenge: Equatable {
    let day: String
    var seed: UInt64 { day.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) } }
    var number: Int { Int(seed % 900) + 100 }
    static func today(_ now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return PetState.dayKey(now, calendar: calendar)
    }
    static func validDay(_ day: String) -> Bool {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        f.isLenient = false
        guard day.count == 10, let date = f.date(from: day) else { return false }
        return f.string(from: date) == day && day >= "2026-01-01" && day <= "2099-12-31"
    }
    func target(round: Int) -> Double { 0.25 + Double((seed &+ UInt64(max(0, round)) &* 127) % 501) / 1000 }
    static func position(elapsed: Double, round: Int) -> Double {
        let period = max(1.35, 2.35 - Double(round) * 0.3)
        let phase = max(0, elapsed).truncatingRemainder(dividingBy: period) / period
        return phase <= 0.5 ? phase * 2 : (1 - phase) * 2
    }
    static func points(position: Double, target: Double) -> Int {
        guard position.isFinite, target.isFinite else { return 0 }
        return max(0, min(100, Int((100 - abs(position - target) * 230).rounded())))
    }
    var url: URL { URL(string: "littledill://challenge/\(day)")! }
    static func from(_ url: URL) -> DailyChallenge? {
        guard url.scheme == "littledill", url.host == "challenge" else { return nil }
        let day = url.lastPathComponent
        return validDay(day) ? DailyChallenge(day: day) : nil
    }
}
