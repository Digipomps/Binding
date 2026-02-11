# PerspectiveCell Weighted Matching (Binding Note)

Canonical protocol/runtime specification lives in:

- `CellProtocolDocuments/Book/14_Perspective_Runtime_Matching.md`
- `CellProtocolDocuments/Book/13_Agent_Instructions.md`

This file is intentionally a short Binding-local note to avoid duplicated
protocol docs.

## Binding-specific usage

For Binding-level integrations (for example `ConferenceCell` usage through
`CellScaffold`), consume the canonical `PerspectiveCell` query keys and payloads
from Chapter 14 without redefining local variants.

Recommended flow:

1. Query local active purposes with `referenceMode = "both"`.
2. Send payload to remote/scaffold runtime.
3. Execute `perspective.query.match` remotely.
4. Use `directPurposeHits` as primary and `viaInterestHits` as secondary ranking input.
