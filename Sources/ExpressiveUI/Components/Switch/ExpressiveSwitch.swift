import SwiftUI

/// Material 3's `Switch`, which is a different control from the one `Toggle` draws by default.
///
/// Everything here is a token read out of `material3`'s own `SwitchTokens`, not an approximation of
/// the look:
///
/// - a 52x32 track, fully rounded, with a 2pt outline while off
/// - a 16pt thumb off and a 24pt thumb on, growing to 28pt while pressed
/// - off: `surfaceContainerHighest` track, `outline` border and thumb
/// - on: `primary` track, `onPrimary` thumb, and the check in `onPrimaryContainer` — the glyph is
///   the accent again rather than a hole in the thumb
///
/// It is a `ToggleStyle` so the call sites stay ordinary `Toggle`s and keep their accessibility:
///
/// ```swift
/// Toggle("Reminders", isOn: $isOn)
///     .toggleStyle(.expressive)
/// ```
public struct ExpressiveSwitchStyle: ToggleStyle {
    @Environment(\.expressiveColors) private var colors
    @Environment(\.isEnabled) private var isEnabled

    /// `SwitchTokens.TrackWidth` / `TrackHeight`.
    private let trackWidth: CGFloat = 52
    private let trackHeight: CGFloat = 32

    /// `UnselectedHandleWidth`, `SelectedHandleWidth`, `PressedHandleWidth`.
    private let thumbOff: CGFloat = 16
    private let thumbOn: CGFloat = 24
    private let thumbPressed: CGFloat = 28

    /// `TrackOutlineWidth`.
    private let outlineWidth: CGFloat = 2

    /// `SelectedIconSize`.
    private let iconSize: CGFloat = 16

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        // The label has to be drawn, and drawn by the style: a `ToggleStyle` is responsible for the
        // whole control, so one that renders only the switch silently deletes whatever the call
        // site put in the `Toggle`'s body. `Spacer(minLength: 0)` costs nothing when the label is
        // empty — which is how a settings row uses it, having already laid out its own text.
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 0)
            SwitchBody(
                configuration: configuration,
                colors: colors,
                isEnabled: isEnabled,
                trackWidth: trackWidth,
                trackHeight: trackHeight,
                thumbOff: thumbOff,
                thumbOn: thumbOn,
                thumbPressed: thumbPressed,
                outlineWidth: outlineWidth,
                iconSize: iconSize
            )
        }
    }

    private struct SwitchBody: View {
        let configuration: Configuration
        let colors: ExpressiveColors
        let isEnabled: Bool
        let trackWidth: CGFloat
        let trackHeight: CGFloat
        let thumbOff: CGFloat
        let thumbOn: CGFloat
        let thumbPressed: CGFloat
        let outlineWidth: CGFloat
        let iconSize: CGFloat

        @State private var isPressed = false

        private var isOn: Bool { configuration.isOn }

        private var thumbSize: CGFloat {
            if isPressed { return thumbPressed }
            return isOn ? thumbOn : thumbOff
        }

        /// Compose derives the travel from the track and the *selected* thumb: the leading edge runs
        /// from `(height - size) / 2` to that plus `(width - 24) - 4`, which puts the on-thumb 4pt
        /// from the trailing edge and the smaller off-thumb 8pt from the leading one. Expressed here
        /// as the two centres those work out to, so the pressed size can grow around them.
        private var thumbCentreX: CGFloat {
            isOn ? trackWidth - thumbOn / 2 - 4 : thumbOff / 2 + 8
        }

        var body: some View {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isOn ? colors.primary : colors.surfaceContainerHighest)
                    .overlay {
                        // Only the off state carries a border; on, the track is a solid fill.
                        Capsule().strokeBorder(
                            isOn ? .clear : colors.outline,
                            lineWidth: outlineWidth
                        )
                    }
                    .frame(width: trackWidth, height: trackHeight)
                    // The colour is nearest the change, so it takes the effects spring while the
                    // thumb's travel below keeps the spatial one.
                    .animation(ExpressiveMotion.fastEffects, value: isOn)

                Circle()
                    .fill(isOn ? colors.onPrimary : colors.outline)
                    .animation(ExpressiveMotion.fastEffects, value: isOn)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay {
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: iconSize * 0.72, weight: .bold))
                                .foregroundStyle(colors.onPrimaryContainer)
                        }
                    }
                    .offset(x: thumbCentreX - thumbSize / 2)
            }
            .frame(width: trackWidth, height: trackHeight)
            .opacity(isEnabled ? 1 : 0.38)
            .animation(ExpressiveMotion.fastSpatial, value: isOn)
            .animation(ExpressiveMotion.fastSpatial, value: isPressed)
            .contentShape(Capsule())
            .onTapGesture { configuration.isOn.toggle() }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !isPressed { isPressed = true } }
                    .onEnded { _ in isPressed = false },
                // The `isEnabled:` overload is iOS 18; `including:` reaches back to the package's
                // deployment target and means the same thing for a disabled control.
                including: isEnabled ? .all : .subviews
            )
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
            }
        }
    }
}

public extension ToggleStyle where Self == ExpressiveSwitchStyle {
    /// Material 3's switch. See ``ExpressiveSwitchStyle``.
    static var expressive: ExpressiveSwitchStyle { ExpressiveSwitchStyle() }
}
