# Plan

WP1 purpose://quality.build-and-regression — root: bygg oppdatert Binding main, reparer kandidatens testoppsett, kjør native regresjoner. Bevis: build-baseline.log og evidence/.
WP2 purpose://cells.capabilities-declared-with-boundary — transport_repair: reparer offentlig katalog med samme autorisasjonsgrense som eksisterende public read-model, test; spor og integrer bare riktig sikker native transport. Bevis: TRANSPORT.md, tester og faktiske svar.
WP3 purpose://gui.parity-with-approved-image — renderer_repair: rett generelle native layoutavvik og de to målte chat-rollene; eksplisitte modifiers vinner. Root: test original state gjennom Binding og lag sammenlignbare bilder. Bevis: RENDERER.md, raw payload + PNG + testlogger.
WP4 purpose://gui.ways-in-are-reachable — root: korpus-inventar fra faktiske enum-cases og katalog, handlinger og målrettede regresjoner; ikke erklær alle grønne på en delmengde.
WP5 purpose://quality.docs-in-same-change — root: versjoner/pakker/testresultater og leveransekandidat; ingen eksisterende WIP overskrives. Lokal commit etter verifikasjon. Produksjonsdeploy er separat milepæl og skal ikke hevdes gjennomført uten test.

## Dataflow
HTTP public configuration/state -> same original JSON -> web SkeletonRuntime / BindingSkeletonView -> CellApple.
Native action -> active requester + resolver/Meddle -> authorized source cell -> new state -> renderer.
Transport possession never grants authority. Alternate private/user paths remain policy-gated.
