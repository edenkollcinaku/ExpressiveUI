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
    /// The quiet accent surface: a FAB menu's items, and anything else that has to read as the
    /// accent without competing with the control that is actually the accent.
    public var primaryContainer: Color
    /// What is legible drawn on `primaryContainer` — and, on a control that has no container of its
    /// own, the accent itself: the switch's check glyph.
    public var onPrimaryContainer: Color
    /// The tinted-elevated surface. An inactive switch track.
    public var surfaceContainerHighest: Color
    /// Borders and inactive control parts that still need to read as a control.
    public var outline: Color
    /// The surface an unselected button in a group sits on: a step up from the page, and quiet
    /// enough that a selected sibling filled with `primary` is obviously the selected one.
    public var surfaceContainer: Color
    /// Text and icons on `surfaceContainer` — the secondary content tone, not full-strength
    /// `onSurface`.
    public var onSurfaceVariant: Color

    /// The roles added after the first release carry defaults, so call sites written before they
    /// existed keep compiling. Those defaults are the baseline *light* values, which are wrong in
    /// the dark — pass the set for the scheme in effect, as `baseline(for:)` does.
    public init(
        primary: Color,
        onPrimary: Color,
        onPrimaryContainer: Color,
        surfaceContainerHighest: Color,
        outline: Color,
        // Spelled out rather than written as `Color(hex: 0xEADDFF)`, which the compiler rejects in a
        // public default: the hex initialiser is internal.
        primaryContainer: Color = Color(.sRGB, red: 234 / 255, green: 221 / 255, blue: 255 / 255, opacity: 1),
        surfaceContainer: Color = Color(.sRGB, red: 243 / 255, green: 237 / 255, blue: 247 / 255, opacity: 1),
        onSurfaceVariant: Color = Color(.sRGB, red: 73 / 255, green: 69 / 255, blue: 79 / 255, opacity: 1)
    ) {
        self.primary = primary
        self.onPrimary = onPrimary
        self.primaryContainer = primaryContainer
        self.surfaceContainer = surfaceContainer
        self.onSurfaceVariant = onSurfaceVariant
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
        outline: Color(hex: 0x79747E),
        primaryContainer: Color(hex: 0xEADDFF),
        surfaceContainer: Color(hex: 0xF3EDF7),
        onSurfaceVariant: Color(hex: 0x49454F)
    )

    static let baselineDark = ExpressiveColors(
        primary: Color(hex: 0xD0BCFF),
        onPrimary: Color(hex: 0x381E72),
        onPrimaryContainer: Color(hex: 0xEADDFF),
        surfaceContainerHighest: Color(hex: 0x36343B),
        outline: Color(hex: 0x938F99),
        primaryContainer: Color(hex: 0x4F378B),
        surfaceContainer: Color(hex: 0x211F26),
        onSurfaceVariant: Color(hex: 0xCAC4D0)
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
