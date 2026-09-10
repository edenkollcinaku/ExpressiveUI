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
/// So these are honest approximations, not a port: the silhouettes and the counts are Material's,
/// the corner rounding is a smoothing exponent rather than a real arc. At the 38pt the indicator
/// draws them, while spinning, that difference is not one you can see.
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

    /// A regular star: `numVerticesPerRadius` points, dipping to `innerRadius` between them.
    ///
    /// `sharpness` stands in for `CornerRounding`: the lobes are a raised cosine, and raising it to
    /// a power pinches them into points or swells them into a cookie's scallops. A low power is a
    /// large corner radius.
    static func star(points: Int, innerRadius: Double, sharpness: Double) -> ExpressiveMaterialShape {
        ExpressiveMaterialShape { angle in
            let lobe = (cos(Double(points) * angle) + 1) / 2
            return innerRadius + (1 - innerRadius) * pow(lobe, sharpness)
        }
    }

    /// A regular polygon of `sides`, with its corners rounded by `rounding` — 0 leaves the corners
    /// sharp, 1 rounds the shape all the way to a circle.
    static func polygon(sides: Int, rounding: Double) -> ExpressiveMaterialShape {
        let half = .pi / Double(sides)
        return ExpressiveMaterialShape { angle in
            // Distance to a flat edge: the apothem over the cosine of the angle off that edge's
            // normal, which sweeps from -half to +half as the ray crosses one side.
            let offEdge = angle.truncatingRemainder(dividingBy: 2 * half) - half
            let flat = cos(half) / cos(offEdge)
            return flat + (1 - flat) * rounding
        }
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

    /// A capsule: a segment of half-length `1 - halfHeight` swept by a disc of `halfHeight`.
    ///
    /// The radius is where the ray leaves that swept region — straight from the disc while the ray
    /// is steep, and from the quadratic where it runs out past the end of the segment.
    static func capsule(halfHeight: Double) -> ExpressiveMaterialShape {
        let half = max(min(halfHeight, 1), 0.01)
        let reach = 1 - half
        return ExpressiveMaterialShape { angle in
            let dx = abs(cos(angle))
            let dy = abs(sin(angle))
            if dy > 0 {
                let alongFlank = half / dy
                if alongFlank * dx <= reach { return alongFlank }
            }
            // (r·dx - reach)² + (r·dy)² = half²
            let a = 1.0
            let b = -2 * reach * dx
            let c = reach * reach - half * half
            let discriminant = max(b * b - 4 * a * c, 0)
            return (-b + discriminant.squareRoot()) / (2 * a)
        }
    }
}

public extension ExpressiveMaterialShape {
    /// `MaterialShapes.Circle`.
    static let circle = ExpressiveMaterialShape { _ in 1 }
    /// `MaterialShapes.Oval` — a circle squashed to 0.64 and turned back 45°.
    static let oval = ellipse(aspect: 0.64, rotation: -.pi / 4)
    /// `MaterialShapes.Pill`.
    static let pill = capsule(halfHeight: 0.55)
    /// `MaterialShapes.Pentagon`, stood on its base with a vertex at the top.
    static let pentagon = polygon(sides: 5, rounding: 0.25).rotated(by: -.pi / 2)
    /// `MaterialShapes.Sunny` — an 8-pointed star at `innerRadius` 0.8, lightly rounded.
    static let sunny = star(points: 8, innerRadius: 0.8, sharpness: 2.2)
    /// `MaterialShapes.Cookie4Sided`.
    static let cookie4Sided = star(points: 4, innerRadius: 0.76, sharpness: 0.85)
    /// `MaterialShapes.Cookie9Sided` — 9 points at 0.8, rounded so far they scallop.
    static let cookie9Sided = star(points: 9, innerRadius: 0.8, sharpness: 0.7)
    /// `MaterialShapes.SoftBurst` — ten soft lobes.
    static let softBurst = star(points: 10, innerRadius: 0.78, sharpness: 1.2)

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
