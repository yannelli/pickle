import SwiftUI

enum HopRules {
    static let ground = 540.0, pickleX = 100.0, radius = 15.0, start = 270.0
    static let gravity = 1500.0, hopSpeed = -470.0, maxFall = 780.0
    static let forkWidth = 64.0, spacing = 215.0, heartRadius = 16.0
    static func speed(score: Int) -> Double { min(235, 150 + Double(score) * 3) }
    static func gap(score: Int) -> Double { max(140, 192 - Double(score) * 2.5) }
}

struct HopFork: Equatable {
    var x: Double
    let gapY: Double
    let gap: Double
    var passed = false
    /// A bonus heart halfway to the next fork.
    var heartY: Double?
    var top: Double { gapY - gap / 2 }
    var bottom: Double { gapY + gap / 2 }
    var heartX: Double { x + HopRules.forkWidth / 2 + HopRules.spacing / 2 }
}

/// Pickle hop: tap to hop through the gaps between forks and jars. One bump ends the run.
struct HopRun: ArcadePlay {
    let game = ArcadeGame.hop
    private(set) var score = 0
    private(set) var message = "tap anywhere to hop"
    private(set) var finishMessage: String?
    private(set) var y = HopRules.start
    private(set) var vy = 0.0
    private(set) var forks: [HopFork] = []
    private(set) var started = false
    private(set) var crashed = false
    private(set) var time = 0.0
    private(set) var lastHop = -1.0
    private(set) var distance = 0.0
    private var crashTime = 0.0
    private var rng: ArcadeRNG

    init(seed: UInt64) {
        rng = ArcadeRNG(seed: seed)
        forks = [makeFork(at: ArcadeWorld.width + 60, after: HopRules.start)]
    }

    var isFinished: Bool { finishMessage != nil }
    func meta(best: Int) -> String { "\(score) PTS · BEST \(best)" }

    mutating func hop() -> [ArcadeCue] {
        guard !crashed, !isFinished else { return [] }
        if !started { started = true; message = "hop through the gaps. grab the hearts!" }
        vy = HopRules.hopSpeed
        lastHop = time
        return [.hop]
    }

    mutating func advance(by seconds: Double) -> [ArcadeCue] {
        var cues: [ArcadeCue] = []
        var left = max(0, seconds)
        while left > 0, !isFinished {
            let dt = min(1.0 / 120, left)
            left -= dt
            cues += step(dt)
        }
        return cues
    }

    private mutating func step(_ dt: Double) -> [ArcadeCue] {
        time += dt
        guard started else { y = HopRules.start + sin(time * 4) * 10; return [] }
        vy = min(HopRules.maxFall, vy + HopRules.gravity * dt)
        y = min(HopRules.ground - HopRules.radius, y + vy * dt)
        if crashed {
            crashTime += dt
            guard crashTime > 0.9 else { return [] }
            switch score {
            case 0: finishMessage = "bonk! one more hop?"
            case 1: finishMessage = "1 point. every hop counts."
            default: finishMessage = "\(score) points. what a hopper!"
            }
            message = finishMessage ?? ""
            return [.finished]
        }
        if y < HopRules.radius { y = HopRules.radius; vy = max(0, vy) }
        let move = HopRules.speed(score: score) * dt
        distance += move
        var cues: [ArcadeCue] = []
        for index in forks.indices {
            forks[index].x -= move
            let fork = forks[index]
            if !fork.passed, fork.x + HopRules.forkWidth < HopRules.pickleX - HopRules.radius {
                forks[index].passed = true
                score += 1
                cues.append(.ding)
            }
            if let heartY = fork.heartY, hypot(fork.heartX - HopRules.pickleX, heartY - y) < HopRules.radius + HopRules.heartRadius {
                forks[index].heartY = nil
                score += 1
                message = "heart! +1"
                cues.append(.good)
            }
        }
        forks.removeAll { $0.heartX < -40 }
        if let last = forks.last, last.x < ArcadeWorld.width + 60 - HopRules.spacing {
            forks.append(makeFork(at: last.x + HopRules.spacing, after: last.gapY))
        }
        if y + HopRules.radius >= HopRules.ground || forks.contains(where: hits) {
            crashed = true
            vy = -260
            message = "bonk!"
            cues.append(.miss)
        }
        return cues
    }

    private func hits(_ fork: HopFork) -> Bool {
        func touches(_ top: Double, _ bottom: Double) -> Bool {
            let x = min(max(HopRules.pickleX, fork.x), fork.x + HopRules.forkWidth)
            let y = min(max(self.y, top), bottom)
            return hypot(HopRules.pickleX - x, self.y - y) < HopRules.radius
        }
        return touches(-200, fork.top) || touches(fork.bottom, HopRules.ground)
    }

    private mutating func makeFork(at x: Double, after previous: Double) -> HopFork {
        let gap = HopRules.gap(score: score)
        let low = max(120, previous - 190), high = min(HopRules.ground - 120, previous + 190)
        let gapY = Double.random(in: low...high, using: &rng)
        var heart: Double?
        if score >= 2, Double.random(in: 0..<1, using: &rng) < 0.35 {
            heart = min(HopRules.ground - 60, max(60, gapY + Double.random(in: -120...120, using: &rng)))
        }
        return HopFork(x: x, gapY: gapY, gap: gap, heartY: heart)
    }
}

struct HopBoard: View {
    let run: HopRun
    let look: PickleLook
    let reduceMotion: Bool
    let hop: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let world = ArcadeWorld(proxy.size)
            Canvas { context, _ in draw(world.context(context)) }
                .frame(width: ArcadeWorld.width * world.scale, height: ArcadeWorld.height * world.scale)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .contentShape(Rectangle())
        .modifier(TouchDown(action: hop))
        .accessibilityElement()
        .accessibilityLabel("Pickle hop board")
        .accessibilityValue("\(run.score) points")
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityAction(named: "Hop", hop)
        .accessibilityIdentifier("arcade.hop.board")
    }

    private func draw(_ c: GraphicsContext) {
        let w = ArcadeWorld.width, ground = HopRules.ground
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: ArcadeWorld.height)),
               with: .linearGradient(Gradient(colors: [DillTheme.cream, DillTheme.sage]), startPoint: .zero, endPoint: CGPoint(x: 0, y: ground)))
        let drift = reduceMotion ? 0 : run.distance
        for n in 0..<4 {
            let raw = (Double(n) * 130 - drift * 0.08).truncatingRemainder(dividingBy: 520)
            let x = (raw < 0 ? raw + 520 : raw) - 80
            let y = 70 + Double(n % 2) * 70
            for (dx, r) in [(0.0, 18.0), (20, 24), (42, 16)] {
                c.fill(Path(ellipseIn: CGRect(x: x + dx - r, y: y - r, width: r * 2, height: r * 1.6)), with: .color(.white.opacity(0.75)))
            }
        }
        let hill = (drift * 0.3).truncatingRemainder(dividingBy: 120)
        for n in 0..<5 {
            let x = Double(n) * 120 - hill
            c.fill(Path(ellipseIn: CGRect(x: x - 20, y: ground - 60, width: 160, height: 120)), with: .color(Color(hex: 0xD9E5BE)))
        }
        for fork in run.forks {
            drawFork(c, fork)
            drawJar(c, fork)
            if let heartY = fork.heartY {
                ArcadeArt.heart(c, at: CGPoint(x: fork.heartX, y: heartY + sin(run.time * 3) * 4), size: HopRules.heartRadius * 2)
            }
        }
        c.fill(Path(CGRect(x: 0, y: ground, width: w, height: ArcadeWorld.height - ground)), with: .color(ArcadeArt.wood))
        c.fill(Path(CGRect(x: 0, y: ground, width: w, height: 4)), with: .color(ArcadeArt.ink))
        let stripe = drift.truncatingRemainder(dividingBy: 36)
        for n in 0..<12 {
            var line = Path()
            let x = Double(n) * 36 - stripe
            line.move(to: CGPoint(x: x, y: ground + 10)); line.addLine(to: CGPoint(x: x - 18, y: ArcadeWorld.height))
            c.stroke(line, with: .color(ArcadeArt.grain), lineWidth: 3)
        }
        drawPickle(c)
        if run.started {
            ArcadeArt.score(c, run.score, at: CGPoint(x: w / 2, y: 44), anchor: .center)
        } else {
            ArcadeArt.caption(c, "tap to hop", at: CGPoint(x: w / 2, y: HopRules.start + 70 + sin(run.time * 5) * 3), size: 22)
        }
    }

    private func drawFork(_ c: GraphicsContext, _ fork: HopFork) {
        let x = fork.x, w = HopRules.forkWidth, tip = fork.top
        let handle = Path(roundedRect: CGRect(x: x + w / 2 - 11, y: -20, width: 22, height: tip - 40), cornerRadius: 10)
        var head = Path(roundedRect: CGRect(x: x, y: tip - 72, width: w, height: 28), cornerRadius: 12)
        for n in 0..<4 {
            head.addRoundedRect(in: CGRect(x: x + 3 + Double(n) * 15.3, y: tip - 56, width: 11, height: 56), cornerSize: CGSize(width: 5.5, height: 5.5))
        }
        for path in [handle, head] {
            c.fill(path, with: .color(ArcadeArt.steel))
            c.stroke(path, with: .color(ArcadeArt.ink), lineWidth: 2.5)
        }
        c.fill(Path(roundedRect: CGRect(x: x + w / 2 - 5, y: -10, width: 4, height: tip - 90), cornerRadius: 2), with: .color(.white.opacity(0.7)))
    }

    private func drawJar(_ c: GraphicsContext, _ fork: HopFork) {
        let x = fork.x, w = HopRules.forkWidth, top = fork.bottom
        let body = Path(roundedRect: CGRect(x: x + 2, y: top + 10, width: w - 4, height: HopRules.ground - top), cornerRadius: 12)
        c.fill(body, with: .color(ArcadeArt.brine.opacity(0.8)))
        c.fill(Path(CGRect(x: x + 8, y: top + 34, width: w - 16, height: 3)), with: .color(.white.opacity(0.6)))
        c.fill(Path(ellipseIn: CGRect(x: x + 14, y: top + 50, width: 14, height: 40)), with: .color(Color(hex: 0x7FA24A)))
        c.fill(Path(ellipseIn: CGRect(x: x + 34, y: top + 64, width: 14, height: 44)), with: .color(Color(hex: 0x6E9440)))
        c.stroke(body, with: .color(ArcadeArt.ink), lineWidth: 3)
        c.fill(Path(roundedRect: CGRect(x: x - 3, y: top, width: w + 6, height: 14), cornerRadius: 5), with: .color(ArcadeArt.ink))
    }

    private func drawPickle(_ c: GraphicsContext) {
        var pose = PicklePose()
        let flap = max(0, 1 - (run.time - run.lastHop) / 0.22)
        pose.armLeft = -10 + 80 * flap
        pose.armRight = 10 - 80 * flap
        if run.crashed {
            pose.eyes = .sickX; pose.mouth = .scaredO
        } else if run.vy > 450 {
            pose.eyes = .wide; pose.mouth = .scaredO
        } else if flap > 0 {
            pose.eyes = .happy; pose.mouth = .grin
        }
        let tilt = run.started ? min(75, max(-25, run.vy / 12)) : 0
        ArcadeArt.pet(c, look: look, pose: pose, at: CGPoint(x: HopRules.pickleX, y: run.y), height: 50, angle: .degrees(tilt))
    }
}
