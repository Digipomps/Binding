# Distribuert purpose- og entity-fabric på tvers av scaffolds

Status: kandidatarkitektur og handoff, 2026-07-14. Dokumentet er ikke en normativ CellProtocol-kontrakt. Det ligger midlertidig i Binding fordi de delte protokollrepoene har pågående, urelaterte endringer. Kontraktene må senere fremmes kontrollert til CellProtocol og CellProtocolDocuments.

## Beslutning

HAVEN trenger én formålsavgrenset spørringsbane som kan hente autoriserte fragmenter fra flere scaffolds uten å gjøre katalogen til en autoritetskilde, uten å innføre en global brukeridentitet og uten å kopiere en brukers Entity til ett monolittisk objekt.

Den logiske Entity-en kan være distribuert. Hver datapassasje skal likevel ha:

- én autoritativ skriver og ett aktivt epoch om gangen,
- en eksplisitt eierkontrollert plassering,
- revisjoner, idempotente mutasjoner og signerbare commit receipts,
- durable replay fra journal, ikke fra prosesslokal cache,
- synlige feil, hull, konflikter og avslag.

«100 % integritet» kan ikke ærlig bety at all maskinvare, alle nettverk og alle katastrofer aldri kan ødelegge data. Den håndhevbare invarianten skal være:

> Ingen mutasjon blir rapportert som committed før den er varig lagret etter valgt feilmodell. En acknowledged/committed mutasjon skal aldri forsvinne stille; hvis systemet ikke kan bevise varighet, returnerer det pending eller failed, ikke success.

For anbefalt produksjonsprofil betyr dette minst tre uavhengige replikaer og commit-quorum 2 av 3. Et miljø kan velge en annen eksplisitt feilmodell, men får da heller ikke påstå samme feil­toleranse.

## Formål, mål og påstander

Det finnes ennå ingen bekreftet kanonisk purposeRef for hele intensjonen. Roten beholdes derfor som `purpose://prompt.unknown` med kandidatnotatet `distributed-purpose-and-entity-fabric`. Dette er bevisst: arkitekturen skal ikke gjøre en ny tekstetikett til en kanonisk referanse uten PurposeKnowledge-prosessen.

Eksisterende tverrgående formål er:

- `purpose://human-agency` for eierkontroll og forståelige beslutninger,
- `purpose://access.audit.privacy` for minst mulig tilgang, revisjon og privatliv.

| Goal | Målbar terminaltilstand |
| --- | --- |
| G-001 | Én purpose-scoped query kan hente autoriserte fragmenter fra commons og to eier-innrullerte scaffolds, med bevart proveniens og eksplisitt status for denied, unavailable, stale og incomplete. |
| G-002 | Ingen fragmenter returneres når purpose, capability, audience, enrollment eller eierbinding ikke matcher nøyaktig. |
| G-003 | Crash-, retry-, duplicate-, reconnect-, out-of-order- og gap-tester mister null committed mutasjoner; receipt utstedes aldri før valgt quorum er oppfylt. |
| G-004 | Discovery og logger inneholder ingen privat Entity-state, globale bruker-ID-er eller implisitte koblingsnøkler på tvers av identity domains. |
| G-005 | Hver partisjon kan bygges opp fra snapshot og journal, og den rekonstruerte root-hashen er identisk med den publiserte committed-hashen. |
| G-006 | Konflikter, replay-hull og utilgjengelige autoritetskilder blir aldri skjult av merge, cache eller last-write-wins. |

Claim-ledger:

| Påstand | Vurdering | Begrunnelse |
| --- | --- | --- |
| «Vi må sømløst kunne spørre flere scaffolds om data vi har tilgang til.» | Normativt arkitekturkrav | Blir G-001 og G-002; «sømløst» betyr ett klientkall, ikke bortfall av autorisasjonsgrensene. |
| Purpose-data vil finnes både i HAVEN som digitalallmenning og i brukerens distribuerte Entity. | Plausibel arkitekturpåstand | Krever et eksplisitt skille mellom felles purpose-definisjoner og private eier-overlays; er ikke runtime-bevist ennå. |
| Dagens enrollment er nok til å løse problemet. | Delvis støttet | Enrollment gir signert onboarding og aktiv link, men ikke føderert query, plassering, synk eller durable commit. |
| Dagens bridge-sequence og FlowCache gir tapsfri replay. | Motsagt av dagens kontrakter | Bridge-gap rapporterer at replay ikke er garantert, og FlowCache er bounded, prosesslokal og eksplisitt ikke en durability-mekanisme. |
| «Vi skal aldri miste data» kan garanteres absolutt. | Må presiseres | Kan håndheves som null stille tap av committed data innen en deklarert feilmodell, ikke mot alle tenkelige fysiske katastrofer. |

## Fem separate plan

### 1. Discovery-plan: finn kandidater, ikke autoritet

Et scaffold publiserer en signert og TTL-avgrenset capability descriptor med:

- scaffold-endepunkt og identity domain,
- hvilke purposeRefs og Explore-kontraktdigests det kan håndtere,
- om dekningen er offentlig eller krever aktiv owner enrollment,
- tilgjengelighet og ferskhet uten privat Entity-innhold.

Eksisterende `EntityAtlasInspectorCell` kan beskrive lokal purpose-dekning. Eksisterende Sprout bridge discovery kan være bootstrap. Ingen av dem gir tilgang: discovery-resultatet er bare en kandidat til et Resolver-kall.

### 2. Authority-plan: hvert mål avgjør selv

- Hvert scaffold har egen domeneavgrenset identitet og egen IdentityVault; private nøkler flyttes ikke.
- Eierens relasjon til et scaffold etableres med den eksisterende `EntityScaffoldEnrollment`-flyten: request, owner approval, activation challenge og active link.
- Hvert remote kall valideres på mål-scaffoldet gjennom Resolver med eksakt capability, purpose, audience og aktiv enrollment.
- `r` gir ikke automatisk `s`. En coordinator som får lese et fragment, får ikke dermed lagre, indeksere eller videresende det.
- `purposeRef` er en semantisk kobling, aldri en capability eller en identitetskobling.

### 3. Query-plan: fan-out med proveniens, ikke skjult sammensmelting

Kandidatcellens arbeidsnavn er `PurposeQueryCoordinatorCell`. Den mottar `haven.purpose-scoped-query.v0`, slår opp relevante descriptor-kandidater og sender autoriserte subqueries via Resolver og transportbridge.

Forespørselen må minst angi:

- stabil `queryID`, eksakte `purposeRefs` og ønsket Explore-kontraktdigest,
- felter eller keypaths som kontrakten tillater,
- konsistensnivå, maksimal staleness, deadline og retention intent,
- requester/audience som Resolver kan verifisere.

Hvert `haven.purpose-query-fragment.v0` beholder:

- source scaffold, source cell, purposeRef og identity domain,
- autoritativ partition, epoch og revision eller stream-watermark,
- content hash, signert proveniens, redactions og ferskhet,
- capability-beslutning og status uten å lekke sensitive avvisningsdetaljer.

Det aggregerte `haven.purpose-query-result.v0` må være `complete`, `partial`, `stale`, `denied`, `unavailable` eller `incomplete`. Coordinatoren kan presentere én samlet visning, men skal bevare fragmentgrensene og aldri late som et delresultat er komplett.

### 4. Placement-plan: én autoritativ skriver per partisjon

En eierkontrollert `EntityDataPlacementManifest` kobler logiske namespaces til autoritative endepunkter. Eksempel:

| Partisjon | Mulig autoritativ plassering | Innhold |
| --- | --- | --- |
| `entity.core` | eierens home scaffold | representation, stabile eierstyrte referanser |
| `entity.projects` | prosjekt-scaffold | prosjektrelasjoner og prosjektspesifikk state |
| `entity.purpose-overlay` | privat purpose-scaffold | aktive private formål, mål, vekter og relasjoner |
| `commons.purpose-catalog` | HAVEN commons | offentlige purpose-definisjoner og versjoner, ikke privat eierstate |

Manifestet inneholder partition ID, autoritativ cell endpoint, replikaer, epoch, revision, sensitivitet og retention/backup-policy. Det skal ikke inneholde eller skape en global bruker-ID.

Autoritet flyttes med signert tofaset handoff:

1. gammel autoritet fryser nye writes og utsteder siste committed revision/root,
2. ny autoritet verifiserer full journal/snapshot og overtar et høyere epoch,
3. Resolver avviser alle senere writes med gammelt epoch,
4. manifestet publiserer først ny plassering etter verifisert overtakelse.

Dette forhindrer to samtidige autoritative skrivere. Manifestet selv må være redundant, kryptert og gjenopprettbart under eierens kontroll.

### 5. Durability-plan: commit er en lagringsbeslutning, ikke transport-ack

Hver mutasjon er en immutable, innholdsadressert envelope med:

- stabil `mutationID` som idempotency key,
- partition, epoch og `expectedRevision`,
- payload- eller payload-hash, forrige committed hash og ny hash,
- requester, purpose, capability og signatur,
- journaltid og policy-ID for feilmodellen.

Skrivebanen er:

1. Resolver godkjenner mutasjonen og policyen.
2. Autoriteten sjekker epoch og compare-and-swap mot `expectedRevision`.
3. Envelope appendes til en durable, hash-kjedet journal.
4. Replikaer verifiserer og lagrer samme envelope.
5. Autoriteten utsteder `CommitReceipt` først når policyens quorum har durable acknowledgements.
6. Snapshot skrives atomisk og kan alltid regenereres fra journalen.

Hvis quorum mangler, beholdes mutasjonen som `pending` i en durable outbox. Retry med samme `mutationID` er idempotent. Transport-ack, HTTP 2xx eller mottatt bridge-command er aldri commit receipt.

Ved konflikt beholdes begge gyldige grener. Systemet bruker ikke generell last-write-wins; det velger en deterministisk domenepolicy eller krever eksplisitt eieravgjørelse. Ved sequence-gap skal consumer replaye fra den durable autoritetskilden. Hvis replay ikke kan bevises, avsluttes strømmen som `incomplete` og kan ikke brukes som fullstendig state.

## Commons og private purpose-overlays

Den felles purpose-katalogen og brukerens purpose-state har ulike roller:

- Commons er autoritativ for publiserte definisjoner, versjoner, relasjoner og eventuelle offentlige evidensreferanser.
- En bruker-Entity er autoritativ for hvilke purposes eieren har aktivert, private mål, prioriteringer, vekter, notater og samtykker.
- Private overlays refererer til commons med `purposeRef` og versjon, men kopierer ikke autoritet eller tilgang.
- Et privat, ennå ikke kanonisert formål kan leve med lokal kandidat-ID og `purpose://prompt.unknown` til det eventuelt godkjennes i PurposeKnowledge-basen.

En query som trenger begge, returnerer separate provenance-fragmenter. En avledet visning kan kombinere dem, men skal kunne forklare hvilken verdi som kom fra commons, eieren eller en tredjepart.

## Implementert authority-, replika- og replay-slice 2026-07-15

CellProtocol har nå en additiv kandidatkontrakt for signert lokal authority-commit:

- stabil mutation ID og canonical payload-hash,
- requester-signert commit request,
- partition/epoch/revision/head compare-and-set,
- append-only hash-kjedet journal og replay,
- authority-signert receipt og atomisk snapshot replace,
- fail-closed avvisning av stale state, mutation-ID-rebinding, korrupt journal og alle krav om replica-ack som runtime ikke kan bevise.

Binding PersonalChat Chronicle bruker denne banen, verifiserer receipt og lar eieren velge `off`, `metadata` eller `full`. Dette lukker den lokale read-before-write-rasen, men er bevisst merket `local_authority_only`, `quorumSatisfied=false` og `distributedCommit=false`.

CellBase har i tillegg en transportnøytral kandidatkontrakt for neste distribuerte lag:

- authority-signert replica admission og quorum-policy, bundet til partition/epoch, tidsvindu, replikaidentitet, fault domain og canonical admission-hash,
- replica-signert acknowledgement bundet til eksakt authority receipt, journal entry og deklarert durability level,
- deterministisk quorum-evaluering som avviser duplicate replica/fault domain, admission-rebinding og `transport_delivery_only`,
- separat authority-signert quorum certificate bundet til receipt, policy, evaluering og aksepterte acknowledgement-påstander,
- replay-range som bare kan anvendes når hele requested range er sammenhengende, authority-receipt-verifisert og merket `complete`,
- filbasert restart-test som viser reparasjon fra persisted journal når snapshot fortsatt er pre-commit.

Dette er kontrakt og testbevis, ikke en aktiv distribuert skrivebane. Quorum-evalueringen er ikke alene et certificate; den nye certificate-fabrikken signerer bare en tilfredsstilt og kryptografisk bundet evaluering. EntityAnchor mangler fortsatt replika-store/bridge/outbox og avviser derfor alle live requests med `requiredReplicaAcks > 0`.

## Faktiske gjenværende gap i dagens kode

Arkitekturen bygger videre på eksisterende arbeid, men følgende er ikke implementert som en sammenhengende kontrakt:

- `EntityScaffoldEnrollmentCell` dekker signert onboarding, replay/audience/capability-subset og activation, men ikke remote EntityAnchor-proxy, placement eller live sync.
- `EntityAtlasInspectorCell` lager et lokalt resolver-snapshot; den koordinerer ikke dataqueries på tvers av scaffolds.
- Sprout bridge discovery gir signerte, TTL-avgrensede descriptors; default capabilities er discovery/join og er ikke dataautoritet.
- `BridgeFlowContinuityTracker` kan oppdage duplicate, out-of-order og gap, men dagens kommentar sier uttrykkelig at manglende ranges ikke har garantert replay.
- `FlowCacheCell` er bounded og prosesslokal, med `reconnectReplayGuaranteed=false`.
- EntityAnchor har journal/revision/CAS/receipt for v0 batch-envelope med `commitRequest`, men eldre direkte skriv bruker fortsatt snapshotbanen og er ikke automatisk journalført.
- V0 har modeller og kontrakttester for durable replica acknowledgements, quorum-evaluering, authority-signert certificate og replay-range, men mangler replika-store, bridgeadapter, durable outbox og certificate-persistens/integrasjon i live EntityAnchor.
- V0 mangler fsync/power-loss-proof og fault-injection/restore-bevis på tvers av prosesser og maskiner; restart-testen dekker bare persisted journal kombinert med et stale snapshot.
- Placement manifest, authority-handoff og read-only purpose-query coordinator er fortsatt ikke implementert.

## Implementeringsrekkefølge

1. Frem `haven.cross-scaffold-purpose-entity-fabric.v0` og authority-kontrakten som reviewbare normative kontrakter i CellProtocolDocuments når dokumentrepoets merge-tilstand er ryddet.
2. Implementer en replika-store og bridgeadapter som persisterer journal før den signerer replica-ack; behold FlowCache kun som ytelses- og UX-optimalisering.
3. Implementer durable outbox og persistér/integrer det authority-signerte quorum certificate uten å omskrive den opprinnelige journalposten.
4. Kjør prosesskill-, disk-full-, torn-write-, fsync-/power-loss- og tverrmaskin-restore-verifikasjon før live receipt kan rapportere quorum.
5. Implementer placement manifest og en read-only `PurposeQueryCoordinatorCell`. Leseføderasjon kommer før distribuerte writes.
6. Koble Binding og Apple Intelligence til coordinator-resultatet med proveniens, redactions og freshness; ingen direkte endpointsøk fra modellprovideren.
7. Åpne remote write-capability først etter verifisert placement handoff, quorum og replay.

## Obligatoriske akseptansetester

- discovery descriptor utløpt, feil signert eller for feil purpose gir ingen query,
- aktiv enrollment med for bred capability blir avvist,
- foreign requester, wrong audience og cross-domain identity reuse blir avvist,
- duplicate mutation med samme ID gir samme receipt og ingen dobbelt write,
- stale expectedRevision og gammelt epoch gir konflikt uten tap av noen gren,
- crash før quorum gir aldri committed receipt,
- crash etter receipt kan gjenopprettes til samme committed root hash,
- bridge-gap uten replay gir `incomplete`, ikke et tilsynelatende komplett resultat,
- utilgjengelig scaffold gir partial/unavailable med bevart kildeoversikt,
- privat purpose-overlay finnes ikke i discovery, commons eller logger,
- restore fra snapshot pluss journal matcher publisert root hash for hver partisjon,
- sletting følger eksplisitt retention/tombstone-policy og kan ikke forveksles med uventet datatap.

## Beslutningsstatus

Kjetils beskjed om å planlegge gjenstående og utføre nå autoriserte den lokale, additive authority-slicen. Følgende arkitekturvalg står fortsatt som porter før distribuert write:

1. invarianten for committed data og anbefalt 2-av-3 feilmodell,
2. én-writer-per-partisjon med epoch fencing,
3. skillet mellom commons-definisjoner og private owner overlays,
4. read-only føderasjon før remote writes,
5. at kontrakten fremmes til CellProtocol/CellProtocolDocuments når de pågående worktree-endringene kan isoleres trygt.
