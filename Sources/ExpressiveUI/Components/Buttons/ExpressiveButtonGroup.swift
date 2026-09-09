import SwiftUI

/// One button in an ``ExpressiveButtonGroup``.
///
/// Compose's `ButtonGroupScope` has two kinds of item, and so does this: a `clickableItem`, which
/// runs an action, and a `toggleableItem`, which owns a checked state. Which one you get is decided
/// by the initialiser you call.
public struct ExpressiveButtonGroupItem: Identifiable {
    public let id = UUID()
    public var label: LocalizedStringKey
    public var systemImage: String?
    public var isEnabled: Bool
    /// A share of the space left over once the unweighted buttons have taken what they need — the
    /// `weight` parameter on Compose's items. `nil` sizes the button to its own label.
    public var weight: CGFloat?

    enum Kind {
        case clickable(() -> Void)
        case toggleable(Binding<Bool>)
    }

    let kind: Kind

    /// A button that runs `action` — Compose's `clickableItem`.
    public init(
        label: LocalizedStringKey,
        systemImage: String? = nil,
        weight: CGFloat? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.weight = weight
        self.isEnabled = isEnabled
        self.kind = .clickable(action)
    }

    /// A button that carries a checked state — Compose's `toggleableItem`.
    public init(
        label: LocalizedStringKey,
        systemImage: String? = nil,
        weight: CGFloat? = nil,
        isEnabled: Bool = true,
        isOn: Binding<Bool>
    ) {
        self.label = label
        self.systemImage = systemImage
        self.weight = weight
        self.isEnabled = isEnabled
        self.kind = .toggleable(isOn)
    }
}

/// Material 3's standard button group: a row of buttons, 12pt apart, where pressing one widens it
/// and takes the space back from its neighbours.
///
/// ```swift
/// ExpressiveButtonGroup(items: [
///     .init(label: "Reply") { reply() },
///     .init(label: "Forward") { forward() },
///     .init(label: "Star", isOn: $starred)
/// ])
/// ```
///
/// Buttons size themselves to their labels. Give one a `weight` and it takes that share of whatever
/// is left over instead — the same rule as Compose's `Modifier.weight`. Buttons that do not fit
/// collapse into a menu behind a trailing indicator, which is what Compose does with its
/// `overflowIndicator`.
public struct ExpressiveButtonGroup: View {
    @Environment(\.expressiveColors) private var colors
    @Environment(\.isEnabled) private var isEnabled

    /// `ButtonGroupSmallTokens.BetweenSpace` and `ContainerHeight`.
    private let spacing: CGFloat = 12
    private let height: CGFloat = 40

    /// `ButtonGroupDefaults.ExpandedRatio`: the pressed button grows by 15% of its width, and its
    /// neighbours give up that much between them, so the group's own width never changes.
    private let expandedRatio: CGFloat

    private let items: [ExpressiveButtonGroupItem]

    @State private var pressedIndex: Int?
    /// How many buttons the layout could fit. The rest are in the overflow menu.
    @State private var visibleCount: Int

    public init(expandedRatio: CGFloat = 0.15, items: [ExpressiveButtonGroupItem]) {
        self.expandedRatio = expandedRatio
        self.items = items
        self._visibleCount = State(initialValue: items.count)
    }

    public var body: some View {
        ButtonGroupRow(
            spacing: spacing,
            expandedRatio: expandedRatio,
            pressedIndex: pressedIndex,
            weights: items.map(\.weight),
            onVisibleCountChange: { visibleCount = $0 }
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                button(item, at: index)
                    .accessibilityHidden(index >= visibleCount)
            }

            overflowIndicator
        }
        .frame(height: height)
        .opacity(isEnabled ? 1 : 0.38)
        .animation(.spring(response: 0.28, dampingFraction: 0.76), value: pressedIndex)
    }

    @ViewBuilder
    private func button(_ item: ExpressiveButtonGroupItem, at index: Int) -> some View {
        // A clickable item is always filled: Compose draws it with `Button`, which is the filled
        // one, not a tonal or outlined variant. A toggleable item is filled only when checked.
        let checked: Bool = {
            if case let .toggleable(binding) = item.kind { return binding.wrappedValue }
            return true
        }()

        Button {
            activate(item)
        } label: {
            ButtonGroupLabel(
                label: item.label,
                systemImage: item.systemImage,
                foreground: checked ? colors.onPrimary : colors.onSurfaceVariant
            )
            .background(checked ? colors.primary : colors.surfaceContainer, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .opacity(item.isEnabled ? 1 : 0.38)
        .accessibilityAddTraits(isChecked(item) ? [.isButton, .isSelected] : .isButton)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if item.isEnabled, pressedIndex != index { pressedIndex = index } }
                .onEnded { _ in pressedIndex = nil }
        )
    }

    /// The trailing button that holds whatever did not fit. The layout gives it no space at all
    /// while everything fits, so it costs nothing in the common case.
    private var overflowIndicator: some View {
        Menu {
            ForEach(items.dropFirst(visibleCount)) { item in
                Button {
                    activate(item)
                } label: {
                    if let systemImage = item.systemImage {
                        Label(item.label, systemImage: systemImage)
                    } else {
                        Text(item.label)
                    }
                }
                .disabled(!item.isEnabled)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.onSurfaceVariant)
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)
                .background(colors.surfaceContainer, in: Capsule())
        }
        .accessibilityLabel("More")
        .accessibilityHidden(visibleCount >= items.count)
    }

    private func activate(_ item: ExpressiveButtonGroupItem) {
        switch item.kind {
        case let .clickable(action): action()
        case let .toggleable(binding): binding.wrappedValue.toggle()
        }
    }

    private func isChecked(_ item: ExpressiveButtonGroupItem) -> Bool {
        if case let .toggleable(binding) = item.kind { return binding.wrappedValue }
        return false
    }
}

/// The row itself: intrinsic widths, weights, the press squeeze, and the decision about what does
/// not fit. It is a `Layout` rather than an `HStack` because all four of those need the measured
/// widths of every button at once, which is exactly what a layout is handed and a stack is not.
///
/// The last subview is the overflow indicator. It is always present and is given zero width while
/// everything fits.
struct ButtonGroupRow: Layout {
    let spacing: CGFloat
    let expandedRatio: CGFloat
    let pressedIndex: Int?
    let weights: [CGFloat?]
    let onVisibleCountChange: (Int) -> Void

    /// How much of its own width a neighbour may be asked to give up, which Compose caps at the
    /// button's content padding: past that the label starts being clipped rather than tightened.
    private let compressionLimit: CGFloat = 24

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = idealWidths(subviews)
        let natural = widths.reduce(0, +) + spacing * CGFloat(max(widths.count - 1, 0))
        return CGSize(
            width: proposal.width ?? natural,
            height: proposal.height ?? subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }
        let indicator = subviews[subviews.count - 1]
        let items = Array(subviews.dropLast())
        guard !items.isEmpty else { return }

        let ideal = idealWidths(items)
        let indicatorWidth = indicator.sizeThatFits(.unspecified).width
        let visible = visibleCount(ideal: ideal, indicatorWidth: indicatorWidth, available: bounds.width)
        let overflowing = visible < items.count

        // Reporting during layout would be a write inside a read; the next runloop turn is soon
        // enough for a menu that only matters once something has already overflowed.
        DispatchQueue.main.async { onVisibleCountChange(visible) }

        var widths = resolvedWidths(
            ideal: ideal,
            visible: visible,
            available: bounds.width,
            indicatorWidth: overflowing ? indicatorWidth : 0
        )
        squeeze(&widths)

        var x = bounds.minX
        for (index, item) in items.enumerated() {
            guard index < visible else {
                // Placed out of the way rather than left at the origin, where a zero-width button
                // still paints a sliver of its container.
                item.place(
                    at: CGPoint(x: bounds.maxX + 10_000, y: bounds.minY),
                    proposal: ProposedViewSize(width: 0, height: 0)
                )
                continue
            }
            item.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: widths[index], height: bounds.height)
            )
            x += widths[index] + spacing
        }

        indicator.place(
            at: CGPoint(x: overflowing ? x : bounds.maxX + 10_000, y: bounds.minY),
            proposal: ProposedViewSize(width: overflowing ? indicatorWidth : 0, height: bounds.height)
        )
    }

    private func idealWidths(_ subviews: [LayoutSubview]) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(.unspecified).width }
    }

    private func idealWidths(_ subviews: Subviews) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(.unspecified).width }
    }

    /// The most buttons that fit, leaving room for the indicator once anything has to overflow.
    private func visibleCount(ideal: [CGFloat], indicatorWidth: CGFloat, available: CGFloat) -> Int {
        // A row where every button has a weight cannot overflow: the buttons share whatever width
        // there is rather than asking for their own.
        if weights.prefix(ideal.count).allSatisfy({ $0 != nil }) { return ideal.count }

        let all = ideal.reduce(0, +) + spacing * CGFloat(max(ideal.count - 1, 0))
        if all <= available { return ideal.count }

        var used: CGFloat = 0
        var count = 0
        for width in ideal {
            let candidate = used + width + (count > 0 ? spacing : 0)
            // The indicator sits after the last visible button, with its own gap in front of it.
            if candidate + spacing + indicatorWidth > available { break }
            used = candidate
            count += 1
        }
        return count
    }

    /// Unweighted buttons keep their own width; weighted ones split what is left in proportion.
    private func resolvedWidths(
        ideal: [CGFloat],
        visible: Int,
        available: CGFloat,
        indicatorWidth: CGFloat
    ) -> [CGFloat] {
        var widths = ideal
        let gaps = CGFloat(max(visible - 1, 0)) + (indicatorWidth > 0 ? 1 : 0)
        let weighted = (0..<visible).filter { weights.indices.contains($0) && weights[$0] != nil }
        guard !weighted.isEmpty else { return widths }

        let unweighted = (0..<visible).filter { !weighted.contains($0) }
        let fixed = unweighted.reduce(0) { $0 + ideal[$1] }
        let free = max(available - indicatorWidth - spacing * gaps - fixed, 0)
        let total = weighted.reduce(0) { $0 + (weights[$1] ?? 0) }
        guard total > 0 else { return widths }

        for index in weighted {
            widths[index] = free * (weights[index] ?? 0) / total
        }
        return widths
    }

    /// The pressed button grows by `expandedRatio` of its width; its neighbours pay for it equally,
    /// each capped at `compressionLimit`, and the growth is trimmed to whatever they can cover so
    /// the row's own width never changes.
    private func squeeze(_ widths: inout [CGFloat]) {
        widths = Self.squeezed(
            widths,
            pressedIndex: pressedIndex,
            expandedRatio: expandedRatio,
            compressionLimit: compressionLimit
        )
    }

    /// Split out from the layout so it can be tested on its own: it is the one piece of the group
    /// whose arithmetic has to hold for every count, ratio and press position.
    static func squeezed(
        _ widths: [CGFloat],
        pressedIndex: Int?,
        expandedRatio: CGFloat,
        compressionLimit: CGFloat
    ) -> [CGFloat] {
        var widths = widths
        guard let pressedIndex, widths.indices.contains(pressedIndex), widths.count > 1 else {
            return widths
        }
        let neighbours = CGFloat(widths.count - 1)
        let share = min(widths[pressedIndex] * expandedRatio / neighbours, compressionLimit)
        for index in widths.indices where index != pressedIndex {
            widths[index] -= share
        }
        widths[pressedIndex] += share * neighbours
        return widths
    }
}

/// The label both group flavours draw: an optional leading icon, then text that shrinks rather than
/// wraps once the layout has decided how much room it gets.
struct ButtonGroupLabel: View {
    let label: LocalizedStringKey
    var systemImage: String?
    let foreground: Color

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(foreground)
        // `ButtonDefaults.ContentPadding`.
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
