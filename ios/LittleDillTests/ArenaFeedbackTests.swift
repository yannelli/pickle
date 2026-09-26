import UIKit
import XCTest
@testable import LittleDill

final class ArenaFeedbackTests: XCTestCase {
    private func snapshot(tick: Int, mass: Double = 50, shield: Double = 0,
                          enemyX: Double? = nil, enemyShield: Double = 0,
                          cellMasses: [Double]? = nil) throws -> ArenaSnapshot {
        func player(id: String, x: Double, mass: Double, shield: Double) -> [String: Any] {
            let cells = (id == "me" ? cellMasses : nil) ?? [mass]
            return ["id": id, "name": id, "brine": "classic", "outfit": "sprout", "bot": id != "me",
             "x": x, "y": 100, "mass": mass, "best": Int(mass), "kills": 0, "alive": true,
             "shield": shield, "dash": 0, "cooldown": 0, "respawn": 0, "eatenBy": "",
             "splitCooldown": 0, "merge": 0, "hurt": 0,
             "cells": cells.enumerated().map { ["id": id + "-cell-\($0.offset)", "x": x,
                                                  "y": 100, "mass": $0.element] as [String: Any] }]
        }
        var players = [player(id: "me", x: 100, mass: mass, shield: shield)]
        if let enemyX { players.append(player(id: "enemy", x: enemyX, mass: 80, shield: enemyShield)) }
        let state: [String: Any] = ["tick": tick, "time": Double(tick) / 20,
                                    "width": 6000, "height": 4500, "humans": 1, "bots": enemyX == nil ? 0 : 1,
                                    "players": players]
        return try JSONDecoder().decode(ArenaSnapshot.self, from: JSONSerialization.data(withJSONObject: state))
    }

    func testSnapshotFoodCuesAreSparseAndIgnoreMassLoss() throws {
        var events = ArenaFeedbackEvents()
        let start = try snapshot(tick: 1)
        let quick = try snapshot(tick: 2, mass: 53)
        let pickup = try snapshot(tick: 3, mass: 56)
        let feast = try snapshot(tick: 4, mass: 65)
        let drain = try snapshot(tick: 5, mass: 61)
        XCTAssertEqual(events.observe(before: nil, after: start, playerID: "me", at: 0, active: true, combat: false), [])
        XCTAssertEqual(events.observe(before: start, after: quick, playerID: "me", at: 0.2, active: true, combat: false), [])
        XCTAssertEqual(events.observe(before: quick, after: pickup, playerID: "me", at: 1, active: true, combat: false), [.pickup])
        XCTAssertEqual(events.observe(before: pickup, after: feast, playerID: "me", at: 1.2, active: true, combat: false), [])
        XCTAssertEqual(events.observe(before: feast, after: drain, playerID: "me", at: 2, active: true, combat: false), [])
        XCTAssertFalse(ArenaView.ateAPiece(before: feast, after: drain, playerID: "me"))
        let later = try snapshot(tick: 6, mass: 70)
        XCTAssertEqual(events.observe(before: drain, after: later, playerID: "me", at: 2.1, active: true, combat: false), [.feast])
        let combat = try snapshot(tick: 7, mass: 79)
        XCTAssertEqual(events.observe(before: later, after: combat, playerID: "me", at: 3.1, active: true, combat: true), [])
    }

    func testThreatEntryRespectsShieldsCombatAndResumeBaseline() throws {
        var events = ArenaFeedbackEvents()
        let near = try snapshot(tick: 1, enemyX: 270)
        let stillNear = try snapshot(tick: 2, enemyX: 268)
        let far = try snapshot(tick: 3, enemyX: 450)
        let entered = try snapshot(tick: 4, enemyX: 270)
        XCTAssertEqual(events.observe(before: nil, after: near, playerID: "me", at: 0, active: true, combat: false), [])
        XCTAssertEqual(events.observe(before: near, after: stillNear, playerID: "me", at: 0.1, active: true, combat: false), [])
        XCTAssertEqual(events.observe(before: stillNear, after: far, playerID: "me", at: 0.2, active: true, combat: false), [])
        XCTAssertEqual(events.observe(before: far, after: entered, playerID: "me", at: 0.3, active: true, combat: false), [.threat])
        let nearAgain = try snapshot(tick: 5, enemyX: 268)
        XCTAssertEqual(events.observe(before: entered, after: nearAgain, playerID: "me", at: 0.4, active: true, combat: false), [])
        let protected = try snapshot(tick: 6, shield: 1, enemyX: 270)
        XCTAssertEqual(events.observe(before: nearAgain, after: protected, playerID: "me", at: 0.5, active: true, combat: false), [])
        let enemyProtected = try snapshot(tick: 7, enemyX: 270, enemyShield: 1)
        XCTAssertEqual(events.observe(before: protected, after: enemyProtected, playerID: "me", at: 0.6, active: true, combat: false), [])
        let exposed = try snapshot(tick: 8, enemyX: 270)
        XCTAssertEqual(events.observe(before: enemyProtected, after: exposed, playerID: "me", at: 0.7, active: true, combat: false), [.threat])
        let farAgain = try snapshot(tick: 9, enemyX: 450)
        let enteredDuringCombat = try snapshot(tick: 10, enemyX: 270)
        let stillInRange = try snapshot(tick: 11, enemyX: 268)
        XCTAssertEqual(events.observe(before: exposed, after: farAgain, playerID: "me", at: 0.8, active: true, combat: false), [])
        XCTAssertEqual(events.observe(before: farAgain, after: enteredDuringCombat, playerID: "me", at: 0.9, active: true, combat: true), [])
        XCTAssertEqual(events.observe(before: enteredDuringCombat, after: stillInRange, playerID: "me", at: 1, active: true, combat: false), [])
        let farWhileInactive = try snapshot(tick: 12, enemyX: 450)
        let resumedNear = try snapshot(tick: 13, enemyX: 270)
        XCTAssertEqual(events.observe(before: stillInRange, after: farWhileInactive, playerID: "me", at: 1.1, active: false, combat: false), [])
        XCTAssertEqual(events.observe(before: farWhileInactive, after: resumedNear, playerID: "me", at: 1.2, active: true, combat: false), [])
    }

    func testGadgetCueHasEntryAndPacedContactThenStopsOnExit() {
        var events = ArenaFeedbackEvents()
        XCTAssertNil(events.gadgetCue(nil, at: 0, active: true))
        XCTAssertEqual(events.gadgetCue(.shaker, at: 0.1, active: true), .shaker)
        XCTAssertNil(events.gadgetCue(.shaker, at: 0.8, active: true))
        XCTAssertEqual(events.gadgetCue(.shaker, at: 1.25, active: true), .shaker)
        XCTAssertNil(events.gadgetCue(nil, at: 1.3, active: true))
        XCTAssertEqual(events.gadgetCue(.grater, at: 1.4, active: true), .grater)
        XCTAssertNil(events.gadgetCue(.grater, at: 1.5, active: false))
        XCTAssertNil(events.gadgetCue(.grater, at: 1.6, active: true))
    }

    func testLostSmallPieceIsAnImpactRatherThanARegroup() throws {
        let before = try snapshot(tick: 1, mass: 100, cellMasses: [98, 2])
        let bitten = try snapshot(tick: 2, mass: 98, cellMasses: [98])
        let merged = try snapshot(tick: 2, mass: 100, cellMasses: [100])
        let mine = try XCTUnwrap(before.players.first)
        let hurt = try XCTUnwrap(bitten.players.first)
        let whole = try XCTUnwrap(merged.players.first)
        XCTAssertFalse(ArenaView.regrouped(before: mine, after: hurt))
        XCTAssertTrue(ArenaView.wasHit(before: mine, after: hurt, regrouped: false))
        XCTAssertTrue(ArenaView.regrouped(before: mine, after: whole))
        XCTAssertFalse(ArenaView.wasHit(before: mine, after: whole, regrouped: true))
    }

    @MainActor func testCuesHaveDistinctShortPatterns() async throws {
        var time: TimeInterval = 0
        var pulses: [(UIImpactFeedbackGenerator.FeedbackStyle, CGFloat)] = []
        let feedback = ArenaFeedback(now: { time }, prepareOutput: {}, emit: { pulses.append(($0, $1)) })
        var signatures: Set<String> = []

        for cue in ArenaFeedbackCue.allCases {
            pulses.removeAll()
            feedback.play(cue)
            try await Task.sleep(for: .milliseconds(120))
            XCTAssertFalse(pulses.isEmpty, "Missing \(cue) feedback")
            let signature = pulses.map { "\($0.0):\($0.1)" }.joined(separator: ",")
            XCTAssertTrue(signatures.insert(signature).inserted, "Repeated \(cue) pattern")
            time += 1
        }
    }

    @MainActor func testRepeatedSnapshotsAreThrottledWithoutCatchUp() async throws {
        var time: TimeInterval = 0
        var pulses: [(UIImpactFeedbackGenerator.FeedbackStyle, CGFloat)] = []
        let feedback = ArenaFeedback(now: { time }, prepareOutput: {}, emit: { pulses.append(($0, $1)) })

        for tick in 0..<10 {
            time = Double(tick) / 10
            feedback.play(.dash)
        }
        XCTAssertEqual(pulses.count, 2)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(pulses.count, 4)
        feedback.stop()
        feedback.play(.dash)
        XCTAssertEqual(pulses.count, 5)
    }

    @MainActor func testStopAndDisableCancelDelayedPulses() async throws {
        var count = 0
        var preparations = 0
        let feedback = ArenaFeedback(now: { 0 }, prepareOutput: { preparations += 1 }, emit: { _, _ in count += 1 })

        feedback.prepare()
        XCTAssertEqual(preparations, 1)
        feedback.play(.split)
        XCTAssertEqual(count, 1)
        feedback.stop()
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(count, 1)

        feedback.play(.split)
        XCTAssertEqual(count, 2)
        feedback.enabled = false
        feedback.prepare()
        feedback.play(.bite)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(count, 2)
        XCTAssertEqual(preparations, 1)

        feedback.enabled = true
        feedback.play(.split)
        XCTAssertEqual(count, 3)
        feedback.stop()
    }

    @MainActor func testLeavingGadgetCancelsItsDelayedPulse() async throws {
        var pulses = 0
        let feedback = ArenaFeedback(now: { 0 }, prepareOutput: {}, emit: { _, _ in pulses += 1 })
        feedback.play(.shaker)
        XCTAssertEqual(pulses, 1)
        feedback.cancelGadgetPulses()
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(pulses, 1)
    }
}
