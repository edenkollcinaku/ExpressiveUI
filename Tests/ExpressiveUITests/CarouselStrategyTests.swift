import XCTest
@testable import ExpressiveUI

/// The carousel's arrangement is searched for rather than laid out, so these check the properties
/// the search is supposed to guarantee rather than numbers copied out of one run.
final class CarouselStrategyTests: XCTestCase {
    private let width: CGFloat = 360
    private let spacing: CGFloat = 8

    private func multiBrowse(itemCount: Int = 10) -> CarouselKeylineList {
        multiBrowseKeylineList(
            carouselMainAxisSize: width,
            preferredItemSize: 186,
            itemSpacing: spacing,
            itemCount: itemCount
        )
    }

    func testArrangementFillsTheContainerExactly() {
        let keylines = multiBrowse()
        let visible = keylines.keylines.filter { !$0.isAnchor }
        let total = visible.reduce(0) { $0 + $1.size }
            + spacing * CGFloat(visible.count - 1)
        XCTAssertEqual(total, width, accuracy: 0.01)
    }

    func testSmallItemStaysWithinMaterialsRange() {
        let keylines = multiBrowse()
        let smallest = keylines.keylines.filter { !$0.isAnchor }.map(\.size).min() ?? 0
        XCTAssertGreaterThanOrEqual(smallest, CarouselDefaults.minSmallItemSize - 0.01)
        XCTAssertLessThanOrEqual(smallest, CarouselDefaults.maxSmallItemSize + 0.01)
    }

    func testSizesDescendFromTheFocalRange() {
        let sizes = multiBrowse().keylines.filter { !$0.isAnchor }.map(\.size)
        XCTAssertEqual(sizes, sizes.sorted(by: >), "large, then medium, then small")
    }

    /// The point of the shift steps: at rest at the start of the list, the first item is focal and
    /// sits at the container's leading edge.
    func testTheFirstItemReachesTheStartOfTheContainer() {
        let strategy = CarouselStrategy(
            defaultKeylines: multiBrowse(),
            availableSpace: width,
            itemSpacing: spacing,
            beforeContentPadding: 0,
            afterContentPadding: 0
        )
        let atRest = strategy.keylineList(scrollOffset: 0, maxScrollOffset: 1000)
        XCTAssertEqual(atRest.firstFocal.offset - atRest.firstFocal.size / 2, 0, accuracy: 0.5)
    }

    /// And at the end of the list, the last item is focal and reaches the trailing edge.
    func testTheLastItemReachesTheEndOfTheContainer() {
        let itemCount = 10
        let strategy = CarouselStrategy(
            defaultKeylines: multiBrowse(itemCount: itemCount),
            availableSpace: width,
            itemSpacing: spacing,
            beforeContentPadding: 0,
            afterContentPadding: 0
        )
        let maxScroll = strategy.maxScrollOffset(itemCount: itemCount)
        let atEnd = strategy.keylineList(scrollOffset: maxScroll, maxScrollOffset: maxScroll)
        XCTAssertEqual(atEnd.lastFocal.offset + atEnd.lastFocal.size / 2, width, accuracy: 0.5)
    }

    /// Every item passes through focus: a step per keyline between the container edge and the focal
    /// range, plus the default arrangement itself.
    func testThereIsOneShiftStepPerKeylineBeforeTheFocalRange() {
        let keylines = multiBrowse()
        let strategy = CarouselStrategy(
            defaultKeylines: keylines,
            availableSpace: width,
            itemSpacing: spacing,
            beforeContentPadding: 0,
            afterContentPadding: 0
        )
        XCTAssertEqual(
            strategy.endKeylineSteps.count,
            keylines.lastNonAnchorIndex - keylines.lastFocalIndex + 1
        )
    }

    func testUncontainedItemsAreAllTheSameSizeBarTheCutOffOne() {
        // 150 rather than 186: at 186 two items do not fit in 360, and the algorithm's own clamp
        // pulls the cut-off item all the way up to the large size, leaving nothing cut off.
        let keylines = uncontainedKeylineList(
            carouselMainAxisSize: width,
            itemSize: 150,
            itemSpacing: spacing
        )
        let visible = keylines.keylines.filter { !$0.isAnchor }
        let focal = visible.filter { $0.isFocal }
        XCTAssertGreaterThanOrEqual(focal.count, 1)
        XCTAssertTrue(focal.allSatisfy { abs($0.size - focal[0].size) < 0.01 })
        XCTAssertLessThan(visible.last!.size, focal[0].size, "the trailing item is cut off")
    }

    func testAnEmptyContainerProducesNoKeylines() {
        XCTAssertTrue(
            multiBrowseKeylineList(
                carouselMainAxisSize: 0,
                preferredItemSize: 186,
                itemSpacing: spacing,
                itemCount: 5
            ).isEmpty
        )
    }
}
