import XCTest
@testable import LittleDill

final class ArenaEarningsTests: XCTestCase {
    private let firstDay = "2026-09-25"
    private let nextDay = "2026-09-26"
    private let firstSession = "PUBLIC:player-1"

    func testIncrementalSnapshotsCreditWholeCoinsOnce() {
        var earnings = ArenaEarnings()
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 0, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 250, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_000, day: firstDay), 1)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_000, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 999, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 100_000, day: firstDay), 99)
        XCTAssertEqual(earnings.mass, 100_000)
        XCTAssertEqual(earnings.total, 100_000)
        XCTAssertEqual(ArenaEarnings.massPerCoin, 1_000)
    }

    func testDailyCapConsumesExcessAndDoesNotPayItTomorrow() {
        var earnings = ArenaEarnings()
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 100_000, day: firstDay), 100)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_200_000, day: firstDay), 900)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_300_000, day: firstDay), 0)
        XCTAssertEqual(earnings.mass, ArenaEarnings.dailyMassLimit)
        XCTAssertEqual(earnings.total, 1_300_000)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_300_000, day: nextDay), 0)
        XCTAssertEqual(earnings.mass, 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_301_000, day: nextDay), 1)
        XCTAssertEqual(ArenaEarnings.dailyCoinLimit, 1_000)
    }

    func testRespawnAndReconnectKeepTheCurrentCursor() throws {
        var earnings = ArenaEarnings()
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_500, day: firstDay), 1)
        let restored = try JSONDecoder().decode(ArenaEarnings.self, from: JSONEncoder().encode(earnings))
        XCTAssertEqual(restored, earnings)
        earnings = restored
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_500, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_300, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 2_000, day: firstDay), 1)
        XCTAssertEqual(earnings.mass, 2_000)
    }

    func testDayRolloverResetsFractionWhileKeepingTotal() {
        var earnings = ArenaEarnings()
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 999, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 999, day: nextDay), 0)
        XCTAssertEqual(earnings.total, 999)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_998, day: nextDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_999, day: nextDay), 1)
        XCTAssertEqual(earnings.mass, 1_000)
    }

    func testNewSessionStartsAtZeroAndKeepsDailyCap() {
        var earnings = ArenaEarnings()
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 100_000, day: firstDay), 100)
        XCTAssertEqual(earnings.record(session: "ROOM42:player-2", earnedMass: 10_000, day: firstDay), 10)
        XCTAssertEqual(earnings.session, "ROOM42:player-2")
        XCTAssertEqual(earnings.total, 10_000)
        XCTAssertEqual(earnings.mass, 110_000)
    }

    func testOlderDayDoesNotReopenTheAllowanceOrMoveCursor() {
        var earnings = ArenaEarnings()
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 1_000, day: firstDay), 1)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 2_000, day: nextDay), 1)
        let before = earnings
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 3_000, day: firstDay), 0)
        XCTAssertEqual(earnings, before)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 3_000, day: nextDay), 1)
    }

    func testInvalidInputsAndMalformedSavesAreClamped() throws {
        var earnings = ArenaEarnings(day: "2026-02-30", mass: .nan, session: "bad", total: .infinity)
        XCTAssertEqual(earnings, ArenaEarnings())
        let saved = try JSONDecoder().decode(ArenaEarnings.self, from: Data(
            #"{"day":"2026-09-25","mass":"bad","session":"PUBLIC:player-1","total":-5}"#.utf8))
        XCTAssertEqual(saved.mass, 0)
        XCTAssertEqual(saved.total, 0)
        let capped = ArenaEarnings(day: firstDay, mass: 2_000_000, session: firstSession, total: 50)
        XCTAssertEqual(capped.mass, ArenaEarnings.dailyMassLimit)
        XCTAssertEqual(earnings.record(session: "", earnedMass: 2_000, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: "bad", earnedMass: 2_000, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: -.infinity, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: -1, day: firstDay), 0)
        XCTAssertEqual(earnings.record(session: firstSession, earnedMass: 2_000, day: "2026-13-01"), 0)
        XCTAssertEqual(earnings, ArenaEarnings())
    }
}
