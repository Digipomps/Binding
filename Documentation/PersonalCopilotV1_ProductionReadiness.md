# Personal Co-Pilot V1 Production Readiness

Dette notatet definerer produksjonsklarhets-formaalet for Binding Personal
Co-Pilot V1.

## Formaal

- `personal.production.readiness`
- `personal.production.readiness.no-raw-failures`
- `personal.production.readiness.owner-scoped-access`
- `personal.production.readiness.gui-quality`

Co-Pilot skal kunne matche prompts som "fiks failure-meldingene", "gjoer denne
flaten produksjonsklar" og "evaluer om GUI-et loeser formaalet" til disse
formaalene.

## Authorization Rule

Binding skal ikke fikse `deniedNoGrant` ved aa legge inn globale bypasser.
Produksjonsklar Personal Co-Pilot bruker ett av disse sporene:

- owner-scoped lokal celle naar data og handlinger eies av brukeren paa enheten
- eksplisitt signert remote-kontrakt naar en CellScaffold/staging-celle eier
  delt state
- public-safe read model naar data er publisert og modererbar

Hvis ingen av sporene finnes, skal flaten vise en menneskelig forklaring eller
lokal fallback, ikke ra `failure`, `denied`, `CellAuthorizationDecision` eller
stack-/debugtekst.

## Failure Budget

For produksjonskritiske Personal Co-Pilot-flater er objektiv port:

- initielle skeleton/root-probes: 0 ra technical failures
- trygge lokale knapper i verifier-korpus: 0 failed actions
- synlig runtime-copy: mindre enn 0.1 prosent av synlige tekstnoder kan
  inneholde `failure`, `denied`, `CellAuthorizationDecision`,
  `Consume command get failed` eller tilsvarende teknisk debugtekst

0.1 prosent er en observabilitetsgrense for store UI-korpus. For de smale
Personal Co-Pilot smoke-testene skal forventningen vaere 0.

## GUI Quality Gate

En Personal Co-Pilot-flate er ikke produksjonsklar bare fordi den kompilerer.
Den skal evalueres paa:

- renhet: ingen ra keypaths, raw provider dumps eller debugfeil i standard UI
- forstaaelighet: brukeren ser hva neste handling gjoer
- eleganse: ett tydelig hovedinteraksjonsomraade, kompakt men komplett
- formaalsloesning: flaten hjelper brukeren med det oppgitte formaalet
- CellProtocol-samsvar: owner, grants og sideeffekter er eksplisitte

Verifier-korpuset i Binding skal utvides foer en flate regnes som ferdig.
