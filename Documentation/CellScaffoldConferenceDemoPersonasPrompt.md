Build the final conference demo story on top of the existing conference shells
and contracts. Do not invent a separate demo-only protocol. The goal is to make
the live demo feel production-like while still staying deterministic enough for
staging, Playwright, and Binding fallback flows.

## Mission

Add a small, stable set of staged conference personas and wire them so the
conference demo can reliably show:

- a participant chooses a relevant person
- a direct chat is started with that person
- the conversation is visible as an actual conference chat surface, not only as
  hidden shared-thread state
- organizer/control-tower surfaces can later point at the same shared follow-up
  state

## Important Context

Binding now already has a bounded local demo-persona layer and a dedicated
conference chat workspace. The persona shape is effectively:

- `name`
- `roleSummary`
- `publicProfileDetail`
- `fitContext`
- `conversationStyle`
- `suggestedOpening`
- `simulatedAgentSummary`
- `starterReply`

The cleanest outcome is that CellScaffold/staging emits persona metadata in a
compatible shape so Binding can consume staged personas without a second round
of UI or contract changes.

## What Must Be Implemented

Seed or bootstrap a small persona catalog on staging and make it reachable
through the normal conference preview/admin flows.

Recommended staged personas:

1. `conference-demo-gov`
   - display name close to `Ane Solberg`
   - governance / policy / public-sector interoperability
   - strongest default participant match

2. `conference-demo-design`
   - display name close to `Lea Heger`
   - service design / product / delivery
   - useful to show that not every good match is governance-only

3. `conference-demo-ops`
   - display name close to `Mads Hovden`
   - operations / interoperability / infrastructure / compliance
   - useful for nearby and practical follow-up

Optional:

4. `conference-demo-group-anchor`
   - stable persona used to make small-group follow-up demos deterministic

## Persona Requirements

Each persona must have:

- stable identity across runs unless explicitly reset
- stable display name and public profile
- stable role and interest cues
- deterministic first-reply behavior
- deterministic meeting / follow-up availability
- deterministic relevance to at least one participant path

The same persona must not silently rotate keys when aliasing, replay, or extra
configuration is added.

## Chat Requirements

The first direct-chat path must be deterministic.

Required first version:

- stable scripted opener
- stable scripted first reply
- persona-specific tone
- no fabricated access, grants, or proof state

Allowed later, but not required in the first landing:

- bounded AI-generated second or third reply

If AI replies are added, they must stay within persona and conference context.
Do not let them invent claims, access, sponsorship, or attendee history that
was not seeded.

## UX Requirements

The live happy path should be understandable without narration-heavy training.

A human observer should be able to see:

1. why a person was recommended
2. that the participant selected that person
3. that direct chat actually started
4. that the chat is visible as a dedicated conference surface
5. that organizer-side surfaces can later read the same follow-up reality

## Contract Guardrails

- do not bypass the real proof/auth model
- do not create a Binding-incompatible demo contract
- do not rely on fragile timing or race-sensitive bootstrap steps
- do not special-case the skeleton renderer with hidden app-only shortcuts
- prefer seeding real state over simulating impossible state in the UI

## Preferred Output Shape

Where practical, let staged person cards and/or chat/thread objects expose
persona metadata compatible with Binding’s bounded demo-persona provider:

- `demoPersona.name`
- `demoPersona.roleSummary`
- `demoPersona.publicProfileDetail`
- `demoPersona.fitContext`
- `demoPersona.conversationStyle`
- `demoPersona.suggestedOpening`
- `demoPersona.simulatedAgentSummary`
- `demoPersona.starterReply`

If a different nested shape is clearly better in Scaffold, document the mapping
explicitly.

## Acceptance Criteria

The work is done when the following are all true:

- `Conference Participant Portal` or its Scaffold equivalent can show a stable
  recommended person from staging
- `Start chat` reliably creates a direct follow-up path with one of the staged
  personas
- the participant can open an explicit chat surface and see at least:
  - the persona name
  - a first reply
  - the current thread context
- the organizer/control-tower side can identify that the follow-up exists, even
  if organizer chat UX is not yet perfect
- Playwright or smoke coverage can use the same personas and get the same first
  chat result repeatedly

## Deliverables

- staging bootstrap or seed path for the personas
- any required Scaffold wiring to make the direct-chat demo path explicit
- tests or smoke coverage where practical
- a short implementation note covering:
  - which personas were added
  - where they appear
  - what direct-chat path is now the safest live demo path
  - whether any remaining gap is UX-only or contract/runtime related
