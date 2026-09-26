import AVFoundation
import CryptoKit
import XCTest
@testable import LittleDill

final class ArenaAudioParityTests: XCTestCase {
    func testBundledLoopsMatchWebRenderAndStrokePeriods() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource:"gadget-audio",withExtension:"json"))
        let manifest = try JSONDecoder().decode(Manifest.self,from:Data(contentsOf:url))
        XCTAssertEqual(manifest.sampleRate,48000)
        XCTAssertEqual(manifest.strokeCount,8)
        for (sound,period) in [(DillSound.slicer,0.32),(.shaker,0.22),(.grater,0.35)] {
            let clip = try XCTUnwrap(manifest.clips[sound.rawValue])
            let wav = sound.waveData(), player = try AVAudioPlayer(data:wav)
            XCTAssertEqual(clip.period,period)
            XCTAssertEqual(player.duration,period * Double(manifest.strokeCount),accuracy:1/48000)
            XCTAssertEqual(player.format.sampleRate,Double(manifest.sampleRate))
            XCTAssertEqual(SHA256.hash(data:wav).map {String(format:"%02x",$0)}.joined(),clip.sha256)
            let pcm = [UInt8](wav.dropFirst(44))
            let framesPerStroke = Int(period * Double(manifest.sampleRate))
            XCTAssertEqual(pcm.count,framesPerStroke * manifest.strokeCount * 2)
            var energy = 0.0, peak = 0.0
            for stroke in 0..<manifest.strokeCount {
                var strokeEnergy = 0.0
                for frame in (stroke * framesPerStroke)..<((stroke + 1) * framesPerStroke) {
                    let value = Double(Int16(bitPattern:UInt16(pcm[frame*2]) | UInt16(pcm[frame*2+1]) << 8)) / 32767
                    strokeEnergy += value * value; peak = max(peak,abs(value))
                }
                XCTAssertGreaterThan(strokeEnergy,0.01,"Missing \(sound) stroke \(stroke)")
                energy += strokeEnergy
            }
            XCTAssertEqual(peak,clip.peak,accuracy:0.00002)
            XCTAssertEqual(sqrt(energy / Double(pcm.count/2)),clip.rms,accuracy:0.00002)
            XCTAssertEqual(Array(pcm.prefix(32)),Array(repeating:0,count:32))
            XCTAssertEqual(Array(pcm.suffix(32)),Array(repeating:0,count:32))
        }
    }

    @MainActor func testLoopKeepsTimeAcrossSnapshotsSwitchesAndStops() async throws {
        let audio = DillAudio()
        defer {audio.stop()}
        audio.setGadget(.slicer)
        let slicer = try await waitForPlayer(audio)
        XCTAssertEqual(slicer.numberOfLoops,-1)
        XCTAssertEqual(slicer.volume,1)
        for _ in 0..<4 {audio.setGadget(.slicer)}
        XCTAssertTrue(audio.gadgetPlayer === slicer)
        slicer.currentTime = slicer.duration - 0.1
        try await Task.sleep(for:.milliseconds(220))
        XCTAssertTrue(slicer.isPlaying,"Loop must continue past the clip boundary")
        XCTAssertLessThan(slicer.currentTime,0.5)
        audio.setGadget(.shaker)
        XCTAssertFalse(slicer.isPlaying)
        let shaker = try await waitForPlayer(audio)
        XCTAssertFalse(shaker === slicer)
        XCTAssertEqual(shaker.duration,1.76,accuracy:0.001)
        audio.setGadget(nil)
        XCTAssertFalse(shaker.isPlaying)
        XCTAssertNil(audio.gadgetSound)
        XCTAssertNil(audio.gadgetPlayer)
        audio.setGadget(.grater)
        audio.stop()
        try await Task.sleep(for:.milliseconds(100))
        XCTAssertNil(audio.gadgetPlayer,"A queued stroke must stay cancelled after leaving")
    }

    @MainActor func testDrainSelectionStopsWhenMutedDeadDisconnectedOrOutsideField() throws {
        let hazards = [ArenaHazard(id:"s",x:100,y:200,r:150,kind:"shaker")]
        func player(alive:Bool = true,drain:Double = 1) throws -> ArenaPlayer {
            let state:[String:Any] = ["id":"you","name":"Dilly","brine":"classic","outfit":"sprout",
                "bot":false,"x":100,"y":200,"mass":100,"best":100,"kills":0,"alive":alive,
                "shield":0,"dash":0,"cooldown":0,"respawn":0,"eatenBy":"",
                "cells":[["id":"a","x":100,"y":200,"mass":100,"drain":drain]]]
            return try JSONDecoder().decode(ArenaPlayer.self,from:JSONSerialization.data(withJSONObject:state))
        }
        XCTAssertEqual(ArenaView.drainingGadget(player:try player(),hazards:hazards,enabled:true),.shaker)
        XCTAssertNil(ArenaView.drainingGadget(player:try player(),hazards:hazards,enabled:false))
        XCTAssertNil(ArenaView.drainingGadget(player:try player(alive:false),hazards:hazards,enabled:true))
        XCTAssertNil(ArenaView.drainingGadget(player:try player(drain:0),hazards:hazards,enabled:true))
        XCTAssertNil(ArenaView.drainingGadget(player:nil,hazards:hazards,enabled:true))
        XCTAssertNil(ArenaView.drainingGadget(player:try player(),hazards:[],enabled:true))
    }

    @MainActor private func waitForPlayer(_ audio:DillAudio) async throws -> AVAudioPlayer {
        for _ in 0..<100 {
            if let player = audio.gadgetPlayer {return player}
            try await Task.sleep(for:.milliseconds(10))
        }
        return try XCTUnwrap(audio.gadgetPlayer)
    }
    private struct Manifest: Decodable {
        let sampleRate: Int
        let strokeCount: Int
        let clips: [String:Clip]
    }
    private struct Clip: Decodable {
        let period: Double
        let peak: Double
        let rms: Double
        let sha256: String
    }
}
