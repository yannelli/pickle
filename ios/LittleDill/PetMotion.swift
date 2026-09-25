import Foundation

// Ports the web pet's CSS keyframes (index.html) to poses sampled from one clock.
enum PetMood: String { case idle, happy, hungry, sick, sleeping, scared, dead }

enum PetVibe: String, CaseIterable { case hop, shades, lounge, fire, book }

enum PetAct: String {
    case hop, look, stretch, wiggle, turn, munch, shimmy, bitten, wake, yawn
    var duration: Double {
        switch self {
        case .hop: return 0.65
        case .look: return 1.8
        case .stretch: return 1.1
        case .wiggle: return 0.55
        case .turn: return 2.2
        case .munch: return 1.1
        case .shimmy: return 0.7
        case .bitten: return 0.5
        case .wake: return 0.9
        case .yawn: return 1.2
        }
    }
    /// IDLE_ACTS in index.html.
    static func idleChoices(for mood: PetMood) -> [PetAct] {
        switch mood {
        case .idle: return [.hop, .look, .stretch, .wiggle, .turn]
        case .happy: return [.look]
        case .hungry: return [.look, .wiggle]
        case .sick: return [.wiggle]
        default: return []
        }
    }
}

/// A CSS-style transform about the bottom centre: translate, then rotate (degrees), then scale.
struct Motion: Equatable {
    var x = 0.0, y = 0.0, rotation = 0.0, sx = 1.0, sy = 1.0
    static let identity = Motion()
    func mix(_ other: Motion, _ t: Double) -> Motion {
        Motion(x: x + (other.x - x) * t, y: y + (other.y - y) * t, rotation: rotation + (other.rotation - rotation) * t,
               sx: sx + (other.sx - sx) * t, sy: sy + (other.sy - sy) * t)
    }
}

enum EyeStyle { case open, happy, squint, closed, wide, reading, sickX }
enum MouthStyle { case smile, grin, frown, sleepO, scaredO, yawnO, chew }

struct PicklePose: Equatable {
    var actor = Motion.identity
    var body = Motion.identity
    var armLeft = -14.0, armRight = 14.0
    var blink = 1.0
    var faceX = 0.0
    var eyes = EyeStyle.open
    var mouth = MouthStyle.smile
    var mouthOpen = 1.0
    var cheek = 1.0
    var shadowX = 0.0, shadowScale = 1.0, shadowOpacity = 1.0
    var sweat: Double?

    func mix(_ other: PicklePose, _ t: Double) -> PicklePose {
        func m(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        var out = t < 0.5 ? self : other
        out.actor = actor.mix(other.actor, t); out.body = body.mix(other.body, t)
        out.armLeft = m(armLeft, other.armLeft); out.armRight = m(armRight, other.armRight)
        out.blink = m(blink, other.blink); out.faceX = m(faceX, other.faceX)
        out.mouthOpen = m(mouthOpen, other.mouthOpen); out.cheek = m(cheek, other.cheek)
        out.shadowX = m(shadowX, other.shadowX); out.shadowScale = m(shadowScale, other.shadowScale)
        out.shadowOpacity = m(shadowOpacity, other.shadowOpacity)
        return out
    }
}

enum Ease {
    /// CSS cubic-bezier(x1, y1, x2, y2) solved for progress `t`.
    static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ t: Double) -> Double {
        let t = min(1, max(0, t))
        func curve(_ a: Double, _ b: Double, _ s: Double) -> Double { 3 * a * (1 - s) * (1 - s) * s + 3 * b * (1 - s) * s * s + s * s * s }
        var s = t
        for _ in 0..<8 {
            let x = curve(x1, x2, s) - t
            let dx = 3 * x1 * (1 - s) * (1 - s) + 6 * (x2 - x1) * (1 - s) * s + 3 * (1 - x2) * s * s
            if abs(x) < 1e-5 || dx == 0 { break }
            s = min(1, max(0, s - x / dx))
        }
        return curve(y1, y2, s)
    }
    static func inOut(_ t: Double) -> Double { bezier(0.42, 0, 0.58, 1, t) }
    static func out(_ t: Double) -> Double { bezier(0, 0, 0.58, 1, t) }
    static func linear(_ t: Double) -> Double { t }
    static func springy(_ t: Double) -> Double { bezier(0.3, 0.7, 0.4, 1.1, t) }
}

/// Keyframes with the timing function applied to each interval, like a CSS animation.
struct Keys<Value> {
    let frames: [(Double, Value)]
    let ease: (Double) -> Double
    let mix: (Value, Value, Double) -> Value
    func at(_ progress: Double) -> Value {
        let p = min(1, max(0, progress))
        var previous = frames[0]
        for frame in frames.dropFirst() {
            if p <= frame.0 {
                let span = frame.0 - previous.0
                return mix(previous.1, frame.1, span <= 0 ? 1 : ease((p - previous.0) / span))
            }
            previous = frame
        }
        return previous.1
    }
}

enum PetMotion {
    static func motion(_ frames: [(Double, Motion)], ease: @escaping (Double) -> Double = Ease.inOut) -> Keys<Motion> {
        Keys(frames: frames, ease: ease) { a, b, t in a.mix(b, t) }
    }
    static func number(_ frames: [(Double, Double)], ease: @escaping (Double) -> Double = Ease.inOut) -> Keys<Double> {
        Keys(frames: frames, ease: ease) { a, b, t in a + (b - a) * t }
    }
    static func loop(_ time: Double, _ period: Double, delay: Double = 0) -> Double {
        let value = (time - delay).truncatingRemainder(dividingBy: period) / period
        return value < 0 ? value + 1 : value
    }

    static let idle = motion([(0, .identity), (0.5, Motion(sx: 1.04, sy: 0.965)), (1, .identity)])
    static let happy = motion([(0, Motion(sx: 1.1, sy: 0.88)), (0.18, Motion(y: -3, sx: 0.92, sy: 1.1)), (0.5, Motion(y: -12, rotation: -3, sx: 0.98, sy: 1.02)),
                               (0.78, Motion(y: -3, rotation: 3)), (0.9, Motion(sx: 1.12, sy: 0.86)), (1, Motion(sx: 1.1, sy: 0.88))])
    static let lounge = motion([(0, Motion(x: -6, rotation: -16, sx: 1.03, sy: 0.97)), (0.5, Motion(x: -6, rotation: -16)), (1, Motion(x: -6, rotation: -16, sx: 1.03, sy: 0.97))])
    static let hungry: Keys<Motion> = {
        let slump = Motion(y: 3, rotation: -6, sx: 1.03, sy: 0.96)
        var left = slump, right = slump
        left.x = -2; right.x = 2
        return motion([(0, Motion(y: 3, rotation: -7, sx: 1.03, sy: 0.96)), (0.4, Motion(y: 4, rotation: -4, sx: 1.05, sy: 0.94)), (0.7, slump),
                       (0.74, left), (0.78, right), (0.82, left), (0.86, right), (0.9, slump), (1, Motion(y: 3, rotation: -7, sx: 1.03, sy: 0.96))])
    }()
    static let sick = motion([(0, Motion(x: -2, rotation: -7)), (0.25, Motion(y: 2)), (0.5, Motion(x: 2, rotation: 7)), (0.75, Motion(y: 2)), (1, Motion(x: -2, rotation: -7))])
    static let sleep = motion([(0, Motion(rotation: -12, sx: 1.02, sy: 0.96)), (0.5, Motion(rotation: -12, sx: 0.99, sy: 1.01)), (1, Motion(rotation: -12, sx: 1.02, sy: 0.96))])
    static let tremble = motion([(0, Motion(x: -1.5, rotation: -2)), (0.5, Motion(x: 1.5, rotation: 2)), (1, Motion(x: -1.5, rotation: -2))], ease: Ease.linear)
    static let blink = number([(0, 1), (0.93, 1), (0.955, 0.12), (0.975, 0.12), (1, 1)], ease: Ease.linear)
    static let swing = number([(0, 0), (0.5, 1), (1, 0)])

    static func act(_ act: PetAct) -> Keys<Motion> {
        switch act {
        case .hop:
            return motion([(0, Motion(sx: 1.08, sy: 0.92)), (0.25, Motion(y: -4, sx: 0.94, sy: 1.08)), (0.55, Motion(y: -12)), (0.85, Motion(sx: 1.1, sy: 0.9)), (1, .identity)], ease: Ease.springy)
        case .wiggle:
            return motion([(0, .identity), (0.2, Motion(x: -2, rotation: -9)), (0.4, Motion(x: 2, rotation: 8)), (0.6, Motion(x: -1, rotation: -6)), (0.8, Motion(x: 1, rotation: 5)), (1, .identity)])
        case .stretch:
            return motion([(0, .identity), (0.35, Motion(sx: 0.94, sy: 1.09)), (0.65, Motion(sx: 0.94, sy: 1.09)), (1, .identity)])
        case .yawn:
            return motion([(0, .identity), (0.3, Motion(rotation: -3, sx: 0.95, sy: 1.07)), (0.7, Motion(rotation: -3, sx: 0.95, sy: 1.07)), (1, .identity)])
        case .look:
            return motion([(0, .identity), (0.2, Motion(rotation: -4)), (0.45, Motion(rotation: -4)), (0.6, Motion(rotation: 4)), (0.85, Motion(rotation: 4)), (1, .identity)])
        case .turn:
            return motion([(0, .identity), (0.2, Motion(sx: -1)), (0.75, Motion(sx: -1)), (1, .identity)])
        case .munch:
            let squash = Motion(sx: 1.05, sy: 0.95), stretch = Motion(sx: 0.98, sy: 1.02)
            return motion([(0, .identity), (0.1, squash), (0.2, stretch), (0.3, squash), (0.4, stretch), (0.5, squash), (0.6, stretch), (0.7, squash), (0.8, stretch), (0.9, squash), (1, .identity)])
        case .shimmy:
            return motion([(0, .identity), (0.15, Motion(rotation: -12, sx: 1.04, sy: 0.97)), (0.3, Motion(rotation: 11)), (0.45, Motion(rotation: -9)),
                           (0.6, Motion(rotation: 7)), (0.75, Motion(rotation: -4)), (0.9, Motion(rotation: 2)), (1, .identity)])
        case .bitten:
            return motion([(0, .identity), (0.15, Motion(x: -7, rotation: -10, sx: 1.08, sy: 0.9)), (0.4, Motion(x: 5, rotation: 6)), (0.65, Motion(x: -3, rotation: -3)), (1, .identity)], ease: Ease.out)
        case .wake:
            return motion([(0, Motion(sx: 1.1, sy: 0.9)), (0.3, Motion(y: -9, sx: 0.95, sy: 1.08)), (0.55, Motion(sx: 1.08, sy: 0.93)), (0.75, Motion(sx: 0.98, sy: 1.02)), (1, .identity)])
        }
    }

    /// The looping mood pose (`.pet-body`) with any act (`.pet-actor`) layered on top.
    static func pose(mood: PetMood, vibe: PetVibe?, act: PetAct?, actElapsed: Double, time: Double, reduceMotion: Bool) -> PicklePose {
        var pose = PicklePose()
        let still = reduceMotion
        func swing(_ period: Double) -> Double { still ? 0 : PetMotion.swing.at(loop(time, period)) }
        pose.blink = blink.at(loop(time, mood == .hungry ? 6 : 4.4))
        switch mood {
        case .idle, .dead:
            pose.body = still ? .identity : idle.at(loop(time, 2.6))
            pose.armLeft = -14 - 10 * swing(2.6); pose.armRight = 14 + 10 * swing(2.6)
            pose.shadowScale = 1 + 0.06 * swing(2.6)
        case .happy:
            switch vibe ?? .hop {
            case .hop:
                pose.body = still ? .identity : happy.at(loop(time, 0.72))
                pose.armLeft = 70 + 30 * swing(0.72); pose.armRight = -70 - 30 * swing(0.72)
                pose.shadowScale = 1.1 - 0.38 * swing(0.72); pose.shadowOpacity = 1 - 0.45 * swing(0.72)
            case .shades, .book, .fire:
                pose.body = still ? .identity : idle.at(loop(time, 2.6))
                pose.shadowScale = 1 + 0.06 * swing(2.6)
                if vibe == .book { pose.armLeft = 100; pose.armRight = -100; pose.eyes = .reading }
                else if vibe == .fire { pose.armLeft = 20; pose.armRight = -14 - 10 * swing(2.6) }
                else { pose.armLeft = -14 - 10 * swing(2.6); pose.armRight = 14 + 10 * swing(2.6) }
            case .lounge:
                pose.body = still ? Motion(rotation: -16) : lounge.at(loop(time, 3.4))
                pose.armLeft = -40; pose.armRight = 40
                pose.shadowX = -8; pose.shadowScale = 1.15
            }
            if pose.eyes != .reading { pose.eyes = .happy }
            pose.mouth = .grin; pose.cheek = 1.3
        case .hungry:
            pose.body = still ? Motion(y: 3, rotation: -6) : hungry.at(loop(time, 3.2))
            pose.armLeft = -38; pose.armRight = 38
            pose.eyes = .squint; pose.mouth = .frown
        case .sick:
            pose.body = still ? .identity : sick.at(loop(time, 1.6))
            pose.armLeft = -70; pose.armRight = 70
            pose.eyes = .sickX; pose.mouth = .frown
            pose.shadowX = still ? 0 : -3 + 6 * swing(1.6)
            pose.sweat = still ? 0.2 : loop(time, 1.6)
        case .sleeping:
            pose.body = still ? Motion(rotation: -12) : sleep.at(loop(time, 3.4))
            pose.armLeft = -42; pose.armRight = 42
            pose.eyes = .closed; pose.mouth = .sleepO; pose.blink = 1
            pose.shadowScale = 1.08
        case .scared:
            pose.body = still ? .identity : tremble.at(loop(time, 0.16))
            pose.armLeft = -62; pose.armRight = 62
            pose.eyes = .wide; pose.mouth = .scaredO; pose.cheek = 0.55; pose.blink = 1
            pose.sweat = still ? 0.2 : loop(time, 0.9)
        }
        guard let act, !still, actElapsed >= 0, actElapsed < act.duration else { return pose }
        let progress = actElapsed / act.duration
        pose.actor = PetMotion.act(act).at(progress)
        switch act {
        case .hop, .wake:
            pose.shadowScale *= 1 - 0.3 * sin(progress * .pi); pose.shadowOpacity *= 1 - 0.4 * sin(progress * .pi)
        case .stretch, .yawn:
            pose.eyes = .closed; pose.mouth = .yawnO
        case .look:
            pose.faceX = PetMotion.motion([(0, .identity), (0.2, Motion(x: -3)), (0.45, Motion(x: -3)), (0.6, Motion(x: 3)), (0.85, Motion(x: 3)), (1, .identity)]).at(progress).x
        case .munch:
            pose.mouth = .chew; pose.mouthOpen = Int(actElapsed / 0.11) % 2 == 0 ? 1 : 0.3; pose.cheek = 1.3
        case .bitten:
            pose.eyes = .wide; pose.mouth = .scaredO
        default: break
        }
        return pose
    }
}
