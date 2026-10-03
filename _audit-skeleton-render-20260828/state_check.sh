#!/bin/bash
# Samler tilstand som mounten ikke kan hente: git fetch (nett) og host-prober.
# Kjøres av Codex på macOS. Skriver ALT til rapportfila; ingen output tapes.
set -u
ROOT=/Users/kjetil/Build/Digipomps/HAVEN
OUT="$ROOT/Binding/_audit-skeleton-render-20260828/state-$(date +%Y%m%d-%H%M%S).md"
exec > >(tee "$OUT") 2>&1
echo "# Tilstandssjekk $(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo
echo "## 0. Stale lock"
L="$ROOT/CellProtocol/.git/index.lock"
if [ -e "$L" ]; then rm -f "$L" && echo "slettet $L" || echo "KUNNE IKKE slette $L"; else echo "ingen index.lock"; fi

for r in CellScaffold CellProtocol Binding; do
  cd "$ROOT/$r" || continue
  echo
  echo "## $r"
  echo '```'
  echo "-- fetch --"
  timeout 90 git fetch --all --prune 2>&1 | tail -5
  echo "-- HEAD --"
  git log -1 --format='%h %ad %an %s' --date=short
  echo "branch: $(git branch --show-current)"
  echo "-- origin/main --"
  git log -1 --format='%h %ad %an %s' --date=short origin/main
  echo "-- commits på origin/main siste 4 dager --"
  git log --since=2026-08-26 --format='  %h %ad %an %s' --date=short origin/main | head -25
  echo "-- er HEAD bak origin/main? --"
  git rev-list --left-right --count origin/main...HEAD 2>/dev/null | awk '{print "  bak origin/main: "$1"   foran: "$2}'
  echo '```'
done

echo
echo "## Bridgehead-ruten på origin/main (CellScaffold)"
cd "$ROOT/CellScaffold"
echo '```'
echo "-- aktiv webSocket-registrering i Sources/App på origin/main --"
git grep -n 'webSocket(' origin/main -- Sources/App | grep -v '^\S*: *//' | head -20
echo
echo "-- grouped(\"bridgehead\") noe sted på origin/main --"
git grep -n 'grouped("bridgehead")' origin/main -- Sources | head
echo
echo "-- VaporBridgehead.boot finnes? --"
git grep -n 'func boot' origin/main -- Sources/App/Controllers/VaporBridgehead.swift | head
echo
echo "-- d805be6c og a3cb593b: er de på origin/main? --"
for s in d805be6c a3cb593b 14b50a51; do printf "%s -> " "$s"; git merge-base --is-ancestor "$s" origin/main 2>/dev/null && echo "PÅ origin/main" || echo "IKKE på origin/main (eller ukjent)"; done
echo '```'

echo
echo "## Levende verter"
echo '```'
for h in staging.haven.digipomps.org haven.digipomps.org; do
  echo "== $h"
  echo -n "  /health/build: "; curl -sS --max-time 12 "https://$h/health/build" | head -c 300; echo
  U=$(uuidgen | tr 'A-Z' 'a-z')
  echo -n "  ws /bridgehead/ConfigurationCatalog: "
  curl -sS -i -N --http1.1 --max-time 8 -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "https://$h/bridgehead/ConfigurationCatalog/$U" 2>&1 | grep -m1 -E '^HTTP/' | tr -d '\r'
  echo -n "  personal-copilot katalog: "; curl -sS -o /dev/null -w '%{http_code}\n' --max-time 12 "https://$h/personal-copilot-v1/api/catalog"
  echo -n "  skeleton-parity text config: "; curl -sS -o /dev/null -w '%{http_code}\n' --max-time 12 "https://$h/skeleton-parity/text/api/configuration"
done
echo '```'
echo
echo "RAPPORT: $OUT"
