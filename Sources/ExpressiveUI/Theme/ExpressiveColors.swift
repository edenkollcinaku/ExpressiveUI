import SwiftUI

/// The colour roles ExpressiveUI's components read.
///
/// Material 3 names far more roles than this; the type carries only the ones a shipped component
/// actually paints with, and grows as components land. Each addition is a minor version, and every
/// role has a baseline value, so a consumer's existing `ExpressiveColors(...)` call keeps compiling.
///
/// Supply your own by mapping your app's palette onto it once, near the root:
///
/// ```swift
/// ContentView()
///     .expressiveColors(.init(primary: brand, onPrimary: .white, ...))
/// ```
///
/// Components resolve the scheme through `@Environment(\.colorScheme)`, so pass the set for the
/// scheme in effect — `ExpressiveColors.baseline(for:)` is the shape to copy.
public struct ExpressiveColors: Equatable, Sendable {
    /// The accent an active control fills itself with.
    public var primary: Color
    /// What is legible drawn *on* `primary`. Not necessarily white: Material picks it by luminance,
    /// so a bright seed wants near-black content here.
    public var onPrimary: Color
    /// The accent as it reads on a light accent surface — the switch's check glyph.
    public var onPrimaryContainer: Color
    /// The tinted-elevated surface. An inactive switch track.
    public var surfaceContainerHighest: Color
    /// Borders and inactive control parts that still need to read as a control.
    public var outline: Color

    public init(
        primary: Color,
        onPrimary: Color,
        onPrimaryContainer: Color,
        surfaceContainerHighest: Color,
        outline: Color
    ) {
        self.primary = primary
        self.onPrimary = onPrimary
        self.onPrimaryContainer = onPrimaryContainer
        self.surfaceContainerHighest = surfaceContainerHighest
        self.outline = outline
    }
}

public extension ExpressiveColors {
    /// Material 3's baseline scheme — the purple one the spec ships when no seed colour is given.
    /// It exists so a component is correct with zero setup, not because it is the look you want.
    static func baseline(for scheme: ColorScheme) -> ExpressiveColors {
        scheme == .dark ? .baselineDark : .baselineLight
    }

    static let baselineLight = ExpressiveColors(
        primary: Color(hex: 0x6750A4),
        onPrimary: .white,
        onPrimaryContainer: Color(hex: 0x21005D),
        surfaceContainerHighest: Color(hex: 0xE6E0E9),
        outline: Color(hex: 0x79747E)
    )

    static let baselineDark = ExpressiveColors(
        primary: Color(hex: 0xD0BCFF),
        onPrimary: Color(hex: 0x381E72),
        onPrimaryContainer: Color(hex: 0xEADDFF),
        surfaceContainerHighest: Color(hex: 0x36343B),
        outline: Color(hex: 0x938F99)
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
