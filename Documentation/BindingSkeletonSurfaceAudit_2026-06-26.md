# Binding Skeleton Surface Audit 2026-06-26

## Scope

Denne runden verifiserte Binding sine tilgjengelige `CellConfiguration`-flater med skeleton gjennom tre spor:

1. Default `ConfigurationCatalog.configurations` i Binding, som i App Store-/Personal Co-Pilot-modus returnerte 15 skeleton-konfigurasjoner.
2. Eksisterende Personal Co-Pilot kontraktstest for lokale flater og sideeffektfrie/safe action-prober.
3. Eksisterende conference-kontraktstester for større workbench-flater utenfor default Personal Co-Pilot-listen.

`xcodebuild test` hang i dette miljøet før test-runneren etablerte connection til appen. For å få konkrete resultater ble testene kjørt direkte mot den bygde `BindingTests.xctest`-bundlen etter `xcodebuild build-for-testing`.

## Advisor Input

Claude ble kjørt via lokal `/Users/kjetil/.local/bin/claude`. Rådet som var nyttig og repo-relevant:

- Audit må følge faktisk Binding/CellProtocol renderer, ikke eldre antagelser om skeleton-format.
- Testen må skille mellom statisk skeleton-dekning, kontrakts-/reference-dekning og faktisk sideeffektfull knappetrykking.
- List/reference row templates må med i traversal, ellers kan flater se grønne ut selv om nested UI lekker bindings.
- Standard chat-/Co-Pilot-flater bør vise færre tekniske ord og færre parallelle handlingsområder.

GLM 5.2 kunne ikke brukes i denne sesjonen: `glm` og `ollama` var ikke på PATH. Jeg brukte derfor Claude og lokale Codex-rådgivere, men markerer GLM som ikke verifisert.

## Implementert

- Utvidet Binding sin skeleton binding-probe til dagens CellProtocol-elementer: `AttachmentField`, `FileUpload`, `Tabs`, `Picker`, `Visualization` og `Unsupported`.
- Utvidet test-verifierens readable binding-traversal med `Tabs`, `Picker`, `Visualization` og `Unsupported`.
- La til `testConfigurationCatalogSkeletonsPassStaticStructureAudit`, som henter `ConfigurationCatalog.configurations`, teller skeleton-elementer/knapper/felter og feiler på harde strukturelle feil.
- Rettet to faktiske skeleton-bindingfeil funnet av auditen:
  - `Entity Scanner`: knapp med eksplisitt `url: cell:///EntityAnchor` brukte fortsatt `proofs.encounters`; endret til lokal target-keypath `encounters`.
  - `Matches`: `selectionValueKeypath` brukte `profile.id` i item-scope uten top-level `profile` reference; endret til `id`.
- Gjorde Personal/Co-Pilot key-value-rader mer mobilrobuste ved å fjerne fast label-bredde og bruke kompakt vertikal label/verdi.
- Ryddet `Meeting Intent` skeleton-copy fra tekniske placeholder-tekster til norsk brukerrettet tekst.

## Verifiserte Resultater

Kommando:

```sh
xcodebuild build-for-testing -project Binding.xcodeproj -scheme Binding -destination platform=macOS -derivedDataPath /tmp/BindingStaticSkeletonAudit CODE_SIGNING_ALLOWED=NO
```

Resultat: `TEST BUILD SUCCEEDED`.

Direkte testbundle-kjøring:

```sh
xcrun xctest -XCTest CellConfigurationVerifierXCTest/testConfigurationCatalogSkeletonsPassStaticStructureAudit /tmp/BindingStaticSkeletonAudit/Build/Products/Debug/Binding.app/Contents/PlugIns/BindingTests.xctest
```

Resultat: passed. Audit etter fiks:

- 15 configs
- 0 errors
- 16 warnings
- 1131 skeleton-elementer totalt i katalog-auditen
- 122 knapper
- 47 input-felter
- 1 visualization

Kjørte også:

```sh
xcrun xctest -XCTest CellConfigurationVerifierXCTest/testPersonalCopilotLocalSurfacesLoadWithoutReferenceFailures /tmp/BindingStaticSkeletonAudit/Build/Products/Debug/Binding.app/Contents/PlugIns/BindingTests.xctest
```

Resultat: passed.

```sh
xcrun xctest -XCTest CellConfigurationVerifierXCTest/testConferenceParticipantPortalContract,CellConfigurationVerifierXCTest/testConferenceAIAssistantContract,CellConfigurationVerifierXCTest/testConferenceNearbyRadarContract /tmp/BindingStaticSkeletonAudit/Build/Products/Debug/Binding.app/Contents/PlugIns/BindingTests.xctest
```

Resultat: passed. Loggen viser en AI gateway `denied`, men testen håndterer dette via fallback og flaten feiler ikke.

```sh
xcrun xctest -XCTest CellConfigurationVerifierXCTest/testConferenceShowcaseButtonsCanExecuteWithoutBrokenBindings /tmp/BindingStaticSkeletonAudit/Build/Products/Debug/Binding.app/Contents/PlugIns/BindingTests.xctest
```

Resultat: passed.

## Gjenstående Varsler

Auditen står igjen med 16 warnings, ikke failures:

- Flere produksjons-skeletons mangler eksplisitt synlig vei til eier-entitet, Co-Pilot eller dokumentert shell-affordance.
- `Co-Pilot` har ubrukt `perspective` reference. Dette kan være forventet hvis provider-/purpose-context brukes av runtime senere, men bør enten bindes synlig/kontraktsmessig eller dokumenteres.
- `Entity Scanner` har flere ubrukte references (`chatHub`, `entity`, `perspective`, `publicProfiles`, `vault`). Det ser ut som en forberedt helhetsflate, men auditmessig bør references enten brukes, skjules bak eksplisitt hjelpeseksjon eller flyttes til en mer avansert surface.
- `Workflow Studio` lekker fortsatt teknisk tekst i normal UI: `condition keypath` og `parser text key`.

## UX-Vurdering

Binding er bedre enn ved starten av runden på strukturell skeleton-sikkerhet, men GUI/UX er ikke ferdig konsolidert på tvers av alle flater.

Det viktigste mønsteret:

- Co-Pilot/Chat bør være primær inngang til handling.
- Andre flater bør ha tydelig "hva gjør jeg nå?" først, deretter status, deretter avansert/diagnostikk.
- Tekniske labels som keypath, parser mode, target ID og ISO-format bør vekk fra default UI og inn i avansert modus.
- Flater med mange buttons bør skille primær handling, sekundære handlinger og destruktive handlinger tydeligere.

## Neste Beste Tekniske Steg

1. Legg owner/Co-Pilot-affordance inn som en gjenbrukbar skeleton-helper, og bruk den på alle Personal/produksjonsflater som mangler den.
2. Del `Workflow Studio` default UI i brukerrettet "bygg flyt" og avansert "parser/keypath" panel.
3. Stram `Entity Scanner` til enten full helhetsflate med synlige sections for alle references eller en minimal scannerflate med færre grants/references.
4. Utvid static audit med feltmutasjon i trygg testmodus: skriv til TextField/TextArea target-keypaths og verifiser at state endres uten å trigge sideeffekter.
5. Få `xcodebuild test`-launcheren stabil igjen; direkte `xcrun xctest` fungerer, men scheme-runneren hengte før connection i denne sesjonen.
