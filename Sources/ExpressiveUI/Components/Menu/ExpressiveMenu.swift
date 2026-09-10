import SwiftUI

/// One row of a menu.
///
/// Compose has three kinds — `DropdownMenuItem`, `CheckableDropdownMenuItem` and
/// `SelectableDropdownMenuItem` — and so does this, chosen by the initialiser you call. A checkable
/// item owns a binding and swaps its leading icon when checked; a selectable one is told whether it
/// is the chosen one and still runs an action.
public struct ExpressiveMenuItem: Identifiable {
    public let id = UUID()
    public var label: LocalizedStringKey
    public var systemImage: String?
    /// The icon that replaces `systemImage` while the item is checked or selected —
    /// `checkedLeadingIcon`. Defaults to a checkmark, which is what the samples use for an item
    /// with no icon of its own.
    public var checkedSystemImage: String?
    /// A second line under the label, in `bodyMedium`.
    public var supportingText: LocalizedStringKey?
    /// Text at the trailing edge — a shortcut, a count, a state.
    public var trailingText: LocalizedStringKey?
    public var isEnabled: Bool

    enum Kind {
        case action(() -> Void)
        case checkable(Binding<Bool>)
        case selectable(isSelected: Bool, action: () -> Void)
    }

    let kind: Kind

    /// A plain item — Compose's `DropdownMenuItem`.
    public init(
        _ label: LocalizedStringKey,
        systemImage: String? = nil,
        supportingText: LocalizedStringKey? = nil,
        trailingText: LocalizedStringKey? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.checkedSystemImage = nil
        self.supportingText = supportingText
        self.trailingText = trailingText
        self.isEnabled = isEnabled
        self.kind = .action(action)
    }

    /// An item that carries a checked state — `CheckableDropdownMenuItem`.
    public init(
        _ label: LocalizedStringKey,
        systemImage: String? = nil,
        checkedSystemImage: String? = nil,
        supportingText: LocalizedStringKey? = nil,
        trailingText: LocalizedStringKey? = nil,
        isEnabled: Bool = true,
        isOn: Binding<Bool>
    ) {
        self.label = label
        self.systemImage = systemImage
        self.checkedSystemImage = checkedSystemImage
        self.supportingText = supportingText
        self.trailingText = trailingText
        self.isEnabled = isEnabled
        self.kind = .checkable(isOn)
    }

    /// An item that is one choice out of several — `SelectableDropdownMenuItem`.
    public init(
        _ label: LocalizedStringKey,
        systemImage: String? = nil,
        checkedSystemImage: String? = nil,
        supportingText: LocalizedStringKey? = nil,
        trailingText: LocalizedStringKey? = nil,
        isEnabled: Bool = true,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.checkedSystemImage = checkedSystemImage
        self.supportingText = supportingText
        self.trailingText = trailingText
        self.isEnabled = isEnabled
        self.kind = .selectable(isSelected: isSelected, action: action)
    }

    /// Whether choosing this item should close the menu. An action is a decision and the menu has
    /// served its purpose; a checkable item is a setting, and closing the menu after every tick
    /// would make setting two of them a chore. Compose leaves this to the call site's `onClick`;
    /// here the presentation does it, so the call site's action stays about the action.
    var dismissesOnActivation: Bool {
        switch kind {
        case .action, .selectable: return true
        case .checkable: return false
        }
    }

    var isChecked: Bool {
        switch kind {
        case .action: return false
        case let .checkable(binding): return binding.wrappedValue
        case let .selectable(isSelected, _): return isSelected
        }
    }

    func activate() {
        switch kind {
        case let .action(action): action()
        case let .checkable(binding): binding.wrappedValue.toggle()
        case let .selectable(_, action): action()
        }
    }
}

/// A run of related items inside a menu, with an optional label above them — Compose's
/// `DropdownMenuGroup`.
public struct ExpressiveMenuGroup: Identifiable {
    public let id = UUID()
    public var label: LocalizedStringKey?
    public var items: [ExpressiveMenuItem]

    public init(_ label: LocalizedStringKey? = nil, items: [ExpressiveMenuItem]) {
        self.label = label
        self.items = items
    }
}

/// Material 3's segmented dropdown menu: groups of items, each group a card, each item a chip
/// inside it, with the corners of both runs rounding at the ends and squaring in the middle.
///
/// ```swift
/// ExpressiveMenu(groups: [
///     .init("Modification", items: [
///         .init("Edit", systemImage: "pencil", supportingText: "Edit mode", isOn: $editing),
///         .init("Settings", systemImage: "gearshape") { openSettings() }
///     ]),
///     .init("Navigation", items: [
///         .init("Home", systemImage: "house") { goHome() }
///     ])
/// ])
/// ```
///
/// This is the menu's surface and contents. Presenting it is a separate question — see
/// ``SwiftUI/View/expressiveMenu(isPresented:groups:)`` for the popover that ships with it, or put
/// this view in a sheet, a panel, or an inline disclosure of your own.
public struct ExpressiveMenu: View {
    @Environment(\.expressiveColors) private var colors

    /// `SegmentedMenuTokens.SegmentedGap` — 2, between items and between groups alike.
    private let gap: CGFloat = 2
    /// `SegmentedMenuTokens.GroupPadding`.
    private let groupPadding: CGFloat = 4

    private let groups: [ExpressiveMenuGroup]
    private let elevation: ExpressiveElevation

    /// - Parameter elevation: how far each group floats. Flat by default: two cards a couple of
    ///   points apart each cast a shadow into the gap between them, and the seam — which is the
    ///   thing that makes a segmented menu read as segmented — muddies. The token says
    ///   `SegmentedMenuTokens.ContainerElevation`, level 2, so pass `.level2` for the spec's own
    ///   answer, or when the menu has to separate itself from busy content behind it.
    public init(groups: [ExpressiveMenuGroup], elevation: ExpressiveElevation = .level0) {
        self.groups = groups
        self.elevation = elevation
    }

    public var body: some View {
        VStack(spacing: gap) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                GroupView(
                    group: group,
                    corners: ExpressiveMenuShapes.group(index: index, count: groups.count),
                    padding: groupPadding,
                    gap: gap,
                    elevation: elevation
                )
            }
        }
        // `DropdownMenuItemDefaultMinWidth` / `MaxWidth`.
        .frame(minWidth: 112, maxWidth: 280, alignment: .leading)
    }

    // The menu itself paints nothing. `DropdownMenuPopup` is a positioned column and each group is
    // its own surface, which is the whole point of a *segmented* menu: the 2pt gaps are gaps, and
    // whatever is behind the menu shows through them.

    private struct GroupView: View {
        @Environment(\.expressiveColors) private var colors

        let group: ExpressiveMenuGroup
        let corners: (top: CGFloat, bottom: CGFloat)
        let padding: CGFloat
        let gap: CGFloat
        let elevation: ExpressiveElevation

        var body: some View {
            VStack(alignment: .leading, spacing: gap) {
                if let label = group.label {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(colors.onSurfaceVariant)
                        // `DropdownMenuGroupLabelHorizontalPadding`.
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                        .frame(minHeight: 32, alignment: .leading)

                    // `HorizontalDividerPadding`.
                    Rectangle()
                        .fill(colors.outlineVariant)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                }

                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    ItemView(
                        item: item,
                        corners: ExpressiveMenuShapes.item(
                            index: index,
                            count: group.items.count,
                            isSelected: item.isChecked
                        )
                    )
                }
            }
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .background(colors.surfaceContainerLow, in: ExpressiveMenuShapes.shape(corners))
            // Each group carries its own shadow, at `SegmentedMenuTokens.ContainerElevation`.
            .expressiveElevation(elevation)
        }
    }

    private struct ItemView: View {
        @Environment(\.expressiveColors) private var colors
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.expressiveMenuDismiss) private var dismiss

        let item: ExpressiveMenuItem
        let corners: (top: CGFloat, bottom: CGFloat)

        /// `ItemLeadingIconSize` / `ItemTrailingIconSize`, and the 48pt row Material lays items on.
        private let iconSize: CGFloat = 20
        private let minHeight: CGFloat = 48

        private var enabled: Bool { isEnabled && item.isEnabled }
        private var checked: Bool { item.isChecked }

        var body: some View {
            Button {
                item.activate()
                if item.dismissesOnActivation { dismiss() }
            } label: {
                HStack(spacing: 8) {
                    if let name = leadingIcon {
                        Image(systemName: name)
                            .font(.system(size: iconSize * 0.8))
                            .frame(width: iconSize, height: iconSize)
                            .foregroundStyle(iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.system(size: 16))
                        if let supportingText = item.supportingText {
                            Text(supportingText)
                                .font(.system(size: 14))
                                .foregroundStyle(secondaryColor)
                        }
                    }

                    Spacer(minLength: 0)

                    if let trailingText = item.trailingText {
                        Text(trailingText)
                            .font(.system(size: 11))
                            .foregroundStyle(secondaryColor)
                    }
                }
                .foregroundStyle(labelColor)
                // `DropdownMenuSelectableItemContentPadding`.
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
                .background(container, in: ExpressiveMenuShapes.shape(corners))
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .accessibilityAddTraits(checked ? [.isButton, .isSelected] : .isButton)
            .animation(ExpressiveMotion.fastEffects, value: checked)
        }

        /// Checked, the item swaps its icon for the filled counterpart the call site gave it, or for
        /// a checkmark when it has none — which is how an item with no icon still shows its state.
        private var leadingIcon: String? {
            guard checked else { return item.systemImage }
            return item.checkedSystemImage ?? item.systemImage ?? "checkmark"
        }

        private var container: Color {
            checked && enabled ? colors.tertiaryContainer : .clear
        }

        private var labelColor: Color {
            guard enabled else { return colors.onSurface.opacity(0.38) }
            return checked ? colors.onTertiaryContainer : colors.onSurface
        }

        private var iconColor: Color {
            guard enabled else { return colors.onSurface.opacity(0.38) }
            return checked ? colors.onTertiaryContainer : colors.onSurfaceVariant
        }

        private var secondaryColor: Color {
            guard enabled else { return colors.onSurface.opacity(0.38) }
            return checked ? colors.onTertiaryContainer : colors.onSurfaceVariant
        }
    }
}

/// How an item asks to be dismissed. A menu presented by ``SwiftUI/View/expressiveMenu(isPresented:arrowEdge:groups:)``
/// fills this in; a menu you present yourself inherits the default, which does nothing — an inline
/// menu has nothing to dismiss.
struct ExpressiveMenuDismissKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var expressiveMenuDismiss: () -> Void {
        get { self[ExpressiveMenuDismissKey.self] }
        set { self[ExpressiveMenuDismissKey.self] = newValue }
    }
}
