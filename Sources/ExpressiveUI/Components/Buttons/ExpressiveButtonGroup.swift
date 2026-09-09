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

    enum Kind {
        case clickable(() -> Void)
        case toggleable(Binding<Bool>)
    }

    let kind: Kind

    /// A button that runs `action` — Compose's `clickableItem`.
    public init(
        label: LocalizedStringKey,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.kind = .clickable(action)
    }

    /// A button that carries a checked state — Compose's `toggleableItem`.
    public init(
        label: LocalizedStringKey,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        isOn: Binding<Bool>
    ) {
        self.label = label
        self.systemImage = systemImage
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
/// The squeeze is the whole point of the component, and it is why the buttons share the width
/// equally rather than sizing to their labels: an exact expansion needs a width to expand *from*.
/// Compose sizes each child intrinsically and hands leftovers to a `weight`; that has no cheap
/// equivalent in SwiftUI, and equal shares are what a group of two or three actions wants anyway.
///
/// Not implemented from Compose's version: overflow into a dropdown menu when the buttons do not
/// fit, per-item weights, and the vertical arrangement.
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

    public init(expandedRatio: CGFloat = 0.15, items: [ExpressiveButtonGroupItem]) {
        self.expandedRatio = expandedRatio
        self.items = items
    }

    public var body: some View {
        GeometryReader { proxy in
            HStack(spacing: spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    button(item, at: index)
                        .frame(width: width(at: index, total: proxy.size.width))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.76), value: pressedIndex)
        }
        .frame(height: height)
        .opacity(isEnabled ? 1 : 0.38)
    }

    @ViewBuilder
    private func button(_ item: ExpressiveButtonGroupItem, at index: Int) -> some View {
        let checked: Bool = {
            if case let .toggleable(binding) = item.kind { return binding.wrappedValue }
            // A clickable item is always filled: Compose draws it with `Button`, which is the
            // filled one, not a tonal or outlined variant.
            return true
        }()

        Button {
            switch item.kind {
            case let .clickable(action):
                action()
            case let .toggleable(binding):
                binding.wrappedValue.toggle()
            }
        } label: {
            ButtonGroupLabel(
                label: item.label,
                systemImage: item.systemImage,
                foreground: checked ? colors.onPrimary : colors.onSurfaceVariant
            )
            .background(
                checked ? colors.primary : colors.surfaceContainer,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .opacity(item.isEnabled ? 1 : 0.38)
        .accessibilityAddTraits(isSelected(item) ? [.isButton, .isSelected] : .isButton)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if item.isEnabled, pressedIndex != index { pressedIndex = index } }
                .onEnded { _ in pressedIndex = nil }
        )
    }

    private func isSelected(_ item: ExpressiveButtonGroupItem) -> Bool {
        if case let .toggleable(binding) = item.kind { return binding.wrappedValue }
        return false
    }

    private func width(at index: Int, total: CGFloat) -> CGFloat {
        ExpressiveButtonGroupLayout.width(
            at: index,
            count: items.count,
            total: total,
            spacing: spacing,
            pressedIndex: pressedIndex,
            expandedRatio: expandedRatio
        )
    }
}

/// The share of the row each button gets, pressed or not. Split out because both group flavours
/// squeeze identically, and because it is the one piece of either that is worth testing directly.
enum ExpressiveButtonGroupLayout {
    static func width(
        at index: Int,
        count: Int,
        total: CGFloat,
        spacing: CGFloat,
        pressedIndex: Int?,
        expandedRatio: CGFloat
    ) -> CGFloat {
        let count = CGFloat(count)
        let base = (total - spacing * max(count - 1, 0)) / max(count, 1)
        guard let pressedIndex, count > 1 else { return base }
        let growth = base * expandedRatio
        return index == pressedIndex ? base + growth : base - growth / (count - 1)
    }
}

/// The label both group flavours draw: an optional leading icon, then text that shrinks rather than
/// wraps. Compose gives a long label to the overflow menu; with no menu here, a translation that
/// does not fit has to stay on one line rather than tear the container open around it.
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
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
