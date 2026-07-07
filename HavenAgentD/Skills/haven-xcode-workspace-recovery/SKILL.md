---
name: haven-xcode-workspace-recovery
description: Use when Xcode reports missing CellProtocol package products or modules such as CellBase, CellApple, CellVapor, or CodableHelpers, or says CellProtocol is already opened from another project/workspace while building Binding, CellScaffold, or another HAVEN Swift workspace.
---

# HAVEN Xcode Workspace Recovery

Use this skill when a HAVEN Swift workspace fails in Xcode with symptoms like:

- `Couldn't load CellProtocol because it is already opened from another project or workspace`
- `Missing package product 'CellBase'`
- `Missing package product 'CellApple'`
- `Missing package product 'CellVapor'`
- `Missing package product 'CodableHelpers'`
- `No such module 'CellBase'`

## Working Theory

Treat these errors as Xcode workspace/package-graph state until proven otherwise. Binding, CellScaffold, and other HAVEN workspaces often point at the same local sibling package:

- `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol`

When Xcode has multiple workspaces open that resolve the same local package, it can keep a stale graph where CellProtocol products disappear even though the package exists and command-line builds can resolve it.

## Preferred Fix

Prefer the structured HAVENAgentD command over raw `osascript`:

```bash
swift run --package-path /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD haven-agentd xcode-ensure-workspace \
  --workspace /Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/CellScaffold.xcworkspace \
  --exclusive-package /Users/kjetil/Build/Digipomps/HAVEN/CellProtocol \
  --scheme Run \
  --destination-name "My Mac (arm64)" \
  --destination-platform macosx \
  --destination-architecture arm64 \
  --timeout-seconds 900
```

For Binding:

```bash
swift run --package-path /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD haven-agentd xcode-ensure-workspace \
  --workspace /Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding.xcworkspace \
  --exclusive-package /Users/kjetil/Build/Digipomps/HAVEN/CellProtocol \
  --scheme HAVEN \
  --destination-name "My Mac (arm64)" \
  --destination-platform macosx \
  --destination-architecture arm64 \
  --timeout-seconds 900
```

The command intentionally closes open Xcode workspace documents by default, opens the requested workspace fresh, selects scheme/destination, and optionally builds. Use `--keep-other-workspaces` only when the user explicitly wants other Xcode workspaces preserved. Use `--no-build` only for a quick reopen/scheme check.

## MCP Form

When using `haven-agentd-mcp`, call:

- `agent.xcode.ensure_workspace`

Typical arguments:

```json
{
  "workspacePath": "/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/CellScaffold.xcworkspace",
  "exclusiveLocalPackagePath": "/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol",
  "scheme": "Run",
  "destinationName": "My Mac (arm64)",
  "destinationPlatform": "macosx",
  "destinationArchitecture": "arm64",
  "closeOtherWorkspaces": true,
  "build": true,
  "timeoutSeconds": 900
}
```

## Verification

Report the JSON result. The recovery is verified only when:

- `ok` is `true`
- `openedWorkspaceName` matches the requested workspace
- `status` is `succeeded` when `build` is true
- `errorCount` is `0`

If this works, say clearly that the fix was Xcode state/workspace recovery, not necessarily a source-code change.

## Guardrails

- This command manipulates the local GUI Xcode session and may close workspaces. Ask for or rely on explicit user permission before running it.
- Do not delete DerivedData, reset package caches, or edit package manifests until this structured recovery has been tried.
- Do not leave a long-running Xcode build session unattended; poll until it exits.
- If the command reports real build errors after workspace recovery, switch back to ordinary build debugging and preserve unrelated dirty worktree changes.
