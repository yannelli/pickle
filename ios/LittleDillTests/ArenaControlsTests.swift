import XCTest
@testable import LittleDill

final class ArenaControlsTests: XCTestCase {
    func testCenterRejectsThumbDriftAndPreservesPreciseSteering() {
        let center = ArenaStickInput.resolve(delta: .zero, reach: 34)
        XCTAssertEqual(center.direction, .zero)
        let drift = ArenaStickInput.resolve(delta: CGSize(width: 2, height: 2), reach: 34)
        XCTAssertEqual(drift.direction, .zero)
        let gentle = ArenaStickInput.resolve(delta: CGSize(width: 17, height: 0), reach: 34)
        let stronger = ArenaStickInput.resolve(delta: CGSize(width: 26, height: 0), reach: 34)
        XCTAssertGreaterThan(gentle.direction.dx, 0)
        XCTAssertLessThan(gentle.direction.dx, 0.5)
        XCTAssertEqual(gentle.direction.dy, 0)
        XCTAssertGreaterThan(stronger.direction.dx, gentle.direction.dx)
        XCTAssertFalse(gentle.atEdge)
    }

    func testDragBeyondStickKeepsDirectionAndCapsServerInput() {
        let input = ArenaStickInput.resolve(delta: CGSize(width: 120, height: -120), reach: 28)
        XCTAssertEqual(hypot(input.direction.dx, input.direction.dy), 1, accuracy: 1e-9)
        XCTAssertEqual(hypot(input.offset.width, input.offset.height), 28, accuracy: 1e-9)
        XCTAssertGreaterThan(input.direction.dx, 0)
        XCTAssertEqual(input.direction.dx, -input.direction.dy, accuracy: 1e-9)
        XCTAssertTrue(input.atEdge)
    }
}
