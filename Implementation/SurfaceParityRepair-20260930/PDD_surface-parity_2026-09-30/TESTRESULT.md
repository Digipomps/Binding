# Testresultater — 30. september 2026

Dette dokumentet navngir de utførte lokale portene; sluttresultatet står i `../REPORT.md` og maskinlesbare summaries. G3/full fjernparitet er ikke godkjent.

## Bygg og native kjøring

Fra `workspaces/Binding` i leveransemappen:

```sh
xcodebuild build-for-testing -quiet -workspace ../../Integration.xcworkspace \
  -scheme HAVEN -testPlan HAVEN -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/HAVEN-SurfaceParity-Integrated-20260930 \
  -disableAutomaticPackageResolution -only-testing:BindingTests \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO -jobs 2
```

Det genererte xctestrun-filen kopieres ved siden av originalen og setter `BINDING_SNAPSHOT_CORPUS_DIR` til `corpus-acceptance-visual`, output til en ny mappe for hvert kodebilde. Dette bevarer `__TESTROOT__`. Testsett:

```sh
xcodebuild test-without-building -quiet \
  -xctestrun "$TEST_RUN_FILE" -destination 'platform=macOS,arch=arm64' \
  -resultBundlePath "$NEW_RESULT_BUNDLE" \
  -only-testing:BindingTests/SkeletonRendererParityTests \
  -only-testing:BindingTests/SkeletonPresentationOverlayTests \
  -only-testing:BindingTests/SkeletonSnapshotRenderXCTest \
  -only-testing:BindingTests/BindingSkeletonMountedActionSupportTests \
  -only-testing:BindingTests/CellConfigurationVerifierXCTest/testNoLocalSurfaceHidesItsOwnWaysIn \
  -parallel-testing-enabled NO -jobs 2
```

Les resultat via `xcrun xcresulttool get test-results summary --path "$NEW_RESULT_BUNDLE" --format json`. Ikke konkluder fra grep i Xcode-loggen alene. Xcode kan logge «command failed with exit code 0» samtidig som sluttkoden og det autoritative testresultatet er grønt; disse loggene er bevart.

## Renderer

CP-pakkens `swift test --filter 'Skeleton.*Tests'` er kjørt i gjenbrukt isolert scratch/cache, to jobber. De nye native regresjonene har før/etter-logger og NSHosting PNG-er. Se `../RENDERER.md` for eksakt kommando, nåværende antall og filhasher.

## Web

Kjør kandidatens `playwright.config.js` med den eksisterende CellScaffold-installasjonens `@playwright/test/cli.js` og `NODE_PATH`; worktreets eget node_modules-link var ugyldig. Siste endringssett omfatter:

- `playwright/skeleton-text-overflow.spec.js`
- `playwright/skeleton-list-static-elements.spec.js`
- `playwright/skeleton-element-catalog.spec.js`

22/22 bestod etter CSS-rettingen. De fire overflow-testene var røde med ubrutt tekst før rettingen. Første testutkast hadde feil `Text.value` i stedet for kontraktens `Text.text`; neste hadde naturlige bindestrek-brytepunkter og ble korrekt grønt på gammel kode. Disse forsøkene er ikke regnet som regresjonsbevis; `web-text-overflow-red-unbroken.log` er riktig rød baseline.

`Scripts/render_skeleton_parity_web.cjs` leser samme JSON/state som native, bruker lokal kandidat-CSS/JS og blokkerer øvrig nettverk. 70 scenarier per kjøring. Sluttopptak: `web-acceptance-delivery/summary.json`, `native-acceptance-delivery/`, `integrated-delivery-summary.json`. Native integrasjon30/30, CP188/188, captures70/70 per renderer. `build-delivery-committed.log` er vellykket sluttbygg med ren proveniens etter lokal commit; ingen funksjonell kode ble endret mellom den grønne testen og dette bygget.

## Katalog og HTTP

Fire avgrensede CellScaffold Swift-tester passerte på publisert CP-avhengighet med vanlig diskvakt og normal Resolver/strict-vault-policy. Kapasiteten kom over terskelen uten opprydding eller omgåelse. Eksakt bounded-kommando og tidligere feil står i `../TRANSPORT.md`.

Staging HTTP/handlinger 11/11 er et annet lag enn brotransport. Et vellykket HTTP-kall, lastet fixture eller 101-svar gjør aldri den generelle fjernbroporten grønn.

## Begrensninger

macOS arm64; ingen iOS-kjøring. Ingen all-modifier/kombinatorisk fulltest, fysisk scanneraksept, generell sikker fjernbro, signert distribusjon eller deploy. Ingen prod-policy eller identitetsfallback er åpnet for å få grønt resultat.
