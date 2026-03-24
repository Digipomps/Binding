# Skeleton Elements — Detailed Reference

This document describes the supported properties for each Skeleton element type, how they are encoded/decoded, and what they imply for rendering. Examples use the canonical JSON shape produced/consumed by the current Codable implementations.

Subscription & filtering
- Certain elements (List, Reference) can subscribe to Flow updates through the view model.
- Use `topic` to select which messages to display.
- Use `filterTypes: [String]` to restrict by FlowElement type (e.g., `event`, `alert`, `content`).

- Skeleton elements represents the json document that is being used to describe how to set up the view or user unterface and map it to the underlying cells. Skeleton elements (SkeletonDescription) is a part of CellBase must never refer to 


## Common: SkeletonModifiers

Supported fields and their rendering effects:
- `padding: Double?` — Adds uniform padding around the element (points).
- `maxWidthInfinity: Bool?` — If true, expands width to the maximum available.
- `maxHeightInfinity: Bool?` — If true, expands height to the maximum available.
- `width: Double?` — Fixed width constraint (points).
- `height: Double?` — Fixed height constraint (points).
- `hAlignment: String?` — Horizontal alignment: `leading`, `center`, `trailing`.
- `vAlignment: String?` — Vertical alignment: `top`, `center`, `bottom`.
- `background: String?` — Background color (hex `#RRGGBB` or `#RRGGBBAA`).
- `cornerRadius: Double?` — Corner radius (points).
- `shadowRadius: Double?`, `shadowX: Double?`, `shadowY: Double?`, `shadowColor: String?` — Shadow parameters.
- `borderWidth: Double?` — Border line width in points; if set > 0, a border is drawn.
- `borderColor: String?` — Border color hex; defaults to semi-transparent black if omitted.
- `opacity: Double?` — Opacity 0.0–1.0.
- `hidden: Bool?` — If true, element is hidden.
- Typography (for text-like elements):
  - `foregroundColor: String?` — Text color hex.
  - `fontStyle: String?` — Named style (e.g., `body`, `headline`).
  - `fontSize: Double?` — Explicit font size.
  - `fontWeight: String?` — `ultraLight`…`black`.
  - `lineLimit: Int?` — Max lines.
  - `multilineTextAlignment: String?` — `leading`, `center`, `trailing`.
  - `minimumScaleFactor: Double?` — Minimum scale when shrinking text.

These modifiers are optional per element; unsupported modifiers for a given element are ignored by the renderer.

JSON example (as nested `modifiers`):
```json
{
  "Text": {
    "text": "Hello",
    "modifiers": {
      "foregroundColor": "#222222",
      "fontStyle": "headline",
      "padding": 8,
      "cornerRadius": 6,
      "background": "#EFEFEF"
    }
  }
}

