# Verktøylenker i «Utvid entiteten» (2026-09-24)

En verktøycelle i den lokale agenten (HavenAgentD) får bare sende testinstruksjoner når eieren har
godkjent den med en **entitetslenke** — samme dokument som lenken eier↔agent (Sprout-format, JCS,
`scope: agent.tool.instruct`, `revocation: owner-only`). Kjetil 2026-09-24: «Godkjenning av link må
kunne initsieres fra begge sider — når den besvares fra den andre siden må det være tydelig i begge
ender hva som skjer.» Denne siden beskriver HAVEN-enden. Agentenden, rutene og tilstandene står i
HavenAgentD `Docs/Testflyt_Verktoycelle.md`; beslutningene (B7, B10) og testresultatene i HavenAgentD
`Docs/PDD_testflyt-verktoycelle_20260923/`.

## Det du ser

«Utvid entiteten» har tre nye deler (godkjent skisse: HavenAgentD
`Docs/PDD_testflyt-verktoycelle_20260923/images/haven-lenke-begge-veier-v2.png`):

- **Ber om tilgang** — verktøy som ber (A). Hver forespørsel viser hvem, hva
  (`agent.tool.instruct`), verktøynøkkelens fingeravtrykk, når den ble startet, og **de fire ordene**
  med spørsmålet «Stemmer ordene med dem i HAVEN Agent?». **Godkjenn** legger din signatur ved siden
  av verktøyets; **Avvis** sender et signert avslag. Begge ber om Touch ID.
- **Gi tilgang** — du tilbyr (B): velg verktøy og tilgang, trykk **Tilby** (Touch ID). Tilbudet står
  som «venter på svar i HAVEN Agent» med de fire ordene til det er besvart der.
- **Koblede steder → Verktøy i agenten din** — aktive lenker med hvem som svarte og når
  («✓ godkjent av deg 12:34», «✓ godtatt i HAVEN Agent 12:41») og **Trekk tilbake** (Touch ID), og
  de siste svarene som spor («✗ avvist i HAVEN Agent», «trukket tilbake av deg», «utløpt uten svar»).

Øverst i «Ber om tilgang» står en linje med antall, eller en advarsel når HAVEN-en ikke har nøkkelen
agenten er paret med — da vil agenten avvise svar herfra, og flaten sier det før du trykker.

## Det HAVEN sjekker før din nøkkel signerer

`ToolLinkReview.checkToolRequest` (i `Cells/BindingToolLinkController.swift`):

1. lenken er ment for nøkkelen i denne HAVEN-en (`pubkey_a`),
2. omfang, verktøydomene og tilbaketrekkingsmodus er de avtalte,
3. de kanoniske bytene HAVEN regner ut er de samme som agenten viser (`canonicalPayloadBase64URL`),
4. verktøyets signatur holder over de bytene,
5. de fire ordene HAVEN regner ut er de samme som agenten viser.

Feiler én av dem, får raden en advarsel, og **Godkjenn** signerer ikke. Ordene regnes ut som i
CellBase `IdentityLinkSAS` (256 ord, ett per byte av SHA-256). Ordlisten er kopiert fordi
CellProtocol-versjonen HAVEN bygger mot ennå ikke har den; testvektoren
`elc_tool_testvector0001` → `db5de536…` → «ås · juv · selje · frosk» står i begge repoer.

## Nøkler på cellen

| Nøkkel | Hva |
|---|---|
| `extension.toolLinks` (les) | bare verktøylenkene; de samme feltene er også flettet inn i `state` |
| `extension.toolLinks.refresh` | hent nytt bilde fra agenten |
| `extension.toolLinks.approve` / `.decline` | svar på en forespørsel; payload `contractID` |
| `extension.toolLinks.offer` | tilby valgt verktøy tilgang |
| `extension.toolLinks.revoke` | trekk tilbake en aktiv lenke; payload `contractID` |
| `extension.toolLinks.selectTool` / `.selectScope` | valgene i «Gi tilgang» |

Felter i `state`: `toolSummary`, `toolIncoming`, `toolOutgoing`, `toolActive`, `toolHistory` (+
`…Count`), `toolChoices`, `toolScopeChoices`, `selectedToolID`, `selectedScope`,
`toolAnswerMessage`, `toolOfferMessage`, `toolLinkedMessage`.

Signeringen bruker samme identitet som paringen: den som trykker, når den har navn og nøkkel, ellers
cellens eier. Nøkkelen sendes i samme form som i paringen (`publicSecureKey.compressedKey`,
base64url; P-256 gir `alg: P256-ES256`).

## Hvordan HAVEN når agenten

Adressen og tokenet leses fra agentens `config.json` (`localControlBridge`) gjennom
`AgentLocalControlBridgeEndpointSupport.controlBridgeHTTPEndpoint()` — samme fil og samme token som
broendepunktene ellers, bare loopback. Rutene: `GET /test-flow/tools`, `GET /test-flow/approvals`,
`POST /test-flow/approval`, `/decline`, `/offer`, `/revoke`. Tilstanden hentes på nytt når flaten
leser den, høyst hvert femte sekund, og etter hver handling.

## Tester

`BindingTests/ToolLinkControllerTests.swift` (Swift Testing, falsk agent i minnet):

- ordene og JCS følger agentens testvektor;
- kontrollen stopper feil eier, endrede bytes, forfalsket verktøysignatur og ulike ord;
- begge ender forteller det samme om hvem som svarte og hva svaret ble;
- **Godkjenn** legger eierens signatur ved siden av verktøyets, og den verifiserer;
- eierens nøkkel signerer aldri noe som ikke besto kontrollen (ingen signering, ingen POST);
- **Tilby** signeres av eieren først, for verktøyets nøkkel agenten oppga;
- tilbud stoppes her når HAVEN har en annen nøkkel enn agenten er paret med;
- avslag og tilbaketrekking er signerte utsagn som verifiserer.

## Kjente grenser

- Synlighetsreglene (skjul tomme lister, vis advarsel bare når den finnes) forutsetter at
  rendereren støtter `visibility` i `SkeletonModifiers`. Uten den vises tomme lister og tomme linjer.
- Flaten oppdaterer seg når den leses, ikke av seg selv. **Oppdater** henter nytt bilde med én gang.
- Når HAVEN ikke får lest agentens `config.json` (sandkasse uten tilgang til Application Support),
  sier flaten «Fant ikke agentens kontrollbro …».
