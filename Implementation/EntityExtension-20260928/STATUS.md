# Entitetsutvidelse, scaffoldvalg og varsling — 2026-09-28

## Svar på brukerens spørsmål

**Delvis implementert. Ikke verifisert som sikker, sømløs entitetsutvidelse mellom
alle scaffolds, og ikke klar som samlet produksjonsfunksjon.**

Dette gjelder menneskets entitet og dens avgrensede operasjonelle identiteter.
Scaffoldene blir ikke slått sammen. Verktøytilgang, samme-entitet-bevis,
datareplikering og varslingsabonnement er forskjellige autoriserte operasjoner.
En signatur beviser nøkkelkontroll; den beviser ikke alene at to fysiske personer
er én person. Ingen automatisk sammenslåing av to menneskers data er utført.

## Kilde- og installasjonsstatus

| Del | Kontrollert versjon og funn |
| --- | --- |
| Installert Mac-app | `/Applications/HAVEN.app`, versjon 1.0/build 3. Egen proveniens oppgir bygg 2026-08-17, Binding `893a7388`, CellProtocol `1632ed65`, Debug/staging. Dette er før septemberarbeidet. |
| Binding main | `8ce634f6533f5e63386229639c69c43aac25c31f`, bekreftet med GitHub API 28. september. Native eierkobling integrert via blant annet #30/#34. |
| Claude | `claude/haven-verktoylenke-20260924`, `e24252c3`; nyere «Utvid entiteten» og toveis verktøylenker. Ikke inkludert i main. Arbeidsområdet har også to lokale endrede filer; de er bevart. |
| CellProtocol | Lokal origin/main `81601a6f`; Binding-prosjektet bruker den eksplisitte revisjonen `79497e85`. Den innsjekkede Package.resolved pekte feilaktig på `b5b7282b`; Xcodes løsning korrigerte dette til prosjektets pin. |
| CellScaffold | Lokal origin/main `adf48d46`. APNs/FCM-adapter og DeviceIngress finnes; komplett nettleserregistrering/mottak mangler i undersøkt main. |
| Sprout | Lokal origin/main `7aea5b0f`, med proof-forwarding og Nearby-pakking. Dette er ikke bevis på fullført menneskeidentitet og lese/skrive/indeks-tilgang gjennom alle vertene. |
| Entitetsdata | Publiseringsrapporten 23. september beskriver vedtatt målform/schemaer, ikke ferdig Swift-implementasjon av den samlede datamodellen. |

Bare Binding-remote ble kontrollert direkte mot GitHub denne gangen. Andre main-SHAer
er lokale remote-tracking refs. Ingen antakelse om at disse SHAene er deployet.
Den fysiske telefonens installerte appversjon er ikke kontrollert.

## Rettet konkret sikkerhetsfeil, isolert kandidat

Gren: `codex/entity-extension-security-20260928`. Lokal retting: `811c3e53`.
Separat dokumentasjon/prototype: `2fcd350f`. Ingen av disse er pushet eller installert.
Arbeidsområde: `/Users/kjetil/.codex/worktrees/entity-extension-security-20260928/Binding`.

`BindingEntityScaffoldExtensionCell` hadde en eldre, tilgjengelig flyt som markerte
en kobling aktiv etter kun lokal request-hash-sammenligning. Godkjennerens signatur
ble ikke verifisert. Ugyldig utløpsdato slapp forbi; godkjenningspakken ble heller
ikke bundet til en betrodd utsteder og audience. `freshAuthMethod` var caller-data,
ikke et OS-verifisert autentiseringsbevis. Godkjenneren opprettet dessuten sin egen
aktive post før felles fullføring.

Den separate nyere `IdentityLinkFlow` verifiserer en completion-envelope gjennom
CellBase og beholder en varig retry-pakke. Det er den støttede flyten som må brukes.
Funn i den eldre cellen er **ikke** bevis på at den nyere verifikatoren har samme feil,
eller at en faktisk resolver-grant ble utstedt av den gamle UI-posten.

Kandidaten:

- Avviser gamle begin/approve/accept/revoke-operasjoner med `verified_completion_required`.
- Fjerner implementasjonene som kunne utstede en uverifisert aktiv post.
- Bevarer historiske poster, men gjenoppretter gamle aktive poster som uverifiserte.
  Bevarer tilbakekallingsbevis og erstatter gamle «Koblet»-suksessmeldinger.
- Henviser til den native QR/nærhetsflyten og fjerner den gamle adresseinnskrivingen
  som ikke utførte en sikker koblingsseremoni.
- Fjerner påstanden om at lokal tilbakekalling i denne eldre cellen har virkning
  hos andre scaffolds. Den gamle revokeringshandlingen avvises også.
- Endrer ikke `IdentityLinkRepository`, CellBase-resolveren eller Claudes verktøylenker.

Dette er en begrensning av en utrygg eldre funksjon, ikke en ferdig ny koblingsflyt
for alle typer scaffold. Native flyt har fortsatt en eksplisitt tillitsliste for
HAVEN staging/prod; vilkårlige vertsmaskiner krever en ordentlig tillitsmodell.

## Ny algoritme, klar til evaluering

Main har allerede `HavenResidencyRanker` og `EntityResidencyCell`: brukerens egne
vekter, harde krav til jurisdiksjon/kryptering, lokal flytting med readback og
manuell eksport/kvittering for scaffolds. Fjernflytting utføres ikke av rankeren.
Dette arbeidet skal videreføres, ikke erstattes av enda et preferansesystem.

`PolicyPrototype/` er et supplerende forslag i en selvstendig Swift-pakke med syntetiske tester. Se README.
Den velger en gjennomførbar scaffoldkombinasjon etter harde tilgangs-, domene-,
lagrings- og tilgjengelighetskrav, og rangerer deretter ytelse/kostnad/energi.
Hysterese hindrer stadige bytter, men holder aldri fast på en utløpt tillatelse.

Varslingsdelen velger én aktuell flate eller foretrukket pushkanal, håndterer
stilleperioder, utløp, tilbakekalling, kvitteringsfrist og fallback. Den sender
ikke varsler. En varig, entitetsavgrenset leveringsjournal må arbitere samtidige
forsøk fra flere scaffolds før algoritmen kobles til ekte transport.

Forslaget er å flytte de felles verdikontraktene og ren beslutningslogikk til
CellProtocol etter evaluering. OS-tillatelser, APNs, Web Push og Nearby-adaptere
hører hjemme hos vertene. Prototypen er ikke integrert eller deployet.

## APNs og nettleser: hva som faktisk mangler

Release-appen har DeviceIngress **deaktivert** og tom pin for produksjonsutsteder.
Dette er en reell konfigurasjonssperre, ikke noe en grønn enhetstest løser.
Staging-pinnen må ikke gjenbrukes blindt i produksjon. Nåværende native
DeviceIngress-enrollment er dessuten eksplisitt begrenset til iOS; Mac får ikke
APNs-enrollment bare fordi Mac-appens konfigurasjon oppgir staging.

Serverens FCM-rute for `.web` er ikke en ferdig nettleserklient. Nettleserens
samtykke, abonnement, service worker, privat lagring av abonnementet,
tilbakekalling, sikker klikknavigasjon og faktiske mottakstester gjenstår.
Se `NOTIFICATIONS_IMPLEMENTATION_CONTRACT.md` for grensesnitt og testkrav.

Safari/Chrome på Mac og HAVEN på iPhone er foreløpige testmål. Brukeren er spurt
om også webappen på iPhones hjemskjerm skal være med. Spørsmålet er en valgfri
avklaring, ikke en generell godkjenningsport.

## Verifikasjon hittil

- Nyere native `IdentityLinkFlowTests`: **12 bestått**, inkludert request-binding,
  avvisning, gjenoppretting og tilbakekalt retry. Falsk rendezvous, ikke ekte prod.
- Registrering/callback-varsling: **34 bestått**, med injiserte testtransporter.
- Ny sikkerhetsregresjon: **3 bestått**, inkludert usignert pakke med matchende hash,
  feil audience og ugyldig dato, samt gjenoppretting av eldre aktive poster.
- De to første nye sikkerhetstestene feiler mot urettet main, som forventet.
- Eksisterende `HavenResidencyRankerTests`: **8 bestått**.
- Planlegging/kanalvalg: **13 bestått**, kun syntetiske policybeslutninger.
- Native UI for synlig bekreftelse og avbryt: **1 bestått**, med syntetisk identitet.
  Første usignerte testkjører ble drept før oppstart. En ny, ad-hoc-signert
  testproduktmappe løste problemet. Ingen test endret sikkerhetspolicyen i OS.
- Sluttkjøring: **57 kodetester + 13 prototypetester + 1 UI-test bestått**.
  `xcode-verification-final.log`, `policy-tests.log`, `xcode-ui-fresh-product.log`.
  UI-bildet er kun et lokalt bevis og inneholder bakgrunnsvinduer; det publiseres ikke.

Logger ligger i denne mappen. Bygg og testprodukter ligger separat under
`/private/tmp/haven-entity-security-20260928`. Ingen CI-kjøring, produksjonsdeploy,
varselsending eller kobling/flytting av brukerens private entitet er utført.

## Nødvendig sluttføring før «fungerer overalt»

1. Integrer sikkerhetsrettingen med Claudes nyere flate, og bygg en identifiserbar
   appkandidat. Kontroller at samme native koblingsflyt er lett tilgjengelig på
   telefon, Mac og fra menylinjen; ingen gammel handling må vise falsk suksess.
2. Gjennomfør parvise koblings- og tilbakekallingstester for HAVEN, agent, meny,
   Sprout og server, med eierbekreftelse på faktisk involverte enheter. Kontroller
   både positiv og negativ tilgang, utløp, restart, avbrudd og replay.
3. Fullfør autorisert lese/skrive/indeks/synk for entitetsdata. Plasseringsplanen
   kan ikke oppfinne manglende lagringsrettigheter eller tapssikker replikering.
4. Implementer nettlesersnittet og leveringsjournalen, og test ekte APNs/Web Push
   fra produsent til mottaker, klikk og autorisert kvittering.
5. Verifiser produksjonens utsteder, riktig APNs-topic/miljø og mottakerregistrering
   før Release-funksjonen aktiveres. Deretter test faktisk produksjonskandidat.

Eksisterende Astra-oppgave «Entitetsdata på tvers av scaffolds»
(`01a090e0-cced-7351-a2b1-f82408848442`) har tidligere data-handoff.
Denne rapporten erstatter ikke den oppgaven og har ikke startet en ny agentkjøring.

## Presisering: automatikk fra attach/Absorb

Kjetils nye føring er konkretisert i [ATTACH_DRIVEN_EXTENSION.md](ATTACH_DRIVEN_EXTENSION.md).
Verifisert eiertilgang til cellen kan starte utvidelse uten egen QR-runde når
brukerens policy og vertens funksjoner tillater det. En ny lokal identitet går
fortsatt gjennom den signerte completion-flyten. Vanlig delt celletilgang gir
ikke samme-entitet-autoritet. Dette er en designoppdatering, ikke ferdig runtime.
