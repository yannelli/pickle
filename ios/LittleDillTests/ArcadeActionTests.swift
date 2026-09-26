import XCTest
@testable import LittleDill

final class ArcadeActionTests: XCTestCase {
    func testEveryGameStartsItsOwnSession() {
        for game in ArcadeGame.allCases {
            let play = game.play(reduceMotion: false, seed: 7)
            XCTAssertEqual(play.game, game)
            XCTAssertEqual(play is ArcadeEngine, game.isClassic, game.rawValue)
            XCTAssertFalse(play.isFinished, game.rawValue)
        }
        XCTAssertEqual(Set(ArcadeGame.allCases.map(\.rawValue)), Set(PetState.arcadeGames))
    }

    func testHopWaitsForTheFirstTapThenClearsCountertopObstacles() {
        var run = HopRun(seed: 3)
        _ = run.advance(by: 2)
        XCTAssertFalse(run.started)
        XCTAssertEqual(run.obstacles.first?.x, HopRules.firstX)
        var cues: [ArcadeCue] = []
        XCTAssertEqual(run.hop(), [.hop])
        var seenKinds = Set<String>()
        var gaps: [Double] = []
        for _ in 0..<(60 * 15) {
            let next = run.obstacles.first { !$0.passed }
            if let next, next.x < 150, run.y >= HopRules.restY, run.vy >= 0 {
                cues += run.hop()
            }
            cues += run.advance(by: 1.0 / 60)
            for obstacle in run.obstacles { seenKinds.insert(String(describing: obstacle.kind)) }
            for pair in zip(run.obstacles, run.obstacles.dropFirst()) { gaps.append(pair.1.x - pair.0.x) }
            if run.crashed { break }
        }
        XCTAssertFalse(run.crashed, "score \(run.score)")
        XCTAssertGreaterThanOrEqual(run.cleared, 10)
        XCTAssertGreaterThan(run.distance, HopRules.zoneLength * 2)
        XCTAssertEqual(seenKinds, Set(["salt", "fork", "pepper", "spoon"]))
        XCTAssertTrue(cues.contains(.ding))
        XCTAssertTrue(cues.contains(.good))
        XCTAssertTrue(cues.contains(.streak))
        XCTAssertTrue(cues.contains(.landing))
        XCTAssertGreaterThanOrEqual(gaps.min() ?? 0, 169.9)
        XCTAssertLessThan(gaps.min() ?? 0, 200)
        XCTAssertGreaterThan(gaps.max() ?? 0, 270)
    }

    func testHopScenesVaryWithoutAdjacentRepeats() {
        let scenes = (0..<40).map { HopScenery.scene(seed: 3, index: $0) }
        XCTAssertEqual(scenes, (0..<40).map { HopScenery.scene(seed: 3, index: $0) })
        XCTAssertEqual(Set(scenes.map { String(describing: $0.kind) }).count, 5)
        XCTAssertGreaterThan(Set(scenes.map { "\($0.kind)-\($0.variant)" }).count, 10)
        for (left, right) in zip(scenes, scenes.dropFirst()) {
            XCTAssertNotEqual(left.kind, right.kind)
        }
        XCTAssertNotEqual(scenes, (0..<40).map { HopScenery.scene(seed: 19, index: $0) })
    }

    func testHopBuffersATapJustBeforeLanding() {
        var run = HopRun(seed: 3)
        XCTAssertEqual(run.hop(), [.hop])
        _ = run.advance(by: 0.68)
        XCTAssertLessThan(run.y, HopRules.restY)
        XCTAssertEqual(run.hop(), [])
        let cues = run.advance(by: 0.18)
        XCTAssertTrue(cues.contains(.hop))
        XCTAssertGreaterThan(run.lastHop, 0.68)
        XCTAssertLessThan(run.y, HopRules.restY)
    }

    func testHopSameSeedProducesSameRun() {
        var a = HopRun(seed: 19)
        var b = HopRun(seed: 19)
        XCTAssertEqual(a.hop(), b.hop())
        for _ in 0..<360 {
            let next = a.obstacles.first { !$0.passed }
            if let next, next.x < 150, a.y >= HopRules.restY, a.vy >= 0 {
                XCTAssertEqual(a.hop(), b.hop())
            }
            XCTAssertEqual(a.advance(by: 1.0 / 60), b.advance(by: 1.0 / 60))
            XCTAssertEqual(a.obstacles, b.obstacles)
        }
        XCTAssertEqual(a.score, b.score)
        XCTAssertGreaterThan(a.cleared, 2)
    }

    func testHopEndsAfterOneBump() {
        var run = HopRun(seed: 3)
        _ = run.hop()
        var cues: [ArcadeCue] = []
        for _ in 0..<(60 * 4) { cues += run.advance(by: 1.0 / 60) }
        XCTAssertTrue(run.crashed)
        XCTAssertTrue(run.isFinished)
        XCTAssertEqual(cues.filter { $0 == .bonk }.count, 1)
        XCTAssertEqual(cues.last, .finished)
        XCTAssertEqual(run.hop(), [])
    }

    func testChopCutsCukesAndBonksThePickle() {
        var run = ChopRun(seed: 11)
        var bonked = false
        for _ in 0..<(60 * 90) where !bonked && !run.isOver {
            _ = run.advance(by: 1.0 / 60)
            for item in run.items where !item.bonked && item.y < 560 {
                let before = (score: run.score, lives: run.lives)
                let cues = run.swipe(from: CGPoint(x: item.x - 40, y: item.y), to: CGPoint(x: item.x + 40, y: item.y))
                _ = run.endSwipe()
                if item.kind == .pal {
                    XCTAssertTrue(cues.contains(.bonk)); XCTAssertEqual(run.lives, before.lives - 1)
                    bonked = true
                } else if cues == [.chop] {
                    XCTAssertEqual(run.score, before.score + ChopRules.points(item.kind))
                }
                break
            }
        }
        XCTAssertTrue(bonked, "a pickle pal shows up once the score passes 4")
        XCTAssertGreaterThanOrEqual(run.score, 4)
        XCTAssertFalse(run.halves.isEmpty)
    }

    func testChopComboAndDrops() {
        var run = ChopRun(seed: 5)
        var combo = false
        for _ in 0..<(60 * 180) where !run.isOver {
            _ = run.advance(by: 1.0 / 60)
            guard !combo else { continue }
            let cukes = run.items.filter { $0.kind != .pal && $0.y < 560 }
            guard cukes.count >= 3, !run.items.contains(where: { $0.kind == .pal }) else {
                for cuke in cukes where cuke.vy > 0 && cuke.y > 500 {
                    _ = run.swipe(from: CGPoint(x: cuke.x - 40, y: cuke.y), to: CGPoint(x: cuke.x + 40, y: cuke.y))
                    _ = run.endSwipe()
                }
                continue
            }
            let before = run.score
            var from = CGPoint(x: cukes[0].x, y: cukes[0].y)
            for cuke in cukes {
                let to = CGPoint(x: cuke.x, y: cuke.y)
                _ = run.swipe(from: from, to: to)
                from = to
            }
            XCTAssertEqual(run.endSwipe(), [.good])
            XCTAssertGreaterThanOrEqual(run.score - before, cukes.count * 2)
            combo = true
        }
        XCTAssertTrue(combo)
        XCTAssertTrue(run.isOver, "unsliced cukes cost hearts until the run ends")
        XCTAssertEqual(run.lives, 0)
        var tail: [ArcadeCue] = []
        for _ in 0..<120 { tail += run.advance(by: 1.0 / 60) }
        XCTAssertTrue(run.isFinished)
        XCTAssertEqual(tail.last, .finished)
        XCTAssertEqual(ChopRun.distance(CGPoint(x: 5, y: 5), CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)), 5)
    }

    private func throwResult(_ pull: CGVector, seed: UInt64 = 1) -> TossRun {
        var run = TossRun(seed: seed)
        _ = run.aim(pull)
        _ = run.release()
        for _ in 0..<(240 * 6) where run.state == .flying { _ = run.advance(by: 1.0 / 240) }
        return run
    }

    func testTossLandsInTheJarAndMissesCostThrows() throws {
        var swish: CGVector?
        search: for dx in stride(from: 20.0, through: 120, by: 4) {
            for dy in stride(from: -120.0, through: 0, by: 4) where throwResult(CGVector(dx: dx, dy: dy)).score == 2 {
                swish = CGVector(dx: dx, dy: dy)
                break search
            }
        }
        let pull = try XCTUnwrap(swish, "some pull lands a clean swish in the first jar")
        var run = throwResult(pull)
        XCTAssertEqual(run.state, .landed)
        XCTAssertEqual(run.lives, TossRules.lives)
        _ = run.advance(by: 1.2)
        XCTAssertEqual(run.state, .aiming)

        var cues: [ArcadeCue] = []
        for _ in 0..<TossRules.lives {
            cues += run.aim(CGVector(dx: 20, dy: 0))
            XCTAssertEqual(run.preview().count, TossRules.previewDots(score: run.score))
            cues += run.release()
            for _ in 0..<(240 * 3) { cues += run.advance(by: 1.0 / 240) }
        }
        XCTAssertEqual(cues.filter { $0 == .miss }.count, TossRules.lives)
        XCTAssertTrue(run.isFinished)
        XCTAssertEqual(cues.last, .finished)
        XCTAssertEqual(run.release(), [])
    }

    func testTossIgnoresATinyPull() {
        var run = TossRun(seed: 2)
        XCTAssertEqual(run.aim(CGVector(dx: 5, dy: -5)), [.select])
        XCTAssertEqual(run.release(), [])
        XCTAssertEqual(run.state, .aiming)
        XCTAssertEqual(run.x, TossRules.anchor.x)
    }
}
