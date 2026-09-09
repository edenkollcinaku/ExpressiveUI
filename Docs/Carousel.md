# Carousel

A scrollable row whose items change size as they pass through it, so the list reads as one object
with a focus rather than as a strip of cards.

![Multi-browse and uncontained carousels, light and dark](Images/carousel-overview.png)

```swift
ExpressiveCarousel(photos, preferredItemWidth: 186, itemSpacing: 8) { photo in
    Image(photo.name).resizable().scaledToFill()
}
.frame(height: 205)
```

Uncontained — every item the same width, with the one at the edge deliberately cut off:

```swift
ExpressiveCarousel(photos, itemWidth: 186, itemSpacing: 8) { photo in ... }
    .frame(height: 205)
```

Give it a height; it takes the width it is offered.

## How it actually works

Items do not own their sizes. The **viewport** owns a list of keylines — positions with sizes
attached — and an item takes whichever size belongs to wherever it has scrolled to. That inversion
is the component.

The arrangement is searched for rather than chosen. A small item wants to be a third of a large one,
a medium item wants to be halfway between them, and Material tries every plausible count of large,
medium and small items, fitting each candidate to the container by bending the small items first,
then the medium ones, then — reluctantly — the large ones. Whichever candidate bent the large item
least is the one you see. That is why `preferredItemWidth` is *preferred*: 186pt in a 360pt viewport
becomes 186 exactly if it fits, and something else if it does not.

Two consequences worth knowing:

- **Items are masked, not scaled.** A small item is a large item with most of it clipped away, so
  text does not shrink into unreadability as it leaves — it is cropped. Compose does the same thing,
  and content near the edges of an item will be cut.
- **Sizes are continuous while dragging.** An item passing from the medium keyline to the large one
  is interpolated between them, so the row breathes rather than stepping.

## The ends

The default arrangement puts the large items at the start, medium and small trailing. Left alone,
that would mean the first item could never be large at the start of the list, and the last item
could never be large at the end.

So the strategy precomputes a *step* per keyline. Each step moves one keyline from one side of the
focal range to the other, walking the focal range towards the container's edge one item at a time —
which is also what guarantees every item passes through focus rather than jumping into it. Scrolling
within a shift distance of either end interpolates between whichever two steps the offset falls
between, and snapping uses the step that belongs to the item being snapped to.

Scroll to the end of a multi-browse carousel and you will see the arrangement mirror itself: small,
medium, then the last item at full size against the trailing edge.

## What was ported

The whole algorithm, from `androidx.compose.material3.carousel`:

| This | Compose |
| --- | --- |
| `CarouselArrangement` | `Arrangement` — the cost search, `fit`, `calculateLargeSize` |
| `CarouselKeyline`, `CarouselKeylineList` | `Keyline`, `KeylineList`, `keylineListOf` and the pivot resolution |
| `multiBrowseKeylineList`, `uncontainedKeylineList` | the same, including the medium item's cut-off sizing |
| `CarouselStrategy` | `Strategy` — start and end steps, shift distances, interpolation points |
| `snapPositionOffset` | `getSnapPositionOffset` |

Not ported: the hero and full-screen layouts, and vertical carousels.

## Sizes

| Token | Value |
| --- | --- |
| `MinSmallItemSize` | 40 |
| `MaxSmallItemSize` | 56 |
| `AnchorSize` | 10 |
| `MediumLargeItemDiffThreshold` | 0.85 |

The item shape defaults to a 28pt corner — Material's extra-large shape — and is a parameter.
