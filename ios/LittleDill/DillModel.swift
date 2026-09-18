import Foundation
import SwiftUI

// Local pet and precision-game rules. The online arena runs its own authoritative server simulation.
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
}

enum Outfit: String, Codable, CaseIterable, Identifiable {
    case original, sprout, bow, shades, crown, party
    var id: String { rawValue }
    var title: String {
        switch self { case .original: return "Au naturel"; case .sprout: return "Plant parent"; case .bow: return "Sweet thing"; case .shades: return "Off duty"; case .crown: return "Big dill"; case .party: return "Party pickle" }
    }
    var symbol: String {
        switch self { case .original: return "heart"; case .sprout: return "leaf.fill"; case .bow: return "gift.fill"; case .shades: return "sunglasses.fill"; case .crown: return "crown.fill"; case .party: return "party.popper.fill" }
    }
    var cost: Int {
        switch self { case .original, .sprout: return 0; case .bow: return 30; case .shades: return 50; case .crown: return 90; case .party: return 120 }
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

struct ScoreEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var day: String
    var score: Int
    var date: Date
}

struct PetState: Codable {
    var version = 1
    var name = "Dilly"
    var brine: Brine = .classic
    var outfit: Outfit = .sprout
    var adopted = false
    var birthday = Date()
    var updatedAt = Date()
    var food = 80.0
    var joy = 85.0
    var clean = 80.0
    var energy = 85.0
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
    var sounds: Bool {soundEnabled ?? true}
    var arenaBest: Int?

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    mutating func refresh(at now: Date, calendar: Calendar = .current) {
        let hours = max(0, now.timeIntervalSince(updatedAt)) / 3600
        food = max(10, min(100, food - hours * 1.5))
        joy = max(10, min(100, joy - hours))
        clean = max(10, min(100, clean - hours * 1.25))
        energy = min(100, max(10, energy + hours * 2))
        // Never move the decay clock backwards if the device clock changes.
        updatedAt = max(updatedAt, now)
        let day = Self.dayKey(now, calendar: calendar)
        if careDay != day { careDay = day; dailyCare = [] }
        guard adopted, lastVisitDay != day, day > lastVisitDay else { return }
        let yesterday = Self.dayKey(calendar.date(byAdding: .day, value: -1, to: now) ?? now, calendar: calendar)
        streak = lastVisitDay == yesterday ? streak + 1 : 1
        lastVisitDay = day
    }

    @discardableResult mutating func care(_ action: Care, at now: Date = Date()) -> Int {
        refresh(at: now)
        switch action {
        case .feed: food = min(100, food + 35)
        case .pet: joy = min(100, joy + 20)
        case .wash: clean = 100
        case .nap: energy = min(100, energy + 25)
        }
        let reward = dailyCare.insert(action.rawValue).inserted ? 5 : 0
        coins += reward
        return reward
    }

    @discardableResult mutating func record(score: Int, day: String, at now: Date = Date()) -> Int {
        guard (0...300).contains(score), DailyChallenge.validDay(day) else { return 0 }
        if let i = scores.firstIndex(where: { $0.day == day }) {
            if score > scores[i].score { scores[i].score = score; scores[i].date = now }
        } else { scores.append(ScoreEntry(day: day, score: score, date: now)) }
        scores = Array(scores.sorted { $0.day > $1.day }.prefix(90))
        // Replays improve a best score. Only today's challenge earns a daily reward.
        let reward = day == DailyChallenge.today(now) && rewardedDays.insert(day).inserted ? 25 : 0
        rewardedDays = Set(rewardedDays.sorted().suffix(120))
        coins += reward
        joy = min(100, joy + 12)
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

    var isValid: Bool {
        version == 1 && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 18 &&
        [food, joy, clean, energy].allSatisfy { $0.isFinite && (0...100).contains($0) } &&
        coins >= 0 && coins <= 1_000_000 && streak >= 0 && unlocked.contains(outfit) &&
        scores.count <= 90 && scores.allSatisfy { (0...300).contains($0.score) && DailyChallenge.validDay($0.day) }
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

@MainActor final class DillStore: ObservableObject {
    @Published private(set) var pet: PetState
    @Published var notice: String?
    private let defaults: UserDefaults
    private let key = "little-dill.native.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            if let saved = try? JSONDecoder().decode(PetState.self, from: data), saved.isValid {
                pet = saved
            } else {
                defaults.set(data, forKey: key + ".recovery")
                pet = PetState()
                notice = "Your previous save could not be read. A recovery copy is preserved on this device."
            }
        } else { pet = PetState() }
        refresh()
    }
    func save() {
        guard let data = try? JSONEncoder().encode(pet) else { return }
        defaults.set(data, forKey: key)
    }
    func refresh() { pet.refresh(at: Date()); save() }
    func adopt(name: String, brine: Brine) {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(18))
        pet.name = name.isEmpty ? "Dilly" : name
        pet.brine = brine; pet.adopted = true; pet.birthday = Date()
        refresh()
    }
    @discardableResult func care(_ action: Care) -> Int { let reward = pet.care(action); save(); return reward }
    @discardableResult func record(score: Int, day: String) -> Int { let reward = pet.record(score: score, day: day); save(); return reward }
    func equip(_ outfit: Outfit) -> Bool { let result = pet.equip(outfit); save(); return result }
    func rename(_ name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(18))
        guard !clean.isEmpty else { return }
        pet.name = clean; save()
    }
    func recordArena(best:Int) {guard best >= 0 else {return}; pet.arenaBest = max(pet.arenaBest ?? 0,best); save()}
    func setHaptics(_ enabled: Bool) { pet.haptics = enabled; save() }
    func setSounds(_ enabled: Bool) { pet.soundEnabled = enabled; save(); if !enabled {DillAudio.shared.stop()} }
    func sound(_ cue:DillSound) {if pet.sounds {DillAudio.shared.play(cue)}}
    func reset() { pet = PetState(); save() }
    func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        if pet.haptics { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }
}
