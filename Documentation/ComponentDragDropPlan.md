# Component Drag/Drop Plan (Binding)

Date: 2026-03-11

## Goal
Add a component-oriented drag/drop flow for Binding's skeleton editor so users can drag compatible cells such as chat into the current canvas, drop them at valid positions, update the skeleton safely, and maintain `cellReferences` consistently.

## Product Decision
- Use a dedicated component palette, not the top toolbar, as the primary source of draggable components.
- On macOS, the palette should be a floating utility panel alongside the existing `Elements` and `Inspector` panels.
- On iPhone, the palette should live in a bottom drawer/sheet in edit mode, opened from a single toolbar button.
- Do not use runtime cell menus as the main droppable surface.
- Menus may expose `Insert into selected container` as a secondary command, but composition should happen through visible drop slots in the canvas.
- Components with no compatible drop target in the current selection/context should be hidden from the contextual palette.

## Why This Shape Fits Binding
- Binding already has path-based skeleton mutation in `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/SkeletonTreeMutations.swift`.
- Binding already tags library results with compatibility hints via `supportedInsertionModes` and `supportedTargetKinds` in `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift`.
- Binding already passes editor context into Full Library in `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/FullLibraryView.swift`.
- The missing piece is an explicit insertion contract that translates `dragged component` + `drop position` into `skeleton mutation` + `cellReference merge`.

## Proposed Model

### 1. Editor document becomes the unit of undo/redo
Today `EditorState` only tracks `SkeletonElement`. That is too narrow for component insertion because a drop may mutate both `skeleton` and `cellReferences`.

Add:

```swift
struct EditorDocument: Equatable {
    var configuration: CellConfiguration
    var selectedNodePath: SkeletonNodePath?
}
```

`EditorState` should move from:
- `viewerSnapshot: SkeletonElement?`
- `workingCopy: SkeletonElement?`

to:
- `viewerSnapshot: EditorDocument?`
- `workingCopy: EditorDocument?`

This keeps undo/redo atomic for:
- insert component
- remove component
- reorder component
- merge/rename references
- prune orphaned references

### 2. Introduce explicit component recipes
Dragging a generic full `CellConfiguration` is too ambiguous. A root workbench and an embeddable component are not the same thing.

Add:

```swift
enum ComponentSourceKind: String, Codable {
    case palette
    case library
    case menu
}

enum ComponentRole: String, Codable {
    case rootScene
    case embeddedWidget
}

struct ComponentPaletteItem: Identifiable, Codable, Transferable {
    var id: String
    var title: String
    var subtitle: String?
    var icon: String
    var recipe: ComponentInsertionRecipe
    var sourceKind: ComponentSourceKind
}

struct ComponentInsertionRecipe: Codable, Equatable {
    var id: String
    var displayName: String
    var role: ComponentRole
    var supportedInsertionModes: [FullLibraryInsertionIntent]
    var supportedTargetKinds: [String]
    var referenceTemplate: [CellReference]
    var skeletonTemplate: SkeletonElement
    var preferredDropBehavior: PreferredDropBehavior
}

enum PreferredDropBehavior: String, Codable {
    case appendIntoContainer
    case insertBeforeTarget
    case insertAfterTarget
    case replacePlaceholder
}
```

Rules:
- A component recipe must always describe the fragment to insert, not only the backing cell.
- Chat should have a dedicated embedded recipe, separate from the current full chat workbench.
- Library entries can expose both:
  - root configuration
  - optional embedded component recipe

### 3. Represent valid drop targets explicitly
The editor needs deterministic hit-testing and predictable UX. Do not infer final mutation directly inside the drop handler.

Add:

```swift
enum DropPlacement: Equatable {
    case intoContainer(at: SkeletonNodePath, index: Int)
    case beforeNode(at: SkeletonNodePath)
    case afterNode(at: SkeletonNodePath)
    case replaceNode(at: SkeletonNodePath)
    case root
}

struct DropTargetDescriptor: Identifiable, Equatable {
    var id: String
    var path: SkeletonNodePath
    var placement: DropPlacement
    var frameKey: String
    var label: String
    var targetKind: String
    var isEnabled: Bool
    var rejectionReason: String?
}
```

Target kind mapping should be editor-owned and simple:
- `vstack`
- `hstack`
- `scrollview`
- `section`
- `grid`
- `zstack`
- `text`
- `image`
- `button`
- `toggle`
- `reference`
- `root`

### 4. Resolve valid targets through one service
Add:

```swift
enum DropTargetResolver {
    static func targets(
        for recipe: ComponentInsertionRecipe,
        document: EditorDocument
    ) -> [DropTargetDescriptor]
}
```

Resolution rules:
- If recipe does not support `.component`, return only `.root` when allowed.
- Container nodes expose `intoContainer`.
- Leaf nodes expose `beforeNode` and `afterNode` through their parent.
- Empty root container exposes `intoContainer(..., index: 0)`.
- If no valid targets exist, remove the component from the contextual palette.

This is the mechanism that answers the requirement:
"Komponenter uten kompatiblet drop-target bør fjernes."

### 5. Separate skeleton insertion planning from reference merging
The drop operation should have two deterministic phases.

Add:

```swift
struct SkeletonInsertionPlan: Equatable {
    var placement: DropPlacement
    var fragment: SkeletonElement
    var resultingSelectionPath: SkeletonNodePath?
}

struct ReferenceMergeResult: Equatable {
    var mergedReferences: [CellReference]
    var rewrittenFragment: SkeletonElement
    var insertedLabelsByEndpoint: [String: String]
}
```

Flow:
1. Resolve drop placement.
2. Merge references into the document configuration.
3. Rewrite fragment keypaths if any labels had to change.
4. Insert fragment into skeleton.
5. Select inserted node.

### 6. Add a dedicated reference merge service
Add:

```swift
enum ReferenceMergeService {
    static func merge(
        recipeReferences: [CellReference],
        into existing: [CellReference],
        fragment: SkeletonElement
    ) -> ReferenceMergeResult
}
```

Rules:
- If same endpoint already exists with same label, reuse it.
- If same endpoint exists with another label, prefer the existing label and rewrite inserted fragment to that label.
- If requested label already points to another endpoint, generate a stable new label such as `chat2`.
- Preserve existing subscriptions and `setKeysAndValues`.
- Canonicalize inserted fragment to label-relative access, aligned with `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/Porthole-and-skeleton.md`.

This service should reuse the same endpoint identity rules already present in `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ContentView.swift`.

### 7. Support safe removal and orphan pruning
Deleting a component should optionally clean up its unique references.

Add:

```swift
struct ReferenceUsageReport: Equatable {
    var referencedLabels: Set<String>
    var unusedTopLevelLabels: Set<String>
}

enum ReferenceUsageAnalyzer {
    static func analyze(
        skeleton: SkeletonElement?,
        references: [CellReference]
    ) -> ReferenceUsageReport
}
```

Deletion flow:
- Remove selected node.
- Recompute used labels from skeleton JSON/keypaths.
- Remove top-level `cellReferences` no longer used anywhere.
- Keep shared references if still used by other fragments.

## Proposed File Changes

### New files
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/EditorDocument.swift`
  - Defines `EditorDocument`.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/ComponentInsertionRecipe.swift`
  - Defines palette item and insertion recipe types.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/DropTargetResolver.swift`
  - Builds valid drop targets from selection and skeleton tree.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/ReferenceMergeService.swift`
  - Merges `cellReferences` and rewrites inserted fragment labels.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/ReferenceUsageAnalyzer.swift`
  - Finds used and orphaned labels.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/ComponentPalettePanel.swift`
  - Shared component palette UI for compact and regular layouts.

### Existing files to change
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/EditorState.swift`
  - Promote state from `SkeletonElement` to `EditorDocument`.
  - Add `applyComponentDrop(recipe:placement:)`.
  - Keep undo/redo at document level.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/SkeletonTreeMutations.swift`
  - Add explicit insertion helpers for:
    - `before path`
    - `after path`
    - `replace path`
  - Current `insert into parentPath` is not enough for visual drop slots.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/SkeletonTreeQueries.swift`
  - Add helper APIs for parent/child insertion planning and node kind classification.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/EditorSelectableSkeletonView.swift`
  - Expose drop slots and highlight valid targets.
  - Surface geometry anchors for drop hit-testing.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ContentView.swift`
  - Add component palette button to the compact toolbar.
  - Host component drawer/panel.
  - Route Full Library add/drag actions to `insert component` when in edit mode.
  - Commit/export the full edited `CellConfiguration`, not only the skeleton.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/FullLibraryView.swift`
  - Add support for returning `ComponentPaletteItem` or `ComponentInsertionRecipe` in edit mode.
  - Hard-filter or disable incompatible entries using valid target analysis.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/SkeletonEditorFloatingPanelsController.swift`
  - Add third floating panel on macOS for components.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift`
  - Add explicit embedded-component catalog entries, starting with chat.
  - Distinguish `root` workbench from `component` recipe metadata.

## UI Design

### macOS
- Keep the existing `Elements` and `Inspector` panels.
- Add a third `Components` floating panel.
- Drag origin lives in the components panel and in Full Library search results.
- Valid drop slots appear inline over the canvas while dragging.

### iPhone
- Do not add more draggable affordances to the top bar than a single palette button.
- Use a bottom drawer in edit mode:
  - collapsed: compact strip with search and recent components
  - expanded: searchable palette with grouped component cards
- While dragging, dim invalid targets and highlight only valid slots.
- If there are zero valid slots, the drawer should hide incompatible components entirely.

### Menus
- Do not turn edge menus into generic drop hosts.
- Optional secondary action:
  - `Insert into selected container`
- Menus remain optimized for launching or loading full scenes, not layout composition.

## Concrete First Slice

### Pilot component: Embedded chat card
Do not start with the current full chat workbench.

Add a compact recipe:
- one chat status header
- message list area
- compact composer
- `chat` reference with feed subscription

Reason:
- avoids nested full-screen workbench behavior
- avoids oversized drag previews
- exercises reference merge and flow-backed rendering
- gives a realistic component users will actually embed

Suggested metadata:

```swift
ComponentInsertionRecipe(
    id: "chat.embedded.card",
    displayName: "Chat Card",
    role: .embeddedWidget,
    supportedInsertionModes: [.component],
    supportedTargetKinds: ["root", "vstack", "section", "scrollview", "grid"],
    referenceTemplate: [CellReference(endpoint: "cell://staging.haven.digipomps.org/Chat", label: "chat")],
    skeletonTemplate: embeddedChatCardSkeleton(),
    preferredDropBehavior: .appendIntoContainer
)
```

## Editor API sketch

```swift
@MainActor
extension EditorState {
    func applyComponentDrop(
        recipe: ComponentInsertionRecipe,
        placement: DropPlacement
    ) {
        guard var document = workingCopy else { return }

        let merge = ReferenceMergeService.merge(
            recipeReferences: recipe.referenceTemplate,
            into: document.configuration.cellReferences ?? [],
            fragment: recipe.skeletonTemplate
        )

        document.configuration.cellReferences = merge.mergedReferences
        document.configuration.skeleton = SkeletonDropApplicator.apply(
            merge.rewrittenFragment,
            placement: placement,
            to: document.configuration.skeleton
        )

        replaceWorkingCopy(with: document)
    }
}
```

`SkeletonDropApplicator` can start as a thin wrapper over `SkeletonTreeMutations`.

## Implementation Order
1. Introduce `EditorDocument` and migrate `EditorState`.
2. Change `ContentView` apply/export path to commit full configuration edits.
3. Add `ComponentInsertionRecipe` and one hardcoded embedded chat recipe.
4. Add `DropTargetResolver` and inline drop-slot overlays in the canvas.
5. Add `ReferenceMergeService`.
6. Wire compact iPhone drawer and macOS floating `Components` panel.
7. Teach Full Library to return embedded recipes in edit mode.
8. Add orphan-reference pruning on delete.

## Validation Checklist
- Dragging a chat card into an empty root works.
- Dragging into a populated `VStack` inserts at the intended index.
- Undo removes both inserted skeleton fragment and any newly added references.
- Redo restores both.
- Dropping a second chat component reuses or deterministically renames labels.
- Copy JSON exports canonical label-relative skeleton references.
- Removing the last chat fragment prunes unused `chat` reference if no other node uses it.
- iPhone edit mode remains usable with one hand and without toolbar overflow.

## Risks To Avoid
- Do not treat every full `CellConfiguration` as safely embeddable.
- Do not let drop handlers mutate references and skeleton separately without one undo step.
- Do not keep incompatible components visible if they can never be dropped in the current context.
- Do not overload edge menus with spatial composition semantics.
- Do not export absolute runtime field URLs from inserted fragments.

## Recommended Next Coding Task
Implement only the first vertical slice:
- `EditorDocument`
- `ComponentInsertionRecipe`
- one embedded chat recipe
- `DropTargetResolver`
- `ReferenceMergeService`
- bottom drawer on iPhone

That slice is small enough to finish cleanly and large enough to validate the architecture.
