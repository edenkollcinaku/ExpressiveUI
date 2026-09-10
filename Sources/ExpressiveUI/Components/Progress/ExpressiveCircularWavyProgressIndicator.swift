import SwiftUI

/// Material 3 Expressive's wavy circular progress indicator: the arc that has been covered ripples,
/// and the track it has not reached stays a smooth ring.
///
/// ```swift
/// ExpressiveCircularWavyProgressIndicator()                // indeterminate
/// ExpressiveCircularWavyProgressIndicator(progress: 0.4)   // determinate
/// ```
///
/// The wave is smaller and tighter than the linear one — 1.6pt at a 15pt wavelength rather than 3
/// at 40 — because it has to read around a 48pt ring rather than along a 240pt bar.
public struct ExpressiveCircularWavyProgressIndicator: View {
    @Environment(\.expressiveColors) private var colors

    /// `CircularProgressIndicatorTokens.WaveSize`, `TrackThickness`, `ActiveWaveAmplitude`,
    /// `ActiveWaveWavelength` and `TrackActiveSpace`.
    private let diameter: CGFloat = 48
    private let thickness: CGFloat = 4
    private let amplitude: CGFloat = 1.6
    private let wavelength: CGFloat = 15
    private let gap: CGFloat = 4

    private let progress: Double?

    @State private var waveHeight: CGFloat

    public init() {
        self.progress = nil
        self._waveHeight = State(initialValue: 1.6)
    }

    public init(progress: Double) {
        self.progress = progress
        self._waveHeight = State(initialValue: (progress <= 0.1 || progress >= 0.95) ? 0 : 1.6)
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let geometry = ExpressiveArcGeometry(size: size, thickness: thickness, gap: gap)
                if let progress {
                    draw(
                        determinate: Swift.min(Swift.max(progress, 0), 1),
                        phase: time,
                        geometry: geometry,
                        in: context
                    )
                } else {
                    draw(
                        rotation: ExpressiveCircularProgressMotion.rotation(at: time),
                        sweep: ExpressiveCircularProgressMotion.sweep(at: time),
                        phase: time,
                        geometry: geometry,
                        in: context
                    )
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .onChange(of: progress) { _ in updateWave() }
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(progress.map { Text("\(Int(Swift.min(Swift.max($0, 0), 1) * 100)) percent") } ?? Text(""))
    }

    private func updateWave() {
        let wanted: CGFloat
        if let progress {
            wanted = (progress <= 0.1 || progress >= 0.95) ? 0 : amplitude
        } else {
            wanted = amplitude
        }
        withAnimation(.easeInOut(duration: 0.5)) { waveHeight = wanted }
    }

    private func draw(
        determinate progress: Double,
        phase: Double,
        geometry: ExpressiveArcGeometry,
        in context: GraphicsContext
    ) {
        let filled = 360 * progress
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
                wave(from: -90, sweep: filled, phase: phase, geometry: geometry),
                with: .color(colors.primary),
                style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func draw(
        rotation: Double,
        sweep: Double,
        phase: Double,
        geometry: ExpressiveArcGeometry,
        in context: GraphicsContext
    ) {
        // No track: `circularIndeterminateTrackColor` is transparent.
        context.stroke(
            wave(from: -90 + rotation, sweep: 360 * sweep, phase: phase, geometry: geometry),
            with: .color(colors.primary),
            style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round)
        )
    }

    /// The arc as a wave: the radius rises and falls as it goes round.
    ///
    /// The wavelength is snapped so a whole number of waves fits the ring. Left as it is, the wave
    /// would arrive back at its start mid-crest, and a wavy ring at full progress would have a
    /// visible seam where the two ends meet at different heights.
    private func wave(
        from start: Double,
        sweep: Double,
        phase: Double,
        geometry: ExpressiveArcGeometry
    ) -> Path {
        let circumference = 2 * .pi * Double(geometry.radius)
        let waves = Swift.max((circumference / Double(wavelength)).rounded(), 1)
        let travelled = phase * Double(wavelength) / circumference * waves

        var path = Path()
        let steps = Swift.max(Int(abs(sweep) / 1.5), 2)
        for step in 0...steps {
            let fraction = Double(step) / Double(steps)
            let degrees = start + sweep * fraction
            let radians = degrees * .pi / 180
            let along = (degrees + 90) / 360
            let radius = Double(geometry.radius)
                + Double(waveHeight) * sin(2 * .pi * (along * waves + travelled))
            let point = CGPoint(
                x: geometry.centre.x + CGFloat(cos(radians) * radius),
                y: geometry.centre.y + CGFloat(sin(radians) * radius)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
