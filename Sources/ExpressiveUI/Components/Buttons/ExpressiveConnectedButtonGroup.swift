import SwiftUI

/// One segment of an ``ExpressiveConnectedButtonGroup``.
public struct ExpressiveConnectedButtonGroupOption<Value: Hashable>: Identifiable {
    public var id: Value { value }
    public var value: Value
    public var label: LocalizedStringKey
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

/// Material 3's connected button group: segments 2pt apart whose corners round to a pill where the
/// group meets the outside and barely at all where one segment meets the next.
///
/// Single selection:
///
/// ```swift
/// ExpressiveConnectedButtonGroup(selection: $range, options: [
///     .init(value: .day, label: "Day"),
///     .init(value: .week, label: "Week"),
///     .init(value: .month, label: "Month")
/// ])
/// ```
///
/// Multiple selection — pass a `Set` instead, and segments toggle independently:
///
/// ```swift
/// ExpressiveConnectedButtonGroup(selection: $formats, options: options)
/// ```
///
/// Three things make it read as Material rather than as a generic segmented control, and all three
/// come from `ConnectedButtonGroupSmallTokens`:
///
/// - the inner corners are 8pt, tightening to 4pt while a segment is pressed;
/// - a selected segment is a pill on *both* sides — it is the one being read, not part of a run;
/// - pressing a segment widens it and its neighbours give up the space.
public struct ExpressiveConnectedButtonGroup<Value: Hashable>: View {
    @Environment(\.expressiveColors) private var colors
    @Environment(\.isEnabled) private var isEnabled

    /// `ConnectedButtonGroupSmallTokens.BetweenSpace` and `ContainerHeight`.
    private let spacing: CGFloat = 2
    private let height: CGFloat = 40

    /// `InnerCornerCornerSize` and `PressedInnerCornerCornerSize`.
    private let innerCorner: CGFloat = 8
    private let pressedInnerCorner: CGFloat = 4

    private let expandedRatio: CGFloat
    private let options: [ExpressiveConnectedButtonGroupOption<Value>]
    private let selection: Selection

    @State private var pressedIndex: Int?

    private enum Selection {
        case single(Binding<Value>)
        case multiple(Binding<Set<Value>>)
    }

    /// One choice out of the set.
    public init(
        selection: Binding<Value>,
        expandedRatio: CGFloat = 0.15,
        options: [ExpressiveConnectedButtonGroupOption<Value>]
    ) {
        self.selection = .single(selection)
        self.expandedRatio = expandedRatio
        self.options = options
    }

    /// Any number of choices, including none.
    public init(
        selection: Binding<Set<Value>>,
        expandedRatio: CGFloat = 0.15,
        options: [ExpressiveConnectedButtonGroupOption<Value>]
    ) {
        self.selection = .multiple(selection)
        self.expandedRatio = expandedRatio
        self.options = options
    }

    public var body: some View {
        GeometryReader { proxy in
            HStack(spacing: spacing) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    segment(option, at: index)
                        .frame(
                            width: ExpressiveButtonGroupLayout.width(
                                at: index,
                                count: options.count,
                                total: proxy.size.width,
                                spacing: spacing,
                                pressedIndex: pressedIndex,
                                expandedRatio: expandedRatio
                            )
                        )
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.76), value: pressedIndex)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: selectedValues)
        }
        .frame(height: height)
        .opacity(isEnabled ? 1 : 0.38)
    }

    private func segment(_ option: ExpressiveConnectedButtonGroupOption<Value>, at index: Int) -> some View {
        let checked = isChecked(option.value)

        return Button {
            select(option.value)
        } label: {
            ButtonGroupLabel(
                label: option.label,
                systemImage: option.systemImage,
                foreground: checked ? colors.onPrimary : colors.onSurfaceVariant
            )
            .background(
                checked ? colors.primary : colors.surfaceContainer,
                in: shape(at: index, checked: checked, pressed: pressedIndex == index)
            )
        }
        .buttonStyle(.plain)
        .disabled(!option.isEnabled)
        .opacity(option.isEnabled ? 1 : 0.38)
        // One choice out of a set, which is what a screen reader should say — otherwise every
        // segment announces as an independent button with nothing tying them together.
        .accessibilityAddTraits(checked ? [.isButton, .isSelected] : .isButton)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if option.isEnabled, pressedIndex != index { pressedIndex = index } }
                .onEnded { _ in pressedIndex = nil }
        )
    }

    private func shape(at index: Int, checked: Bool, pressed: Bool) -> UnevenRoundedRectangle {
        // The outer corner is spelled from the control's own height rather than as a percentage, so
        // it lands on a true pill at whatever height the group is given.
        let outer = height / 2
        let inner = pressed ? pressedInnerCorner : innerCorner
        // `SelectedInnerCornerCornerSizePercent` is 50: selected, both sides go full.
        let leading = checked || index == 0 ? outer : inner
        let trailing = checked || index == options.count - 1 ? outer : inner
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

    private var selectedValues: Set<Value> {
        switch selection {
        case let .single(binding): return [binding.wrappedValue]
        case let .multiple(binding): return binding.wrappedValue
        }
    }

    private func isChecked(_ value: Value) -> Bool {
        selectedValues.contains(value)
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
