# Conference Control Tower Uplift Plan

Date: 2026-03-31

## Goal

Lift `Conference Control Tower` so it feels as intentional and legible as `Conference Participant Portal Dashboard`, while keeping the organizer surface canonical in CellScaffold and parity-friendly for Binding.

## Current read

- The latest staging deploy now serves useful organizer state for:
  - access and access requests
  - audience discovery
  - organizer insights
  - sponsor aggregate
  - simulation
- The main remaining data gap is the `system` section:
  - `system.status = "Live admin metrics unavailable."`
  - `system.topProcessSummary = "AdminOverview lookup failed: denied"`
- The organizer surface therefore no longer needs a placeholder-first rescue plan.
- It does need a clearer visual hierarchy and a stronger demo story.

## Design direction

Keep the same calm conference visual language as participant surfaces:

- dark canvas
- stronger section framing
- explicit status cards near the top
- fewer long text walls before first useful action
- clear difference between:
  - run-of-show / operations
  - audience / access
  - content / publication
  - sponsor / leads
  - system / observer metrics

## Recommended layout changes

### 1. Stronger top hero

Replace the current flat opening with a short organizer hero:

- `Conference Control Tower`
- one-sentence organizer purpose
- 3 to 4 badges:
  - conference scope
  - current ops pressure
  - access request count
  - sponsor / relation pulse

This should read like a control room, not a debug dump.

### 2. Pulse cards first

Bring the most important cards to the top in one adaptive grid:

- `Drift nå`
- `Audience access`
- `Insight pulse`
- `Sponsor pulse`

Each card should answer:

- what is live now
- what needs attention
- what is the next safe action

### 3. Make run-of-show its own lane

Operations should not be buried among other organizer sections.

Add a dedicated section for:

- current alerts
- session polling
- live thread activity
- simulation clock / playback

This becomes the “room is moving” part of the organizer story.

### 4. Make publishing legible

Published content currently risks reading as a generic unavailable CMS lane.

The content section should show:

- publication lifecycle
- current public surface summary
- draft / preview readiness
- next publishing action

This should make it obvious how admin work turns into the public conference surface.

### 5. Sponsor lane should read like a funnel

Sponsor information is more useful when it looks like a pipeline:

- lead-ready
- captured
- handed off
- cross-role relation context

If counts are zero, the cards should still read as an intentional empty funnel, not as failure.

### 6. System lane should degrade cleanly

Until `AdminOverview` access is fixed, the system section should be honest but still useful:

- keep the section
- show that observer metrics require stronger access
- avoid letting the whole page feel broken because one lane is denied

## Implementation order

1. Fix the remaining `system` observer path in CellScaffold staging.
2. Uplift the canonical organizer skeleton in CellScaffold, not Binding-only.
3. Verify the same improved organizer surface in:
   - staging web
   - Binding launcher path
4. Only then add extra polish if something still feels flat.

## Acceptance criteria

- The top third of the page immediately explains organizer status.
- The organizer can see a meaningful next action without reading long paragraphs.
- Zero-data states look intentional, not broken.
- `Conference Control Tower` feels like the organizer sibling of the participant dashboard.
- Binding and staging still render the same organizer story.
