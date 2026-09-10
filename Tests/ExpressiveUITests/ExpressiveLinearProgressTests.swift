import XCTest
@testable import ExpressiveUI

final class ExpressiveLinearProgressTests: XCTestCase {
    func testEasingRunsFromZeroToOne() {
        let easing = ExpressiveCubicBezier.emphasizedAccelerate
        XCTAssertEqual(easing(0), 0, accuracy: 0.0001)
        XCTAssertEqual(easing(1), 1, accuracy: 0.0001)
    }

    /// Emphasized-accelerate holds back before it goes: halfway through the time it is well short of
    /// halfway through the distance.
    func testEmphasizedAccelerateStartsSlowly() {
        let easing = ExpressiveCubicBezier.emphasizedAccelerate
        XCTAssertLessThan(easing(0.5), 0.25)
        XCTAssertGreaterThan(easing(0.9), 0.6)
    }

    func testEasingIsMonotonic() {
        let easing = ExpressiveCubicBezier.emphasizedAccelerate
        var previous = -1.0
        for step in 0...100 {
            let value = easing(Double(step) / 100)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
    }

    /// A bar's tail can never overtake its head, at any point in the loop — that would draw a bar
    /// backwards.
    func testBarsAreNeverInverted() {
        for step in 0...350 {
            let time = Double(step) / 200
            for bar in ExpressiveLinearProgressMotion.bars(at: time) {
                XCTAssertLessThanOrEqual(bar.lowerBound, bar.upperBound)
                XCTAssertGreaterThanOrEqual(bar.lowerBound, 0)
                XCTAssertLessThanOrEqual(bar.upperBound, 1)
            }
        }
    }

    func testTheLoopRepeats() {
        let cycle = ExpressiveLinearProgressMotion.cycle
        let now = ExpressiveLinearProgressMotion.bars(at: 0.4)
        let later = ExpressiveLinearProgressMotion.bars(at: 0.4 + cycle)
        XCTAssertEqual(now.count, later.count)
        for (a, b) in zip(now, later) {
            XCTAssertEqual(a.lowerBound, b.lowerBound, accuracy: 0.0001)
            XCTAssertEqual(a.upperBound, b.upperBound, accuracy: 0.0001)
        }
    }

    /// The track never runs under a bar, and never touches one: there is always the gap.
    func testTheTrackKeepsItsDistanceFromEveryBar() {
        let gap = 0.02
        for step in 0...350 {
            let bars = ExpressiveLinearProgressMotion.bars(at: Double(step) / 200)
            let track = ExpressiveLinearProgressMotion.trackGaps(around: bars, gap: gap)
            for segment in track {
                for bar in bars {
                    let clearance = Swift.min(
                        abs(segment.upperBound - bar.lowerBound),
                        abs(bar.upperBound - segment.lowerBound)
                    )
                    let overlaps = segment.overlaps(bar)
                    XCTAssertFalse(overlaps, "track segment \(segment) runs under bar \(bar)")
                    if !overlaps {
                        XCTAssertGreaterThanOrEqual(clearance, gap - 0.0001)
                    }
                }
            }
        }
    }
}
