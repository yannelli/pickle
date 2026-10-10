import XCTest
@testable import LittleDill

final class ArenaPlaybackTests: XCTestCase {
    private func snapshot(tick:Int) throws -> ArenaSnapshot {
        let x = Double(tick) * 10
        let player:[String:Any] = ["id":"me","name":"me","brine":"classic","outfit":"sprout","bot":false,
            "x":x,"y":100,"mass":50,"best":50,"kills":0,"alive":true,"shield":0,"dash":0,"cooldown":0,"respawn":0,"eatenBy":"",
            "cells":[["id":"a","x":x,"y":100,"mass":50]]]
        let state:[String:Any] = ["tick":tick,"time":Double(tick) / 20,"width":6000,"height":4500,"humans":1,"bots":0,"players":[player]]
        return try JSONDecoder().decode(ArenaSnapshot.self,from:JSONSerialization.data(withJSONObject:state))
    }

    private func shownX(_ playback:inout ArenaPlayback,at now:Date) throws -> Double {
        let frame = try XCTUnwrap(playback.time(at:now).flatMap {playback.frame(at:$0)})
        let from = try XCTUnwrap(frame.from.players.first?.pieces.first), to = try XCTUnwrap(frame.to.players.first?.pieces.first)
        return from.x + (to.x - from.x) * frame.blend
    }

    func testSteadyPacketsPlayAtRealTimeBehindTheNewestTick() throws {
        var playback = ArenaPlayback()
        let start = Date(timeIntervalSince1970:1000)
        var shown:[Double] = []
        for packet in 0..<10 {
            let arrival = start.addingTimeInterval(Double(packet) * 0.1)
            playback.receive(try snapshot(tick:100 + packet * 2),at:arrival)
            for frame in 0..<12 {shown.append(try shownX(&playback,at:arrival.addingTimeInterval(Double(frame) / 120)))}
        }
        let last = try XCTUnwrap(playback.time(at:start.addingTimeInterval(0.9)))
        XCTAssertEqual(last,Double(118) / 20 - ArenaPlayback.delay,accuracy:1e-6)
        let steps = zip(shown.dropFirst(36),shown.dropFirst(37)).map {$1 - $0}
        for step in steps {XCTAssertEqual(step,200.0 / 120,accuracy:1e-3)}
    }

    func testJitteredPacketsNeitherStallNorJumpTheView() throws {
        var playback = ArenaPlayback()
        let start = Date(timeIntervalSince1970:1000)
        let arrivals = (0..<40).map { packet -> (tick:Int,at:Double) in
            let jitter:Double = packet.isMultiple(of:2) ? 0.025 : -0.025
            return (100 + packet * 2,Double(packet) * 0.1 + jitter + 0.03)
        }
        var delivered = 0, previous:Double?
        for frame in 0..<480 {
            let time = Double(frame) / 120
            while delivered < arrivals.count, arrivals[delivered].at <= time {
                playback.receive(try snapshot(tick:arrivals[delivered].tick),at:start.addingTimeInterval(arrivals[delivered].at)); delivered += 1
            }
            guard delivered > 0 else {continue}
            let x = try shownX(&playback,at:start.addingTimeInterval(time))
            if time > 0.6, let previous {
                XCTAssertGreaterThan(x - previous,0.8 * 200 / 120,"no stall at \(time)s")
                XCTAssertLessThan(x - previous,1.2 * 200 / 120,"no jump at \(time)s")
            }
            previous = x
        }
    }

    func testHistoryIgnoresRepeatsRestartsOnOlderTicksAndHoldsItsEnds() throws {
        var playback = ArenaPlayback()
        let now = Date(timeIntervalSince1970:1000)
        for tick in [10,12,12,14,16,18] {playback.receive(try snapshot(tick:tick),at:now)}
        XCTAssertEqual(playback.history.map(\.tick),[12,14,16,18])
        XCTAssertEqual(playback.frame(at:0)?.from.tick,12)
        XCTAssertEqual(playback.frame(at:0)?.blend,0)
        XCTAssertEqual(playback.frame(at:100)?.to.tick,18)
        XCTAssertEqual(try XCTUnwrap(playback.frame(at:100)).blend,1 + ArenaPlayback.maxLead / 0.1,accuracy:1e-9)
        XCTAssertEqual(try XCTUnwrap(playback.frame(at:0.75)).blend,0.5,accuracy:1e-9)
        playback.receive(try snapshot(tick:4),at:now)
        XCTAssertEqual(playback.history.map(\.tick),[4])
        XCTAssertEqual(playback.time(at:now),0.2 - ArenaPlayback.delay)
    }
}
