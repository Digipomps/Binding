# HAVEN Personal Butler — auditrapport mot App Store, mikrobetaling og viral vekst

Statusdato: 19. august 2026
Revisjon undersøkt: `60ec4cc0` (Bridge native models and persist private contacts), med urent worktree (10 modifiserte filer, bl.a. `project.pbxproj`, `Info.plist`, begge entitlements-filer)
Metode: kildeaudit av `Binding`, `CellProtocol`, `CellScaffold`, `DiMyMicropayments`, `DiMyDocuments/ValueRedistribution`, kombinert med kontroll mot gjeldende offisielle Apple-, Finanstilsynet-, EBA-, ESA- og EUR-Lex-kilder hentet 19. august 2026. Ingen produktkode ble endret.
Skills anvendt: `dimy-payment-regulatory-guardrails`, `haven-claim-review`.

> **Dette er ikke juridisk rådgivning.** Ingen regulatorisk konklusjon i dette dokumentet er avklart. Der noe er uverifisert står det eksplisitt.

---

## 1. Beslutning

**Den ønskede v1 — «HAVEN Personal Butler med mikrobetaling som åpner tilgang til celler» — kan ikke sendes til App Review i den formen mikrobetalingen har i dag.** Ikke fordi den er umoden, men fordi arkitekturen er navngitt i forbudsteksten i Apples retningslinje 3.1.1.

Ordrett, fra [App Review Guidelines 3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase), hentet 19. august 2026:

> "If you want to unlock features or functionality within your app […] you must use in-app purchase. **Apps may not use their own mechanisms to unlock content or functionality, such as license keys, augmented reality markers, QR codes, cryptocurrencies and cryptocurrency wallets, etc.**"

`DiMyMicropayments` er en klientside-lommebok med blindede ihendehaver-coins innløst mot en mint (`Coin`, `SpendBundle`, `/issue`, `/redeem`, `merchantID`). Uansett om Apple ville kalt det «cryptocurrency wallet» eller «own mechanism/license key» — begge kategoriene er uttrykkelig forbudt for å låse opp innhold i appen. Det finnes ingen tolkning som redder den stien.

**Men konklusjonen er ikke «drop mikrobetaling».** Den er at det finnes én vei som løser Apple-problemet og det regulatoriske problemet samtidig, og som er billigere enn dagens design:

> **StoreKit 2 consumable IAP som eneste kjøpsvei i iOS-appen. Kreditten er ikke-overførbar, ikke innløselig i penger, aksepteres kun av HAVEN, og kjøpes hos Apple.**

Det er nøyaktig `access entitlement` + `usage quota` i deres egen [regulatoriske matrise](#6-regulatorisk-analyse-norgeeøs), som er den eneste varianten matrisen tillater i v0. Apple blir betalingsbehandler, noe som fjerner PSP-, kundemiddel- og AML-eksponeringen fra v1 helt. Ecash-stacken beholdes — men på web/desktop/server, der Apples regler ikke gjelder.

**Rekkefølgen jeg vil anbefale, med begrunnelse i seksjon 8:** iOS-gulv ned først, deretter butler-persistens, deretter IAP, deretter det sosiale laget. Ikke motsatt.

---

## 2. Hva som faktisk er sterkt i dagens kodebase

Dette er ikke høflighet — det er materiale rapporten bygger på.

- **Scope-gaten finnes og virker i Release.** `BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1` krever scope-token, avviser skjulte conference-flater og krever at alle refererte endepunkter er godkjente. Conference-menyer, staging-seeds og agent-workbench er `#if DEBUG`-gated og returnerer hardkodet `false` i Release. Dette er materielt bedre enn 3. august-vurderingen beskrev.
- **Betalingsposituren er allerede riktig tenkt.** `PersonalUsageQuotaLocalCell` deklarerer `productVariant=usage_quota`, `paymentRole=entitlement_client`, `transferability=none`, `cashOut=false`, `externalAcceptance=false`, `nativePurchaseCTA=disabled` og en eksplisitt `hardStops`-liste, og blokkerer top-up i App Store-modus. Noen har gjort DiMy-matrisen om til kjørende kode. Det er uvanlig disiplin.
- **Butler-policyen er en reell konkurransefordel.** `BindingPersonalButlerPolicy` er default-av på proaktivitet, 72-timers minimumsintervall, stilletid 22–08, fast signal-allowlist, `retainsRawFeedback=false`, `providerInvoked=false` ved capability-refresh og ingen emosjons- eller helseinferens. Dette er en sterkere privacy-historie enn de fleste AI-apper i Store, og den er etterprøvbar.
- **Entitets-primitiven finnes allerede.** `EntityAuthorityCommit`, `EntityAuthorityReplication`, `EntityAuthorityReplicaStore`, `UserOwnedBackupCodec`, `UserDataErasureCoding` og `UserDataInventoryContracts` ligger i CellProtocol, og `PersonalChatChronicle` bruker commit-stien allerede. «Butler i entitet, ikke enhet» er et integrasjonsarbeid, ikke et forskningsarbeid.
- **Tillatelsene er ryddet siden 3. august.** Background modes er nede i `remote-notification` alene, associated domains peker nå på `haven.digipomps.org` i stedet for demo-ID-en, og alle usage descriptions er på plass og presist formulert.

---

## 3. Modenhet per område

Skala: 0 konsept · 1 implementert · 2 lokalt verifisert · 3 miljøverifisert · 4 produksjonsklar.

| Område | Nivå | Evidens | Dom |
|---|---:|---|---|
| Scope-gate i Release | 2–3 | `isAllowedInPersonalCopilotV1`, `#if DEBUG`-gating, fire policy-tester | Grønn mekanikk, se F1 om tillitsmodellen |
| Butler-policy | 3 | `BindingPersonalButlerPolicy`, 51 tester i `ChatWorkbenchParityTests` | Sterkeste komponenten |
| Butler-persistens/entitet | 1 | `EntityAuthorityCommit` finnes, men ingen test for butler-profil over omstart | **P0 — kjerneløftet er ubevist** |
| Mikrobetaling, Apple-lovlighet | 0 | 0 forekomster av `StoreKit`; blokkert top-up; wallet-celler registrert | **P0 — blokkerende** |
| Mikrobetaling, regulatorisk | 1 | Guardrails i kode, men bearer-coins + `merchantID` i stacken | **P0 — hard stop-nær** |
| Privacy-manifest | 0 | Ingen app-eid `PrivacyInfo.xcprivacy`; 18 `UserDefaults`-bruk | **P0 — ASC avviser opplasting** |
| Aldersvurdering | 1 | `ageRatingHint` default `"12+"` fortsatt i koden | **P0 — utgått system, ny frist sept. 2026** |
| Rekkevidde/vekstgulv | 0 | `IPHONEOS_DEPLOYMENT_TARGET = 26.1` | **P0 for vekst — se seksjon 7** |
| Autoritativt release-inventar | 0 | Ingen test som enumererer nåbare flater | P0 fra 3. aug, fortsatt åpen |
| Distribusjon/signering | 1 | Bundle-ID `org.digipomps.haven` frosset; to ulike `DEVELOPMENT_TEAM` i prosjektet | P1 |
| Sosialt lag / viralitet | 1 | Nearby-tillatelser og radar finnes; ingen invitasjonsløkke | P1, bevisst utsatt |
| Nøkkelhåndtering ved oppstart | 1 | Se F6 | P1 med sikkerhetsflagg |

**Samlet: 1,5 av 4 for den ønskede v1.** Butler-kjernen er sterk; betaling, persistens og innsendingsmekanikk er ikke det.

---

## 4. Funn

### F1 — Scope-gaten er selverklæring, ikke allowlist (P0)

`hasPersonalCopilotScope` godkjenner enhver konfigurasjon som **selv** oppgir `personal-copilot-v1` blant sine `discovery.interests`:

```swift
return interests.contains { token in
    let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == appStoreScope
        || normalized == "appstorescope:\(appStoreScope)"
        || normalized == "appstorescope=\(appStoreScope)"
}
```

Tillitsgrensen er dermed ikke «en fast liste vedtatt ved release», men «hva verten sender, hvis den merker det riktig». I tillegg:

- `approvedRemoteHosts` inneholder **kun** `staging.haven.digipomps.org`. Ingen produksjonsvert. Associated domains peker på `haven.digipomps.org`, som ikke er i listen. Disse to peker på hver sin vert.
- `isApprovedEndpoint` returnerer `true` for tom host og for `localhost`.

**Hvorfor det betyr noe:** foreslått review-tekst sier at hver nåbar konfigurasjon er «fixed by the release allowlist». Slik koden er nå er den påstanden ikke dekkende, og den er den typen påstand Apple kan etterprøve ved å be om katalogen. Under 4.7 er dette dessuten forskjellen mellom «deklarativ førsteparts-konfigurasjon» og «plattform for ikke-embedded software» — se F8.

**Minste fiks:** en kompilert `Set<String>` av godkjente konfigurasjonsnavn eller signerte manifest-hasher, hvor selverklært interesse-token er *nødvendig, men ikke tilstrekkelig*. Legg produksjonsverten inn og fjern staging fra Release.

### F2 — Mikrobetalingsdesignet er navngitt i Apples forbud (P0, blokkerende)

Tre uavhengige klausuler treffer, hver for seg tilstrekkelig:

1. **3.1.1**, «unlock features or functionality within your app […] you must use in-app purchase» + «may not use their own mechanisms […] such as license keys […] cryptocurrencies and cryptocurrency wallets».
2. **3.1.1**, «Digital gift cards, certificates, vouchers, and coupons which can be redeemed for digital goods or services can only be sold in your app using in-app purchase.» En coin innløst mot en celle er funksjonelt en voucher.
3. **4.7.1** tredje kulepunkt: software som ikke er embedded i binæren må «follow Guideline 3.1 in order to offer digital goods or services to end users». 4.7 gir altså ingen betalingsdispensasjon — den re-importerer 3.1.

**Ingen 3.1.3-underklausul redder det.** Nærmeste er 3.1.3(b) Multiplatform Services, men forbeholdet er bærende: varene må «also be available as in-app purchases within the app». 3.1.3(a) gjelder seks navngitte medietyper, ikke programvaremoduler. 3.1.3(f) krever *null* kjøp og *null* call-to-action i appen.

**Norge har ingen utvei via eksterne lenker.** [Apples liste over tillatte regioner](https://developer.apple.com/support/communication-and-promotion-of-offers-on-the-app-store-in-the-eu/) for External Purchase Link Entitlement er de 27 EU-landene; `no` står ikke der. [DMA-siden](https://developer.apple.com/support/dma-and-apps-in-the-eu/) sier uttrykkelig «the 27 EU member countries». Norge er EØS, ikke EU. Det eneste stedet Apple navngir Norge er [Music Streaming Services Entitlement (EEA)](https://developer.apple.com/support/music-streaming-services-entitlement-eea/), som krever at appen har musikkstrømming som primærformål og Music som primærkategori — HAVEN er Productivity.

> **Uverifisert og verdt å følge:** Apples [EU-endringer 18. august 2026](https://developer.apple.com/news/?id=gmws0jgp), som fra 1. oktober 2026 tillater alternative betalingsmåter *ved siden av* IAP, navngir ingen land. Gitt DMA-sidens ordlyd er Norge nesten sikkert utenfor, men Apple har ikke publisert landliste for oktober-vilkårene. Ikke planlegg for at Norge er med.

**En felle å notere allerede nå:** 3.1.1 sier at «any credits or in-game currencies purchased via in-app purchase **may not expire**». Det kolliderer direkte med DiMy-matrisens ønske om at internal event credit skal være «begrenset og utløpende», og med enhver coin-TTL eller nøkkelepoke-rotasjon. Dere må velge, og valget må tas før prismodellen låses.

### F3 — Wallet-cellene er registrert i appens runtime i dag (P0)

`RootView.swift` registrerer DiMy-cellene ved hver oppstart:

```swift
try await DiMyCellRuntimeRegistration.registerBindingCells(
    resolver: resolver,
    identityDomain: "private"
)
```

og `ConfigurationCatalogCell` publiserer katalogoppføringer med `sourceCellEndpoint: "cell:///DiMyWallet"`, visningsnavn «DiMy Wallet Runtime» og interests `["wallet", "payments", "identity", "commerce"]`.

Selv om `nativePurchaseCTA` er deaktivert og top-up er blokkert i App Store-modus, betyr det at den innsendte binæren inneholder og registrerer en lommebok-runtime. Under 3.1.5(i) er det å *ha* en wallet tillatt for organisasjonskontoer — men det fritar ikke 3.1.1, og det er inventar dere må kunne redegjøre for hvis Apple spør. Kombinert med F1 er dette den mest sannsynlige kilden til et vanskelig review-spørsmål.

**Anbefaling:** ta `DiMyCellProtocolCells` ut av iOS-app-targetet for v1. `#if canImport` er ikke en gate — det er en byggavhengighet.

### F4 — «Butleren skal leve i brukerens entitet» er ikke bevist (P0 for produktløftet)

Dette er funnet jeg vil løfte høyest, fordi det rammer selve produktløftet og ikke bare compliance.

- Appen starter på `BindingStartupIdentityVault`, en **in-memory** actor. `identityUUIDsByContext` og `identitiesByUUID` er vanlige dictionaries, `vaultReference` får ny UUID per prosess, og signeringsnøkler genereres med `P256.Signing.PrivateKey()` uten lagring.
- Overgangen til den ekte, Keychain- og biometri-baserte `IdentityVault.shared` skjer i `BindingRuntimeBootstrap.ensureBaseline()`, som **kun** kalles fra `ContentView` (tre steder). `RootView` sin oppstart kaller bare `ensureInfrastructureBaseline()`.
- Persistens finnes: `documentRootPath()` peker på Application Support, og `TypedCellUtility(storage: FileSystemCellStorage())` er koblet inn.
- Men: jeg fant **ingen test og ingen eksplisitt persist-sti for `chatHub.state.butler`**. Butler-dokumentet fra 13. juli sier selv at cross-device-synk er et åpent spørsmål, og at slicen «keeps them in the owner-scoped chat cell».

**Jeg påstår ikke at butler-navnet går tapt ved omstart — jeg påstår at ingenting i repoet beviser at det overlever.** Det er en forskjell, og den forskjellen er hele poenget: hvis en bruker gir butleren navn og navnet forsvinner, er det produktdrepende på en måte ingen review-avvisning er.

**Minste neste bevis:** én test som setter butler-profilnavn, river runtime, bygger den opp igjen og leser navnet tilbake. Deretter én tilsvarende over `EntityAuthorityCommit` mot to enheter.

### F5 — Innsendingsblokkere som fortsatt står åpne fra 3. august (P0)

- **Ingen app-eid `PrivacyInfo.xcprivacy`.** De eneste treffene i repoet er i `HavenAgentD/.build/checkouts/`. Appen bruker `UserDefaults` 18 steder. Apple: «Starting May 1, 2024, apps that don't describe their use of required reason API in their privacy manifest file aren't accepted by App Store Connect.» Relevante kategorier og koder: `NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1`, og sannsynligvis `FileTimestamp` → `C617.1` og `SystemBootTime` → `35F9.1` gitt filbasert cellelagring. Merk at `35F9.1` forbyr at boot-tid forlater enheten — relevant hvis coin-ferskhet noen gang beregnes fra den.
- **`ageRatingHint: String = "12+"`** står fortsatt som default i `BindingPersonalCopilotV1Policy.metadataHints`. Gyldige verdier er nå 4+/9+/13+/16+/18+. I tillegg: fra [9. juli 2026](https://developer.apple.com/news/?id=tlur8uvi) er det nye spørsmål om «social media capabilities» i spørreskjemaet, og **svar blir påkrevd fra september 2026** for nye apper og oppdateringer. Det er om få uker.
- **Ingen autoritativ inventarliste.** Ingen test i `BindingTests/` enumererer nåbare Release-konfigurasjoner. Dette er årsaken til «tre divergerende inventory-tall» i august-vurderingen, og den vil komme tilbake så lenge `ConfigurationCatalogCell.swift` er 947 KB og inventaret er håndtelt.
- **To ulike `DEVELOPMENT_TEAM`** i `project.pbxproj`: `58VP3BNL4B` og `5UT5HQTCV9`. Må avklares før arkivering.
- **AASA er uverifisert.** `haven.digipomps.org` var ikke tilgjengelig fra dette miljøet (proxy-blokkert), så jeg kan verken bekrefte eller avkrefte at `.well-known/apple-app-site-association` nå er riktig. Må sjekkes manuelt.

### F6 — Avledet «hemmelighet» i oppstartsvaulten (P1, sikkerhet)

```swift
func scopedSecretData(tag: String, minimumLength: Int) async throws -> Data {
    // buffer.append(contentsOf: SHA256.hash(data: payload))  der payload = tag || counter
}
```

Dette er en usaltet, unøklet SHA-256 av en offentlig tag-streng, og `aquireKeyForTag` bygger AES-nøkkel og IV rett ut av den. Enhver som kjenner tag-en kan regne ut nøkkelen. `CellResolver` har en fallback-kjede som treffer nettopp denne stien.

Så lenge oppstartsvaulten er aktiv, er alt som krypteres med `aquireKeyForTag` kryptografisk kosmetikk. Det står også i spenn med `NSFaceIDUsageDescription`, som lover «nøkler som brukeren kontrollerer».

Jeg har **ikke** verifisert hvilke celler som faktisk krypterer innhold med denne stien i Release — det bør gjøres før dere sier noe offentlig om innholdskryptering. `Documentation/KeyHandlingAndContentCryptoAssessment.md` konkluderer allerede med at innholdskryptering ikke er «good enough» ennå; dette funnet skjerper den konklusjonen.

### F7 — iOS 26.1 som deployment target er den største vekstbremsen (P0 for vekst)

`IPHONEOS_DEPLOYMENT_TARGET = 26.1`. iOS 26.1 ble tilgjengelig i november 2025. Alle som ikke har oppdatert til nyeste større versjon kan ikke installere HAVEN — de får «krever iOS 26.1 eller nyere» i App Store.

For et produkt hvis vekstmodell er «bruker inviterer venn i samme rom» er dette ikke en detalj. **Invitasjonen feiler hos mottakeren, ikke hos avsenderen** — og det er det verst tenkelige stedet en viral løkke kan brekke, fordi avsenderen opplever det som at HAVEN ikke virker.

August-vurderingen bekreftet at en diagnostisk Release-build med target 18.0 kompilerte. Det gjenstår runtime-testing, men kompilering er allerede bevist. Dette er sannsynligvis den høyest rangerte enkelthandlingen i hele rapporten målt i vekst per innsats.

`TARGETED_DEVICE_FAMILY = "1,2,7"` og `SUPPORTED_PLATFORMS` inkluderer `xros`. visionOS i target-familien bør bekreftes som villet før innsending.

### F8 — 4.7 avhenger av et spørsmål dere ennå ikke har svart entydig på (P0 for review-historien)

Hvis cellene/skeletonene lastes ned og tolkes i runtime, er de «software that is not embedded in the binary», og hele 4.7 gjelder — inkludert **4.7.4**: «You must provide an index of software and metadata available in your app. It must include universal links that lead to all of the software offered in your app.»

Med F1 slik den står i dag ligger HAVEN nærmere plattform-siden enn dere sannsynligvis ønsker. Med en kompilert allowlist og førsteparts, rent deklarative konfigurasjoner er «dette er data som rendres av native kode, ikke nedlastet software» en holdbar posisjon. Det er én kodeendring som avgjør hvilken av de to historiene som er sann.

### F9 — Filstørrelser gjør inventaret uetterprøvbart (P2, men årsak til P0)

`ConfigurationCatalogCell.swift` er 947 KB. `BootstrapView.swift` 485 KB, `ChatWorkbenchParityCells.swift` 435 KB, `ContentView.swift` 368 KB. Til sammen ~80 700 linjer Swift i app + celler fordelt på 63 filer.

Dette er ikke i seg selv en review-risiko. Men det er den direkte årsaken til at ingen kan svare presist på «hva er nåbart i Release», og det er derfor F5s inventarpunkt må løses maskinelt og ikke ved gjennomlesning.

---

## 5. Apple-analyse: hva som faktisk er tillatt

| Ønsket kapabilitet | Tillatt? | Hjemmel | Hva som må gjøres |
|---|---|---|---|
| Betale for å låse opp celler | Ja, men **kun via IAP** | 3.1.1 | StoreKit 2 consumable eller non-consumable |
| Kreditt kjøpt via PSP utenfor appen | **Nei** | 3.1.1 + 3.1.3-preamble | Fjern fra iOS |
| Lenke/CTA til ekstern top-up | **Nei i Norge** | 3.1.1(a); Norge ikke i regionslisten | Fjern helt fra iOS-flaten |
| Ha en wallet i appen | Ja, hvis Organization-konto | 3.1.5(i) | Men fritar ikke 3.1.1 — anbefaler å ta den ut av v1 |
| Kreditt som utløper | **Nei** hvis kjøpt via IAP | 3.1.1 | Velg: enten IAP eller utløp, ikke begge |
| «Tjen kreditt ved å verve venner» | **Nei** | 3.1.5(v), 3.2.2(x) | Viral belønning kan ikke være kreditt |
| Butler-profil på tvers av enheter | Ja | — | Utløser 5.1.1(v): kontosletting i app blir påkrevd |
| Egen innlogging uten Google/Facebook | Ja, uten Sign in with Apple | 4.8, første unntak | Egen kontoløsning holder |
| BankID/Vipps som innlogging | Ja, unntatt fra 4.8 | 4.8, fjerde unntak («government or industry-backed […] electronic ID») | Verdt å merke seg for senere |
| Invitasjon/chat mellom personer | Ja | 1.2 | Filter, rapportering, blokkering, publisert kontaktinfo |
| Nedlastede celler | Ja, under 4.7 | 4.7.1–4.7.5 | 4.7.4-indeks med universal links — unngås ved kompilert allowlist |

**Én uløst spenning å ta stilling til bevisst:** 3.1.1 krever at IAP-kreditt aldri utløper og at det finnes gjenopprettingsmekanisme. 5.1.1(v) krever at kontosletting sletter brukerens data. Apple publiserer ingen veiledning om hvordan disse to forholder seg til en saldo ved kontosletting. Ta et dokumentert standpunkt før innsending i stedet for å bli spurt.

---

## 6. Regulatorisk analyse (Norge/EØS)

**Ikke juridisk rådgivning.** Kildene er hentet 19. august 2026.

### Det avgjørende: `merchantID`

Den norske e-pengedefinisjonen ([finansforetaksloven § 2-4 annet ledd, gjengitt av Finanstilsynet](https://www.finanstilsynet.no/tillatelser/e-pengeforetak/definisjonen-av-e-penger/)) har fire kumulative vilkår. Det fjerde er at verdien er «anerkjent som betalingsmiddel av **andre foretak enn utstederen**».

`DiMyAccessCell` er merchant-scoped. Så lenge Digipomps er både utsteder og eneste akseptør, treffes vilkår 4 sannsynligvis ikke. I det øyeblikket en annen juridisk enhet er akseptør og har oppgjørsavtale med utsteder, er vilkår 4 nettopp det som slår inn — og produktet bytter regulatorisk klasse.

Finanstilsynet legger nå til grunn EU-kommisjonens januar 2025-tolkning bygget på EU-domstolen i sak **C-661/22 (ABC Projektai)**: «Mottakeren må faktisk motta e-pengene, og må dermed også ha et kontraktsforhold med utstederen.»

**Anbefaling:** hvis v0 virkelig er enutsteder, skal `merchantID` fjernes eller hardkodes til én verdi — ikke bare stå ubrukt. Latent flerpartsfunksjonalitet er en omgåelsesrisiko, og Finansdepartementet advarte uttrykkelig mot dette i [klagevedtakene 8. april 2025](https://www.finanstilsynet.no/nyhetsarkiv/nyheter/2025/vedtak-om-e-penger-og-unntaket-for-begrenset-nettverk/).

### Ihendehaver-coins og MiCA

ESAenes felles retningslinjer [JC 2024 28](https://www.esma.europa.eu/sites/default/files/2025-03/JC_2024_28_Guidelines_on_explanations_and_opinions__and_the_standardised_test_for_crypto-assets_under_MiCA.pdf), som Finanstilsynet la til grunn i tilsynspraksis fra januar 2026, punkt 19:

> "A token may be considered 'non-transferable' only where at least the following conditions are satisfied (i) the token is accepted only by the issuer or offeror, and (ii) **there is no technical possibility for the token to be transferred** by a holder to persons other than the issuer or offeror."

«No technical possibility» — kontraktsvilkår og ToS teller ikke. Chaumianske blindede coins er per konstruksjon ihendehaverinstrumenter og trivielt overførbare ved å dele bytes, med mindre noe binder dem kryptografisk til enhet eller konto. Dagens design oppfyller ikke testen slik den er formulert.

### Positivt presedensmateriale

Finansdepartementets klagevedtak i **Facebook/FBPIL-saken (14.03.2025)** er nærmest HAVEN-caset: spillkonto for kjøp av digitalt innhold i egne spill. Finanstilsynet vurderte at virksomheten «isolert sett kunne anses tilstrekkelig begrenset og funksjonelt tilknyttet kjøp av digitalt innhold i spill», og departementet «har ikke funnet grunn til å overprøve denne vurderingen». **Amfi Drift-saken (18.03.2025)** går motsatt vei: gavekort brukbart hos mange forhandlere i ulike bransjer var for bredt.

Lærdommen: én utsteder, ett funksjonelt sammenhengende digitalt innhold, én app ligger på riktig side. En voksende katalog med tredjeparts celleleverandører gjør det ikke.

### Terskler og prosess

- **Meldeplikt** etter finansforetaksforskriften § 1-8 utløses når samlet transaksjonsverdi siste 12 måneder overstiger **EUR 1 mill.** Skjema KRT-3040 i Altinn.
- **Konsesjon** som e-pengeforetak: gebyr kr 30 000, normalt tre måneders saksbehandling etter innbetalt gebyr, startkapital sannsynligvis EUR 350 000 (bekreftet i Prop. 125 L (2013–2014), ikke reverifisert mot gjeldende forskrift).
- **PSD3/PSR**: politisk enighet 27. november 2025, ECON godkjente 5. mai 2026, ikke formelt vedtatt eller publisert i EU-tidende per 19. august 2026. Kommisjonens PSR-forslag har en «physical premises»-formulering i fortalen som vil ramme rene app-baserte kreditter hvis den overlevde forhandlingene — **uverifisert**, og en reell nedsiderisiko å følge.

### Hvorfor IAP løser begge problemer samtidig

Dette er rapportens viktigste enkeltinnsikt:

En StoreKit consumable er per konstruksjon ikke-overførbar, ikke innløselig i penger, aksepteres kun av utsteder, og **Apple er betalingsbehandler**. Det plasserer produktet i `access entitlement` / `usage quota` i deres egen matrise — den eneste tillatte v0-varianten — og fjerner PSP-forholdet, kundemiddelspørsmålet og AML-eksponeringen fra v1 helt. Apple-kravet og Finanstilsynet-risikoen peker samme vei. Det er sjelden, og det bør utnyttes.

---

## 7. Viral vekst: hva som faktisk kan bære den

### Rekkefølgen er ikke valgfri

Alt annet i denne seksjonen er akademisk så lenge `IPHONEOS_DEPLOYMENT_TARGET = 26.1`. En invitasjonsløkke der mottakeren ikke kan installere appen har k-faktor null uansett hvor god mekanikken er. **Senk gulvet først.**

### Tre tjenestetyper, rangert

**1. Butler-til-butler-håndtrykk — hovedløkken.**
To personer i samme rom; hver butler forhandler på vegne av sin eier og returnerer bare det omforente resultatet: hva dere bør snakke om, hvilken tid dere begge har ledig, hvilken fil du mente å sende. Egenskapene passer HAVENs arkitektur usedvanlig godt:

- krever nøyaktig to personer, så invitasjonspresset ligger *i* verdien og er ikke påklistret
- peer-to-peer, ingen server, ingen katalog, ingen publisert innhold → verken 1.2 eller 4.7 utløses
- resultatet er privat mellom de to → ingen modereringsflate
- fungerer uten konto
- og det er strukturelt noe en generell assistent-app ikke kan gjøre — det er den faktiske vollgraven

Infrastrukturen finnes allerede: `NSBonjourServices _haven-radar._tcp`, `NSLocalNetworkUsageDescription`, `NSNearbyInteractionUsageDescription`, `ConferenceNearbyRadarSurfaceView` med ærlig presisjonsmodell (`precise`/`approximate`/`unknown`), og `DeviceCallbackCapabilityContract`. Det som mangler er invitasjonsløkken, ikke radaren.

**2. Gjest-celle — den undervurderte.**
La en HAVEN-bruker kjøre en celle *for* en ikke-bruker, med resultatet levert som en lenke. Mottakeren får verdi uten å installere noe, og ser hvor den kom fra. Dette er den eneste mekanikken som gir verdi før installasjon, og den omgår hele iOS-gulvproblemet i mellomtiden.

**3. Delt artefakt med tilbakelenke.**
Alt butleren produserer — agenda, oppsummering, plan — eksporteres som noe som kan deles og bærer en lenke tilbake. Lav k-faktor, null review-risiko, kan shippes i v1.

### Den ærlige advarselen

Nearby-basert viralitet er **klyngeviralitet**. Den virker eksplosivt i tette rom — konferanser, kontorer, studiestart — og gjør ingenting i en spredt befolkning. Vekststrategien må derfor være «mett én klynge om gangen», ikke bred lansering. Det var det Arendalsuka var ment å være.

### Hva som ikke kan brukes

Verving kan ikke belønnes med kreditt. 3.1.5(v): «Cryptocurrency apps may not offer currency for completing tasks, such as […] encouraging other users to download». 3.1.2(a) og 3.2.2(x) peker samme vei. Belønningen må være funksjonell — mer butler, ikke mer valuta.

---

## 8. Anbefalt sekvens

### Sprint 0 — fjern det som blokkerer alt annet

1. **Senk `IPHONEOS_DEPLOYMENT_TARGET`** til laveste versjon dere faktisk vil teste på fysisk enhet. Kompilering på 18.0 er allerede bevist; det som gjenstår er runtime-verifisering.
2. **Bevis butler-persistens.** Én test: sett navn → riv runtime → les navn. Uten den er kjerneløftet en påstand.
3. **Legg inn `PrivacyInfo.xcprivacy`** med `CA92.1` for UserDefaults, og gjør en full required-reason-gjennomgang.
4. **Rett `ageRatingHint`** til gjeldende verdier, og svar på de nye social-media-spørsmålene i App Store Connect **før september 2026**.
5. **Avklar `DEVELOPMENT_TEAM`** og verifiser AASA på `haven.digipomps.org`.

### Sprint 1 — gjør scope-historien sann

6. **Bytt selverklæring med kompilert allowlist.** Interesse-token blir nødvendig, ikke tilstrekkelig.
7. **Legg produksjonsverten inn i `approvedRemoteHosts`, ta staging ut av Release.**
8. **Maskingenerer release-inventaret** fra den signerte builden som en test. Da kan review notes aldri divergere fra virkeligheten igjen.
9. **Ta `DiMyCellProtocolCells` ut av iOS-app-targetet.**

### Sprint 2 — betaling, riktig vei

10. **StoreKit 2 consumable** som eneste kjøpsvei på iOS. Kvitteringsvalidering server-side mot HAVENs entitlement-modell.
11. **Behold `PersonalUsageQuotaLocalCell`s posturfelter** — de blir nå sanne uten forbehold, fordi Apple er utsteder.
12. **Ta stilling til utløp** — 3.1.1 forbyr at IAP-kreditt utløper. Skriv ned valget.
13. **Ecash-stacken flyttes til web/desktop**, der Apples regler ikke gjelder og der `merchantID` kan utvikles videre med juridisk løp ved siden av.

### Sprint 3 — det sosiale laget, én retningslinje om gangen

14. Butler-til-butler-håndtrykk, device-to-device, ingen katalog. Ingen 1.2-flate.
15. Deretter invitasjonsbasert chat med full 1.2-pakke: filter, rapportering, blokkering, publisert kontaktinfo.
16. Deretter offentlig profil med eksplisitt samtykke + kontosletting i app (5.1.1(v)).

**Aldri pakk «første sosiale funksjon» sammen med «første innsending».** Oppdateringer på en godkjent app er billigere å få avvist enn en førstegangsinnsending.

---

## 9. Claim ledger

| Påstand | Type | Status | Falsifikator / minste neste bevis |
|---|---|---|---|
| C1: Ecash-unlock kan godkjennes av Apple | capability | **contradicted** | Skriftlig Apple-bekreftelse, eller godkjent build med samme mekanikk |
| C2: Norge kan bruke ekstern kjøpslenke | capability | **contradicted** | `no` dukker opp i Apples regionsliste |
| C3: IAP consumable løser både Apple og DiMy-matrisen | normative | **supported** | En regulatorisk vurdering som klassifiserer StoreKit-kreditt som money-like |
| C4: Scope-gaten gjør inventaret fast ved release | assertive | **contradicted** | Kompilert allowlist der interesse-token ikke er tilstrekkelig |
| C5: Butlerprofilen overlever omstart | capability | **unsupported** | Én restart-test som leser navnet tilbake |
| C6: Butleren lever i entiteten, ikke enheten | capability | **unsupported** | `EntityAuthorityCommit`-replikering bevist mellom to enheter |
| C7: Kredittene er ikke e-penger | regulatory | **unsupported** | Skriftlig juridisk betenkning; `merchantID` fjernet eller låst |
| C8: Coins er ikke-overførbare i MiCA-forstand | regulatory | **contradicted** | Teknisk umulighet for overføring, ikke bare policy |
| C9: Nearby-scanner driver viral vekst | predictive | **open**, eier: Kjetil | Målt k-faktor i én tett klynge etter at iOS-gulvet er senket |
| C10: Innhold er kryptert med brukerkontrollerte nøkler | capability | **contradicted for oppstartsvault** | Bevis for at ingen Release-sti bruker `aquireKeyForTag` mot startup-vaulten |
| C11: Appen er innsendbar i dag | assertive/allOf | **contradicted** | Alle Sprint 0-punkter lukket + prosessert build i App Store Connect |

---

## 10. Menneskelige beslutninger

1. Laveste iOS-versjon dere faktisk vil støtte og fysisk teste.
2. Om v1 bruker StoreKit IAP, eller om betaling utsettes til v1.1 og v1 er gratis.
3. Om kreditt kan utløpe — og dermed om den kan selges via IAP.
4. Om `merchantID` fjernes fra v0-stien eller låses til én verdi.
5. Hvilken av de to 4.7-posisjonene dere velger: kompilert deklarativ allowlist, eller plattform med 4.7.4-indeks.
6. Om produksjonsverten er `haven.digipomps.org`, og om visionOS skal være med i target-familien.
7. Om det skal innhentes skriftlig juridisk betenkning før noen offentlig uttalelse om kredittenes klassifisering.

---

## 11. Språkregler for offentlig omtale

Fra `01_TERMINOLOGY_AND_CLAIMS_CANON.md`, som gjelder også for App Store-metadata:

**Ikke skriv:** «regulatorisk avklart» · «ikke e-money» · «penger uten lisensbehov» · «global reputation» · «kjører lokalt» der det ikke er bevist per datatype.

**Skriv i stedet:** «tilgangsrettighet» eller «brukskvote» for kreditten · «domenebegrenset identitet» for entiteten · og for butleren det som faktisk kan bevises: proaktivitet av som standard, ingen rå atferdslogg, ingen emosjons- eller helseinferens, ingen modellkall ved kapabilitetsoppdatering. Det er sterkere enn en generisk personvernpåstand, nettopp fordi hvert ledd har en test bak seg.

---

## 12. Autoritative kilder

**Apple**
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Oppdaterte retningslinjer 8. juni 2026](https://developer.apple.com/news/?id=a233fmpw) · [6. februar 2026](https://developer.apple.com/news/?id=d75yllv4) · [13. november 2025](https://developer.apple.com/news/?id=ey6d8onl)
- [Communication and promotion of offers in the EU (regionsliste)](https://developer.apple.com/support/communication-and-promotion-of-offers-on-the-app-store-in-the-eu/)
- [DMA and apps in the EU](https://developer.apple.com/support/dma-and-apps-in-the-eu/) · [Endringer for EU 18. august 2026](https://developer.apple.com/news/?id=gmws0jgp)
- [Music Streaming Services Entitlement (EEA)](https://developer.apple.com/support/music-streaming-services-entitlement-eea/)
- [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) · [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/) · [Sosiale medier-spørsmål, 9. juli 2026](https://developer.apple.com/news/?id=tlur8uvi)
- [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)

**Regulatorisk**
- [Finanstilsynet: definisjonen av e-penger](https://www.finanstilsynet.no/tillatelser/e-pengeforetak/definisjonen-av-e-penger/)
- [Vedtak om e-penger og unntaket for begrenset nettverk, 8. april 2025](https://www.finanstilsynet.no/nyhetsarkiv/nyheter/2025/vedtak-om-e-penger-og-unntaket-for-begrenset-nettverk/) · [Klagevedtak Facebook (PDF)](https://www.finanstilsynet.no/contentassets/7d04f66515e84fb6a767e918db255b7f/klagevedtak---facebook.pdf) · [Klagevedtak Amfi Drift (PDF)](https://www.finanstilsynet.no/contentassets/7d04f66515e84fb6a767e918db255b7f/klagevedtak---amfi-drift.pdf)
- [Finanstilsynet: kryptoeiendeler/MiCA](https://www.finanstilsynet.no/tema/kryptoeiendeler-mica/) · [ESA JC 2024 28, standardisert test (PDF)](https://www.esma.europa.eu/sites/default/files/2025-03/JC_2024_28_Guidelines_on_explanations_and_opinions__and_the_standardised_test_for_crypto-assets_under_MiCA.pdf)
- [Meldepliktig betalingstjenestevirksomhet](https://www.finanstilsynet.no/tillatelser/meldepliktig-betalingstjenestevirksomhet/) · [E-pengeforetak](https://www.finanstilsynet.no/tillatelser/e-pengeforetak/)
- [EBA: final Guidelines on the limited network exclusion](https://eba.europa.eu/publications-and-media/press-releases/eba-publishes-final-guidelines-limited-network-exclusion)
- [Direktiv 2009/110/EF (EMD2)](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX%3A32009L0110) · [COM(2023) 367 PSR-forslag](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX%3A52023PC0367) · [Legislative Train: PSR](https://www.europarl.europa.eu/legislative-train/theme-an-economy-that-works-for-people/file-revision-of-eu-rules-on-payment-services)

**Interne**
- `DiMyDocuments/ValueRedistribution/01_TERMINOLOGY_AND_CLAIMS_CANON.md`, `02_PRODUCT_VARIANT_AND_REGULATORY_MATRIX.md`, `05_ASSURANCE_MATURITY_MATRIX.md`
- `Documentation/Apple_Arendalsuka_Maturity_Evaluation_2026-08-03.md`, `AppStoreReviewNotes_PersonalCopilotV1.md`, `PersonalButlerProfileAndProactivity_2026-07-13.md`, `KeyHandlingAndContentCryptoAssessment.md`, `ConferenceNearbyRadarImplementationPlan.md`

---

## 13. Hva denne rapporten ikke dekker

- **AASA og produksjonsvert** kunne ikke probes fra dette miljøet (proxy-blokkert). Uverifisert.
- **App Store Connect-status** — avtaler, DSA/trader-status, privacy labels, export compliance, screenshots — kunne ikke auditeres uten innlogget sesjon.
- **Om Release faktisk krypterer innhold med `aquireKeyForTag`** er ikke sporet til ende. F6 er derfor et flagg, ikke en dom.
- **Ingen build eller test ble kjørt** i denne runden. Modenhetsnivåene bygger på kildeaudit og på testresultater dokumentert i eksisterende Documentation-filer.
- **Ordlyden i finansforetaksloven, finansforetaksforskriften og hvitvaskingsforskriften** er gjengitt via Finanstilsynet og Finansdepartementet, ikke hentet fra Lovdata (automatisk henting er blokkert). Bør kontrolleres manuelt før den brukes i noe formelt.
