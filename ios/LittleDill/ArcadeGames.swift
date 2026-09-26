import Foundation

// Rules and timings of the web pet arcade (index.html startGame, huntRound, memoryRound, catchRound, finishGame).
enum ArcadeGame: String, CaseIterable, Identifiable {
    case hunt = "hunt"
    case memory = "memory"
    case brineCatch = "catch"
    case hop = "hop"
    case chop = "chop"
    case toss = "toss"

    var id: String { rawValue }
    var isClassic: Bool { [.hunt, .memory, .brineCatch].contains(self) }
    var title: String {
        switch self {
        case .hunt: return "Heart hunt"
        case .memory: return "Dill says"
        case .brineCatch: return "Brine catch"
        case .hop: return "Countertop escape"
        case .chop: return "Cuke chop"
        case .toss: return "Jar toss"
        }
    }
    var tagline: String {
        switch self {
        case .hunt: return "follow the jar"
        case .memory: return "echo the tune"
        case .brineCatch: return "catch & dodge"
        case .hop: return "escape the kitchen · collect dill"
        case .chop: return "swipe cukes · spare your pickle"
        case .toss: return "pull back · fling into brine"
        }
    }
    var glyph: String {
        switch self {
        case .hunt: return "♥"
        case .memory: return "♫"
        case .brineCatch: return "⌴"
        case .hop: return "↑"
        case .chop: return "✂\u{FE0E}"
        case .toss: return "◡"
        }
    }
    var rounds: Int {
        switch self {
        case .hunt: return 3
        case .memory: return 5
        case .brineCatch: return 12
        case .hop, .chop, .toss: return 0
        }
    }

    func play(reduceMotion: Bool, seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)) -> any ArcadePlay {
        switch self {
        case .hunt, .memory, .brineCatch: return ArcadeEngine(game: self, reduceMotion: reduceMotion, seed: seed)
        case .hop: return HopRun(seed: seed)
        case .chop: return ChopRun(seed: seed)
        case .toss: return TossRun(seed: seed)
        }
    }
}

/// One arcade session. `advance(by:)` is the only thing that moves game time.
protocol ArcadePlay {
    var game: ArcadeGame { get }
    var score: Int { get }
    var message: String { get }
    var finishMessage: String? { get }
    var isFinished: Bool { get }
    func meta(best: Int) -> String
    mutating func advance(by seconds: Double) -> [ArcadeCue]
}

enum ArcadeCue: Equatable {
    case shuffle, good, miss, select, finished
    case hop, landing, ding, streak, chop, bonk, fling, splash, clank
    case note(Int)
}

struct ArcadeRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct CatchDrop: Equatable {
    let lane: Int
    let salt: Bool
    let start: Double
    let duration: Double
}

enum CatchRules {
    static func isSalt(round: Int) -> Bool { round % 4 == 0 }
    static func duration(round: Int) -> Double { max(0.85, 1.55 - Double(round) * 0.045) }
    /// Returns the new score and streak after a drop lands, like the web catchRound() landing timer.
    static func land(salt: Bool, caught: Bool, score: Int, combo: Int) -> (score: Int, combo: Int) {
        if caught && !salt {
            let streak = combo + 1
            return (score + (streak >= 3 ? 2 : 1), streak)
        }
        if caught && salt { return (max(0, score - 1), 0) }
        return (score, salt ? combo : 0)
    }
}

enum HuntRules {
    static func swaps(round: Int) -> Int { round + 2 }
    static func shuffleDuration(round: Int, reduceMotion: Bool) -> Double { reduceMotion ? 0 : 0.44 - Double(round) * 0.035 }
}

enum MemoryRules {
    static let shapes = ["●", "◆", "★"]
    static func deadline(length: Int) -> Double { 10 + Double(length) * 2 }
}

struct ArcadeEngine: ArcadePlay {
    enum Phase: Equatable { case watch, shuffle, choose, reveal, listen, respond, between, ready, falling, result }
    private enum Event {
        case huntShuffle, huntSwap(Int, Int), huntChoose, huntNext
        case memoryFlash(Int), memoryRespond, memoryTimeout, memoryNext
        case catchDrop, catchLand, catchNext
    }
    private struct Scheduled {
        let at: Double
        let order: Int
        let event: Event
    }

    let game: ArcadeGame
    let reduceMotion: Bool
    private(set) var phase: Phase = .watch
    private(set) var time = 0.0
    private(set) var round = 1
    private(set) var score = 0
    private(set) var message = ""
    private(set) var finishMessage: String?
    // Heart hunt: `order[slot]` is the jar id shown in that slot.
    private(set) var winner = 0
    private(set) var order = [0, 1, 2]
    private(set) var revealed: Set<Int> = []
    private(set) var picked: Int?
    private(set) var shuffleDuration = 0.0
    // Dill says
    private(set) var sequence: [Int] = []
    private(set) var input = 0
    private var litPad: Int?
    private var litUntil = 0.0
    // Brine catch
    private(set) var basket = 1
    private(set) var combo = 0
    private(set) var drop: CatchDrop?

    private var rng: ArcadeRNG
    private var events: [Scheduled] = []
    private var eventCount = 0

    init(game: ArcadeGame, reduceMotion: Bool, seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)) {
        self.game = game
        self.reduceMotion = reduceMotion
        rng = ArcadeRNG(seed: seed)
        switch game {
        case .hunt: huntRound()
        case .memory: memoryRound()
        case .brineCatch:
            phase = .ready
            message = "catch ♥ · dodge salt × · move below"
            later(1.6, .catchDrop)
        case .hop, .chop, .toss: phase = .result
        }
    }

    var isFinished: Bool { phase == .result }
    var litNote: Int? { time < litUntil ? litPad : nil }
    var dropProgress: Double? {
        guard let drop else { return nil }
        return min(1, max(0, (time - drop.start) / drop.duration))
    }
    var acceptsInput: Bool {
        switch game {
        case .hunt: return phase == .choose
        case .memory: return phase == .respond
        case .brineCatch: return phase == .ready || phase == .falling
        case .hop, .chop, .toss: return false
        }
    }
    func slot(ofJar jar: Int) -> Int { order.firstIndex(of: jar) ?? jar }
    func meta(best: Int) -> String {
        switch game {
        case .hunt: return "ROUND \(round)/3 · \(score) FOUND · BEST \(best)"
        case .memory: return "LEVEL \(round)/5 · BEST \(best)"
        case .brineCatch: return "DROP \(round)/12 · \(score) PTS · BEST \(best)"
        case .hop, .chop, .toss: return ""
        }
    }

    /// Advances game time and fires every due event in order. Pausing is not calling this.
    mutating func advance(by seconds: Double) -> [ArcadeCue] {
        let target = time + max(0, seconds)
        var cues: [ArcadeCue] = []
        while let next = nextDue(before: target) {
            let item = events.remove(at: next)
            time = item.at
            cues += fire(item.event)
        }
        time = target
        return cues
    }

    mutating func chooseJar(_ jar: Int) -> [ArcadeCue] {
        guard game == .hunt, phase == .choose, (0..<3).contains(jar) else { return [] }
        let won = jar == winner
        phase = .reveal
        if won { score += 1 }
        message = won ? "heart found! lovely little detective." : "there it is! another chance coming."
        revealed = [0, 1, 2]
        picked = jar
        later(1.1, .huntNext)
        return [won ? .good : .miss]
    }

    mutating func chooseNote(_ pad: Int) -> [ArcadeCue] {
        guard game == .memory, phase == .respond, (0..<3).contains(pad) else { return [] }
        var cues = flash(pad)
        guard pad == sequence[input] else { return cues + finish("nice try, little maestro.") }
        input += 1
        message = "\(input)/\(sequence.count) notes. keep going!"
        guard input == sequence.count else { return cues }
        events.removeAll()
        litPad = nil
        score = round
        phase = .between
        message = "nailed it! one more note…"
        cues.append(.good)
        if round == 5 { return cues + finish("five levels! encore!") }
        later(0.9, .memoryNext)
        return cues
    }

    mutating func moveBasket(_ lane: Int) -> [ArcadeCue] {
        guard game == .brineCatch, phase == .ready || phase == .falling else { return [] }
        basket = min(2, max(0, lane))
        return [.select]
    }

    private func nextDue(before target: Double) -> Int? {
        var best: Int?
        for index in events.indices where events[index].at <= target {
            guard let current = best else { best = index; continue }
            let a = events[index], b = events[current]
            if a.at < b.at || (a.at == b.at && a.order < b.order) { best = index }
        }
        return best
    }

    private mutating func later(_ delay: Double, _ event: Event) {
        eventCount += 1
        events.append(Scheduled(at: time + delay, order: eventCount, event: event))
    }

    private mutating func fire(_ event: Event) -> [ArcadeCue] {
        switch event {
        case .huntShuffle:
            phase = .shuffle
            message = "keep an eye on that little heart."
            revealed = reduceMotion ? [winner] : []
            return []
        case let .huntSwap(first, second):
            order.swapAt(first, second)
            return [.shuffle]
        case .huntChoose:
            phase = .choose
            message = "where’s the heart? pick 1, 2, or 3."
            revealed = []
            return []
        case .huntNext:
            if round == 3 { return finish("\(score)/3 hearts found.") }
            round += 1
            huntRound()
            return []
        case let .memoryFlash(pad):
            return flash(pad)
        case .memoryRespond:
            phase = .respond
            message = "your turn! repeat all \(sequence.count) notes."
            later(MemoryRules.deadline(length: sequence.count), .memoryTimeout)
            return []
        case .memoryTimeout:
            return phase == .respond ? finish("good practice!") : []
        case .memoryNext:
            round += 1
            memoryRound()
            return []
        case .catchDrop:
            return dropNext()
        case .catchLand:
            return land()
        case .catchNext:
            round += 1
            return dropNext()
        }
    }

    private mutating func huntRound() {
        phase = .watch
        winner = Int.random(in: 0..<3, using: &rng)
        order = [0, 1, 2]
        message = "follow the heart. here it is!"
        revealed = [winner]
        picked = nil
        shuffleDuration = HuntRules.shuffleDuration(round: round, reduceMotion: reduceMotion)
        later(1.3, .huntShuffle)
        let swaps = HuntRules.swaps(round: round)
        for turn in 0..<swaps {
            let first = Int.random(in: 0..<3, using: &rng)
            let second = (first + 1 + Int.random(in: 0..<2, using: &rng)) % 3
            later(1.7 + Double(turn) * 0.62, .huntSwap(first, second))
        }
        later(1.7 + Double(swaps) * 0.62, .huntChoose)
    }

    private mutating func memoryRound() {
        events.removeAll()
        litPad = nil
        phase = .listen
        input = 0
        while sequence.count < round + 1 { sequence.append(Int.random(in: 0..<3, using: &rng)) }
        message = "watch the shapes. remember the tune."
        for (index, pad) in sequence.enumerated() { later(0.7 + Double(index) * 0.65, .memoryFlash(pad)) }
        later(0.7 + Double(sequence.count) * 0.65, .memoryRespond)
    }

    private mutating func flash(_ pad: Int) -> [ArcadeCue] {
        litPad = pad
        litUntil = time + 0.3
        if phase == .listen { message = "listen: note \(pad + 1) \(MemoryRules.shapes[pad])" }
        return [.note(pad)]
    }

    private mutating func dropNext() -> [ArcadeCue] {
        phase = .falling
        let lane = Int.random(in: 0..<3, using: &rng)
        let salt = CatchRules.isSalt(round: round)
        let next = CatchDrop(lane: lane, salt: salt, start: time, duration: CatchRules.duration(round: round))
        drop = next
        let streak = combo > 1 ? " · \(combo) streak" : ""
        message = (salt ? "salt! dodge lane " : "heart! catch lane ") + "\(lane + 1)" + streak
        later(next.duration, .catchLand)
        return []
    }

    private mutating func land() -> [ArcadeCue] {
        guard let landed = drop else { return [] }
        drop = nil
        let caught = basket == landed.lane
        let result = CatchRules.land(salt: landed.salt, caught: caught, score: score, combo: combo)
        score = result.score
        combo = result.combo
        var cues: [ArcadeCue] = []
        if caught { cues.append(landed.salt ? .miss : .good) }
        if caught {
            message = landed.salt ? "a little too salty! −1 point." : "crunch! \(combo) in a row!"
        } else {
            message = landed.salt ? "smooth dodge. stay crunchy." : "missed it. next heart is yours."
        }
        if round == 12 { return cues + finish("\(score) points. nicely brined!") }
        later(0.26, .catchNext)
        return cues
    }

    private mutating func finish(_ text: String) -> [ArcadeCue] {
        guard phase != .result else { return [] }
        events.removeAll()
        phase = .result
        litPad = nil
        drop = nil
        finishMessage = text
        message = text
        return [.finished]
    }
}
