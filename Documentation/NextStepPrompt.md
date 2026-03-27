## Next Step Prompt

Continue from the deterministic conference configuration verifier now documented in `Documentation/ConferenceConfigurationVerifier.md`.

Current green baseline:

- `./Scripts/run_conference_configuration_verifier.sh all contract`
- `./Scripts/run_conference_configuration_verifier.sh all render`

Covered surfaces:

- `Conference Participant Portal`
- `Conference Participant Nearby Follow-Up`
- `Conference Control Tower`

Covered layers:

- contract verification for references, root probes, and selected actions
- contract verification for nearby follow-up state transition and chat handoff
- renderer verification for expected visible strings and timing

Important working assumptions:

- a green verifier means local conference wiring, local fallbacks, and renderer behavior are coherent
- it does not prove that staging preview/auth/bridge is healthy
- if live GUI still shows `Innholdet er ikke tilgjengelig akkurat nå.`, check verifier first, then move to staging/debug work

Next recommended engineering steps:

1. Extend the nearby verifier one step deeper:
   - assert `requestContact` before verified contact injection
   - assert scanner status transitions (`started`, `stopped`)
   - keep the verified follow-up chat handoff green
2. Add simple timing summaries or thresholds so slowdowns are easier to spot automatically.
3. Add one more stable conference configuration when it is ready for the demo story.
4. Consider a separate iOS-oriented layer later:
   - contract verification can still be local
   - render verification may need screenshot-driven validation instead of AppKit hosting
5. If a verifier case becomes flaky again, first check whether shared runtime state has crept back in before blaming staging.

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
