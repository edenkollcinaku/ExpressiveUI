import AppKit
import ExpressiveUI
import SwiftUI

// The images in Docs/ are rendered from the shipping component rather than drawn by hand, so a
// change to the switch that nobody documents still shows up the next time these are regenerated.
//
//     swift run --package-path Tools/ScreenshotGenerator
//
// Writes into Docs/Images relative to the repository root.

// MARK: - Palette for the pages themselves

private extension Color {
    static let pageLight = Color(.sRGB, red: 0.996, green: 0.984, blue: 0.996)
    static let pageDark = Color(.sRGB, red: 0.078, green: 0.071, blue: 0.094)
    static let captionLight = Color(.sRGB, red: 0.29, green: 0.27, blue: 0.31)
    static let captionDark = Color(.sRGB, red: 0.79, green: 0.77, blue: 0.81)
}

private struct Panel<Content: View>: View {
    let scheme: ColorScheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .environment(\.colorScheme, scheme)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(scheme == .dark ? Color.pageDark : .pageLight)
    }
}

/// One switch, frozen in a state. `.constant` means it does not react — these are stills.
private struct Specimen: View {
    let isOn: Bool
    var isEnabled: Bool = true

    var body: some View {
        Toggle(isOn: .constant(isOn)) { EmptyView() }
            .toggleStyle(.expressive)
            .fixedSize()
            .disabled(!isEnabled)
    }
}

private struct Caption: View {
    let text: String
    let scheme: ColorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(scheme == .dark ? Color.captionDark : .captionLight)
    }
}

// MARK: - Overview

private struct Overview: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                Panel(scheme: scheme) {
                    VStack(spacing: 20) {
                        HStack(spacing: 28) {
                            Specimen(isOn: false)
                            Specimen(isOn: true)
                        }
                        Caption(text: scheme == .dark ? "Dark" : "Light", scheme: scheme)
                    }
                }
            }
        }
        .frame(width: 640, height: 200)
    }
}

// MARK: - States

private struct States: View {
    private let rows: [(String, Bool)] = [("Enabled", true), ("Disabled", false)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                Panel(scheme: scheme) {
                    Grid(horizontalSpacing: 28, verticalSpacing: 22) {
                        GridRow {
                            Color.clear.frame(width: 1, height: 1)
                            Caption(text: "Off", scheme: scheme)
                            Caption(text: "On", scheme: scheme)
                        }
                        ForEach(rows, id: \.0) { name, enabled in
                            GridRow {
                                Caption(text: name, scheme: scheme)
                                    .gridColumnAlignment(.leading)
                                Specimen(isOn: false, isEnabled: enabled)
                                Specimen(isOn: true, isEnabled: enabled)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 640, height: 220)
    }
}

// MARK: - Anatomy

/// The plate is laid out on a fixed 640x300 canvas so every leader line can be pointed at a real
/// edge of the component: the specimens are drawn at 3.5x, which makes the 52x32 track 182x112, and
/// the coordinates below are that geometry rather than numbers nudged until they looked right.
private struct Anatomy: View {
    private let scale: CGFloat = 3.5
    private var trackW: CGFloat { 52 * 3.5 }
    private var trackH: CGFloat { 32 * 3.5 }

    /// Centres of the two specimens on the canvas.
    private let offCentre = CGPoint(x: 170, y: 130)
    private let onCentre = CGPoint(x: 460, y: 130)

    /// The on-handle sits 4pt from the trailing edge, so its centre is 36pt in — 126 at 3.5x.
    private var handleCentre: CGPoint {
        CGPoint(x: onCentre.x - trackW / 2 + 36 * scale, y: onCentre.y)
    }

    private let legend = [
        "Track",
        "Track outline (off only)",
        "Handle",
        "Icon (on only)"
    ]

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                big(false).position(offCentre)
                big(true).position(onCentre)

                // 1 — track, pointed at the leading edge of the off specimen.
                leader(from: CGPoint(x: 30, y: offCentre.y), to: CGPoint(x: offCentre.x - trackW / 2, y: offCentre.y))
                bullet(1, at: CGPoint(x: 30, y: offCentre.y))

                // 2 — the 2pt outline, pointed at the bottom of that same track.
                leader(from: CGPoint(x: offCentre.x, y: 240), to: CGPoint(x: offCentre.x, y: offCentre.y + trackH / 2))
                bullet(2, at: CGPoint(x: offCentre.x, y: 252))

                // 3 — the handle, pointed at the top of the on specimen's thumb.
                leader(from: CGPoint(x: handleCentre.x, y: 30), to: CGPoint(x: handleCentre.x, y: handleCentre.y - 24 * scale / 2))
                bullet(3, at: CGPoint(x: handleCentre.x, y: 18))

                // 4 — the check glyph inside it.
                leader(from: CGPoint(x: 610, y: handleCentre.y), to: CGPoint(x: handleCentre.x + 16 * scale / 2, y: handleCentre.y))
                bullet(4, at: CGPoint(x: 610, y: handleCentre.y))
            }
            .frame(width: 640, height: 278)

            HStack(alignment: .top, spacing: 48) {
                VStack(alignment: .leading, spacing: 10) {
                    legendRow(1)
                    legendRow(2)
                }
                VStack(alignment: .leading, spacing: 10) {
                    legendRow(3)
                    legendRow(4)
                }
            }
        }
        .padding(.vertical, 28)
        .frame(width: 700, height: 396)
        .background(Color.pageLight)
    }

    /// The style lays the label out first, so a specimen's box is 12pt wider than the track and its
    /// visual centre sits half of that to the right. Pulling it back lets every coordinate above be
    /// read straight off the track.
    private func big(_ isOn: Bool) -> some View {
        Specimen(isOn: isOn)
            .scaleEffect(scale)
            .offset(x: -6 * scale)
    }

    private func leader(from: CGPoint, to: CGPoint) -> some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.captionLight.opacity(0.45), lineWidth: 1)
    }

    private func bullet(_ number: Int, at point: CGPoint) -> some View {
        marker(number, size: 24, font: 13).position(point)
    }

    private func legendRow(_ number: Int) -> some View {
        HStack(spacing: 10) {
            marker(number, size: 21, font: 12)
            Text(legend[number - 1])
                .font(.system(size: 14))
                .foregroundStyle(Color.captionLight)
        }
    }

    private func marker(_ number: Int, size: CGFloat, font: CGFloat) -> some View {
        Text("\(number)")
            .font(.system(size: font, weight: .semibold))
            .foregroundStyle(Color.pageLight)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.captionLight))
    }
}

// MARK: - FAB menu

/// Two neutral entries. The plates are of the component, so the labels are deliberately generic.
private func demoItems() -> [ExpressiveFABMenuItem] {
    [
        .init(systemImage: "square.and.pencil", label: "Note") {},
        .init(systemImage: "camera", label: "Photo") {}
    ]
}

private struct FABMenuOverview: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                Panel(scheme: scheme) {
                    VStack(spacing: 20) {
                        HStack(alignment: .bottom, spacing: 56) {
                            ExpressiveFABMenu(isOpen: .constant(false), items: demoItems())
                            ExpressiveFABMenu(isOpen: .constant(true), items: demoItems())
                        }
                        Caption(text: scheme == .dark ? "Dark" : "Light", scheme: scheme)
                    }
                }
            }
        }
        .frame(width: 760, height: 320)
    }
}

/// One item and the FAB, with the leader lines aimed using the component's own measurements: a 56pt
/// FAB and a 56pt item, 12pt apart, and an item whose width is its label measured in the same font
/// the component draws it in.
private struct FABMenuAnatomy: View {
    private let label = "Note"
    private let canvas = CGSize(width: 700, height: 270)
    private let trailingEdge: CGFloat = 470
    private let fabCentre = CGPoint(x: 442, y: 212)

    private var itemCentreY: CGFloat { fabCentre.y - 28 - 12 - 28 }
    private var itemWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 16, weight: .medium)
        let text = (label as NSString).size(withAttributes: [.font: font]).width
        // icon + spacing + label, inside 24pt of padding on each side.
        return 24 + 8 + ceil(text) + 48
    }
    private var itemLeadingEdge: CGFloat { trailingEdge - itemWidth }
    private var iconCentreX: CGFloat { itemLeadingEdge + 24 + 12 }
    private var labelCentreX: CGFloat { itemLeadingEdge + 24 + 24 + 8 + (itemWidth - 24 - 8 - 48) / 2 }

    private let legend = ["FAB", "Menu item", "Item icon", "Item label"]

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                ExpressiveFABMenu(
                    isOpen: .constant(true),
                    items: [.init(systemImage: "square.and.pencil", label: LocalizedStringKey(label)) {}]
                )
                // Padded first, then framed, so the menu's own trailing and bottom edges land on
                // the coordinates the leader lines below are written against.
                .padding(.trailing, canvas.width - trailingEdge)
                .padding(.bottom, canvas.height - (fabCentre.y + 28))
                .frame(width: canvas.width, height: canvas.height, alignment: .bottomTrailing)

                leader(from: CGPoint(x: trailingEdge + 72, y: fabCentre.y), to: CGPoint(x: trailingEdge, y: fabCentre.y))
                bullet(1, at: CGPoint(x: trailingEdge + 84, y: fabCentre.y))

                leader(from: CGPoint(x: trailingEdge + 72, y: itemCentreY), to: CGPoint(x: trailingEdge, y: itemCentreY))
                bullet(2, at: CGPoint(x: trailingEdge + 84, y: itemCentreY))

                leader(from: CGPoint(x: iconCentreX, y: 40), to: CGPoint(x: iconCentreX, y: itemCentreY - 28))
                bullet(3, at: CGPoint(x: iconCentreX, y: 28))

                // Angled away from the FAB, which sits directly below the label.
                leader(from: CGPoint(x: labelCentreX, y: itemCentreY + 28), to: CGPoint(x: labelCentreX - 130, y: 240))
                bullet(4, at: CGPoint(x: labelCentreX - 130, y: 240))
            }
            .frame(width: canvas.width, height: canvas.height)

            HStack(alignment: .top, spacing: 48) {
                VStack(alignment: .leading, spacing: 10) {
                    legendRow(1)
                    legendRow(2)
                }
                VStack(alignment: .leading, spacing: 10) {
                    legendRow(3)
                    legendRow(4)
                }
            }
        }
        .padding(.vertical, 28)
        .frame(width: 700, height: 400)
        .background(Color.pageLight)
    }

    private func leader(from: CGPoint, to: CGPoint) -> some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.captionLight.opacity(0.45), lineWidth: 1)
    }

    private func bullet(_ number: Int, at point: CGPoint) -> some View {
        marker(number, size: 24, font: 13).position(point)
    }

    private func legendRow(_ number: Int) -> some View {
        HStack(spacing: 10) {
            marker(number, size: 21, font: 12)
            Text(legend[number - 1])
                .font(.system(size: 14))
                .foregroundStyle(Color.captionLight)
        }
    }

    private func marker(_ number: Int, size: CGFloat, font: CGFloat) -> some View {
        Text("\(number)")
            .font(.system(size: font, weight: .semibold))
            .foregroundStyle(Color.pageLight)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.captionLight))
    }
}

// MARK: - Rendering

@MainActor
private func write<V: View>(_ view: V, to name: String) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    guard
        let image = renderer.nsImage,
        let tiff = image.tiffRepresentation,
        let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    else {
        fatalError("could not render \(name)")
    }
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // ScreenshotGenerator
        .deletingLastPathComponent()  // Sources
        .deletingLastPathComponent()  // ScreenshotGenerator
        .deletingLastPathComponent()  // Tools
        .deletingLastPathComponent()  // repository root
    let directory = root.appendingPathComponent("Docs/Images")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(name)
    try! png.write(to: url)
    print("wrote \(url.path)")
}

MainActor.assumeIsolated {
    write(Overview(), to: "switch-overview.png")
    write(States(), to: "switch-states.png")
    write(Anatomy(), to: "switch-anatomy.png")
    write(FABMenuOverview(), to: "fab-menu-overview.png")
    write(FABMenuAnatomy(), to: "fab-menu-anatomy.png")
}
