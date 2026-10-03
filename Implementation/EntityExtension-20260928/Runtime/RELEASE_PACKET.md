> BLOCKED PREPARATION: no server image or cutover exists. Unknown fields below
> are blocking, not waived. See ROLLOUT.md and ROLLOUT_STATUS.json for exact source
> and evidence. Current source scope adds optional owner-attach receiver and a
> non-identifying readiness route; data movement/indexing/notifications remain
> independently authorized features.

# CellScaffold release packet

Kopier denne filen for hver release. Fyll ut alle obligatoriske felt før
status settes til `PREFLIGHT_GREEN`. Bruk `UKJENT` som en blokkerende verdi;
aldri fyll inn en antakelse for å gjøre en gate grønn.

Kanonisk arbeidsflyt:
[`CellScaffold_Deployment_Workflow.md`](../CellScaffold_Deployment_Workflow.md)

## Identitet og myndighet

| Felt | Verdi |
| --- | --- |
| Release-ID | `owner-attach-20260928` |
| Status | `HANDOFF_REQUIRED` — capacity, physical phone and private CI prerequisites unresolved |
| Environment | staging, then the same artifact in production |
| Opprettet UTC | `UKJENT` |
| Menneskelig releaseeier | Kjetil |
| Executor | Codex task 01a08bdf-7a94-74a3-985d-cb1d59869d50 |
| Reviewer | `UKJENT` |
| Mutasjonsautorisasjon og tidspunkt | User request 2026-09-28: roll out to phone, Sprout, agent, menu helper, staging/prod |
| Cleanup-plan SHA-256 / token | None created or approved; no cleanup performed |

## Releasefrys og CI-aktivitet

| Felt | Verdi |
| --- | --- |
| Freeze-melding / tidspunkt UTC | `UKJENT` |
| Kanonisk integrasjonsbranch | `UKJENT` |
| Kandidat-SHA før merge | `UKJENT` |
| Forventet mergecommit i `main` | `UKJENT` |
| Autorisert CI-workflow og executor | `UKJENT` |
| Forventede automatiske PR-workflows | `UKJENT` / `ingen` |
| Forventede main-push-workflows | `UKJENT` / `ingen` |
| Forventet eksplisitt release-dispatch | `UKJENT` / `ingen` |
| Forventede cross-repo-dispatcher | `UKJENT` / `ingen` |
| In-flight CI ved freeze | `ingen` / `UKJENT` |
| Tillatt behandling av in-flight CI | `fullfør som candidate_evidence_only` / `kanseller` / `UKJENT` |
| Maksimalt rerunbudsjett | `0` eller `1` |

Inkluderte PR-er/commits med begrunnelse:

- `UKJENT`

Eksplisitt ekskluderte/supersederte PR-er/commits:

- `UKJENT`

Scope-ledger mot aktuell `main` og live staging:

- `UKJENT`

## Scope

Mål:

- `UKJENT`

Tillatte mutasjoner:

- `UKJENT`

Eksplisitte non-goals:

- `UKJENT`

## Eksakte artefakter

| Artefakt | Branch/ref | 40-tegns commit eller digest | Ren/reviewet | Evidenskilde |
| --- | --- | --- | --- | --- |
| CellScaffold | `codex/owner-attach-runtime-20260928` | Base `adf48d4615d1ed143d5bdc190fcf63e266214c8f`; runtime changes uncommitted | Not compiled | `CellScaffold.patch`, `ROLLOUT_STATUS.json` |
| CellProtocol | candidate PR #56; not yet a consumer pin | `980e8a2845905391fb66ce098958dcdc4194d144` | Clean candidate, CI pending; unpublished | `CellProtocol.patch`, PR #56 |
| CellProtocol remote reachability | immutable commit | `UKJENT` | `UKJENT` | clean locked resolution |
| CellProtocolDocuments | submodule pin | `UKJENT` | `UKJENT` | `git submodule status` |
| AdminScaffold image | immutable | `UKJENT` | `UKJENT` | CI/OCI |
| CellScaffold web image | immutable | `UKJENT` | `UKJENT` | CI/OCI |
| Binding/HAVEN | `codex/entity-extension-security-20260928` | `e5691ba2d13b956e39508864ad9473c01a4093a7` | Clean source; final signed build/install pending | Binding Git; `ROLLOUT_STATUS.json` |
| Binding CellProtocol | remote pin still old; local test override | Remote `79497e85ef2f3fb02db0d6df5b601c5f1bc76391` | NOT reconciled to release candidate | Xcode project and lockfiles |

CI-runner og attestation/provenance:

- `UKJENT`

Pre-merge løp er merket:

- `candidate_evidence_only` / `ikke relevant`

Releasecontroller og SHA-256:

- staging: `UKJENT`
- production: `ikke relevant` eller `UKJENT`

## Read-only live inventar

| Kilde | Før-verdi | Tidspunkt UTC | Verdict |
| --- | --- | --- | --- |
| Deployjournal/status | `UKJENT` | `UKJENT` | `UKJENT` |
| Sanitert status schema/digest/provenanceComplete | `UKJENT` | `UKJENT` | `UKJENT` |
| Aktiv deploylås/prosess | `UKJENT` | `UKJENT` | `UKJENT` |
| Staging container/digest/restart count | `UKJENT` | `UKJENT` | `UKJENT` |
| Staging offentlig build/ready | `UKJENT` | `UKJENT` | `UKJENT` |
| Admin container/digest/restart count | `UKJENT` | `UKJENT` | `UKJENT` |
| Admin offentlig build/ready | `UKJENT` | `UKJENT` | `UKJENT` |
| Prod container/digest/restart count | `UKJENT` | `UKJENT` | `UKJENT` |
| Prod offentlig build/ready | `UKJENT` | `UKJENT` | `UKJENT` |
| DeviceIngress sanitert status/count | `UKJENT` | `UKJENT` | `UKJENT` |

Observerte mismatcher:

- `ingen` / `UKJENT`

## Kapasitet

Registrer både bytes og prosent. `projected free` skal inkludere kandidat,
backup, rollback og forventet buildvekst.

| Host/filsystem | Free før | Free % før | Planlagt vekst | Projected free | Projected % | Krav | Verdict |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Lokal buildcache | `UKJENT` | `UKJENT` | `UKJENT` | `UKJENT` | `UKJENT` | 40 GiB + 10 % | `UKJENT` |
| Server root | `UKJENT` | `UKJENT` | `UKJENT` | `UKJENT` | `UKJENT` | 40 GiB + 4 % | `UKJENT` |
| Data/rollback | `UKJENT` | `UKJENT` | `UKJENT` | `UKJENT` | `UKJENT` | 40 GiB + 4 % | `UKJENT` |
| Backup/registry | `UKJENT` | `UKJENT` | `UKJENT` | `UKJENT` | `UKJENT` | 40 GiB + 4 % | `UKJENT` |

Stabil cache/DerivedData-path og størrelse før:

- `UKJENT`

## Topologi

| Rute/tjeneste | Forventet før | Forventet kandidat | Observert før | Observert etter |
| --- | --- | --- | --- | --- |
| staging public | `127.0.0.1:8081` | `127.0.0.1:8081` | `UKJENT` | `ikke kjørt` |
| production public | `UKJENT` | `127.0.0.1:8084` | `UKJENT` | `ikke kjørt` |
| staging Admin | `UKJENT` | `UKJENT` | `UKJENT` | `ikke kjørt` |
| production Admin | `UKJENT` | `UKJENT` | `UKJENT` | `ikke kjørt` |

Nginx-konfigurasjon før og backup-referanse:

- `UKJENT`

## Persistent state og rollback

| Felt | Staging | Production |
| --- | --- | --- |
| Aktiv state-generation | `UKJENT` | `UKJENT` |
| Backupmanifest + SHA-256 | `UKJENT` | `UKJENT` |
| Isolert restore-verdict | `UKJENT` | `UKJENT` |
| Forrige image/digest | `UKJENT` | `UKJENT` |
| Rollback-container | `UKJENT` | `UKJENT` |
| Rollback state-generation | `UKJENT` | `UKJENT` |
| Rollback rute | `UKJENT` | `UKJENT` |
| Rollback testet | `UKJENT` | `UKJENT` |

## Gatejournal

Tillatte verdicts: `pass`, `fail`, `unknown`, `not_run`, `not_relevant`.
`not_relevant` krever begrunnelse og reviewer.

| Gate | Verdict | Tidspunkt | Evidensreferanse | Reviewer/notat |
| --- | --- | --- | --- | --- |
| Kilde og dependency-pins | `fail` | 2026-09-28 | `ROLLOUT_STATUS.json` | Consumer requirements still await published dependency and locked resolution |
| CellProtocol remote pin kan løses låst | `unknown` | | | |
| Binding og CellScaffold bruker avtalt CellProtocol-pin | `unknown` | | | |
| CI, image og provenance | `fail` | 2026-09-28 | Sprout Actions runs 36470283753 / 36470288447 | Private jobs never started: GitHub payment/spending gate; no server image built |
| Koordinering/lås | `unknown` | | | |
| Sanitert deploystatus kan verifiseres uten privat journaltilgang | `unknown` | | | |
| Kapasitet | `fail` | 2026-09-28 | `ROLLOUT.md` capacity checkpoints | Mac projected free 9% with required 10 GiB reserve; server below 40 GiB floor before build/rollback growth |
| Backup og isolert restore | `unknown` | | | |
| Staging atomisk cutover | `not_run` | | | |
| Staging kontrollert restart | `not_run` | | | |
| Offentlig build/ready | `not_run` | | | |
| Scaffold Setup før 45 s | `not_run` | | | |
| Binding exact build/install | `not_run` | | | |
| Identity Link completion staged | `not_run` | | | |
| DeviceIngress `active_consented` | `not_run` | | | |
| APNs fysisk mottak/callback/ack | `not_run` | | | |
| DeviceIngress restartkontinuitet | `not_run` | | | |
| Prod direkte 8084-gate | `not_run` | | | |
| Prod atomisk rute/cutover | `not_run` | | | |
| Prod rollback | `not_run` | | | |

## Fysisk enhet

Ikke skriv rå device-ID, push-token eller identity-ID.

| Felt | Verdi |
| --- | --- |
| Menneskevalgt enhetsnavn | `UKJENT` |
| deviceType | `UKJENT` |
| Xcode-transport | `USB` / `Wi-Fi` / `UKJENT` |
| Binding commit | `UKJENT` |
| Executable SHA-256 | `UKJENT` |
| Provenance SHA-256 | `UKJENT` |
| Bundle-ID / synlig navn | `UKJENT` |
| Normal launch/crash delta | `UKJENT` |

## Failure fingerprint og retrybudsjett

| Forsøk | Phase | Reason code | Kandidathasher | State-generation | Mutation occurred | Diskriminerende test | Resultat |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 0 | | | | | | | |
| 1 (maks) | | | | | | | |

Samme gate blokkert siden UTC:

- `ikke blokkert` / `UKJENT`

To-timers stopptid:

- `ikke relevant` / `UKJENT`

## Mutasjonslogg

| Tid UTC | Executor | Eksakt handling | Controller/hash | Resultat | Rollbackpåvirkning |
| --- | --- | --- | --- | --- | --- |
| | | `ingen mutasjon ennå` | | | |

## Terminal receipt

| Felt | Verdi |
| --- | --- |
| Terminal status | `HANDOFF_REQUIRED`; no server mutation or cutover |
| Eksakt aktiv commit/digest | `UKJENT` |
| Deployjournal/receipt + SHA-256 | `UKJENT` |
| Kapasitet etter | `UKJENT` |
| Cache/DerivedData-delta | `UKJENT` |
| Container/restart count etter | `UKJENT` |
| Offentlig rute/port etter | `UKJENT` |
| Fysisk gate | `not_run` |
| Rollback beholdt til | `UKJENT` |
| Executor sign-off | `UKJENT` |
| Reviewer sign-off | `UKJENT` |
| Menneskelig releaseavgjørelse | `UKJENT` |

## Handoff ved stopp

Hvis status er `HANDOFF_REQUIRED`, oppgi:

1. eksakt mål og authority/non-goals;
2. eksakte commits, image- og controller-hasher;
3. live container/rute/state-generation;
4. siste terminale evidens og failure fingerprint;
5. om mutasjon skjedde;
6. verifisert rollbackstatus;
7. resterende kapasitet;
8. nøyaktig én anbefalt neste diskriminerende handling.

## Scope ledger at preparation

CellScaffold base adf48d4615d1ed143d5bdc190fcf63e266214c8f includes seven commits
after live staging feec23725321320ab00f0e7f7bf728b775869ec7: idea selection and
stage-action/TTL corrections, deploy capacity enforcement, and skill guidance.
The 23-file base difference (872 additions/107 removals) must remain in the
release review; using current main is not evidence by itself. This candidate
adds the owner-attach receiver and readiness, no data migration.

Live production before-value: 18c14c32cb6e2957c1d13a20a4b2d97ece2f02b6.
No server mutation has been performed. No raw identity/device/push secrets
are included here. Current capacity and CI billing gates prevent preflight.

## Concrete handoff boundary

The user's rollout authorization remains valid. The remaining blockers are
capacity, a disconnected physical phone, private GitHub Actions billing, and
verification of final dependency/build artifacts. No new HAVEN, agent or menu
helper has been installed. Sprout alone is installed as a signed local candidate.
No identity/data migration or server mutation has occurred. Existing live
services remain as inventoried; rollback/restore for a new release is not verified.

The first external action is to restore the local build margin, or answer the
pending explicit exception request for a 2 GiB incremental-build reserve.
Automatic approval review rejected that reduction from the required 10 GiB.
It has not been applied. Sufficient server space, private CI recovery and the
connected/unlocked physical phone are independent prerequisites afterwards.
Resume at the exact source/evidence checkpoint in `ROLLOUT.md`; regenerate
preflight and final pins before any install or cutover. Do not treat this packet
as permission to bypass a failed gate.
