# Button group

Material 3 has two of these: a **standard** group, where a row of buttons sits 12pt apart, and a
**connected** group, where segments sit 2pt apart with their corners squared off against each other
to read as one control. Both squeeze: pressing a button widens it and its neighbours give up the
space.

## Standard

![A standard button group, light and dark](Images/button-group-overview.png)

```swift
ExpressiveButtonGroup(items: [
    .init(label: "Reply") { reply() },
    .init(label: "Forward") { forward() },
    .init(label: "Star", isOn: $starred)
])
```

The initialiser you call decides the kind of button, matching Compose's two:

| This | Compose | Behaviour |
| --- | --- | --- |
| `.init(label:systemImage:action:)` | `clickableItem` | Runs an action. Always filled. |
| `.init(label:systemImage:isOn:)` | `toggleableItem` | Carries a checked state. Filled when checked, `surfaceContainer` when not. |

### Weights

A button sizes itself to its label. Give it a `weight` and it takes that share of whatever is left
over instead — the same rule as Compose's `Modifier.weight`:

```swift
ExpressiveButtonGroup(items: [
    .init(label: "Cancel", weight: 1) { dismiss() },
    .init(label: "Save", weight: 2) { save() }
])
```

### Overflow

Buttons that do not fit collapse into a menu behind a trailing indicator, which is what Compose's
`overflowIndicator` does. Nothing is dropped and nothing wraps: the menu carries the same labels,
icons and actions, and the indicator is hidden from accessibility while everything fits.

A group whose buttons all carry weights never overflows — they share the width they are given.

## Connected

![A connected button group, light and dark](Images/connected-button-group-overview.png)

One choice out of a set:

```swift
ExpressiveConnectedButtonGroup(selection: $range, options: [
    .init(value: .day, label: "Day"),
    .init(value: .week, label: "Week"),
    .init(value: .month, label: "Month")
])
```

Any number of choices — pass a `Set` and the segments toggle independently:

```swift
ExpressiveConnectedButtonGroup(selection: $activeFormats, options: formats)
```

### Anatomy

![The connected group's corners: outer full, inner 8pt, selected full on both sides, 2pt spacing](Images/connected-button-group-anatomy.png)

The corner rules *are* the component. A segment is a pill where the group meets the outside and
barely rounded where one segment meets the next; a selected segment goes full on both sides, because
it is the one being read rather than part of a run.


## The squeeze

Pressing a button expands it by 15% of its width — `ButtonGroupDefaults.ExpandedRatio` — and its
neighbours give up that much between them, so the group's own width never changes. Pass
`expandedRatio:` to change it; `0` turns it off.

A neighbour is never asked to give up more than 24pt — `ButtonDefaults.ContentPadding`, past which
its label would start being clipped rather than tightened. When the cap bites, the pressed button
grows by less than the ratio asked for, so the row's own width still never changes.

## Motion

Compose does not tune a spring per component; it names six and every component asks for one by role.
`ExpressiveMotion` carries all six, converted from `ExpressiveMotionTokens`:

| Role | Damping | Stiffness | Used for |
| --- | --- | --- | --- |
| `fastSpatial` | 0.6 | 800 | the press squeeze, the switch's thumb, the FAB menu opening |
| `fastEffects` | 1.0 | 3800 | every colour change |

Keeping those apart is what makes the control feel like the Android one. A colour that eases as
slowly as a movement reads as a fade; on an effects spring it lands in about a tenth of a second,
while the geometry keeps the looser spatial spring and its slight overshoot.

## Geometry

| Token | Standard | Connected |
| --- | --- | --- |
| `ContainerHeight` | 40 | 40 |
| `BetweenSpace` | 12 | 2 |
| `InnerCornerCornerSize` | — | 8 |
| `PressedInnerCornerCornerSize` | — | 4 |
| Outer corner | full | full |

## Colour

| State | Container | Content |
| --- | --- | --- |
| Selected, or a plain action | `primary` | `onPrimary` |
| Unselected | `surfaceContainer` | `onSurfaceVariant` |

Disabled drops to 38% opacity, per button or for the whole group.
