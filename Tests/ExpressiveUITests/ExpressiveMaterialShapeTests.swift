import XCTest
@testable import ExpressiveUI

final class ExpressiveMaterialShapeTests: XCTestCase {
    private let angles: [Double] = (0..<128).map { 2 * .pi * Double($0) / 128 }

    /// Every shape in the sequence has to be normalised the same way, or a morph between two of
    /// them would be a resize as much as a change of shape.
    func testEveryShapeReachesOneAndNeverExceedsIt() {
        for shape in ExpressiveMaterialShape.indeterminateSequence {
            let radii = angles.map { shape.radius(atAngle: $0) }
            XCTAssertLessThanOrEqual(radii.max() ?? 0, 1.0001)
            XCTAssertGreaterThan(radii.max() ?? 0, 0.98)
            XCTAssertGreaterThan(radii.min() ?? 0, 0)
        }
    }

    /// Sunny is eight points at an inner radius of 0.8. Rounding pulls the extremes in a little, so
    /// this checks the count and the depth rather than exact figures: eight peaks, and troughs that
    /// sit near 0.8 rather than at the middle or the edge.
    func testSunnyHasEightPointsAtRoughlyItsInnerRadius() {
        let sunny = ExpressiveMaterialShape.sunny
        let dense = (0..<720).map { sunny.radius(atAngle: 2 * .pi * Double($0) / 720) }
        var peaks = 0
        for index in dense.indices {
            let before = dense[(index + dense.count - 1) % dense.count]
            let after = dense[(index + 1) % dense.count]
            if dense[index] > before, dense[index] >= after { peaks += 1 }
        }
        XCTAssertEqual(peaks, 8)
        XCTAssertEqual(dense.min() ?? 0, 0.8, accuracy: 0.06)
    }

    func testACircleIsTheSameInEveryDirection() {
        let radii = angles.map { ExpressiveMaterialShape.circle.radius(atAngle: $0) }
        XCTAssertEqual(radii.min(), radii.max())
    }

    /// Material's Pill is not a capsule. Its reference image is a soft blob, built from three
    /// points mirrored around the centre, so it repeats every half turn and is a little wider one
    /// way than the other.
    func testThePillRepeatsEveryHalfTurnAndIsNotACircle() {
        let pill = ExpressiveMaterialShape.pill
        for angle in stride(from: 0.0, to: .pi, by: 0.1) {
            XCTAssertEqual(
                pill.radius(atAngle: angle),
                pill.radius(atAngle: angle + .pi),
                accuracy: 0.02
            )
        }
        let radii = (0..<360).map { pill.radius(atAngle: 2 * .pi * Double($0) / 360) }
        let spread = (radii.max() ?? 1) / (radii.min() ?? 1)
        XCTAssertGreaterThan(spread, 1.05)
        XCTAssertLessThan(spread, 1.5)
    }

    /// Rounding a corner may never push it outside the polygon it belongs to.
    func testRoundingStaysInsideTheShape() {
        let square = [
            RoundedVertex(-1, -1, 0.4),
            RoundedVertex(1, -1, 0.4),
            RoundedVertex(1, 1, 0.4),
            RoundedVertex(-1, 1, 0.4)
        ]
        for point in ExpressiveRoundedPolygon.outline(square) {
            XCTAssertLessThanOrEqual(abs(point.x), 1.0001)
            XCTAssertLessThanOrEqual(abs(point.y), 1.0001)
        }
    }

    /// A corner asked for more rounding than its edges can hold gets cut back rather than folding
    /// the outline through itself — which is what a nine-sided cookie at 0.5 needs.
    func testOverlargeRoundingIsCutBackInsteadOfFoldingOver() {
        let spike = [
            RoundedVertex(0, -1, 5),
            RoundedVertex(0.2, 0, 5),
            RoundedVertex(0, 1, 5),
            RoundedVertex(-0.2, 0, 5)
        ]
        let outline = ExpressiveRoundedPolygon.outline(spike)
        for point in outline {
            XCTAssertLessThanOrEqual(abs(point.y), 1.0001)
        }
    }

    func testMorphingProducesAClosedPathOfTheRightSize() {
        let rect = CGRect(x: 0, y: 0, width: 38, height: 38)
        let path = ExpressiveMaterialShape.indeterminateSequence.morphedPath(
            index: 0,
            progress: 0.5,
            in: rect
        )
        XCTAssertFalse(path.isEmpty)
        XCTAssertLessThanOrEqual(path.boundingBox.width, rect.width + 0.001)
        XCTAssertLessThanOrEqual(path.boundingBox.height, rect.height + 0.001)
    }
}
