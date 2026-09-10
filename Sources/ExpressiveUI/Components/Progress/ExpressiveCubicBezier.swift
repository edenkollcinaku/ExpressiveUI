import Foundation

/// A cubic Bézier easing curve, the way Compose's `CubicBezierEasing` defines one: two control
/// points between (0,0) and (1,1), and a lookup of y for a given x.
///
/// Needed because the linear indicator's indeterminate motion is keyframes on
/// `EasingEmphasizedAccelerate`, and the shape of that curve is most of what makes the two bars
/// read as Material rather than as two things sliding.
struct ExpressiveCubicBezier {
    let x1, y1, x2, y2: Double

    /// `MotionTokens.EasingEmphasizedAccelerateCubicBezier`.
    static let emphasizedAccelerate = ExpressiveCubicBezier(x1: 0.3, y1: 0, x2: 0.8, y2: 0.15)
    /// `MotionTokens.EasingStandardCubicBezier`.
    static let standard = ExpressiveCubicBezier(x1: 0.2, y1: 0, x2: 0, y2: 1)

    func callAsFunction(_ fraction: Double) -> Double {
        let t = Swift.min(Swift.max(fraction, 0), 1)
        guard t > 0, t < 1 else { return t }
        return valueY(at: parameter(forX: t))
    }

    /// Newton's method, falling back to bisection: the curve is given as x(s) and y(s), so finding
    /// y for an x means solving for s first.
    private func parameter(forX x: Double) -> Double {
        var s = x
        for _ in 0..<8 {
            let error = valueX(at: s) - x
            if abs(error) < 1e-6 { return s }
            let slope = derivativeX(at: s)
            if abs(slope) < 1e-6 { break }
            s -= error / slope
        }

        var low = 0.0
        var high = 1.0
        var mid = x
        for _ in 0..<24 {
            mid = (low + high) / 2
            if valueX(at: mid) < x { low = mid } else { high = mid }
        }
        return mid
    }

    private func valueX(at s: Double) -> Double { curve(s, x1, x2) }
    private func valueY(at s: Double) -> Double { curve(s, y1, y2) }

    private func curve(_ s: Double, _ a: Double, _ b: Double) -> Double {
        let inverse = 1 - s
        return 3 * inverse * inverse * s * a + 3 * inverse * s * s * b + s * s * s
    }

    private func derivativeX(at s: Double) -> Double {
        let inverse = 1 - s
        return 3 * inverse * inverse * x1
            + 6 * inverse * s * (x2 - x1)
            + 3 * s * s * (1 - x2)
    }
}

/// The shared bones of both linear indicators: what the bars are doing at a given moment.
enum ExpressiveLinearProgressMotion {
    /// `LinearAnimationDuration`, and the four head and tail keyframes that run inside it.
    static let cycle: Double = 1.750

    static let firstHead = (delay: 0.0, duration: 1.0)
    static let firstTail = (delay: 0.25, duration: 1.0)
    static let secondHead = (delay: 0.65, duration: 0.85)
    static let secondTail = (delay: 0.9, duration: 0.85)

    /// One keyframe: flat at 0 until its delay, eased to 1 over its duration, flat at 1 after.
    static func position(at time: Double, delay: Double, duration: Double) -> Double {
        let elapsed = time - delay
        guard elapsed > 0 else { return 0 }
        guard elapsed < duration else { return 1 }
        return ExpressiveCubicBezier.emphasizedAccelerate(elapsed / duration)
    }

    /// The two bars, as fractions of the track, at `time` seconds into the loop.
    static func bars(at time: Double) -> [ClosedRange<Double>] {
        let now = time.truncatingRemainder(dividingBy: cycle)
        let spans = [
            (position(at: now, delay: firstTail.delay, duration: firstTail.duration),
             position(at: now, delay: firstHead.delay, duration: firstHead.duration)),
            (position(at: now, delay: secondTail.delay, duration: secondTail.duration),
             position(at: now, delay: secondHead.delay, duration: secondHead.duration))
        ]
        return spans.compactMap { tail, head in
            head - tail > 0.0001 ? tail...head : nil
        }
    }

    /// What is left of the track once the bars — and the gap either side of each — are taken out of
    /// it. Material never lets the track run under a bar or touch one.
    static func trackGaps(around bars: [ClosedRange<Double>], gap: Double) -> [ClosedRange<Double>] {
        var free: [ClosedRange<Double>] = [0...1]
        for bar in bars {
            let blocked = (bar.lowerBound - gap)...(bar.upperBound + gap)
            free = free.flatMap { segment -> [ClosedRange<Double>] in
                guard segment.overlaps(blocked) else { return [segment] }
                var pieces: [ClosedRange<Double>] = []
                if blocked.lowerBound > segment.lowerBound {
                    pieces.append(segment.lowerBound...Swift.min(blocked.lowerBound, segment.upperBound))
                }
                if blocked.upperBound < segment.upperBound {
                    pieces.append(Swift.max(blocked.upperBound, segment.lowerBound)...segment.upperBound)
                }
                return pieces.filter { $0.upperBound - $0.lowerBound > 0.001 }
            }
        }
        return free
    }
}
