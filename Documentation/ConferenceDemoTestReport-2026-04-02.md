# Conference Demo Test Report

Date: 2026-04-02

Environment:
- Repo: `Binding`
- Target: `My Mac`
- App build: `/Users/kjetil/Library/Developer/Xcode/DerivedData/Binding-erntjstdfcrbeachccbemadrrbon/Build/Products/Debug/Binding.app`

## Scope

This pass tested the current conference demo story in the running macOS Binding app, with emphasis on:
- default startup into `Conference Demo Launcher`
- launcher entry points
- participant portal
- participant chat path
- control tower
- scaffold setup / identity-link intake

## Result Summary

### Passed

- Binding can now start from `Conference Demo Launcher` after relaunch.
- `Conference Demo Launcher` opens correctly from the library.
- `Conference Participant Portal Dashboard` opens from the launcher.
- `Conference Scaffold Setup & Identity Link` opens from the library/launcher path.
- `Conference Control Tower` opens from the library and clearly shows current staging denial state instead of a black/empty shell.
- `haven://identity-link?...` is now recognized by the app bundle after adding URL scheme registration in `Info.plist`. Before this fix macOS returned `-10814`.

### Partial / Degraded

- `Conference Public Surface` opens, but still shows a warning banner and degraded/denied state from staging.
- `Conference Participant Portal Dashboard` loads and shows the current local participant fallback, but the recommended-person action path was not fully executable in this GUI pass.
- Organizer parity is still degraded because `Conference Control Tower` is mostly placeholder/unavailable content when `conferenceAdminShell.state` is denied by staging.

### Failed / Blocked

- The visible `Vis i siden` actions on recommended participants did not produce a selected-participant transition during this automated GUI pass.
- Because selected participant state did not advance from the visible recommendation cards, the pure GUI happy path
  `participant portal -> select Ane Solberg -> Start chat -> Åpne chatflate`
  could not be completed end-to-end from the portal itself in this pass.
- The library search result `Conference Participant Chat` still opens the generic snapshot workbench, not the dedicated demo chat surface.

## Concrete Findings

### 1. Startup default is now aligned with the demo

After relaunch, the app landed on `Conference Demo Launcher` instead of reopening an old workspace.

This was verified live after rebuilding and relaunching the app.

Related local changes:
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ContentView.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/BindingTests.swift`

### 2. Launcher is usable as the primary demo entry

`Conference Demo Launcher` rendered correctly and exposed the intended conference entry points.

Useful capture:
- `/var/folders/7s/xyjsdm211_xggqqzw1nmx8xc0000gn/T/codex-shot-2026-04-02_10-22-17.png`

### 3. Participant portal opens, but selection from recommendation cards is still a real blocker

The participant portal renders correctly enough to present the recommended people:
- `Ane Solberg`
- `Mads Hovden`
- `Lea Heger`

Useful capture:
- `/var/folders/7s/xyjsdm211_xggqqzw1nmx8xc0000gn/T/codex-shot-2026-04-02_10-25-37.png`

However, the visible `Vis i siden` actions did not move the UI out of:
- `VALGT DELTAKER`
- `Ingen deltaker valgt ennå`

This means the user-facing recommendation-to-chat handoff is still not reliable enough in the live GUI.

### 4. Control Tower still reflects staging denial, not a Binding-only bug

`Conference Control Tower` opened successfully when explicitly selected from the library, but it rendered a degraded/unavailable organizer surface:
- warning banner for unavailable data
- repeated `Innholdet er ikke tilgjengelig akkurat nå.`
- `conferenceAdminShell.state: denied`

Useful capture:
- `/var/folders/7s/xyjsdm211_xggqqzw1nmx8xc0000gn/T/codex-shot-2026-04-02_10-40-54.png`

This is consistent with the earlier staging handoff and should still be treated as a staging/admin-preview parity issue, not something Binding should paper over with fake content.

### 5. Identity-link intake is now OS-reachable

Before adding URL registration, a live `haven://identity-link?...` open attempt failed with:
- `-10814`

After adding `CFBundleURLTypes` for the `haven` scheme and rebuilding, `open location "haven://identity-link?..."`
returned successfully instead of failing immediately.

Related local change:
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/Info.plist`

Important nuance:
- the intake screen itself opened correctly before this change
- the new fix specifically addresses OS-level dispatch into the app

## Recommended Next Fixes

1. Fix recommended-person selection in the participant portal.
- This is now the main blocker for the real demo happy path.
- Focus areas:
  - recommendation action wiring in `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift`
  - recommendation card/button skeleton in `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift`

2. Make the dedicated participant chat surface discoverable without requiring a generic snapshot route.
- The library should distinguish between:
  - generic snapshot inspection
  - actual `Conference Participant Chat` demo surface

3. Keep treating organizer degradation as a staging-truth issue.
- Do not add Binding-only fake organizer content.
- Re-test `Conference Control Tower` once staging returns real admin preview state.

4. Add one explicit GUI-verifier path for:
- `Ane Solberg -> Vis i siden -> Start chat -> Åpne chatflate`

## Verification Performed

- `xcodebuild -project /Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build`
- live relaunch of the built app
- live library-driven navigation through launcher, participant portal, control tower, and identity-link intake

## Known Limitations During This Pass

- macOS screenshot/window capture intermittently became unstable after some UI transitions, especially after URL-dispatch tests. When that happened, full-screen capture sometimes returned black or per-window capture required rediscovering the current window id.
- Accessibility interaction was stable enough for library-driven navigation, but not fully reliable for proving `Vis i siden` on the participant recommendation cards.
