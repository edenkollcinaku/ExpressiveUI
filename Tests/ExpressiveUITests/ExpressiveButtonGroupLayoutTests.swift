import XCTest
@testable import ExpressiveUI

final class ExpressiveButtonGroupLayoutTests: XCTestCase {
    private func widths(total: CGFloat, count: Int, spacing: CGFloat, pressed: Int?) -> [CGFloat] {
        (0..<count).map {
            ExpressiveButtonGroupLayout.width(
                at: $0,
                count: count,
                total: total,
                spacing: spacing,
                pressedIndex: pressed,
                expandedRatio: 0.15
            )
        }
    }

    func testUnpressedButtonsShareTheRowEqually() {
        let widths = widths(total: 324, count: 3, spacing: 12, pressed: nil)
        XCTAssertEqual(widths, [100, 100, 100])
    }

    func testPressingExpandsByTheRatio() {
        let widths = widths(total: 324, count: 3, spacing: 12, pressed: 0)
        XCTAssertEqual(widths[0], 115, accuracy: 0.001)
    }

    /// The neighbours pay for the expansion, which is the only reason the group can be squeezed
    /// without the row it sits in moving.
    func testTheGroupKeepsItsWidthWhilePressed() {
        for pressed in 0..<3 {
            let total = widths(total: 324, count: 3, spacing: 12, pressed: pressed).reduce(0, +)
            XCTAssertEqual(total + 24, 324, accuracy: 0.001)
        }
    }

    func testASingleButtonHasNothingToTakeFrom() {
        XCTAssertEqual(widths(total: 200, count: 1, spacing: 12, pressed: 0), [200])
    }
}
