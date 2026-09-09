import XCTest
@testable import ExpressiveUI

final class ExpressiveButtonGroupLayoutTests: XCTestCase {
    private func widths(total: CGFloat, count: Int, spacing: CGFloat, pressed: Int?) -> [CGFloat] {
        let base = (total - spacing * CGFloat(count - 1)) / CGFloat(count)
        return ButtonGroupRow.squeezed(
            Array(repeating: base, count: count),
            pressedIndex: pressed,
            expandedRatio: 0.15,
            compressionLimit: 24
        )
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

    /// Past the compression limit the neighbours would start clipping their labels, so the pressed
    /// button gets less than the ratio asked for rather than the row losing its shape.
    func testCompressionIsCapped() {
        let widths = ButtonGroupRow.squeezed(
            [400, 400],
            pressedIndex: 0,
            expandedRatio: 0.15,
            compressionLimit: 24
        )
        XCTAssertEqual(widths, [424, 376])
    }
}
