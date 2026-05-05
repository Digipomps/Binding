# Skeleton Editor (Binding)

This page documents the in-app editor used to modify a loaded `CellConfiguration.skeleton` in Binding.

## Scope
- Edit mode works on the currently loaded skeleton (`workingCopy`) and does not mutate source config until `Apply`.
- View mode renders the committed skeleton only.

## UI layout
- The mode switch (`view` / `edit`) remains in the main window (`ContentView`).
- On macOS, editor tools are shown as two floating `NSPanel` windows:
  - `Elements` panel
  - `Inspector` panel (parameters + modifiers)
- The floating panels are moveable, resizable, and can be positioned outside the main window.
- Panel frame positions are autosaved:
  - `SkeletonEditor.ElementsPanel`
  - `SkeletonEditor.ModifiersPanel`

## Elements panel
- Shows a linearized tree of skeleton nodes.
- Supports:
  - Selecting an element.
  - Inserting a new element (from supported element kinds).
  - Deleting the selected node (except root).

## Inspector panel
The inspector has two sections for the selected element.

### Parameters
- Supports add/edit/delete for element fields such as:
  - `text`, `endpoint`, `name`, `keypath`, `sourceKeypath`, `targetKeypath`, `placeholder`
  - `label`, `topic`, `filterTypes`, `axis`, `spacing`, `width`, `padding`, `isOn`
  - `resizable`, `scaledToFit`
- Available parameter keys are filtered by element type.
- Invalid user input is validated and shown inline.
- Some required fields are intentionally not removable:
  - `keypath` on `Reference`, `Button`, `Toggle`
  - `label` on `Button`, `Toggle`
  - `topic` on `Reference`

### Modifiers
- Supports add/edit/delete of `SkeletonModifiers`.
- Available modifier keys are filtered by element type.
- Typed editing is supported for bool/int/double/string values.

## Editing lifecycle
- Entering edit mode initializes editor state from the rendered skeleton.
- `Undo` / `Redo` operate on the editor working copy.
- `Discard` restores the original snapshot.
- `Apply` commits the working copy and reloads the view model with updated configuration.

## Key implementation files
- `Binding/ContentView.swift`
- `Binding/SkeletonEditor/EditorState.swift`
- `Binding/SkeletonEditor/SkeletonTreeMutations.swift`
- `Binding/SkeletonEditor/SkeletonTreeQueries.swift`
- `Binding/SkeletonEditor/EditorSelectableSkeletonView.swift`
- `Binding/SkeletonEditor/SkeletonEditorPanels.swift`
- `Binding/SkeletonEditor/SkeletonEditorFloatingPanelsController.swift`
- `Binding/SkeletonEditor/SkeletonElementParameterCatalog.swift`
- `Binding/SkeletonEditor/SkeletonModifierCatalog.swift`
