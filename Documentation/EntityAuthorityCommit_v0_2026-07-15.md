# Entity Authority Commit v0

Dato: 2026-07-16
Status: implementert kandidatkontrakt i CellProtocol; lokal authority-profil og read-back-verifisert replika-store, men ikke distribuert live commit

## Formål og terminale mål

Arbeidet er forankret i `purpose://human-agency`, `purpose://access.audit.privacy` og kandidatintensjonen `distributed-purpose-and-entity-fabric` under `purpose://prompt.unknown`.

| Goal | Status | Bevis |
| --- | --- | --- |
| Stabil idempotency key kan ikke bindes til nytt innhold | oppfylt lokalt | Lik mutation ID + payload gir samme receipt; annet payload gir `mutation_id_conflict`. |
| Samtidige skriv kan ikke skjule revision/head-konflikt | oppfylt lokalt | Epoch, expected revision og previous hash sjekkes under serialisert authority-gate. |
| Committed lokal state kan bygges opp fra journal | oppfylt innen v0 | Snapshot kan repareres ved replay av den hash-kjedede journalen. |
| Avbrutt snapshot-skriving kan repareres etter restart | oppfylt for filbasert kontrakttest | Persisted journal og pre-commit snapshot dekodes på nytt; replay gjenoppretter committed verdi. Dette er ikke en fysisk power-loss-test. |
| Klient får et kryptografisk verifiserbart success-bevis | oppfylt lokalt | Authority signerer receipt; Binding verifiserer signatur, mutation ID og payload-hash. |
| Replika-ack, quorum certificate og replay-range har en signert wire-kontrakt | oppfylt som kontrakt | Authority-signert admission/policy/certificate, replica-signert ack, unike fault domains og komplett/incomplete/conflict replay-range er testet. |
| Replika persisterer og validerer journal før ack | oppfylt innen v0-feilmodellen | Replika-store anvender bare komplett, receipt-verifisert replay, persisterer den sammenslåtte journalen, leser tilbake eksakte bytes og signerer først deretter. Atomisk filreplace er fortsatt ikke power-loss-bevis. |
| Live receipt beviser valgt distribuert feilmodell | ikke oppfylt | Replika-store og certificate-kontrakt finnes, men EntityAnchor har ennå ingen bridge/outbox eller live certificate-integrasjon. |
| Power-loss-sikker filcommit er bevist | ikke oppfylt | Atomisk filreplace er brukt, men fsync/disk-controller/power-loss er ikke bevist. |

## Kontrakter

Den additive wire-utvidelsen er valgfri `commitRequest` på eksisterende `EntityBatchPersistEnvelope`. Fravær beholder v1-oppførsel og `status=persisted`. Tilstedeværelse aktiverer v0-authoritykontrakten:

- `haven.entity-authority-commit-request.v0`
- `haven.entity-authority-commit-state.v0`
- `haven.entity-authority-journal.v0`
- `haven.entity-authority-journal-entry.v0`
- `haven.entity-authority-commit-receipt.v0`
- `haven.entity-authority-replica-admission.v0`
- `haven.entity-authority-replica-quorum-policy.v0`
- `haven.entity-authority-replica-ack.v0`
- `haven.entity-authority-replica-quorum-certificate.v0`
- `haven.entity-authority-replay-range-request.v0`
- `haven.entity-authority-replay-range-response.v0`

Requesten binder mutation ID, partition, epoch, expected revision/head, canonical payload-hash, requester-identitet/fingerprint, purpose, capability, fault policy og ønsket replica-ack-antall til requesterens signatur.

Authorityen validerer requesten, gjør CAS, appender en immutable hash-kjedet journalpost, signerer receipt og skriver snapshot atomisk. Journalen skrives før snapshot. Hvis snapshot-skriving feiler etter journalappend, returneres ikke success i det forsøket; retry med samme mutation ID reparerer snapshot fra journal og returnerer samme receipt.

Ved oppstart valideres journalstruktur, hash-kjede og authority-signerte receipts. En manglende snapshot kan bygges fra journalen. Korrupt eksisterende snapshot eller journal overskrives ikke stille; persistence feiler lukket.

## Replika- og replay-kontrakt

CellBase har nå transportnøytrale byggesteiner og en konkret replika-store:

- authority-signert, tids- og epoch-avgrenset admission av en replikaidentitet,
- authority-signert quorum-policy som binder både admission-ID og canonical admission-hash,
- replica-signert acknowledgement bundet til eksakt authority receipt, entry hash, payload hash og deklarert durability level,
- deterministisk quorum-evaluering som teller hver replika og fault domain maksimalt én gang,
- eksplisitt avvisning av `transport_delivery_only` som quorum-bevis,
- separat authority-signert quorum certificate bundet til eksakt receipt-, policy- og evaluation-hash samt de aksepterte ack-påstandene,
- replay-range med `complete`, `incomplete` og `conflict`; bare en sammenhengende, receipt-verifisert `complete` range kan anvendes atomisk.
- admission-bundet replika-store som avviser gap/divergens/tampering, verifiserer persisterte bytes med umiddelbar read-back og først deretter signerer ack for de anvendte journalpostene.

Quorum-evalueringen er med vilje ikke alene et commit-sertifikat. Resultatet har `authorityCertificateRequired=true`, og certificate-fabrikken feiler lukket dersom evalueringen ikke tilfredsstiller policyen. Sertifikatet er supplement til den immutable lokale receipt-en; det omskriver ikke originaljournalen. Replika-store er ikke koblet til bridge eller EntityAnchors write-bane. Før EntityAnchor har transportadapter, durable outbox og live certificate-bane, fortsetter live write derfor å avvise `requiredReplicaAcks > 0`.

## Implementert replika-store 2026-07-16

`EntityAuthorityReplicaStore` serialiserer merge, persistensverifikasjon og ack-signering for én admission-bundet replika. Den:

- krever gyldig authority-signert admission og eksakt binding til replikaens UUID og signeringsnøkkel;
- anvender bare en `complete` replay-range som verifiserer mot authorityens receipts;
- tillater byte-ekvivalent/idempotent overlapp, men avviser manglende eller divergerende revisjoner uten å erstatte tidligere gyldig historikk;
- skriver hele den validerte journalen, leser tilbake eksakte canonical bytes og validerer dokumentet på nytt før noen replica-ack signeres;
- avviser `transport_delivery_only` som durability level.

Standard filpersistens bruker atomisk replace og private rettigheter (`0700` katalog, `0600` fil). Den deklarerer med vilje bare `atomic_file_replace_without_power_loss_proof`. Read-back beviser at persistence-implementasjonen returnerte de forventede bytes i testen; den beviser ikke fsync, disk-controller-flush eller overlevelse etter fysisk strømbrudd.

Wire-valideringen avgrenser materialet til maksimalt 64 admissions, 256 acknowledgements per evaluering og 4096 journalposter per replay-range.

## Eksplisitt receipt-semantikk

V0-receipt har:

```text
status=authority_committed
durabilityLevel=atomic_file_replace_without_power_loss_proof
replicationState=local_authority_only
replicaAckCount=0
quorumSatisfied=false
distributedCommit=false
```

`authority_committed` betyr derfor: authorityen har tatt en signert, hash-kjedet lokal journalbeslutning innen den deklarerte lokale feilmodellen. Det betyr ikke at data finnes på en annen maskin, tåler disk-/strømsvikt eller har 2-av-3 quorum.

En request med `requiredReplicaAcks > 0` avvises før journalappend med `quorum_unavailable`. Transport-ack, flow-levering og HTTP-status kan aldri oppgradere denne receiptens semantikk.

## Claim ledger

| Påstand | Vurdering |
| --- | --- |
| «Vi har atomisk lokal idempotens og revision fencing.» | støttet av kontrakttester og Binding-integrasjonsbane |
| «En gammel mutation ID kan overskrive historikk.» | avvist; annet payload gir konflikt før append |
| «Journal-tampering oppdages.» | støttet for struktur/hash og authority-receipt-signatur |
| «En transportkvittering kan telles som durable replica-ack.» | avvist av quorum-policy og kontrakttest |
| «To kvitteringer fra samme replika eller fault domain kan tilfredsstille 2-av-3.» | avvist; de telles maksimalt én gang |
| «En admission-ID kan bindes om til en annen replika.» | avvist; policyen signerer canonical admission-hash i tillegg til ID |
| «En lokal aktør kan merke et utilstrekkelig quorum som distribuert commit.» | avvist i certificate-fabrikken; bare authority-signert sertifikat over en tilfredsstilt, bundet evaluering verifiserer |
| «Replay med hull kan rapporteres komplett.» | avvist; manglende revision gir `incomplete`, feil previous hash gir `conflict` |
| «Alle eksisterende EntityAnchor-skriv er nå journalført.» | avvist; bare batch-envelope med `commitRequest` bruker v0-journalen |
| «Vi har distribuert tapsfrihet.» | avvist; replika-store finnes, men ingen live bridge/outbox/quorum eller restore-bevis på tvers av scaffolds |
| «100 % integritet er nå bevist.» | avvist; v0 lukker en lokal silent-loss/idempotency-risiko, men ikke hele feilmodellen |

## Gjenværende implementeringsrekkefølge

1. Implementer bridgeadapteren rundt `EntityAuthorityReplicaStore`; transport skal bare frakte replay request/response og videresende den signerte ack-en som store produserer etter verifisert persistens.
2. Implementer durable outbox og persistér det signerte quorum-sertifikatet som separat bevis uten å omskrive original journalhistorikk.
3. Legg til prosesskill-, fsync-, disk-full-, torn-write-, power-loss- og tverrmaskin-restore-verifikasjon mot publisert root hash.
4. Implementer eierstyrt placement manifest med epoch-fenced authority handoff.
5. Implementer read-only `PurposeQueryCoordinatorCell` med proveniens, partial/incomplete og capability-enforcement.
6. Åpne remote writes først etter at 1–5 er verifisert; behold FlowCache som cache, aldri durability.

## Testgrunnlag

- `EntityAuthorityCommitTests`: legacy-wire, signatur/hash-kjede, idempotent receipt, mutation-ID-konflikt, stale CAS/quorum-avvisning, tamper detection, restart recovery, admission-hash-binding, durable/fault-domain quorum, certificate-binding og komplett replay-range.
- `EntityAuthorityReplicaStoreTests`: persist/read-back/restart, idempotent retry, signert ack, ingen ack ved persistence failure, avvisning av incomplete/tampered/transport-only samt gap/divergens uten tap av tidligere journal.
- `PersonalChatChronicleTests`: eierstyrte moduser, faktisk EntityAnchor-write, verifisert receipt, lokal-only markering, retry og konfliktbevaring.

Verifisert 2026-07-16:

- ren CellProtocol-gren: `swift test --disable-sandbox --filter EntityAuthority` — 12 tester, 0 feil;
- samme CellProtocol-gren: `swift test --disable-sandbox` — full pakke, 800 tester, 0 feil;
- ren Binding-gren bygget mot den rene CellProtocol-grenen: `Scripts/test_binding.sh ... -only-testing:BindingTests/PersonalChatChronicleTests` — 5 tester, 0 feil.
- samme integrerte checkout: `Scripts/test_binding.sh ... -only-testing:BindingTests/ChatWorkbenchParityTests` — 51 tester, 0 feil.

Kandidatkontrakten bør flyttes til normative CellProtocolDocuments når det repoets pågående merge-/worktree-tilstand er ryddet; denne filen er handoff og sannhetsavgrensning, ikke en erstatning for den normative boken.
