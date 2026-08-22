# Relasjoner, invitasjon og datalokasjon — implementasjon 2026-08-20

Skrevet av Claude. **Kompilert og testet 2026-08-21** — se
`HAVEN_Perspective_Entities_and_Invite_Landing_2026-08-21.md`, seksjonen
«Bygg og verifiser», for kommandoene og for hva som fortsatt er rødt.

Mål: gjøre det friksjonsløst å invitere noen som ennå ikke har en entitet i
HAVEN, ved å hente inn relasjonene vi allerede har, finne riktig person når
noen sier «inviter Vegar», og levere en ferdig melding på en kanal
vedkommende faktisk bruker.

---

## Hva som er nytt

Alt ligger i `Binding` (mappene er filsystem-synkroniserte, så ingen
`project.pbxproj`-redigering var nødvendig for kildefilene).

### Kjerne — plattformnøytral, klar for promotering til CellProtocol

| Fil | Innhold |
|---|---|
| `Cells/HavenRelationKit.swift` | `HavenRelationRecord`, endepunkter, E.164/e-post-normalisering, deterministisk id, sammenslåingsregler, forklarbart søk |
| `Cells/HavenContactDocumentKit.swift` | Formatdeteksjon, CSV/TSV med skilletegn- og tegnsett-sniffing, vCard, avhengighetsfri ZIP-leser, XLSX-leser |
| `Cells/HavenContactColumnInference.swift` | Kolonnegjenkjenning på både overskrift og verdiform, og bygging av relasjoner fra tabell eller vCard |
| `Cells/HavenInviteTicket.swift` | `HavenInviteTicket`, lenkekoding, verifisering, meldingstekst per kanal |
| `Cells/HavenResidencyKit.swift` | Lokasjoner, brukervekter, forklarbar rangering, signert kvittering, lokal lagring med lesekontroll |
| `Cells/HavenRelationCellSupport.swift` | Delt `ValueType`-plumbing og presentasjonsrader |

Disse filene importerer bare `Foundation`, `CellBase` og (guardet)
`Compression`/`CryptoKit`. Ingen UIKit, ingen AppKit, ingen Contacts. Flytting
til `CellProtocol/Sources/CellBase` er mekanisk.

### Celler

| Endepunkt | Klasse | Rolle |
|---|---|---|
| `cell:///Relations` | `BindingRelationsCell` | **Single source of truth** for relasjoner i egen entitet |
| `cell:///ContactImport` | `BindingContactImportCell` | Les fil → forhåndsvis → bekreft → skriv |
| `cell:///AddressBook` | `BindingAddressBookCell` | Kontaktvelger, full lesing (opt-in), filvelger |
| `cell:///Invitation` | `BindingInvitationCell` | Signert billett, lenke, ferdig melding, statussporing |
| `cell:///EntityResidency` | `BindingEntityResidencyCell` | Hvor dataene bor, og flytting med kvittering |
| `cell:///EntityScaffoldExtension` | `BindingEntityScaffoldExtensionCell` | Utvid entiteten til nytt scaffold/enhet |

Alle er registrert `.identityUnique` + `.persistant` i
`BootstrapView.registerRelationsAndInviteCells(on:)`, kalt fra alle tre
registreringsstiene — inkludert den tidlige, siden en første registrering som
efemer ikke kan oppgraderes senere.

### Bro

`Binding/ContactSourceBridge.swift` — eneste sted som rører `Contacts` eller en
filvelger. `@MainActor`-singleton med nøytrale `Sendable`-typer ut.

---

## Nøkkelbeslutninger, og hvorfor

**Kontaktvelger før tillatelse.** `CNContactPickerViewController` gir oss bare
de personene brukeren peker på, og utløser ingen tillatelsesdialog i det hele
tatt — OS-et megler. Full `CNContactStore`-skanning finnes, men bak
`addressBook.importAll`, som spør først i det øyeblikket brukeren ba om nettopp
det. Dette følger prinsippet fra førstegangsopplevelsen: verdi før tillatelse,
og grensen sagt i samme setning som spørsmålet.

macOS har ingen velger vi kan drive fra en celle. `supportsPicker` er `false`
der, og flaten sier det i stedet for å vise en død knapp.

**Import er to steg, aldri ett.** En adressebok er ikke en payload som skal
svelges; det er påstander om andre mennesker. `import.ingest` leser og
foreslår, `import.commit` skriver. Forhåndsvisningen viser kolonnekartlegging
med begrunnelse og konfidens, prøverader, hvilke rader som ble hoppet over og
hvorfor, og én linje om hva som faktisk skjer med dataene.

**Deterministisk id, konservativ sammenslåing.** Id-en utledes fra det
sterkeste identifikatoren (e-post > telefon > handle), så samme regneark
importert to ganger gir ikke tvillinger. To poster slås bare sammen når de
deler en sterk identifikator. Likt navn alene flagges som *mulig* dublett og
overlates til brukeren — «Anne Hansen» er ikke en identifikator. E-post
normaliseres uten å strippe punktum eller plusstagger, fordi de er ulike
postbokser hos de fleste tilbydere og en sammenslåing der ville smelte sammen
to virkelige mennesker.

**Telefonnumre nekter heller enn å gjette.** Et feil nummer i en kontaktliste
er verre enn et manglende. Norsk 8-siffer → `+47`, `00`-prefiks håndteres,
alt som ikke passer en kjent form for regionen forkastes.

**Blokkering og «er med» overlever reimport.** En senere fil kan ikke
gjenopplive en blokkert kontakt eller angre at noen er blitt med.

**Import kan angres.** Hver post bærer sin batch. `relations.forgetBatch`
sletter alt som bare kom derfra, men beholder dem du faktisk har hatt kontakt
med, og sier hvor mange av hver.

**Tvetydighet er et svar.** `relations.search` returnerer status `ambiguous`
med et spørsmål i stedet for å plukke den ene. `invite.prepare` leverer det
spørsmålet videre i stedet for å invitere feil person.

**Billetten gir ingenting.** `capabilities` er
`["create_own_entity", "send_contact_request_to_issuer"]` — ingen tilgang, i
noen retning. `audienceToken` er en trunkert hash av endepunktet den ble sendt
til, så mottakersiden kan bekrefte at lenken nådde riktig person uten at lenken
bærer adressen. Signaturen dekker alt utenom beviset selv, og
`issuer`-deskriptoren reiser med, så en helt ny enhet kan verifisere offline.

**Cellen sender aldri noe.** `invite.prepare` returnerer en `mailto:`- eller
`sms:`-URL og ferdig tekst. Brukeren trykker send. Det er både den ærlige
designen og det Apple vil ha.

**Én autoritativ lokasjon.** Per datasett er nøyaktig ett sted autoritativt;
resten er hurtigkopi eller sikkerhetskopi med en uttalt foreldelsesgrense.
Rangeringen min-max-normaliserer hvert kriterium på tvers av kandidatene —
«billigst av disse tre» er en påstand vi kan forsvare, «billig» er det ikke.
En flytting som ikke kan verifiseres med tilbakelesing, skjer ikke.

**Utvidelse gjenbruker enrollment-primitivene.** `IdentityEnrollmentRequest`,
`IdentityEnrollmentApproval`, `IdentityLinkRecord` og `IdentityLinkRevocation`
finnes allerede i CellBase. Cellen er koreografien, ikke kryptografien.
Godkjenningen dekker hashen av forespørselen, så en avlyttet forespørsel kan
ikke pekes om til en annen nøkkel.

---

## Slik tester du det i Binding

Alle seks flatene ligger nå i Personal Co-Pilot-menyen.

1. **Hent noen kontakter.** Åpne «Hent kontakter» → *Velg fra kontaktene*.
   På iOS åpnes systemets velger uten tillatelsesdialog. Velg tre personer.
2. **Se dem i relasjonene.** «Relasjoner» viser dem med kanal-oppsummering og
   hvem som kan inviteres. `relations.state.summary` er den ene linjen.
3. **Importer en fil.** «Kontaktimport» → slipp inn en CSV eller XLSX.
   Se over kolonnekartleggingen — hver rad forklarer hvorfor den ble tolket
   slik. Rett opp med `import.setMapping` `{columnIndex, field}`. Trykk
   *Legg inn i relasjonene mine*.
   Prøv en fil med semikolon og ISO-8859-1; den skal virke.
   Prøv en `.numbers`-fil; du skal få en presis beskjed om å eksportere.
4. **Angre importen.** `relations.forgetBatch` med `batchID` fra svaret.
5. **Sett opp invitasjon.** `invite.configure` med
   `{"landingBase": "https://haven.digipomps.org", "issuerDisplayName": "Kjetil"}`.
   Uten dette får du bare en `haven://`-lenke, og flaten sier fra.
6. **Inviter.** «Invitasjon» → skriv «vegar» i feltet, eller trykk *Lag
   invitasjon* på en kandidat. Du får billett-id, kode, lenke, emnefelt,
   brødtekst og en `handoffURL`. Åpne den, så står meldingen ferdig i Mail
   eller Meldinger. Trykk send selv.
7. **Verifiser mottakersiden.** `invite.verify` med `{"link": "<lenken>"}`.
   Endre ett tegn i lenken og kjør igjen — den skal si at signaturen ikke
   stemmer.
8. **Datalokasjon.** «Datalokasjon» → registrer en `userFolder`-lokasjon med
   `residency.registerLocation`, sett vekter med `residency.setWeight`, se
   rangeringen endre seg, kjør `residency.plan` og så `residency.move`.
   Kvitteringen er signert og listet.
9. **Utvid entiteten.** `extension.beginRequest` med `{"audience": "..."}` gir
   en pakke og en kode. På en annen enhet: `extension.reviewRequest`, så
   `extension.approveRequest`. Tilbake: `extension.acceptApproval`.

Enhetstestene dekker normalisering, dedup, kolonneinferens, CSV/vCard/XLSX
(med en ekte zip bygget i testen), signering og verifisering av billetter, og
vektet rangering:

```
BindingTests/RelationsImportTests.swift
BindingTests/InvitationResidencyTests.swift
```

---

## Hva som ærlig talt ikke er ferdig

**Perspective mangler `addEntity`.** `PerspectiveCell` eksponerer `addPurpose`,
`matchPurpose` og spørringer — men ingen intercept for entiteter.
`transformObjectToWeightedEntity` finnes, men er ikke eksponert. Derfor kan
relasjonene ikke skrives inn i `EntityRepresentation` i dag.
`relations.publishPurposeSignals` publiserer det som faktisk virker
(formålssignaler) og returnerer entitetene som `entityRepresentationDrafts` i
nøyaktig den formen `transformObjectToWeightedEntity` forventer. Dagen en
`addEntity`-intercept finnes, er tilkoblingen én linje.
**Dette krever din godkjenning før noen rører `PerspectiveCell`.**

**`.numbers` kan ikke leses.** Numbers lagrer i IWA — protobuf pakket i en egen
Snappy-variant, uten offentlig spesifikasjon. Vi kjenner igjen filen og gir en
presis beskjed om å eksportere til CSV eller Excel. Å skrive en IWA-leser er
ikke noe jeg vil anbefale.

**Scaffold-destinasjoner skrives ikke av oss.** `residency.move` mot en
`scaffold`-lokasjon lager en signert eksportpakke og en manifest, og markerer
overføringen `pendingAcknowledgement`. Destinasjonen blir ikke autoritativ før
`residency.acknowledgeTransfer` bekrefter samme hash. Det er riktig oppførsel,
men scaffold-siden finnes ikke ennå.

**`extension.acceptApproval` verifiserer ikke godkjennerens signatur.**
`IdentityEnrollmentApproval` bærer `issuerIdentityUUID`, men ingen
nøkkeldeskriptor. Vi sjekker at forespørselens hash stemmer og sier eksplisitt
i svaret at signaturen ikke er verifisert, med råd om å bekrefte koden muntlig.
Å legge en `IdentityPublicKeyDescriptor` på godkjenningen ville løse det —
CellBase-endring, altså din avgjørelse.

**Tilbakekalling er lokal.** `invite.revoke` og `extension.revokeLink` virker
umiddelbart her, men en lenke som allerede er sendt slutter først å virke når
landingssiden sjekker mot listen. Svarene sier dette rett ut.

---

## Hva CellScaffold trenger

1. `GET /i/<base64url-billett>` — dekod, verifiser signatur, vis
   «\<navn\> inviterte deg», la mottakeren opprette sin egen entitet. Ingenting
   annet skal lenken gi.
2. `GET /i/<6-tegns-kode>` — slå opp kort kode, for SMS.
3. Tilbakekallingsliste billettene sjekkes mot.
4. `residency.acknowledgeTransfer`-motpart: ta imot manifest, bekreft hash.
5. En `IdentityPublicKeyDescriptor` på `IdentityEnrollmentApproval`, hvis du
   godkjenner den CellBase-endringen.

`applinks:haven.digipomps.org` ligger allerede i begge entitlements-filene, og
`haven://` er registrert i `Info.plist`. Universal links skal altså virke uten
mer oppsett når landingssiden finnes.

---

## Endringer utenfor de nye filene

- `Binding/BootstrapView.swift` — ny `registerRelationsAndInviteCells(on:)`,
  kalt tre steder.
- `Cells/ConfigurationCatalogCell.swift` — seks nye konfigurasjoner i
  `personalCopilotV1MenuConfigurations()`, og seks nye `case` i
  endepunkt-switchen.
- `Binding.xcodeproj/project.pbxproj` — `INFOPLIST_KEY_NSContactsUsageDescription`
  i begge app-konfigurasjonene.
- `Binding/Binding.entitlements` —
  `com.apple.security.personal-information.addressbook` for macOS-sandboksen.

---

## Bygg og verifiser

Jeg fikk **ikke** kjørt en kompilering: auto-modus i denne økten blokkerte
Codex-kallene, og `device_bash` er Linux uten Xcode. Alt under er derfor
uverifisert kode. Kjør:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/build_binding.sh
./Scripts/test_binding.sh
```

Ting jeg vil se ekstra på i første feilrunde:

- Aktør-isolasjon. App-målet har `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
  testmålet ikke. Alle rene verdityper er derfor merket `nonisolated`, i tråd
  med mønsteret i `FullLibraryView.swift`. Om noe glapp, er det her.
- `SkeletonFileUpload`-kontrakten: hva rendereren faktisk leverer til
  `actionKeypath` ved filvalg. `import.ingest` tar imot `text`, `dataBase64`
  eller et `attachment`-objekt, men jeg har ikke sett den faktiske payloaden.
  Filvelgeren i `addressBook.pickFile` går utenom og er den sikre stien.
- XLSX-lesingen bruker `compression_stream` med `COMPRESSION_ZLIB` (rå
  DEFLATE). Testen dekker lagrede oppføringer; komprimerte er ikke prøvd mot
  en ekte Excel-fil ennå.
