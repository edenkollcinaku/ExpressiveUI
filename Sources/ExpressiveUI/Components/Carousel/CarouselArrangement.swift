import CoreGraphics

/// A count of large, medium and small items, and the sizes they were adjusted to in order to fill
/// the carousel exactly.
///
/// A direct port of `androidx.compose.material3.carousel.Arrangement`. Carousel does not pick sizes
/// and hope they fit: it generates candidate arrangements, fits each one to the available space by
/// bending the small items first, then the medium ones, then — reluctantly — the large ones, and
/// keeps whichever ended up bending the large item least.
struct CarouselArrangement: Equatable {
    let priority: Int
    let smallSize: CGFloat
    let smallCount: Int
    let mediumSize: CGFloat
    let mediumCount: Int
    let largeSize: CGFloat
    let largeCount: Int

    /// A medium item may be stretched or squeezed by this much of its own size to spare the large
    /// items from being adjusted.
    private static let mediumItemFlexPercentage: CGFloat = 0.1

    var itemCount: Int { largeCount + mediumCount + smallCount }

    /// Sizes must descend for the arrangement to read as large-medium-small rather than as an
    /// accident.
    private var isValid: Bool {
        if largeCount > 0 && smallCount > 0 && mediumCount > 0 {
            return largeSize > mediumSize && mediumSize > smallSize
        } else if largeCount > 0 && smallCount > 0 {
            return largeSize > smallSize
        }
        return true
    }

    /// How far this arrangement had to move the large item away from its target, weighted by the
    /// order the arrangement was generated in. An invalid arrangement is infinitely expensive.
    func cost(targetLargeSize: CGFloat) -> CGFloat {
        guard isValid else { return .greatestFiniteMagnitude }
        return abs(targetLargeSize - largeSize) * CGFloat(priority)
    }

    /// Searches the candidate counts in priority order and returns the cheapest fit, stopping early
    /// on a cost of zero because the counts are generated best-first.
    static func findLowestCost(
        availableSpace: CGFloat,
        itemSpacing: CGFloat,
        targetSmallSize: CGFloat,
        minSmallSize: CGFloat,
        maxSmallSize: CGFloat,
        smallCounts: [Int],
        targetMediumSize: CGFloat,
        mediumCounts: [Int],
        targetLargeSize: CGFloat,
        largeCounts: [Int]
    ) -> CarouselArrangement? {
        var lowest: CarouselArrangement?
        var priority = 1

        for largeCount in largeCounts {
            for mediumCount in mediumCounts {
                for smallCount in smallCounts {
                    let arrangement = fit(
                        priority: priority,
                        availableSpace: availableSpace,
                        itemSpacing: itemSpacing,
                        smallCount: smallCount,
                        smallSize: targetSmallSize,
                        minSmallSize: minSmallSize,
                        maxSmallSize: maxSmallSize,
                        mediumCount: mediumCount,
                        mediumSize: targetMediumSize,
                        largeCount: largeCount,
                        largeSize: targetLargeSize
                    )
                    if lowest == nil
                        || arrangement.cost(targetLargeSize: targetLargeSize)
                            < lowest!.cost(targetLargeSize: targetLargeSize) {
                        lowest = arrangement
                        if arrangement.cost(targetLargeSize: targetLargeSize) == 0 {
                            return arrangement
                        }
                    }
                    priority += 1
                }
            }
        }
        return lowest
    }

    /// Fits one set of counts into the available space, adjusting the large item as little as it can
    /// get away with.
    private static func fit(
        priority: Int,
        availableSpace: CGFloat,
        itemSpacing: CGFloat,
        smallCount: Int,
        smallSize: CGFloat,
        minSmallSize: CGFloat,
        maxSmallSize: CGFloat,
        mediumCount: Int,
        mediumSize: CGFloat,
        largeCount: Int,
        largeSize: CGFloat
    ) -> CarouselArrangement {
        let totalItemCount = largeCount + mediumCount + smallCount
        let availableSpaceWithoutSpacing =
            availableSpace - CGFloat(totalItemCount - 1) * itemSpacing

        var arrangedSmallSize = min(max(smallSize, minSmallSize), maxSmallSize)
        var arrangedMediumSize = mediumSize
        var arrangedLargeSize = largeSize

        let totalSpaceTaken =
            arrangedLargeSize * CGFloat(largeCount)
            + arrangedMediumSize * CGFloat(mediumCount)
            + arrangedSmallSize * CGFloat(smallCount)
        let delta = availableSpaceWithoutSpacing - totalSpaceTaken

        // Small items give first, within their own min-max range.
        if smallCount > 0 && delta > 0 {
            arrangedSmallSize += min(delta / CGFloat(smallCount), maxSmallSize - arrangedSmallSize)
        } else if smallCount > 0 && delta < 0 {
            arrangedSmallSize += max(delta / CGFloat(smallCount), minSmallSize - arrangedSmallSize)
        }

        arrangedSmallSize = smallCount > 0 ? arrangedSmallSize : 0
        arrangedLargeSize = calculateLargeSize(
            availableSpace: availableSpaceWithoutSpacing,
            smallCount: smallCount,
            smallSize: arrangedSmallSize,
            mediumCount: mediumCount,
            largeCount: largeCount
        )
        arrangedMediumSize = (arrangedLargeSize + arrangedSmallSize) / 2

        // If the large item still had to move, buy some of that back out of the medium item's flex.
        if mediumCount > 0 && arrangedLargeSize != largeSize {
            let targetAdjustment = (largeSize - arrangedLargeSize) * CGFloat(largeCount)
            let availableMediumFlex =
                arrangedMediumSize * mediumItemFlexPercentage * CGFloat(mediumCount)
            let distribute = min(abs(targetAdjustment), availableMediumFlex)
            if targetAdjustment > 0 {
                arrangedMediumSize -= distribute / CGFloat(mediumCount)
                arrangedLargeSize += distribute / CGFloat(largeCount)
            } else {
                arrangedMediumSize += distribute / CGFloat(mediumCount)
                arrangedLargeSize -= distribute / CGFloat(largeCount)
            }
        }

        return CarouselArrangement(
            priority: priority,
            smallSize: arrangedSmallSize,
            smallCount: smallCount,
            mediumSize: arrangedMediumSize,
            mediumCount: mediumCount,
            largeSize: arrangedLargeSize,
            largeCount: largeCount
        )
    }

    /// Solves `availableSpace = large*largeCount + ((large + small) / 2)*mediumCount +
    /// small*smallCount` for the large size.
    private static func calculateLargeSize(
        availableSpace: CGFloat,
        smallCount: Int,
        smallSize: CGFloat,
        mediumCount: Int,
        largeCount: Int
    ) -> CGFloat {
        let mediumHalves = CGFloat(mediumCount) / 2
        return (availableSpace - (CGFloat(smallCount) + mediumHalves) * smallSize)
            / (CGFloat(largeCount) + mediumHalves)
    }
}
