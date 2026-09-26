import XCTest
@testable import LittleDill

final class FeedFoodTests:XCTestCase {
    func testFoodRotationMatchesWebAndPerformanceKeepsItsSelection() {
        let order = ["carrot","strawberry","broccoli","apple","cheese"]
        XCTAssertEqual((0..<10).map {FeedFood.at($0).rawValue},order + order)
        let performance = CarePerformance(action:.feed,food:FeedFood.at(2))
        _ = FeedFood.at(3)
        XCTAssertEqual(performance.food,.broccoli)
        XCTAssertEqual(performance.duration,3.8)
    }
}
