# Perspective test data (Binding <-> CellScaffold)

## Filer
- `local_perspective_dataset.json` (brukers lokale Perspective i Binding)
- `cellscaffold_conference_dataset.json` (konferanse Perspective i CellScaffold, med kafeer og konsertscener)
- `local_activePurposes_query.json` (ferdig request for lokal `perspective.query.activePurposes`)
- `cellscaffold_match_request_with_local_targets.json` (ferdig request for `perspective.query.match` i CellScaffold)

## Bruk
1. Last `local_perspective_dataset.json` som `Perspective.json` for lokal `PerspectiveCell` i Binding.
2. Last `cellscaffold_conference_dataset.json` som `Perspective.json` for konferanse-`PerspectiveCell` i CellScaffold.
3. Sett opp bridge mellom Binding og CellScaffold.
4. Kjor lokalt:
   - `SET perspective.query.activePurposes` med `referenceMode = "both"`.
5. Send resultatets `purposes` til CellScaffold og kjor:
   - `SET perspective.query.match` med `targetPurposes = <purposes-fra-lokal side>`.

Alternativt kan du bruke ferdig testpayload direkte:

- `cellscaffold_match_request_with_local_targets.json`
  - inkluderer `targetPurposes`
  - simulerer ulike lokale refs pa tvers av maskiner med stabile `portable*Ref`

## Anbefalt match-foresporsel i CellScaffold
```json
{
  "minPurposeWeight": 0.65,
  "minInterestWeight": 0.60,
  "minMatchScore": 0.35,
  "limit": 20,
  "allowViaInterests": true,
  "referenceMode": "both",
  "targetPurposes": []
}
```

## Forventede treff
- Direkte: `purpose://attend-conference-talks`
- Via interesser:
  - `interest://networking` / `interest://collaboration` / `interest://startups`
  - `interest://specialty-coffee` / `interest://quiet-workspace`
  - `interest://live-music` / `interest://jazz` / `interest://indie`
  - `interest://privacy-tech` / `interest://digital-rights`
