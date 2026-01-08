// Skeleton Modifiers and New Elements
//
// This page describes the shared modifiers (SkeletonModifiers) available across Skeleton elements, the new element stubs, and includes a Quick Start with examples.
//
// Common Modifiers (SkeletonModifiers)
// The following fields are supported on all elements via `modifiers`:
// - padding: Double — uniform padding
// - width, height: Double — fixed dimensions
// - maxWidthInfinity, maxHeightInfinity: Bool — expand to available space
// - hAlignment: leading | center | trailing — horizontal alignment
// - vAlignment: top | center | bottom — vertical alignment
// - background: Hex color (#RRGGBB or #RRGGBBAA)
// - cornerRadius: Double
// - shadowRadius: Double, shadowX: Double, shadowY: Double, shadowColor: Hex color
// - opacity: Double
// - hidden: Bool
//
// Typography modifiers for Text
// When applied to `Text` elements, the following fields are also supported:
// - foregroundColor: Hex color
// - fontStyle: largeTitle | title | title2 | title3 | headline | subheadline | body | callout | footnote | caption | caption2
// - fontSize: Double (overrides preset; used with fontWeight)
// - fontWeight: ultralight | thin | light | regular | medium | semibold | bold | heavy | black
// - lineLimit: Int
// - multilineTextAlignment: leading | center | trailing
// - minimumScaleFactor: Double
//
// New Elements
// - Divider
//   - Renders a SwiftUI Divider
//   - Supports `modifiers`
//
// - ScrollView
//   - Fields: `axis` ("horizontal" or omitted for vertical), `elements` (array of SkeletonElement)
//   - Renders a ScrollView containing the provided elements
//   - Supports `modifiers`
//
// - Section
//   - Fields: `header` (SkeletonElement?), `footer` (SkeletonElement?), `content` (array of SkeletonElement)
//   - Renders a vertical stack: optional header, content, optional footer
//   - Supports `modifiers`
//
// - ZStack
//   - Fields: `elements` (array of SkeletonElement)
//   - Overlays elements in a ZStack
//   - Supports `modifiers`
//
// - Grid (LazyVGrid)
//   - Fields: `columns` ([fixed|flexible|adaptive]), `spacing` (Double?), `elements` (array of SkeletonElement)
//   - Supports `modifiers`
//
// - Toggle (bound to keypath)
//   - Fields: `label` (String), `keypath` (String; absolute `cell:///...` or relative)
//   - Fetches initial value via `Meddle.get` and writes updates via `Meddle.set`
//   - Relative keypaths are resolved as `cell:///Porthole/<keypath>`
//
// Quick Start
// This is a minimal example showing how to embed a Skeleton in JSON and render it.
//
// 1) Define your skeleton (see more in `Prompts/SkeletonExamples.json`):
// ```
// {
//   "VStack": [
//     { "Text": { "text": "Hello", "modifiers": { "fontStyle": "title2", "fontWeight": "semibold", "padding": 8 } } },
//     { "Toggle": { "label": "Enable feature", "keypath": "cell:///Porthole/settings.enableFeature" } }
//   ]
// }
// ```
//
// 2) Load and render
// - If you're embedding this skeleton in a CellConfiguration, add a reference pointing to a cell that knows how to render it (e.g., your Porthole or a ProfileWrapper). At runtime, the renderer (`SkeletonView` / `SkeletonElementView`) will traverse the structure and apply modifiers.
// - Toggle will read the initial value via `Meddle.get` and call `Meddle.set` on change.
//
// Tip: Use the examples in `Prompts/SkeletonExamples.json` as a starting point and compose them to build your UI.
//
// Examples
// See `Prompts/SkeletonExamples.json` for complete, runnable examples:
// - ZStack overlay
// - Adaptive Grid
// - Toggle bound to cell:/// keypath
// - ScrollView with sections
// - Horizontal cards (ScrollView .horizontal)
// - Mixed Grid (fixed + flexible)
// - Person Profile (basic profile fields)
//
// How to use the examples
// - Paste the desired JSON block into your skeleton source (e.g., in a CellConfiguration or a runtime generator).
// - For `Toggle`:
//   - `keypath` can be absolute (starts with `cell://`) or relative (resolved as `cell:///Porthole/<keypath>`).
//   - Toggle fetches the initial value via `Meddle.get` and sets new values via `Meddle.set` when the user toggles.
//
// Tips
// - Combine `modifiers` to achieve layout: padding, alignment, maxWidthInfinity, background, cornerRadius, shadow.
// - For text, use typography modifiers (fontStyle, fontSize, fontWeight, lineLimit, multilineTextAlignment, minimumScaleFactor) for consistent typography.


## Endpoint vs keypath and Porthole (OrchestratorCell)

There are two ways to point to a data source in skeleton JSON:

1) Endpoint (cell://...)
- A full `cell://` URL, e.g. `cell:///AppleIntelligence/ai.candidates`.
- `CellResolver` resolves the cell by name/UUID and ensures the correct instance (including scope/persistence).
- Then `get`/`set` (via `Resolver`) is called on the keypath after the last `/`.

2) Relative `keypath` (without endpoint)
- If you only write `"ai.candidates"`, this is interpreted as `cell:///Porthole/ai.candidates` for `List` (see `urlFromKeypath`).
- Porthole is an `OrchestratorCell` registered with scope `identityUnique` and persisted. The same Identity will reuse the same Porthole across app sessions.
- Benefit: Less verbosity when Porthole is your default hub/anchor for UI/state.

Choose based on whether you want to explicitly target a specific cell, or you’re working within the Porthole context.

Examples:

- Endpoint (explicit):
```json
{ "List": { "keypath": "ai.candidates" } }

import UIKit

class MyCustomView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .white
    }
    
    func updateContent(with text: String) {
        // Update the view content with the provided text
    }
}

## See also
- Skeleton elements reference: [Documentation/SkeletonElements.md](SkeletonElements.md)
- How to create a Cell: [Documentation/HowTo_CreateCell.md](HowTo_CreateCell.md)
