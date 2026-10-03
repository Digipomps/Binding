# Fjernflater i HAVEN — kontroll 29. september 2026

**Påstanden «alle flater fra andre scaffolds kan kjøres og ser like ut i HAVEN» kan ikke bekreftes.** Det finnes fungerende offentlig HTTP-levering og en fungerende webhandling, men en testet native fjernrute feiler, stilkontraktene er ulike og full native verifikasjon ble ikke kjørt.

## Revisjoner og avgrensning

- Binding: `775fc93db71397022733e8225827d92a9423c803` med eksisterende lokale endringer; disse er bevart.
- Lokal CellProtocol: `81601a6f835252aba7e99d43786fb5d67227c245`.
- Lokal CellScaffold: `942965ca24e9a418b531f9514c1da75d6d529e30`.
- Staging `/health/build`: CellScaffold `feec23725321320ab00f0e7f7bf728b775869ec7`, CellProtocol `9c60001ac53abc35ba7ad6e2c0efa2a79ab2a366`, bygget 28. september.
- Produksjon `/health/build`: CellScaffold `18c14c32cb6e2957c1d13a20a4b2d97ece2f02b6`, CellProtocol `473357cf4efee831cb3b55ae87bc921d4bb63c10`, bygget 25. september.
- HTTP-måling: `2026-09-29T12:29:10Z`. Xcode 27.0, build `27A266a`.

Dette er en avgrenset kontroll av de to publiserte scaffoldene, ni gyldige testkonfigurasjoner, én ugyldig testkonfigurasjon og Co-Pilot-endepunkter. Det er ikke en uttømmende test av alle katalogflater, alle mulige scaffolds eller en autentisert brukerreise. Ingen autentiseringsopplysninger eller persondata ble brukt i HTTP-probene.

## Nye målinger

| Kontroll | Staging | Produksjon | Hva dette beviser |
| --- | --- | --- | --- |
| Testkatalog | HTTP 200, 10 oppføringer | HTTP 200, 10 oppføringer | Katalogen kan hentes |
| Konfigurasjon og state for ni gyldige testflater | 18/18 HTTP 200 | 18/18 HTTP 200 | Payload tilgjengelig, ikke native rendering eller handlinger |
| Ugyldig testkonfigurasjon | Forventet HTTP 422 | Forventet HTTP 422 | Eksplisitt negativ HTTP-kontrakt |
| Tekstflatens Acknowledge i nettleseren | Synlig overgang til «Ack mottatt 1 gang(er).» | Ikke kjørt | Én faktisk webhandling fungerer |
| WebSocket `/bridgehead/SkeletonParityTextFixture/<uuid>` | HTTP 404 | HTTP 404 | Testet fjernrute er utilgjengelig |
| `/personal-copilot-v1/api/catalog` | HTTP 500 | HTTP 500 | Offentlig katalogforespørsel feiler: `Failed to resolve Personal Co-Pilot requester.` |
| `/personal-copilot-v1/chat/api/configuration` | HTTP 200 | HTTP 200 | Chatkonfigurasjon kan hentes; kjøring ikke bevist |

Rådata og alle svar ligger i [http-probes.json](http-probes.json). Dette er 50 forespørsler: 44 svar med 200, to forventede 422, to 500 og to 404. HTTP 200 er ikke et bestått ende-til-ende-forløp.

`Binding/RemoteCatalogSupport.swift:23` konfigurerer standard ekstern rute med `websocketEndpoint: "bridgehead"` og `endpointThenPublisherUUID`. 404-funnet gjelder den konkret testede fixturen på begge verter. Det beviser ikke at alle alternative autentiserte transportveier feiler.

## Paritetsmatrise for testkorpuset

«Ikke kjørt» skal ikke telles som bestått. Schema-kolonnen er en JSON-inventering, ikke en Swift-dekodert validering.

| Scenario | Schema/HTTP | Web-render | Binding-render | Handling | Referanser | Responsive/shell |
| --- | --- | --- | --- | --- | --- | --- |
| text | JSON hentet | Synlig og skjermbilde inspisert | Ikke kjørt | Web Acknowledge bekreftet | Native bro 404 | Web 1280 × 720; native ikke verifisert |
| list | JSON hentet | Ikke kjørt | Ikke kjørt | Ikke kjørt | Ikke verifisert | Ikke verifisert |
| grid | JSON hentet | Ikke kjørt | Ikke kjørt | Ikke kjørt | Ikke verifisert | Ikke verifisert |
| form | JSON hentet | Ikke kjørt | Ikke kjørt | Ikke kjørt | Ikke verifisert | Ikke verifisert |
| markdown | JSON hentet | Ikke kjørt | Ikke kjørt | Ikke kjørt | Ikke verifisert | Ikke verifisert |
| relative-keypath | JSON hentet | Ikke kjørt | Ikke kjørt | Ikke kjørt | Ikke verifisert | Ikke verifisert |
| nested-reference | JSON hentet | Ikke kjørt | Ikke kjørt | Ikke kjørt | Navnet beviser ikke `Reference`-rendering | Ikke verifisert |
| remote-bridge | JSON hentet | Ikke kjørt | Ikke kjørt | Ikke kjørt | Metadata er ikke transportbevis | Ikke verifisert |
| unavailable | JSON hentet | Ikke kjørt | Ikke kjørt | Ikke kjørt | Ikke verifisert | Ikke verifisert |
| invalid | Forventet HTTP 422 | Ikke kjørt | Ikke kjørt | Ikke relevant | Ikke relevant | Ikke verifisert |

De ni gyldige konfigurasjonene inneholder bare ti av dagens 26 enum-cases, inklusive `Unsupported` i totalen. De dekker Button, Divider, Grid, HStack, List, Section, Text, TextArea, TextField og VStack. AttachmentField, ComponentSurface, FileUpload, Image, NavigationBar, Object, Picker, Reference, ScrollView, Spacer, Tabs, Toggle, Tree, Unsupported, Visualization og ZStack er ikke representert i dette publiserte fixture-korpuset. Andre tester kan dekke disse; de er ikke kjørt her. Se [fixture-coverage.json](fixture-coverage.json).

## Visuell likhet: konkret kontraktgap

Nåværende kildekode har ulike stilvokabularer:

- `CellProtocol/Sources/CellBase/Skeleton/SkeletonStyleParity.swift:33`: `agreedRoles` er tomt.
- `CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonView.swift:186`: `applyStyleMetadata` legger roller/klasser i tilgjengelighetsmetadata, uten generell CSS-styling. Enkelte native roller behandles særskilt andre steder.
- `CellScaffold/Public/css/porthole-webo.css:3417` og `:3445` gir `chat-active-tool-chips` og `chat-active-tool-chip` egne regler for layout og utseende.
- Den ferskt hentede chatkonfigurasjonen bruker nettopp disse rollene og klassene. Dette er dermed relevant for publisert innhold, ikke bare en teoretisk forskjell.
- `SkeletonParityRenderer.renderPNG` har `normalizeStyleTokens: true` som standard. Den fjerner roller/klasser uten felles kontrakt før bildet rendres. Et grønt normalisert bilde er ikke bevis på likt utseende for originalflaten.

Dette er et kildebekreftet gap i visuell kontrakt. Det ble ikke produsert et nytt side-ved-side-bilde av aktuell native app og web. Rapportene fra 14.–15. september gjelder isolerte kandidater; nyere CellProtocol-endringer fra 18.–26. september gjør at de gamle funnene ikke uten videre beskriver dagens renderer.

## Native kontroll og begrensning

Følgende målrettede bygg ble forsøkt, først i sandkassen og deretter utenfor:

```sh
xcodebuild build-for-testing -quiet -workspace Binding.xcworkspace \
  -scheme HAVEN -testPlan HAVEN -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/HAVEN-SurfaceParity-20260929 \
  -disableAutomaticPackageResolution \
  -only-testing:BindingTests/SkeletonRendererParityTests \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO
```

Sandkassen blokkerte Xcode-tjenester/workspace-lesing. Det nye forsøket utenfor sandkassen nådde avhengighetskontrollen og stoppet med «an out-of-date resolved file was detected» for `Binding.xcworkspace/xcshareddata/swiftpm/Package.resolved`. Ingen XCTest ble kjørt. Dette er `test-harness-gap`, ikke en feilet renderer-assertion. Pakkelåsen ble ikke endret som del av denne kontrollen. Se [build.log](build.log) og [build-unsandboxed.log](build-unsandboxed.log).

UI-verktøyet fant HAVEN, men eksponerte bare appmenyen, ingen testbar innholdsflate eller skjermbilde. Dette gir ikke grunnlag for å erklære at appen er tom eller ødelagt, men ga heller ingen native bekreftelse.

## Hva som må lukkes før en samlet bekreftelse

1. **Transport/tjeneste:** Verifiser den tilsiktede autentiserte native lastestien og håndter den målte 404-ruten og 500-katalogen på riktig lag.
2. **Visuell kontrakt/renderer:** Sammenlign identisk originalkonfigurasjon og state på web og native. Avklar og implementer felles behandling der publiserte stilroller gir avvik.
3. **Testoppsett:** Få en konsistent avhengighetslås i en avgrenset testkandidat, og kjør native testene på dokumentert revisjon.
4. **Dekning:** Utvid korpuset med de manglende elementtypene og de faktiske katalogflatene. Kontroller handlinger, referanser, oppdateringer og relevante skjermstørrelser ende til ende.

Ingen konfigurasjonsendring alene er dokumentert som løsning på disse funnene. Produktkode, installert app og servere er ikke endret. Denne kontrollen opprettet bare rapport/probescript/resultater i denne mappen samt den pålagte læringsfangsten.

Læring `L-2026-09-29-visuell-paritet-for-publiserte-skeleton-flater` er applied og synced til ferdigheten `binding-skeleton-parity-testing`. Global `haven_learn.py check --strict` er fortsatt rød på tre andre eksisterende læringer; de er utenfor denne kontrollen. Cowork-pluginoppdatering krever opplasting av den genererte ZIP-filen; lokal Desktop-store-synk er ikke garanti for varig oppdatering.
