# Entity experience policy — executable proposal, 2026-09-28

This is a **standalone, synthetic-data prototype**, not a deployed CellProtocol
capability or a notification sender. It explores additional multi-scaffold decision rules requested by Kjetil. No app, agent or scaffold currently calls this package.

## Existing implementation to preserve

Binding main already has `HavenResidencyRanker` / `EntityResidencyCell` and tests
in `InvitationResidencyTests.swift`. The ranker uses the user's weights for
availability, latency, cost, jurisdiction and independence, and excludes
locations that violate jurisdiction/encryption preferences. Local file moves
perform readback; scaffold moves produce an export bundle and await a receipt.
They do not perform automatic remote read/write/index synchronization.

This proposal adds admission/freshness gates, combinations of replicas in
separate failure domains, stability rules and notification channel selection.
Before integration, consolidate its illustrative scoring with the existing
ranker's preferences/explanation model; do not ship two competing preference
systems. The proposed logical operation history and the existing single-home
physical residency model also need an explicit reconciliation contract.

## Placement

For one owner-authorized workload, evaluate candidates in this order:

1. Reject missing/expired admission, a different entity context, absent read,
   write, index or storage capabilities, disallowed jurisdiction, unreachable
   hosts, stale/future observations and malformed metrics.
2. Enumerate feasible sets with the requested replica count, separate failure
   domains and a total cost within budget. At most 16 candidates are accepted;
   larger inputs return an explicit limit result. The prototype never silently
   discards candidates and calls the result globally optimal.
3. Minimize weighted worst availability shortfall, worst latency, total cost and
   average energy. Sort IDs to resolve equal scores deterministically.
4. Keep the currently valid configuration during cooldown or for a small gain.
   Revoked/expired admission bypasses cooldown immediately.
5. Return a proposal and exclusions. The host must revalidate every admission,
   current revocations, data disclosure/storage permissions and inventory version
   at execution time. A plan is never a grant.

The sample weights favor availability. They are product defaults for evaluation,
not learned preferences or user consent. Measured availability is not a promise.
Staging and production on one server are one failure domain. Different labels or
processes do not establish independence. The model makes no probabilistic claim
about combined uptime, and does not move historical data or resolve conflicts.

`entityContext` is a host-local, owner-scoped correlation context obtained from
verified links. It must not become a public global person identifier. Candidate
`admittedUntil` and `capabilities` are trusted resolver outputs, never discovery
claims. `store` is separate from `read`; production integration must use the
canonical RWXS/keypath/purpose contracts, not these prototype labels.

## Notification choice

Choose a fresh foreground surface first, then an authorized APNs/Web Push endpoint
in the user's preference order. Require valid endpoint admission, notification
permission, provider readiness and no revocation. Suppress expired/already
acknowledged events and quiet-hours interruptions without the user's explicit
urgent exception. Wait for the existing receipt deadline before fallback; do not
immediately send the same event to every device.

The caller must atomically claim an attempt in a durable **entity-scoped delivery
ledger** before sending. This pure function does not prevent two servers from
concurrently sending a notification. Provider acceptance, device receipt and the
human's action remain distinct states. All private content requires its own
content/disclosure policy; the default push should contain a neutral notice and
an opaque event reference, then fetch details through the authorized app.

## Intended integration boundaries, for evaluation

- CellProtocol: shared plan/decision value contracts, verified capability inputs,
  stable rejection reasons and reusable pure selection logic.
- Scaffold/runtime: signed inventory observations, policy evaluation, execution,
  operation-log/replica synchronization, durable notification attempt ledger.
- Binding, Sprout, menu helper and web: explain the proposal, collect preferences,
  OS/browser permission, show actual completion/recovery and revocation status.
- APNs, Web Push, FCM, QR and Nearby remain transport/adapters. None establishes
  human ownership or expands a grant.

Before promoting this prototype: add per-workload role placement (read/write/index
may use different hosts), capacity constraints, compatible schema/version and
custody requirements, disclosure/cross-domain consent, migration cost, uncertain
network observations, authenticated execution with compare-and-swap, rollback,
partitions and real-host measurements. Do not route production work through it
until these adapters and policy tests exist.

## Run

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/haven-entity-policy-clang \
  swift test --disable-sandbox --package-path . \
  --scratch-path /private/tmp/haven-entity-policy-20260928
```

All fixtures use invented identities and endpoints. There are no external
package dependencies, credentials, provider calls or user-data writes.
