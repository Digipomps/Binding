# Agreement Template Editor Plan (Draft for Approval)

Date: 2026-02-13

## Goal
Create a skeleton-based tool that edits a cell's `agreementTemplate` with capability-based authorization, explicit rollout policy, and non-compliance handling aligned with CellProtocol concepts.

## Non-Negotiable Rules
- Authorization is grants-per-identity, not roles/labels.
- Owner always has full authority.
- `agreementTemplate.access.manage` can be delegated explicitly.
- Agreement changes can be applied to new connections only, or can re-evaluate existing connections.
- Re-evaluation may force renewed `signContract` or revoke access only when allowed by active terms.
- Agreements should support signatures from all parties and retrieval for storage in each party-controlled entity context.
- `Entity` means digital presence/resources/functionality controlled by a person.
- Non-compliance must be explicit and policy-driven.

## Capability Surface
- `agreementTemplate.read`
- `agreementTemplate.write`
- `agreementTemplate.apply.newConnections`
- `agreementTemplate.apply.reEvaluateExisting`
- `agreementTemplate.contracts.enforce`
- `agreementTemplate.access.manage`
- Owner bypass remains explicit and deterministic.

## Meddle Endpoint Contract
- `GET agreementTemplate.state`
- `SET agreementTemplate.preview`
- `SET agreementTemplate.apply`
- `SET agreementTemplate.access.grant`
- `SET agreementTemplate.access.revoke`
- `GET agreements.current`
- `GET agreements.history`
- `SET agreements.sign`
- `SET agreements.nonCompliant.report`
- `SET agreements.nonCompliant.policy`
- `GET agreementTemplate.auditLog`

## Rollout and Non-Compliance Model
- `new_connections_only`: active connections continue until next connect cycle.
- `re_evaluate_existing`: current identities are checked against the new template.
- If non-compliant, emit explicit non-compliance event with evidence reference.
- Policy options (stored per cell/entity context):
  - `manual_only`
  - `auto_escalate`
  - `auto_request_resign`
  - `auto_restrict_until_resolved`

## File-by-File Implementation Plan
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift`
  - Add agreement-template endpoint implementations and capability checks.
  - Add preview/apply workflow with rollout mode and validation.
  - Add non-compliance reporting/policy handlers and audit flow emission.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ContentView.swift`
  - Add entry point to open the agreement template editor in edit mode.
  - Add save/apply actions with preview confirmation path.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/EditorState.swift`
  - Extend state with agreement-editor draft, preview result, and apply status.
  - Keep undo/redo isolated from runtime-applied template state.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/SkeletonEditor/SkeletonTreeMutations.swift`
  - Reuse for template visual editing where tree operations are needed.
  - Add helper entry points if agreement editor needs structure-safe inserts/deletes.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift`
  - Ensure any required resolver registration for agreement-management cell surface.
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/BindingTests.swift`
  - Add tests for owner access, delegated manage access, and denied access.
  - Add tests for preview/apply rollout behavior.
  - Add tests for non-compliant event/policy behavior.

## Sequence
1. Define `ValueType` payload contracts for all new endpoints.
2. Implement backend endpoint logic and access checks in `ConfigurationCatalogCell`.
3. Add UI scaffolding for agreement editor flow in `ContentView` + `EditorState`.
4. Wire preview/apply + policy selection.
5. Add tests and run test suite.
6. Document final endpoint payloads in `Documentation/` after implementation.

## Open Risk Checks Before Coding
- Confirm where signed agreement artifacts should be persisted when multiple entities are controlled by the same person.
- Confirm if non-compliance evidence should reference `agreements.history` IDs only or allow external verifiable credentials.
- Confirm if apply should be blocked when preview snapshot hash differs from current template hash.
