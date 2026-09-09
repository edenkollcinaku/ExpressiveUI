import SwiftUI

/// Material 3 Expressive's motion scheme, which is where the snap comes from.
///
/// Compose does not hand-tune a spring per component: it names six, and every component asks for one
/// of them by role. The values here are `ExpressiveMotionTokens`' own damping ratios and stiffnesses,
/// converted into the two numbers SwiftUI's spring takes — for a unit mass, `response` is
/// `2π / √stiffness`, and `dampingFraction` is the damping ratio unchanged.
///
/// The split that matters is *spatial* against *effects*. Anything that moves or resizes gets a
/// spatial spring, which is loose enough to overshoot slightly. Anything that only changes colour or
/// opacity gets an effects spring, which is critically damped and roughly three times faster —
/// a colour that eases as slowly as a movement reads as a fade, and fading is what makes a control
/// feel soft when the Android one does not.
public enum ExpressiveMotion {
    /// `SpringDefaultSpatial`: damping 0.8, stiffness 380.
    public static let defaultSpatial = Animation.spring(response: 0.322, dampingFraction: 0.8)
    /// `SpringFastSpatial`: damping 0.6, stiffness 800. What a button group's press uses.
    public static let fastSpatial = Animation.spring(response: 0.222, dampingFraction: 0.6)
    /// `SpringSlowSpatial`: damping 0.8, stiffness 200.
    public static let slowSpatial = Animation.spring(response: 0.444, dampingFraction: 0.8)

    /// `SpringDefaultEffects`: damping 1.0, stiffness 1600.
    public static let defaultEffects = Animation.spring(response: 0.157, dampingFraction: 1)
    /// `SpringFastEffects`: damping 1.0, stiffness 3800. Colour changes land in about a tenth of a
    /// second, which is what reads as instant without cutting.
    public static let fastEffects = Animation.spring(response: 0.102, dampingFraction: 1)
    /// `SpringSlowEffects`: damping 1.0, stiffness 800.
    public static let slowEffects = Animation.spring(response: 0.222, dampingFraction: 1)
}
