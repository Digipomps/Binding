#!/bin/bash
# Forensikk: hva ble fjernet i herdingskampanjen, og virker NOEN bro i dag.
# Kjøres av Codex på macOS (git + nett). Mounten kan verken git eller nett.
set -u
ROOT=/Users/kjetil/Build/Digipomps/HAVEN
OUT="$ROOT/Binding/_audit-skeleton-render-20260828/forensics-$(date +%Y%m%d-%H%M%S).md"
exec > >(tee "$OUT") 2>&1
cd "$ROOT/CellScaffold" || exit 1

BASE=$(git rev-list -1 --before=2026-07-01 origin/main)
echo "# Broforensikk $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo
echo "Referansepunkt før herdingen: \`$BASE\` ($(git log -1 --format='%ad %s' --date=short $BASE))"
echo "Nå: \`$(git rev-parse --short origin/main)\` ($(git log -1 --format='%ad %s' --date=short origin/main))"

echo
echo "## 1. Slettede filer under Sources/ i hele perioden"
echo '```'
git log --diff-filter=D --name-only --format='COMMIT %h %ad %s' --date=short "$BASE..origin/main" -- Sources | grep -v '^$' | head -60
echo '```'

echo
echo "## 2. WebSocket-registreringer: før vs nå"
echo '```'
echo "--- FØR ($BASE) ---"
git grep -n 'webSocket(' "$BASE" -- Sources | grep -v ': *//' | sed 's/^[^:]*://'
echo
echo "--- NÅ (origin/main) ---"
git grep -n 'webSocket(' origin/main -- Sources | grep -v ': *//' | sed 's/^[^:]*://'
echo '```'

echo
echo "## 3. register(collection:) — hvilke rutesamlinger forsvant"
echo '```'
git grep -h 'register(collection:' "$BASE" -- Sources/App/routes.swift | sed 's/.*collection: //;s/()).*//;s/).*//' | sort > /tmp/before_cols.txt
git grep -h 'register(collection:' origin/main -- Sources/App/routes.swift | sed 's/.*collection: //;s/()).*//;s/).*//' | sort > /tmp/after_cols.txt
echo "FJERNET siden $BASE:"; comm -23 /tmp/before_cols.txt /tmp/after_cols.txt | sed 's/^/  - /'
echo "LAGT TIL:"; comm -13 /tmp/before_cols.txt /tmp/after_cols.txt | sed 's/^/  + /'
echo '```'

echo
echo "## 4. Commits som rørte VaporBridgehead eller bro-ruter"
echo '```'
git log --format='  %h %ad %an  %s' --date=short "$BASE..origin/main" -- \
  Sources/App/Controllers/VaporBridgehead.swift \
  Sources/ScaffoldKit/AdminScaffoldBridgeRoutes.swift | head -30
echo '```'

echo
echo "## 5. Er bro-koden i CellProtocol intakt?"
cd "$ROOT/CellProtocol"
echo '```'
CPBASE=$(git rev-list -1 --before=2026-07-01 origin/main)
echo "CellProtocol før: $CPBASE  nå: $(git rev-parse --short origin/main)"
echo "Slettede filer under Sources:"
git log --diff-filter=D --name-only --format='COMMIT %h %ad %s' --date=short "$CPBASE..origin/main" -- Sources | grep -v '^$' | head -30
echo "(tomt = ingenting slettet)"
echo '```'

echo
echo "## 6. Virker NOEN bro live?"
echo '```'
probe_ws() {
  local url="$1" label="$2"
  local status
  status=$(curl -sS -i -N --http1.1 --max-time 10 \
    -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "$url" 2>&1 | grep -m1 -E '^HTTP/' | tr -d '\r')
  printf '  %-58s %s\n' "$label" "${status:-INGEN HTTP-RESPONS}"
}
U=$(uuidgen | tr 'A-Z' 'a-z')
for h in staging.haven.digipomps.org haven.digipomps.org; do
  echo "== $h"
  probe_ws "https://$h/bridgehead/ConfigurationCatalog/$U"            "generell bro /bridgehead/<celle>/<uuid>"
  probe_ws "https://$h/bridgehead/session"                            "multipleks /bridgehead/session"
  probe_ws "https://$h/v1/resolver/native-porthole/Porthole/$U"       "sprout native-porthole (uten kontrakt)"
  probe_ws "https://$h/browserhead/wsce/$U"                           "browserhead wsce (uten sesjon)"
  probe_ws "https://$h/palazzo-concierge/bridgehead/PalazzoConciergeKnowledge" "palazzo under sti-prefiks"
done
echo "== admin.staging.haven.digipomps.org (AdminScaffold, egen vert)"
probe_ws "https://admin.staging.haven.digipomps.org/bridgehead/AdminEntry/$U" "admin bro /bridgehead/AdminEntry/<uuid>"
probe_ws "https://admin.staging.haven.digipomps.org/bridgehead/session"       "admin multipleks"
echo -n "  admin /health/live: "; curl -sS -o /dev/null -w '%{http_code}\n' --max-time 10 https://admin.staging.haven.digipomps.org/health/live
echo '```'

echo
echo "## 7. Palazzo og Butterpop over HTTP"
echo '```'
for h in staging.haven.digipomps.org haven.digipomps.org; do
  echo "== $h"
  for p in /palazzo-concierge/ /palazzo/api/ask /butterpop /butterpop/api/catalog /mvp/music/tracks; do
    printf '  %-34s ' "$p"
    curl -sS -o /dev/null -w '%{http_code}  %{time_total}s\n' --max-time 12 "https://$h$p"
  done
done
echo '```'
echo
echo "RAPPORT: $OUT"
