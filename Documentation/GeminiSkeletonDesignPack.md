# Gemini Skeleton Design Pack

This document is a focused handoff package for external design review of Skeleton-based UI in HAVEN/Binding.

Use it when asking Gemini or another model to propose UI improvements without breaking the current runtime model.

## What Skeleton Is

- `Skeleton` is the declarative UI DSL used by `Porthole`.
- `Porthole` is the runtime/control surface that loads a `CellConfiguration`, absorbs referenced cells, and renders the configuration's `skeleton`.
- The renderer is SwiftUI-based, but the design surface is described as Skeleton elements such as `VStack`, `HStack`, `Text`, `Image`, `List`, `Reference`, `Button`, `Grid`, `Section`, `ScrollView`, `TextField`, and `TextArea`.

Primary reference:
- [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/Porthole-and-skeleton.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/Porthole-and-skeleton.md)

Element and modifier references:
- [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonElements_Detailed.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonElements_Detailed.md)
- [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonModifiers.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonModifiers.md)

## Runtime Model Gemini Must Respect

These are hard boundaries. Design suggestions should stay inside them.

- Do not propose a new runtime primitive just to improve layout.
- Do not propose replacing `Porthole` or bypassing the absorbed-cell model.
- Do not propose direct remote field URLs inside skeleton internals when a top-level `cellReference` with a `label` already exists.
- Do not treat Skeleton as a freeform scene graph, AR layer, or canvas engine.
- Do not redesign the app around a new navigation architecture.
- Do not suggest that requester-local draft state should be put on the shared flow.

Safe rules:
- Absolute endpoints belong in `cellReferences`.
- Skeleton internals should use label-relative addressing.
- When an element requires a URL-like path, prefer `cell:///Porthole/<label>...`.
- Shared chat/message state can be on feed/flow.
- Unsent draft/composer state should remain requester-local and be read through `get`.

## Supported UI Building Blocks

Gemini should assume the following are the normal, safe building blocks:

- `VStack`
- `HStack`
- `ZStack`
- `ScrollView`
- `Section`
- `Grid`
- `List`
- `Reference`
- `Text`
- `Image`
- `Button`
- `TextField`
- `TextArea`
- `Picker`
- `Toggle`
- `Divider`

And these common modifiers:

- layout: `padding`, `width`, `height`, `maxWidthInfinity`, `maxHeightInfinity`, `hAlignment`, `vAlignment`
- surface: `background`, `cornerRadius`, `borderWidth`, `borderColor`, `shadowRadius`, `shadowX`, `shadowY`, `shadowColor`, `opacity`, `hidden`
- text: `foregroundColor`, `fontStyle`, `fontSize`, `fontWeight`, `lineLimit`, `multilineTextAlignment`, `minimumScaleFactor`

## Current Chat-Specific Truths

The current conference chat is not a generic messenger app. It is a participant conference follow-up surface built on top of local preview/snapshot logic in Binding.

Chat contract reference:
- [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/ScaffoldChat.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/ScaffoldChat.md)

Important constraints:
- The chat already works technically.
- `TextArea`/composer already exists.
- Message thread, focused participant/thread, action suggestions, and back-navigation already exist.
- We want the UI to feel more like a traditional chat without changing the underlying control/data model.
- On iPhone portrait, the chat should be one clear column.
- On iPad/Mac, the main conversation should still read as one conversation, even if extra context panels exist.

## Current Conference Chat Source Files

These are the main truth sources Gemini should be aware of:

- Chat workbench skeleton/UI:
  - [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift)
- Chat snapshot/state logic:
  - [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift)
- Porthole/Skeleton renderer:
  - [/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonView.swift](/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellApple/Cells/Porthole/Utility%20Views/Skeleton/Suggestion/SkeletonView.swift)

Useful adjacent conference references:
- Participant portal and conference UI composition:
  - [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift)
- Canonical conference shells in CellScaffold:
  - [/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/Skeleton/ConferenceShellConfigurationFactory.swift](/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/Skeleton/ConferenceShellConfigurationFactory.swift)

## What Kind of Design Feedback Is Useful

Good feedback:
- make the thread easier to read as a conversation
- improve incoming vs outgoing visual distinction
- improve composer hierarchy and spacing
- reduce dashboard feel in the chat surface
- suggest responsive layout rules for iPhone vs iPad/Mac
- suggest which cards should remain and which should be visually compressed
- suggest how metadata should be shown without overwhelming the conversation

Bad feedback:
- “build a new custom canvas/chat engine”
- “move chat into a totally different architecture”
- “use a new runtime primitive”
- “replace absorbed cell references with direct remote URLs”
- “put unsent drafts on the shared event feed”

## Recommended Reading Order For Gemini

If Gemini can read multiple files, this is the best order:

1. [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/Porthole-and-skeleton.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/Porthole-and-skeleton.md)
2. [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonElements_Detailed.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonElements_Detailed.md)
3. [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonModifiers.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonModifiers.md)
4. [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/ScaffoldChat.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/ScaffoldChat.md)
5. [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift)
6. [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift)

## Expected Output From Gemini

Ask Gemini for:

- a short explanation of what makes the current UI feel dashboard-like rather than chat-like
- a concrete layout proposal for iPhone portrait
- a concrete layout proposal for iPad/Mac
- phase 1 changes with low implementation risk
- phase 2 changes that can come later
- things to avoid so the design stays compatible with Skeleton/Porthole

## Short Summary You Can Paste Alongside The Files

Use this if you want to give Gemini a compact framing:

> This UI is rendered through HAVEN Skeleton inside Porthole. Please propose visual and interaction improvements only. Do not suggest new runtime primitives, new app architecture, direct remote URLs inside skeleton internals, or shared-feed drafts. Respect the absorbed-cell model, label-relative references, and requester-local composer state. Focus on making the conference chat feel more like a traditional readable chat on iPhone, iPad, and Mac.
