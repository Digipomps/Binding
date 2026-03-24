# Conference Debug Playbook

This note captures the methods that worked during live debugging of the conference workbench configurations in Binding, what was changed, and what the next language model should do next.

## Scope
- `Conference AI Assistant`
- `Conference Participant Portal Dashboard`
- `Conference Partnering MVP`
- `Conference Sponsor Follow-up`

These configurations are defined in:
- `Cells/ConfigurationCatalogCell.swift`

The runtime/shell behavior that matters most lives in:
- `Binding/ContentView.swift`
- `Binding/Debug/BindingRuntimeDiagnostics.swift`
- `Scripts/ax_binding.swift`

## Methods That Worked

### 1. Build against local `CellProtocol`
Use the local package, not a stale remote checkout, so runtime fixes in `CellProtocol` are actually present in Binding.

Commands:

```bash
xcodebuild -workspace Binding.xcworkspace -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution build
swift test --filter SkeletonActionButtonExecutionTests
```

What this confirmed on 2026-03-22:
- Binding builds cleanly against local `CellProtocol`
- the conference prompt preset payload regression test passes

### 2. Use AX automation for reproducible GUI inspection
The most useful GUI tool for Binding has been:

```bash
swift Scripts/ax_binding.swift dump --app Binding --depth 10
swift Scripts/ax_binding.swift click --app Binding --query library --depth 10
swift Scripts/ax_binding.swift setText --app Binding --query conference --depth 10
```

Why this helps:
- it gives a structured view of what SwiftUI actually exposed through Accessibility
- it confirms button names, text field contents, and whether a sheet/panel is really open
- it is faster than relying only on screenshots

Important nuance from the organizer/live-library round on 2026-03-24:
- native `AXUIElement` access was more reliable than AppleScript `System Events`
- `System Events` often returned `count of entire contents = 0` or `missing value` for window buttons
- SwiftUI toolbar/titlebar controls were not consistently discoverable through the simpler AppleScript wrappers
- `Scripts/ax_binding.swift` is the better tool because it talks to `AXUIElement` directly
- the script now also traverses toolbar/titlebar related attributes, not only plain `AXChildren`

Practical takeaway:
- prefer `swift Scripts/ax_binding.swift dump ...` first
- only fall back to AppleScript for app activation or trivial window metadata
- do not assume that `System Events` failure means the Accessibility API itself is broken

### 3. Use OS screenshots only after AX confirms the expected state
For visual checks, this sequence worked reliably:

```bash
bash /Users/kjetil/.codex/skills/screenshot/scripts/ensure_macos_permissions.sh
python3 /Users/kjetil/.codex/skills/screenshot/scripts/take_screenshot.py --app Binding --mode temp
python3 /Users/kjetil/.codex/skills/screenshot/scripts/take_screenshot.py --list-windows --app Binding
```

Why this order matters:
- `AX` is better for state inspection
- screenshots are better for layout/visibility checks
- using both avoids guessing

For tricky SwiftUI sheets, two additional steps proved useful:

```bash
python3 /Users/kjetil/.codex/skills/screenshot/scripts/take_screenshot.py --app Binding --list-windows
swift -e '/* Vision OCR over screenshot to locate visible labels/buttons */'
```

Why:
- `--list-windows` separates the parent window from the sheet window
- OCR is a good fallback when AX exposes state but synthetic `AXPress` is still unreliable on a custom SwiftUI surface
- this made it possible to verify when `Conference Control Tower` and `Legg til i Porthole` were actually visible in `Full Library`

### 4. Use the in-app Debug panel early
The `Debug` button in Binding is currently the fastest way to understand why a configuration is not rendering.

Signals that mattered in this round:
- `Discovery skiller seg fra references`
- `bridge_description_deferred:wss://staging.haven.digipomps.org/bridgehead/ConferenceParticipantPreviewShell:timeout`

This helped separate:
- slow or blocked bridge/runtime issues
- configuration/schema issues
- shell UX issues

### 5. Always relaunch Binding from a clean process before a new GUI check
Stale debug sessions have caused false negatives before.

Useful sequence:

```bash
ps aux | rg '[B]inding(.app/Contents/MacOS/Binding|$)'
kill <pid>
open /Users/kjetil/Library/Developer/Xcode/DerivedData/Binding-bnzbjkzdqhtnnnfveahehmbivnwn/Build/Products/Debug/Binding.app
```

Also verify that old background processes are really gone:

```bash
ps aux | rg '/Binding.app/Contents/MacOS/Binding'
```

During the organizer round, stale terminal-launched Binding processes from older DerivedData roots kept competing with the active app. Killing them before re-open removed a lot of false GUI noise.

### 6. Prefer keyboard/default actions over tiny SwiftUI buttons
Small `borderedProminent` buttons embedded in SwiftUI list rows were significantly less reliable to hit via synthetic GUI events than:
- a top-level preview action
- a default keyboard action
- a dedicated demo-start control

This led to the following Binding UX changes:
- `Legg til i Porthole` moved higher in the `Full Library` preview panel
- `Cmd-Return` was wired to the selected preview action
- a dedicated `Start demo her` control now sets the chosen configuration as the demo start and loads it immediately

These are not only testing conveniences; they are better demo ergonomics for real users too.

## What Was Changed In This Round

### 1. Preserve explicit conference preset payloads
Problem:
- conference preset buttons such as `Daily brief` shared the same target keypath as the prompt editor
- cached field state could overwrite explicit button payloads at execution time

Fix:
- `CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonView.swift`
- explicit `SkeletonButton.payload` now wins over cached payload
- cached payload is only used when the button itself has no payload

Tests:
- `CellProtocol/Tests/CellBaseTests/SkeletonActionButtonExecutionTests.swift`

### 2. Make conference loading non-blocking after absorb
Problem:
- Binding kept Porthole blank while waiting for bridge/root probes to become readable
- this made conference loads feel frozen even when the absorb itself had already succeeded

Fix:
- `Binding/ContentView.swift`
- after successful absorb, Binding now shows the intended skeleton immediately
- root probing still runs, but now mainly drives status/error messaging instead of holding the whole UI white
- probe timing was shortened:
  - `maxAttempts`: `8 -> 5`
  - `perProbeTimeout`: `1.5s -> 0.9s`
  - `retryDelay`: `350ms -> 300ms`

UX outcome intended:
- user sees the actual conference UI sooner
- slow remote roots no longer hold the full surface blank
- remaining bridge issues are surfaced as status/warning, not as a total visual stop

### 3. Improve Full Library for demo flows and GUI robustness
Problems:
- `Full Library` organizer testing was too dependent on tiny row buttons and scroll position
- synthetic clicks against nested SwiftUI surfaces were inconsistent
- organizer/demo flows need a single clear "this is the start" interaction

Fixes:
- `Binding/FullLibraryView.swift`
- `Legg til i Porthole` is shown high in the preview pane
- `Cmd-Return` is bound to the selected preview action
- selected library items can now be marked as `Start demo her`
- the chosen demo-start configuration is persisted and auto-loaded by Binding

Runtime hookup:
- `Binding/ContentView.swift`
- demo-start persists through `@AppStorage`
- after bootstrap, Binding loads the stored demo-start configuration automatically

Intended outcome:
- cleaner conference demo startup
- less dependency on brittle GUI hit-testing
- easier parity between what the team wants to show and what Binding opens with

## What Was Observed

### Confirmed
- the prompt-preset fix is verified by test
- Binding build is green after the non-blocking load change
- the Debug panel is surfacing the real bridge symptom for conference preview cells
- staging `/health` and `/` return `200 OK`
- staging receives websocket requests for `GET /bridgehead/ConferenceParticipantPreviewShell/<uuid>`

### Still unstable
- the library search path was inconsistent in one live session and returned `Resultater (0)` for `conference` even though the direct catalog fallback had worked earlier
- the `ConferenceParticipantPreviewShell` bridge path still produced deferred-description timeout logs during live loading

That means the current remaining blocker is probably not the preset-button bug anymore. The more likely live blocker is the preview-shell remote bridge path.

## Current Likely Root Cause

The conference workbenches that depend on `cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell` can still stall on the remote preview-shell bridge.

The strongest current signal is:

```text
bridge_description_deferred:wss://staging.haven.digipomps.org/bridgehead/ConferenceParticipantPreviewShell:timeout
```

This suggests:
- the remote bridge is being established
- `description` retrieval is deferred or timing out on the Binding side
- the server-side route is alive, but the remote connect/admit flow is still unhealthy for this cell

Server log evidence from staging:

```text
GET /bridgehead/ConferenceParticipantPreviewShell/<uuid>
Got request for ConferenceParticipantPreviewShell
CONSUME Command cmd: admit
Got sign response
Got no signed data!
Identity could not prove ownership of private key!
******* Connect state was not connected!!!!
```

That points to a sharper hypothesis than a generic timeout:
- the preview-shell websocket route exists
- the session reaches `admit`
- the requester falls into an owner/member proof path
- ownership proof fails because signed data is missing or rejected
- Binding then sees a deferred-description / unreadable-root symptom on top

## Guardrails For The Next Model

- Do not commit `Binding.xcworkspace/xcuserdata/kjetil.xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist`
- Prefer `AX + screenshot + debug panel` together; using only one of them loses important signal
- Prefer native `AXUIElement` tooling (`Scripts/ax_binding.swift`) over `System Events` whenever toolbar/titlebar or SwiftUI sheets are involved
- Keep changes aligned with `CellProtocol`, `CellConfiguration`, and `skeleton`
- Avoid creating a second runtime path for Binding that diverges from scaffold semantics unless there is a documented parity reason

## Prompt For The Next Language Model

Use this prompt directly if helpful:

```text
Continue from the conference debug state in Binding. First verify live that the non-blocking load change in Binding/ContentView.swift now shows the conference skeleton immediately after absorb instead of holding Porthole blank. Then focus on the remaining remote blocker around ConferenceParticipantPreviewShell by tracing why the debug panel records bridge_description_deferred:wss://staging.haven.digipomps.org/bridgehead/ConferenceParticipantPreviewShell:timeout. Use Scripts/ax_binding.swift for state inspection, the screenshot skill for visual confirmation, and the in-app Debug panel early. Keep Binding aligned with CellProtocol/CellConfiguration/skeleton semantics. Document anything that works or fails in Documentation/ConferenceDebugPlaybook.md, and do not stage or commit the user breakpoint file.
```

## Suggested Next Technical Step

If continuing immediately:
1. Load `Conference AI Assistant` and `Conference Participant Portal Dashboard` again after the non-blocking load change.
2. Confirm whether the conference skeleton is visible before the bridge probe finishes.
3. If live data still does not appear, trace `ConferenceParticipantPreviewShell` bridge setup and authorization/description flow in `CellResolver` and the staging scaffold/runtime.
4. Compare the preview-shell instance ownership/admission semantics with `ConfigurationCatalog`, since `ConfigurationCatalog` currently admits and serves requests while `ConferenceParticipantPreviewShell` reaches `admit` and then fails on identity proof.
