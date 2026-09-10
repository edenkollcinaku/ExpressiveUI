import XCTest
@testable import ExpressiveUI

final class ExpressiveMaterialShapeTests: XCTestCase {
    private let angles: [Double] = (0..<64).map { 2 * .pi * Double($0) / 64 }

    /// Every shape in the sequence has to be normalised the same way, or a morph between two of
    /// them would be a resize as much as a change of shape.
    func testEveryShapeReachesOneAndNeverExceedsIt() {
        for shape in ExpressiveMaterialShape.indeterminateSequence {
            let radii = angles.map(shape.radius)
            XCTAssertLessThanOrEqual(radii.max() ?? 0, 1.0001)
            XCTAssertGreaterThan(radii.max() ?? 0, 0.98)
            XCTAssertGreaterThan(radii.min() ?? 0, 0)
        }
    }

    func testAStarDipsToItsInnerRadiusBetweenPoints() {
        let star = ExpressiveMaterialShape.star(points: 8, innerRadius: 0.8, sharpness: 2.2)
        // A lobe peaks where cos(8θ) is 1 and troughs half a lobe later.
        XCTAssertEqual(star.radius(0), 1, accuracy: 0.0001)
        XCTAssertEqual(star.radius(.pi / 8), 0.8, accuracy: 0.0001)
    }

    func testACircleIsTheSameInEveryDirection() {
        let radii = angles.map(ExpressiveMaterialShape.circle.radius)
        XCTAssertEqual(radii.min(), radii.max())
    }

    /// The pill is wider than it is tall, and its flank is flat — the radius at the side is its
    /// half-height, not something the quadratic branch invented.
    func testTheCapsuleIsFlatAlongItsFlank() {
        let pill = ExpressiveMaterialShape.capsule(halfHeight: 0.55)
        XCTAssertEqual(pill.radius(.pi / 2), 0.55, accuracy: 0.0001)
        XCTAssertEqual(pill.radius(0), 1, accuracy: 0.0001)
    }

    func testMorphingProducesAClosedPathOfTheRightSize() {
        let rect = CGRect(x: 0, y: 0, width: 38, height: 38)
        let path = ExpressiveMaterialShape.indeterminateSequence.morphedPath(
            index: 0,
            progress: 0.5,
            in: rect
        )
        XCTAssertFalse(path.isEmpty)
        // Nothing may spill outside the box the indicator is given.
        XCTAssertLessThanOrEqual(path.boundingBox.width, rect.width + 0.001)
        XCTAssertLessThanOrEqual(path.boundingBox.height, rect.height + 0.001)
    }
}
