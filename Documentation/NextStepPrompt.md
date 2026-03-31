## Next Step Prompt

Continue from the deterministic conference configuration verifier now documented in `Documentation/ConferenceConfigurationVerifier.md`.

Current green baseline:

- `./Scripts/run_conference_configuration_verifier.sh all contract`
- `./Scripts/run_conference_configuration_verifier.sh all render`

Covered surfaces:

- `Conference Participant Portal`
- `Conference Participant Agenda Snapshot`
- `Conference Participant Chat`
- `Conference Nearby Radar`
- `Conference Participant Nearby Follow-Up`
- `Conference Control Tower`

Covered layers:

- contract verification for references, root probes, and selected actions
- contract verification for the participant-local agenda snapshot, including optimistic mode/track updates when bridge refresh lags
- contract verification now also requires the visible agenda selection cards (`modeChoices` / `trackChoices`) that the GUI depends on
- participant-portal contract probing is now intentionally composition-oriented: the portal checks its key snapshot surfaces directly instead of brute-forcing the whole page
- contract verification for the dedicated nearby-radar workbench, including start/stop and return-to-portal routing
- nearby workbench contracts should stay composition-oriented too: probe `nearbyRadar.state` directly instead of requiring a coarse participant-shell root that the page itself does not need
- contract verification for nearby scanner start/requestContact/verified follow-up/stop
- contract verification for the participant-local matchmaking snapshot, including inline focus, follow-up marking, and chat handoff
- contract verification for the participant-local discovery snapshot, including inline focus, follow-up marking, and chat handoff
- nearby-radar state verification for focused participant state and honest `Retning usikker` handling
- renderer verification for expected visible strings and timing

Current UX decision:

- first click stays inline in the current conference page
- `Vis i siden` means “focus this participant here”
- participant recommendations now follow that same rule through a local `ConferenceParticipantMatchmakingSnapshot`
- participant discovery now follows that same rule through a local `ConferenceParticipantDiscoverySnapshot`
- participant agenda now follows that same rule through a local `ConferenceParticipantAgendaSnapshot`
- participant chat now has an explicit dedicated workbench through a local `ConferenceParticipantChatSnapshot`
- the active agenda state should be obvious in the page itself through visible choice cards, not just inferred from text summaries
- `Åpne full radar` and `Åpne profilflate` mean “open a separate workbench in Porthole”
- `Åpne chatflate` means “open the dedicated conversation workbench in Porthole”
- do not hide that transition behind a generic button label
- avoid overlay/modal as the primary pattern for now; the current skeleton/runtime model is better served by explicit inline focus first and explicit workbench expansion second
- nearby radar now carries a richer local status model:
  - `matchSummary`
  - `selectedEntity.relevanceBadge`
  - `selectedEntity.relevanceSummary`
  - `selectedEntity.followUpSummary`
  - `selectedEntity.chatSummary`
  Use those fields instead of forcing users to infer state from generic action text.

Current demo-story reality:

- direct chat is already wired into participant recommendations, discovery, and nearby follow-up
- a dedicated participant chat workbench now exists and is verifier-covered
- the next UX step is to make chat readiness and chat opening even more obvious in the inline participant page
- see `Documentation/ConferenceDemoStory.md`
- staged persona support should be pushed into CellScaffold using
  `Documentation/CellScaffoldConferenceDemoPersonasPrompt.md`
- the next nearby-radar implementation pass is scoped in
  `Documentation/ConferenceNearbyRadarImplementationPlan.md`
- the next organizer/dashboard uplift pass is scoped in
  `Documentation/ConferenceControlTowerUpliftPlan.md`
- staging admin preview is no longer broadly dead:
  - access, audience discovery, insights, sponsor, session polling, session thread, and simulation are now populated
  - the remaining staging preview gaps are mainly `content` and `system`
  - see `Documentation/CellScaffoldConferenceAdminPreviewStagingHandoff.md`

Important working assumptions:

- a green verifier means local conference wiring, local fallbacks, and renderer behavior are coherent
- it does not prove that staging preview/auth/bridge is healthy
- if live GUI still shows `Innholdet er ikke tilgjengelig akkurat nå.`, check verifier first, then move to staging/debug work

Next recommended engineering steps:

1. Finish organizer preview parity on staging:
   - fix the `content` lane so organizer publishing does not read as unavailable
   - fix the `system` lane so `AdminOverview` no longer returns denied in preview
   - once those are healthy, implement the visual uplift in `Documentation/ConferenceControlTowerUpliftPlan.md`
2. Implement the nearby-radar plan in `Documentation/ConferenceNearbyRadarImplementationPlan.md` in order:
   - honest spatial contract
   - native full radar surface
   - compact embedded radar
   - inspect/action card tightening
   - motion and quality pass only after the interaction model is stable
3. Keep tightening the participant chat surface:
   - `Start chat` should make "chat ready" unmissable inline
   - the dedicated chat workbench should read like a real transcript, not a dashboard of status cards
   - compose state should stay stable while the user types
4. Seed stable staged demo personas in CellScaffold:
   - governance / policy
   - service design / product
   - interoperability / operations
   - optional group anchor
5. Keep the agenda snapshot visible in the GUI, not just contract-safe:
   - selected agenda mode should be obvious at a glance
   - selected track focus should read like an active chip, not bare text
   - local sync warnings should surface without resetting the visible selection
6. Make the inline participant selection pattern consistent across nearby, recommendations, discovery, and chat:
   - `Åpne profil`
   - `Marker for oppfølging`
   - `Åpne chatflate`
   - `Be om møte`
7. Add simple timing summaries or soft thresholds so slowdowns are easier to spot automatically.
8. Extend verifier coverage to one more conference configuration that matters for the demo story.
9. Consider a separate iOS-oriented layer later:
   - contract verification can still be local
   - render verification may need screenshot-driven validation instead of AppKit hosting
10. If live UI still claims the debug panel is drawing outside its frame, inspect:
   - `Binding/Debug/BindingRuntimeDiagnostics.swift`
   - rounded shape clipping
   - scroll container clipping
   - lazy log stack behavior
11. If a verifier case becomes flaky again, first check whether shared runtime state or local test-environment cache restrictions have crept back in before blaming staging.

If you need to debug a fresh conference regression, start with:

```bash
./Scripts/run_conference_configuration_verifier.sh all contract
./Scripts/run_conference_configuration_verifier.sh all render
```

Then inspect:

- `Binding/ContentView.swift`
- `Binding/BootstrapView.swift`
- `Binding/ConferenceConfigurationRepair.swift`
- `Cells/ConfigurationCatalogCell.swift`
- `BindingTests/BindingTests.swift`
- `BindingTests/CellConfigurationVerifierXCTest.swift`
