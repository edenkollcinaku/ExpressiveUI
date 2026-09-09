import SwiftUI

/// Material 3's carousel: a scrollable row whose items change size as they pass through it, so the
/// list reads as a single object with a focus rather than as a strip of cards.
///
/// Multi-browse — large items, then a medium, then a small, sized to fill the width exactly:
///
/// ```swift
/// ExpressiveCarousel(photos, preferredItemWidth: 186, itemSpacing: 8) { photo in
///     Image(photo.name).resizable().scaledToFill()
/// }
/// .frame(height: 205)
/// ```
///
/// Uncontained — every item the same width, flowing past the edge:
///
/// ```swift
/// ExpressiveCarousel(photos, itemWidth: 186, itemSpacing: 8) { photo in ... }
///     .frame(height: 205)
/// ```
///
/// The arrangement is not laid out item by item. The viewport owns a list of keylines — positions
/// with sizes attached — and an item takes whichever size belongs to wherever it has scrolled to,
/// masked to that size rather than scaled. Scrolling to either end interpolates through a series of
/// shifted arrangements so the first and last items can still reach full size at the edges.
/// See ``CarouselStrategy``.
///
/// Give it a height; it takes the width it is offered.
public struct ExpressiveCarousel<Data: RandomAccessCollection, Content: View>: View
where Data.Element: Identifiable {
    private enum Layout {
        case multiBrowse(preferredItemWidth: CGFloat)
        case uncontained(itemWidth: CGFloat)
    }

    private let data: Data
    private let layout: Layout
    private let itemSpacing: CGFloat
    private let contentPadding: CGFloat
    private let itemCornerRadius: CGFloat
    private let content: (Data.Element) -> Content

    @State private var scrollOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat?

    /// A multi-browse carousel. `preferredItemWidth` is a suggestion — the arrangement search bends
    /// it to whatever fills the container exactly.
    public init(
        _ data: Data,
        preferredItemWidth: CGFloat = 186,
        itemSpacing: CGFloat = 8,
        contentPadding: CGFloat = 0,
        itemCornerRadius: CGFloat = 28,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.layout = .multiBrowse(preferredItemWidth: preferredItemWidth)
        self.itemSpacing = itemSpacing
        self.contentPadding = contentPadding
        self.itemCornerRadius = itemCornerRadius
        self.content = content
    }

    /// An uncontained carousel: every item `itemWidth` wide, with the one at the edge deliberately
    /// cut off to show there is more.
    public init(
        _ data: Data,
        itemWidth: CGFloat,
        itemSpacing: CGFloat = 8,
        contentPadding: CGFloat = 0,
        itemCornerRadius: CGFloat = 28,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.layout = .uncontained(itemWidth: itemWidth)
        self.itemSpacing = itemSpacing
        self.contentPadding = contentPadding
        self.itemCornerRadius = itemCornerRadius
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let strategy = strategy(forWidth: proxy.size.width)
            let maxScrollOffset = strategy.maxScrollOffset(itemCount: data.count)
            let keylines = strategy.keylineList(
                scrollOffset: scrollOffset,
                maxScrollOffset: maxScrollOffset
            )

            ZStack(alignment: .topLeading) {
                if strategy.isValid {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
                        item(
                            element,
                            at: index,
                            strategy: strategy,
                            keylines: keylines,
                            height: proxy.size.height
                        )
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(scrollGesture(strategy: strategy, maxScrollOffset: maxScrollOffset))
            .clipped()
        }
    }

    /// Where an item sits and how much of it is visible, for the current scroll offset.
    private struct Placement {
        let maskSize: CGFloat
        let offset: CGFloat
        let zIndex: Double
    }

    private func item(
        _ element: Data.Element,
        at index: Int,
        strategy: CarouselStrategy,
        keylines: CarouselKeylineList,
        height: CGFloat
    ) -> some View {
        let placement = placement(at: index, strategy: strategy, keylines: keylines)

        return content(element)
            .frame(width: strategy.itemMainAxisSize, height: height)
            .mask(alignment: .center) {
                RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous)
                    .frame(width: placement.maskSize)
            }
            .offset(x: placement.offset)
            // The focal item draws in front, and neighbours fall behind it by distance.
            .zIndex(placement.zIndex)
    }

    /// The port of Compose's per-item layout: find the keylines this item's centre falls between,
    /// interpolate one from them, mask to that size, and translate onto it.
    private func placement(
        at index: Int,
        strategy: CarouselStrategy,
        keylines: CarouselKeylineList
    ) -> Placement {
        let itemSize = strategy.itemMainAxisSize
        let itemSizeWithSpacing = itemSize + strategy.itemSpacing

        // Where this item's centre sits in scroll space, where every item is focal-sized.
        let unadjustedCenter = CGFloat(index) * itemSizeWithSpacing + itemSize / 2 - scrollOffset

        let keylineBefore = keylines.keylineBefore(unadjustedCenter)
        let keylineAfter = keylines.keylineAfter(unadjustedCenter)
        let progress = progress(
            before: keylineBefore,
            after: keylineAfter,
            unadjustedOffset: unadjustedCenter
        )
        let interpolated = lerp(keylineBefore, keylineAfter, progress)
        let isOutOfKeylineBounds = keylineBefore == keylineAfter

        // Masking leaves gaps between items, so each one is pulled onto its keyline.
        var translation = interpolated.offset - unadjustedCenter
        if isOutOfKeylineBounds, interpolated.size != 0 {
            // Past the first or last keyline there is nothing to interpolate towards, so the item
            // keeps moving in proportion to how much of it is left.
            translation += (unadjustedCenter - interpolated.unadjustedOffset) / interpolated.size
        }

        let distance = abs(unadjustedCenter - keylines.firstFocal.unadjustedOffset)
        return Placement(
            maskSize: max(interpolated.size, 0),
            offset: CGFloat(index) * itemSizeWithSpacing - scrollOffset + translation + contentPadding,
            zIndex: Double(1 / (1 + distance))
        )
    }

    /// Drag, then snap to the keyline the nearest item should rest on.
    private func scrollGesture(strategy: CarouselStrategy, maxScrollOffset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = dragStartOffset ?? scrollOffset
                if dragStartOffset == nil { dragStartOffset = start }
                scrollOffset = min(max(start - value.translation.width, 0), maxScrollOffset)
            }
            .onEnded { value in
                let start = dragStartOffset ?? scrollOffset
                dragStartOffset = nil
                let projected = start - value.predictedEndTranslation.width
                let target = restingOffset(
                    near: projected,
                    strategy: strategy,
                    maxScrollOffset: maxScrollOffset
                )
                withAnimation(ExpressiveMotion.defaultSpatial) {
                    scrollOffset = target
                }
            }
    }

    /// The offset at which some item is sitting exactly on its keyline. Items near the ends snap to
    /// their own shift step, which is how the first and last items reach the container's edges.
    private func restingOffset(
        near offset: CGFloat,
        strategy: CarouselStrategy,
        maxScrollOffset: CGFloat
    ) -> CGFloat {
        let itemSizeWithSpacing = strategy.itemMainAxisSize + strategy.itemSpacing
        guard itemSizeWithSpacing > 0, data.count > 0 else { return 0 }

        let index = Int((offset / itemSizeWithSpacing).rounded())
        let clamped = min(max(index, 0), data.count - 1)
        let snapOffset = strategy.snapPositionOffset(itemIndex: clamped, itemCount: data.count)
        let resting = CGFloat(clamped) * itemSizeWithSpacing - snapOffset
        return min(max(resting, 0), maxScrollOffset)
    }

    private func strategy(forWidth width: CGFloat) -> CarouselStrategy {
        let available = max(width - contentPadding * 2, 0)
        let keylines: CarouselKeylineList
        switch layout {
        case let .multiBrowse(preferredItemWidth):
            keylines = multiBrowseKeylineList(
                carouselMainAxisSize: available,
                preferredItemSize: preferredItemWidth,
                itemSpacing: itemSpacing,
                itemCount: data.count
            )
        case let .uncontained(itemWidth):
            keylines = uncontainedKeylineList(
                carouselMainAxisSize: available,
                itemSize: itemWidth,
                itemSpacing: itemSpacing
            )
        }
        return CarouselStrategy(
            defaultKeylines: keylines,
            availableSpace: available,
            itemSpacing: itemSpacing,
            beforeContentPadding: contentPadding,
            afterContentPadding: contentPadding
        )
    }

    /// How far `unadjustedOffset` sits between two keylines.
    private func progress(
        before: CarouselKeyline,
        after: CarouselKeyline,
        unadjustedOffset: CGFloat
    ) -> CGFloat {
        if before == after { return 1 }
        let total = after.unadjustedOffset - before.unadjustedOffset
        guard total != 0 else { return 1 }
        return (unadjustedOffset - before.unadjustedOffset) / total
    }
}
