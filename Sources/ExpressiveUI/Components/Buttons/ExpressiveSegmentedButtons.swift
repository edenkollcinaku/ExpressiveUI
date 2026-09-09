import SwiftUI

/// One segment of an ``ExpressiveSegmentedButtons`` row.
public struct ExpressiveSegmentedButtonOption<Value: Hashable>: Identifiable {
    public var id: Value { value }
    public var value: Value
    public var label: LocalizedStringKey
    /// Shown in place of the checkmark while this segment is *not* selected — Compose's
    /// `inactiveContent`. Leave it out and the segment simply has no icon until it is selected.
    public var systemImage: String?
    public var isEnabled: Bool

    public init(
        value: Value,
        label: LocalizedStringKey,
        systemImage: String? = nil,
        isEnabled: Bool = true
    ) {
        self.value = value
        self.label = label
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }
}

/// Material 3's segmented button: outlined segments in a single row, sharing their borders, with a
/// checkmark that grows into the selected one.
///
/// One choice out of a set — Compose's `SingleChoiceSegmentedButtonRow`:
///
/// ```swift
/// ExpressiveSegmentedButtons(selection: $range, options: [
///     .init(value: .day, label: "Day"),
///     .init(value: .week, label: "Week"),
///     .init(value: .month, label: "Month")
/// ])
/// ```
///
/// Any number of choices — `MultiChoiceSegmentedButtonRow`. Pass a `Set` and each segment toggles
/// on its own. Material asks for between two and five of them; past that it wants chips.
///
/// ```swift
/// ExpressiveSegmentedButtons(selection: $modes, options: modes)
/// ```
///
/// This is not ``ExpressiveConnectedButtonGroup``. Both put choices in a row, but a segmented button
/// is outlined, shares one border line between neighbours, and marks its selection with a checkmark;
/// the connected group is filled, keeps its segments 2pt apart, and marks selection by turning the
/// chosen one into a pill. Segmented buttons came first; the connected group is what Expressive
/// reaches for now.
public struct ExpressiveSegmentedButtons<Value: Hashable>: View {
    @Environment(\.expressiveColors) private var colors
    @Environment(\.isEnabled) private var isEnabled

    /// `OutlinedSegmentedButtonTokens.ContainerHeight`, `OutlineWidth` and `IconSize`.
    private let height: CGFloat = 40
    private let borderWidth: CGFloat = 1
    private let iconSize: CGFloat = 18

    /// `SegmentedButtonDefaults.ContentPadding`, and the gap between icon and label.
    private let horizontalPadding: CGFloat = 12
    private let iconSpacing: CGFloat = 8

    private let options: [ExpressiveSegmentedButtonOption<Value>]
    private let selection: Selection

    private enum Selection {
        case single(Binding<Value>)
        case multiple(Binding<Set<Value>>)
    }

    /// One choice out of the set.
    public init(
        selection: Binding<Value>,
        options: [ExpressiveSegmentedButtonOption<Value>]
    ) {
        self.selection = .single(selection)
        self.options = options
    }

    /// Any number of choices, including none.
    public init(
        selection: Binding<Set<Value>>,
        options: [ExpressiveSegmentedButtonOption<Value>]
    ) {
        self.selection = .multiple(selection)
        self.options = options
    }

    public var body: some View {
        // Negative spacing by exactly the border width: two neighbours' borders land on the same
        // line rather than stacking into a 2pt seam. It is what Compose's `space` parameter does,
        // and it defaults to the border width there too.
        HStack(spacing: -borderWidth) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                segment(option, at: index)
            }
        }
        .frame(height: height)
    }

    private func segment(_ option: ExpressiveSegmentedButtonOption<Value>, at index: Int) -> some View {
        let selected = isSelected(option.value)
        let enabled = isEnabled && option.isEnabled

        return Button {
            select(option.value)
        } label: {
            HStack(spacing: iconSpacing) {
                icon(for: option, selected: selected)
                Text(option.label)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(content(selected: selected, enabled: enabled))
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                selected && enabled ? colors.secondaryContainer : .clear,
                in: shape(at: index)
            )
            .overlay {
                shape(at: index).strokeBorder(
                    // `DisabledOutlineColor` is `onSurface` at 12%; enabled it is plain `outline`.
                    enabled ? colors.outline : colors.onSurface.opacity(0.12),
                    lineWidth: borderWidth
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .contentShape(Rectangle())
        // A selected segment draws above its neighbours so its border is the one that survives on
        // the shared line — Compose raises it by a z-index for the same reason.
        .zIndex(selected ? 1 : 0)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .animation(ExpressiveMotion.fastEffects, value: selected)
    }

    @ViewBuilder
    private func icon(for option: ExpressiveSegmentedButtonOption<Value>, selected: Bool) -> some View {
        if let systemImage = option.systemImage {
            // With an icon of its own, the segment crossfades between it and the checkmark rather
            // than making room for a second glyph.
            Image(systemName: selected ? "checkmark" : systemImage)
                .font(.system(size: iconSize * 0.8, weight: .semibold))
                .frame(width: iconSize, height: iconSize)
                .transition(.opacity)
        } else if selected {
            // Without one, the checkmark grows out of the label's leading edge and the label slides
            // over to make room: `scaleIn` from zero about `TransformOrigin(0f, 1f)`.
            Image(systemName: "checkmark")
                .font(.system(size: iconSize * 0.8, weight: .semibold))
                .frame(width: iconSize, height: iconSize)
                .transition(
                    .scale(scale: 0, anchor: .bottomLeading)
                        .combined(with: .opacity)
                )
        }
    }

    /// `itemShape`: the row's outer ends are pills, and everything between them is square.
    private func shape(at index: Int) -> UnevenRoundedRectangle {
        let full = height / 2
        let isFirst = index == 0
        let isLast = index == options.count - 1
        let leading = isFirst ? full : 0
        let trailing = isLast ? full : 0
        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: leading,
                bottomLeading: leading,
                bottomTrailing: trailing,
                topTrailing: trailing
            ),
            style: .continuous
        )
    }

    private func content(selected: Bool, enabled: Bool) -> Color {
        // `DisabledLabelTextColor` is `onSurface` at 38%.
        guard enabled else { return colors.onSurface.opacity(0.38) }
        return selected ? colors.onSecondaryContainer : colors.onSurface
    }

    private func isSelected(_ value: Value) -> Bool {
        switch selection {
        case let .single(binding): return binding.wrappedValue == value
        case let .multiple(binding): return binding.wrappedValue.contains(value)
        }
    }

    private func select(_ value: Value) {
        switch selection {
        case let .single(binding):
            binding.wrappedValue = value
        case let .multiple(binding):
            if binding.wrappedValue.contains(value) {
                binding.wrappedValue.remove(value)
            } else {
                binding.wrappedValue.insert(value)
            }
        }
    }
}
