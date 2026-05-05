# Binding

Binding is the primary app-side integration project for CellProtocol in this workspace.

## Scope

- SwiftUI client app in `Binding/`
- Local/runtime cells in `Cells/`
- Binding-specific docs in `Documentation/`
- Prompt and workflow docs in `Prompts/`
- Shared protocol docs via `CellProtocolDocuments/`

## Start Here

1. Open `Binding.xcworkspace`.
2. Read `Documentation/README.md`.
3. Use `CellProtocolDocuments/Book/10_Quickstart.md` for protocol/runtime onboarding.

## Status

This is an active integration repo and is expected to track latest CellProtocol and Scaffold-facing behavior.

Binding is now being separated into a standalone app boundary:

- Binding must run without a local HAVEN agent.
- Binding may connect to a remote `CellScaffold` instance.
- `HavenAgentD` is treated as an optional external tool, not part of the main app product.

Current separation docs:

- [BindingStandaloneSeparationPlan-2026-04-16.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/BindingStandaloneSeparationPlan-2026-04-16.md)
- [BindingStandaloneStatus.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/BindingStandaloneStatus.md)
- [HavenAgentD docs](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/README.md)
