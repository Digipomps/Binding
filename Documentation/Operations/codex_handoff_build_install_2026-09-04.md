# Codex-oppdrag: bygg og start HAVEN fra gjeldende arbeidstre (2026-09-04)

Formål: Den HAVEN-appen som kjører på Mac-en skal være bygget fra **nøyaktig det
arbeidstreet som ligger i /Users/kjetil/Build/Digipomps/HAVEN/Binding akkurat nå**
(gren `codex/havenagentd-sentinel-remote-intent-icon-20260804`, inkludert
ukommitterte endringer). Hvert steg måles mot det.

Kalleren (Claude via codex-local MCP) kan time ut etter 60 s. Ikke vent på mer
input — fullfør på disk og skriv rapporten til fila under.

## Godkjente steg

1. `cd /Users/kjetil/Build/Digipomps/HAVEN/Binding`
2. Noter `git rev-parse --short HEAD`, `git status --short | wc -l` og
   `git log -1 --format='%h %ci %s'`. **Ikke** bytt gren, ikke pull, ikke stash,
   ikke rør ukommitterte endringer.
3. Fjern eventuelle stale `.git/*.lock` som ikke tilhører en kjørende prosess.
4. Kjør `Scripts/run_binding.sh` (bygger via build_binding.sh og starter nøyaktig
   den bundelen bygget produserte). Logg til
   `/tmp/haven_build_2026-09-04.log`.
5. Verifiser — ikke stol på `.app`-katalogens mtime:
   - `stat -f '%Sm' <APP>/Contents/MacOS/HAVEN.debug.dylib` skal være fra nå
   - `pgrep -fl HAVEN.app/Contents/MacOS/HAVEN` viser at appen kjører
6. Skriv rapport til
   `Documentation/Operations/codex_report_build_install_2026-09-04.md` med:
   HEAD-sha, antall dirty filer, BUILT_PRODUCTS_DIR-stien, dylib-mtime,
   pid, og ved feil: de siste 40 linjene fra byggloggen.

## Ikke godkjent
- Kodeendringer for å få bygget grønt. Feiler bygget: rapporter og stopp.
- Kopi til /Applications (ikke bestilt).
