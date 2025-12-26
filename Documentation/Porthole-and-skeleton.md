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
