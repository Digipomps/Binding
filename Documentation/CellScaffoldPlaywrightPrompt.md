# CellScaffold Playwright Prompt

Use this in the active `CellScaffold` thread when it is ready to add browser smoke coverage for the conference demo.

## Why This Exists

We need a browser-level safety net for the conference demo on staging.

This is a layer **over** auth/bridge debugging, not a replacement for it.

That means:
- keep protocol/auth/admission logging and targeted server-side debugging
- add browser smoke tests to prove the user-visible flow still works
- capture screenshots/traces/videos when the demo fails in staging

## What To Build

Add a small `Playwright` smoke suite for conference demo flows in `CellScaffold`.

Prefer a minimal, maintainable setup over a large framework rollout.

## Coverage Goals

1. Participant demo smoke
   - open the participant portal entry point used in staging/demo
   - verify headline and at least a few core summaries/counts
   - verify that at least one safe participant action produces visible feedback

2. Organizer demo smoke
   - open the organizer control tower entry point used in staging/demo
   - verify headline and core organizer panels
   - verify that at least one safe organizer action produces visible feedback

3. Perspective connection smoke
   - verify that the participant and organizer pages use coherent conference concepts
   - examples: sessions, recommendations, meetings/requests, published content, counts, titles

4. Failure capture
   - save screenshot on failure
   - save trace on failure
   - save page HTML or a reduced DOM snapshot if helpful

## Guardrails

1. Do not replace auth/bridge debugging with UI waits.
   - If a websocket/admission/auth problem exists, the smoke tests should expose it clearly.

2. Prefer stable selectors.
   - Use explicit test ids or accessibility labels if needed.
   - Avoid brittle CSS-path assertions.

3. Keep the first version staging-focused and small.
   - We want demo confidence quickly.

4. Report demo impact.
   - If a smoke test fails, explain whether it blocks:
     - participant demo
     - organizer demo
     - the connection between them

## Suggested Deliverables

1. `Playwright` setup committed in `CellScaffold`
2. one participant smoke test
3. one organizer smoke test
4. one minimal cross-perspective coherence check
5. short run instructions
6. note on how this complements existing auth/bridge debugging

## Prompt For The CellScaffold Thread

```text
Add a minimal Playwright smoke suite to CellScaffold for the conference demo on staging. This must be a browser-level verification layer over existing auth/bridge debugging, not a replacement for it. Focus on one participant flow and one organizer flow that match the demo entry points used by Binding and staging. Verify that the participant portal and organizer control tower render meaningful visible state, and that at least one safe action on each side produces visible GUI feedback. Capture screenshots and traces on failure. Prefer stable selectors such as explicit test ids or accessibility labels over brittle DOM paths. Document how to run the smoke tests and explain any remaining failures in terms of demo impact.
```
