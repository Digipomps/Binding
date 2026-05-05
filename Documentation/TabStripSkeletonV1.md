# Tab Strip Skeleton V1

This document defines the first practical contract for tab-like navigation in skeleton-driven surfaces without introducing a brand-new `SkeletonElement` yet.

## Goal

Support tab-like launchers that:

- load a `CellConfiguration` when activated
- can be composed at the top or bottom of a surface
- keep the portable skeleton contract small
- avoid creating a Binding-only tab API that other scaffold clients must later reverse-engineer

## V1 Decision

V1 uses `SkeletonList` plus style metadata and existing selection/activation payloads.

It does **not** introduce a new `TabView` or `TabStrip` element in the skeleton spec yet.

Reasoning:

- `SkeletonList` already supports `selectionStateKeypath`, `selectionActionKeypath`, and `activationActionKeypath`
- selection payloads can already carry full row objects, including embedded `CellConfiguration`
- composition with `VStack` already gives us deterministic top/bottom placement
- the renderer cost stays local to one existing primitive instead of expanding the shared spec immediately

## Contract Shape

### Container

Represent the tab strip as a `SkeletonList` with:

- `selectionMode = single`
- `selectionPayloadMode = item`
- `selectionStateKeypath` pointing to local tab state
- `activationActionKeypath` pointing to a cell action that extracts `selected.configuration` and loads it
- `modifiers.styleRole = "tabstrip"`

Optional style classes:

- `"top-pinned"`
- `"bottom-pinned"`
- `"compact"`
- `"prominent"`

These are renderer hints only. Layout truth still comes from skeleton composition order.

### Row object schema

Each tab row should be a `ValueType.object` with this shape:

```json
{
  "id": "agenda",
  "title": "Agenda",
  "badge": "3",
  "icon": "calendar",
  "configuration": {
    "...": "CellConfiguration payload"
  }
}
```

Required fields:

- `id`
- `title`
- `configuration`

Optional fields:

- `badge`
- `icon`
- `subtitle`

`icon` and `badge` are part of the row contract even if a generic fallback renderer only shows `title` at first.

## Activation Contract

The activation target should accept the standard `SkeletonList.selectionPayload(trigger: .activate, ...)` envelope.

For single selection, the relevant payload shape is:

```json
{
  "selectionMode": "single",
  "trigger": "activate",
  "selectedIndex": 0,
  "selected": {
    "id": "agenda",
    "title": "Agenda",
    "configuration": {
      "...": "CellConfiguration payload"
    }
  }
}
```

The receiving cell action should:

1. read `selected`
2. extract `selected.configuration`
3. decode it as `CellConfiguration`
4. forward it to the porthole/orchestrator load path

Recommended action names:

- `tabs.loadSelectedConfiguration`
- `tabs.activate`

V1 deliberately keeps this action outside the generic skeleton spec. It belongs in the owning cell, not in the renderer.

## Top-Pinned Example

```json
{
  "VStack": [
    {
      "List": {
        "elements": [
          {
            "id": "agenda",
            "title": "Agenda",
            "badge": "3",
            "icon": "calendar",
            "configuration": {
              "name": "Agenda Surface"
            }
          },
          {
            "id": "chat",
            "title": "Chat",
            "icon": "bubble.left.and.bubble.right",
            "configuration": {
              "name": "Chat Surface"
            }
          }
        ],
        "selectionMode": "single",
        "selectionStateKeypath": "tabs.selected",
        "activationActionKeypath": "tabs.loadSelectedConfiguration",
        "selectionPayloadMode": "item",
        "modifiers": {
          "styleRole": "tabstrip",
          "styleClasses": ["top-pinned"]
        }
      }
    },
    {
      "ScrollView": {
        "axis": "vertical",
        "elements": [
          { "Text": { "text": "Panel content" } }
        ]
      }
    }
  ]
}
```

## Bottom-Pinned Example

```json
{
  "VStack": [
    {
      "ScrollView": {
        "axis": "vertical",
        "elements": [
          { "Text": { "text": "Panel content" } }
        ]
      }
    },
    {
      "List": {
        "elements": [
          {
            "id": "home",
            "title": "Home",
            "configuration": {
              "name": "Home Surface"
            }
          },
          {
            "id": "settings",
            "title": "Settings",
            "configuration": {
              "name": "Settings Surface"
            }
          }
        ],
        "selectionMode": "single",
        "selectionStateKeypath": "tabs.selected",
        "activationActionKeypath": "tabs.loadSelectedConfiguration",
        "selectionPayloadMode": "item",
        "modifiers": {
          "styleRole": "tabstrip",
          "styleClasses": ["bottom-pinned"]
        }
      }
    }
  ]
}
```

## Renderer Expectations For The Later CellProtocol Pass

When we implement renderer support for `styleRole = "tabstrip"`, the renderer should:

- render the list horizontally
- support overflow by horizontal scrolling, not forced compression
- keep activation manual when panel switching is not instantaneous
- distinguish selected state and focus state clearly
- allow title-only fallback if icon/badge data is present but not renderable on a given client

## Non-Goals For V1

V1 does not attempt to solve:

- nested tab hierarchies
- draggable tab reordering
- close buttons on tabs
- sticky behavior independent of skeleton composition
- a generic inline panel-host abstraction in the skeleton spec

Those can be added later if the first contract proves itself across clients.
