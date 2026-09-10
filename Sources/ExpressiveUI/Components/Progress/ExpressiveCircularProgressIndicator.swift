import SwiftUI

/// Material 3's circular progress indicator.
///
/// ```swift
/// ExpressiveCircularProgressIndicator()                // indeterminate
/// ExpressiveCircularProgressIndicator(progress: 0.4)   // determinate
/// ```
///
/// Determinate, it is an arc, a 4pt gap at each end of it, and a track — the ring equivalent of what
/// [the linear indicator](Docs/LinearProgressIndicator.md) does.
///
/// Indeterminate, **there is no track at all**: `circularIndeterminateTrackColor` is transparent,
/// so a lone arc travels an empty ring. That is the difference people notice between the two states
/// without being able to name it.
public struct ExpressiveCircularProgressIndicator: View {
    @Environment(\.expressiveColors) private var colors

    /// `CircularProgressIndicatorTokens.Size`, `TrackThickness` and `TrackActiveSpace`.
    private let diameter: CGFloat = 40
    private let thickness: CGFloat = 4
    private let gap: CGFloat = 4

    private let progress: Double?

    public init() {
        self.progress = nil
    }

    public init(progress: Double) {
        self.progress = progress
    }

    public var body: some View {
        Group {
            if let progress {
                Canvas { context, size in
                    drawDeterminate(Swift.min(Swift.max(progress, 0), 1), in: context, size: size)
                }
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        drawIndeterminate(
                            rotation: ExpressiveCircularProgressMotion.rotation(at: time),
                            sweep: ExpressiveCircularProgressMotion.sweep(at: time),
                            in: context,
                            size: size
                        )
                    }
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(progress.map { Text("\(Int(Swift.min(Swift.max($0, 0), 1) * 100)) percent") } ?? Text(""))
    }

    private func drawDeterminate(_ progress: Double, in context: GraphicsContext, size: CGSize) {
        let geometry = ExpressiveArcGeometry(size: size, thickness: thickness, gap: gap)
        let filled = 360 * progress

        // The track takes what the arc has not, less a gap at each end. Below that it is not drawn:
        // there is no room for a track between two gaps.
        let remaining = 360 - filled - 2 * geometry.gapDegrees
        if remaining > 0 {
            context.stroke(
                geometry.arc(from: -90 + filled + geometry.gapDegrees, sweep: remaining),
                with: .color(colors.secondaryContainer),
                style: StrokeStyle(lineWidth: thickness, lineCap: .round)
            )
        }

        if filled > 0 {
            context.stroke(
                geometry.arc(from: -90, sweep: filled),
                with: .color(colors.primary),
                style: StrokeStyle(lineWidth: thickness, lineCap: .round)
            )
        }
    }

    private func drawIndeterminate(
        rotation: Double,
        sweep: Double,
        in context: GraphicsContext,
        size: CGSize
    ) {
        let geometry = ExpressiveArcGeometry(size: size, thickness: thickness, gap: gap)
        context.stroke(
            geometry.arc(from: -90 + rotation, sweep: 360 * sweep),
            with: .color(colors.primary),
            style: StrokeStyle(lineWidth: thickness, lineCap: .round)
        )
    }
}

/// The ring both circular indicators are drawn on, and the one conversion they both need: a gap
/// given in points has to become an angle, and how big an angle depends on the radius.
struct ExpressiveArcGeometry {
    let centre: CGPoint
    let radius: CGFloat
    let gapDegrees: Double

    init(size: CGSize, thickness: CGFloat, gap: CGFloat) {
        centre = CGPoint(x: size.width / 2, y: size.height / 2)
        radius = (Swift.min(size.width, size.height) - thickness) / 2
        let circumference = 2 * .pi * Double(Swift.max(radius, 0.001))
        gapDegrees = Double(gap) / circumference * 360
    }

    func arc(from start: Double, sweep: Double) -> Path {
        var path = Path()
        path.addArc(
            center: centre,
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(start + sweep),
            clockwise: false
        )
        return path
    }
}
