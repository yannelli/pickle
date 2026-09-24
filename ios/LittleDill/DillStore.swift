import Foundation
import SwiftUI

@MainActor final class DillStore: ObservableObject {
    @Published private(set) var pet: PetState
    @Published var notice: String?
    /// The pickle's latest line, matching the web game's speech bubble.
    @Published private(set) var speech: String?
    /// Bites taken during an open "eat the pickle" prompt; nil when no prompt is open.
    @Published private(set) var snackBites: Int?
    @Published private(set) var arcadeActive = false
    @Published private var previousPet: PetState?
    var canUndoRestore: Bool { previousPet != nil }
    private var snackUntil: Date?
    private let defaults: UserDefaults
    private let key = "little-dill.native.v1"
    private let recoveryKey = "little-dill.native.v1.recovery"
    private let clock: () -> Date
    private var now: Date { clock() }
    /// The first save that failed to load, as stored. Later failures keep this copy.
    var recoveryCopy: Data? { defaults.data(forKey: recoveryKey) }

    init(defaults: UserDefaults = .standard, clock: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.clock = clock
        pet = PetState(now: clock())
        guard let data = defaults.data(forKey: key) else { refresh(); return }
        let decoder = JSONDecoder()
        decoder.userInfo[PetState.nowKey] = clock()
        let saved = try? decoder.decode(PetState.self, from: data)
        if let saved, saved.isValid { pet = saved; refresh(); return }
        let copied = recoveryCopy == nil
        if copied { defaults.set(data, forKey: recoveryKey) }
        let copy = copied ? "A copy of the original save is in Settings → Backups." : "An earlier recovery copy is still in Settings → Backups."
        if var saved {
            let keptPickle = saved.repair(now: clock())
            pet = saved
            notice = (keptPickle ? "Some saved progress was out of range and has been repaired. "
                      : "Your pickle’s save was damaged, so a new egg is ready. Coins and outfits were kept. ") + copy
        } else {
            notice = "Your previous save could not be read, so a new egg is ready. " + copy
        }
        refresh()
    }
    func save() {
        guard let data = try? JSONEncoder().encode(pet) else { return }
        defaults.set(data, forKey: key)
    }
    // Mirrors the web syncTime(): apply elapsed time, close games and bites after death, announce a new stage.
    private func sync(at time: Date) {
        let before = PetLife.stage(pet.life, now: pet.life.updatedAt)
        pet.refresh(at: time)
        if pet.life.dead { arcadeActive = false; snackBites = nil; snackUntil = nil }
        let after = PetLife.stage(pet.life, now: PetLife.ms(time))
        if after != before && pet.life.phase == .living && !pet.life.dead { speech = "look at you grow. hello, \(after.rawValue)!" }
    }
    func refresh() { sync(at: now); save() }
    /// Call every few seconds and when the app returns to the foreground.
    func tick() {
        if let until = snackUntil, now > until { cancelBite() }
        refresh()
    }
    @discardableResult func brine(_ kind: Brine) -> Bool {
        let time = now
        sync(at: time)
        guard PetLife.brine(&pet.life, kind: kind.rawValue, now: PetLife.ms(time), random: Double.random(in: 0..<1)) else { return false }
        save(); return true
    }
    func name(_ text: String) -> Bool {
        let time = now
        sync(at: time)
        guard PetLife.name(&pet.life, text: text, now: PetLife.ms(time)) else { return false }
        sync(at: time)
        speech = "welcome home, \(pet.name)."
        save(); return true
    }
    @discardableResult func care(_ action: Care) -> CareResult {
        if snackBites != nil { cancelBite(); return CareResult(applied: false, coins: 0, message: speech ?? "") }
        if action == .nap { return toggleSleep() }
        guard !arcadeActive else { return CareResult(applied: false, coins: 0, message: "") }
        let time = now
        sync(at: time)
        let result = pet.care(action, at: time)
        if !result.message.isEmpty { speech = result.message }
        save(); return result
    }
    @discardableResult func toggleSleep() -> CareResult {
        let sleeping = !pet.life.sleeping, time = now
        sync(at: time)
        guard snackBites == nil, !arcadeActive else { return CareResult(applied: false, coins: 0, message: "") }
        let result = pet.setSleeping(sleeping, at: time)
        if !result.message.isEmpty { speech = result.message }
        save(); return result
    }
    /// Spends 6 energy to enter an arcade game, like the web startGame().
    func startArcade() -> Bool {
        guard snackBites == nil else { return false }
        let time = now
        sync(at: time)
        guard pet.startArcade(at: time) else {
            if pet.adopted && !pet.life.dead && !pet.life.sleeping { speech = "a little nap first! games need 6 energy." }
            return false
        }
        arcadeActive = true; save(); return true
    }
    /// Returns the happiness gained. `completed == false` leaves the game without a reward, like the web endGame().
    @discardableResult func finishArcade(game: String, score: Int, completed: Bool) -> Int {
        let time = now
        sync(at: time)
        guard arcadeActive else { return 0 }
        arcadeActive = false
        let added = pet.finishArcade(game: game, score: score, completed: completed, at: time)
        save(); return added
    }
    /// Opens the web "are you going to EAT me?!" prompt without biting.
    @discardableResult func startBite() -> Bool {
        let time = now
        sync(at: time)
        guard snackBites == nil, pet.adopted, !pet.life.dead, !pet.life.sleeping, !arcadeActive else { return false }
        snackBites = 0; snackUntil = time.addingTimeInterval(9)
        speech = "wait. are you going to... EAT me?!"
        return true
    }
    /// Returns 0 after the first bite, 1 after the second, 2 when the pickle is eaten, and -1 when biting is unavailable.
    @discardableResult func bite() -> Int {
        if snackBites == nil && !startBite() { return -1 }
        let time = now
        sync(at: time)
        guard let taken = snackBites, pet.adopted, !pet.life.dead else { return -1 }
        let bites = taken + 1
        if bites < 3 {
            let before = pet.life.happiness
            pet.life.happiness = PetLife.clamp(before - 10)
            let lost = Int((before - pet.life.happiness).rounded(.toNearestOrAwayFromZero))
            speech = ["CRONCH. ...ow.", "half a dill. 100% betrayed."][bites - 1] + (lost > 0 ? " −\(lost) happy." : "")
            PetLife.assess(&pet.life)
            snackBites = bites; snackUntil = time.addingTimeInterval(12)
            save(); return bites - 1
        }
        snackBites = nil; snackUntil = nil
        pet.life.dead = true; pet.life.eaten = true; pet.life.sleeping = false
        pet.life.diedAt = max(pet.life.bornAt, PetLife.ms(time))
        speech = "you ate \(pet.name). it was delicious. you monster."
        save(); return 2
    }
    func cancelBite() {
        guard let bites = snackBites else { return }
        snackBites = nil; snackUntil = nil
        speech = bites > 0 ? "you took a BITE and stopped?! ...it grows back. i won’t forget." : "phew. i’m a friend, not a snack."
    }
    /// Starts a new egg after death. Coins, outfits and other native progress stay.
    func restart() {
        guard pet.life.dead else { return }
        arcadeActive = false; snackBites = nil; snackUntil = nil; previousPet = nil
        pet.life = PetLife.fresh(now: PetLife.ms(now)); pet.lastPetAt = nil
        speech = "a fresh start. a brand-new little dill."
        save()
    }
    func exportBackup() throws -> Data {
        refresh()
        return try DillBackup.encode(pet: pet.life, native: pet.native, savedAt: PetLife.ms(now))
    }
    func previewBackup(_ data: Data) throws -> BackupPreview {
        guard data.count <= DillBackup.MAX_FILE_BYTES else { throw DillBackupError.fileTooLarge }
        return DillBackup.preview(try DillBackup.decode(data), now: PetLife.ms(now))
    }
    /// Replaces the pickle, and the native extras when the file has them, then applies elapsed time like the web import.
    func restoreBackup(_ preview: BackupPreview) {
        let time = now
        sync(at: time)
        let previous = pet
        var next = pet
        next.life = preview.backup.restored(now: PetLife.ms(time))
        if let native = preview.backup.native { next.apply(native) }
        replace(with: next, at: time)
        previousPet = previous
    }
    @discardableResult func undoRestore() -> Bool {
        guard let previous = previousPet else { return false }
        previousPet = nil
        replace(with: previous, at: now)
        return true
    }
    private func replace(with state: PetState, at time: Date) {
        arcadeActive = false; snackBites = nil; snackUntil = nil; speech = nil
        pet = state; pet.lastPetAt = nil
        sync(at: time); save()
    }
    @discardableResult func record(score: Int, day: String) -> Int { let reward = pet.record(score: score, day: day, at: now); save(); return reward }
    func equip(_ outfit: Outfit) -> Bool { let result = pet.equip(outfit); save(); return result }
    @discardableResult func rename(_ name: String) -> Bool {
        guard pet.adopted, let clean = PetLife.cleanName(name) else { return false }
        pet.life.name = clean; save(); return true
    }
    func recordArena(best:Int) {guard best >= 0 else {return}; pet.arenaBest = max(pet.arenaBest ?? 0,best); save()}
    func setHaptics(_ enabled: Bool) { pet.haptics = enabled; save() }
    func setSounds(_ enabled: Bool) { pet.soundEnabled = enabled; save(); if !enabled {DillAudio.shared.stop()} }
    func sound(_ cue:DillSound) {if pet.sounds {DillAudio.shared.play(cue)}}
    func reset() {
        arcadeActive = false; snackBites = nil; snackUntil = nil; previousPet = nil; speech = nil
        pet = PetState(now: now); save()
    }
    func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        if pet.haptics { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }
}
