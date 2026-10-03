# Handoff: kjør HAVEN surface audit (2026-08-28)

Objective: kjør den nye audit-testen `BindingTests/RemoteSurfaceRenderAuditXCTest`
mot staging og prod, og la rapporten lande i `_audit-skeleton-render-20260828/reports/`.

Kommando (kjør rett fram, ikke nohup/&/launchctl):

    zsh /Users/kjetil/Build/Digipomps/HAVEN/Binding/_audit-skeleton-render-20260828/run_surface_audit.sh

Skriptet logger til `_audit-skeleton-render-20260828/logs/xcodebuild-<stamp>.log`
og avslutter med `EXIT=<kode>` + `DONE`. Testen skriver
`reports/surface-audit-<stamp>.json` og `.md`.

Constraints:
- Ikke rediger kildefiler. Ikke bytt branch. Ikke rør `_wt-*`-worktrees.
- Hvis bygget feiler på kompilering i `RemoteSurfaceRenderAuditXCTest.swift`,
  IKKE fiks selv: skriv feilene (fil:linje + melding) til
  `_audit-skeleton-render-20260828/logs/compile-errors-<stamp>.md` og stopp.
- Kalleren (Claude via MCP) kan time ut etter 60 s. Fullfør uansett; loggfila er kanalen.

Verifikasjon som forventes: `** TEST SUCCEEDED **` eller `** TEST FAILED **` i loggen,
og at minst én `surface-audit-*.md` finnes under `reports/`.
