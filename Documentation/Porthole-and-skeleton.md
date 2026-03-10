# Porthole and Skeleton

This document explains how Porthole and Skeleton relate in the project, how data flows, and how to add or modify views.

## Overview
- **Porthole** is a Cell that can receive and send UI configuration and content via `flow` and `get/set` operations.
- **Skeleton** is a declarative description of UI (a small DSL) with elements like `.VStack`, `.HStack`, `.Text`, `.Image`, `.List`, `.Reference`, `.Button`, etc.
- **The client (app)** renders Skeleton in SwiftUI using `SkeletonView(element:)` and updates when Porthole publishes new elements on the stream.

## Architecture
1. Porthole (server/cell):
   - Exposes a `flow` of content. The content can be:
     - An object that decodes directly to `SkeletonElement`, or
     - A `CellConfiguration` that contains a `skeleton` field.
   - Accepts `set(keypath:value:)` calls to switch configuration or trigger actions.

2. Client (UI):
   - Owns a view model that connects to Porthole, listens to `flow`, and publishes the current `SkeletonElement` to the view.
   - Can send `set(...)` to instruct Porthole to load a new configuration.

## View model: PortholeBindingViewModel
The consolidated view model for Porthole is `PortholeBindingViewModel` in `PortholeViewModel-Binding.swift`.

Responsibilities:
- Connect to Porthole once (`connectIfNeeded()`).
- Subscribe to `flow` and decode incoming objects into `SkeletonElement`.
- Expose `@Published var currentSkeleton` that the UI renders.
- Send `set(keypath:value:)` when the user selects a new configuration (via `load(configuration:)`).

Minimal usage:
```swift
@StateObject private var viewModel = PortholeBindingViewModel()

var body: some View {
    PortholeCanvas(skeleton: viewModel.currentSkeleton)
        .task { await viewModel.connectIfNeeded() }
}
```

## Edit mode (Binding)
- Binding can switch between `view` and `edit` mode for the currently loaded `CellConfiguration.skeleton`.
- In `edit` mode, the rendered skeleton is interactive and supports selecting elements directly in the canvas.
- Element updates are made on a working copy and then applied back to the configuration with `Apply` (or reverted with `Discard`).
- On macOS, editor tools are shown in two floating utility windows (`Elements` and `Modifiers/Inspector`) that can be moved outside the main app window.
- For implementation details, see [Documentation/SkeletonEditor.md](SkeletonEditor.md).

## Absorbed cell references and skeleton addressing
When a `CellConfiguration` contains a top-level `cellReference`, that reference should normally be treated as an absorbed runtime dependency of `Porthole`, not as a separate direct fetch target for every skeleton element.

Example:

```json
{
  "cellReferences": [
    {
      "endpoint": "cell://staging.haven.digipomps.org/AdminOverview",
      "label": "adminOverview"
    }
  ]
}
```

In this case the preferred skeleton access pattern is:

- `adminOverview.someKey`
- `cell:///Porthole/adminOverview.someKey`

The pattern that should be avoided in skeletons is:

- `cell://staging.haven.digipomps.org/AdminOverview/someKey`

Reason:

- The top-level reference tells `Porthole` what to connect/absorb.
- Skeleton elements should then address the absorbed cell through the reference label.
- This avoids unnecessary direct resolver lookups and avoids opening a new remote path for each skeleton field.
- It also makes exported `CellConfiguration` JSON more stable and portable.

## Current Binding rule set
As of the current `Binding` implementation:

- `cellReferences` keep their absolute endpoint.
- Skeleton internals should prefer label-relative keypaths when talking to absorbed cells.
- If a skeleton element requires a `url` field instead of a pure keypath, it should target `cell:///Porthole/<label>...` rather than the remote endpoint directly.
- `Copy JSON` should export the canonicalized form above, not absolute runtime field URLs.

This is now important for both menu-loaded and library-loaded configurations, because both go through the same normalization path in `Binding/ContentView.swift`.

## Why some configurations failed to load
Some generated workbenches used direct skeleton URLs such as:

- `cell://staging.haven.digipomps.org/AdminOverview/status`
- `cell://staging.haven.digipomps.org/AdminOverview/state`

That bypassed the absorb model. It also interacted badly with Binding's pre-probe of references, which could reject the configuration before the skeleton was shown.

The corrected pattern is:

- top-level `cellReference`: `cell://staging.haven.digipomps.org/AdminOverview` with label `adminOverview`
- skeleton text/runtime reads:
  - `cell:///Porthole/adminOverview.status`
  - `cell:///Porthole/adminOverview.state`
  - or relative keypaths like `adminOverview.start`, `adminOverview.reload`, etc. where the element type supports keypath-based access

## Deferred work: fully generic relative references
Fully generic relative references are not implemented yet.

What is meant by "fully generic":

- a skeleton should be able to say `adminOverview.status`
- and have that resolved relative to the current focused container cell, not implicitly relative to `Porthole`

This is intentionally on hold because the current renderer contract in `CellProtocol` still assumes `Porthole` as the default base for non-absolute keypaths in several places.

To support fully generic relative references cleanly, `CellProtocol` needs a renderer-level change:

1. Introduce an explicit skeleton/container base context for URL and keypath resolution.
2. Make `SkeletonText`, `SkeletonButton`, `SkeletonTextField`, `SkeletonTextArea`, `SkeletonList`, and `SkeletonReference` resolve non-absolute addresses relative to that context instead of hardcoding `cell:///Porthole`.
3. Preserve backward compatibility so existing `Porthole`-centric skeletons still work.
4. Keep `cellReferences` as the place where absolute discovery/transport endpoints live.

Until that is done, the safe rule is:

- absolute endpoint in `cellReferences`
- label-relative addressing inside skeleton
- `cell:///Porthole/<label>...` when a `url` field is required
