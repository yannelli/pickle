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

    func testHopWaitsForTheFirstTapThenScoresForks() {
        var run = HopRun(seed: 3)
        _ = run.advance(by: 2)
        XCTAssertFalse(run.started)
        XCTAssertEqual(run.forks.first?.x, ArcadeWorld.width + 60)
        var cues: [ArcadeCue] = []
        var lastTap = -1.0
        XCTAssertEqual(run.hop(), [.hop])
        for _ in 0..<(60 * 12) {
            let next = run.forks.first { $0.x + HopRules.forkWidth > HopRules.pickleX - HopRules.radius }
            let target = (next?.gapY ?? 270) + 22
            if run.y > target, run.time - lastTap > 0.12 { cues += run.hop(); lastTap = run.time }
            cues += run.advance(by: 1.0 / 60)
        }
        XCTAssertFalse(run.crashed, "score \(run.score)")
        XCTAssertGreaterThanOrEqual(run.score, 5)
        XCTAssertTrue(cues.contains(.ding))
    }

    func testHopEndsAfterOneBump() {
        var run = HopRun(seed: 3)
        _ = run.hop()
        var cues: [ArcadeCue] = []
        for _ in 0..<(60 * 4) { cues += run.advance(by: 1.0 / 60) }
        XCTAssertTrue(run.crashed)
        XCTAssertTrue(run.isFinished)
        XCTAssertEqual(cues.filter { $0 == .miss }.count, 1)
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
