# HAVEN Standalone Separation Plan

Date: April 16, 2026

## Goal

Make `HAVEN` a standalone app that:

- runs without any local HAVEN agent installed
- keeps its own local runtime, identity, vault, and UI surfaces
- connects to a remote `CellScaffold` instance when available
- treats the local agent as an optional external tool, not part of the app product boundary

## Target architecture

### HAVEN

Owns:

- SwiftUI app shell and local runtime bootstrap
- local cells needed for standalone use inside HAVEN
- configuration catalog, porthole flows, conference/demo flows, vault, perspective, scanners, and document handling
- remote `CellScaffold` connectivity

Must not own:

- building `haven-agentd`
- installing binaries into `~/Library/Application Support`
- writing or loading `LaunchAgent` plists
- pairing/setup flows that assume a bundled local agent
- agent review queues as part of the main app experience

### HavenAgentD

Owns:

- the standalone agent executable
- launchd/login/session automation concerns
- AppleScript/Shortcuts/local review policy
- remote-intent execution and approval mechanics
- agent-specific provisioning and bootstrap tooling

### Integration boundary

If HAVEN ever talks to a local agent again, it should do so through an explicit optional bridge:

- capability discovery
- version/protocol negotiation
- explicit user opt-in
- graceful degradation when the agent is absent

HAVEN must never compile, install, or start the agent as part of normal app behavior.

## Phase plan

### Phase 1

Separate HAVEN from the agent at the app boundary.

Changes:

- exclude agent provisioning/enrollment source files from the `HAVEN` target
- remove agent runtime registration from HAVEN bootstrap
- remove agent setup surfaces from catalog and curated menus
- replace agent-coupled tests with standalone assertions
- document the new architecture and current status

Success criteria:

- HAVEN builds without compiling the agent adapter files
- HAVEN no longer exposes `Agent Setup Workbench`
- HAVEN runtime starts without registering `AgentProvisioning` or `AgentEnrollment`

### Phase 2

Move the remaining agent-facing HAVEN admin code out of the app repo surface.

Changes:

- extract the legacy agent admin UI from `ConfigurationCatalogCell`
- move agent-specific docs into a dedicated agent/admin area
- decide whether agent admin belongs in a separate helper app or only in the `HavenAgentD` project/docs

### Phase 3

Optional re-integration through a clean external boundary.

Changes:

- add optional capability discovery for an already-running agent
- expose a read-only status surface first
- add write/approval operations only behind explicit connection setup

## Executed in this change set

The work completed in this repo now covers Phase 1 and Phase 2.

What now works:

- `HAVEN` no longer compiles `Cells/AgentProvisioningCell.swift`
- `HAVEN` no longer compiles `Cells/AgentEnrollmentCell.swift`
- HAVEN bootstrap no longer registers `AgentProvisioning` or `AgentEnrollment`
- curated HAVEN menus no longer include `Agent Setup`
- `ConfigurationCatalog` no longer exposes `Agent Setup Workbench`
- the legacy `agentSetupWorkbenchConfiguration()` builder has been removed from `ConfigurationCatalogCell`
- tests now verify the standalone contract instead of agent integration
- agent-specific docs have been moved out of `Documentation/` into `HavenAgentD/Docs`
- the repo now records the explicit decision that agent admin belongs in `HavenAgentD` docs, not in the main HAVEN app surface
- a repo sweep finds no active HAVEN runtime/catalog/menu references to `AgentProvisioning`, `AgentEnrollment`, or `Agent Setup Workbench`

## Remaining follow-up

- add explicit standalone-product acceptance tests for HAVEN's remote `CellScaffold` connection flow
