import XCTest
@testable import ExpressiveUI

final class ExpressiveMenuShapesTests: XCTestCase {
    func testALoneGroupIsRoundAtBothEnds() {
        let corners = ExpressiveMenuShapes.group(index: 0, count: 1)
        XCTAssertEqual(corners.top, ExpressiveMenuShapes.groupOuter)
        XCTAssertEqual(corners.bottom, ExpressiveMenuShapes.groupOuter)
    }

    /// The ends of a run face the outside with the outer radius and each other with the inner one,
    /// which is what makes a stack of groups read as one card cut into pieces.
    func testARunOfGroupsRoundsOnlyItsOutsideEdges() {
        let first = ExpressiveMenuShapes.group(index: 0, count: 3)
        let middle = ExpressiveMenuShapes.group(index: 1, count: 3)
        let last = ExpressiveMenuShapes.group(index: 2, count: 3)

        XCTAssertEqual(first.top, ExpressiveMenuShapes.groupOuter)
        XCTAssertEqual(first.bottom, ExpressiveMenuShapes.groupInner)
        XCTAssertEqual(middle.top, ExpressiveMenuShapes.groupInner)
        XCTAssertEqual(middle.bottom, ExpressiveMenuShapes.groupInner)
        XCTAssertEqual(last.top, ExpressiveMenuShapes.groupInner)
        XCTAssertEqual(last.bottom, ExpressiveMenuShapes.groupOuter)
    }

    func testItemsFollowTheSameRuleAtTheirOwnRadii() {
        let first = ExpressiveMenuShapes.item(index: 0, count: 3, isSelected: false)
        let middle = ExpressiveMenuShapes.item(index: 1, count: 3, isSelected: false)

        XCTAssertEqual(first.top, ExpressiveMenuShapes.itemOuter)
        XCTAssertEqual(first.bottom, ExpressiveMenuShapes.itemInner)
        XCTAssertEqual(middle.top, ExpressiveMenuShapes.itemInner)
    }

    /// Selected, an item leaves the run: it is round on all four corners wherever it sits.
    func testASelectedItemIsRoundWhereverItSits() {
        for index in 0..<3 {
            let corners = ExpressiveMenuShapes.item(index: index, count: 3, isSelected: true)
            XCTAssertEqual(corners.top, ExpressiveMenuShapes.itemSelected)
            XCTAssertEqual(corners.bottom, ExpressiveMenuShapes.itemSelected)
        }
    }
}
