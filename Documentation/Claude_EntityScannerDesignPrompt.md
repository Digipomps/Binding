# Claude Prompt: Entity Scanner UI Design

Use this prompt with Claude when we want grounded UI design proposals for `EntityScanner` in Binding.

## Prompt

```text
You are designing the user interface for `EntityScanner` in Binding.

Important: this is not a blank-slate speculative design exercise. You must stay grounded in the implementation model and contracts described below. You may propose new functionality, but only if it cleanly respects CellProtocol concepts and separation of concerns.

I am giving you the current ground-truth status so you do not invent the wrong architecture.

## Product context

Binding is evolving into a Personal Co-Pilot app. `EntityScanner` is a local Apple-framework-backed capability that discovers nearby entities, measures proximity, and helps the user decide whether to follow up.

The target experience is not a conference demo UI. It should feel like a high-trust Personal Co-Pilot surface for discovering nearby relevant people/entities and deciding whether to inspect published information, send an invitation, or start a chat.

## Ground-truth architecture

### 1. What EntityScanner is

`EntityScanner` is a local utility cell backed by Apple device frameworks. It is local to Binding / CellApple and should not be moved into a remote CellScaffold surface.

Its current responsibility is roughly:
- discover nearby peers
- emit nearby/proximity/contact events
- exchange signed contact proofs
- persist encounter summaries
- export encounter data

It is not currently the owner of:
- public profile publishing
- public profile directory search
- general chat storage
- arbitrary remote mini-app logic

Those belong elsewhere if needed, through additional cells and references.

### 2. What EntityScanner already exposes

Current scanner contract includes:
- `start`
- `stop`
- `invite`
- `requestContact`
- `acceptContact`
- `exportEncounter`
- `exportEncounterJSON`
- `capabilities`
- `encounters`

Current scanner flow/topics include:
- `scanner.capabilities`
- `scanner.found`
- `scanner.lost`
- `scanner.status`
- `scanner.connected`
- `scanner.proximity`
- `scanner.contact.pending`
- `scanner.contact.outgoing`
- `scanner.contact.received`
- `scanner.contact.established`
- `scanner.encounter.saved`
- `scanner.encounter.exported`
- `scanner.encounter.jsonExported`

Typical scanner event payload fields already include:
- `remoteUUID`
- `displayName`
- `status`
- `connected`
- `connectedDevices`
- `distanceMeters`
- `direction.x`
- `direction.y`
- `direction.z`
- capability fields such as `transportMode`, `precisionMode`, `supportsNearbyPrecision`

Persisted encounter summaries already include:
- remote identity/display information when verified
- `matchCount`
- `match`
- verification status
- transport/precision mode
- export actions

### 3. What Binding already does on top of EntityScanner

Binding already has a local nearby-radar enrichment layer over `EntityScanner`. This is currently conference-oriented, but it gives real ground-truth about the shape of useful state.

That local Binding layer already works with concepts such as:
- live entities list
- selected entity
- distance
- precise direction vs uncertain direction
- scanner lifecycle status
- capability description
- contact signal state
- purpose signal / verified overlap summary
- relevance badges and summaries
- selected entity actions
- local “radar layout” summary state

Important current truth rules:
- if we do not have trustworthy direction, the UI must not fake precise direction
- MPC-only peers may be shown as nearby, but direction remains uncertain
- distance may exist even when direction is uncertain
- signed contact verification is a stronger state than raw nearby proximity

### 4. Current relevance logic

Binding already models relevance in a simple but meaningful way:

- if there is no score yet:
  - treat it as “nearby first”
  - user may still inspect or request contact
- if verified and score >= 0.80:
  - strong / green match
- if verified and score >= 0.55:
  - good / yellow match
- if verified and below that:
  - weak / red match
- if unverified and score >= 0.65:
  - promising match
- if unverified and score >= 0.35:
  - moderate match
- if lower:
  - low relevance

For the design brief below, assume that low-relevance results should not be shown in the primary scanner results.

### 5. What the new Entity Scanner experience should support

The desired scanner experience should:
- show dynamically relevant nearby entities
- show how far away they are
- show which direction they are in, when direction is trustworthy
- show how relevant they are
- hide results that are below the chosen relevance threshold
- let the user inspect what is openly published by the visible nearby entities
- let the user send an invitation
- let the user start a chat

### 6. Important conceptual boundaries

If you need more functionality, you may propose it, but you must keep the architecture clean:

- `EntityScanner` should remain the local scanner / contact / proximity owner
- published profile data should come from a profile/public-directory style cell, not be invented inside the scanner
- chat should come from a chat cell / chat hub contract, not be stored ad hoc inside scanner state
- relevance should be explainable from available signals, not magical
- private data should not be shown just because a nearby signal exists
- only openly published data should be visible before stronger consent/contact states
- any invitation/chat action should fit existing CellProtocol interaction patterns: explicit actions, state transitions, get/set/flow, absorbed references, and requester-scoped local draft state where appropriate

You may propose:
- new local Binding-side adapter state
- new CellConfiguration composition patterns
- new CellScaffold cells or references for public profile / published metadata lookup
- new generic CellProtocol contracts if truly reusable

You may not propose:
- violating local-vs-remote boundaries
- bypassing explicit consent flows
- turning the scanner into a random social feed
- making up private data from nearby presence
- custom architecture that ignores CellProtocol concepts

## Your task

Design a new `EntityScanner` UI system for Binding that works on:
- phone
- iPad / tablet
- laptop / desktop

The design should feel like a Personal Co-Pilot tool, not a conference gimmick.

## What I want from you

Please produce a practical design proposal with these parts:

### 1. UX concept
Explain the overall UX concept for the scanner:
- what the user sees first
- how the scanner transitions from idle -> scanning -> visible matches -> selected entity -> invitation/chat
- what the emotional tone should be
- how to keep the UI calm even when nearby events are dynamic

### 2. Information hierarchy
Define the hierarchy for:
- scanner status
- visible nearby entities
- relevance
- distance
- direction certainty
- published public information
- invitation/contact status
- chat readiness / chat launch

### 3. Result filtering and visibility rules
This part is critical.

Propose explicit UI rules for:
- which entities should be visible by default
- what relevance threshold should hide a result completely
- whether hidden/low results should be collapsible or omitted
- how to distinguish:
  - high-confidence relevant result
  - medium-confidence result
  - nearby but low-value result
  - uncertain direction result
  - verified contact result

Use the existing relevance logic above as a starting point. If you change thresholds or classification, explain why.

### 4. Core components
Design the scanner component set, including at minimum:
- scanner hero/status block
- nearby entity card
- selected entity detail card
- direction/distance indicator
- relevance badge / confidence badge
- published profile preview panel
- invitation CTA
- request contact / verify contact CTA
- start chat CTA
- empty state
- scanning state
- denied capability / unsupported device state
- uncertain direction state
- no relevant entities state

For each component, describe:
- purpose
- main content
- important states
- behavior on phone/tablet/desktop
- whether it is local scanner state, public remote state, or chat-related state

### 5. Layout proposals by device class
Show layouts for:
- phone
- iPad
- desktop/laptop

Address:
- one-column vs multi-pane
- whether the selected entity gets a dedicated pane
- where the published profile preview lives
- where invitation/chat actions live
- how the scanner remains useful when there are 0, 1, few, or many relevant entities

### 6. Publicly published data preview
Design the UI for “what is openly published from nearby entities”.

Important:
- only openly published information should be shown
- the scanner must not imply access to private data
- the preview should help the user decide whether to invite / request contact / start chat

Propose what kinds of public data make sense to show, for example:
- display name
- headline / public role
- organization
- public purpose/interests
- public match context
- public profile summary

If you think new supporting functionality is needed, specify exactly where it belongs:
- scanner
- public profile directory / publisher cell
- matchmaking / ranking cell
- chat hub
- Binding-local adapter

### 7. Invitation and chat flows
Design the shortest coherent path from:
- seeing a relevant nearby entity
- to invitation / request contact
- to verified state
- to starting or opening chat

Be very explicit about:
- what actions are available before contact is verified
- what actions become available after verification
- how chat should appear
- when to show disabled states vs hidden states
- how to avoid dead ends

### 8. New functionality proposals
If the current system is missing functionality needed for a great scanner UI, propose it.

But every proposal must be categorized as one of:
- can be built now with current contracts
- needs Binding-local adapter/state only
- needs a new reusable CellProtocol contract
- needs a new CellScaffold cell/reference

For each new proposal, explain why it belongs there.

### 9. CellProtocol discipline
I want you to actively police the architecture.

Add a short section called:
`CellProtocol discipline check`

In that section, explicitly say:
- which parts stay local to Binding/CellApple
- which parts should be absorbed via cell references
- which parts should remain portable in `CellConfiguration`
- which parts should not be pushed into the scanner itself

### 10. Output format
Structure your answer like this:

1. Recommended scanner UX direction
2. Visibility / relevance model
3. Component library
4. Phone layout
5. Tablet layout
6. Desktop layout
7. Public profile preview design
8. Invitation + chat flow
9. New functionality proposals
10. CellProtocol discipline check
11. A short implementation roadmap

## Final instruction

Do not give me only visual moodboard language.
I need a design that could actually be implemented in Binding with CellConfiguration, local Apple-backed scanner state, and additional absorbed cells where necessary.

If you propose something beyond today’s functionality, keep it strict, modular, and reusable.
```

## Notes For Us

- This prompt intentionally separates local scanner truth, public published data, and chat ownership.
- It also pushes Claude to propose missing functionality without letting it smuggle everything into `EntityScanner`.
- A good next step after Claude answers would be a second prompt asking for Skeleton-oriented component recipes for the chosen direction.
