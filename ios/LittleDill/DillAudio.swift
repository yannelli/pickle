import AVFoundation

enum DillSound: String, CaseIterable {
    case feed, pet, wash, nap, dash, pop, respawn, crunch, win
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
        }
    }

    // Original, deterministic PCM effects: no downloads, audio assets, or packages.
    func waveData() -> Data {
        let rate = 24_000, frames = Int(duration * Double(rate))
        var pcm = Data(capacity:frames * 2)
        var noiseState: UInt32 = 0xD111
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
        for frame in 0..<frames {
            let t = Double(frame) / Double(rate)
            noiseState = 1664525 &* noiseState &+ 1013904223
            let noise = Double(noiseState >> 8) / Double(0xFFFFFF) * 2 - 1
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

@MainActor final class DillAudio {
    static let shared = DillAudio()
    private let sessionQueue = DispatchQueue(label:"app.littledill.audio-session")
    private var sessionActive = false
    private var request = 0
    private var player: AVAudioPlayer?
    private var clips: [DillSound:Data] = [:]
    /// The clip starts after the queued session change, so a stop followed by a play can't deactivate the new clip.
    func play(_ sound:DillSound) {
        let data = clips[sound] ?? sound.waveData(); clips[sound] = data
        player?.stop(); player = nil
        request += 1
        let current = request, activate = !sessionActive
        sessionActive = true
        sessionQueue.async {
            if activate { Self.setSession(active:true) }
            Task { @MainActor in if self.request == current { self.start(data) } }
        }
    }
    func stop() {
        request += 1
        player?.stop(); player = nil
        guard sessionActive else {return}
        sessionActive = false
        sessionQueue.async { Self.setSession(active:false) }
    }
    private func start(_ data:Data) {
        player = try? AVAudioPlayer(data:data)
        player?.volume = 0.7; player?.prepareToPlay(); player?.play()
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
