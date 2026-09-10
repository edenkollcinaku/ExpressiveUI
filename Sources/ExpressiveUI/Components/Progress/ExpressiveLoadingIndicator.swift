import SwiftUI

/// Material 3's loading indicator: a shape that spins while morphing through a sequence of others.
///
/// ```swift
/// ExpressiveLoadingIndicator()                 // spins until it goes away
/// ExpressiveLoadingIndicator(progress: 0.4)    // morphs by how far along you are
/// ```
///
/// Contained, it sits on a `primaryContainer` circle — Compose's `ContainedLoadingIndicator`:
///
/// ```swift
/// ExpressiveLoadingIndicator(contained: true)
/// ```
///
/// Two things are happening at once, and they are deliberately out of step: the whole shape turns
/// once every 4.666 seconds at a constant rate, while every 650ms it springs into the next shape in
/// the sequence *and* adds a quarter turn of its own. Because the spring settles before the next
/// morph begins, the indicator keeps arriving somewhere and setting off again, which is what stops
/// it reading as a mechanical spinner.
public struct ExpressiveLoadingIndicator: View {
    @Environment(\.expressiveColors) private var colors
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `LoadingIndicatorTokens.ContainerWidth` / `ContainerHeight` and `ActiveSize`.
    private let containerSize: CGFloat = 48
    private let indicatorSize: CGFloat = 38

    /// `GlobalRotationDurationMillis` and `MorphIntervalMillis`.
    private let rotationPeriod: Double = 4.666
    private let morphInterval: Double = 0.650

    /// The morph's own spring — damping 0.6, stiffness 200 — which Compose runs with a raised
    /// visibility threshold so it settles inside the 650ms before the next one starts.
    private let morphDamping: Double = 0.6
    private let morphStiffness: Double = 200

    private let shapes: [ExpressiveMaterialShape]
    private let contained: Bool
    private let progress: Double?

    /// The indeterminate indicator: morphs through `shapes` for as long as it is on screen.
    public init(
        shapes: [ExpressiveMaterialShape] = ExpressiveMaterialShape.indeterminateSequence,
        contained: Bool = false
    ) {
        self.shapes = shapes
        self.contained = contained
        self.progress = nil
    }

    /// The determinate indicator: its place in the sequence *is* the progress, and it turns
    /// counterclockwise through half a revolution on the way.
    public init(
        progress: Double,
        shapes: [ExpressiveMaterialShape] = ExpressiveMaterialShape.determinateSequence,
        contained: Bool = false
    ) {
        self.shapes = shapes
        self.contained = contained
        self.progress = progress
    }

    public var body: some View {
        indicator
            .frame(width: containerSize, height: containerSize)
            .background(contained ? colors.primaryContainer : .clear, in: Circle())
            .accessibilityElement()
            .accessibilityLabel("Loading")
            .accessibilityValue(progress.map { Text("\(Int($0.clamped() * 100)) percent") } ?? Text(""))
    }

    @ViewBuilder
    private var indicator: some View {
        if let progress {
            shape(index: morphIndex(for: progress), progress: morphProgress(for: progress))
                // Counterclockwise, half a turn across the whole of the progress.
                .rotationEffect(.degrees(-progress.clamped() * 180))
        } else if reduceMotion {
            // Someone who has asked for less motion still needs to know it is working, so the
            // sequence keeps going and the spinning stops.
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let step = Int(time / morphInterval)
                shape(index: step % shapes.count, progress: spring(at: time.truncatingRemainder(dividingBy: morphInterval)))
            }
        } else {
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let step = Int(time / morphInterval)
                let intoMorph = time.truncatingRemainder(dividingBy: morphInterval)
                let settled = spring(at: intoMorph)
                shape(index: step % shapes.count, progress: settled)
                    .rotationEffect(.degrees(
                        // The steady turn, plus the quarter each morph brings with it.
                        time / rotationPeriod * 360 + (Double(step) + settled) * 90
                    ))
            }
        }
    }

    private func shape(index: Int, progress: Double) -> some View {
        Canvas { context, size in
            let path = shapes.morphedPath(
                index: index,
                progress: progress,
                in: CGRect(origin: .zero, size: size)
            )
            context.fill(Path(path), with: .color(indicatorColor))
        }
        .frame(width: indicatorSize, height: indicatorSize)
    }

    private var indicatorColor: Color {
        contained ? colors.onPrimaryContainer : colors.primary
    }

    /// Which morph of the sequence a determinate indicator is in the middle of.
    private func morphIndex(for progress: Double) -> Int {
        let morphs = Swift.max(shapes.count - 1, 1)
        return Swift.min(Int(progress.clamped() * Double(morphs)), morphs - 1)
    }

    private func morphProgress(for progress: Double) -> Double {
        let morphs = Swift.max(shapes.count - 1, 1)
        let scaled = progress.clamped() * Double(morphs)
        // At exactly 1 the fraction would wrap to zero and snap back to the previous shape.
        return scaled >= Double(morphs) ? 1 : scaled.truncatingRemainder(dividingBy: 1)
    }

    /// Where an underdamped spring has got to, `time` seconds after it was let go.
    ///
    /// Spelled out rather than handed to `Animation.spring`, because the indicator's frame is drawn
    /// from a clock rather than from a state change: at any instant it has to be able to say where
    /// the morph is, including the overshoot past 1 that gives the shape its slight snap.
    private func spring(at time: Double) -> Double {
        let omega = morphStiffness.squareRoot()
        let damped = omega * (1 - morphDamping * morphDamping).squareRoot()
        let decay = exp(-morphDamping * omega * time)
        return 1 - decay * (cos(damped * time) + (morphDamping * omega / damped) * sin(damped * time))
    }
}

private extension Double {
    func clamped() -> Double { Swift.min(Swift.max(self, 0), 1) }
}
