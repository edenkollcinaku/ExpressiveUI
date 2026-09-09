import CoreGraphics
import Foundation

/// The keyline list for any scroll offset, including the shifted arrangements used at either end of
/// the list. A port of `androidx.compose.material3.carousel.Strategy`.
///
/// The default arrangement puts the focal range where the design wants it — for multi-browse, at the
/// start, with the medium and small items trailing. That alone would mean the first item can never
/// be large at the start of the list, and the last item can never be large at the end. So the
/// strategy precomputes a *step* per keyline: each one moves a single keyline from one side of the
/// focal range to the other, walking the focal range to the container's edge one item at a time.
/// Scrolling then interpolates between whichever two steps the offset falls between.
struct CarouselStrategy: Equatable {
    let defaultKeylines: CarouselKeylineList
    let startKeylineSteps: [CarouselKeylineList]
    let endKeylineSteps: [CarouselKeylineList]
    let availableSpace: CGFloat
    let itemSpacing: CGFloat
    let beforeContentPadding: CGFloat
    let afterContentPadding: CGFloat

    let minItemSize: CGFloat
    let maxItemSize: CGFloat

    /// Scroll distances covered by the two step lists, and the 0-1 points at which each step takes
    /// over from the one before it.
    private let startShiftDistance: CGFloat
    private let endShiftDistance: CGFloat
    private let startShiftPoints: [CGFloat]
    private let endShiftPoints: [CGFloat]

    /// The size of a fully unmasked item — the space scroll offsets are measured in.
    var itemMainAxisSize: CGFloat { defaultKeylines.isEmpty ? 0 : defaultKeylines.firstFocal.size }

    var isValid: Bool { !defaultKeylines.isEmpty && availableSpace != 0 && itemMainAxisSize != 0 }

    static let empty = CarouselStrategy(
        defaultKeylines: .empty,
        availableSpace: 0,
        itemSpacing: 0,
        beforeContentPadding: 0,
        afterContentPadding: 0
    )

    init(
        defaultKeylines: CarouselKeylineList,
        availableSpace: CGFloat,
        itemSpacing: CGFloat,
        beforeContentPadding: CGFloat,
        afterContentPadding: CGFloat
    ) {
        let startSteps = Self.startKeylineSteps(
            defaultKeylines: defaultKeylines,
            carouselMainAxisSize: availableSpace,
            itemSpacing: itemSpacing,
            beforeContentPadding: beforeContentPadding
        )
        let endSteps = Self.endKeylineSteps(
            defaultKeylines: defaultKeylines,
            carouselMainAxisSize: availableSpace,
            itemSpacing: itemSpacing,
            afterContentPadding: afterContentPadding
        )

        self.defaultKeylines = defaultKeylines
        self.startKeylineSteps = startSteps
        self.endKeylineSteps = endSteps
        self.availableSpace = availableSpace
        self.itemSpacing = itemSpacing
        self.beforeContentPadding = beforeContentPadding
        self.afterContentPadding = afterContentPadding

        var min = defaultKeylines.isEmpty ? 0 : defaultKeylines.minSize
        var max = defaultKeylines.isEmpty ? 0 : defaultKeylines.maxSize
        for step in startSteps + endSteps {
            if step.minSize < min { min = step.minSize }
            if step.maxSize > max { max = step.maxSize }
        }
        self.minItemSize = min
        self.maxItemSize = max

        self.startShiftDistance = Self.startShiftDistance(
            startKeylineSteps: startSteps,
            beforeContentPadding: beforeContentPadding
        )
        self.endShiftDistance = Self.endShiftDistance(
            endKeylineSteps: endSteps,
            afterContentPadding: afterContentPadding
        )
        self.startShiftPoints = Self.stepInterpolationPoints(
            totalShiftDistance: startShiftDistance,
            steps: startSteps,
            isShiftingLeft: true
        )
        self.endShiftPoints = Self.stepInterpolationPoints(
            totalShiftDistance: endShiftDistance,
            steps: endSteps,
            isShiftingLeft: false
        )
    }

    /// The keylines to use at `scrollOffset`: the default arrangement in the middle of the list, and
    /// an interpolation through the shift steps within one shift distance of either end.
    func keylineList(
        scrollOffset: CGFloat,
        maxScrollOffset: CGFloat,
        roundToNearestStep: Bool = false
    ) -> CarouselKeylineList {
        guard isValid else { return defaultKeylines }

        let positiveScrollOffset = max(0, scrollOffset)
        let startShiftOffset = startShiftDistance
        let endShiftOffset = max(0, maxScrollOffset - endShiftDistance)

        if positiveScrollOffset >= startShiftOffset && positiveScrollOffset <= endShiftOffset {
            return defaultKeylines
        }

        var interpolation = lerp(
            outputMin: 1,
            outputMax: 0,
            inputMin: 0,
            inputMax: startShiftOffset,
            value: positiveScrollOffset
        )
        var shiftPoints = startShiftPoints
        var steps = startKeylineSteps

        if positiveScrollOffset > endShiftOffset {
            interpolation = lerp(
                outputMin: 0,
                outputMax: 1,
                inputMin: endShiftOffset,
                inputMax: maxScrollOffset,
                value: positiveScrollOffset
            )
            shiftPoints = endShiftPoints
            steps = endKeylineSteps

            // When end shifting starts at offset zero, the list is short enough that we interpolate
            // straight from the last start step to the last end step without passing through the
            // default arrangement at all.
            if endShiftOffset < 0.01, startKeylineSteps.count == 2, endKeylineSteps.count == 2,
               let lastStart = startKeylineSteps.last, let lastEnd = endKeylineSteps.last {
                steps = [lastStart, lastEnd]
            }
        }

        guard steps.count > 1 else { return steps.first ?? defaultKeylines }

        var fromStepIndex = 0
        var toStepIndex = 0
        var steppedInterpolation: CGFloat = 0
        var lowerBounds = shiftPoints[0]
        for index in 1..<steps.count {
            let upperBounds = shiftPoints[index]
            if interpolation <= upperBounds {
                fromStepIndex = index - 1
                toStepIndex = index
                steppedInterpolation = lerp(
                    outputMin: 0,
                    outputMax: 1,
                    inputMin: lowerBounds,
                    inputMax: upperBounds,
                    value: interpolation
                )
                break
            }
            lowerBounds = upperBounds
        }

        if roundToNearestStep {
            return steps[steppedInterpolation.rounded() == 0 ? fromStepIndex : toStepIndex]
        }

        return lerp(steps[fromStepIndex], steps[toStepIndex], steppedInterpolation)
    }

    /// Where an item must come to rest to sit on a keyline. Items near either end snap to their own
    /// shift step rather than to the default focal keyline, which is what lets the first and last
    /// items reach the edges.
    func snapPositionOffset(itemIndex: Int, itemCount: Int) -> CGFloat {
        guard isValid else { return 0 }

        var offset = (defaultKeylines.firstFocal.unadjustedOffset - itemMainAxisSize / 2).rounded()

        if itemIndex <= startKeylineSteps.count - 1 {
            // Step lists run from the default arrangement outwards, so index from the end.
            let stepIndex = min(max(startKeylineSteps.count - 1 - itemIndex, 0), startKeylineSteps.count - 1)
            let startKeylines = startKeylineSteps[stepIndex]
            offset = (startKeylines.firstFocal.unadjustedOffset - itemMainAxisSize / 2).rounded()
        }

        let lastItemIndex = itemCount - 1
        if itemIndex >= lastItemIndex - (endKeylineSteps.count - 1),
           itemCount > defaultKeylines.focalCount {
            let stepIndex = min(
                max(endKeylineSteps.count - 1 - (lastItemIndex - itemIndex), 0),
                endKeylineSteps.count - 1
            )
            let endKeylines = endKeylineSteps[stepIndex]
            offset = (endKeylines.lastFocal.unadjustedOffset - itemMainAxisSize / 2).rounded()
        }

        return offset
    }

    /// The furthest an item can scroll: everything laid end to end, less one viewport.
    func maxScrollOffset(itemCount: Int) -> CGFloat {
        let maxScrollPossible =
            itemMainAxisSize * CGFloat(itemCount) + itemSpacing * CGFloat(itemCount - 1)
        return max(maxScrollPossible - availableSpace, 0)
    }

    // MARK: - Steps

    private static func startShiftDistance(
        startKeylineSteps: [CarouselKeylineList],
        beforeContentPadding: CGFloat
    ) -> CGFloat {
        guard let last = startKeylineSteps.last, let first = startKeylineSteps.first else { return 0 }
        return max(last.first.unadjustedOffset - first.first.unadjustedOffset, beforeContentPadding)
    }

    private static func endShiftDistance(
        endKeylineSteps: [CarouselKeylineList],
        afterContentPadding: CGFloat
    ) -> CGFloat {
        guard let first = endKeylineSteps.first, let last = endKeylineSteps.last else { return 0 }
        return max(first.last.unadjustedOffset - last.last.unadjustedOffset, afterContentPadding)
    }

    /// Steps that walk the focal range to the start of the container, one keyline at a time, so that
    /// every item passes through focus rather than jumping into it.
    private static func startKeylineSteps(
        defaultKeylines: CarouselKeylineList,
        carouselMainAxisSize: CGFloat,
        itemSpacing: CGFloat,
        beforeContentPadding: CGFloat
    ) -> [CarouselKeylineList] {
        guard !defaultKeylines.isEmpty else { return [] }

        var steps: [CarouselKeylineList] = [defaultKeylines]

        if defaultKeylines.isFirstFocalItemAtStartOfContainer() {
            if beforeContentPadding != 0 {
                steps.append(
                    shiftedKeylineListForContentPadding(
                        from: defaultKeylines,
                        carouselMainAxisSize: carouselMainAxisSize,
                        itemSpacing: itemSpacing,
                        contentPadding: beforeContentPadding,
                        pivot: defaultKeylines.firstFocal,
                        pivotIndex: defaultKeylines.firstFocalIndex
                    )
                )
            }
            return steps
        }

        let startIndex = defaultKeylines.firstNonAnchorIndex
        let endIndex = defaultKeylines.firstFocalIndex
        let numberOfSteps = endIndex - startIndex

        if numberOfSteps <= 0 && defaultKeylines.firstFocal.cutoff > 0 {
            steps.append(
                moveKeylineAndCreateShiftedKeylineList(
                    from: defaultKeylines,
                    sourceIndex: 0,
                    destinationIndex: 0,
                    carouselMainAxisSize: carouselMainAxisSize,
                    itemSpacing: itemSpacing
                )
            )
            return steps
        }

        for step in 0..<max(numberOfSteps, 0) {
            let previousStep = steps[steps.count - 1]
            let originalItemIndex = startIndex + step
            var destinationIndex = defaultKeylines.lastIndex
            if originalItemIndex > 0 {
                let neighbourBeforeSize = defaultKeylines[originalItemIndex - 1].size
                destinationIndex = previousStep.firstIndexAfterFocalRange(withSize: neighbourBeforeSize) - 1
            }
            steps.append(
                moveKeylineAndCreateShiftedKeylineList(
                    from: previousStep,
                    sourceIndex: defaultKeylines.firstNonAnchorIndex,
                    destinationIndex: destinationIndex,
                    carouselMainAxisSize: carouselMainAxisSize,
                    itemSpacing: itemSpacing
                )
            )
        }

        if beforeContentPadding != 0, let last = steps.last {
            steps[steps.count - 1] = shiftedKeylineListForContentPadding(
                from: last,
                carouselMainAxisSize: carouselMainAxisSize,
                itemSpacing: itemSpacing,
                contentPadding: beforeContentPadding,
                pivot: last.firstFocal,
                pivotIndex: last.firstFocalIndex
            )
        }

        return steps
    }

    /// The mirror image: steps that walk the focal range to the end of the container.
    private static func endKeylineSteps(
        defaultKeylines: CarouselKeylineList,
        carouselMainAxisSize: CGFloat,
        itemSpacing: CGFloat,
        afterContentPadding: CGFloat
    ) -> [CarouselKeylineList] {
        guard !defaultKeylines.isEmpty else { return [] }

        var steps: [CarouselKeylineList] = [defaultKeylines]

        if defaultKeylines.isLastFocalItemAtEndOfContainer(carouselMainAxisSize: carouselMainAxisSize) {
            if afterContentPadding != 0 {
                steps.append(
                    shiftedKeylineListForContentPadding(
                        from: defaultKeylines,
                        carouselMainAxisSize: carouselMainAxisSize,
                        itemSpacing: itemSpacing,
                        contentPadding: -afterContentPadding,
                        pivot: defaultKeylines.lastFocal,
                        pivotIndex: defaultKeylines.lastFocalIndex
                    )
                )
            }
            return steps
        }

        let startIndex = defaultKeylines.lastFocalIndex
        let endIndex = defaultKeylines.lastNonAnchorIndex
        let numberOfSteps = endIndex - startIndex

        if numberOfSteps <= 0 && defaultKeylines.lastFocal.cutoff > 0 {
            steps.append(
                moveKeylineAndCreateShiftedKeylineList(
                    from: defaultKeylines,
                    sourceIndex: 0,
                    destinationIndex: 0,
                    carouselMainAxisSize: carouselMainAxisSize,
                    itemSpacing: itemSpacing
                )
            )
            return steps
        }

        for step in 0..<max(numberOfSteps, 0) {
            let previousStep = steps[steps.count - 1]
            let originalItemIndex = endIndex - step
            var destinationIndex = 0
            if originalItemIndex < defaultKeylines.lastIndex {
                let neighbourAfterSize = defaultKeylines[originalItemIndex + 1].size
                destinationIndex = previousStep.lastIndexBeforeFocalRange(withSize: neighbourAfterSize) + 1
            }
            steps.append(
                moveKeylineAndCreateShiftedKeylineList(
                    from: previousStep,
                    sourceIndex: defaultKeylines.lastNonAnchorIndex,
                    destinationIndex: destinationIndex,
                    carouselMainAxisSize: carouselMainAxisSize,
                    itemSpacing: itemSpacing
                )
            )
        }

        if afterContentPadding != 0, let last = steps.last {
            steps[steps.count - 1] = shiftedKeylineListForContentPadding(
                from: last,
                carouselMainAxisSize: carouselMainAxisSize,
                itemSpacing: itemSpacing,
                contentPadding: -afterContentPadding,
                pivot: last.lastFocal,
                pivotIndex: last.lastFocalIndex
            )
        }

        return steps
    }

    /// Content padding is paid for by every non-anchor keyline giving up an equal share of its size,
    /// so the arrangement still fills the container exactly.
    private static func shiftedKeylineListForContentPadding(
        from: CarouselKeylineList,
        carouselMainAxisSize: CGFloat,
        itemSpacing: CGFloat,
        contentPadding: CGFloat,
        pivot: CarouselKeyline,
        pivotIndex: Int
    ) -> CarouselKeylineList {
        let numberOfNonAnchorKeylines = from.keylines.filter { !$0.isAnchor }.count
        guard numberOfNonAnchorKeylines > 0 else { return from }
        let sizeReduction = contentPadding / CGFloat(numberOfNonAnchorKeylines)

        let newKeylines = carouselKeylineList(
            carouselMainAxisSize: carouselMainAxisSize,
            itemSpacing: itemSpacing,
            pivotIndex: pivotIndex,
            pivotOffset: pivot.offset - sizeReduction / 2 + contentPadding
        ) { builder in
            for keyline in from.keylines {
                builder.add(size: keyline.size - abs(sizeReduction), isAnchor: keyline.isAnchor)
            }
        }

        // Scroll space is unchanged by padding — items are still laid end to end at their full size
        // — so the unadjusted offsets are put back as they were.
        return CarouselKeylineList(
            newKeylines.keylines.enumerated().map { index, keyline in
                var copy = keyline
                copy.unadjustedOffset = from[index].unadjustedOffset
                return copy
            }
        )
    }

    /// One step: lift the keyline at `sourceIndex`, drop it in at `destinationIndex`, and move the
    /// pivot by the size of what moved so the arrangement stays pinned to the container.
    private static func moveKeylineAndCreateShiftedKeylineList(
        from: CarouselKeylineList,
        sourceIndex: Int,
        destinationIndex: Int,
        carouselMainAxisSize: CGFloat,
        itemSpacing: CGFloat
    ) -> CarouselKeylineList {
        let pivotDirection: CGFloat = sourceIndex > destinationIndex ? 1 : -1
        let pivotDelta =
            (from[sourceIndex].size - from[sourceIndex].cutoff + itemSpacing) * pivotDirection
        let newPivotIndex = from.pivotIndex + Int(pivotDirection)
        let newPivotOffset = from.pivot.offset + pivotDelta

        var moved = from.keylines
        let keyline = moved.remove(at: sourceIndex)
        moved.insert(keyline, at: destinationIndex)

        return carouselKeylineList(
            carouselMainAxisSize: carouselMainAxisSize,
            itemSpacing: itemSpacing,
            pivotIndex: newPivotIndex,
            pivotOffset: newPivotOffset
        ) { builder in
            for keyline in moved {
                builder.add(size: keyline.size, isAnchor: keyline.isAnchor)
            }
        }
    }

    /// The 0-1 points at which each step takes over. They are unevenly spaced, because each step
    /// covers however far its keylines actually had to travel.
    private static func stepInterpolationPoints(
        totalShiftDistance: CGFloat,
        steps: [CarouselKeylineList],
        isShiftingLeft: Bool
    ) -> [CGFloat] {
        var points: [CGFloat] = [0]
        guard totalShiftDistance != 0, !steps.isEmpty else { return points }

        for index in 1..<steps.count {
            let previous = steps[index - 1]
            let current = steps[index]
            let distanceShifted = isShiftingLeft
                ? current.first.unadjustedOffset - previous.first.unadjustedOffset
                : previous.last.unadjustedOffset - current.last.unadjustedOffset
            let stepPercentage = distanceShifted / totalShiftDistance
            points.append(index == steps.count - 1 ? 1 : points[index - 1] + stepPercentage)
        }
        return points
    }
}
