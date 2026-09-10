import SwiftUI

/// Material's elevation levels, as shadows.
///
/// Android casts these for real: a `Surface` is given a height in dp and the platform lights it with
/// two sources — a sharp key light close to the shape, and a broad ambient one. SwiftUI has neither,
/// so each level here is that pair spelled out as two stacked shadows, at the offsets and alphas
/// Material publishes for them (30% key, 15% ambient).
///
/// Two shadows rather than one is not fussiness. A single blurred shadow at the ambient's radius
/// reads as fog under the shape; the tight key shadow is what makes an edge look like it is *just*
/// off the surface rather than floating over it — which matters most where two elevated things sit
/// a couple of points apart and their shadows would otherwise pool in the gap.
public enum ExpressiveElevation: Sendable {
    /// Flat on the surface. No shadow at all.
    case level0
    /// `ElevationTokens.Level1` — 1dp. An elevated button.
    case level1
    /// `ElevationTokens.Level2` — 3dp. A menu group.
    case level2
    /// `ElevationTokens.Level3` — 6dp. A FAB.
    case level3
    /// `ElevationTokens.Level4` — 8dp.
    case level4
    /// `ElevationTokens.Level5` — 12dp.
    case level5

    /// The key light: tight, close, and directly under the shape.
    var key: (radius: CGFloat, y: CGFloat, opacity: Double) {
        switch self {
        case .level0: return (0, 0, 0)
        case .level1: return (1, 1, 0.30)
        case .level2: return (1, 1, 0.30)
        case .level3: return (1.5, 1, 0.30)
        case .level4: return (1.5, 2, 0.30)
        case .level5: return (2, 4, 0.30)
        }
    }

    /// The ambient light: broad, soft, and offset further down.
    var ambient: (radius: CGFloat, y: CGFloat, opacity: Double) {
        switch self {
        case .level0: return (0, 0, 0)
        case .level1: return (1.5, 1, 0.15)
        case .level2: return (3, 2, 0.15)
        case .level3: return (4, 4, 0.15)
        case .level4: return (5, 6, 0.15)
        case .level5: return (6, 8, 0.15)
        }
    }
}

public extension View {
    /// Casts Material's shadow for `elevation`. See ``ExpressiveElevation``.
    func expressiveElevation(_ elevation: ExpressiveElevation) -> some View {
        let key = elevation.key
        let ambient = elevation.ambient
        return shadow(color: .black.opacity(key.opacity), radius: key.radius, y: key.y)
            .shadow(color: .black.opacity(ambient.opacity), radius: ambient.radius, y: ambient.y)
    }
}
