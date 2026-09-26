import SwiftUI
import XCTest
@testable import LittleDill

@MainActor final class PickleBodyTests: XCTestCase {
    func testSixDistinctUprightSilhouettes() {
        let shapes = PickleVariety.all.map(\.shape)
        XCTAssertEqual(Set(shapes.map(\.rawValue)).count, 6)
        var signatures = Set<String>()
        for shape in shapes {
            let profile = PickleBody.profile(shape)
            let points = PickleBody.points(shape, width: profile.width, height: profile.height)
            XCTAssertEqual(points.count, 72)
            signatures.insert(points.map { String(format: "%.5f,%.5f", $0.x, $0.y) }.joined(separator: ";"))
            for i in 0..<72 {
                let angle = Double(i) * .pi * 2 / 72
                let radius = PickleBody.radius(shape, at: angle, width: profile.width, height: profile.height)
                XCTAssertGreaterThan(radius, 0)
                XCTAssertTrue(radius.isFinite)
                let reflected = PickleBody.radius(shape, at: .pi - angle, width: profile.width, height: profile.height)
                XCTAssertEqual(radius, reflected, accuracy: 1e-10, shape.rawValue)
            }
            XCTAssertEqual(points[18].x, 0, accuracy: 1e-10)
            XCTAssertEqual(points[54].x, 0, accuracy: 1e-10)
        }
        XCTAssertEqual(signatures.count, 6)
        XCTAssertGreaterThan(radius(.pear, .pi / 4), radius(.pear, -.pi / 4))
        XCTAssertLessThan(radius(.tapered, .pi / 4), radius(.tapered, -.pi / 4))
    }

    func testBodiesMatchSharedWebProfilesAndSamples() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "arena-parity", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.bodyProfiles.count, 6)
        XCTAssertFalse(fixture.bodySamples.isEmpty)
        for (name, expected) in fixture.bodyProfiles {
            let shape = try XCTUnwrap(PickleVariety.Shape(rawValue: name))
            let profile = PickleBody.profile(shape)
            XCTAssertEqual(profile.width, expected.width, accuracy: 1e-10)
            XCTAssertEqual(profile.height, expected.height, accuracy: 1e-10)
        }
        for sample in fixture.bodySamples {
            let shape = try XCTUnwrap(PickleVariety.Shape(rawValue: sample.shape))
            XCTAssertEqual(PickleBody.radius(shape, at: sample.angle, width: sample.width, height: sample.height), sample.radius, accuracy: 1e-9)
            let variety = try XCTUnwrap(PickleVariety.all.first { $0.shape == shape })
            let arena = ArenaShape(try player(variety), r: 50)
            XCTAssertEqual(arena.hw, sample.width, accuracy: 1e-9)
            XCTAssertEqual(arena.hh, sample.height, accuracy: 1e-9)
            XCTAssertEqual(arena.radius(at: sample.angle), sample.radius, accuracy: 1e-9)
            XCTAssertEqual(arena.lean, 0)
        }
    }

    func testFaceLimbsAndFeetFitEveryLifeStage() {
        for variety in PickleVariety.all {
            for stage in stages {
                let look = PickleLook(variety: variety, stage: stage)
                let f = PickleFrame(look: look)
                XCTAssertLessThanOrEqual(f.face + 27, f.h)
                XCTAssertTrue(f.outline.contains(CGPoint(x: f.w / 2, y: f.face + 12.5)), "\(variety.id) \(stage)")
                let armY = f.arm + 13.5, edge = f.edgeX(at: armY)
                XCTAssertGreaterThan(edge, f.w / 2)
                XCTAssertTrue(f.outline.contains(CGPoint(x: edge - 2, y: armY)))
                for side in [-1.0, 1.0] {
                    let footX = f.w / 2 + f.w * 0.16 * side
                    let root = CGPoint(x: footX, y: f.bottomY(at: footX) - 2)
                    XCTAssertTrue(f.outline.contains(root))
                    XCTAssertLessThan(root.y, f.h + 1)
                }
                XCTAssertLessThan(f.h + 6, 102)
                XCTAssertLessThan(f.w, 80)
            }
        }
    }

    func testFoodTracksMouthThroughPoseTransforms() {
        var pose = PicklePose()
        pose.actor = Motion(x: -7, y: 4, rotation: -8, sx: 0.91, sy: 1.08)
        pose.body = Motion(x: 3, y: -8, rotation: 13, sx: 1.12, sy: 0.88)
        pose.faceX = 2.5
        for variety in PickleVariety.all {
            for stage in stages {
                let look = PickleLook(variety: variety, stage: stage)
                let f = PickleFrame(look: look)
                var expected = CGPoint(x: pose.faceX, y: f.face + 12.5 - f.h - 6)
                for motion in [pose.body, pose.actor] { expected = apply(motion, to: expected) }
                expected.x *= CareScene.unit
                expected.y = expected.y * CareScene.unit + CareScene.groundOffset
                let actual = CareScene.mouth(look: look, pose: pose)
                XCTAssertEqual(actual.x, expected.x, accuracy: 1e-8)
                XCTAssertEqual(actual.y, expected.y, accuracy: 1e-8)
            }
        }
    }

    private let stages: [LifeStage] = [.baby, .young, .teen, .adult, .elder]
    private func radius(_ shape: PickleVariety.Shape, _ angle: Double) -> Double {
        let profile = PickleBody.profile(shape)
        return PickleBody.radius(shape, at: angle, width: profile.width, height: profile.height)
    }
    private func apply(_ motion: Motion, to point: CGPoint) -> CGPoint {
        let angle = motion.rotation * .pi / 180, x = point.x * motion.sx, y = point.y * motion.sy
        return CGPoint(x: x * cos(angle) - y * sin(angle) + motion.x, y: x * sin(angle) + y * cos(angle) + motion.y)
    }
    private func player(_ variety: PickleVariety) throws -> ArenaPlayer {
        let fields: [String: Any] = ["id": "pet", "name": "Dilly", "brine": variety.brine, "outfit": "original", "variety": variety.id,
                                     "bot": false, "x": 100, "y": 100, "mass": 100, "best": 100, "kills": 0, "alive": true,
                                     "shield": 0, "dash": 0, "cooldown": 0, "respawn": 0, "eatenBy": ""]
        return try JSONDecoder().decode(ArenaPlayer.self, from: JSONSerialization.data(withJSONObject: fields))
    }
    private struct Fixture: Decodable { let bodyProfiles: [String: Profile]; let bodySamples: [Sample] }
    private struct Profile: Decodable { let width: Double; let height: Double }
    private struct Sample: Decodable { let shape: String; let angle: Double; let width: Double; let height: Double; let radius: Double }
}
