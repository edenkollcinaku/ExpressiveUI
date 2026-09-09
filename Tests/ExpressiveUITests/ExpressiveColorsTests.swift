import SwiftUI
import XCTest
@testable import ExpressiveUI

final class ExpressiveColorsTests: XCTestCase {
    func testBaselineDiffersByScheme() {
        XCTAssertNotEqual(ExpressiveColors.baseline(for: .light), ExpressiveColors.baseline(for: .dark))
    }

    func testEnvironmentFallsBackToBaselineForTheCurrentScheme() {
        var values = EnvironmentValues()
        values.colorScheme = .dark
        XCTAssertEqual(values.expressiveColors, .baselineDark)

        values.colorScheme = .light
        XCTAssertEqual(values.expressiveColors, .baselineLight)
    }

    func testSuppliedColoursWinOverTheBaseline() {
        var values = EnvironmentValues()
        values.colorScheme = .light
        values.expressiveColors = .baselineDark
        XCTAssertEqual(values.expressiveColors, .baselineDark)
    }

    func testHexInitialiserReadsChannelsInOrder() {
        XCTAssertEqual(Color(hex: 0xFF0000), Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1))
        XCTAssertEqual(Color(hex: 0x00FF00), Color(.sRGB, red: 0, green: 1, blue: 0, opacity: 1))
        XCTAssertEqual(Color(hex: 0x0000FF), Color(.sRGB, red: 0, green: 0, blue: 1, opacity: 1))
    }
}
