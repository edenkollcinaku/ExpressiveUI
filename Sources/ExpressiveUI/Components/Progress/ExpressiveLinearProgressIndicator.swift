import SwiftUI

/// Material 3's linear progress indicator.
///
/// ```swift
/// ExpressiveLinearProgressIndicator()                // indeterminate
/// ExpressiveLinearProgressIndicator(progress: 0.4)   // determinate
/// ```
///
/// Determinate, it is three things rather than one bar over another: the filled part, a 4pt gap,
/// and the track — plus a dot at the far end that stays put. The gap and the dot are what make it
/// read as Material rather than as a generic progress bar, and both come from
/// `LinearProgressIndicatorTokens`.
public struct ExpressiveLinearProgressIndicator: View {
    @Environment(\.expressiveColors) private var colors
    @Environment(\.layoutDirection) private var layoutDirection

    /// `LinearProgressIndicatorTokens.Height`, `TrackActiveSpace` and `StopSize`.
    let thickness: CGFloat = 4
    let gap: CGFloat = 4
    let stopSize: CGFloat = 4

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
                    draw(determinate: Swift.min(Swift.max(progress, 0), 1), in: context, size: size)
                }
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        draw(
                            bars: ExpressiveLinearProgressMotion.bars(
                                at: timeline.date.timeIntervalSinceReferenceDate
                            ),
                            in: context,
                            size: size
                        )
                    }
                }
            }
        }
        // The default width Material gives it; it stretches happily past that.
        .frame(maxWidth: 240)
        .frame(height: thickness)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(progress.map { Text("\(Int(Swift.min(Swift.max($0, 0), 1) * 100)) percent") } ?? Text(""))
    }

    private func draw(determinate progress: Double, in context: GraphicsContext, size: CGSize) {
        let stopCentre = size.width - stopSize / 2
        let filled = size.width * progress

        // The track picks up after the gap and stops short of the dot.
        let trackStart = Swift.min(filled + gap, size.width)
        if trackStart < stopCentre {
            bar(from: trackStart, to: size.width, in: context, size: size, colour: colors.secondaryContainer)
        }

        // The dot is the track's own end, and it is there at every progress — including zero, where
        // it is the only thing drawn besides the track.
        context.fill(
            Path(ellipseIn: CGRect(
                x: stopCentre - stopSize / 2,
                y: size.height / 2 - stopSize / 2,
                width: stopSize,
                height: stopSize
            )),
            with: .color(colors.primary)
        )

        if filled > 0 {
            bar(from: 0, to: filled, in: context, size: size, colour: colors.primary)
        }
    }

    private func draw(bars: [ClosedRange<Double>], in context: GraphicsContext, size: CGSize) {
        let gapFraction = Double(gap / Swift.max(size.width, 1))
        for segment in ExpressiveLinearProgressMotion.trackGaps(around: bars, gap: gapFraction) {
            bar(
                from: size.width * CGFloat(segment.lowerBound),
                to: size.width * CGFloat(segment.upperBound),
                in: context,
                size: size,
                colour: colors.secondaryContainer
            )
        }
        for bar in bars {
            self.bar(
                from: size.width * CGFloat(bar.lowerBound),
                to: size.width * CGFloat(bar.upperBound),
                in: context,
                size: size,
                colour: colors.primary
            )
        }
    }

    private func bar(
        from start: CGFloat,
        to end: CGFloat,
        in context: GraphicsContext,
        size: CGSize,
        colour: Color
    ) {
        guard end > start else { return }
        let y = size.height / 2
        var path = Path()
        // Inset by half the cap so a round end lands on the edge rather than past it.
        let cap = thickness / 2
        path.move(to: CGPoint(x: Swift.min(start + cap, end), y: y))
        path.addLine(to: CGPoint(x: Swift.max(end - cap, start), y: y))
        context.stroke(
            path,
            with: .color(colour),
            style: StrokeStyle(lineWidth: thickness, lineCap: .round)
        )
    }
}
