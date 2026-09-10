import CoreGraphics
import Foundation

/// One of Material's shapes, as a radius for every angle.
///
/// Android builds these with `androidx.graphics.shapes`: a `RoundedPolygon` is a list of vertices,
/// each with its own corner rounding, and a `Morph` matches the cubic curves of two of them so one
/// can be tweened into the other. None of that exists on this side, and porting it is a library in
/// its own right.
///
/// What every shape in the loading indicator's sequence has in common is that it is *star-shaped
/// about its centre*: a ray from the middle crosses the outline exactly once. That makes each one
/// expressible as `radius(atAngle:)`, normalised so the widest point is 1 — and it makes morphing
/// between any two of them a straight interpolation of those radii at matching angles, which is
/// what `Morph` is trying to achieve by matching curves.
///
/// The shapes themselves are built from Material's own published figures — the points, the corner
/// radii, the repeat counts — by ``ExpressiveRoundedPolygon``, and only then flattened into this
/// form. So the outline is Google's; the representation is ours.
public struct ExpressiveMaterialShape: Sendable {
    let radius: @Sendable (_ angle: Double) -> Double

    init(radius: @escaping @Sendable (_ angle: Double) -> Double) {
        self.radius = radius
    }

    /// How far the outline is from the centre at `angle`, in radians clockwise from the trailing
    /// edge, normalised so the shape's widest point is 1.
    public func radius(atAngle angle: Double) -> Double {
        radius(angle)
    }

    /// Built from an outline: the polyline is turned into a radius for every angle, and scaled so
    /// its furthest point is 1.
    ///
    /// This is where the port stops being exact and starts being a representation. Every shape in
    /// Material's sequence is star-shaped about its centre — a ray from the middle crosses the
    /// outline once — so nothing is lost in the conversion for these. A shape with a dent deep
    /// enough to hide part of itself from the centre could not be stored this way, and neither
    /// could it be morphed by interpolating radii.
    static func outline(_ points: [CGPoint], centre: CGPoint) -> ExpressiveMaterialShape {
        // Straight edges have to be walked, not just sampled at their ends: interpolating radius
        // between two vertices bows the edge outward, which is what turns a pentagon into a blob.
        var dense: [CGPoint] = []
        for (index, point) in points.enumerated() {
            let next = points[(index + 1) % points.count]
            let length = Double(((next.x - point.x) * (next.x - point.x) + (next.y - point.y) * (next.y - point.y)).squareRoot())
            let steps = Swift.max(Int((length / 0.004).rounded(.up)), 1)
            for step in 0..<steps {
                let t = CGFloat(Double(step) / Double(steps))
                dense.append(CGPoint(
                    x: point.x + (next.x - point.x) * t,
                    y: point.y + (next.y - point.y) * t
                ))
            }
        }

        var polar = dense.map { point -> (angle: Double, radius: Double) in
            let dx = Double(point.x - centre.x)
            let dy = Double(point.y - centre.y)
            var angle = atan2(dy, dx)
            if angle < 0 { angle += 2 * .pi }
            return (angle, (dx * dx + dy * dy).squareRoot())
        }
        polar.sort { $0.angle < $1.angle }

        let longest = polar.map(\.radius).max() ?? 1
        guard longest > 0, polar.count > 1 else { return .circle }
        let normalised = polar.map { (angle: $0.angle, radius: $0.radius / longest) }

        return ExpressiveMaterialShape { angle in
            var query = angle.truncatingRemainder(dividingBy: 2 * .pi)
            if query < 0 { query += 2 * .pi }

            // The outline is a loop, so a query before the first sample falls between the last and
            // the first.
            var index = normalised.firstIndex { $0.angle >= query } ?? 0
            if index == 0 {
                let last = normalised[normalised.count - 1]
                let first = normalised[0]
                let span = first.angle + 2 * .pi - last.angle
                let along = span > 0 ? (query + (query < first.angle ? 2 * .pi : 0) - last.angle) / span : 0
                return last.radius + (first.radius - last.radius) * Swift.min(Swift.max(along, 0), 1)
            }
            index = Swift.min(index, normalised.count - 1)
            let before = normalised[index - 1]
            let after = normalised[index]
            let span = after.angle - before.angle
            let along = span > 0 ? (query - before.angle) / span : 0
            return before.radius + (after.radius - before.radius) * along
        }
    }

    /// `MaterialShapes.customPolygon` — points repeated around the centre, then rounded.
    static func custom(
        _ vertices: [RoundedVertex],
        reps: Int,
        mirroring: Bool = false,
        rotation: Double = 0
    ) -> ExpressiveMaterialShape {
        let centre = CGPoint(x: 0.5, y: 0.5)
        let repeated = ExpressiveRoundedPolygon.repeated(vertices, reps: reps, centre: centre, mirroring: mirroring)
        let turned = rotation == 0
            ? repeated
            : repeated.map { RoundedVertex(point: ExpressiveRoundedPolygon.rotate($0.point, degrees: rotation, around: centre), rounding: $0.rounding) }
        return outline(ExpressiveRoundedPolygon.outline(turned), centre: centre)
    }

    /// `RoundedPolygon.star`.
    static func star(
        points: Int,
        innerRadius: Double,
        rounding: Double,
        rotation: Double = 0
    ) -> ExpressiveMaterialShape {
        let centre = CGPoint.zero
        let vertices = ExpressiveRoundedPolygon.star(points: points, innerRadius: innerRadius, rounding: rounding)
        let turned = rotation == 0
            ? vertices
            : vertices.map { RoundedVertex(point: ExpressiveRoundedPolygon.rotate($0.point, degrees: rotation, around: centre), rounding: $0.rounding) }
        return outline(ExpressiveRoundedPolygon.outline(turned), centre: centre)
    }

    /// The same shape, turned by `rotation` radians.
    public func rotated(by rotation: Double) -> ExpressiveMaterialShape {
        let radius = self.radius
        return ExpressiveMaterialShape { angle in radius(angle - rotation) }
    }

    /// An ellipse with the given aspect, turned by `rotation` radians.
    static func ellipse(aspect: Double, rotation: Double = 0) -> ExpressiveMaterialShape {
        ExpressiveMaterialShape { angle in
            let turned = angle - rotation
            let x = cos(turned)
            let y = sin(turned) / aspect
            return 1 / (x * x + y * y).squareRoot()
        }
    }
}

public extension ExpressiveMaterialShape {
    /// `MaterialShapes.Circle`.
    static let circle = ExpressiveMaterialShape { _ in 1 }

    /// `MaterialShapes.Oval` — a circle squashed to 0.64 and turned back 45°.
    static let oval = ellipse(aspect: 0.64, rotation: -.pi / 4)

    /// `MaterialShapes.Pill`.
    static let pill = custom(
        [
            RoundedVertex(0.961, 0.039, 0.426),
            RoundedVertex(1.001, 0.428),
            RoundedVertex(1.000, 0.609, 1.000)
        ],
        reps: 2,
        mirroring: true
    )

    /// `MaterialShapes.Pentagon`.
    static let pentagon = custom(
        [
            RoundedVertex(0.500, -0.009, 0.172),
            RoundedVertex(1.030, 0.365, 0.164),
            RoundedVertex(0.828, 0.970, 0.169)
        ],
        reps: 1,
        mirroring: true
    )

    /// `MaterialShapes.Sunny` — eight points at an inner radius of 0.8, rounded by 0.15.
    static let sunny = star(points: 8, innerRadius: 0.8, rounding: 0.15)

    /// `MaterialShapes.Cookie4Sided`.
    static let cookie4Sided = custom(
        [
            RoundedVertex(1.237, 1.236, 0.258),
            RoundedVertex(0.500, 0.918, 0.233)
        ],
        reps: 4
    )

    /// `MaterialShapes.Cookie9Sided` — nine points at 0.8, rounded by 0.5, stood on a vertex.
    static let cookie9Sided = star(points: 9, innerRadius: 0.8, rounding: 0.5, rotation: -90)

    /// `MaterialShapes.SoftBurst` — ten soft lobes.
    static let softBurst = custom(
        [
            RoundedVertex(0.193, 0.277, 0.053),
            RoundedVertex(0.176, 0.055, 0.053)
        ],
        reps: 10
    )

    /// `LoadingIndicatorDefaults.IndeterminateIndicatorPolygons`, in Material's own order.
    static let indeterminateSequence: [ExpressiveMaterialShape] = [
        .softBurst, .cookie9Sided, .pentagon, .pill, .sunny, .cookie4Sided, .oval
    ]

    /// `LoadingIndicatorDefaults.DeterminateIndicatorPolygons`: a circle opening into a soft burst.
    static let determinateSequence: [ExpressiveMaterialShape] = [.circle, .softBurst]
}

public extension Array where Element == ExpressiveMaterialShape {
    /// The path of `self[index]` morphed `progress` of the way into the next shape, drawn to fill
    /// `rect`. Sampling both shapes at the same angles is what makes the tween well behaved: no
    /// vertex matching to get wrong, and a shape never turns inside out on its way to the next one.
    func morphedPath(index: Int, progress: Double, in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        guard !isEmpty else { return path }

        let from = self[index % count]
        let to = self[(index + 1) % count]
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let scale = Swift.min(rect.width, rect.height) / 2
        let samples = 240

        var radii = (0..<samples).map { step -> Double in
            let angle = 2 * .pi * Double(step) / Double(samples)
            let start = from.radius(angle)
            return start + (to.radius(angle) - start) * progress
        }
        radii = Self.smoothedMidMorph(radii, progress: progress)

        for (step, radius) in radii.enumerated() {
            let angle = 2 * .pi * Double(step) / Double(samples)
            let point = CGPoint(
                x: centre.x + CGFloat(cos(angle) * radius) * scale,
                y: centre.y + CGFloat(sin(angle) * radius) * scale
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    /// Rounds off the ripple that appears halfway through a morph between two shapes with different
    /// numbers of lobes.
    ///
    /// Nine lobes fading into ten do not line up, and their sum beats: the in-between shape grows
    /// small extra bumps that belong to neither end. Android does not have this problem because
    /// `Morph` matches the two outlines feature by feature before it tweens them. Blurring the
    /// radii instead is the cheap equivalent — and it is applied by how far into the morph we are,
    /// peaking in the middle and vanishing at both ends, so the shapes themselves are drawn exactly
    /// as defined and only the passage between them is softened.
    private static func smoothedMidMorph(_ radii: [Double], progress: Double) -> [Double] {
        let midway = sin(.pi * Swift.min(Swift.max(progress, 0), 1))
        guard midway > 0.001, radii.count > 8 else { return radii }

        let reach = Int((Double(radii.count) / 26 * midway).rounded())
        guard reach > 0 else { return radii }

        return radii.indices.map { index in
            var total = 0.0
            var weight = 0.0
            for offset in -reach...reach {
                // A triangular kernel, wrapped: the outline is a loop with no first or last point.
                let w = 1 - Double(abs(offset)) / Double(reach + 1)
                let i = ((index + offset) % radii.count + radii.count) % radii.count
                total += radii[i] * w
                weight += w
            }
            return total / weight
        }
    }
}
