# CellScaffold Conference Parity Prompt

Use this when the active `CellScaffold` thread is ready to align with the current Binding/demo flow.

## Goal

Bring `CellScaffold` conference behavior into full parity with the Binding demo flow for:
- `Conference Participant Portal Dashboard`
- `Conference Control Tower`
- related conference preview/admin shells used by `ConfigurationCatalog`

## Current Binding Expectations

Binding now assumes and/or benefits from the following:

1. Organizer access stays stable after requester resolution.
   - No identity mutation when alias/context mappings are added.
   - Organizer/admin proof should remain valid through shell state loading.

2. `Conference Control Tower` is a real demo entry point.
   - It should be available from `ConfigurationCatalog`.
   - It should render meaningful organizer-facing workspace/access/content/ops state.

3. Participant and organizer surfaces should feel connected.
   - The same conference scenario should be understandable from both sides.
   - Naming, summaries, and live shell data should make that relationship obvious.

4. Preview wrappers should stay honest.
   - If data is partial, preview can degrade gracefully.
   - But organizer/participant previews should not silently diverge from the real shell semantics.

## Concrete Parity Checks For CellScaffold

1. Verify that `ConferenceAdminPreviewShell` and `ConferenceParticipantPreviewShell` expose data that matches the real shell state closely enough for Binding preview/demo use.

2. Re-check organizer admission for foreign requesters backed by:
   - same-entity credential
   - organizer/admin role grant

3. Re-check that `BrowserClientIdentityVault` never regenerates key material for an existing UUID when only alias/context mappings change.

4. Confirm that the conference catalog/configuration layer still includes:
   - organizer control-tower entry
   - participant portal entry
   - any conference AI/copilot entry expected in the demo story

5. Confirm that read-heavy organizer sections are populated and not placeholder-only:
   - workspace
   - ownership/access
   - published content
   - operations/insights

6. Confirm that participant-facing summaries remain readable and consistent with organizer state:
   - recommendations
   - saved sessions / agenda
   - meetings / requests
   - sponsor/shared-thread summaries if present

## Demo-Focused UX Questions For Scaffold

These should be answered explicitly, not implicitly:

1. Which organizer action is the safest live demo action?
   - Prefer something reversible and visibly stateful.

2. Which participant action best shows the relation to organizer state?
   - Example: recommendation refresh, meeting request, saved session, or follow-up.

3. Which fields are required to make the story legible without narration?
   - Titles
   - badges/counts
   - short summaries
   - one visible action per surface

## Prompt For The CellScaffold Thread

```text
Bring CellScaffold conference behavior into parity with the current Binding demo flow. Focus on ConferenceParticipantPreviewShell, ConferenceAdminPreviewShell, ConferenceAdminShell, and the related ConfigurationCatalog entries. Verify that organizer/admin access remains stable for credential-backed foreign requesters, that BrowserClientIdentityVault never mutates key material for an existing identity UUID when adding alias/context mappings, and that both participant and organizer surfaces expose live, legible state suitable for a connected demo story. Check that preview wrappers do not diverge materially from the real shell semantics. Document any remaining parity gaps in terms of concrete demo impact, not generic architecture.
```
