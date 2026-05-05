# Conference Preview Shell Boundary

This note records the current ownership boundary for conference preview shells after moving the Binding-local fallback contracts out of `BootstrapView.swift`.

## What Works Now

- Binding registers conference preview endpoints locally without teaching the renderer anything special about conference skeletons.
- The Binding-local fallback cells live in:
  - `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ConferencePreviewShellLocalCells.swift`
  - `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ConferencePreviewShellSupport.swift`
- The local fallback cells expose the same public surface expected by the shell configurations:
  - `state`
  - `skeletonConfiguration`
  - `dispatchAction`
  - organizer-side write keypaths that the current control-tower skeleton uses
- The fallback cells now restore their runtime hooks after Codable round-trip by decoding the serialized owner identity from the `GeneralCell` payload before reinstalling intercepts.

## Ground Truth

- Binding depends on `CellProtocol` as a local Swift package and does not depend on `CellScaffold`:
  - `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding.xcodeproj/project.pbxproj`
- CellScaffold already owns the canonical conference preview wrapper cells:
  - `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/Cells/ConferenceParticipantPreviewShellCell.swift`
  - `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/Cells/ConferenceAdminPreviewShellCell.swift`
- CellScaffold also owns preview-wrapper resolution support and preview identity policy:
  - `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/ConferencePreviewWrapperResolverSupport.swift`
- CellScaffold also owns the canonical conference AI preview wrapper and public shell that Binding should render directly over bridge:
  - `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/Cells/ConferenceAIGatewayPreviewCell.swift`
  - `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/Cells/ConferencePublicShellCell.swift`

## Conclusions

- Conference preview shells are service-specific and should not move into `CellProtocol`.
- Binding should not import `CellScaffold` just to reuse conference cells, because that would invert the dependency direction and pull app-specific code into the renderer host.
- `Conference AI Assistant` should be treated like the public surface: scaffold-hosted in product/runtime, not reimplemented as a Binding-specific page path.
- The correct short-term boundary is:
  - `CellProtocol`: general rendering, bridge, agreement, identity, and cell primitives
  - `CellScaffold`: canonical conference preview wrappers, conference AI preview, public surface, and staging/runtime ownership
  - `Binding`: local fallback adapters only for the preview-shell contracts that truly need host-local resilience, not for conference product surfaces that already exist in CellScaffold
- The correct longer-term extraction, if we want one implementation reused by both apps, is a dedicated shared conference package or module that both `Binding` and `CellScaffold` can import without depending on each other directly.

## Evidence

- macOS Binding build succeeds after the extraction.
- Conference smoke again renders populated participant and organizer shells after moving persisted preview repair back onto the startup requester identity:
  - `/tmp/binding-conference-smoke-20260413i/report.md`
  - `/tmp/binding-conference-smoke-20260413i/binding.log`
  - `/tmp/binding-conference-smoke-20260413i/02-participant-portal.png`
  - `/tmp/binding-conference-smoke-20260413i/06-control-tower.png`
- Residual note:
  - the smoke log still contains `Authenticate failed ... -34018` during app initialization
  - those log lines did not prevent the local participant or organizer preview shells from rendering in the verified run above

## Assumptions Behind The Current Design

- A valid skeleton should render the same way regardless of whether its data source is a local Binding fallback cell or a staging-backed CellScaffold cell.
- The only thing the renderer needs is a valid cell contract and reachable data for the referenced keypaths.
- Preview fallback state is allowed to be host-local, but its public contract must stay aligned with the canonical conference shells.
- This specifically means the app-path for `Conference AI Assistant` must consume `ConferenceAIGatewayPreview` from CellScaffold instead of silently rewriting the AI half to a Binding-local proxy.
