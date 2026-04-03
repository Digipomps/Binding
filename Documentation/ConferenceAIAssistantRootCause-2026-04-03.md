# Conference AI Assistant Root Cause

Date checked: 2026-04-03

## Summary

`Conference AI Assistant` fails in Binding for a narrow reason:

- the participant-side conference context now loads correctly
- the embedded AI path does not
- Binding does not host a local `AIGateway`
- the live fallback depends on a readable staging `AIGateway` route
- that staging gateway path is not currently stable/readable from Binding over bridge

This is no longer a generic "chat UI" or "prompt field" problem.
It is a gateway access problem.

## What is already proven healthy

These parts are working:

- `Conference AI Assistant` can render the conference snapshot and prompt-ready participant context
- local conference startup no longer requires full auth/bootstrap just to open the AI surface
- the participant preview shell is therefore not the active blocker for this workspace

Visual proof from the earlier live sweep:

- `/tmp/binding-conference-smoke-20260403-181822/07-ai-assistant.png`

That screenshot shows:

- `Conference Snapshot` populated
- `Prompt-Ready Context` populated
- degradation starting at the `Copilot Setup` / `aiGateway.state` side

## Binding-side gateway reality

Current Binding runtime facts:

- local `AIGateway` is not registered in Binding
- Binding therefore tries:
  1. `cell:///AIGateway`
  2. `cell://staging.haven.digipomps.org/AIGateway`

The first step fails honestly because there is no local `AIGateway` cell in this app.

The second step is where the live failure sits.

## Concrete live evidence

When the AI assistant is opened and the proxy attempts the staging gateway path, Binding logs:

- `Did NOT find any EmitCell with name: AIGateway!!!`
- `send command: admit`
- `CONSUME Command cmd: sign`
- `Cloud Bridge connect failed with error: finishedWithoutValue`

What that means:

- Binding reached the remote bridge/admission layer
- this is not just a missing text field or an empty prompt
- the bridge never reaches a stable readable `AIGateway` cell for Binding to use

## Important architecture finding

CellScaffold documentation and tests strongly document `AIGateway` as:

- local endpoint: `cell:///AIGateway`

They do **not** currently provide the same kind of staging/demo publication proof that exists for:

- `ConferenceParticipantPreviewShell`
- `ConferenceAdminPreviewShell`

Relevant examples:

- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Documentation/AIGatewayCell.md`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Prompts/AIGatewayCell_Handover.md`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/CellScaffoldConferenceAdminPreviewStagingHandoff.md`

The preview-shell handoff/docs are explicit about staging/demo preview exposure.
The AI gateway docs are explicit about a local cell.

So the current parity gap is:

- Binding assumes a usable remote staging `AIGateway`
- the repo-grounded CellScaffold material only clearly guarantees a local `AIGateway`

## Practical conclusion

`Conference AI Assistant` in Binding does not currently fail because of:

- missing prompt text
- bad button wiring
- participant preview loading
- local auth bootstrap

It fails because:

- Binding has no local `AIGateway`
- the fallback staging `AIGateway` path is not presently giving Binding a stable readable bridge session

## Best next steps

There are only two honest ways forward:

1. Expose a real staging/demo-safe `AIGateway` route from CellScaffold

- equivalent in clarity to the preview-wrapper story for participant/admin
- documented and verified as a Binding-consumable remote cell

2. Give Binding a real local `AIGateway` implementation

- then `Conference AI Assistant` stops depending on staging bridge readability for the AI half

What should **not** be done:

- pretend the current bridge timeout is just a UI issue
- hide the failure behind generic "content unavailable" copy
- claim the embedded AI route is local when it is not

