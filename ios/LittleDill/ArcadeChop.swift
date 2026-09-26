import Foundation

enum ChopRules {
    static let gravity = 740.0, launchY = 630.0, lostY = 650.0, lives = 3
    static let radius = 30.0, minSwipe = 3.0, trailSeconds = 0.14
    /// Dropped cukes are free until the first chop or this many seconds in.
    static let graceSeconds = 8.0
    static func interval(score: Int) -> Double { max(0.8, 1.6 - Double(score) * 0.02) }
    static func waveSize(score: Int) -> Int { min(5, 2 + score / 10) }
    static func points(_ kind: ChopItem.Kind) -> Int { kind == .gold ? 3 : 1 }
}

struct ChopItem: Equatable {
    enum Kind: Equatable { case cuke, gold, pal }
    let kind: Kind
    var x: Double, y: Double, vx: Double, vy: Double
    var angle: Double, spin: Double
    var bonked = false
}

struct ChopHalf: Equatable {
    let gold: Bool
    let right: Bool
    var x: Double, y: Double, vx: Double, vy: Double
    var angle: Double, spin: Double
}

struct ChopMark: Equatable {
    let x: Double, y: Double, born: Double
    var gold = false
}

struct ChopTrail: Equatable {
    let x: Double, y: Double, time: Double, stroke: Int
}

/// Cuke chop: swipe tossed cucumbers, spare your pickle. Dropped cukes and pickle bonks cost a heart.
struct ChopRun: ArcadePlay {
    let game = ArcadeGame.chop
    private(set) var score = 0
    private(set) var lives = ChopRules.lives
    private(set) var message = "swipe the cukes. spare your pickle!"
    private(set) var finishMessage: String?
    private(set) var items: [ChopItem] = []
    private(set) var halves: [ChopHalf] = []
    private(set) var splashes: [ChopMark] = []
    private(set) var drops: [ChopMark] = []
    private(set) var trail: [ChopTrail] = []
    private(set) var time = 0.0
    private var queue: [(at: Double, item: ChopItem)] = []
    private var nextWave = 0.9
    private var stroke = 0
    private var swipeHits = 0
    private var endedAt: Double?
    private var rng: ArcadeRNG

    init(seed: UInt64) { rng = ArcadeRNG(seed: seed) }

    var isFinished: Bool { finishMessage != nil }
    var isOver: Bool { endedAt != nil }
    func meta(best: Int) -> String { "\(score) CHOPPED · BEST \(best)" }

    mutating func advance(by seconds: Double) -> [ArcadeCue] {
        var cues: [ArcadeCue] = []
        var left = max(0, seconds)
        while left > 0, !isFinished {
            let dt = min(1.0 / 60, left)
            left -= dt
            cues += step(dt)
        }
        return cues
    }

    /// One finger movement, in world points. Every item the segment crosses is cut.
    mutating func swipe(from a: CGPoint, to b: CGPoint) -> [ArcadeCue] {
        guard endedAt == nil else { return [] }
        if trail.last?.stroke != stroke { trail.append(ChopTrail(x: a.x, y: a.y, time: time, stroke: stroke)) }
        trail.append(ChopTrail(x: b.x, y: b.y, time: time, stroke: stroke))
        let dx = b.x - a.x, dy = b.y - a.y, length = hypot(dx, dy)
        guard length >= ChopRules.minSwipe else { return [] }
        let normal = (x: -dy / length, y: dx / length)
        var cues: [ArcadeCue] = []
        for index in items.indices.reversed() {
            let item = items[index]
            guard !item.bonked, Self.distance(CGPoint(x: item.x, y: item.y), a, b) <= ChopRules.radius else { continue }
            if item.kind == .pal {
                let side = (item.x - a.x) * normal.x + (item.y - a.y) * normal.y < 0 ? -1.0 : 1.0
                items[index].bonked = true
                items[index].vx = normal.x * side * 220
                items[index].vy = min(item.vy, -120)
                items[index].spin = side * 9
                lives -= 1
                message = lives > 0 ? "ow! that’s your pickle. \(lives) ♥ left" : "ow! out of hearts."
                cues.append(.bonk)
                if lives == 0 { endedAt = time }
                continue
            }
            items.remove(at: index)
            score += ChopRules.points(item.kind)
            swipeHits += 1
            for right in [false, true] {
                let push = right ? 130.0 : -130.0
                halves.append(ChopHalf(gold: item.kind == .gold, right: right, x: item.x, y: item.y,
                                       vx: item.vx + normal.x * push, vy: min(item.vy, 0) + normal.y * push - 60,
                                       angle: item.angle, spin: item.spin + (right ? 5 : -5)))
            }
            splashes.append(ChopMark(x: item.x, y: item.y, born: time, gold: item.kind == .gold))
            message = item.kind == .gold ? "golden cuke! +3" : "chop!"
            cues.append(.chop)
        }
        return cues
    }

    /// The finger lifted. Three or more cuts in one swipe score a combo bonus.
    mutating func endSwipe() -> [ArcadeCue] {
        let hits = swipeHits
        swipeHits = 0
        stroke += 1
        guard hits >= 3, endedAt == nil else { return [] }
        score += hits
        message = "\(hits)× combo! +\(hits)"
        return [.good]
    }

    static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y, squared = dx * dx + dy * dy
        let t = squared == 0 ? 0 : max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / squared))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    private mutating func step(_ dt: Double) -> [ArcadeCue] {
        time += dt
        var cues: [ArcadeCue] = []
        if endedAt == nil, time >= nextWave { launchWave() }
        while let first = queue.first, first.at <= time, endedAt == nil {
            items.append(first.item)
            queue.removeFirst()
        }
        for index in items.indices {
            items[index].vy += ChopRules.gravity * dt
            items[index].x += items[index].vx * dt
            items[index].y += items[index].vy * dt
            items[index].angle += items[index].spin * dt
        }
        for index in halves.indices {
            halves[index].vy += ChopRules.gravity * dt
            halves[index].x += halves[index].vx * dt
            halves[index].y += halves[index].vy * dt
            halves[index].angle += halves[index].spin * dt
        }
        let warmedUp = score > 0 || time > ChopRules.graceSeconds
        for item in items where item.y > ChopRules.lostY && item.vy > 0 && item.kind != .pal && endedAt == nil && warmedUp {
            lives -= 1
            drops.append(ChopMark(x: min(ArcadeWorld.width - 24, max(24, item.x)), y: ArcadeWorld.height - 30, born: time))
            message = lives > 0 ? "dropped one! \(lives) ♥ left" : "out of hearts!"
            cues.append(.miss)
            if lives == 0 { endedAt = time }
        }
        items.removeAll { $0.y > ChopRules.lostY && $0.vy > 0 }
        halves.removeAll { $0.y > ChopRules.lostY + 60 }
        splashes.removeAll { time - $0.born > 0.6 }
        drops.removeAll { time - $0.born > 0.9 }
        trail.removeAll { time - $0.time > ChopRules.trailSeconds }
        if let endedAt, time - endedAt > 1 {
            finishMessage = score == 1 ? "1 cuke chopped." : "\(score) cukes chopped. sharp work!"
            message = finishMessage ?? ""
            cues.append(.finished)
        }
        return cues
    }

    private mutating func launchWave() {
        let count = Int.random(in: 1...ChopRules.waveSize(score: score), using: &rng)
        let pal = score >= 4 && Double.random(in: 0..<1, using: &rng) < 0.22
        for n in 0..<(count + (pal ? 1 : 0)) {
            let kind: ChopItem.Kind = pal && n == count ? .pal : (Double.random(in: 0..<1, using: &rng) < 0.07 ? .gold : .cuke)
            let x = Double.random(in: 50...310, using: &rng)
            let item = ChopItem(kind: kind, x: x, y: ChopRules.launchY,
                                vx: (180 - x) * Double.random(in: 0.25...0.7, using: &rng),
                                vy: -Double.random(in: 780...910, using: &rng),
                                angle: Double.random(in: 0...(2 * .pi), using: &rng),
                                spin: Double.random(in: -4...4, using: &rng))
            queue.append((time + Double(n) * 0.14, item))
        }
        nextWave = time + ChopRules.interval(score: score) + Double(count) * 0.14
    }
}
