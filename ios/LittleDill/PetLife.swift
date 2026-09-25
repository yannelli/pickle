import Foundation

// Swift port of ../../pet-life.js. Timestamps are integer milliseconds so saves and backups match the web game.
struct PetLifeError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
    static let invalid = PetLifeError(message: "This file contains invalid pickle progress.")
    static let unreadable = PetLifeError(message: "Unreadable pickle save.")
}

enum JSONValue: Decodable, Equatable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    static func parse(_ data: Data) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: data) }
    subscript(key: String) -> JSONValue? { if case .object(let o) = self { return o[key] }; return nil }
    var number: Double? { if case .number(let v) = self { return v }; return nil }
    var bool: Bool? { if case .bool(let v) = self { return v }; return nil }
    var string: String? { if case .string(let v) = self { return v }; return nil }
    var isObject: Bool { if case .object = self { return true }; return false }
    var safeInteger: Int64? {
        guard let v = number, v.isFinite, v == v.rounded(.towardZero), abs(v) <= 9_007_199_254_740_991 else { return nil }
        return Int64(v)
    }
}

struct PickleVariety: Equatable, Identifiable {
    enum Shape: String { case long, round, crooked }
    let id: String, name: String, brine: String
    let color: UInt32, light: UInt32, dark: UInt32
    let shape: Shape
    static let all = [
        PickleVariety(id: "dill", name: "Classic Dill", brine: "classic", color: 0x78954b, light: 0xa1b56b, dark: 0x527637, shape: .long),
        PickleVariety(id: "gherkin", name: "Tiny Gherkin", brine: "classic", color: 0x709855, light: 0xbad28c, dark: 0x486b37, shape: .round),
        PickleVariety(id: "garlic", name: "Garlic Goblin", brine: "garlic", color: 0x98a76d, light: 0xd1d99d, dark: 0x617c4c, shape: .crooked),
        PickleVariety(id: "butter", name: "Butter Bean", brine: "garlic", color: 0xb0a44d, light: 0xddce80, dark: 0x877a39, shape: .round),
        PickleVariety(id: "chili", name: "Chili Dill", brine: "spicy", color: 0x958749, light: 0xd2af73, dark: 0x6a693a, shape: .long),
        PickleVariety(id: "pepper", name: "Pepper Punk", brine: "spicy", color: 0x66875d, light: 0xa7c18a, dark: 0x415c3f, shape: .crooked)
    ]
    static func of(_ id: String) -> PickleVariety { all.first { $0.id == id } ?? all[0] }
    static func first(brine: String) -> PickleVariety { all.first { $0.brine == brine } ?? all[0] }
}

struct TeenLook: Equatable, Identifiable {
    let id: String, name: String, quip: String, hat: String, prop: String, accent: UInt32
    var day = 0
    static let all: [TeenLook] = [
        ("nerd", "Nerd", "Actually, it’s a cucurbit.", "nerdglasses", "book"),
        ("emo", "Emo", "Nobody understands brine like I do.", "fringe", "journal"),
        ("jock", "Jock", "Do you even lift, jar?", "backcap", "ball"),
        ("skater", "Skater", "Kickflip. Wipeout. Repeat.", "beanie", "skateboard"),
        ("gamer", "Gamer", "One more round. Six more rounds.", "headset", "controller"),
        ("theater", "Theater Kid", "The whole jar is a stage.", "beret", "masks"),
        ("band", "Band Kid", "This one time, at brine camp...", "shako", "trumpet"),
        ("prep", "Prep", "Early decision. Extra brine.", "mortarboard", "phone")
    ].enumerated().map { i, t in TeenLook(id: t.0, name: t.1, quip: t.2, hat: t.3, prop: t.4, accent: [0x5b6f8a, 0x3d3d47, 0x8a5b5b, 0x6f7f4a][i % 4]) }
}

struct ElderLook: Equatable, Identifiable {
    let id: String, name: String, quip: String, hat: String, prop: String, accent: UInt32
    var number = 0, unlocked = 0, lap = 0
    static let all: [ElderLook] = [
        ("grandill", "Grandill", "Back in my brine, jars were uphill both ways.", "cap", "cane"),
        ("retired-dj", "DJ Dill Senior", "Still dropping beets. Mostly by accident.", "headphones", "record"),
        ("tax-wizard", "Tax Wizard", "Claims the jar as a home office.", "wizard", "scroll"),
        ("lawn-lord", "Lawn Lord", "Get off my garnish.", "sunhat", "rake"),
        ("soup-oracle", "Soup Oracle", "Foresees a 90% chance of soup.", "turban", "bowl"),
        ("disco", "Disco Gherkin", "The knees say no. The groove says yes.", "afro", "record"),
        ("admiral", "Admiral Brine", "Has never left the bath.", "captain", "anchor"),
        ("professor", "Professor Crunch", "Tenure in advanced sitting.", "mortarboard", "book"),
        ("couch-duke", "Duke of Couch", "Rules from a very soft throne.", "crown", "mug"),
        ("pickle-cowboy", "Dill With No Name", "This jar ain’t big enough for two lids.", "cowboy", "cane"),
        ("tea-gossip", "Tea Goblin", "Spills the tea. Blames the saucer.", "bonnet", "mug"),
        ("space-grandpa", "Space Grandill", "One small step. One loud knee.", "antenna", "planet"),
        ("yoga", "Flexible in Theory", "Downward dill. Upward groan.", "headband", "flower"),
        ("pirate", "Captain Picklebeard", "The treasure was the snacks we ate.", "pirate", "anchor"),
        ("detective", "Inspector Gherkin", "The missing sock was in the jar.", "deerstalker", "lens"),
        ("influencer", "Granfluencer", "Link in brine-o.", "sunglasses", "phone"),
        ("goth", "Goth Grandill", "It was never a phase, cucumber.", "witch", "flower"),
        ("billionaire", "Brine Baron", "Owns three jars. Calls it an empire.", "top", "coin"),
        ("mushroom", "Mushroom Uncle", "A fun guy with questionable stories.", "mushroom", "cane"),
        ("chef", "Chef Al Dente", "Too many cooks. Just enough pickle.", "chef", "bowl"),
        ("knight", "Sir Crunch-a-Lot", "Defender of the afternoon nap.", "helmet", "shield"),
        ("weather", "Weather Dill", "Can feel rain in the brine.", "rainhat", "umbrella"),
        ("punk", "Punkle", "Anarchy, but after breakfast.", "mohawk", "record"),
        ("gardener", "Compost Philosopher", "Everything is a salad if you believe.", "sunhat", "flower"),
        ("accountant", "Count Pickula", "One receipt. Two receipts. Ah ah ah.", "vampire", "book"),
        ("zen", "The Big Chill", "Has achieved inner peas.", "halo", "bowl"),
        ("magician", "The Great Dilldini", "Makes an entire afternoon disappear.", "top", "wand"),
        ("artist", "Vincent Van Gherkin", "Still in the green period.", "beret", "palette"),
        ("royal", "Her Royal Brineness", "We are not a-mused. We are a-pickled.", "crown", "scepter"),
        ("timekeeper", "Father Thyme", "Late to everything. Including aging.", "wizard", "clock"),
        ("cosmic", "Cosmic Cucumber", "Knows the universe is mostly snack space.", "antenna", "wand"),
        ("eternal", "The Eternal Dill", "Best before: absolutely never.", "halo", "infinity")
    ].enumerated().map { i, e in ElderLook(id: e.0, name: e.1, quip: e.2, hat: e.3, prop: e.4, accent: [0x718449, 0x8b754a, 0x65785f, 0x8e8460][i % 4]) }
}

enum LifeStage: String { case new, brining, naming, baby, young, teen, adult, elder }
enum PetPhase: String, Codable { case new, brining, naming, living }
enum PetStat: String, CaseIterable { case fullness, happiness, energy, hygiene }

struct WebPet: Codable, Equatable {
    var version = 2
    var phase: PetPhase = .new
    var name = ""
    var variety = "dill"
    var brine = "classic"
    var brinedAt: Int64 = 0
    var hatchAt: Int64 = 0
    var bornAt: Int64 = 0
    var fullness = 90.0
    var happiness = 85.0
    var energy = 90.0
    var hygiene = 95.0
    var sleeping = false
    var sick = false
    var dead = false
    var neglectMs = 0.0
    var diedAt: Int64 = 0
    var lastCareAt: Int64 = 0
    var updatedAt: Int64 = 0
    var eaten: Bool?

    subscript(stat: PetStat) -> Double {
        get { switch stat { case .fullness: return fullness; case .happiness: return happiness; case .energy: return energy; case .hygiene: return hygiene } }
        set { switch stat { case .fullness: fullness = newValue; case .happiness: happiness = newValue; case .energy: energy = newValue; case .hygiene: hygiene = newValue } }
    }
}

enum PetLife {
    static let HOUR: Int64 = 3_600_000
    static let DAY: Int64 = 24 * HOUR
    static let HATCH_MS: Int64 = 60_000
    static let STATS = PetStat.allCases
    static let RATES: [(stat: PetStat, rate: Double)] = [(.fullness, 1.5), (.happiness, 1), (.hygiene, 1.25)]
    static let BRINES = ["classic", "garlic", "spicy"]
    static let MAX_TIMESTAMP: Int64 = 8_640_000_000_000_000
    private static let hour = Double(HOUR), neglectLimit = 48 * Double(HOUR)

    static func ms(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded(.down)) }
    static func date(_ ms: Int64) -> Date { Date(timeIntervalSince1970: Double(ms) / 1000) }
    static func clamp(_ value: Double) -> Double { max(0, min(100, value)) }

    static func fresh(now: Int64) -> WebPet { WebPet(lastCareAt: now, updatedAt: now) }

    // JS String.prototype.trim and /\s/ whitespace.
    static func isSpace(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x9...0xD, 0x20, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF: return true
        default: return false
        }
    }
    static func hasControl(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.properties.generalCategory == .control || $0.properties.generalCategory == .format }
    }
    static func trim(_ text: String) -> String {
        let s = Array(text.unicodeScalars)
        var start = 0, end = s.count
        while start < end, isSpace(s[start]) { start += 1 }
        while end > start, isSpace(s[end - 1]) { end -= 1 }
        var out = String.UnicodeScalarView(); out.append(contentsOf: s[start..<end])
        return String(out)
    }
    static func cleanName(_ text: String) -> String? {
        var out = String.UnicodeScalarView(), space = false
        for s in trim(text.precomposedStringWithCanonicalMapping).unicodeScalars {
            if isSpace(s) { if !space { out.append(" ") }; space = true } else { out.append(s); space = false }
        }
        let cleaned = String(out)
        guard !cleaned.isEmpty, cleaned.unicodeScalars.count <= 24, !hasControl(cleaned) else { return nil }
        return cleaned
    }
    static func isTimestamp(_ value: Int64) -> Bool { value >= 0 && value <= MAX_TIMESTAMP }

    @discardableResult static func validate(_ pet: WebPet) throws -> WebPet {
        let times = [pet.brinedAt, pet.hatchAt, pet.bornAt, pet.lastCareAt, pet.updatedAt, pet.diedAt]
        guard pet.version == 2, pet.name.unicodeScalars.count <= 24, !hasControl(pet.name),
              !(pet.phase == .living && trim(pet.name).isEmpty), PickleVariety.all.contains(where: { $0.id == pet.variety }),
              BRINES.contains(pet.brine), STATS.allSatisfy({ pet[$0].isFinite && pet[$0] >= 0 && pet[$0] <= 100 }),
              times.allSatisfy(isTimestamp), pet.neglectMs.isFinite, pet.neglectMs >= 0, pet.neglectMs <= neglectLimit,
              !(pet.dead && pet.sleeping), !(pet.phase != .living && (pet.dead || pet.sleeping || pet.sick)),
              !(pet.dead && pet.diedAt < pet.bornAt), !(pet.phase != .new && pet.hatchAt < pet.brinedAt),
              !(pet.phase == .living && pet.bornAt > pet.updatedAt), !(pet.eaten == true && !pet.dead)
        else { throw PetLifeError.invalid }
        var result = pet
        result.eaten = pet.eaten == true ? true : nil
        return result
    }

    static func validate(json value: JSONValue) throws -> WebPet {
        guard value.isObject, value["version"]?.number == 2,
              let phase = value["phase"]?.string.flatMap(PetPhase.init(rawValue:)), let name = value["name"]?.string,
              let variety = value["variety"]?.string, let brine = value["brine"]?.string,
              let fullness = value["fullness"]?.number, let happiness = value["happiness"]?.number,
              let energy = value["energy"]?.number, let hygiene = value["hygiene"]?.number,
              let brinedAt = value["brinedAt"]?.safeInteger, let hatchAt = value["hatchAt"]?.safeInteger,
              let bornAt = value["bornAt"]?.safeInteger, let lastCareAt = value["lastCareAt"]?.safeInteger,
              let updatedAt = value["updatedAt"]?.safeInteger, let diedAt = value["diedAt"]?.safeInteger,
              let neglectMs = value["neglectMs"]?.number, let sleeping = value["sleeping"]?.bool,
              let sick = value["sick"]?.bool, let dead = value["dead"]?.bool
        else { throw PetLifeError.invalid }
        var eaten: Bool?
        if let raw = value["eaten"] { guard let flag = raw.bool else { throw PetLifeError.invalid }; eaten = flag }
        return try validate(WebPet(version: 2, phase: phase, name: name, variety: variety, brine: brine, brinedAt: brinedAt, hatchAt: hatchAt,
                                   bornAt: bornAt, fullness: fullness, happiness: happiness, energy: energy, hygiene: hygiene,
                                   sleeping: sleeping, sick: sick, dead: dead, neglectMs: neglectMs, diedAt: diedAt,
                                   lastCareAt: lastCareAt, updatedAt: updatedAt, eaten: eaten))
    }

    static func restore(json value: JSONValue, now: Int64) throws -> WebPet {
        if value["version"]?.number == 2 { return try validate(json: value) }
        guard value.isObject, value["version"]?.number == 1,
              STATS.allSatisfy({ value[$0.rawValue]?.number.map { $0.isFinite && $0 >= 0 && $0 <= 100 } == true }),
              ["ageTicks", "neglect", "updatedAt"].allSatisfy({ value[$0]?.number.map { $0.isFinite && $0 >= 0 } == true }),
              let sleeping = value["sleeping"]?.bool, let sick = value["sick"]?.bool, let dead = value["dead"]?.bool,
              let ticks = value["ageTicks"]?.number
        else { throw PetLifeError.unreadable }
        let age = ticks >= 600 ? 14 * DAY : ticks >= 100 ? 7 * DAY : ticks >= 10 ? DAY : 0
        var pet = fresh(now: now)
        for stat in STATS { pet[stat] = value[stat.rawValue]?.number ?? 0 }
        pet.phase = .living; pet.name = "Little Dill"
        pet.bornAt = max(0, now - age); pet.brinedAt = max(0, now - age - HATCH_MS); pet.hatchAt = max(0, now - age)
        pet.sleeping = sleeping && !dead; pet.sick = sick; pet.dead = dead; pet.diedAt = dead ? now : 0
        return pet
    }

    static func restore(json data: Data, now: Int64) throws -> WebPet {
        guard let value = try? JSONValue.parse(data) else { throw PetLifeError.unreadable }
        return try restore(json: value, now: now)
    }

    static func brine(_ pet: inout WebPet, kind: String, now: Int64, random: Double) -> Bool {
        guard pet.phase == .new, BRINES.contains(kind) else { return false }
        let choices = PickleVariety.all.filter { $0.brine == kind }
        pet.phase = .brining; pet.brine = kind
        pet.variety = choices[random >= 0.5 ? 1 : 0].id
        pet.brinedAt = now; pet.hatchAt = now + HATCH_MS; pet.updatedAt = now
        return true
    }

    static func name(_ pet: inout WebPet, text: String, now: Int64) -> Bool {
        guard pet.phase == .naming, let cleaned = cleanName(text) else { return false }
        pet.phase = .living; pet.name = cleaned; pet.bornAt = now; pet.lastCareAt = now; pet.updatedAt = now
        return true
    }

    static func assess(_ pet: inout WebPet) {
        guard pet.phase == .living, !pet.dead else { return }
        if min(pet.fullness, pet.happiness, pet.hygiene) <= 8 { pet.sick = true }
        if RATES.allSatisfy({ pet[$0.stat] > 0 }) { pet.neglectMs = 0 }
        if STATS.allSatisfy({ pet[$0] >= 30 }) { pet.sick = false }
    }

    static func advance(_ pet: inout WebPet, now: Int64) {
        // A backward wall-clock adjustment must not count the same hours twice.
        guard now > pet.updatedAt else { return }
        if pet.phase == .brining && now >= pet.hatchAt { pet.phase = .naming }
        guard pet.phase == .living, !pet.dead else { pet.updatedAt = now; return }
        let elapsed = Double(now - pet.updatedAt)
        let emptyAfter = RATES.map { pet[$0.stat] / $0.rate * hour }.min()!
        if emptyAfter > 0 { pet.neglectMs = 0 }
        let untilDeath = emptyAfter + neglectLimit - pet.neglectMs
        let duration = min(elapsed, untilDeath)
        let hours = duration / hour
        let recoveryHours = max(0, 30 - pet.energy) / (pet.sleeping ? 30 : 2)
        if recoveryHours <= hours && RATES.allSatisfy({ pet[$0.stat] - $0.rate * recoveryHours >= 30 }) { pet.sick = false }
        for (stat, rate) in RATES { pet[stat] = clamp(pet[stat] - rate * hours) }
        pet.energy = clamp(pet.energy + hours * (pet.sleeping ? 30 : 2))
        if pet.energy >= 100 { pet.sleeping = false }
        pet.neglectMs = min(neglectLimit, pet.neglectMs + max(0, duration - emptyAfter))
        assess(&pet)
        if pet.neglectMs >= neglectLimit {
            pet.dead = true; pet.sleeping = false
            pet.diedAt = Int64((Double(pet.updatedAt) + duration).rounded(.toNearestOrAwayFromZero))
        }
        pet.updatedAt = now
    }

    static func age(_ pet: WebPet, now: Int64) -> Int64 {
        pet.phase == .living ? max(0, (pet.dead ? pet.diedAt : max(now, pet.updatedAt)) - pet.bornAt) : 0
    }

    static func stage(_ pet: WebPet, now: Int64) -> LifeStage {
        guard pet.phase == .living else { return LifeStage(rawValue: pet.phase.rawValue)! }
        let days = Double(age(pet, now: now)) / Double(DAY)
        return days < 1 ? .baby : days < 3 ? .young : days < 7 ? .teen : days < 14 ? .adult : .elder
    }

    static func teen(_ pet: WebPet, now: Int64) -> TeenLook? {
        guard stage(pet, now: now) == .teen else { return nil }
        let day = Int((age(pet, now: now) - 3 * DAY) / DAY)
        let offset = Int((pet.bornAt / 1000) % Int64(TeenLook.all.count))
        var look = TeenLook.all[(offset + day) % TeenLook.all.count]
        look.day = day
        return look
    }

    static func elder(_ pet: WebPet, now: Int64) -> ElderLook? {
        guard stage(pet, now: now) == .elder else { return nil }
        let number = Int((age(pet, now: now) - 14 * DAY) / (3 * DAY)), count = ElderLook.all.count
        var look = ElderLook.all[number % count]
        look.number = number; look.unlocked = min(count, number + 1); look.lap = number / count + 1
        return look
    }

    static func nextCareAt(_ pet: WebPet, now: Int64) -> Double {
        let hours = RATES.map { max(0, pet[$0.stat] - 55) / $0.rate }.min()!
        return Double(now) + max(2, hours) * hour
    }
}
