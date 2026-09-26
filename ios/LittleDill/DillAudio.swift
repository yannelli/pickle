import AVFoundation

enum DillSound: String, CaseIterable {
    case feed, pet, wash, nap, dash, pop, respawn, crunch, win, eaten, gulp, nibble, slice, slicer, shaker, grater
    case hop, ding, chop, boing, splash, clank, nibble2, nibble3, nibble4
    var duration: Double {
        switch self {
        case .feed: return 3.4
        case .pet: return 2.8
        case .wash: return 4.3
        case .nap: return 4.5
        case .dash: return 0.32
        case .pop: return 0.5
        case .respawn: return 0.5
        case .crunch: return 0.23
        case .win: return 0.8
        case .eaten: return 0.35
        case .gulp: return 0.2
        case .nibble,.nibble2,.nibble3,.nibble4: return 0.11
        case .slice: return 0.15
        case .slicer: return 0.32 * 8
        case .shaker: return 0.22 * 8
        case .grater: return 0.35 * 8
        case .hop: return 0.14
        case .ding: return 0.22
        case .chop: return 0.2
        case .boing: return 0.42
        case .splash: return 0.45
        case .clank: return 0.3
        }
    }

    var isGadget: Bool { self == .slicer || self == .shaker || self == .grater }

    func waveData() -> Data {
        if let index = [DillSound.nibble,.nibble2,.nibble3,.nibble4].firstIndex(of:self) {
            guard let url = Bundle.main.url(forResource:"arena-pickup-\(index)",withExtension:"wav"),
                  let data = try? Data(contentsOf:url) else {return Data()}
            return data
        }
        if isGadget {
            guard let url = Bundle.main.url(forResource:"arena-\(rawValue)",withExtension:"wav"),
                  let data = try? Data(contentsOf:url) else {return Data()}
            return data
        }
        let rate = 24_000, frames = Int(duration * Double(rate))
        var pcm = Data(capacity:frames * 2)
        var noiseState: UInt32 = 0xD111
        var crackle = 1.0
        var crisp = Band(2600,q:1.1,rate:Double(rate)), body = Band(1100,q:0.9,rate:Double(rate)), air = Band(6200,q:0.8,rate:Double(rate))
        func tone(_ t:Double,_ start:Double,_ length:Double,_ hz:Double,_ slide:Double = 0) -> Double {
            let u = t - start
            guard u >= 0 && u < length else {return 0}
            let envelope = min(1,u / 0.008) * pow(1 - u / length,2)
            return sin(2 * .pi * (hz * u + slide * u * u / 2)) * envelope
        }
        func hiss(_ t:Double,_ start:Double,_ length:Double,_ noise:Double) -> Double {
            let u = t - start
            guard u >= 0 && u < length else {return 0}
            return noise * min(1,u / 0.01) * pow(1 - u / length,1.4)
        }
        func click(_ t:Double,_ start:Double,_ length:Double,_ source:Double) -> Double {
            let u = t - start
            guard u >= 0 && u < length else {return 0}
            return source * pow(1 - u / length,2)
        }
        for frame in 0..<frames {
            let t = Double(frame) / Double(rate)
            noiseState = 1664525 &* noiseState &+ 1013904223
            let noise = Double(noiseState >> 8) / Double(0xFFFFFF) * 2 - 1
            if frame % 24 == 0 {crackle = abs(noise) > 0.8 ? 1.9 : 0.3 + 0.7 * abs(noise)}
            let high = crisp(noise), low = body(noise), hush = air(noise)
            var sample = 0.0
            switch self {
            case .feed:
                for start in [0.45,0.9,1.35,1.8,2.25] {
                    sample += hiss(t,start,0.16,noise) * 0.34 + tone(t,start,0.12,180,-600) * 0.3
                }
                sample += tone(t,2.7,0.22,660) * 0.23 + tone(t,2.92,0.35,880) * 0.2
            case .pet:
                for i in 0..<4 {sample += tone(t,0.2 + Double(i)*0.6,0.3,430 + Double(i)*70,900) * 0.24}
            case .wash:
                sample = hiss(t,0.15,2.6,noise) * 0.13
                for i in 0..<10 {sample += tone(t,0.3 + Double(i)*0.28,0.13,650 + Double(i%3)*160,-2200) * 0.23}
                sample += tone(t,3.35,0.3,1047) * 0.18 + tone(t,3.65,0.5,1319) * 0.16
            case .nap:
                for (i,hz) in [523.25,659.25,783.99,659.25,523.25].enumerated() {
                    sample += tone(t,Double(i)*0.65,1.3,hz) * 0.15
                    sample += tone(t,Double(i)*0.65,1.3,hz*2) * 0.035
                }
            case .dash: sample = hiss(t,0,0.32,noise) * 0.18 + tone(t,0,0.25,210,1900) * 0.2
            case .pop: sample = tone(t,0,0.4,340,-700) * 0.32 + hiss(t,0,0.09,noise) * 0.18
            case .respawn: sample = tone(t,0,0.2,440) * 0.23 + tone(t,0.13,0.3,660) * 0.23
            case .crunch: sample = hiss(t,0,0.19,noise) * 0.4 + tone(t,0,0.18,150,-400) * 0.25
            case .win:
                for (i,hz) in [523.25,659.25,783.99,1046.5].enumerated() {sample += tone(t,Double(i)*0.12,0.4,hz) * 0.25}
            case .eaten:
                for (start,length,level) in [(0.0,0.05,1.0),(0.045,0.04,0.8),(0.095,0.06,0.9),(0.15,0.035,0.65)] {
                    let u = t - start
                    guard u >= 0 && u < length else {continue}
                    let envelope = min(1,u / 0.0015) * pow(1 - u / length,1.6) * level
                    sample += (high * 0.8 + low * 0.45) * crackle * envelope
                }
                sample += tone(t,0,0.3,120,-65 / 0.3) * 0.5
            case .gulp: sample = tone(t,0,0.2,300,-900) * 0.42 + tone(t,0,0.2,600,-1800) * 0.08 + click(t,0.002,0.006,high) * 0.9
            case .nibble,.nibble2,.nibble3,.nibble4: break
            case .slice:
                sample = click(t,0,0.006,high + hush) + click(t,0.04,0.006,high + hush) * 0.8
                sample += tone(t,0.012,0.138,900,-400 / 0.138) * 0.26
            case .slicer,.shaker,.grater: break
            case .hop: sample = tone(t,0,0.12,360,4200) * 0.3 + tone(t,0,0.1,720,8000) * 0.06 + click(t,0,0.004,low) * 0.4
            case .ding: sample = tone(t,0,0.2,1318.5) * 0.2 + tone(t,0.05,0.17,1760) * 0.18
            case .chop:
                let swish = t < 0.07 ? sin(.pi * t / 0.07) : 0
                sample = hush * swish * 0.55 + click(t,0.06,0.01,high + low) * 0.8
                sample += tone(t,0.06,0.12,260,-900) * 0.3 + hiss(t,0.06,0.1,low) * 0.25
            case .boing:
                let phase = 2 * .pi * (180 * t + 100 * t * t) - 60.0 / 18 * cos(2 * .pi * 18 * t)
                sample = sin(phase) * min(1,t / 0.005) * pow(1 - t / 0.42,1.5) * 0.4 + click(t,0,0.006,low) * 0.6
            case .splash:
                sample = hiss(t,0,0.25,low) * 0.5 + hiss(t,0,0.12,hush) * 0.3
                for (start,hz,level) in [(0.08,520.0,0.18),(0.17,640,0.15),(0.27,480,0.12)] {sample += tone(t,start,0.08,hz,3200) * level}
            case .clank:
                for (i,(hz,level)) in [(920.0,0.22),(1383,0.16),(2210,0.1),(3120,0.06)].enumerated() {sample += tone(t,0,0.28 - Double(i) * 0.04,hz) * level}
                sample += click(t,0,0.004,high) * 0.6
            }
            var value = Int16(max(-0.85,min(0.85,sample)) * Double(Int16.max)).littleEndian
            withUnsafeBytes(of:&value) {pcm.append(contentsOf:$0)}
        }
        var wav = Data()
        func word(_ number:UInt16) {var n = number.littleEndian; withUnsafeBytes(of:&n) {wav.append(contentsOf:$0)}}
        func dword(_ number:UInt32) {var n = number.littleEndian; withUnsafeBytes(of:&n) {wav.append(contentsOf:$0)}}
        wav.append(Data("RIFF".utf8)); dword(UInt32(36 + pcm.count)); wav.append(Data("WAVEfmt ".utf8))
        dword(16); word(1); word(1); dword(UInt32(rate)); dword(UInt32(rate*2)); word(2); word(16)
        wav.append(Data("data".utf8)); dword(UInt32(pcm.count)); wav.append(pcm)
        return wav
    }
}

/// Two-pole band-pass (RBJ, constant peak gain) for shaping noise inside `waveData()`.
private struct Band {
    let b0: Double, b2: Double, a1: Double, a2: Double
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
    init(_ hz:Double,q:Double,rate:Double) {
        let w = 2 * .pi * hz / rate, alpha = sin(w) / (2 * q), a0 = 1 + alpha
        b0 = alpha / a0; b2 = -alpha / a0; a1 = -2 * cos(w) / a0; a2 = (1 - alpha) / a0
    }
    mutating func callAsFunction(_ x:Double) -> Double {
        let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        return y
    }
}

@MainActor final class DillAudio {
    static let shared = DillAudio()
    private let sessionQueue = DispatchQueue(label:"app.littledill.audio-session")
    private var sessionActive = false
    private var generation = 0
    private var voices: [(sound:DillSound,player:AVAudioPlayer)] = []
    private var clips: [DillSound:Data] = [:]
    private var gadgetRevision = 0
    private(set) var gadgetSound: DillSound?
    private(set) var gadgetPlayer: AVAudioPlayer?
    private static let voiceLimit = 4
    private static let performances: Set<DillSound> = [.feed,.pet,.wash,.nap]
    /// The clip starts after the queued session change, so a stop followed by a play can't deactivate the new clip.
    /// Clips overlap on up to four voices; `stop()` silences them all and drops clips still waiting to start.
    func play(_ sound:DillSound,volume:Float = 0.7) {
        let data = clips[sound] ?? sound.waveData(); clips[sound] = data
        let current = generation, activate = !sessionActive
        sessionActive = true
        sessionQueue.async {
            if activate { Self.setSession(active:true) }
            Task { @MainActor in if self.generation == current { self.start(sound,data,volume:volume) } }
        }
    }
    func stop() {
        generation += 1
        setGadget(nil)
        for voice in voices {voice.player.stop()}
        voices = []
        guard sessionActive else {return}
        sessionActive = false
        sessionQueue.async { Self.setSession(active:false) }
    }
    func setGadget(_ sound:DillSound?) {
        let sound = sound?.isGadget == true ? sound : nil
        guard sound != gadgetSound else {return}
        gadgetRevision += 1
        gadgetPlayer?.stop(); gadgetPlayer = nil; gadgetSound = sound
        guard let sound else {return}
        let data = clips[sound] ?? sound.waveData(); clips[sound] = data
        let revision = gadgetRevision, current = generation, activate = !sessionActive
        sessionActive = true
        sessionQueue.async {
            if activate { Self.setSession(active:true) }
            Task { @MainActor in
                guard self.generation == current, self.gadgetRevision == revision,
                      let player = try? AVAudioPlayer(data:data) else {return}
                player.numberOfLoops = -1; player.volume = 1
                player.prepareToPlay(); player.play()
                self.gadgetPlayer = player
            }
        }
    }
    private func start(_ sound:DillSound,_ data:Data,volume:Float) {
        guard let player = try? AVAudioPlayer(data:data) else {return}
        // A care performance replaces the one already playing instead of layering over it.
        let replacing = Self.performances.contains(sound)
        voices.removeAll { voice in
            let done = !voice.player.isPlaying || replacing && Self.performances.contains(voice.sound)
            if done {voice.player.stop()}
            return done
        }
        if voices.count >= Self.voiceLimit {voices.removeFirst().player.stop()}
        player.volume = max(0,min(1,volume)); player.prepareToPlay(); player.play()
        voices.append((sound,player))
    }
    nonisolated private static func setSession(active:Bool) {
        let session = AVAudioSession.sharedInstance()
        if active {
            // Ambient respects the silent switch and mixes with the user's music.
            try? session.setCategory(.ambient,mode:.default,options:.mixWithOthers)
            try? session.setActive(true)
        } else {
            try? session.setActive(false,options:.notifyOthersOnDeactivation)
        }
    }
}
