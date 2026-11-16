# Binding agent rules

Gjelder Codex, Claude Code og Cowork likt. Felles prosedyre og måling: skillen
`agent-token-discipline` i `<HAVEN_ROOT>/CellScaffold/.claude/skills/`.

## Token- og tråddisiplin

Målt 2026-11-16: Codex-trådene i Binding brukte 429 millioner input-tokens på
én uke for 0,74 millioner output, 582 input-tokens per output-token, med
enkeltdager på over 1 000. Friskt kodearbeid ligger på 50–150. Årsaken er
xcodebuild- og testlogger lest i løkke og tråder som sto åpne i dager.

- **Bygg og tester gjennom skript, aldri i løkke.** Kjør `xcodebuild` via et
  skript i `Scripts/` som venter selv, bruker én stabil `-derivedDataPath`, og
  returnerer høyst 30 linjer: feilene (`grep -E "error:|failed|Executed"`) og
  exit-koden. Les aldri rå xcodebuild-utdata inn i konteksten.
- **Én tråd per oppgave.** Start fra handoff eller `codex exec`-oppdrag,
  lever, skriv handoff, avslutt. Ved 150 000 tokens kontekst eller 100 svar:
  skriv handoff og avslutt.
- **Svar bare ved tilstandsendring.** Ingen fremdriftsnotater eller
  kvitteringer til andre tråder.
- **Si fra når du er for lang.** Passerer konteksten 150 000 tokens, skriv det
  til Digipomps før du fortsetter.
- Måling: `python3 <HAVEN_ROOT>/CellScaffold/scripts/codex_token_usage.py --since 7d --by session --flag`.

## Xcode

- Bruk `<HAVEN_ROOT>/CellScaffold/scripts/xcode-check.sh` der det finnes; det
  bruker én DerivedData-sti og samme kapasitetsgate som CellScaffold.
- Ved «CellProtocol is already opened from another project» eller manglende
  pakkeprodukter: skillen `haven-xcode-workspace-recovery`.
