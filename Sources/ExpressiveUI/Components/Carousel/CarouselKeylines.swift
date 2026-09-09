import CoreGraphics
import Foundation

/// The sizes Material allows a small item to take, and the sliver of an item left visible past the
/// container's edge. `CarouselDefaults.MinSmallItemSize`, `MaxSmallItemSize`, `AnchorSize`.
enum CarouselDefaults {
    static let minSmallItemSize: CGFloat = 40
    static let maxSmallItemSize: CGFloat = 56
    static let anchorSize: CGFloat = 10
    /// Past this fraction of the large size, a medium item is too similar to a large one to produce
    /// any sense of motion as items pass between them.
    static let mediumLargeItemDiffThreshold: CGFloat = 0.85
}

/// The multi-browse arrangement: large items, then one medium, then one small, all left-aligned.
///
/// A port of `multiBrowseKeylineList`. The sizes are not chosen — they are searched for. A small
/// item wants to be a third of a large one, a medium item wants to be halfway between the two, and
/// the arrangement that fills the viewport while bending the large item least is the one that wins.
func multiBrowseKeylineList(
    carouselMainAxisSize: CGFloat,
    preferredItemSize: CGFloat,
    itemSpacing: CGFloat,
    itemCount: Int,
    minSmallItemSize: CGFloat = CarouselDefaults.minSmallItemSize,
    maxSmallItemSize: CGFloat = CarouselDefaults.maxSmallItemSize
) -> CarouselKeylineList {
    guard carouselMainAxisSize != 0, preferredItemSize != 0 else { return .empty }

    var smallCounts: [Int] = [1]
    let mediumCounts: [Int] = [1, 0]

    let targetLargeSize = min(preferredItemSize, carouselMainAxisSize)
    let targetSmallSize = min(max(targetLargeSize / 3, minSmallItemSize), maxSmallItemSize)
    let targetMediumSize = (targetLargeSize + targetSmallSize) / 2

    if carouselMainAxisSize < minSmallItemSize * 2 {
        // Too narrow to hold a large item and a small one, so allow arrangements with no small item.
        smallCounts = [0]
    }

    let minAvailableLargeSpace =
        carouselMainAxisSize
        - targetMediumSize * CGFloat(mediumCounts.max() ?? 0)
        - maxSmallItemSize * CGFloat(smallCounts.max() ?? 0)
    let minLargeCount = max(1, Int(floor(minAvailableLargeSpace / targetLargeSize)))
    let maxLargeCount = Int(ceil(carouselMainAxisSize / targetLargeSize))
    let largeCounts = (0...(maxLargeCount - minLargeCount)).map { maxLargeCount - $0 }

    var arrangement = CarouselArrangement.findLowestCost(
        availableSpace: carouselMainAxisSize,
        itemSpacing: itemSpacing,
        targetSmallSize: targetSmallSize,
        minSmallSize: minSmallItemSize,
        maxSmallSize: maxSmallItemSize,
        smallCounts: smallCounts,
        targetMediumSize: targetMediumSize,
        mediumCounts: mediumCounts,
        targetLargeSize: targetLargeSize,
        largeCounts: largeCounts
    )

    // A carousel with fewer items than keylines would leave gaps, so drop keylines until they
    // match: small ones first, then medium, never large — large items are already unmasked.
    if let found = arrangement, found.itemCount > itemCount {
        var keylineSurplus = found.itemCount - itemCount
        var smallCount = found.smallCount
        var mediumCount = found.mediumCount
        while keylineSurplus > 0 {
            if smallCount > 0 {
                smallCount -= 1
            } else if mediumCount > 1 {
                // Keep one medium, or the large items fill the carousel outright.
                mediumCount -= 1
            }
            keylineSurplus -= 1
        }
        arrangement = CarouselArrangement.findLowestCost(
            availableSpace: carouselMainAxisSize,
            itemSpacing: itemSpacing,
            targetSmallSize: targetSmallSize,
            minSmallSize: minSmallItemSize,
            maxSmallSize: maxSmallItemSize,
            smallCounts: [smallCount],
            targetMediumSize: targetMediumSize,
            mediumCounts: [mediumCount],
            targetLargeSize: targetLargeSize,
            largeCounts: largeCounts
        )
    }

    guard let arrangement else { return .empty }

    return createLeftAlignedKeylineList(
        carouselMainAxisSize: carouselMainAxisSize,
        itemSpacing: itemSpacing,
        leftAnchorSize: CarouselDefaults.anchorSize,
        rightAnchorSize: CarouselDefaults.anchorSize,
        arrangement: arrangement
    )
}

/// The uncontained arrangement: as many same-size items as fit, and one deliberately cut-off item
/// in whatever space is left. A port of `uncontainedKeylineList`.
func uncontainedKeylineList(
    carouselMainAxisSize: CGFloat,
    itemSize: CGFloat,
    itemSpacing: CGFloat
) -> CarouselKeylineList {
    guard carouselMainAxisSize != 0, itemSize != 0 else { return .empty }

    let largeItemSize = min(itemSize + itemSpacing, carouselMainAxisSize)
    let largeCount = max(1, Int(floor(carouselMainAxisSize / largeItemSize)))
    let remainingSpace = carouselMainAxisSize - CGFloat(largeCount) * largeItemSize
    let mediumCount = remainingSpace > 0 ? 1 : 0

    let mediumItemSize = calculateMediumChildSize(
        minimumMediumSize: CarouselDefaults.anchorSize,
        largeItemSize: largeItemSize,
        remainingSpace: remainingSpace
    )
    let arrangement = CarouselArrangement(
        priority: 0,
        smallSize: 0,
        smallCount: 0,
        mediumSize: mediumItemSize,
        mediumCount: mediumCount,
        largeSize: largeItemSize,
        largeCount: largeCount
    )

    let extraSmallSize = min(CarouselDefaults.anchorSize, itemSize)
    // Half the cut-off item, so motion at the leading edge resembles motion at the trailing one.
    let leftAnchorSize = max(extraSmallSize, mediumItemSize * 0.5)

    return createLeftAlignedKeylineList(
        carouselMainAxisSize: carouselMainAxisSize,
        itemSpacing: itemSpacing,
        leftAnchorSize: leftAnchorSize,
        rightAnchorSize: CarouselDefaults.anchorSize,
        arrangement: arrangement
    )
}

/// Anchor, large items, medium items, small items, anchor — the order they appear in the viewport.
func createLeftAlignedKeylineList(
    carouselMainAxisSize: CGFloat,
    itemSpacing: CGFloat,
    leftAnchorSize: CGFloat,
    rightAnchorSize: CGFloat,
    arrangement: CarouselArrangement
) -> CarouselKeylineList {
    carouselKeylineList(
        carouselMainAxisSize: carouselMainAxisSize,
        itemSpacing: itemSpacing,
        alignment: .start
    ) { builder in
        builder.add(size: leftAnchorSize, isAnchor: true)
        for _ in 0..<arrangement.largeCount { builder.add(size: arrangement.largeSize) }
        for _ in 0..<arrangement.mediumCount { builder.add(size: arrangement.mediumSize) }
        for _ in 0..<arrangement.smallCount { builder.add(size: arrangement.smallSize) }
        builder.add(size: rightAnchorSize, isAnchor: true)
    }
}

/// Sizes the cut-off item so a third of it is hidden — and, if that leaves it too close to the large
/// size to read as different, backs off to a fifth.
private func calculateMediumChildSize(
    minimumMediumSize: CGFloat,
    largeItemSize: CGFloat,
    remainingSpace: CGFloat
) -> CGFloat {
    var mediumItemSize = max(remainingSpace * 1.5, minimumMediumSize)
    let largeItemThreshold = largeItemSize * CarouselDefaults.mediumLargeItemDiffThreshold
    if mediumItemSize > largeItemThreshold {
        let sizeWithFifthCutOff = remainingSpace * 1.2
        mediumItemSize = min(max(largeItemThreshold, sizeWithFifthCutOff), largeItemSize)
    }
    return mediumItemSize
}
