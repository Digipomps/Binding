# Attachment Surface Thread Prompt (Binding)

Use this prompt when implementing Binding-side rendering for the shared attachment surface contract defined in `CellProtocolDocuments/Prompts/AttachmentSurface_ThreadPrompt.md`.

## Goal

Consume the shared attachment contract in Binding and render the shared attachment field as a first-class native editing surface, with platform-appropriate file picking and drag/drop behavior while preserving the same semantics as web/Porthole.

## Important Precondition

This prompt assumes the shared protocol contract has been defined in `CellProtocol` and is available in the version of the dependency used by `Binding`.

If the shared contract is not merged or not yet available in this repo:

- do not invent a Binding-only attachment model
- do not close the gap with a product-specific workaround as the final solution
- stop after identifying exactly which protocol/API pieces are still missing
- document the missing dependency and the smallest renderer work that can begin once it lands

## Requirements

Implement Binding renderer support for the shared attachment element and its shared value/state/action payloads so that:

This is renderer work, not protocol design work. `Binding` should consume the contract, not redefine it.

- macOS can support drag-and-drop plus an explicit attach dialog
- iPhone/iPad can support an explicit picker flow even when drag-and-drop is unavailable or secondary
- preview, replace, remove, retry, and error states use the same shared value/state/action model
- Binding does not fork the protocol contract into a private native-only representation

## Native Rendering Expectations

### macOS

- Show a visible drop target when `supportsDrop == true`
- Support dropping files/images from Finder or other apps
- Provide an explicit attach button that opens the appropriate native picker
- Keep keyboard-accessible actions for replace/remove/open

### iPhone / iPad

- Show a strong empty state with an `Attach…` action as the primary path
- Use the appropriate native picker mechanism for the accepted content types
- Treat drag-and-drop as optional enhancement, not the only interaction path

## Execution Order

1. Confirm which `CellProtocol` types and payloads are already available in this checkout.
2. Identify the general Binding rendering/editor layer that must consume them.
3. Implement the generic native renderer behavior there.
4. Prove the behavior with one real skeleton-driven editor surface.
5. If anything is still blocked by protocol gaps, document the exact gap instead of papering over it locally.

## Behavior Rules

- The renderer must preserve the shared typed action payload model.
- Local platform APIs may produce temporary URLs/providers, but the durable value written back must still match the shared `AttachmentValue` contract.
- Preview should be compact and field-local.
- Errors should be shown inline with a retry path when possible.
- If multiple attachments are not allowed, the UI should clearly present `Replace` instead of pretending append is supported.

## Suggested Platform Hooks

- macOS: native drop destination + file importer/open panel
- iOS/iPadOS: file importer and photo/media picker as appropriate
- SwiftUI/AppKit/UIKit integration is up to the implementer, but the outward behavior must stay protocol-aligned

## Out Of Scope

- defining new protocol payloads that should live in `CellProtocol`
- solving this only inside one conference/profile editor
- adding a Binding-only representation that other renderers cannot consume

## Acceptance Criteria

- A skeleton-driven editor in Binding can render an empty attachment field, an in-progress upload state, and an attached preview state.
- The same `CellConfiguration.skeleton` that works in Porthole also works in Binding without changing the product contract.
- Users always have a visible non-drag path to attach a file.

## Verification

At minimum:

- focused renderer/editor tests for the new element
- one sample configuration proving the field renders in Binding
- manual validation notes for macOS and one touch-first surface if automated coverage is limited
