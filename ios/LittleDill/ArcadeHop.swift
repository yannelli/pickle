import SwiftUI

enum HopRules {
    static let ground = 482.0, pickleX = 90.0, restY = 458.0
    static let gravity = 1600.0, jumpSpeed = -610.0, maxFall = 820.0
    static let firstX = ArcadeWorld.width + 72
    static let landingBuffer = 0.12
    static let zoneLength = 840.0
    static func speed(cleared: Int) -> Double { min(228, 174 + Double(cleared) * 3) }
}

struct HopObstacle: Equatable {
    enum Kind: CaseIterable, Equatable { case salt, fork, pepper, spoon }
    let kind: Kind
    var x: Double
    var passed = false
    var hasDill: Bool
    var dillOffset = 0.0
    var dillY = 350.0
    var width: Double {
        switch kind {
        case .salt: return 42
        case .fork: return 36
        case .pepper: return 39
        case .spoon: return 59
        }
    }
    var height: Double {
        switch kind {
        case .salt: return 25
        case .fork: return 59
        case .pepper: return 47
        case .spoon: return 23
        }
    }
    var dillX: Double { x + width / 2 + dillOffset }
}

struct HopRun: ArcadePlay {
    let game = ArcadeGame.hop
    private(set) var score = 0
    private(set) var message = "the jar is open. tap to jump!"
    private(set) var finishMessage: String?
    private(set) var y = HopRules.restY
    private(set) var vy = 0.0
    private(set) var obstacles = [HopObstacle(kind: .salt, x: HopRules.firstX, hasDill: false)]
    private(set) var started = false
    private(set) var crashed = false
    private(set) var time = 0.0
    private(set) var lastHop = -1.0
    private(set) var distance = 0.0
    private(set) var cleared = 0
    private(set) var streak = 0
    private(set) var lastLanding = -1.0
    private(set) var lastCollect = -1.0
    let scenerySeed: UInt64
    private var crashTime = 0.0
    private var queuedUntil = -1.0
    private var rng: ArcadeRNG

    init(seed: UInt64) {
        scenerySeed = seed
        rng = ArcadeRNG(seed: seed)
    }

    var isFinished: Bool { finishMessage != nil }
    func meta(best: Int) -> String { "\(score) PTS · BEST \(best)" }

    mutating func hop() -> [ArcadeCue] {
        guard !crashed, !isFinished else { return [] }
        if !started {
            started = true
            message = "jump the kitchen clutter · grab dill!"
        }
        if y >= HopRules.restY - 0.5, vy >= 0 { return jump() }
        queuedUntil = time + HopRules.landingBuffer
        return []
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

    private mutating func jump() -> [ArcadeCue] {
        vy = HopRules.jumpSpeed
        lastHop = time
        queuedUntil = -1
        return [.hop]
    }

    private mutating func step(_ dt: Double) -> [ArcadeCue] {
        time += dt
        guard started else { return [] }
        vy = min(HopRules.maxFall, vy + HopRules.gravity * dt)
        y = min(HopRules.restY, y + vy * dt)
        if crashed {
            crashTime += dt
            if crashTime > 0.8 {
                finishMessage = score == 0 ? "back to the jar?" : "\(score) points · try another escape!"
                message = finishMessage ?? ""
                return [.finished]
            }
            return []
        }
        var cues: [ArcadeCue] = []
        if y >= HopRules.restY, vy > 0 {
            vy = 0
            lastLanding = time
            cues.append(.landing)
            if queuedUntil >= time { cues += jump() }
        }
        let move = HopRules.speed(cleared: cleared) * dt
        distance += move
        for index in obstacles.indices {
            obstacles[index].x -= move
            let obstacle = obstacles[index]
            if hits(obstacle) {
                crashed = true
                vy = -205
                streak = 0
                message = "bonk!"
                cues.append(.bonk)
                break
            }
            if obstacle.hasDill, hypot(obstacle.dillX - HopRules.pickleX, obstacle.dillY - y) < 24 {
                obstacles[index].hasDill = false
                lastCollect = time
                streak += 1
                let bonus = streak % 3 == 0 ? 4 : 2
                score += bonus
                message = streak % 3 == 0 ? "dill streak! +4" : "dill sprig! +2"
                cues.append(streak % 3 == 0 ? .streak : .good)
            }
            if !obstacle.passed, obstacle.x + obstacle.width < HopRules.pickleX - 14 {
                obstacles[index].passed = true
                cleared += 1
                score += 1
                cues.append(.ding)
            }
        }
        obstacles.removeAll { $0.x + $0.width < -50 }
        if !crashed, let last = obstacles.last, last.x < ArcadeWorld.width - 148 {
            var next = makeObstacle(after: last.kind)
            let tall = last.height > 40 || next.height > 40
            let rhythm = Int.random(in: 0..<5, using: &rng)
            let gap: Double
            switch rhythm {
            case 0, 1: gap = Double.random(in: (tall ? 218.0 : 170.0)...(tall ? 240.0 : 193.0), using: &rng)
            case 2, 3: gap = Double.random(in: 211...254, using: &rng)
            default: gap = Double.random(in: 275...320, using: &rng)
            }
            next.x = last.x + gap
            obstacles.append(next)
        }
        return cues
    }

    private func hits(_ obstacle: HopObstacle) -> Bool {
        let inset = obstacle.kind == .salt || obstacle.kind == .spoon ? 7.0 : 4.0
        let left = obstacle.x + inset, right = obstacle.x + obstacle.width - inset
        return HopRules.pickleX + 13 > left && HopRules.pickleX - 13 < right
            && y + 19 > HopRules.ground - obstacle.height + 3
    }

    private mutating func makeObstacle(after previous: HopObstacle.Kind) -> HopObstacle {
        let choices = HopObstacle.Kind.allCases.filter { $0 != previous }
        let kind = choices[Int.random(in: 0..<choices.count, using: &rng)]
        let hasDill = Int.random(in: 0..<4, using: &rng) != 0
        let offset = [-72.0, -48.0, 0.0][Int.random(in: 0..<3, using: &rng)]
        let dillY = offset < 0 ? 385.0 : 350.0
        let obstacle = HopObstacle(kind: kind, x: 0, hasDill: hasDill, dillOffset: offset, dillY: dillY)
        return obstacle
    }
}

struct HopBoard: View {
    let run: HopRun
    let look: PickleLook
    let reduceMotion: Bool
    let hop: () -> Void

    var body: some View {
        Canvas { context, size in
            let scale = size.width / ArcadeWorld.width
            var world = context
            world.scaleBy(x:scale,y:scale)
            draw(world,height:size.height / scale)
        }
        .clipShape(RoundedRectangle(cornerRadius:24,style:.continuous))
        .contentShape(Rectangle())
        .modifier(TouchDown(action: hop))
        .accessibilityElement()
        .accessibilityLabel("Countertop escape. Tap to jump over kitchen obstacles. Collect dill sprigs for streaks.")
        .accessibilityValue("\(run.score) points")
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityAction(named: "Jump", hop)
        .accessibilityIdentifier("arcade.hop.board")
    }

    private func draw(_ c: GraphicsContext,height:Double) {
        let w = ArcadeWorld.width
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: height)), with: .color(Color(hex: 0xF6F0DD)))
        HopScenery.draw(c, height: height, distance: run.distance, seed: run.scenerySeed, reduceMotion: reduceMotion)
        var play = c
        play.translateBy(x:0,y:height - ArcadeWorld.height)
        drawJar(play)
        drawCounter(play)
        for obstacle in run.obstacles {
            switch obstacle.kind {
            case .salt: drawSalt(play, obstacle)
            case .fork: drawFork(play, obstacle)
            case .pepper: drawPepper(play, obstacle)
            case .spoon: drawSpoon(play, obstacle)
            }
            if obstacle.hasDill { drawDill(play, obstacle) }
        }
        drawPickle(play)
        if run.started {
            ArcadeArt.score(c, run.score, at: CGPoint(x: w / 2, y: 30), anchor: .center)
            if run.streak >= 2 {
                ArcadeArt.caption(c, "\(run.streak) sprigs", at: CGPoint(x: 61, y: 31), size: 12)
            }
        } else {
            c.draw(Text("the great pickle escape")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(ArcadeArt.ink), at: CGPoint(x: w / 2, y: max(212,(height + 60) / 2 - 20)))
            ArcadeArt.caption(c, "tap to jump", at: CGPoint(x: w / 2, y: max(245,(height + 60) / 2 + 13)), size: 16)
        }
    }

    private func drawJar(_ c: GraphicsContext) {
        let x = 18 - run.distance
        guard x > -100 else { return }
        let glass = Path(roundedRect: CGRect(x: x, y: 356, width: 78, height: 123), cornerRadius: 17)
        c.fill(glass, with: .color(Color(hex: 0xD6EAB7).opacity(0.68)))
        c.stroke(glass, with: .color(ArcadeArt.ink), lineWidth: 3)
        let rim = Path(ellipseIn: CGRect(x: x - 3, y: 347, width: 84, height: 20))
        c.fill(rim, with: .color(Color(hex: 0xF4F8DC)))
        c.stroke(rim, with: .color(ArcadeArt.ink), lineWidth: 3)
        c.fill(Path(ellipseIn: CGRect(x: x + 8, y: 352, width: 62, height: 9)), with: .color(Color(hex: 0xA8C874)))
        c.fill(Path(roundedRect: CGRect(x: x + 10, y: 376, width: 58, height: 62), cornerRadius: 8), with: .color(Color(hex: 0xFFF9DE)))
        c.draw(Text("DILL")
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(ArcadeArt.ink), at: CGPoint(x: x + 39, y: 407))
        c.stroke(Path(roundedRect: CGRect(x: x + 9, y: 361, width: 10, height: 78), cornerRadius: 5), with: .color(.white.opacity(0.8)), lineWidth: 3)
    }

    private func drawCounter(_ c: GraphicsContext) {
        c.fill(Path(CGRect(x: 0, y: HopRules.ground, width: 360, height: 98)), with: .color(Color(hex: 0xE7CBA0)))
        c.fill(Path(CGRect(x: 0, y: HopRules.ground - 8, width: 360, height: 11)), with: .color(Color(hex: 0xF7DEA9)))
        c.stroke(Path(CGRect(x: 0, y: HopRules.ground - 8, width: 360, height: 12)), with: .color(ArcadeArt.ink), lineWidth: 3)
        let shift = reduceMotion ? 0 : run.distance.truncatingRemainder(dividingBy: 82)
        for n in 0..<6 {
            let x = Double(n) * 82 - shift
            var grain = Path()
            grain.move(to: CGPoint(x: x, y: 518))
            grain.addCurve(to: CGPoint(x: x + 59, y: 518), control1: CGPoint(x: x + 16, y: 510), control2: CGPoint(x: x + 36, y: 526))
            c.stroke(grain, with: .color(ArcadeArt.grain), lineWidth: 2)
            c.fill(Path(ellipseIn: CGRect(x: x + 26, y: 548, width: 16, height: 5)), with: .color(ArcadeArt.grain))
        }
    }

    private func drawSalt(_ c: GraphicsContext, _ obstacle: HopObstacle) {
        let x = obstacle.x, y = HopRules.ground
        var mound = Path()
        mound.move(to: CGPoint(x: x, y: y))
        mound.addQuadCurve(to: CGPoint(x: x + 42, y: y), control: CGPoint(x: x + 20, y: y - 51))
        mound.closeSubpath()
        c.fill(mound, with: .color(Color(hex: 0xFFFDF0)))
        c.stroke(mound, with: .color(ArcadeArt.ink), lineWidth: 3)
        for (dx, dy) in [(12.0, -10.0), (22, -17), (30, -8)] {
            c.fill(Path(ellipseIn: CGRect(x: x + dx, y: y + dy, width: 3, height: 3)), with: .color(Color(hex: 0xC9C5B2)))
        }
    }

    private func drawFork(_ c: GraphicsContext, _ obstacle: HopObstacle) {
        let x = obstacle.x, y = HopRules.ground
        var shape = Path()
        shape.move(to: CGPoint(x: x + 16, y: y))
        shape.addQuadCurve(to: CGPoint(x: x + 13, y: y - 4), control: CGPoint(x: x + 13, y: y))
        shape.addLine(to: CGPoint(x: x + 13, y: y - 30))
        shape.addCurve(to: CGPoint(x: x + 2, y: y - 43), control1: CGPoint(x: x + 13, y: y - 36), control2: CGPoint(x: x + 3, y: y - 37))
        for start in [2.0, 11.0, 20.0, 29.0] {
            shape.addLine(to: CGPoint(x: x + start, y: y - 57))
            shape.addQuadCurve(to: CGPoint(x: x + start + 4, y: y - 57), control: CGPoint(x: x + start + 2, y: y - 61))
            if start < 29 {
                shape.addLine(to: CGPoint(x: x + start + 5, y: y - 44))
                shape.addQuadCurve(to: CGPoint(x: x + start + 9, y: y - 44), control: CGPoint(x: x + start + 7, y: y - 41))
            }
        }
        shape.addLine(to: CGPoint(x: x + 33, y: y - 43))
        shape.addCurve(to: CGPoint(x: x + 22, y: y - 30), control1: CGPoint(x: x + 33, y: y - 37), control2: CGPoint(x: x + 22, y: y - 36))
        shape.addLine(to: CGPoint(x: x + 22, y: y - 4))
        shape.addQuadCurve(to: CGPoint(x: x + 19, y: y), control: CGPoint(x: x + 22, y: y))
        shape.closeSubpath()
        c.fill(shape, with: .color(ArcadeArt.steel))
        c.stroke(shape, with: .color(ArcadeArt.ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        var gleam = Path()
        gleam.move(to: CGPoint(x: x + 17, y: y - 5))
        gleam.addLine(to: CGPoint(x: x + 17, y: y - 28))
        gleam.addQuadCurve(to: CGPoint(x: x + 11, y: y - 38), control: CGPoint(x: x + 17, y: y - 34))
        c.stroke(gleam, with: .color(.white.opacity(0.78)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    private func drawPepper(_ c: GraphicsContext, _ obstacle: HopObstacle) {
        let x = obstacle.x, y = HopRules.ground
        let body = Path(roundedRect: CGRect(x: x + 4, y: y - 38, width: 31, height: 38), cornerRadius: 9)
        c.fill(body, with: .color(Color(hex: 0xA45842)))
        c.stroke(body, with: .color(ArcadeArt.ink), lineWidth: 2.5)
        c.fill(Path(roundedRect: CGRect(x: x + 7, y: y - 47, width: 25, height: 13), cornerRadius: 5), with: .color(Color(hex: 0xD4D7CF)))
        c.stroke(Path(roundedRect: CGRect(x: x + 7, y: y - 47, width: 25, height: 13), cornerRadius: 5), with: .color(ArcadeArt.ink), lineWidth: 2)
        c.fill(Path(roundedRect: CGRect(x: x + 10, y: y - 26, width: 19, height: 14), cornerRadius: 3), with: .color(Color(hex: 0xF6E6CA)))
        c.draw(Text("P").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(ArcadeArt.ink), at: CGPoint(x: x + 19.5, y: y - 19))
        for dx in [14.0, 20.0, 26.0] {
            c.fill(Path(ellipseIn: CGRect(x: x + dx, y: y - 43, width: 2.5, height: 2.5)), with: .color(ArcadeArt.ink))
        }
    }

    private func drawSpoon(_ c: GraphicsContext, _ obstacle: HopObstacle) {
        let x = obstacle.x, y = HopRules.ground
        var spoon = Path()
        spoon.move(to: CGPoint(x: x + 22, y: y - 10))
        spoon.addLine(to: CGPoint(x: x + 56, y: y - 4))
        spoon.addQuadCurve(to: CGPoint(x: x + 56, y: y - 1), control: CGPoint(x: x + 61, y: y - 2))
        spoon.addLine(to: CGPoint(x: x + 21, y: y - 6))
        spoon.closeSubpath()
        c.fill(spoon, with: .color(ArcadeArt.steel))
        c.stroke(spoon, with: .color(ArcadeArt.ink), lineWidth: 2)
        let bowl = Path(ellipseIn: CGRect(x: x, y: y - 23, width: 30, height: 19))
        c.fill(bowl, with: .color(ArcadeArt.steel))
        c.stroke(bowl, with: .color(ArcadeArt.ink), lineWidth: 2.5)
        c.stroke(Path(ellipseIn: CGRect(x: x + 5, y: y - 19, width: 17, height: 9)), with: .color(.white.opacity(0.75)), lineWidth: 1.5)
    }

    private func drawDill(_ c: GraphicsContext, _ obstacle: HopObstacle) {
        let x = obstacle.dillX, y = obstacle.dillY
        let stem = Path { p in p.move(to: CGPoint(x: x, y: y + 12)); p.addLine(to: CGPoint(x: x, y: y - 12)) }
        c.stroke(stem, with: .color(Color(hex: 0x397547)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        for side in [-1.0, 1.0] {
            for level in 0..<3 {
                let dy = Double(level) * 7 - 9
                let leaf = Path(ellipseIn: CGRect(x: x + side * 9 - 5, y: y + dy - 4, width: 10, height: 6))
                c.fill(leaf, with: .color(Color(hex: 0x5E9F55)))
                c.stroke(leaf, with: .color(Color(hex: 0x397547)), lineWidth: 1)
            }
        }
    }

    private func drawPickle(_ c: GraphicsContext) {
        var pose = PicklePose()
        let airborne = run.y < HopRules.restY - 1
        let stride = reduceMotion ? 0 : sin(run.time * 17) * 18
        pose.armLeft = airborne ? -65 : -12 + stride
        pose.armRight = airborne ? 65 : 12 - stride
        if run.crashed {
            pose.eyes = .sickX; pose.mouth = .scaredO
        } else if airborne {
            pose.eyes = .happy; pose.mouth = .grin
        }
        let shadowWidth = max(18, 39 - (HopRules.restY - run.y) * 0.18)
        c.fill(Path(ellipseIn: CGRect(x: HopRules.pickleX - shadowWidth / 2, y: HopRules.ground - 4, width: shadowWidth, height: 7)), with: .color(ArcadeArt.ink.opacity(0.2)))
        if !reduceMotion, run.time - run.lastLanding < 0.18 {
            let progress = (run.time - run.lastLanding) / 0.18
            let width = 28 + progress * 24
            c.stroke(Path(ellipseIn: CGRect(x: HopRules.pickleX - width / 2, y: HopRules.ground - 6, width: width, height: 9)), with: .color(Color(hex: 0xFFF1B5).opacity(1 - progress)), lineWidth: 3)
        }
        let tilt = reduceMotion ? 0 : (airborne ? max(-14, min(12, run.vy / 24)) : 0)
        let landing = !reduceMotion && run.time - run.lastLanding < 0.09
        ArcadeArt.pet(c, look: look, pose: pose, at: CGPoint(x: HopRules.pickleX, y: run.y + (landing ? 3 : 0)), height: landing ? 49 : 54, angle: .degrees(tilt))
        if !reduceMotion, run.time - run.lastCollect < 0.3 {
            let progress = (run.time - run.lastCollect) / 0.3
            for side in [-1.0, 1.0] {
                let x = HopRules.pickleX + side * (27 + progress * 15)
                c.fill(Path(ellipseIn: CGRect(x: x - 3, y: run.y - 24 - progress * 12, width: 6, height: 6)), with: .color(Color(hex: 0xF7D26A).opacity(1 - progress)))
            }
        }
    }
}
