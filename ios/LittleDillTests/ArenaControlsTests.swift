import XCTest
@testable import LittleDill

final class ArenaControlsTests: XCTestCase {
    func testCenterRejectsThreePointThumbDrift() {
        for reach in [CGFloat(28), CGFloat(34)] {
            for delta in [CGSize.zero, CGSize(width: 2, height: 2), CGSize(width: 3, height: 0)] {
                let input = ArenaStickInput.resolve(delta: delta, reach: reach)
                XCTAssertEqual(input.direction, .zero)
                XCTAssertFalse(input.atEdge)
                XCTAssertEqual(input.offset.width, delta.width, accuracy: 1e-9)
                XCTAssertEqual(input.offset.height, delta.height, accuracy: 1e-9)
            }
            let moving = ArenaStickInput.resolve(delta: CGSize(width: 3.1, height: 0), reach: reach)
            XCTAssertGreaterThan(moving.direction.dx, 0)
        }
    }

    func testShortDragsReachFullSpeedInsideVisibleTravel() {
        for reach in [CGFloat(28), CGFloat(34)] {
            let halfway = ArenaStickInput.resolve(delta: CGSize(width: reach * 0.5, height: 0), reach: reach)
            XCTAssertGreaterThanOrEqual(halfway.direction.dx, 0.75)
            XCTAssertLessThan(halfway.direction.dx, 1)
            XCTAssertEqual(halfway.direction.dy, 0)
            XCTAssertFalse(halfway.atEdge)
            XCTAssertEqual(halfway.offset.width, reach * 0.5, accuracy: 1e-9)

            let full = ArenaStickInput.resolve(delta: CGSize(width: reach * 0.65, height: 0), reach: reach)
            XCTAssertEqual(full.direction.dx, 1, accuracy: 1e-9)
            XCTAssertEqual(full.direction.dy, 0)
            XCTAssertTrue(full.atEdge)
            XCTAssertEqual(full.offset.width, reach * 0.65, accuracy: 1e-9)
        }
    }

    func testDiagonalAndReversePreserveDirectionAndFingerOffset() {
        for reach in [CGFloat(28), CGFloat(34)] {
            let delta = CGSize(width: reach * 0.3, height: -reach * 0.4)
            let input = ArenaStickInput.resolve(delta: delta, reach: reach)
            let speed = hypot(input.direction.dx, input.direction.dy)
            XCTAssertEqual(input.direction.dx / speed, 0.6, accuracy: 1e-9)
            XCTAssertEqual(input.direction.dy / speed, -0.8, accuracy: 1e-9)
            XCTAssertGreaterThanOrEqual(speed, 0.75)
            XCTAssertEqual(input.offset.width, delta.width, accuracy: 1e-9)
            XCTAssertEqual(input.offset.height, delta.height, accuracy: 1e-9)

            let reverse = ArenaStickInput.resolve(delta: CGSize(width: -delta.width, height: -delta.height), reach: reach)
            XCTAssertEqual(reverse.direction.dx, -input.direction.dx, accuracy: 1e-9)
            XCTAssertEqual(reverse.direction.dy, -input.direction.dy, accuracy: 1e-9)
            XCTAssertEqual(reverse.offset.width, -input.offset.width, accuracy: 1e-9)
            XCTAssertEqual(reverse.offset.height, -input.offset.height, accuracy: 1e-9)
        }
    }

    func testDragBeyondStickKeepsDirectionAndCapsServerInput() {
        let input = ArenaStickInput.resolve(delta: CGSize(width: 120, height: -120), reach: 28)
        XCTAssertEqual(hypot(input.direction.dx, input.direction.dy), 1, accuracy: 1e-9)
        XCTAssertEqual(hypot(input.offset.width, input.offset.height), 28, accuracy: 1e-9)
        XCTAssertGreaterThan(input.direction.dx, 0)
        XCTAssertEqual(input.direction.dx, -input.direction.dy, accuracy: 1e-9)
        XCTAssertTrue(input.atEdge)
    }

    func testNativeStickMatchesSharedWebFixtures() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "arena-parity", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        for row in fixture.joystick {
            let input = ArenaStickInput.resolve(delta: CGSize(width: row.dx, height: row.dy), reach: row.reach)
            XCTAssertEqual(input.offset.width, row.offsetX, accuracy: 1e-9)
            XCTAssertEqual(input.offset.height, row.offsetY, accuracy: 1e-9)
            XCTAssertEqual(input.direction.dx, row.x, accuracy: 1e-9)
            XCTAssertEqual(input.direction.dy, row.y, accuracy: 1e-9)
            XCTAssertEqual(input.atEdge, row.atEdge)
        }
    }

    private struct Fixture: Decodable { let joystick: [Stick] }
    private struct Stick: Decodable {
        let dx: CGFloat
        let dy: CGFloat
        let reach: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
        let x: CGFloat
        let y: CGFloat
        let atEdge: Bool
    }
}
