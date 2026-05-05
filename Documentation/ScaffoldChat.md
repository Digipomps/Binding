# Scaffold Chat Workbench

This document records the `Scaffold Chat` setup that currently works from `Binding`, what contract the workbench depends on, and where the hard boundaries are.

## Purpose
- Use `Binding` as a control surface for a shared chat running on staging.
- Let multiple clients absorb the same chat cell and observe the same sent messages and participant state.
- Keep unsent composer drafts private to the current requester.

## Runtime target
- Staging endpoint: `cell://staging.haven.digipomps.org/Chat`
- Workbench reference label: `chat`
- The `CellConfiguration` should keep the absolute endpoint in `cellReferences`.
- Skeleton internals should address the absorbed cell through `chat...` or `cell:///Porthole/chat...`.

## What works now

### Shared message state
- Message history is read from `chat.messages`.
- New messages are observed on topic `chat.message`.
- The workbench uses `SkeletonList(keypath: "chat.messages", topic: "chat.message")` so initial state and new events are merged in one list.

### Shared participant state
- Participants are read from `chat.participants`.
- Live participant updates are observed on topic `chat.participant`.
- The workbench uses the same `state + feed` pattern as messages.

### Private composer state
- Draft body is stored per requester under `chat.compose.body`.
- Format is stored per requester under `chat.compose.contentType`.
- Rich draft metadata is exposed through:
  - `chat.compose.state`
  - `chat.compose.previewRows`
- `compose.previewRows` is a convenience list with one row, intended for `SkeletonList`-based preview cards.

### Sending and clearing
- Send action: `chat.sendComposedMessage`
- Clear action: `chat.clearComposer`
- After send, the remote draft is cleared and the workbench refreshes the text area + preview.

### Formatting
- Supported formats:
  - `text/plain`
  - `text/markdown`
- Sent markdown messages render in the conversation list by using `SkeletonText.modifiers.styleRole = "markdown"`.
- Plain text messages are escaped server-side before markdown rendering so they do not accidentally render as formatted content.

## Why composer preview is not on the shared feed
Composer drafts are requester-scoped. The chat cell uses a shared `flow` publisher for the cell, so publishing draft events there would leak unsent text to every other subscriber of the same chat.

That is why the current contract is:
- shared things go on `chat.message`, `chat.participant`, `chat.status`
- private draft things are read via `get` on `compose.*`

## Renderer behavior that now matters
- `SkeletonTextArea` now persists to its target keypath while the user types, not only on submit.
- Local mutations bump a small UI refresh token in `PortholeViewModel`.
- `SkeletonList` reloads its `keypath` source when that refresh token changes.

This is what makes `chat.compose.previewRows` usable as a live preview inside the same workbench without leaking drafts onto the shared feed.

## Verified workbench contract
- `status`
- `state`
- `messages`
- `participants`
- `members`
- `compose.body`
- `compose.contentType`
- `compose.availableFormats`
- `compose.state`
- `compose.previewRows`
- `sendMessage`
- `sendComposedMessage`
- `clearComposer`

## Known limitations
- No reply/thread model yet.
- No delivery/read receipts yet.
- The live composer preview depends on the local workbench renderer refresh path; it is not a shared remote event stream.
- Other clients will only see the message after `sendComposedMessage`, not while the user is typing.

## Relevant files
- `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Cells/Chat/ChatCell.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Cells/Chat/ChatPresentation.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/CellListView.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/CellButtonView.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonView.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift`
