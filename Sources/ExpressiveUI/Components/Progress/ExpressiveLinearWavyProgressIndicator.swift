import SwiftUI

/// Material 3 Expressive's wavy linear progress indicator: the filled part is a travelling wave,
/// and the track it has not reached yet is a straight line.
///
/// ```swift
/// ExpressiveLinearWavyProgressIndicator()                // indeterminate
/// ExpressiveLinearWavyProgressIndicator(progress: 0.4)   // determinate
/// ```
///
/// The wave moves at one wavelength per second — `waveSpeed` defaults to `wavelength` in Compose,
/// which is what that sentence means — so it reads as motion along the bar rather than as a shape
/// wobbling in place.
///
/// The amplitude is not constant. Material flattens the wave below 10% and above 95% of the way,
/// so the indicator settles as it arrives instead of stopping mid-crest.
public struct ExpressiveLinearWavyProgressIndicator: View {
    @Environment(\.expressiveColors) private var colors

    /// `LinearProgressIndicatorTokens`: the container is 10 tall to hold a 3pt wave drawn with a
    /// 4pt stroke, and the track sits in the middle of it.
    private let containerHeight: CGFloat = 10
    private let thickness: CGFloat = 4
    private let amplitude: CGFloat = 3
    private let gap: CGFloat = 4
    private let stopSize: CGFloat = 4

    /// `LinearDeterminateWavelength` and `LinearIndeterminateWavelength`.
    private let determinateWavelength: CGFloat = 40
    private let indeterminateWavelength: CGFloat = 20

    private let progress: Double?

    @State private var waveHeight: CGFloat

    public init() {
        self.progress = nil
        // Starting at the amplitude it should already have, rather than growing into it on first
        // appearance: an indicator that comes on screen at 40% was already waving before you
        // looked at it.
        self._waveHeight = State(initialValue: 3)
    }

    public init(progress: Double) {
        self.progress = progress
        self._waveHeight = State(initialValue: (progress <= 0.1 || progress >= 0.95) ? 0 : 3)
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                if let progress {
                    draw(
                        determinate: Swift.min(Swift.max(progress, 0), 1),
                        phase: time,
                        in: context,
                        size: size
                    )
                } else {
                    draw(
                        bars: ExpressiveLinearProgressMotion.bars(at: time),
                        phase: time,
                        in: context,
                        size: size
                    )
                }
            }
        }
        .frame(maxWidth: 240)
        .frame(height: containerHeight)
        .onChange(of: progress) { _ in updateWave() }
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(progress.map { Text("\(Int(Swift.min(Swift.max($0, 0), 1) * 100)) percent") } ?? Text(""))
    }

    /// `WavyProgressIndicatorDefaults.indicatorAmplitude`: full wave between 10% and 95%, flat
    /// outside that. Compose eases the change over 500ms rather than switching it, so the wave
    /// grows and settles rather than appearing.
    private func updateWave() {
        let wanted: CGFloat
        if let progress {
            wanted = (progress <= 0.1 || progress >= 0.95) ? 0 : amplitude
        } else {
            wanted = amplitude
        }
        withAnimation(.easeInOut(duration: 0.5)) { waveHeight = wanted }
    }

    private func draw(determinate progress: Double, phase: Double, in context: GraphicsContext, size: CGSize) {
        let stopCentre = size.width - stopSize / 2
        let filled = size.width * CGFloat(progress)

        let trackStart = Swift.min(filled + gap, size.width)
        if trackStart < stopCentre {
            flat(from: trackStart, to: size.width, in: context, size: size, colour: colors.secondaryContainer)
        }

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
            wave(
                from: 0,
                to: filled,
                wavelength: determinateWavelength,
                phase: phase,
                in: context,
                size: size
            )
        }
    }

    private func draw(bars: [ClosedRange<Double>], phase: Double, in context: GraphicsContext, size: CGSize) {
        let gapFraction = Double(gap / Swift.max(size.width, 1))
        for segment in ExpressiveLinearProgressMotion.trackGaps(around: bars, gap: gapFraction) {
            flat(
                from: size.width * CGFloat(segment.lowerBound),
                to: size.width * CGFloat(segment.upperBound),
                in: context,
                size: size,
                colour: colors.secondaryContainer
            )
        }
        for bar in bars {
            wave(
                from: size.width * CGFloat(bar.lowerBound),
                to: size.width * CGFloat(bar.upperBound),
                wavelength: indeterminateWavelength,
                phase: phase,
                in: context,
                size: size
            )
        }
    }

    /// The wave itself: a sine along the bar, sampled finely enough that the stroke reads as a
    /// curve. Its phase advances by one wavelength every second, and it is *not* reset per bar —
    /// the wave belongs to the track, so a bar sliding along it moves through the wave rather than
    /// carrying its own.
    private func wave(
        from start: CGFloat,
        to end: CGFloat,
        wavelength: CGFloat,
        phase: Double,
        in context: GraphicsContext,
        size: CGSize
    ) {
        guard end > start else { return }
        let cap = thickness / 2
        let first = Swift.min(start + cap, end)
        let last = Swift.max(end - cap, start)
        guard last > first else { return }

        let middle = size.height / 2
        let travelled = CGFloat(phase.truncatingRemainder(dividingBy: 3600)) * wavelength
        var path = Path()
        var x = first
        while x <= last {
            let y = middle + waveHeight * CGFloat(sin(Double((x + travelled) / wavelength) * 2 * .pi))
            if x == first {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += 1
        }
        let y = middle + waveHeight * CGFloat(sin(Double((last + travelled) / wavelength) * 2 * .pi))
        path.addLine(to: CGPoint(x: last, y: y))

        context.stroke(
            path,
            with: .color(colors.primary),
            style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round)
        )
    }

    private func flat(
        from start: CGFloat,
        to end: CGFloat,
        in context: GraphicsContext,
        size: CGSize,
        colour: Color
    ) {
        guard end > start else { return }
        let cap = thickness / 2
        var path = Path()
        path.move(to: CGPoint(x: Swift.min(start + cap, end), y: size.height / 2))
        path.addLine(to: CGPoint(x: Swift.max(end - cap, start), y: size.height / 2))
        context.stroke(
            path,
            with: .color(colour),
            style: StrokeStyle(lineWidth: thickness, lineCap: .round)
        )
    }
}
