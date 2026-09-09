import SwiftUI

/// Resolves to the baseline scheme until a call site supplies its own, and — because the default is
/// a *function* of the environment's `colorScheme` rather than a fixed value — an app that never
/// calls `expressiveColors(_:)` still gets light and dark correctly.
private struct ExpressiveColorsKey: EnvironmentKey {
    static let defaultValue: ExpressiveColors? = nil
}

public extension EnvironmentValues {
    /// The colour set components paint with. Reading it falls back to `ExpressiveColors.baseline`
    /// for the current `colorScheme`, so it is never nil at the point of use.
    var expressiveColors: ExpressiveColors {
        get { self[ExpressiveColorsKey.self] ?? .baseline(for: colorScheme) }
        set { self[ExpressiveColorsKey.self] = newValue }
    }
}

public extension View {
    /// Paints every ExpressiveUI component beneath this view with `colors`.
    ///
    /// Apply it once near the root. If your palette differs by light and dark, read
    /// `@Environment(\.colorScheme)` at the call site and pass the matching set.
    func expressiveColors(_ colors: ExpressiveColors) -> some View {
        environment(\.expressiveColors, colors)
    }
}
