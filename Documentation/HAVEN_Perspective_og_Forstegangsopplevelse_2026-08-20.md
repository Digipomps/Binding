# HAVEN — rotårsak til perspective-feilen, og analyse av førstegangsopplevelsen

Dato: 20. august 2026
Grunnlag: kildeaudit av `Binding` og `CellProtocol`, kombinert med fire faktiske kjøringer av HAVEN på iOS 18.6-simulator (signert og usignert build), konsoll- og os_log-fangst, og inspeksjon av appens datakontainer.

---

# Del 1 — Perspective-feilen

## 1.1 Hva brukeren ser

På Chat-fanen, ved hver oppstart:

> **Co-Pilot**
> Kunne ikke hente innhold
> 1 felt venter på gyldig tilgang eller ferdig synkronisering. Berørte celler: perspective.

Reproduserbar i alle fire kjøringer, både på rene installasjoner og på relansering mot samme container. Selvheler ikke innen 60 sekunder.

## 1.2 Mekanismen, sporet gjennom koden

Kjeden er entydig:

1. **Co-Pilot-konfigurasjonen har to referanser.** Bekreftet fra appens egen lagrede konfigurasjon, fanget i os_log:
   ```json
   {"endpoint":"cell:///PersonalChatHub","label":"chatHub","subscribeFeed":true}
   {"endpoint":"cell:///Perspective","label":"perspective","subscribeFeed":false}
   ```
2. **Skeletonet binder `perspective.activePurpose.purposes`** — `ConfigurationCatalogCell.swift:9155`.
3. **Probe-utledningen kutter til rot-keypath.** `SkeletonBindingProbeSupport.rootProbe(from:labels:)` (`ContentView.swift:176-205`) gir `RootProbe(label: "perspective", rootKeypath: "activePurpose")`, altså kvalifisert keypath `perspective.activePurpose`.
4. **Probing kjøres med hard budsjettgrense.** `waitForReadableBindingRoots` (`ContentView.swift:6093-6130`):
   ```swift
   let maxAttempts = 5
   let retryDelayNanoseconds: UInt64 = 300_000_000
   let perProbeTimeoutNanoseconds: UInt64 = 900_000_000
   ```
   Totalt budsjett ≈ 5 × 900 ms + 4 × 300 ms ≈ **6 sekunder**. Deretter `.failed`.
5. **`.failed` er en blindvei.** `ContentView.swift:6009-6023` setter `failurePlaceholderSkeleton` og returnerer `false`. Det finnes ingen ny probing når flaten dukker opp igjen, ingen «prøv på nytt»-handling for brukeren, og ingen automatisk gjenoppretting.
6. **Leseren på cellesiden returnerer enten data eller `"denied"`.** `PerspectiveCell.swift:96-107`:
   ```swift
   await addInterceptForGet(requester: owner, key: "activePurpose", getValueIntercept: { keypath, requester in
       if await self.validateAccess("r---", at: "activePurpose", for: requester) {
           return await self.activePurposesPayload(...)
       }
       return .string("denied")
   })
   ```
7. **`"denied"` klassifiseres som feil.** `SkeletonBindingProbeSupport.failureDetail(from:)` (`ContentView.swift:101-118`) returnerer feildetalj for strenger som starter med `denied`.

Kjeden er bekreftet. Det som gjensto var *hvorfor* proben ikke lykkes.

## 1.3 Rotårsak — sterkt understøttet hypotese

**Perspective-cellen får en ny eier-identitet ved hver eneste oppstart, og den persisterte celletilstanden fra forrige kjøring tilhører en identitet som ikke lenger finnes.**

Beviskjeden:

**A. Eier-UUID er ny hver gang.** Fra konsollfangst i tre uavhengige kjøringer:

| Kjøring | `PerspectiveCell init. Owner:` |
|---|---|
| Usignert build | `7D942B02-6ACD-445A-9D78-ED95A2AA4DA2` |
| Signert build, ren install | `18F81FBB-4148-46AB-BC95-431DC612DECC` |
| Signert build, relansering | `2A034FD3-8CAE-4043-8285-84BDE86C9710` |

Ingen gjenbruk. Dette er nøyaktig oppførselen til `BindingStartupIdentityVault` — en `actor` med `identityUUIDsByContext` og `identitiesByUUID` som rene minne-dictionaries, `vaultReference` med ny `UUID()` per prosess, og `P256.Signing.PrivateKey()` generert på nytt uten lagring. `RootView` sin oppstart kaller kun `ensureInfrastructureBaseline()`, som setter denne vaulten; overgangen til den Keychain-baserte `IdentityVault.shared` skjer i `ensureBaseline()`, som bare kalles fra `ContentView`.

**B. All autorisasjon er registrert *for eieren*.** `setupKeys(owner:)` kaller `registerContracts(requester: owner)` og `addInterceptForGet(requester: owner, ...)`. Når eieren er ny hver gang, kan ingen kontrakt overleve en omstart.

**C. `Perspective.json` blir aldri skrevet.** Jeg listet hele appens datakontainer. Cellene persisterer `typedCell.json`, `keypathstorage.json`, `CellConfiguration.json` og `SkeletonExamples.json` — men det finnes **ingen `Perspective.json` noe sted**. `persistPerpective()` kalles fra `PerspectiveCell.swift:811` og `:1191`, altså fra skrivestier som aldri nås fordi lesestien er blokkert. Appen står permanent i førstegangstilstand for perspective.

**D. Nøyaktig ett felt feiler.** Meldingen sier «1 felt». Co-Pilot-skeletonet binder mange `chatHub.*`-keypaths og minst én `perspective.*`. Alle chatHub-probene lykkes; kun perspective feiler. Var årsaken generell treghet ved kaldstart, ville `chatHub` — den større cellen, med `subscribeFeed: true` — feilet minst like ofte. At det deterministisk er den separat eide, ikke-abonnerte Perspective-referansen som ryker, peker klart mot autorisasjon og ikke mot timing.

**Dette er samme defekt som audit-funn F4.** Den identiteten som skal bære «butleren lever i brukerens entitet, ikke på enheten» er den samme identiteten som Perspective-cellen trenger for å gjenkjenne sin egen lagrede tilstand. Én rot, to symptomer: butleren husker ikke navnet sitt, og Chat-flaten viser feil ved hver oppstart.

### Hva jeg ikke har bevist

Jeg har ikke fanget selve feilstrengen fra proben. `"denied"` og `"Timeout while reading perspective.activePurpose"` gir identisk brukertekst, og detaljstrengen logges verken til stdout eller os_log — `diagnosticsStore.record` skriver til et internt lager, og `summarizeBindingFailures` (den tekniske varianten) brukes kun i conference-rewarm-grenen.

**Minste avgjørende neste bevis:** logg `requester.uuid` sammen med `storedOwnerIdentity.uuid` i `PerspectiveCell`s `activePurpose`-intercept, og logg feildetaljen i `.failed`-grenen i `ContentView.swift:6009`. Hvis de to UUID-ene avviker, er hypotesen bekreftet på under ett minutt.

## 1.4 To feil, ikke én — og den andre er viktigere

Selv når rotårsaken er rettet, står en designfeil igjen:

> **Hovedflaten har et 6-sekunders budsjett og en permanent feiltilstand.**

Dere har nettopp senket deployment target til iOS 18.0. Det betyr eldre og tregere maskinvare enn utviklingsmaskinen. En iPhone fra 2019 på kaldstart, med lavt batteri eller under minnepress, kan trivielt bruke mer enn 900 ms på å initialisere en celle. Da får den brukeren nøyaktig denne skjermen — og aldri noe annet, fordi det ikke finnes ny probing.

Tre uavhengige rettelser bør inn:

| Rettelse | Hvorfor |
|---|---|
| Ny probing når flaten dukker opp igjen (`onAppear`/scene-aktivering) | Fjerner blindveien uansett årsak |
| Delvis rendering: vis det som er lesbart, degrader kun det feltet som mangler | Ett felt av mange skal ikke ta ned hele flaten |
| Synlig, menneskelig gjenopprettingshandling i stedet for teknisk statustekst | «Berørte celler: perspective» er interne begreper i brukerflaten |

Den midterste er den viktigste. Co-Pilot-skeletonet har et fullt fungerende chat-grensesnitt bak denne feilmeldingen; brukeren nektes alt fordi ett purpose-felt ikke svarte.

## 1.5 Anbefalt rekkefølge

1. Logg requester- og eier-UUID i proben. Bekreft eller avkreft hypotesen. **Under én time.**
2. Gjør identiteten persistent — flytt oppstart til den Keychain-baserte vaulten, eller la `ensureInfrastructureBaseline()` gjenopprette identitet fra Keychain før noen celle instansieres. Dette lukker samtidig F4 og gir «butler i entitet» et fundament.
3. Gjør probe-feil ikke-terminal: ny probing ved gjenvisning, delvis rendering, menneskelig feiltekst.
4. Legg til en regresjonstest: kaldstart → Chat → ingen `failurePlaceholderSkeleton`. Kjør den på laveste støttede iOS-versjon.

---

# Del 2 — Førstegangsopplevelsen

Målet, slik det ble formulert: brukeren skal tenke *«wow, dette er dødsfett og akkurat det jeg trenger»*, det skal være troverdig trygt, og det skal kjennes som å komme hjem.

Jeg tar det på alvor som en designoppgave, ikke som en stemning.

## 2.1 Den sentrale spenningen

«Wow» og «hjemme» kommer normalt fra motsatte kanter.

**Wow** i assistentprodukter kommer nesten alltid fra at systemet *vet noe om deg*. Det krever data. Data krever tilganger. Tilganger krever at du gir fra deg noe før du har fått noe.

**Hjemme** kommer fra det motsatte: at ingenting krever noe av deg, at det du la fra deg ligger der du la det, og at ingen har rotet i skuffene mens du var borte.

Nesten alle produkter velger wow og betaler med utrygghet. HAVEN har en sjelden mulighet, fordi arkitekturen faktisk kan levere begge — men bare hvis wow-øyeblikket **flyttes fra «se hva jeg vet om deg» til «se hvor fort dette ble ditt»**.

Det er den ene strategiske beslutningen i hele denne analysen. Alt annet følger av den.

## 2.2 Hva «å komme hjem» faktisk består av

Fem komponenter. For hver: hva den krever, og hva i HAVEN som allerede kan gjøre den sann.

### 1. Ingen terskel
Hjemme ber ikke om legitimasjon i døra. Ingen konto, ingen e-post, ingen tilganger før noe er levert. Apple 5.1.1(v) sier det samme: *«If your app doesn't include significant account-based features, let people use it without a login.»* Dette er allerede v1-scopet.

### 2. Gjenkjennelse av hensikt, ikke av person
Førstegangs har appen ingenting å vite om deg. Den kan likevel gjenkjenne *hva du er her for*. `purpose://`-modellen er bygget for nøyaktig dette, og Perspective-cellen er allerede den delen av systemet som holder formål og vekt. Ironisk nok er det den cellen som i dag tar ned flaten.

### 3. Bevist ro
Trygghet som påstand er verdiløs. Trygghet som **kvittering** er noe helt annet. `BindingPersonalButlerPolicy` har allerede feltene: `providerInvoked=false`, `derivedFromDescriptorsOnly=true`, `retainsRawFeedback=false`, proaktivitet av som standard, stilletid 22–08, fast signal-allowlist. Det er ikke markedsføring — det er tilstand med tester bak.

### 4. Eierskap gjennom navngiving
Å gi noe navn er den billigste og sterkeste eierskapshandlingen som finnes. Men navngiving *før* verdi er en oppgave. Navngiving *etter* første nytte er et ritual.

### 5. Retur
Det er andre besøk som avgjør om det er et hjem. Det krever at ting overlever omstart. **Dette er i dag ubevist** — se Del 1 og audit F4. Uten persistens finnes ingen «hjem», bare gjentatte førstemøter.

## 2.3 De første seksti sekundene

Konkret forslag. Hvert steg har en begrunnelse og en grense.

**0–3 s · Døra**
Ingen splash med logo. Ingen konto. Ingen tillatelsesdialog. Én rolig flate, butleren allerede til stede, og én linje som gjør det klart hva som skjer nå:

> «Jeg kjører her på telefonen din. Ingenting forlater den uten at du sier ja. Hva har du på hjertet?»

Dette er både velkomsten og trygghetsløftet, og det koster null skjermbilder.

**3–20 s · Første forespørsel**
Brukeren skriver noe ekte. Butleren gjør det. Ingen «her er hva jeg kan»-karusell — den ber brukeren om å lære et system i stedet for å bruke det.

Hvis flaten trenger et frø: tre forslag hentet fra det brukeren faktisk kan ha bruk for uten noen tilgang — «skriv ned en idé», «hjelp meg tenke gjennom noe», «hva bør jeg spørre deg om?». Det siste er en undervurdert inngang: den lar butleren forklare seg selv på brukerens initiativ.

**20–30 s · Kvitteringen — dette er wow-øyeblikket**
Rett etter første svar, ikke som en fane eller en innstilling, men som en liten linje i samtalen:

> «Det der gjorde jeg lokalt. Ingen modell ble kontaktet, ingenting ble lagret utenfor telefonen din.»
> *Se hva jeg har tilgang til →*

Wow-et er ikke at den svarte. Wow-et er at den **fortalte deg hva den ikke gjorde** — og at det er etterprøvbart. Ingen assistent gjør dette. Det er den ene tingen i HAVEN som er både ny, sann og umiddelbart forståelig.

Kravet dette stiller: kvitteringen må være ærlig. Er en ekstern modell kontaktet, må linja si det, med navn. En kvittering som lyver én gang er verre enn ingen kvittering.

**30–45 s · Navngivingen**
Nå, ikke før:

> «Forresten — jeg heter ingenting ennå. Vil du gi meg et navn?»

Avvisning må være helt gratis og aldri gjentas uoppfordret. Et navn som ikke ble valgt er også et valg.

**45–60 s · Én dør, ikke fem**
Ett tilbud, valgt ut fra det brukeren nettopp gjorde. Ikke en tillatelsesmeny. Eksempel:

> «Vil du at jeg skal kunne se kalenderen din når du spør meg om dagen? Jeg leser den bare når du spør, og jeg husker ikke innholdet.»

Just-in-time, med grensen sagt høyt i samme setning som spørsmålet. Dette er både bedre konvertering og bedre review.

**Andre gangs oppstart · Selve hjemfølelsen**
Ikke «velkommen tilbake» som floskel, men beviset: det du la fra deg ligger der. Butleren har navnet du ga den. Ingen badge, ingen «du har gått glipp av», ingen oppfordring til å fullføre profilen.

Dette steget er der «hjem» faktisk oppstår — og det er det eneste steget som er **teknisk blokkert i dag**.

## 2.4 Hva som ikke må skje — og som skjer nå

Fra de faktiske skjermbildene av kjørende app:

| Observert | Konsekvens | Rettelse |
|---|---|---|
| Feilmelding på hovedflaten ved kaldstart | Første inntrykk er «ødelagt» | Del 1 |
| Varselforespørsel før noe er levert, med tekst om enhets-ID og push-token | Ber om noe som virker inngripende, før tillit finnes | Flytt til etter første nytte, og bare når varsler faktisk trengs |
| Rå `NSError` synlig i UI, rødt, på blandet norsk og engelsk | Ser uferdig ut for både bruker og reviewer | Aldri vis systemfeiltekst; logg internt |
| Interne begreper i brukerflaten: «Berørte celler», «synkronisering» | Bryter illusjonen om et hjem, avslører maskineriet | Menneskelig språk i alle brukervendte strenger |
| Fem faner ved første oppstart, inkludert «Matches» | Sprer oppmerksomheten, og Matches hører ikke til i smal v1 | Én flate først; faner kan vokse fram |

Den generelle regelen: **førstegangsbrukeren skal aldri se et ord som bare gir mening for den som skrev koden.**

## 2.5 Hvorfor dette også er den beste review-strategien

Det er verdt å si eksplisitt, fordi det betyr at dere ikke trenger å velge:

| Designvalg | Effekt på bruker | Effekt på Apple review |
|---|---|---|
| Ingen konto ved oppstart | Ingen terskel | 5.1.1(v) tilfredsstilt; kontosletting utløses ikke |
| Just-in-time tillatelser med grensen sagt høyt | Høyere aksept | 5.1.1/5.1.2 er nettopp dette |
| Én flate, alt nåbart fra chat | Ingen forvirring | 4.2 Minimum Functionality besvares av én sammenhengende flyt |
| Fungerer uten nett | Virker overalt | 4.2.3(i) — appen skal virke på egen hånd |
| Kvittering om hva som forlot enheten | Bygger tillit | 5.1.2(i) krever nettopp opplysning om deling med tredjeparts-AI |
| Ingen feilskjerm ved kaldstart | Første inntrykk holder | 2.1 App Completeness — den vanligste avvisningsgrunnen |

Samme design på begge sider av bordet.

## 2.6 Og hvorfor det bærer viral vekst

Den inviterte vennen er den strengeste brukeren dere har. Hen åpner HAVEN fordi noen sa «du må prøve dette», med lav tålmodighet og null investering.

Hen tåler ikke: en konto, en tillatelsesmeny, en tom flate, eller en feilmelding.

Hen tåler: én rolig flate, ett svar, én kvittering, ett navn.

Det er samme sekvens som over. Førstegangsopplevelsen *er* vekstmotoren — ikke noe som kommer i tillegg til den. Og butler-til-butler-håndtrykket fungerer bare hvis begge parter allerede har hatt sitt eget lille øyeblikk med sin egen butler.

## 2.7 Claim ledger

| Påstand | Type | Status | Falsifikator |
|---|---|---|---|
| P1: Perspective-feilen skyldes ny eier-identitet per oppstart | causal | **sterkt understøttet**, ikke bevist | Requester- og eier-UUID logget som like ved en feilende probe |
| P2: `Perspective.json` skrives aldri | capability | **bekreftet** | Filen finnes i appkontaineren etter normal bruk |
| P3: 6-sekundersbudsjettet vil ryke på eldre iOS 18-maskinvare | predictive | **åpen** | Grønn kaldstart på eldste støttede fysiske enhet, ti ganger på rad |
| P4: Kvittering om lokal kjøring er wow-øyeblikket | normative | **antakelse** | Brukertest der kvitteringen fjernes og opplevd verdi er uendret |
| P5: Navngiving etter første nytte slår navngiving før | predictive | **antakelse** | A/B på fullføringsrate for navngiving |
| P6: «Hjem» krever persistens over omstart | normative | **understøttet** | — dette følger av definisjonen, men kan ikke leveres før Del 1 er løst |

## 2.8 Det ene som må gjøres først

Alt i Del 2 forutsetter Del 1.

En butler som får ny identitet ved hver oppstart kan ikke huske navnet sitt, kan ikke kjenne igjen sin egen tilstand, og kan ikke være noens hjem. Den kan bare være et gjentatt førstemøte — som er den nøyaktige motsetningen til det dere vil bygge.

Rett identiteten. Så blir resten mulig.
