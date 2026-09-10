import SwiftUI

public extension View {
    /// Presents an ``ExpressiveMenu`` from this view.
    ///
    /// ```swift
    /// Button("Options") { showingMenu = true }
    ///     .buttonStyle(.expressive(.tonal))
    ///     .expressiveMenu(isPresented: $showingMenu, groups: groups)
    /// ```
    ///
    /// It is a popover, not a reimplementation of one. Compose's `DropdownMenuPopup` owns its window
    /// and positions itself against the anchor; SwiftUI already has that, and a menu that fought it
    /// would lose the things it gets for free — dismissing on an outside tap, staying on screen near
    /// an edge, and the platform's own focus handling.
    ///
    /// What the modifier does add is Material's opening: the menu scales up from
    /// `ClosedScaleTarget` — 0.8 — and fades in, on the spatial and effects springs respectively.
    ///
    /// iOS 16.4 and up, because that is where a popover can be told to stay a popover on iPhone
    /// rather than adapting into a sheet. Below that, present ``ExpressiveMenu`` yourself.
    @available(iOS 16.4, macOS 13.3, *)
    func expressiveMenu(
        isPresented: Binding<Bool>,
        arrowEdge: Edge = .top,
        elevation: ExpressiveElevation = .level0,
        groups: [ExpressiveMenuGroup]
    ) -> some View {
        popover(isPresented: isPresented, arrowEdge: arrowEdge) {
            ExpressiveMenuPopoverContent(groups: groups, elevation: elevation) {
                isPresented.wrappedValue = false
            }
        }
    }
}

@available(iOS 16.4, macOS 13.3, *)
private struct ExpressiveMenuPopoverContent: View {
    @Environment(\.expressiveColors) private var colors

    let groups: [ExpressiveMenuGroup]
    let elevation: ExpressiveElevation
    let dismiss: () -> Void

    @State private var shown = false

    var body: some View {
        ExpressiveMenu(groups: groups, elevation: elevation)
            .scaleEffect(shown ? 1 : 0.8, anchor: .top)
            .opacity(shown ? 1 : 0)
            .fixedSize()
            .padding(4)
            // The popover paints its own chrome behind the menu, and the menu is itself a surface,
            // so the only thing added here is enough padding for its shadow to land.
            .presentationCompactAdaptation(.popover)
            .environment(\.expressiveMenuDismiss, dismiss)
            .onAppear {
                withAnimation(ExpressiveMotion.fastSpatial) { shown = true }
            }
    }
}
