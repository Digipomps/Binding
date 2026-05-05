# Binding Standalone Status

Updated: April 17, 2026

`Binding` is now being treated as a standalone app product.

Current contract:

- Binding starts and runs without a local HAVEN agent
- Binding may connect to a remote `CellScaffold` instance
- the local agent is no longer part of the main Binding runtime/catalog/menu surface

Implemented in the current repo state:

- agent provisioning/enrollment adapter files are excluded from the `Binding` target
- Binding bootstrap no longer registers the agent cells
- the configuration catalog no longer publishes `Agent Setup Workbench`
- curated menus no longer seed an agent setup entry
- agent-specific docs now live under [HavenAgentD/Docs/README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/README.md) instead of the main Binding docs index

Verified in this change set:

- `xcodebuild -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS,arch=arm64' build` succeeded on April 16, 2026
- `xcodebuild -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS,arch=arm64' build-for-testing` succeeded on April 17, 2026
- standalone-specific code paths compile after removing the agent cells from the main app target
- `BindingTests/BindingTests.swift` now verifies that the catalog does not expose `Agent Setup Workbench`
- `BindingTests/BindingTests.swift` now verifies that local bootstrap does not resolve `AgentProvisioning` or `AgentEnrollment`
- the old dead `agentSetupWorkbenchConfiguration()` builder has been removed from `ConfigurationCatalogCell`
- the Binding docs index no longer presents the old agent workbench/runbook docs as active Binding documentation
- a repo sweep now finds agent references only in the legacy agent source files, `HavenAgentD`, and negative standalone assertions

Known verification gap:

- `xcodebuild -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS,arch=arm64' test -only-testing:BindingTests` is not clean yet because an existing conference/bridge-oriented test failed with `denied` in [CellConfigurationVerifierXCTest.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift:1562) during `testConferenceAIAssistantButtonsUpdateDraftAndSessionKeyViaRendererExecutionPath`
- that failure is outside the removed agent setup surface and should be tracked separately from the standalone-boundary work

What still works after this separation:

- local Binding bootstrap and local cell registration
- configuration catalog and library flows
- porthole-driven workbench loading
- conference launcher, participant, admin, public, and AI assistant flows
- local perspective, vault, entity, scanner, folder-watch, and graph-oriented surfaces that belong to Binding itself

What is intentionally no longer part of Binding:

- install/start/connect/stop flows for `haven-agentd`
- LaunchAgent management from inside the app
- agent pairing/setup workbench as a first-class Binding surface

Agent-specific code still exists in the repo for now, but the docs and product boundary now place that material on the `HavenAgentD` side instead of inside main Binding documentation.
