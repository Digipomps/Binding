# HavenAgentD repository separation decision

Date: 2026-08-18

Completed: 2026-08-21

## Decision

`HavenAgentD` is a separate product and repository. Binding remains an app-side
consumer of released agent executables and versioned runtime contracts; it does
not own, build, package, or release the agent source tree.

Canonical repositories:

- Binding: `https://github.com/Digipomps/Binding`
- HavenAgentD: `https://github.com/Digipomps/HavenAgentD`

The repositories may be checked out as siblings for local development. Binding
must continue to start and run without a HavenAgentD checkout or installation.

The extracted agent history is published on `main` at commit
`f3a9f94b021fa4013a7a2045187d759ec126bcaf`. The canonical local development
layout is `Binding/` and `HavenAgentD/` as sibling checkouts.

## Integration boundary

Binding may depend on:

- installed, signed HavenAgentD executables;
- explicit developer path overrides;
- the loopback onboarding/status boundary;
- versioned JSON contracts under `HavenAgentD/Contracts`;
- CellProtocol flows and signed remote-intent envelopes.

Binding must not depend on HavenAgentD source files, Swift targets, build
directories, or a nested `Binding/HavenAgentD` path.

The current registration observation contract is
`haven.agentd-registration-observation.v1`. Binding keeps a checked copy of the
JSON Schema under `Documentation/TestData/HavenAgentD` so cross-repository
compatibility can be verified without source-tree coupling.

## Completed migration order

1. Make both Swift packages resolve sibling checkouts or pinned remote
   dependencies.
2. Move agent-only scripts, CI, packaging, contracts, and documentation to the
   agent repository.
3. Extract the `HavenAgentD/` Git history into the new repository.
4. Publish and validate the new agent repository.
5. Remove the embedded source tree from Binding and retain only adapters,
   contract fixtures, integration tests, and cross-product runbooks.

No Git submodule is introduced. A submodule would preserve the source-layout
coupling that this decision removes.
