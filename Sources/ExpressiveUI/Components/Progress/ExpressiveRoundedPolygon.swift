import CoreGraphics
import Foundation

/// A vertex and the radius its corner is rounded by — `androidx.graphics.shapes`' `PointNRound`.
struct RoundedVertex {
    var point: CGPoint
    var rounding: Double

    init(_ x: Double, _ y: Double, _ rounding: Double = 0) {
        self.point = CGPoint(x: x, y: y)
        self.rounding = rounding
    }

    init(point: CGPoint, rounding: Double) {
        self.point = point
        self.rounding = rounding
    }
}

/// Enough of `androidx.graphics.shapes.RoundedPolygon` to build Material's own shapes from the
/// numbers Google publishes for them.
///
/// `MaterialShapes` describes every shape as a handful of points with per-corner rounding, repeated
/// around the centre — `customPolygon(points, reps, mirroring)` — or as a star of so many points at
/// so deep an inner radius. Those figures are exact, so the shapes here are built from them rather
/// than from anybody's eye: this file turns that description into an outline, and
/// ``ExpressiveMaterialShape`` turns the outline into the radius-per-angle form the morph needs.
///
/// What is *not* ported is `CornerRounding`'s smoothing parameter, which flattens an arc into the
/// edges either side of it. Every shape the loading indicator uses leaves it at zero.
enum ExpressiveRoundedPolygon {
    /// `MaterialShapes.doRepeat` — the points repeated `reps` times around `centre`.
    ///
    /// The mirrored form alternates direction each time round, so a run of points reads forwards,
    /// then backwards, then forwards. That is what lets three points describe a five-sided pentagon:
    /// two of its corners are the first two read back the other way.
    static func repeated(
        _ points: [RoundedVertex],
        reps: Int,
        centre: CGPoint = CGPoint(x: 0.5, y: 0.5),
        mirroring: Bool = false
    ) -> [RoundedVertex] {
        guard !points.isEmpty else { return [] }

        if !mirroring {
            return (0..<(points.count * reps)).map { index in
                let source = points[index % points.count]
                let turn = Double(index / points.count) * 360 / Double(reps)
                return RoundedVertex(
                    point: rotate(source.point, degrees: turn, around: centre),
                    rounding: source.rounding
                )
            }
        }

        let angles = points.map { angleDegrees(of: $0.point, around: centre) }
        let distances = points.map { distance(from: $0.point, to: centre) }
        let actualReps = reps * 2
        let sectionAngle = 360.0 / Double(actualReps)

        var result: [RoundedVertex] = []
        for rep in 0..<actualReps {
            for index in points.indices {
                let i = rep % 2 == 0 ? index : points.count - 1 - index
                guard i > 0 || rep % 2 == 0 else { continue }
                let angle = sectionAngle * Double(rep)
                    + (rep % 2 == 0 ? angles[i] : sectionAngle - angles[i] + 2 * angles[0])
                let radians = angle * .pi / 180
                let point = CGPoint(
                    x: centre.x + CGFloat(cos(radians) * distances[i]),
                    y: centre.y + CGFloat(sin(radians) * distances[i])
                )
                result.append(RoundedVertex(point: point, rounding: points[i].rounding))
            }
        }
        return result
    }

    /// `RoundedPolygon.star`: `points` spikes at radius 1, dipping to `innerRadius` between them,
    /// every corner rounded by `rounding`.
    static func star(
        points: Int,
        innerRadius: Double,
        rounding: Double,
        innerRounding: Double? = nil
    ) -> [RoundedVertex] {
        (0..<(points * 2)).map { index in
            let angle = .pi * Double(index) / Double(points)
            let outer = index % 2 == 0
            let radius = outer ? 1 : innerRadius
            return RoundedVertex(
                cos(angle) * radius,
                sin(angle) * radius,
                outer ? rounding : (innerRounding ?? rounding)
            )
        }
    }

    /// The outline as a closed polyline, with each corner replaced by the arc that is tangent to
    /// both of its edges.
    ///
    /// A corner's radius is cut back to fit when its edges are too short to hold it — which is what
    /// keeps a deep star like the nine-sided cookie from folding through itself at a rounding of
    /// 0.5.
    static func outline(_ vertices: [RoundedVertex], segmentsPerCorner: Int = 12) -> [CGPoint] {
        let count = vertices.count
        guard count > 2 else { return vertices.map(\.point) }

        // How far back along its edges each corner would like to be cut, and the half-angle its arc
        // is drawn from.
        var wanted = [Double](repeating: 0, count: count)
        var halfAngles = [Double](repeating: 0, count: count)
        for index in 0..<count {
            let previous = vertices[(index + count - 1) % count].point
            let current = vertices[index]
            let next = vertices[(index + 1) % count].point
            let toPrevious = normalize(previous - current.point)
            let toNext = normalize(next - current.point)
            let between = acos(Swift.min(Swift.max(dot(toPrevious, toNext), -1), 1))
            guard current.rounding > 0, between > 0.001, between < .pi - 0.001 else { continue }
            halfAngles[index] = between / 2
            wanted[index] = current.rounding / tan(between / 2)
        }

        // Each edge is shared by the two corners at its ends, so they share its length: a corner
        // takes what it asked for unless its neighbour is asking for the same stretch, and then
        // both give way in proportion. Capping every corner at half an edge instead — which is the
        // obvious thing to do — starves a big corner sitting next to a small one, and that is the
        // difference between a fat four-sided cookie and a thin star.
        var allowed = wanted
        for index in 0..<count {
            let next = (index + 1) % count
            let length = distance(from: vertices[index].point, to: vertices[next].point)
            let demand = wanted[index] + wanted[next]
            guard demand > length, demand > 0 else { continue }
            let share = length / demand
            allowed[index] = Swift.min(allowed[index], wanted[index] * share)
            allowed[next] = Swift.min(allowed[next], wanted[next] * share)
        }

        var result: [CGPoint] = []
        for index in 0..<count {
            let previous = vertices[(index + count - 1) % count].point
            let current = vertices[index]
            let next = vertices[(index + 1) % count].point

            let cut = allowed[index]
            let half = halfAngles[index]
            guard cut > 0, half > 0 else {
                result.append(current.point)
                continue
            }

            let toPrevious = normalize(previous - current.point)
            let toNext = normalize(next - current.point)
            let radius = cut * tan(half)
            let start = current.point + toPrevious * cut
            let end = current.point + toNext * cut
            let bisector = normalize(toPrevious + toNext)
            let centre = current.point + bisector * (radius / sin(half))

            let startAngle = atan2(start.y - centre.y, start.x - centre.x)
            let endAngle = atan2(end.y - centre.y, end.x - centre.x)
            var sweep = endAngle - startAngle
            // The short way round: the arc replaces the corner, it does not go around the shape.
            while sweep > .pi { sweep -= 2 * .pi }
            while sweep < -.pi { sweep += 2 * .pi }

            for step in 0...segmentsPerCorner {
                let angle = startAngle + sweep * Double(step) / Double(segmentsPerCorner)
                result.append(CGPoint(
                    x: centre.x + CGFloat(cos(angle)) * CGFloat(radius),
                    y: centre.y + CGFloat(sin(angle)) * CGFloat(radius)
                ))
            }
        }
        return result
    }

    // MARK: - Small vector helpers

    static func rotate(_ point: CGPoint, degrees: Double, around centre: CGPoint) -> CGPoint {
        let radians = degrees * .pi / 180
        let offset = point - centre
        return CGPoint(
            x: centre.x + offset.x * CGFloat(cos(radians)) - offset.y * CGFloat(sin(radians)),
            y: centre.y + offset.x * CGFloat(sin(radians)) + offset.y * CGFloat(cos(radians))
        )
    }

    private static func angleDegrees(of point: CGPoint, around centre: CGPoint) -> Double {
        let offset = point - centre
        return atan2(Double(offset.y), Double(offset.x)) * 180 / .pi
    }

    private static func distance(from a: CGPoint, to b: CGPoint) -> Double {
        Double(((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot())
    }

    private static func normalize(_ point: CGPoint) -> CGPoint {
        let length = (point.x * point.x + point.y * point.y).squareRoot()
        guard length > 0 else { return .zero }
        return CGPoint(x: point.x / length, y: point.y / length)
    }

    private static func dot(_ a: CGPoint, _ b: CGPoint) -> Double {
        Double(a.x * b.x + a.y * b.y)
    }
}

private func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

private func * (lhs: CGPoint, rhs: Double) -> CGPoint {
    CGPoint(x: lhs.x * CGFloat(rhs), y: lhs.y * CGFloat(rhs))
}
