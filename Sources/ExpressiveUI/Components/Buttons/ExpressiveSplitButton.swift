import SwiftUI

/// Material 3's split button: one button that runs the primary action, and a second, narrower one
/// beside it that opens whatever is contextually related to it.
///
/// ```swift
/// @State private var showingOptions = false
///
/// ExpressiveSplitButton("Edit", systemImage: "pencil", isExpanded: $showingOptions) {
///     edit()
/// }
/// .popover(isPresented: $showingOptions) { optionsList }
/// ```
///
/// The trailing button is a toggle, not a menu, which is how Compose has it: `SplitButtonLayout`
/// takes two buttons and the sample attaches its own menu to the trailing one. Binding it here
/// rather than owning a menu keeps the presentation yours — a popover, a sheet, a custom panel —
/// while the component keeps the parts Material specifies: the chevron turns over, and the trailing
/// button becomes a circle while it is open.
public struct ExpressiveSplitButton: View {
    @Environment(\.expressiveColors) private var colors
    @Environment(\.isEnabled) private var isEnabled

    /// The five sizes, from `SplitButtonXSmallTokens` to `SplitButtonXLargeTokens`.
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

        /// `LeadingButtonLeadingSpace` and `LeadingButtonTrailingSpace`.
        var leadingButtonPadding: (leading: CGFloat, trailing: CGFloat) {
            switch self {
            case .extraSmall: return (12, 10)
            case .small: return (16, 12)
            case .medium: return (24, 24)
            case .large: return (48, 48)
            case .extraLarge: return (64, 64)
            }
        }

        /// `TrailingButtonLeadingSpace` / `TrailingButtonTrailingSpace`, which are equal at every
        /// size — the trailing button is a square-ish tap target around one icon.
        var trailingButtonPadding: CGFloat {
            switch self {
            case .extraSmall: return 10
            case .small: return 13
            case .medium: return 16
            case .large: return 28
            case .extraLarge: return 40
            }
        }

        /// `TrailingIconSize`.
        var trailingIconSize: CGFloat {
            switch self {
            case .extraSmall: return 22
            case .small: return 22
            case .medium: return 26
            case .large: return 38
            case .extraLarge: return 50
            }
        }

        /// `InnerCornerCornerSize` — the corners where the two buttons face each other.
        var innerCorner: CGFloat {
            switch self {
            case .extraSmall, .small, .medium: return 4
            case .large: return 8
            case .extraLarge: return 12
            }
        }

        /// `InnerPressedCornerCornerSize`. Pressing *opens* the inner corner rather than tightening
        /// it, which is the opposite of what the standalone button does and is deliberate: the two
        /// halves pull apart from each other.
        var pressedInnerCorner: CGFloat {
            switch self {
            case .extraSmall, .small, .medium: return 12
            case .large, .extraLarge: return 20
            }
        }

        /// Material's type scale, as with ``ExpressiveButtonStyle``.
        var labelSize: CGFloat {
            switch self {
            case .extraSmall, .small: return 14
            case .medium: return 16
            case .large: return 24
            case .extraLarge: return 32
            }
        }
    }

    /// `SplitButtonDefaults.Spacing`, which is 2 at every size.
    private let spacing: CGFloat = 2

    private let label: LocalizedStringKey
    private let systemImage: String?
    private let size: Size
    private let action: () -> Void
    @Binding private var isExpanded: Bool

    @State private var pressedHalf: Half?

    private enum Half { case leading, trailing }

    public init(
        _ label: LocalizedStringKey,
        systemImage: String? = nil,
        size: Size = .small,
        isExpanded: Binding<Bool>,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.size = size
        self._isExpanded = isExpanded
        self.action = action
    }

    public var body: some View {
        HStack(spacing: spacing) {
            leadingButton
            trailingButton
        }
        .frame(height: size.height)
        .animation(ExpressiveMotion.fastSpatial, value: pressedHalf)
        .animation(ExpressiveMotion.fastSpatial, value: isExpanded)
    }

    private var leadingButton: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(label)
                    .lineLimit(1)
            }
            .font(.system(size: size.labelSize, weight: .medium))
            .foregroundStyle(contentColor)
            .padding(.leading, size.leadingButtonPadding.leading)
            .padding(.trailing, size.leadingButtonPadding.trailing)
            .frame(maxHeight: .infinity)
            .background(containerColor, in: leadingShape)
        }
        .buttonStyle(.plain)
        .pressed(into: $pressedHalf, as: .leading, isEnabled: isEnabled)
    }

    private var trailingButton: some View {
        Button {
            isExpanded.toggle()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: size.trailingIconSize * 0.6, weight: .semibold))
                // The chevron turns over rather than swapping for a second glyph.
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .foregroundStyle(contentColor)
                .frame(width: size.trailingIconSize, height: size.trailingIconSize)
                .padding(.horizontal, size.trailingButtonPadding)
                .frame(maxHeight: .infinity)
                .background(containerColor, in: trailingShape)
        }
        .buttonStyle(.plain)
        .pressed(into: $pressedHalf, as: .trailing, isEnabled: isEnabled)
        .accessibilityLabel(isExpanded ? "Hide options" : "Show options")
    }

    /// Outer corners full, inner corners small — and opening while pressed.
    private var leadingShape: UnevenRoundedRectangle {
        let outer = size.height / 2
        let inner = pressedHalf == .leading ? size.pressedInnerCorner : size.innerCorner
        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: outer,
                bottomLeading: outer,
                bottomTrailing: inner,
                topTrailing: inner
            ),
            style: .continuous
        )
    }

    /// The mirror of the leading one, except while expanded: `TrailingCheckedShape` is a circle, so
    /// the button that opened the thing is round for as long as it is open.
    private var trailingShape: UnevenRoundedRectangle {
        let outer = size.height / 2
        let inner = isExpanded
            ? outer
            : (pressedHalf == .trailing ? size.pressedInnerCorner : size.innerCorner)
        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: inner,
                bottomLeading: inner,
                bottomTrailing: outer,
                topTrailing: outer
            ),
            style: .continuous
        )
    }

    private var containerColor: Color {
        isEnabled ? colors.primary : colors.onSurface.opacity(0.1)
    }

    private var contentColor: Color {
        isEnabled ? colors.onPrimary : colors.onSurfaceVariant.opacity(0.38)
    }
}

private extension View {
    /// Reports presses into a shared slot, so each half knows whether *it* is the one being held —
    /// the inner corners of both halves are drawn from that one piece of state.
    func pressed<Half: Equatable>(
        into binding: Binding<Half?>,
        as half: Half,
        isEnabled: Bool
    ) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled, binding.wrappedValue != half { binding.wrappedValue = half } }
                .onEnded { _ in binding.wrappedValue = nil }
        )
    }
}
