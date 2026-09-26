import UIKit

enum ArenaFeedbackCue: CaseIterable, Equatable {
    case stick, edge, dash, split, bite, eaten, regroup, ready
    case slicer, shaker, grater, pickup, feast, threat

    fileprivate var cooldown: TimeInterval {
        switch self {
        case .stick: 0.14
        case .edge: 0.35
        case .dash: 0.55
        case .split: 0.6
        case .bite: 0.2
        case .eaten: 0.8
        case .regroup: 0.5
        case .ready: 0.8
        case .slicer: 0.32
        case .shaker: 0.22
        case .grater: 0.35
        case .pickup: 0.9
        case .feast: 0.9
        case .threat: 3
        }
    }

    fileprivate var pulses: [ArenaFeedbackPulse] {
        switch self {
        case .stick: [(.light, 0.28, 0)]
        case .edge: [(.rigid, 0.45, 0)]
        case .dash: [(.rigid, 0.8, 0), (.soft, 0.24, 75)]
        case .split: [(.rigid, 0.75, 0), (.rigid, 0.55, 85)]
        case .bite: [(.rigid, 0.62, 0), (.soft, 0.32, 55)]
        case .eaten: [(.heavy, 1, 0), (.rigid, 0.58, 85)]
        case .regroup: [(.soft, 0.52, 0), (.soft, 0.3, 70)]
        case .ready: [(.light, 0.38, 0)]
        case .slicer: [(.rigid, 0.28, 0)]
        case .shaker: [(.soft, 0.23, 0), (.soft, 0.18, 65)]
        case .grater: [(.light, 0.28, 0), (.rigid, 0.2, 45)]
        case .pickup: [(.light, 0.32, 0)]
        case .feast: [(.light, 0.5, 0), (.soft, 0.25, 65)]
        case .threat: [(.rigid, 0.42, 0)]
        }
    }

    fileprivate var isGadget: Bool {
        switch self {
        case .slicer, .shaker, .grater: return true
        default: return false
        }
    }
}

fileprivate typealias ArenaFeedbackPulse = (style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat, delay: Int)

struct ArenaFeedbackEvents {
    private var primed = false
    private var gadgetPrimed = false
    private var threatArmed = true
    private var lastPickupAt = -Double.infinity
    private var gadget: ArenaGadget?
    private var lastGadgetAt = -Double.infinity

    mutating func reset() {
        primed = false
        gadgetPrimed = false
        threatArmed = true
        lastPickupAt = -Double.infinity
        gadget = nil
        lastGadgetAt = -Double.infinity
    }

    mutating func observe(before: ArenaSnapshot?, after: ArenaSnapshot, playerID: String,
                          at time: TimeInterval, active: Bool, combat: Bool) -> [ArenaFeedbackCue] {
        guard active, let mine = after.players.first(where: { $0.id == playerID }), mine.alive else {
            reset()
            return []
        }
        let edge = Self.threatEdge(in: after, playerID: playerID)
        if !primed {
            primed = true
            threatArmed = edge > 125
            lastPickupAt = time
            return []
        }
        guard let before, let prior = before.players.first(where: { $0.id == playerID }), prior.alive else {
            threatArmed = edge > 125
            lastPickupAt = time
            return []
        }
        guard after.tick > before.tick else { return [] }
        if edge >= 190 { threatArmed = true }
        var cues: [ArenaFeedbackCue] = []
        if edge <= 125, threatArmed {
            threatArmed = false
            if !combat { cues.append(.threat) }
        }
        let gain = mine.mass - prior.mass
        if !combat, cues.isEmpty, gain >= 2, time - lastPickupAt >= 0.9 {
            cues.append(gain >= 8 ? .feast : .pickup)
            lastPickupAt = time
        }
        return cues
    }

    static func threatEdge(in snapshot: ArenaSnapshot, playerID: String) -> Double {
        guard let mine = snapshot.players.first(where: { $0.id == playerID }), mine.alive, mine.shield <= 0 else {
            return .infinity
        }
        return snapshot.players.filter { $0.id != playerID && $0.alive && $0.shield <= 0 }
            .flatMap { opponent in
                opponent.pieces.flatMap { predator in
                    mine.pieces.filter { predator.mass >= $0.mass * 1.22 }.map { cell in
                        hypot(predator.x - cell.x, predator.y - cell.y) - predator.radius - cell.radius
                    }
                }
            }.min() ?? .infinity
    }

    mutating func gadgetCue(_ current: ArenaGadget?, at time: TimeInterval, active: Bool) -> ArenaFeedbackCue? {
        guard active else {
            gadgetPrimed = false
            gadget = nil
            lastGadgetAt = -Double.infinity
            return nil
        }
        if !gadgetPrimed {
            gadgetPrimed = true
            gadget = current
            lastGadgetAt = time
            return nil
        }
        guard let current else {
            gadget = nil
            lastGadgetAt = -Double.infinity
            return nil
        }
        guard current != gadget || time - lastGadgetAt >= 1.1 else { return nil }
        gadget = current
        lastGadgetAt = time
        switch current {
        case .slicer: return .slicer
        case .shaker: return .shaker
        case .grater: return .grater
        }
    }
}

@MainActor final class ArenaFeedback {
    var enabled = true {
        didSet { if !enabled { stop() } }
    }

    private let now: @MainActor () -> TimeInterval
    private let prepareOutput: @MainActor () -> Void
    private let emit: @MainActor (UIImpactFeedbackGenerator.FeedbackStyle, CGFloat) -> Void
    private var lastPlayed: [ArenaFeedbackCue: TimeInterval] = [:]
    private var pending: [UUID: (cue: ArenaFeedbackCue, task: Task<Void, Never>)] = [:]

    init() {
        let output = ArenaImpactOutput()
        now = { ProcessInfo.processInfo.systemUptime }
        prepareOutput = { output.prepare() }
        emit = { style, intensity in output.emit(style, intensity: intensity) }
    }

    init(now: @escaping @MainActor () -> TimeInterval,
         prepareOutput: @escaping @MainActor () -> Void,
         emit: @escaping @MainActor (UIImpactFeedbackGenerator.FeedbackStyle, CGFloat) -> Void) {
        self.now = now
        self.prepareOutput = prepareOutput
        self.emit = emit
    }

    func prepare() {
        guard enabled else { return }
        prepareOutput()
    }

    func play(_ cue: ArenaFeedbackCue) {
        guard enabled else { return }
        let time = now()
        if let previous = lastPlayed[cue], time - previous < cue.cooldown { return }
        lastPlayed[cue] = time
        for pulse in cue.pulses {
            if pulse.delay == 0 {
                emit(pulse.style, pulse.intensity)
                continue
            }
            let id = UUID()
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(pulse.delay))
                guard !Task.isCancelled, let self, self.enabled else { return }
                self.pending[id] = nil
                self.emit(pulse.style, pulse.intensity)
            }
            pending[id] = (cue, task)
        }
    }

    func cancelGadgetPulses() {
        for (id, pulse) in pending.filter({ $0.value.cue.isGadget }) {
            pulse.task.cancel()
            pending[id] = nil
        }
    }

    func stop() {
        for pulse in pending.values { pulse.task.cancel() }
        pending.removeAll()
        lastPlayed.removeAll()
    }
}

@MainActor private final class ArenaImpactOutput {
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)

    func prepare() {
        soft.prepare()
        light.prepare()
        heavy.prepare()
        rigid.prepare()
    }

    func emit(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .soft: generator = soft
        case .light: generator = light
        case .heavy: generator = heavy
        default: generator = rigid
        }
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }
}
