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

final class ExpressiveCircularProgressTests: XCTestCase {
    /// Three full turns per six-second cycle, plus four quarter-turns of its own: the arc's start
    /// ends the loop exactly one turn further round than the steady rotation alone would take it.
    func testTheArcGainsAFullExtraTurnEachCycle() {
        let cycle = ExpressiveCircularProgressMotion.cycle
        let start = ExpressiveCircularProgressMotion.rotation(at: 0)
        let end = ExpressiveCircularProgressMotion.rotation(at: cycle - 0.0001)
        XCTAssertEqual(start, 0, accuracy: 0.0001)
        XCTAssertEqual(end, 1080 + 360, accuracy: 1)
    }

    /// Within a cycle the arc only ever moves forwards — it lunges and waits, it never backs up.
    /// At the loop's end it wraps to zero, which is the same place: 1440° is four whole turns.
    func testRotationOnlyEverIncreasesWithinACycle() {
        var previous = -1.0
        for step in 0..<600 {
            let value = ExpressiveCircularProgressMotion.rotation(at: Double(step) / 100)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
        XCTAssertEqual(
            ExpressiveCircularProgressMotion.rotation(at: ExpressiveCircularProgressMotion.cycle),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual((1080 + 360).truncatingRemainder(dividingBy: 360), 0, accuracy: 0.0001)
    }

    /// The quarter-turns land where Material says: 90° by 300ms, and still 90° at 1500ms.
    func testTheFirstQuarterTurnLandsAndThenHolds() {
        XCTAssertEqual(ExpressiveCircularProgressMotion.rotation(at: 0.3) - 0.3 / 6 * 1080, 90, accuracy: 1)
        XCTAssertEqual(ExpressiveCircularProgressMotion.rotation(at: 1.4) - 1.4 / 6 * 1080, 90, accuracy: 1)
    }

    /// The arc grows to 87% of the ring and comes back to 10%, and never leaves that range.
    func testSweepStaysBetweenItsTwoLimits() {
        for step in 0...600 {
            let sweep = ExpressiveCircularProgressMotion.sweep(at: Double(step) / 100)
            XCTAssertGreaterThanOrEqual(sweep, ExpressiveCircularProgressMotion.minimumSweep - 0.0001)
            XCTAssertLessThanOrEqual(sweep, ExpressiveCircularProgressMotion.maximumSweep + 0.0001)
        }
        XCTAssertEqual(
            ExpressiveCircularProgressMotion.sweep(at: 3),
            ExpressiveCircularProgressMotion.maximumSweep,
            accuracy: 0.0001
        )
    }

    /// A 4pt gap is a wider angle on a small ring than a big one — the conversion has to know the
    /// radius, which is the one thing a linear indicator never has to think about.
    func testTheGapAngleShrinksAsTheRingGrows() {
        let small = ExpressiveArcGeometry(size: CGSize(width: 40, height: 40), thickness: 4, gap: 4)
        let large = ExpressiveArcGeometry(size: CGSize(width: 80, height: 80), thickness: 4, gap: 4)
        XCTAssertGreaterThan(small.gapDegrees, large.gapDegrees)
        XCTAssertEqual(small.gapDegrees, 4 / (2 * .pi * 18) * 360, accuracy: 0.001)
    }
}
