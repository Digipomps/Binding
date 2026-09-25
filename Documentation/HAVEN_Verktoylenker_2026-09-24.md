# Verktøylenker i «Utvid entiteten» (2026-09-24)

En verktøycelle i den lokale agenten (HavenAgentD) får bare sende testinstruksjoner når eieren har
godkjent den med en **entitetslenke** — samme dokument som lenken eier↔agent (Sprout-format, JCS,
`scope: agent.tool.instruct`, `revocation: owner-only`). Kjetil 2026-09-24: «Godkjenning av link må
kunne initsieres fra begge sider — når den besvares fra den andre siden må det være tydelig i begge
ender hva som skjer.» Denne siden beskriver HAVEN-enden. Agentenden, rutene og tilstandene står i
HavenAgentD `Docs/Testflyt_Verktoycelle.md`; beslutningene (B7, B10) og testresultatene i HavenAgentD
`Docs/PDD_testflyt-verktoycelle_20260923/`.

## Det du ser

«Utvid entiteten» er fire kort i HAVENs designsystem (`BindingPersonalCopilotDesignSystem`),
venstrestilt (godkjent skisse: HavenAgentD
`Docs/PDD_testflyt-verktoycelle_20260923/images/haven-lenke-begge-veier-v2.png`; runde 3, 25.09):

1. **Utvid entiteten** — hvor entiteten finnes («… her og i HAVEN Agent på denne maskinen» når
   agenten er paret her), og sikkerhetslinjen.
2. **HAVEN Agent på denne maskinen** — én av disse:
   - agenten er paret med en annen identitet (eller ikke paret): **bare paringen** — et gult kort med
     **Par agenten med denne HAVEN-en** og **Oppdater**. Forespørsler og lenker til den andre
     identiteten vises ikke, og det finnes ingen svarknapper eller «Tilby», fordi agenten ville
     avvist dem. Paringen kjører den vanlige paringen (`cell:///AgentEnrollment`,
     `enrollment.createPairingArtifact`: agenten attesterer, du signerer med Touch ID, paringen og
     entitetslenken skrives der agenten leser dem) uten å røre agentens config eller oppstart; agenten
     tar den i bruk ved neste oppstart. Paringsflaten finnes bare når agentoppsettet er slått på
     (utviklerbygg: `--enable-agent-setup-workbench`).
   - agenten er paret her: **Ber om tilgang** (A) med **Oppdater** — hver forespørsel er et kort med
     verktøyet og hva det ber om i halvfet, omfang, verktøynøkkelens fingeravtrykk og når den ble
     startet, **de fire ordene som merkelapp**, «Stemmer ordene med dem i HAVEN Agent?», og
     **Godkjenn**/**Avvis** (Touch ID). Svaret står under («Godkjent: … HAVEN Agent viser at du
     godkjente.»). Så **Gi tilgang** (B): velg verktøy og tilgang, **Tilby** (Touch ID); tilbudet står
     med ordene og «venter på svar i HAVEN Agent».
   - ingen agent på maskinen: én linje, «HAVEN Agent er ikke satt opp på denne maskinen.»; får HAVEN
     ikke kontakt: grunnen og **Prøv igjen**.
3. **Koblede steder** — verktøyene som har tilgang («✓ godkjent av deg 12:34», «✓ godtatt i HAVEN
   Agent 12:41») med **Trekk tilbake** (Touch ID), stedene entiteten er utvidet til, og **Siste svar**
   som én farget linje hver («… · ✗ avvist i HAVEN Agent 12:41», «… · utløpt uten svar»).
4. **Nytt sted** — adressefeltet (Enter starter forespørselen), koden og forespørslene som venter.

## Det HAVEN sjekker før din nøkkel signerer

`ToolLinkReview.checkToolRequest` (i `Cells/BindingToolLinkController.swift`):

1. lenken er ment for nøkkelen i denne HAVEN-en (`pubkey_a`),
2. omfang, verktøydomene og tilbaketrekkingsmodus er de avtalte,
3. de kanoniske bytene HAVEN regner ut er de samme som agenten viser (`canonicalPayloadBase64URL`),
4. verktøyets signatur holder over de bytene,
5. de fire ordene HAVEN regner ut er de samme som agenten viser.

Feiler én av dem, får kortet en advarsel og ingen svarknapper, og **Godkjenn** signerer ikke. En
forespørsel til en annen identitet (punkt 1) vises ikke; paringen er svaret på den. Ordene regnes ut som i
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
| `extension.toolLinks.selection` / `.scopeSelection` | velgernes tilstand: les gir `{selected}`, skriv tar imot `{selectedIndex, selected}` fra velgeren |
| `extension.toolLinks.selectTool` / `.selectScope` | samme valg, for kall utenfra |
| `extension.toolLinks.pairAgent` | par agenten med identiteten som brukes her (se over) |

Felter i `state` som flaten leser: `summary`, `safetyLine`, `toolAgentRows` (kortet for agenten),
`linkedRows` (koblede steder: verktøy, steder, siste svar), `newPlaceRows` (svar og ventende
forespørsler), `toolChoices`, `toolScopeChoices`. Hver rad har `kind` (`pairing`, `problem`,
`subheading`, `request`, `offerForm`, `outgoing`, `tool`, `device`, `history`, `code`, `pending`,
`note`, `success`, `failure`), og flaten viser bare delen for den typen. Øvrige felter:
`toolSummary`, `toolIncoming`, `toolOutgoing`, `toolActive`, `toolHistory` (+ `…Count`),
`toolLinkedRows`, `toolHistoryRows`, `agentPairing`, `selectedToolID`, `selectedScope`,
`toolAnswerMessage`, `toolOfferMessage`, `toolLinkedMessage`, `toolPairingMessage`.

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

`BindingTests/ToolLinkControllerTests.swift` (Swift Testing, falsk agent i minnet), 11 tester:

- ordene og JCS følger agentens testvektor;
- kontrollen stopper feil eier, endrede bytes, forfalsket verktøysignatur og ulike ord;
- begge ender forteller det samme om hvem som svarte og hva svaret ble, og flaten får radene i riktig
  rekkefølge (også sporlinjen, så det aldri står «Innholdet er ikke tilgjengelig»);
- **Godkjenn** legger eierens signatur ved siden av verktøyets, og den verifiserer;
- eierens nøkkel signerer aldri noe som ikke besto kontrollen (ingen signering, ingen POST), og en
  forespørsel til en annen identitet vises ikke;
- **Tilby** signeres av eieren først, for verktøyets nøkkel agenten oppga, og stoppes her når HAVEN har
  en annen nøkkel enn agenten er paret med;
- når nøkkelen ikke stemmer, eller agenten ikke er paret, er paringen det eneste kortet viser — ingen
  forespørsler, ingen «Trekk tilbake» og ikke noe spor fra den andre identiteten;
- uten agent på maskinen sier kortet det med én linje;
- velgeren leser og skriver `{selected}`;
- avslag og tilbaketrekking er signerte utsagn som verifiserer.

Flaten: `CellConfigurationVerifierXCTest/testNoLocalSurfaceHidesItsOwnWaysIn` finner ingenting i
«Utvid entiteten» (testen feiler på «Relasjoner», som den gjorde før denne grenen), og
`testPersonalCopilotLocalSurfacesLoadWithoutReferenceFailures` er grønn.

## Kjente grenser

- **Venstrestilt tekst krever paritetsendringen i rendreren.** I CellProtocol-versjonen HAVEN bygget
  mot (tilstanden fra 16.09) sentrerer `CellTextView` teksten i sin egen ramme, og VStack/HStack er
  sentrert; `hAlignment` kan ikke overstyre det. HAVEN-grenen bygger derfor mot en lokal commit i
  CellProtocol (`claude/haven-lenke-base-20260924`, 291f1fb) med de samme linjene som 6218ed5/fa7982d
  og 410a0c6 i `codex/prod-complete-20260917`. Den gjør alle flater i bygget venstrestilte, og er ikke
  til main.
- Synlighetsregler med `scope: .root` virker ikke på toppnivå (de evalueres mot en verdi som ikke
  finnes der). Hvert kort er derfor én liste der cellen bestemmer radene; en skjult rad tar ingen
  plass, men en tom liste gjør det. Inne i en rad virker `scope: .item`.
- `wrap` (FlowLayout) gir hvert element sin ideelle bredde og bryter aldri tekst: bare korte
  merkelapper der. Knapper står i en vanlig HStack, som kan krympe dem og bryte en lang tekst.
- `maxWidthInfinity` gjør også høyden strekkbar i denne rendereren; i en listerad kuttet det teksten ved
  siden av med «…». Den brukes ikke i radene.
- Kort i en liste står 8 pt inn fra venstre og 16 pt inn fra høyre i kortet rundt (radens polstring og
  mellomrom i rendreren).
- Tekstfeltet følger systemets mørke modus, resten av flaten har faste lyse farger.
- En velger (`Picker`) skriver valget til `selectionStateKeypath` og leser `{selected}` derfra når den
  vises. Nøkkelen må derfor være både lesbar og skrivbar; ellers står velgeren på «Velg …».
- Flaten oppdaterer seg når den leses, ikke av seg selv. **Oppdater** henter nytt bilde med én gang.
- Når HAVEN ikke får lest agentens `config.json` (sandkasse uten tilgang til Application Support),
  sier kortet at HAVEN Agent ikke er satt opp på maskinen.
