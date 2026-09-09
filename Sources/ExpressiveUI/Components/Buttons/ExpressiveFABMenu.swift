import SwiftUI

/// One entry in an ``ExpressiveFABMenu``.
///
/// The icon is an SF Symbol name so a call site needs no asset catalogue; the label is a
/// `LocalizedStringKey`, which means a literal at the call site is looked up in the app's
/// `Localizable.strings` for free.
public struct ExpressiveFABMenuItem: Identifiable {
    public let id = UUID()
    public var systemImage: String
    public var label: LocalizedStringKey
    public var action: () -> Void

    public init(systemImage: String, label: LocalizedStringKey, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }
}

/// Material 3's FAB menu: a floating action button that opens into a column of labelled actions.
///
/// It is one view rather than a FAB plus a menu you assemble, because the two halves share the
/// state that makes it a menu — the FAB's icon rotates into a close affordance, the items stagger
/// out from it, and choosing one closes the menu before it acts.
///
/// ```swift
/// ExpressiveFABMenu(
///     items: [
///         .init(systemImage: "square.and.pencil", label: "Note") { compose(.note) },
///         .init(systemImage: "camera", label: "Photo") { compose(.photo) }
///     ]
/// )
/// ```
///
/// Place it in an overlay pinned to the bottom-trailing corner — it sizes itself to the FAB when
/// closed and grows upward, so it never needs the space its open state occupies.
///
/// Pass `isOpen` when something outside has to close it: a tab change, a sheet, a back gesture.
public struct ExpressiveFABMenu: View {
    @Environment(\.expressiveColors) private var colors

    /// `FabPrimaryTokens.ContainerWidth` / `ContainerHeight`, and the corner it rests at.
    private let fabSize: CGFloat = 56
    private let fabCorner: CGFloat = 16
    /// `FabPrimaryTokens.IconSize`.
    private let iconSize: CGFloat = 24

    /// The items are 56pt capsules, the same height as the FAB they come out of.
    private let itemHeight: CGFloat = 56

    /// How far apart each item starts moving. Small enough to read as one gesture rather than a
    /// queue, large enough that the eye can follow it down to the FAB.
    private let stagger: Double = 0.065

    private let systemImage: String
    private let openedAccessibilityLabel: LocalizedStringKey
    private let closedAccessibilityLabel: LocalizedStringKey
    private let items: [ExpressiveFABMenuItem]

    /// Used when the call site does not supply a binding.
    @State private var localIsOpen = false
    private let externalIsOpen: Binding<Bool>?

    public init(
        systemImage: String = "plus",
        accessibilityLabel: LocalizedStringKey = "Open menu",
        closeAccessibilityLabel: LocalizedStringKey = "Close menu",
        items: [ExpressiveFABMenuItem]
    ) {
        self.systemImage = systemImage
        self.closedAccessibilityLabel = accessibilityLabel
        self.openedAccessibilityLabel = closeAccessibilityLabel
        self.items = items
        self.externalIsOpen = nil
    }

    /// The same menu, with its open state owned by the call site.
    public init(
        isOpen: Binding<Bool>,
        systemImage: String = "plus",
        accessibilityLabel: LocalizedStringKey = "Open menu",
        closeAccessibilityLabel: LocalizedStringKey = "Close menu",
        items: [ExpressiveFABMenuItem]
    ) {
        self.systemImage = systemImage
        self.closedAccessibilityLabel = accessibilityLabel
        self.openedAccessibilityLabel = closeAccessibilityLabel
        self.items = items
        self.externalIsOpen = isOpen
    }

    private var isOpen: Binding<Bool> {
        externalIsOpen ?? $localIsOpen
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            VStack(alignment: .trailing, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    MenuItem(
                        item: item,
                        colors: colors,
                        height: itemHeight,
                        iconSize: iconSize,
                        isOpen: isOpen.wrappedValue,
                        // The item nearest the FAB leads on the way out and trails on the way back,
                        // so the column reads as unfolding from the button rather than arriving as
                        // a block.
                        delay: delay(for: index)
                    ) {
                        close()
                        item.action()
                    }
                }
            }

            fab
        }
    }

    private var fab: some View {
        Button {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
                isOpen.wrappedValue.toggle()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .medium))
                // Open, the icon is a close affordance and the container a circle: the same 45°
                // that turns a plus into a cross reads as a rotation on any symbol.
                .rotationEffect(.degrees(isOpen.wrappedValue ? 45 : 0))
                .foregroundStyle(colors.onPrimary)
                .frame(width: fabSize, height: fabSize)
                .background(
                    colors.primary,
                    in: RoundedRectangle(
                        cornerRadius: isOpen.wrappedValue ? fabSize / 2 : fabCorner,
                        style: .continuous
                    )
                )
                .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
        }
        .buttonStyle(PressableScale())
        .accessibilityLabel(isOpen.wrappedValue ? openedAccessibilityLabel : closedAccessibilityLabel)
    }

    private func delay(for index: Int) -> Double {
        let fromBottom = Double(items.count - 1 - index)
        let total = Double(max(items.count - 1, 0)) * stagger
        return isOpen.wrappedValue ? fromBottom * stagger : total - fromBottom * stagger
    }

    private func close() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            isOpen.wrappedValue = false
        }
    }

    private struct MenuItem: View {
        let item: ExpressiveFABMenuItem
        let colors: ExpressiveColors
        let height: CGFloat
        let iconSize: CGFloat
        let isOpen: Bool
        let delay: Double
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: iconSize * 0.9, weight: .semibold))
                        .frame(width: iconSize, height: iconSize)

                    Text(item.label)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(colors.onPrimaryContainer)
                .padding(.horizontal, 24)
                .frame(minWidth: height, minHeight: height)
                .background(colors.primaryContainer, in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
            }
            .buttonStyle(PressableScale())
            // Without this the row would stretch to whatever the overlay gives it; an item is as
            // wide as its label and no wider.
            .fixedSize(horizontal: true, vertical: false)
            // Closed, the item collapses into the FAB's edge rather than fading in place. Scaling to
            // exactly zero would take the row out of layout, so it keeps a hair of width.
            .scaleEffect(x: isOpen ? 1 : 0.01, y: 1, anchor: .trailing)
            .opacity(isOpen ? 1 : 0)
            .allowsHitTesting(isOpen)
            .accessibilityHidden(!isOpen)
            .animation(.spring(response: 0.38, dampingFraction: 0.78).delay(delay), value: isOpen)
        }
    }

    /// Material's press response for a raised container: it dips, it does not ripple.
    private struct PressableScale: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .opacity(configuration.isPressed ? 0.88 : 1)
                .animation(.spring(response: 0.24, dampingFraction: 0.74), value: configuration.isPressed)
        }
    }
}
