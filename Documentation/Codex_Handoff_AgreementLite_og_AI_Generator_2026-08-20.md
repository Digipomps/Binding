# Codex-handoff: Agreement Lite + ekte AI-generator — 2026-08-20

Oppdragsgiver: Kjetil. Skrevet av Claude etter kildelesning i
`CellProtocol/Sources/CellBase/Agreement/`,
`CellScaffold/Sources/App/Cells/AgreementWorkbench/`,
`CellScaffold/Sources/App/Cells/AI/` og `Binding/Cells/ConfigurationCatalogCell.swift`.

Ingenting er verifisert mot kjørende kode. Bekreft linjenumre før du endrer.

---

## 0. Forutsetning: rydd trærne før første linje kode

Tre ting må være på plass. Detaljene ligger i
`Deploy_Handoff_Dirty_Trees_2026-08-20.md`, samme mappe.

1. **`CellScaffold`-branchen har ingen upstream** og ligger 49 foran / **128 bak**
   `origin/main`. 49 commits finnes bare på Kjetils disk, og `Package.resolved` er
   endret uten å være committet — avhengighetspinner er udefinerte for alle andre
   enn denne maskinen. Det finnes allerede et salvage-dokument fra i dag,
   `Documentation/Operations/WO_Salvage_Main_Derived_2026-08-20.md`. **Les det før
   du rører noe i CellScaffold.** Ingen deploy herfra er reproduserbar nå.
2. **`CellProtocol/main` er 2 foran og 3 bak `origin/main`.** Rebase først. Én av
   de tre manglende commitene endrer skeleton-vokabularet — se punkt 3.
3. **Elementtypene er 24, ikke 23.** `135d3c0` (#23) la til
   `SkeletonElement.NavigationBar`. Og `fc259fd` (#21) la til
   `SkeletonModifiers.wrap` med en `FlowLayout`, slik at `HStack`/`List` kan
   legge barn ut som organisk breddede chips som brekker til ny rad — i stedet
   for `SkeletonGrid`, som gir uniform kolonnebredde. **Det er nøyaktig det
   Agreement Lite steg 2 trenger** for kortene «Navn og kontaktinfo», «At vi
   møttes», «Oppfølging på chat». Ikke bygg dem med `Grid`.

Kort sagt: rebase CellProtocol, avklar CellScaffold-branchen, bygg grønt, og
*deretter* start på seksjon 2.

---

## 1. Korreksjon til premisset

Oppdraget var «vi må ha AI-promptverktøy for å lage Agreements, men også en
Agreement-editor som er enkel å bruke». **Editoren finnes allerede, og den er
solid.** Det er viktig å vite før noe rives.

`AgreementWorkbenchCell`
(`CellScaffold/Sources/App/Cells/AgreementWorkbench/AgreementWorkbenchCell.swift`,
4 602 linjer) + `AgreementWorkbenchConfigurationFactory.swift` (1 016 linjer) gir:

- 11 faner: Overview, **AI Agreement Assistant**, Parties and Purpose, Keypath
  Normalization, Grants, Conditions, VC-er, Sammenlign, Review, Machine JSON,
  Historikk og lagring
- ~17 GET- og ~60 SET-keypaths, inkludert full CRUD på grants og conditions
- signering via `Contract.ownerSignedSnapshot`, persistering gjennom
  `EntityAnchorCell.signedAgreementEntity.commit` med verify → skriv → les
  tilbake → hash-sjekk
- 25 tester (`AgreementWorkbenchCellTests.swift`, 1 074 linjer +
  `AgreementWorkbenchConfigurationFactoryTests.swift`)
- en passerende Playwright-scenario
  (`playwright/skeleton-scenarios/agreement-workbench.view.json`) på 1440×1000 og 390×844
- publisert i katalogen (`ConfigurationCatalogCell.swift:1461`, `:1719-1724`)
- en kompakt innbyggbar variant, `compactHelperElements(...)` (`:595`), allerede
  gjenbrukt av Personal Co-Pilot

**Det som faktisk mangler er to ting**, og de er begge presise:

1. **«AI-assistenten» er ikke AI.** `makeAISuggestionEnvelope()`
   (`AgreementWorkbenchCell.swift:1458-1549`) er nøkkelordmatching i Swift:

   ```swift
   let isSponsor = lowerPrompt.contains("sponsor") || lowerPrompt.contains("lead")   // :1472
   suggestedConditions = lowerPrompt.contains("proof") || lowerPrompt.contains("billett") ? [proofCondition] : []   // :1529
   ```

   Den returnerer to hardkodede grants og to hardkodede conditions. Ingen
   nettverkskall, ingen modell.

2. **Workbenchen er ekspertverktøy.** Elleve faner og seksti keypaths er riktig
   for den som skal finlese en avtale. Det er feil for den som skal si ja til en
   kontakt på en konferanse. Vi mangler en enkel flate.

Beslutning fra Kjetil: **bygg «Agreement Lite» ved siden av, ikke i stedet.**
Workbenchen blir «avansert modus». De 25 testene og Playwright-scenarioen skal
ikke røres.

---

## 2. Leveranse 1 — ekte AI-generering

### Vert: `AIGatewayCell`

`CellScaffold/Sources/App/Cells/AI/AIGatewayCell.swift` (3 296 linjer).
Relevante keypaths: `ai.invoke` (`:457-468`), `ai.invokePurposeBound` (`:722`,
`:1100`, `:2812`). Request/response: `AIGatewayInvokeRequest`
(`AIGatewayModels.swift:648-684`), `AIGatewayInvokeResponse` (`:714-729`).

**Viktig begrensning:** gatewayen returnerer fritekst `outputText: String?`. Det
finnes ingen JSON-schema- eller structured-output-modus. Etablert mønster er «be
om kompakt JSON i prompten, parse strengen».

**Referanseimplementasjon å kopiere:**
`CellScaffold/Sources/App/Cells/Restaurant/RestaurantExperiencePlanCell.swift:446-530`.
Den resolver `cell:///AIGateway` (`:452`), caster til `AIGatewayCell` (`:461`),
ber om «Return compact JSON with keys …» (`:465-477`), kaller med
`deterministicMode: true` (`:493`), og faller tilbake til en heuristisk plan ved
`fallback.no-gateway` / `fallback.no-resolver`.

### Arbeid

1. Ny metode `makeAISuggestionEnvelopeViaGateway(prompt:mode:requester:)` i
   `AgreementWorkbenchCell`. Behold `makeAISuggestionEnvelope()` uendret som
   fallback-sti.
2. Utgangskontrakten er allerede riktig og skal ikke endres:
   `AgreementAISuggestionEnvelope` (`:429-449`) med `summary`, `suggestedName`,
   `suggestedCounterparty`, `suggestedPurpose`, `suggestedGrants`,
   `suggestedConditions`, `warnings`. Modellen skal produsere nøyaktig denne
   formen.
3. **Grunn prompten i faktiske keypaths.** Den største risikoen er at modellen
   finner opp grants mot keypaths som ikke finnes. Send med den normaliserte
   keypath-katalogen som allerede driver fanen «Keypath Normalization»
   (`keypathSetQuery`, `keypathSelectSuggestion`, `:1898-1924`), og **valider hver
   foreslåtte grant mot den før den vises**. En grant mot en ukjent keypath skal
   bli en `warning`, ikke et forslag.
4. Permissions skal være kanoniske `rwxs` (`Permission.swift:11-22`). Ikke la
   modellen skrive vilkårlige strenger — map til enumen og avvis resten.
5. `deterministicMode: true`. Samme prompt skal gi samme utkast.
6. **Bevar review-portene.** `aiAcceptGrant`, `aiAcceptCondition`,
   `aiAcceptPurpose`, `aiAcceptSummary` (`:1957-2014`) er per-element godkjenning,
   og kommentarene på `:1547` og `:2841` sier «AI lagrer aldri og signerer aldri
   automatisk». Det skal fortsatt være sant etter endringen. Ingen auto-apply,
   ingen auto-sign, uansett hvor sikker modellen virker.
7. Tester: at gateway-svar som ikke parser gir fallback og ikke krasj, at ukjente
   keypaths blir warnings, at `deterministicMode` gir stabil utgang, og at ingen
   sti fører til lagring eller signering uten eksplisitt `aiAccept*`.

### Apple-lokal variant (valgfri, egen commit)

`AppleIntelligenceCell` (`CellProtocol/Sources/CellApple/Intelligence/AppleIntelligenceCell.swift`,
1 464 linjer) har ekte verktøykall og `@Generable`-typer — den beste
structured-output-primitiven i kodebasen. Den er Apple-only, så den kan ikke være
serverstien, men den er riktig for en Binding-lokal generator som virker uten
nett. Bygg den **etter** gateway-stien, ikke i stedet for.

---

## 3. Leveranse 2 — «Agreement Lite»

### Prinsipp

> Brukervennlighet og estetikk trumfer antall features.

Lite er ikke en redusert Workbench. Det er en annen flate for en annen situasjon:
noen står foran deg, dere vil utveksle noe, og avtalen skal ta under et minutt.

### Fire steg, ett spørsmål per skjerm

| Steg | Spørsmål til brukeren | Under panseret |
|---|---|---|
| 1 — Hvem | «Hvem er dette med?» | `setDraftCounterparty` |
| 2 — Hva | «Hva skal deles?» — 3–5 forhåndsdefinerte kort, lagt ut som wrappede chips (`SkeletonModifiers.wrap`, `#21`) | `addGrant` med ferdig keypath + permission |
| 3 — Hvor lenge | «Hvor lenge?» — I dag / En uke / Ett år | `setDraftDurationDays` |
| 4 — Signer | Ett sammendrag i klarspråk, én knapp | `signAndStoreAgreement` |

Alle fire bruker **de samme keypathene som Workbenchen**. Ingen ny
forretningslogikk, ingen ny celle, ingen ny persistering. Lite er en annen
`CellConfiguration` mot samme `AgreementWorkbenchCell`.

### Harde krav til flaten

- **Aldri vis en keypath til en vanlig bruker.** `person.displayName` er ikke
  norsk. Steg 2 viser «Navnet ditt», «Kontaktinfo», «At du var her» — kortene
  bærer keypathen som skjult payload.
- **Aldri vis `rwxs`.** Rendre permission som en setning: «De kan lese dette»,
  «De kan lagre en kopi». `s`-biten (`Permission.swift:6-10`) er *bevis båret av
  en avtale*, ikke kopisperre — teksten må ikke antyde noe annet.
- **Ett primærvalg per skjerm.** Maks én fremhevet knapp. Alt annet er sekundært.
- **390×844 er designmålet**, ikke et tilfelle som skal håndteres. Test der først.
- **Rømningsvei:** «Vis alle detaljer» åpner samme utkast i full Workbench uten å
  miste tilstand. `restoreSelectedAgreement` / `selectSavedAgreement` (`:2083-2201`)
  finnes allerede.
- **Ingen nye skeleton-elementtyper.** Etter rebase er det **24** — `NavigationBar`
  kom med `#23` og er relevant hvis Lite trenger en bunnforankret stegindikator.
  Begge renderere er i paritet: Porthole-SwiftUI (`SkeletonView.swift`) og web
  (`Public/js/skeleton-runtime.js:484-528`). Bruk `SkeletonModifiers.wrap` fra
  `#21` til kortene i steg 2. Hvis du tror du trenger en 25.: si fra og stopp,
  ikke oppfinn en.

### Ærlighet i teksten

Tre ting flaten **ikke** har lov å påstå:

1. **Ikke «dere signerte».** `Contract` er issuer-only og subject-bound av design
   — `Contract.swift:18-21` sier det eksplisitt, og `Agreement.sign(identity:)`
   (`Agreement.swift:231-236`) er en tom stub. Skriv «Du har signert din side».
2. **Ikke «du kan trekke den tilbake» uten forbehold.** Tilbakekalling finnes
   ikke i CellBase — `Agreement.removeGrant(_:)` (`:227-229`) har tom kropp, og
   grep etter `revoke` i `Sources/CellBase/Agreement/` gir én kommentar. Utløp
   håndheves av `Contract.verifySignature(now:)` (`:174-177`). Si det som er sant:
   avtalen utløper.
3. **Ikke la AI-utkastet se ferdig ut.** Et generert utkast skal være tydelig
   merket som utkast helt til brukeren har godkjent hvert element.

### Publisering

Ny factory `AgreementLiteConfigurationFactory.swift` ved siden av
`AgreementWorkbenchConfigurationFactory.swift`, publisert i
`ConfigurationCatalogCell` med egne interests. Behold Workbench-oppføringen som
den er.

---

## 4. Kobling til nearby-oppdraget

Trinn 3 i `Codex_Handoff_NearbyPurposeBridge_2026-08-20.md` (samme mappe i
Binding-repoet) er «Agreement» — der en nearby-peer man har utvekslet signert
proof med kan gå videre til en formell avtale. Den flyten trenger nøyaktig Lite,
ikke Workbench.

Grensesnittet mellom oppdragene er ett felt:
`NearbyDisclosurePolicy.agreementTemplateRef: String?`. Nearby-siden leverer en
mal-referanse og en motpart; Lite tar over derfra. Ikke bygg nearby-spesifikk
logikk inn i Agreement-flaten.

---

## 5. Ikke-mål

- Ikke bygg om `AgreementWorkbenchCell` eller dens 11 faner.
- Ikke rør de 25 eksisterende testene eller Playwright-scenarioen.
- Ikke implementer bilateral signatur. Det er en arkitekturbeslutning, ikke en
  oppgave — `Contract.swift:18-21` er eksplisitt, og
  `AgreementWorkbenchRedesign_2026-07-15.md` §C1 har allerede avvist påstanden.
- Ikke implementer tilbakekalling i denne runden.
- Ikke slå sammen CellBase-`Agreement` og Binding-lokale `AgreementRecord`
  (`Binding/Cells/ConfigurationCatalogCell.swift:1337-1369`). De er to
  parallelle modeller. Det er gjeld, men det er ikke dette oppdraget — noter det.
- Ingen nye skeleton-elementtyper.

---

## 6. Verifikasjon som forventes

Rapporter faktiske tall, ikke «ser bra ut»:

1. `swift test --filter Agreement` i CellScaffold. Antall tester, antall
   passerende, tid. De 25 eksisterende skal fortsatt være grønne.
2. Nye tester for gateway-stien og for keypath-validering av forslag.
3. Playwright-scenario for Lite på 390×844 **og** 1440×1000. Mål dokumentbredde
   og bekreft at ingen synlige elementer ligger utenfor viewport.
4. Én ekte AI-generering fra en norsk prompt, med utkastet limt inn i rapporten,
   så vi kan vurdere kvaliteten på grants og conditions.
5. Skjermbilde eller DOM-dump av alle fire Lite-steg på 390×844.

---

## 7. Åpne spørsmål til Kjetil

1. **Hvilke 3–5 kort skal steg 2 ha?** Dette er det viktigste produktvalget i
   hele flaten. Mitt utgangspunkt, som må overprøves: «Navn og kontaktinfo»,
   «At vi møttes», «Oppfølging på chat», «Del interesser». Hva er de faktiske
   scenariene på Arendalsuka?
2. **Skal Lite ligge i CellScaffold, i Binding, eller begge?** Skeleton-paritet
   betyr at én factory kan rendres begge steder, men katalogpublisering og
   endepunkt-godkjenning er ulikt. Anbefaling: CellScaffold, retargetet fra
   Binding slik AgreementWorkbench allerede er (`Binding/ContentView.swift:555`).
3. **Skal AI-genereringen være tilgjengelig i Lite i det hele tatt**, eller bare
   i Workbench? Argumentet for å holde den ute av Lite er at Lite skal være rask
   og forutsigbar; et LLM-kall er ingen av delene.
4. **Modellvalg og kostnad.** `AIGatewayCell` har kvote- og
   prisestimatfelter (`AIGatewayInvokeResponse.quota`, `.pricingEstimate`). Hvem
   betaler for utkastgenerering, og skal det være en grense?
