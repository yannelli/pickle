import CoreGraphics
import Foundation

/// A brine jar: announced `warnSeconds` before it spills, then lingers with `warn == 0` until the server removes it.
struct ArenaJar: Decodable, Equatable {
    static let warnSeconds = 10.0
    static let lingerSeconds = 8.0
    static let radius = 260.0
    let x: Double
    let y: Double
    let warn: Double
    var spilled: Bool { warn <= 0 }
    var spoken: String { spilled ? "A brine jar spilled." : "A brine jar spills in \(Int(ceil(warn))) seconds." }
    static func spilled(from old:ArenaJar?,to new:ArenaJar?) -> Bool {
        guard let old, let new else {return false}
        return old.warn > 0 && new.warn <= 0
    }
}

/// One run goal from the server: `[kind, target, progress]`.
struct ArenaGoal: Decodable, Equatable {
    let kind: String
    let target: Double
    let progress: Double
    init(kind:String,target:Double,progress:Double) {self.kind = kind; self.target = target; self.progress = progress}
    init(from decoder:Decoder) throws {
        var row = try decoder.unkeyedContainer()
        kind = try row.decode(String.self)
        target = try row.decode(Double.self)
        progress = try row.decode(Double.self)
        guard abs(target) < 1e12, abs(progress) < 1e12 else {
            throw DecodingError.dataCorruptedError(in:row,debugDescription:"Goal numbers must be finite and bounded")
        }
    }
    var done: Bool { progress >= target }
    var label: String {
        let n = Int(target)
        switch kind {
        case "eat": return n == 1 ? "Crunch 1 pickle" : "Crunch \(n) pickles"
        case "mass": return "Reach \(n) mass"
        case "survive": return n % 60 == 0 ? "Survive \(n / 60) min" : "Survive \(n)s"
        case "food": return "Eat \(n) pellets"
        case "jar": return "Touch a jar spill"
        default: return "Complete a goal"
        }
    }
    var progressText: String {
        let current = Int(max(0,min(progress,target))), goal = Int(target)
        return kind == "survive" ? "\(current)/\(goal)s" : "\(current)/\(goal)"
    }
}

/// The current life's stats, frozen at death: `[peakMass, kills, secondsAlive, bestRank]`.
struct ArenaRun: Decodable, Equatable {
    let peakMass: Double
    let kills: Int
    let secondsAlive: Double
    let bestRank: Int
    init(peakMass:Double,kills:Int,secondsAlive:Double,bestRank:Int) {
        self.peakMass = peakMass; self.kills = kills; self.secondsAlive = secondsAlive; self.bestRank = bestRank
    }
    init(from decoder:Decoder) throws {
        let values = try [Double](from:decoder)
        guard values.count >= 4, values.prefix(4).allSatisfy({abs($0) < 1e12}) else {
            throw DecodingError.dataCorrupted(.init(codingPath:decoder.codingPath,debugDescription:"Run needs four numbers"))
        }
        self.init(peakMass:max(0,values[0]),kills:max(0,Int(values[1])),secondsAlive:max(0,values[2]),bestRank:max(0,Int(values[3])))
    }
    var values: [Double] { [peakMass,Double(kills),secondsAlive,Double(bestRank)] }
}

/// Goals that turn done between consecutive observed snapshots of one life.
/// The first snapshot after `reset()` only primes, so joins and resumed sessions do not replay completions.
struct ArenaGoalWatch {
    private var last: [ArenaGoal]?
    mutating func reset() {last = nil}
    mutating func completed(_ goals:[ArenaGoal]) -> [ArenaGoal] {
        defer {last = goals}
        guard let last else {return []}
        return goals.enumerated().compactMap {index,goal in
            guard goal.done, index < last.count else {return nil}
            let before = last[index]
            return before.kind == goal.kind && before.target == goal.target && !before.done ? goal : nil
        }
    }
    static func toast(_ goal:ArenaGoal,coins:Bool) -> String {
        "✓ \(goal.label)" + (coins ? " · +\(ArenaEarnings.coinsPerGoal) coins" : "")
    }
}

/// Wall-clock start of the current jar's spill, for the tip animation and linger fade.
final class ArenaJarClock {
    private var spot: CGPoint?
    private var spilledAt: Date?
    func spillAge(_ jar:ArenaJar?,at now:Date) -> Double? {
        guard let jar else {spot = nil; spilledAt = nil; return nil}
        let here = CGPoint(x:jar.x,y:jar.y)
        if spot != here {spot = here; spilledAt = nil}
        guard jar.spilled else {spilledAt = nil; return nil}
        if spilledAt == nil {spilledAt = now}
        return max(0,now.timeIntervalSince(spilledAt ?? now))
    }
}
