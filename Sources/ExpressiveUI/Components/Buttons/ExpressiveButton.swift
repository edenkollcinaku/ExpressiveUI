import SwiftUI

/// Material 3's button, in all five emphases and all five sizes.
///
/// ```swift
/// Button("Save") { save() }
///     .buttonStyle(.expressive)
///
/// Button("Cancel") { dismiss() }
///     .buttonStyle(.expressive(.text))
///
/// Button("Join now") { join() }
///     .buttonStyle(.expressive(.filled, size: .large))
/// ```
///
/// The press is the part that makes it Expressive rather than merely Material: the container is a
/// pill at rest and morphs to a squarer corner while held — `ContainerShapeRound` to
/// `PressedContainerShape` — instead of dimming or scaling.
public struct ExpressiveButtonStyle: ButtonStyle {
    /// How much weight the button carries, in Compose's order of emphasis.
    public enum Variant: Sendable {
        /// `Button`. The one high-emphasis action that completes a flow.
        case filled
        /// `ElevatedButton`. A filled button that needs separating from a busy surface behind it.
        case elevated
        /// `FilledTonalButton`. Between filled and outlined: important, but not the final word.
        case tonal
        /// `OutlinedButton`. A container only where it matters, for secondary actions.
        case outlined
        /// `TextButton`. The lowest emphasis, for actions that must not compete.
        case text
    }

    /// The five container heights Expressive names, from `ButtonXSmallTokens` to
    /// `ButtonXLargeTokens`. They are not just heights: the padding, the icon, the label and the
    /// pressed corner all move with them.
    public enum Size: Sendable {
        case extraSmall, small, medium, large, extraLarge

        /// `ContainerHeight`.
        var height: CGFloat {
            switch self {
            case .extraSmall: return 32
            case .small: return 40
            case .medium: return 56
            case .large: return 96
            case .extraLarge: return 136
            }
        }

        /// `LeadingSpace` / `TrailingSpace`.
        var horizontalPadding: CGFloat {
            switch self {
            case .extraSmall, .small: return 16
            case .medium: return 24
            case .large: return 48
            case .extraLarge: return 64
            }
        }

        /// `PressedContainerShape`, which the container morphs to while held.
        var pressedCorner: CGFloat {
            switch self {
            case .extraSmall, .small: return 8
            case .medium: return 12
            case .large, .extraLarge: return 16
            }
        }

        /// The label's size on Material's type scale — label large through headline medium. The size
        /// tokens carry no font of their own, so these come from the scale rather than from a token
        /// that could be read out.
        var labelSize: CGFloat {
            switch self {
            case .extraSmall, .small: return 14
            case .medium: return 16
            case .large: return 24
            case .extraLarge: return 32
            }
        }
    }

    private let variant: Variant
    private let size: Size

    public init(_ variant: Variant = .filled, size: Size = .small) {
        self.variant = variant
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        Container(configuration: configuration, variant: variant, size: size)
    }

    /// A view of its own so it can read `isEnabled`, which a `ButtonStyle` cannot see directly.
    private struct Container: View {
        @Environment(\.expressiveColors) private var colors
        @Environment(\.isEnabled) private var isEnabled

        let configuration: Configuration
        let variant: Variant
        let size: Size

        /// `ButtonSmallTokens.OutlinedOutlineWidth`.
        private let outlineWidth: CGFloat = 1
        /// `ButtonDefaults.MinWidth`.
        private let minWidth: CGFloat = 58

        var body: some View {
            configuration.label
                .font(.system(size: size.labelSize, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(contentColor)
                .padding(.horizontal, size.horizontalPadding)
                .frame(minWidth: minWidth, minHeight: size.height)
                .background(containerColor, in: shape)
                .overlay {
                    if variant == .outlined {
                        shape.strokeBorder(outlineColor, lineWidth: outlineWidth)
                    }
                }
                // `ElevatedButtonTokens.ContainerElevation` is level 1; every other variant sits flat
                // on the surface.
                .shadow(
                    color: .black.opacity(variant == .elevated && isEnabled ? 0.20 : 0),
                    radius: 3,
                    y: 1
                )
                .animation(ExpressiveMotion.fastSpatial, value: configuration.isPressed)
                .animation(ExpressiveMotion.fastEffects, value: isEnabled)
        }

        /// A pill at rest, a squarer corner while held. Rounded rather than a `Capsule` because the
        /// two corners have to animate into each other.
        private var shape: RoundedRectangle {
            RoundedRectangle(
                cornerRadius: configuration.isPressed ? size.pressedCorner : size.height / 2,
                style: .continuous
            )
        }

        private var containerColor: Color {
            guard isEnabled else {
                // `DisabledContainerColor` is `onSurface` at 10%, for every variant that has a
                // container at all.
                return variant == .outlined || variant == .text
                    ? .clear
                    : colors.onSurface.opacity(0.1)
            }
            switch variant {
            case .filled: return colors.primary
            case .elevated: return colors.surfaceContainerLow
            case .tonal: return colors.secondaryContainer
            case .outlined, .text: return .clear
            }
        }

        private var contentColor: Color {
            // `DisabledLabelTextColor` is `onSurfaceVariant` at 38%.
            guard isEnabled else { return colors.onSurfaceVariant.opacity(0.38) }
            switch variant {
            case .filled: return colors.onPrimary
            case .elevated: return colors.primary
            case .tonal: return colors.onSecondaryContainer
            case .outlined, .text: return colors.onSurfaceVariant
            }
        }

        private var outlineColor: Color {
            // `OutlineColor` is `outlineVariant`, and `DisabledOutlineColor` is the same role at the
            // disabled alpha rather than a different colour.
            isEnabled ? colors.outlineVariant : colors.outlineVariant.opacity(0.38)
        }
    }
}

public extension ButtonStyle where Self == ExpressiveButtonStyle {
    /// Material 3's filled button at its default size. See ``ExpressiveButtonStyle``.
    static var expressive: ExpressiveButtonStyle { ExpressiveButtonStyle() }

    /// Material 3's button in a given emphasis and size. See ``ExpressiveButtonStyle``.
    static func expressive(
        _ variant: ExpressiveButtonStyle.Variant,
        size: ExpressiveButtonStyle.Size = .small
    ) -> ExpressiveButtonStyle {
        ExpressiveButtonStyle(variant, size: size)
    }
}
