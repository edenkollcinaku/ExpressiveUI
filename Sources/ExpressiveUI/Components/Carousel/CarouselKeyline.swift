import CoreGraphics

/// A position in the carousel's viewport, and the size an item takes when its centre is there.
///
/// A port of `androidx.compose.material3.carousel.Keyline`. Items do not each own a size: the
/// *viewport* owns a list of these, and an item takes whichever size belongs to wherever it has
/// scrolled to. That inversion is the whole component.
struct CarouselKeyline: Equatable {
    /// The item's size when its centre is at this keyline.
    var size: CGFloat
    /// Where this keyline's centre sits in the viewport.
    var offset: CGFloat
    /// Where the centre would sit if every item were focal-sized. Scroll positions are measured in
    /// this space, which is what lets a keyline list be scrolled through smoothly.
    var unadjustedOffset: CGFloat
    /// Focal keylines are the fully unmasked ones.
    var isFocal: Bool
    /// Anchors sit off-screen at either end and are never shifted.
    var isAnchor: Bool
    /// The keyline every other offset in its list was calculated from.
    var isPivot: Bool
    /// How far an item at this keyline bleeds past the container's edge — zero when it is fully in
    /// or fully out.
    var cutoff: CGFloat
}

/// The keylines describing one arrangement, in the order they appear across the viewport.
struct CarouselKeylineList: Equatable {
    var keylines: [CarouselKeyline]

    let minSize: CGFloat
    let maxSize: CGFloat
    let pivotIndex: Int
    let firstNonAnchorIndex: Int
    let lastNonAnchorIndex: Int
    let firstFocalIndex: Int
    let lastFocalIndex: Int

    init(_ keylines: [CarouselKeyline]) {
        self.keylines = keylines
        self.minSize = keylines.map(\.size).min() ?? .greatestFiniteMagnitude
        self.maxSize = keylines.map(\.size).max() ?? 0
        self.pivotIndex = keylines.firstIndex(where: \.isPivot) ?? -1
        self.firstNonAnchorIndex = keylines.firstIndex(where: { !$0.isAnchor }) ?? -1
        self.lastNonAnchorIndex = keylines.lastIndex(where: { !$0.isAnchor }) ?? -1
        self.firstFocalIndex = keylines.firstIndex(where: \.isFocal) ?? -1
        self.lastFocalIndex = keylines.lastIndex(where: \.isFocal) ?? -1
    }

    static let empty = CarouselKeylineList([])

    var isEmpty: Bool { keylines.isEmpty }
    var count: Int { keylines.count }
    var lastIndex: Int { keylines.count - 1 }
    subscript(index: Int) -> CarouselKeyline { keylines[index] }
    var first: CarouselKeyline { keylines[0] }
    var last: CarouselKeyline { keylines[keylines.count - 1] }

    var pivot: CarouselKeyline { keylines[pivotIndex] }
    var firstNonAnchor: CarouselKeyline { keylines[firstNonAnchorIndex] }
    var lastNonAnchor: CarouselKeyline { keylines[lastNonAnchorIndex] }
    var firstFocal: CarouselKeyline { keylines[firstFocalIndex] }
    var lastFocal: CarouselKeyline { keylines[lastFocalIndex] }
    var focalCount: Int { lastFocalIndex - firstFocalIndex + 1 }

    /// True when the focal range cannot be shifted any further towards the start.
    func isFirstFocalItemAtStartOfContainer() -> Bool {
        let firstFocalLeft = firstFocal.offset - firstFocal.size / 2
        return firstFocalLeft >= 0 && firstFocal == firstNonAnchor
    }

    /// True when the focal range cannot be shifted any further towards the end.
    func isLastFocalItemAtEndOfContainer(carouselMainAxisSize: CGFloat) -> Bool {
        let lastFocalRight = lastFocal.offset + lastFocal.size / 2
        return lastFocalRight <= carouselMainAxisSize && lastFocal == lastNonAnchor
    }

    /// Where to re-insert a keyline that is being moved past the focal range, so the arrangement
    /// stays visually balanced: the first slot after the focal range holding the same size.
    func firstIndexAfterFocalRange(withSize size: CGFloat) -> Int {
        (lastFocalIndex...lastIndex).first { keylines[$0].size == size } ?? lastIndex
    }

    /// The mirror of the above, for a keyline moving the other way.
    func lastIndexBeforeFocalRange(withSize size: CGFloat) -> Int {
        stride(from: firstFocalIndex - 1, through: 0, by: -1)
            .first { keylines[$0].size == size } ?? 0
    }

    /// The last keyline sitting before `unadjustedOffset` in scroll space.
    func keylineBefore(_ unadjustedOffset: CGFloat) -> CarouselKeyline {
        for index in keylines.indices.reversed() where keylines[index].unadjustedOffset < unadjustedOffset {
            return keylines[index]
        }
        return first
    }

    /// The first keyline sitting at or after `unadjustedOffset` in scroll space.
    func keylineAfter(_ unadjustedOffset: CGFloat) -> CarouselKeyline {
        keylines.first { $0.unadjustedOffset >= unadjustedOffset } ?? last
    }
}

/// Where the focal range is anchored when a keyline list is built.
enum CarouselAlignment {
    case start, center, end
}

/// Builds a keyline list from bare sizes, then resolves every offset from a single pivot.
///
/// Sizes go in in the order they appear across the viewport; the largest non-anchor entry starts the
/// focal range, and the range runs as far as consecutive entries keep that size.
struct CarouselKeylineListBuilder {
    private struct TemporaryKeyline {
        let size: CGFloat
        let isAnchor: Bool
    }

    private var temporaries: [TemporaryKeyline] = []
    private var firstFocalIndex: Int = -1
    private var focalItemSize: CGFloat = 0

    mutating func add(size: CGFloat, isAnchor: Bool = false) {
        temporaries.append(TemporaryKeyline(size: size, isAnchor: isAnchor))
        if !isAnchor && size > focalItemSize {
            firstFocalIndex = temporaries.count - 1
            focalItemSize = size
        }
    }

    /// Aligns the focal range against the container, and resolves everything from there.
    func createWithAlignment(
        carouselMainAxisSize: CGFloat,
        itemSpacing: CGFloat,
        alignment: CarouselAlignment
    ) -> CarouselKeylineList {
        let lastFocalIndex = findLastFocalIndex()
        let focalItemCount = lastFocalIndex - firstFocalIndex

        let pivotOffset: CGFloat
        switch alignment {
        case .center:
            // With an even number of focal keylines the spacing itself lands in the centre, so only
            // an odd count contributes half a gap.
            let itemSpacingSplit = (itemSpacing == 0 || focalItemCount % 2 == 0) ? 0 : itemSpacing / 2
            let itemSpaceCounts = CGFloat(focalItemCount / 2) * itemSpacing
            pivotOffset =
                carouselMainAxisSize / 2
                - (focalItemSize / 2) * CGFloat(focalItemCount)
                - itemSpacingSplit
                - itemSpaceCounts
        case .end:
            pivotOffset = carouselMainAxisSize - focalItemSize / 2
        case .start:
            pivotOffset = focalItemSize / 2
        }

        return CarouselKeylineList(
            createKeylinesWithPivot(
                pivotIndex: firstFocalIndex,
                pivotOffset: pivotOffset,
                firstFocalIndex: firstFocalIndex,
                lastFocalIndex: lastFocalIndex,
                itemMainAxisSize: focalItemSize,
                carouselMainAxisSize: carouselMainAxisSize,
                itemSpacing: itemSpacing
            )
        )
    }

    /// Resolves from a caller-chosen pivot, which is how a shifted step keeps its focal range where
    /// the shift put it.
    func createWithPivot(
        carouselMainAxisSize: CGFloat,
        itemSpacing: CGFloat,
        pivotIndex: Int,
        pivotOffset: CGFloat
    ) -> CarouselKeylineList {
        CarouselKeylineList(
            createKeylinesWithPivot(
                pivotIndex: pivotIndex,
                pivotOffset: pivotOffset,
                firstFocalIndex: firstFocalIndex,
                lastFocalIndex: findLastFocalIndex(),
                itemMainAxisSize: focalItemSize,
                carouselMainAxisSize: carouselMainAxisSize,
                itemSpacing: itemSpacing
            )
        )
    }

    /// The focal range runs from the first largest entry through every consecutive entry of the
    /// same size.
    private func findLastFocalIndex() -> Int {
        guard firstFocalIndex >= 0 else { return -1 }
        var lastFocalIndex = firstFocalIndex
        while lastFocalIndex < temporaries.count - 1,
              temporaries[lastFocalIndex + 1].size == focalItemSize {
            lastFocalIndex += 1
        }
        return lastFocalIndex
    }

    /// Walks outwards from the pivot in both directions. Offsets accumulate real sizes; unadjusted
    /// offsets accumulate the focal size, because that is the space scrolling is measured in.
    private func createKeylinesWithPivot(
        pivotIndex: Int,
        pivotOffset: CGFloat,
        firstFocalIndex: Int,
        lastFocalIndex: Int,
        itemMainAxisSize: CGFloat,
        carouselMainAxisSize: CGFloat,
        itemSpacing: CGFloat
    ) -> [CarouselKeyline] {
        guard !temporaries.isEmpty, temporaries.indices.contains(pivotIndex) else { return [] }

        let pivot = temporaries[pivotIndex]
        var keylines: [CarouselKeyline] = []

        let pivotCutoff: CGFloat
        if isCutoffLeft(size: pivot.size, offset: pivotOffset) {
            pivotCutoff = pivotOffset - pivot.size / 2
        } else if isCutoffRight(size: pivot.size, offset: pivotOffset, carouselMainAxisSize: carouselMainAxisSize) {
            pivotCutoff = (pivotOffset + pivot.size / 2) - carouselMainAxisSize
        } else {
            pivotCutoff = 0
        }

        keylines.append(
            CarouselKeyline(
                size: pivot.size,
                offset: pivotOffset,
                unadjustedOffset: pivotOffset,
                isFocal: (firstFocalIndex...max(firstFocalIndex, lastFocalIndex)).contains(pivotIndex),
                isAnchor: pivot.isAnchor,
                isPivot: true,
                cutoff: pivotCutoff
            )
        )

        var offset = pivotOffset - itemMainAxisSize / 2 - itemSpacing
        var unadjustedOffset = offset
        for originalIndex in stride(from: pivotIndex - 1, through: 0, by: -1) {
            let temporary = temporaries[originalIndex]
            let temporaryOffset = offset - temporary.size / 2
            let temporaryUnadjustedOffset = unadjustedOffset - itemMainAxisSize / 2
            let cutoff = isCutoffLeft(size: temporary.size, offset: temporaryOffset)
                ? abs(temporaryOffset - temporary.size / 2)
                : 0
            keylines.insert(
                CarouselKeyline(
                    size: temporary.size,
                    offset: temporaryOffset,
                    unadjustedOffset: temporaryUnadjustedOffset,
                    isFocal: originalIndex >= firstFocalIndex && originalIndex <= lastFocalIndex,
                    isAnchor: temporary.isAnchor,
                    isPivot: false,
                    cutoff: cutoff
                ),
                at: 0
            )
            offset -= temporary.size + itemSpacing
            unadjustedOffset -= itemMainAxisSize + itemSpacing
        }

        offset = pivotOffset + itemMainAxisSize / 2 + itemSpacing
        unadjustedOffset = offset
        for originalIndex in (pivotIndex + 1)..<temporaries.count {
            let temporary = temporaries[originalIndex]
            let temporaryOffset = offset + temporary.size / 2
            let temporaryUnadjustedOffset = unadjustedOffset + itemMainAxisSize / 2
            let cutoff = isCutoffRight(
                size: temporary.size,
                offset: temporaryOffset,
                carouselMainAxisSize: carouselMainAxisSize
            ) ? (temporaryOffset + temporary.size / 2) - carouselMainAxisSize : 0
            keylines.append(
                CarouselKeyline(
                    size: temporary.size,
                    offset: temporaryOffset,
                    unadjustedOffset: temporaryUnadjustedOffset,
                    isFocal: originalIndex >= firstFocalIndex && originalIndex <= lastFocalIndex,
                    isAnchor: temporary.isAnchor,
                    isPivot: false,
                    cutoff: cutoff
                )
            )
            offset += temporary.size + itemSpacing
            unadjustedOffset += itemMainAxisSize + itemSpacing
        }

        return keylines
    }

    /// Straddling the container's leading edge — not fully in, not fully out.
    private func isCutoffLeft(size: CGFloat, offset: CGFloat) -> Bool {
        offset - size / 2 < 0 && offset + size / 2 > 0
    }

    /// Straddling the trailing edge.
    private func isCutoffRight(size: CGFloat, offset: CGFloat, carouselMainAxisSize: CGFloat) -> Bool {
        offset - size / 2 < carouselMainAxisSize && offset + size / 2 > carouselMainAxisSize
    }
}

/// Builds a keyline list, aligning the focal range as asked.
func carouselKeylineList(
    carouselMainAxisSize: CGFloat,
    itemSpacing: CGFloat,
    alignment: CarouselAlignment,
    _ build: (inout CarouselKeylineListBuilder) -> Void
) -> CarouselKeylineList {
    var builder = CarouselKeylineListBuilder()
    build(&builder)
    return builder.createWithAlignment(
        carouselMainAxisSize: carouselMainAxisSize,
        itemSpacing: itemSpacing,
        alignment: alignment
    )
}

/// Builds a keyline list around an explicit pivot.
func carouselKeylineList(
    carouselMainAxisSize: CGFloat,
    itemSpacing: CGFloat,
    pivotIndex: Int,
    pivotOffset: CGFloat,
    _ build: (inout CarouselKeylineListBuilder) -> Void
) -> CarouselKeylineList {
    var builder = CarouselKeylineListBuilder()
    build(&builder)
    return builder.createWithPivot(
        carouselMainAxisSize: carouselMainAxisSize,
        itemSpacing: itemSpacing,
        pivotIndex: pivotIndex,
        pivotOffset: pivotOffset
    )
}

func lerp(_ start: CGFloat, _ end: CGFloat, _ fraction: CGFloat) -> CGFloat {
    start + (end - start) * fraction
}

/// Maps `value` from one range onto another, clamped at both ends.
func lerp(
    outputMin: CGFloat,
    outputMax: CGFloat,
    inputMin: CGFloat,
    inputMax: CGFloat,
    value: CGFloat
) -> CGFloat {
    if value <= inputMin { return outputMin }
    if value >= inputMax { return outputMax }
    return lerp(outputMin, outputMax, (value - inputMin) / (inputMax - inputMin))
}

func lerp(_ start: CarouselKeyline, _ end: CarouselKeyline, _ fraction: CGFloat) -> CarouselKeyline {
    CarouselKeyline(
        size: lerp(start.size, end.size, fraction),
        offset: lerp(start.offset, end.offset, fraction),
        unadjustedOffset: lerp(start.unadjustedOffset, end.unadjustedOffset, fraction),
        isFocal: fraction < 0.5 ? start.isFocal : end.isFocal,
        isAnchor: fraction < 0.5 ? start.isAnchor : end.isAnchor,
        isPivot: fraction < 0.5 ? start.isPivot : end.isPivot,
        cutoff: lerp(start.cutoff, end.cutoff, fraction)
    )
}

/// Interpolates two lists keyline by keyline. Unlike building one, this does not re-derive offsets
/// from a pivot — the whole point is to land between two already-resolved arrangements.
func lerp(_ from: CarouselKeylineList, _ to: CarouselKeylineList, _ fraction: CGFloat) -> CarouselKeylineList {
    CarouselKeylineList(from.keylines.enumerated().map { index, keyline in
        lerp(keyline, to[index], fraction)
    })
}
