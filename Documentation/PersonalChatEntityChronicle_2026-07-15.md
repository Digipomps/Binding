# PersonalChatHub og Entity Chronicle

Dato: 2026-07-16
Status: Implementert vertikal Binding-slice, med eksplisitte integritetsbegrensninger

## Formål og mål

Denne implementasjonen er forankret i:

- `purpose://preference.owner-controlled`: eieren bestemmer om og hvor mye samtalehistorikk som lagres.
- `purpose://access.audit.privacy`: lagring skal være synlig, privat og mulig å revidere.
- `purpose://human-agency`: analyse av et utkast skal ikke i seg selv mutere brukerens Entity.

Mål:

1. Første resolve av `PersonalChatHub` skal registreres som persistent.
2. Chronicle-lagring skal være av som standard.
3. Brukeren skal kunne velge `off`, `metadata` eller `full`.
4. `assistant.analyzeDraft` skal være uten Entity-sideeffekt; bare eksplisitt `prompt.submit` kan skrive en samtaleturn.
5. Metadata-modus skal aldri lagre prompt- eller svartekst.
6. Gjentatt innsending med samme `turnID` og innhold skal gjenkjennes uten ny skriving; samme ID med annet innhold skal avvises fail-closed.
7. Runtime skal returnere og verifisere en signert, journalført authority-kvittering, men ikke omtale den lokale kvitteringen som distribuert quorum.

## Registreringsfeilen

`BindingLocalCellRegistration` registrerte tidligere chat-cellene med `persistency: nil` før `BindingRuntimeBootstrap.ensureInfrastructureBaseline()` hadde installert typed-cell storage. Senere forsøk på persistent registrering ble avvist som duplikat. Resultatet var at den første `PersonalChatHub`-resolvekontrakten ble ephemeral.

Rekkefølgen er nå:

1. installer infrastruktur-baseline og typed-cell storage;
2. registrer `PersonalChatHub`, `AppleIntelligence`, `LocalLLM` og `ContactEndpoint` som `.persistant`;
3. registrer resten av den lokale runtime-overflaten.

En registry-snapshot-test verifiserer at `PersonalChatHub` er `identityUnique`, `private` og `.persistant`.

## Eierstyrt lagringskontrakt

Policy lagres i eierens EntityAnchor på:

```text
person.copilot.chatHistoryPolicy
```

Samtaleturner lagres på en stabil, nøkkelsti-sikker ID:

```text
chronicle[id=personal-chat-turn-<turnID>]
```

Tilstandene er:

| Modus | Automatisk ved eksplisitt submit | Lagret innhold |
|---|---:|---|
| `off` | nei | ingenting |
| `metadata` | ja | ID, tråd, tidspunkt, formål/hjelper og kilde; ingen prompt- eller svartekst |
| `full` | ja | metadata pluss prompt- og svartekst |

`metadata` krever `confirm=true`. `full` krever både `confirm=true` og `fullContentWarningAccepted=true`. `off` kan alltid velges uten ekstra bekreftelse.

`history.clearLocal` tømmer bare den lokale promptloggen og muterer ikke Entity. Å sette policy til `off` stopper nye Chronicle-poster, men sletter ikke eksisterende poster. Separat, autorisert erase/redaction er ikke implementert i denne slicen.

## Sideeffektgrense

Følgende operasjon forblir en ren analyseoperasjon:

```text
chatHub.assistant.analyzeDraft
```

Chronicle-lagring kan bare utløses etter brukerens eksplisitte:

```text
chatHub.prompt.submit
```

En klient kan sende `turnID` eller `requestID`. ID-en normaliseres til alfanumeriske tegn, `-`, `_` og `.`, og avgrenses til 96 tegn. Posten får et SHA-256-fingeravtrykk av de lagringsrelevante feltene. Samme ID og signerte payload-hash gjenkjennes atomisk av EntityAnchor og returnerer den opprinnelige kvitteringen uten ny journalpost. Samme ID med et annet payload avvises for å hindre at en eldre Chronicle-post blir overskrevet. I metadata-modus inngår ikke prompt- eller svartekst i posten eller payload-hashen; denne modusen kan derfor bare konfliktkontrollere feltene den faktisk har lov til å lagre.

Binding leser authorityens epoch, revision og head-hash, signerer commit-requesten og prøver på nytt ved en samtidig revision/head-konflikt. Den gamle, raseutsatte lokale read-before-write-sjekken er fjernet. Avgørelsen ligger nå under EntityAnchors serialiserte commit-gate og journal-CAS.

En vellykket respons inneholder en authority-signert `haven.entity-authority-commit-receipt.v0`. Binding verifiserer signaturen, mutation ID og payload-hash før brukerflaten får success. Kvitteringen sier eksplisitt `local_authority_only`, `quorumSatisfied=false` og `distributedCommit=false`; `durableCommitReceipt` forblir derfor `false`.

## Explore- og UI-kontrakt

`history.configure` og `chatHub.history.configure` har eksplisitt `rw-s` i PersonalChatHub-kontrakten. Vanlige chat-actions beholder `rw--`; de får ikke implisitt storage-rettighet.

Personvernspanelet viser:

- aktiv historikkmodus og siste persistensstatus;
- `Chronicle av`;
- `Lagre metadata`;
- `Lagre fulltekst` med eksplisitt fulltekstvarsel;
- `Tøm lokal samtalehistorikk`;
- beskjed om at eksisterende Chronicle-poster ikke slettes automatisk.

## Claim ledger

| Påstand | Status | Grunnlag / begrensning |
|---|---|---|
| Første `PersonalChatHub`-registrering var ephemeral | støttet | Koden registrerte med `persistency: nil` før baseline; registry-test dekker rettelsen. |
| Nye samtaleturner lagres nå i Chronicle | betinget støttet | Bare når eieren har valgt `metadata` eller `full`, og bare ved eksplisitt `prompt.submit`. Standard er `off`. |
| Analyse lagrer samtalen | avvist | `assistant.analyzeDraft` er fortsatt sideeffektfri mot Entity. |
| Retry med samme `turnID` lager ikke duplikat eller overskriver historikk | støttet for lokal authority-commit | Stabil mutation ID og signert payload-hash gjør lik retry idempotent under samme serialiserte journal; kolliderende payload avvises. |
| Bekreftelsen beviser lokal authority-commit | støttet med avgrensning | Signert hash-kjedet journal, monotone revisjoner, epoch/head-CAS og atomisk filreplace. Ingen fsync-/power-loss-proof. |
| Bekreftelsen beviser varig distribuert commit | ikke støttet | Receipt oppgir eksplisitt null replica-acks, quorum false og distributed false. Transport-ack brukes ikke som commit. |
| Ingen data kan gå tapt på tvers av scaffolds | ikke implementert ennå | Replika-store og replay-kontrakt finnes, men live bridge/outbox/quorum, placement og restore/fault-injection-bevis mangler. |

## Verifikasjon

Fokuserte tester ligger i `BindingTests/PersonalChatChronicleTests.swift` og dekker:

- eksplisitt policyeskalering og standard `off`;
- nøkkelsti-sikker `turnID`;
- persistent resolver-registrering;
- analyse uten Entity-sideeffekt;
- metadata uten tekst;
- idempotent replay uten overskriving;
- verifisert authority-receipt med eksplisitt lokal-only/quorum-false status;
- eksplisitt fulltekstsamtykke;
- policy-rehydrering fra Entity;
- lokal sletting uten Entity-mutasjon;
- synlige valg i Co-Pilot-skjelettet.

Verifisert 2026-07-16 mot rene Binding- og CellProtocol-grener: 5 fokuserte Chronicle-tester og 51 ChatWorkbench-regresjonstester, 0 feil. Den underliggende authority-/replika-suiten hadde 12 fokuserte tester, og hele CellProtocol-pakken hadde 800 tester, 0 feil. Dette er programvarekontrakt- og restart/read-back-bevis, ikke fysisk power-loss- eller tverrmaskinbevis.

## Neste riktige arkitekturtrinn

Denne slicen etablerer brukerpolicy og den lokale authority-write-boundaryen, men skal ikke brukes som bevis for 100 % integritet på tvers av scaffolds. Replika-store, acknowledgement- og replay-kontraktene finnes nå; neste protokolltrinn er bridgekobling, durable outbox og live quorum-certificate, etterfulgt av placement og read-only query federation. Binding kan først oppgradere `durableCommitReceipt` når receipt faktisk beviser valgt quorum og restore/fault-injection-testene er grønne.
