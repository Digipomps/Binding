# Binding P0 Utility Cells

Denne noten dokumenterer Binding-siden av P0 utility-cell-arbeidet fra `codex_binding_p0_utility_cells_prompt.md`.

## Hva som ble generalisert

- `Binding/PortableSurfaceSupport.swift`
  - `BindingAdmissionChallengeSupport` dekoder `AdmissionChallengePayload` fra portabel `ValueType` eller JSON uten Binding-lokale kontrakter.
  - `BindingAdmissionChallengeSnapshot` gjør session/retry/helper-data lesbar for Binding-flater uten aa endre payload-shape.
  - `PortableSurfaceContractSupport` samler generisk dekoding av `CellConfiguration` fra portabel `ValueType`.
  - `PortableSurfaceCacheStore` lagrer ra remote `CellConfiguration` og valgte snapshots per endpoint med freshness-metadata.

## Hvor dette brukes na

- Same-entity identity-link intake i `Binding/BootstrapView.swift`
  - eksisterende deep-link og innlimt payload fortsetter aa virke
  - hvis payloaden samtidig matcher `AdmissionChallengePayload`, eksponeres typed session/retry/helper-data i `identityLink.state.admission`
  - helper remediation kan aapnes eksplisitt via `identityLink.openHelper`
- Remote configuration recovery i `Binding/ContentView.swift`
  - ra recovered `CellConfiguration` caches per endpoint
  - cache brukes kun nar remote recovery ikke leverer en lesbar konfigurasjon
- Conference AI gateway proxy i `Binding/BootstrapView.swift`
  - valgte remote snapshots caches per endpoint/keypath
  - cache brukes som eksplisitt resilience nar live bridge/gateway ikke svarer

## Hva som bevisst fortsatt er lokalt

- `ConferenceIdentityLinkSupport` bygger fortsatt Binding-spesifikke presentasjonssammendrag for deep-link review.
  - slutning: review-sammendragene er host-UI, mens challenge/session-dataene under dem na er delt/typed
- `ConferenceAIAssistantGatewayProxyCell` er fortsatt en conference-spesifikk proxy.
  - slutning: cache-seamen under den er generell, men selve AI gateway-proxyen tilhorer fortsatt conference-demo/runtime

## Slutninger dette bygger pa

- Portabilitetsregelen i `Documentation/SkeletonPortabilityRequirement.md` tillater cache, men ikke kontraktsomskriving.
- Derfor caches ra remote-konfigurasjoner og snapshots for seg, og normalisering skjer forst ved faktisk rendering i Binding.
- Same-entity link approval er ikke authority i Binding.
  - Binding viser incoming challenge-data, lokal review og eventuelle typed remediation-signaler, men approval/fullforing forblir i den delte protokollen.

## Gjenstaende risiko

- Ikke alle `connect.challenge`-konsumenter i hele stakken er flyttet til typed decode ennå.
- Cache brukes forelopig i de viktigste resilience-banene, ikke i alle remote surface-banene.
- Identity-link-flaten viser na typed retry-data, men trigger ikke en full admission retry alene; den eksponerer session/helper-data eksplisitt for videre flyt.

## Stabilitetspass april 2026

### ConfigurationCatalog absorb/load

- Rotarsak:
  `ConfigurationCatalog` er registrert som `scaffoldUnique` i `private`-domenet, men named resolve og delte persistente instanser kunne bli opprettet under startup-vaulten for den endelige autentiserte `private`-identiteten var aktiv.
- Konsekvens:
  `cell:///ConfigurationCatalog` kunne resolve med en eldre owner-UUID enn requesteren som senere lastet den gjennom `Porthole`, og `catalog.state` feilet da korrekt med `denied`.
- Varig fix:
  owner-refresh og stale shared-cell invalidasjon er lagt i resolver-laget, ikke som Binding-testunntak.
  Binding rerunner og refresh-er named resolves nar aktiv vault byttes inn.
- Filer som eier fixen:
  `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Cells/CellResolver/CellResolve.swift`
  `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Cells/CellResolver/Cast/ResolverAuditor.swift`
  `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Cells/CellResolver/CellResolver.swift`
  `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/AppInitializer.swift`
  `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BindingAppNotifications.swift`
  `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift`

### Verifisert na

- `CatalogAbsorbXCTest` passerer signert mot macOS-host:
  `xcodebuild -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -derivedDataPath /tmp/BindingDD test -only-testing:BindingTests/CatalogAbsorbXCTest/testPortholeAbsorbsConfigurationCatalogAsCatalogLabel`
- Testen bekrefter baade direkte kataloglesing og attach via `Porthole`, inkludert at resolved owner matcher aktiv `private` requester-identitet.
- `Scripts/run_skeleton_parity_suite.sh` er rettet slik at `remote`-modus faktisk kan brukes som gate i `zsh`.

### Parity-status

- Remote parity er delvis gronn:
  10 av 12 staging-baserte parity-tester passerte i siste kjoring 14. april 2026.
- Gjenværende feil:
  - `testBridgeBackedFixtureResolvesThroughBindingAndExecutesAction` feilet med `Cloud Bridge connect failed with error: timeout` og `contractRejected(..., "notConnected")`
  - `testTextFixturePublishesConfigurationStateAndActionContract` feilet med HTTP timeout mot `https://staging.haven.digipomps.org/skeleton-parity/text/api/configuration`
- Slutning:
  renderer- og kontraktsparity for de vanlige HTTP-fixturene ser god ut, men bridge-backed parity mot staging er fortsatt ikke robust nok til aa kalles en hard gate.

### Concurrency-status

- `Binding`-targetet kompilerer med `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- Derfor blir nye utility-seams i `Binding/PortableSurfaceSupport.swift` main-actor-isolerte med mindre vi opt-er dem eksplisitt ut eller flytter dem til et target uten den defaulten.
- Konsekvens:
  Promptens concurrency-punkt er ikke helt i mal ennå. De mest konkrete gjenstående warningene sees na i tester som leser `BindingAdmissionChallengeSupport`, `PortableSurfaceCacheMetadata` og andre value/helper-typer som egentlig burde være enkle ikke-UI seams.

### 2026-04-15 stability cleanup

- De viktigste Binding-eide value/helper-seams er na eksplisitt `nonisolated` i stedet for aa arve `MainActor` unodvendig:
  - `Binding/PortableSurfaceSupport.swift`
  - `Binding/ContentView.swift`
  - `Binding/FullLibraryView.swift`
  - `Binding/ConferencePreviewShellSupport.swift`
  - `Binding/ConferenceConfigurationRepair.swift`
  - `Binding/RemoteCatalogSupport.swift`
  - `Cells/ConfigurationCatalogCell.swift`
- Slutning:
  disse typene bygger ikke UI-tilstand direkte, og de er derfor tryggere og mer i overenskomst med CellProtocol som vanlige kontrakt-/helper-seams enn som implisitte main-actor-typer.
- Verifieren venter na eksplisitt pa attach-etiketter etter `Porthole`-load for kontraktstester som prover attached references og actions.
  - slutning:
    dette er ikke en Binding-spesialvei for et bestemt skeleton; det er en deterministisk synkronisering mot samme attach-modell som rendererbanen faktisk bruker.
- Lokal runtime-stoy fra gjentatt Binding-registrering filtrerer na ogsa `duplicatedCodingName`, ikke bare duplikate endpoint-navn.
  - slutning:
    nar `AppInitializer` allerede har registrert samme coding name, er det ikke en runtime-feil og bor ikke spamme verifier-/smoke-loggene.

## Verifisering

- `xcodebuild -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -derivedDataPath /tmp/BindingDD build` bygger med utility-endringene.
- I Swift Testing-runneren passerer na de nye testene:
  - `bindingAdmissionChallengeSupportDecodesSharedPayload()`
  - `conferenceIdentityLinkInboxExposesTypedAdmissionSessionAndRetryRequest()`
  - `portableSurfaceCacheStoreRoundTripsConfigurationAndSnapshotsFaithfully()`
- Slutningen dette bygger pa:
  - typed admission decode maa kunne overleve lossy `Object`-transport, ikke bare perfekt `Codable`-JSON
  - cache-verifisering maa vaere semantisk faithful for `ValueType.object`, siden `ValueType` bevisst ikke gir dyp `Equatable` for objekttrær
- Den brede `BindingTests`-kjøringen har fortsatt andre, eldre feil utenfor denne P0-slicen, blant annet `configurationEndpointRetargetingRewritesNestedConfigurationLookupEndpoints()` og flere conference-/nearby-relaterte tester.
- 15. april 2026 ble disse konkrete kjoringene verifisert etter cleanup-pass:
  - `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/BindingDD-stability-build-clean-4 build`
  - `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/BindingDD-stability-catalog-final-2 test -only-testing:BindingTests/CatalogAbsorbXCTest/testPortholeAbsorbsConfigurationCatalogAsCatalogLabel`
  - `./Scripts/run_conference_configuration_verifier.sh nearby contract startup unsigned`
  - `./Scripts/run_conference_configuration_verifier.sh participant contract startup unsigned`
- Resultat:
  - lokal app-build er gronn
  - `ConfigurationCatalog` absorb/load er gronn
  - nearby-kontrakten er gronn
  - participant-kontrakten er gronn
  - gjenværende parity-stoy ligger fortsatt i staging-backed remote timeouts, ikke i lokale Binding-kontrakter
