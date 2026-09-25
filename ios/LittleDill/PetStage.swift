import SwiftUI

struct FloatEffect {
    let text: String
    var hearts = false
    let started = Date()
}

/// Remembers the last drawn pose so mood, vibe and performance changes blend instead of snapping.
final class MotionMemory {
    private var key = ""
    private var from: PicklePose?
    private var last = PicklePose()
    private var changedAt = 0.0
    func resolve(_ target: PicklePose, key: String, time: Double, blend: Double = 0.35) -> PicklePose {
        if key != self.key { from = last; changedAt = time; self.key = key }
        var pose = target
        if let from, blend > 0 {
            let t = (time - changedAt) / blend
            if t < 1 && t >= 0 { pose = from.mix(target, Ease.inOut(t)) } else { self.from = nil }
        }
        last = pose
        return pose
    }
}

/// Nest-only presentation state mirroring the web page: happyUntil, chill vibes, idle acts and the message line.
@MainActor final class PetStage: ObservableObject {
    @Published private(set) var act: PetAct?
    @Published private(set) var actStarted = Date.distantPast
    @Published var happyUntil = Date.distantPast
    @Published private(set) var effect: FloatEffect?
    @Published private(set) var line: String?
    private(set) var lastSaid = Date.distantPast
    private var lastAction = Date.distantPast
    private var chill: (vibe: PetVibe, until: Date) = (.hop, .distantPast)
    private var lineTask: Task<Void, Never>?
    let memory = MotionMemory()

    func mood(_ pet: WebPet, snacking: Bool, now: Date) -> PetMood {
        if pet.dead { return .dead }
        if snacking { return .scared }
        if pet.sleeping { return .sleeping }
        if pet.sick { return .sick }
        if now < happyUntil || (pet.happiness >= 80 && pet.energy >= 25) { return .happy }
        if pet.fullness < 30 || pet.energy < 20 || pet.happiness < 25 { return .hungry }
        return .idle
    }

    /// A content pickle keeps one vibe for 30 to 60 seconds. A fresh pet or treat means a happy hop.
    func vibe(for mood: PetMood, now: Date) -> PetVibe? {
        guard mood == .happy else { return nil }
        if now < happyUntil { return .hop }
        if now >= chill.until {
            let options = PetVibe.allCases.filter { $0 != chill.vibe }
            chill = (options.randomElement() ?? .hop, now.addingTimeInterval(Double.random(in: 30...60)))
        }
        return chill.vibe
    }

    func play(_ act: PetAct) {
        self.act = act
        actStarted = Date(); lastAction = actStarted
    }

    func pop(_ text: String, hearts: Bool = false) { effect = FloatEffect(text: text, hearts: hearts) }

    func say(_ text: String, for seconds: Double = 3.5) {
        guard !text.isEmpty else { return }
        line = text; lastSaid = Date()
        lineTask?.cancel()
        lineTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.line = nil
        }
    }

    /// Web scheduleIdle(): a random act for the current mood, never within 1.5 s of an action.
    func idleTick(mood: PetMood, busy: Bool, reduceMotion: Bool) {
        let now = Date()
        guard !reduceMotion, !busy, now.timeIntervalSince(lastAction) > 1.5 else { return }
        if let act, now.timeIntervalSince(actStarted) < act.duration { return }
        guard let next = PetAct.idleChoices(for: mood).randomElement() else { return }
        act = next; actStarted = now
    }

    func reset() {
        act = nil; happyUntil = .distantPast; effect = nil; line = nil
        lineTask?.cancel(); chill = (.hop, .distantPast)
    }
}
