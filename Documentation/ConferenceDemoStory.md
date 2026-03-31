# Conference Demo Story

This is the recommended end-to-end demo story for the conference surfaces. It
is written to stay as close to production behavior as possible while still
being robust enough for staging and Binding fallback flows.

## Primary Goal

A person watching the demo should understand, without prior training:

1. why a participant sees a given person as relevant
2. how the participant selects that person
3. how direct chat starts
4. where the conversation is visible
5. that organizer-side surfaces are reading the same conference reality

## Surfaces

Participant entry point:

- `Conference Participant Portal Dashboard`

Organizer entry point:

- `Conference Control Tower`

Supporting participant workbenches:

- `Conference Nearby Radar · Full oversikt`
- `Conference Participant Chat`

## Current Truth

What already works well:

- inline participant selection with `Vis i siden`
- explicit `Start chat`
- explicit `Åpne chatflate`
- local bounded personas in Binding
- deterministic chat demo fallback in Binding

What still needs the final Scaffold/staging pass:

- stable staged personas that drive the same story without relying on local
  fallback
- organizer-side visibility that clearly reflects the same direct follow-up
- a final demo path that feels real, not only technically wired

## Recommended Happy Path

### Phase 1: Open Participant Context

Open:

- `Conference Participant Portal Dashboard`

Show:

- agenda summary
- recommended people
- discovery section
- nearby radar if available on device

Narration:

- the participant keeps personal state local
- the same conference world is still projected into shared shells and organizer
  views

### Phase 2: Choose One Person

Pick one strong candidate, ideally a stable governance persona such as the
staged equivalent of `Ane Solberg`.

Click:

- `Vis i siden`

Show:

- why that person is relevant
- the selected-person profile
- the next obvious actions:
  - `Start chat`
  - `Marker for oppfølging`
  - `Be om møte`

Narration:

- the first click stays inline so the user does not lose context

### Phase 3: Start Direct Chat

Click:

- `Start chat`

Expected visible result:

- selected person now indicates that chat is ready
- shared-thread count or equivalent relation state changes
- recent follow-up state updates
- the action becomes `Åpne chatflate`

Narration:

- the participant has not just clicked a decorative button
- a real follow-up state now exists in the conference model

### Phase 4: Open Dedicated Chat Surface

Click:

- `Åpne chatflate`

Expected visible result:

- dedicated conference chat surface opens
- selected participant name is obvious
- first reply is visible
- compose area is visible
- user can send one custom message
- staged or bounded persona can answer consistently

Narration:

- the conversation is now explicit and visible as its own conference surface
- this is better than forcing the user to infer chat from badges or hidden hub
  state

### Phase 5: Return To Organizer

Open:

- `Conference Control Tower`

Show:

- that participant-side follow-up exists in the same conference reality
- any organizer-readable shared-thread, follow-up, request, or relationship
  signal connected to the participant action

Narration:

- organizer and participant are not looking at separate invented worlds
- they are reading different surfaces over the same conference state

## UX Rules For The Final Demo

- first click stays inline
- second step may open a dedicated workbench
- the selected person must visually dominate over the recommendation list
- the chat surface must look like a real conversation, not only a status panel
- every primary button must show a visible outcome in the GUI

This especially applies to:

- `Vis i siden`
- `Start chat`
- `Åpne chatflate`
- `Marker for oppfølging`
- `Be om møte`
- `Søk governance`

## Non-Negotiables

- no demo-only auth shortcut that breaks the real conference model
- no hidden state that only Binding can understand
- no wall-clock-sensitive bootstrap that makes the demo flaky
- no “chat succeeded” state unless a visible thread or message is actually
  available

## Final Acceptance Criteria

The final demo story is ready when all of this is true:

- participant selection is obvious
- chat start is obvious
- chat opening is obvious
- one custom user-written message can be sent
- one stable persona reply can be shown
- organizer can later point at the resulting shared follow-up state
- the same core story works in:
  - CellScaffold/web
  - Binding
  - smoke/demo automation

## Recommended Safest Live Demo Path

Until the organizer side is equally polished, the safest live demo path is:

1. open participant portal
2. choose the strongest staged match
3. `Start chat`
4. `Åpne chatflate`
5. send one custom follow-up
6. show the stable persona reply
7. switch to control tower and point at the same follow-up state

This is the path the final Scaffold pass should optimize for first.
