import Foundation

enum TossRules {
    static let floor = 540.0, radius = 17.0, gravity = 900.0
    static let anchor = CGPoint(x: 78, y: 400)
    static let power = 6.4, maxPull = 120.0, minPull = 18.0
    static let jarHeight = 140.0, rim = 5.0, wall = 8.0, bounce = 0.55, lives = 3
    static func mouth(score: Int) -> Double { max(64, 104 - Double(score) * 2.5) }
    static func sway(score: Int) -> Double { score < 3 ? 0 : min(80, 20 + Double(score) * 4) }
    static func windLimit(score: Int) -> Double { score < 6 ? 0 : min(90, 25 + Double(score - 6) * 6) }
    static func previewDots(score: Int) -> Int { max(3, 9 - score / 2) }
}

struct TossJar: Equatable {
    let base: Double, sway: Double, pace: Double, mouth: Double, top: Double
    func x(at time: Double) -> Double { base + sway * sin(time * pace) }
}

/// Jar toss: pull back and fling your pickle into the brine. Three misses end the run.
struct TossRun: ArcadePlay {
    enum State: Equatable { case aiming, flying, landed, missed }
    let game = ArcadeGame.toss
    private(set) var score = 0
    private(set) var lives = TossRules.lives
    private(set) var streak = 0
    private(set) var message = "pull back, then let go to fling"
    private(set) var finishMessage: String?
    private(set) var state = State.aiming
    private(set) var x = TossRules.anchor.x, y = TossRules.anchor.y
    private(set) var vx = 0.0, vy = 0.0, angle = 0.0
    private(set) var pull: CGVector?
    private(set) var jar: TossJar
    private(set) var wind = 0.0
    private(set) var time = 0.0
    private(set) var settledAt = 0.0
    /// Where the pickle bobs in the brine, relative to the jar center.
    private(set) var sink = 0.0
    private(set) var touchedRim = false
    private var flightTime = 0.0
    private var rng: ArcadeRNG

    init(seed: UInt64) {
        rng = ArcadeRNG(seed: seed)
        jar = TossJar(base: 250, sway: 0, pace: 0, mouth: TossRules.mouth(score: 0), top: TossRules.floor - TossRules.jarHeight)
    }

    var isFinished: Bool { finishMessage != nil }
    func meta(best: Int) -> String { "\(score) PTS · BEST \(best)" }

    /// `pull` points from the finger back to where it landed; the fling goes that way.
    mutating func aim(_ pull: CGVector) -> [ArcadeCue] {
        guard state == .aiming, !isFinished else { return [] }
        let length = hypot(pull.dx, pull.dy)
        let scale = length > TossRules.maxPull ? TossRules.maxPull / length : 1
        let first = self.pull == nil
        let held = CGVector(dx: pull.dx * scale, dy: pull.dy * scale)
        self.pull = held
        x = TossRules.anchor.x - held.dx
        y = TossRules.anchor.y - held.dy
        return first ? [.select] : []
    }

    mutating func release() -> [ArcadeCue] {
        guard state == .aiming, let held = pull else { return [] }
        pull = nil
        guard hypot(held.dx, held.dy) >= TossRules.minPull else {
            x = TossRules.anchor.x; y = TossRules.anchor.y
            return []
        }
        state = .flying
        flightTime = 0
        touchedRim = false
        vx = held.dx * TossRules.power
        vy = held.dy * TossRules.power
        return [.fling]
    }

    /// The dotted aim guide. It leaves out the wind.
    func preview() -> [CGPoint] {
        guard let held = pull else { return [] }
        let vx = held.dx * TossRules.power, vy = held.dy * TossRules.power
        return (1...TossRules.previewDots(score: score)).map { n in
            let t = Double(n) * 0.07
            return CGPoint(x: x + vx * t, y: y + vy * t + TossRules.gravity * t * t / 2)
        }
    }

    mutating func advance(by seconds: Double) -> [ArcadeCue] {
        var cues: [ArcadeCue] = []
        var left = max(0, seconds)
        while left > 0, !isFinished {
            let dt = min(1.0 / 240, left)
            left -= dt
            time += dt
            switch state {
            case .aiming: break
            case .flying: cues += fly(dt)
            case .landed, .missed: if time - settledAt > 1.1 { cues += nextThrow() }
            }
        }
        return cues
    }

    private mutating func fly(_ dt: Double) -> [ArcadeCue] {
        flightTime += dt
        let before = y
        vx += wind * dt
        vy += TossRules.gravity * dt
        x += vx * dt
        y += vy * dt
        angle += vx / 45 * dt
        let center = jar.x(at: time), left = center - jar.mouth / 2, right = center + jar.mouth / 2, top = jar.top
        if before < top, y >= top, vy > 0, x > left + TossRules.rim, x < right - TossRules.rim {
            return land(center: center, clean: !touchedRim && min(x - left, right - x) > TossRules.radius)
        }
        var cues: [ArcadeCue] = []
        let reach = TossRules.radius + TossRules.rim
        for rimX in [left, right] {
            let dx = x - rimX, dy = y - top, distance = hypot(dx, dy)
            guard distance < reach, distance > 0 else { continue }
            let nx = dx / distance, ny = dy / distance, toward = vx * nx + vy * ny
            x = rimX + nx * reach
            y = top + ny * reach
            guard toward < 0 else { continue }
            vx -= (1 + TossRules.bounce) * toward * nx
            vy -= (1 + TossRules.bounce) * toward * ny
            if !touchedRim || toward < -80 { cues.append(.clank) }
            touchedRim = true
        }
        let outerLeft = left - TossRules.wall, outerRight = right + TossRules.wall
        if y > top + TossRules.rim, x + TossRules.radius > outerLeft, x - TossRules.radius < outerRight {
            if x < center { x = outerLeft - TossRules.radius; vx = -abs(vx) * TossRules.bounce }
            else { x = outerRight + TossRules.radius; vx = abs(vx) * TossRules.bounce }
            touchedRim = true
            cues.append(.clank)
        }
        if y + TossRules.radius >= TossRules.floor || x < -60 || x > ArcadeWorld.width + 60 || flightTime > 5 {
            y = min(y, TossRules.floor - TossRules.radius)
            lives -= 1
            streak = 0
            state = .missed
            settledAt = time
            message = lives > 0 ? "so close! \(lives) ♥ left" : "out of throws."
            cues.append(.miss)
        }
        return cues
    }

    private mutating func land(center: Double, clean: Bool) -> [ArcadeCue] {
        streak += 1
        let bonus = streak >= 3 ? 1 : 0
        score += (clean ? 2 : 1) + bonus
        state = .landed
        settledAt = time
        sink = max(-(jar.mouth / 2 - 14), min(jar.mouth / 2 - 14, x - center))
        if bonus > 0 { message = "\(streak) in a row! +\((clean ? 2 : 1) + bonus)" }
        else { message = clean ? "swish! +2" : "rim and in! +1" }
        return bonus > 0 ? [.splash, .good] : [.splash]
    }

    private mutating func nextThrow() -> [ArcadeCue] {
        if lives == 0 {
            finishMessage = score == 1 ? "1 point of pure brine." : "\(score) points of pure brine!"
            message = finishMessage ?? ""
            return [.finished]
        }
        if state == .landed { jar = makeJar() }
        let limit = TossRules.windLimit(score: score)
        wind = limit > 0 ? Double.random(in: -1...1, using: &rng) * limit : 0
        state = .aiming
        x = TossRules.anchor.x; y = TossRules.anchor.y
        vx = 0; vy = 0; angle = 0
        if wind != 0 { message = "wind \(wind > 0 ? "→" : "←") \(Int(abs(wind).rounded())). aim for it." }
        else { message = "pull back, then let go" }
        return []
    }

    private mutating func makeJar() -> TossJar {
        let center = Double.random(in: 200...290, using: &rng)
        let sway = min(TossRules.sway(score: score), center - 170, 310 - center)
        let pace = min(2.4, Double.random(in: 0.8...1.2, using: &rng) + Double(score) * 0.05)
        let shelf = score >= 8 ? Double.random(in: 0...100, using: &rng) : 0
        return TossJar(base: center, sway: sway, pace: pace, mouth: TossRules.mouth(score: score), top: TossRules.floor - TossRules.jarHeight - shelf)
    }
}
