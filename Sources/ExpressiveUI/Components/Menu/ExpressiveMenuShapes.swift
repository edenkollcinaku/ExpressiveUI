import SwiftUI

/// The corner arithmetic behind a segmented dropdown menu.
///
/// A menu is a stack of groups, and a group is a stack of items, and *both* stacks round their ends
/// and square their middles — at different radii. Compose spells this out as eight cached shapes
/// (`defaultMenuLeadingGroupShapes`, `defaultMenuMiddleItemShapes`, and so on) picked by
/// `MenuDefaults.groupShape(index:count:)` and `itemShape(index:count:)`. It is the same rule twice,
/// so it lives here once and is the one piece of the menu worth testing on its own.
enum ExpressiveMenuShapes {
    /// `CornerValueLarge` / `Small` — a group's outer and inner corners.
    static let groupOuter: CGFloat = 16
    static let groupInner: CGFloat = 8

    /// `CornerValueMedium` / `ExtraSmall` — an item's outer and inner corners, and the corner a
    /// selected item rounds to on every side (`ItemSelectedShape`).
    static let itemOuter: CGFloat = 12
    static let itemInner: CGFloat = 4
    static let itemSelected: CGFloat = 12

    /// Top and bottom radii for the element at `index` of `count`, given the pair of radii its
    /// stack uses. A lone element is round on both ends; the ends of a run keep the outer radius
    /// where they face the outside and take the inner one where they face a sibling.
    static func corners(
        index: Int,
        count: Int,
        outer: CGFloat,
        inner: CGFloat
    ) -> (top: CGFloat, bottom: CGFloat) {
        guard count > 1 else { return (outer, outer) }
        switch index {
        case 0: return (outer, inner)
        case count - 1: return (inner, outer)
        default: return (inner, inner)
        }
    }

    static func group(index: Int, count: Int) -> (top: CGFloat, bottom: CGFloat) {
        corners(index: index, count: count, outer: groupOuter, inner: groupInner)
    }

    static func item(index: Int, count: Int, isSelected: Bool) -> (top: CGFloat, bottom: CGFloat) {
        // Selected, an item leaves the run and becomes its own rounded thing on all four corners.
        guard !isSelected else { return (itemSelected, itemSelected) }
        return corners(index: index, count: count, outer: itemOuter, inner: itemInner)
    }

    /// A rectangle with different radii top and bottom, which is what both rules produce.
    static func shape(_ corners: (top: CGFloat, bottom: CGFloat)) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: corners.top,
                bottomLeading: corners.bottom,
                bottomTrailing: corners.bottom,
                topTrailing: corners.top
            ),
            style: .continuous
        )
    }
}
