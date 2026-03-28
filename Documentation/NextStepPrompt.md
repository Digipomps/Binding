## Next Step Prompt

Continue from the deterministic conference configuration verifier now documented in `Documentation/ConferenceConfigurationVerifier.md`.

Current green baseline:

- `./Scripts/run_conference_configuration_verifier.sh all contract`
- `./Scripts/run_conference_configuration_verifier.sh all render`

Covered surfaces:

- `Conference Participant Portal`
- `Conference Nearby Radar`
- `Conference Participant Nearby Follow-Up`
- `Conference Control Tower`

Covered layers:

- contract verification for references, root probes, and selected actions
- contract verification for the dedicated nearby-radar workbench, including start/stop and return-to-portal routing
- contract verification for nearby scanner start/requestContact/verified follow-up/stop
- renderer verification for expected visible strings and timing

Important working assumptions:

- a green verifier means local conference wiring, local fallbacks, and renderer behavior are coherent
- it does not prove that staging preview/auth/bridge is healthy
- if live GUI still shows `Innholdet er ikke tilgjengelig akkurat nå.`, check verifier first, then move to staging/debug work

Next recommended engineering steps:

1. Add simple timing summaries or soft thresholds so slowdowns are easier to spot automatically.
2. Use the nearby-radar workbench as the next home for a real spatial conference view:
   - honest MPC-only uncertainty
   - clearer UWB-ready direction/distance presentation
   - visible selected-entity follow-up state
3. Extend verifier coverage to one more conference configuration that matters for the demo story.
4. Consider a separate iOS-oriented layer later:
   - contract verification can still be local
   - render verification may need screenshot-driven validation instead of AppKit hosting
5. If live UI still claims the debug panel is drawing outside its frame, inspect:
   - `Binding/Debug/BindingRuntimeDiagnostics.swift`
   - rounded shape clipping
   - scroll container clipping
   - lazy log stack behavior
6. If a verifier case becomes flaky again, first check whether shared runtime state or local test-environment cache restrictions have crept back in before blaming staging.

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
