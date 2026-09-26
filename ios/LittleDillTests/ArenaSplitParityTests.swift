import XCTest
@testable import LittleDill

final class ArenaSplitParityTests: XCTestCase {
    private func player(masses: [Double]?, cooldown: Double = 0, alive: Bool = true) throws -> ArenaPlayer {
        var state: [String: Any] = [
            "id": "you", "name": "Dilly", "brine": "classic", "outfit": "sprout",
            "bot": false, "x": 100, "y": 200, "mass": masses?.reduce(0, +) ?? 90,
            "best": 120, "kills": 0, "alive": alive, "shield": 0, "dash": 0,
            "cooldown": 0, "splitCooldown": cooldown, "respawn": 0, "eatenBy": ""
        ]
        if let masses {
            state["cells"] = masses.enumerated().map { index, mass in
                ["id": "cell-\(index)", "x": 100, "y": 200, "mass": mass] as [String: Any]
            }
        }
        return try JSONDecoder().decode(ArenaPlayer.self, from: JSONSerialization.data(withJSONObject: state))
    }

    func testSplitAllowsFourAndSevenPieces() throws {
        for count in [4, 7] {
            let subject = try player(masses: Array(repeating: 60, count: count))
            XCTAssertTrue(subject.canSplit, "\(count) pieces")
            XCTAssertEqual(subject.splitHint, "Launch a half")
        }
    }

    func testSplitBlocksEightPieces() throws {
        let subject = try player(masses: Array(repeating: 60, count: 8))
        XCTAssertFalse(subject.canSplit)
        XCTAssertEqual(subject.splitHint, "8 cucumbers max")
    }

    func testSplitWaitsForCooldown() throws {
        let subject = try player(masses: [60], cooldown: 0.1)
        XCTAssertFalse(subject.canSplit)
        XCTAssertEqual(subject.splitHint, "Ready in 1s")
        XCTAssertTrue(try player(masses: [60], cooldown: 0).canSplit)
    }

    func testSplitRequiresOneCellWithAtLeastSixtyMass() throws {
        let small = try player(masses: [59.9, 59.9])
        XCTAssertFalse(small.canSplit)
        XCTAssertEqual(small.splitHint, "One cucumber needs 60")
        XCTAssertTrue(try player(masses: [59.9, 60]).canSplit)
    }

    func testOldServerAndDeadPlayerCannotSplit() throws {
        let oldServer = try player(masses: nil)
        XCTAssertFalse(oldServer.canSplit)
        XCTAssertEqual(oldServer.splitHint, "Rejoin to split")
        let dead = try player(masses: [60], alive: false)
        XCTAssertFalse(dead.canSplit)
        XCTAssertEqual(dead.splitHint, "Respawn to split")
    }
}
