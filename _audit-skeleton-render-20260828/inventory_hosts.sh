#!/bin/bash
# Inventory of what staging and prod actually publish over HTTP, plus a raw
# WebSocket-upgrade probe on the bridgehead route HAVEN uses. Runs on the Mac
# (the Cowork VM has no network). Writes everything under ./inventory/<host>/.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/inventory"
mkdir -p "$OUT"
SUMMARY="$OUT/inventory_summary.md"
: > "$SUMMARY"
echo "# Host inventory $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$SUMMARY"

probe_http() { # host path label
  local host="$1" path="$2" label="$3" dir="$OUT/$1"
  mkdir -p "$dir"
  local body="$dir/$label.json" meta
  meta=$(curl -sS -o "$body" -w '%{http_code} %{time_total} %{size_download}' --max-time 12 "https://$host$path" 2>"$dir/$label.err")
  local code; code=$(echo "$meta" | awk '{print $1}')
  local t; t=$(echo "$meta" | awk '{print $2}')
  local sz; sz=$(echo "$meta" | awk '{print $3}')
  echo "| $host | GET $path | ${code:-ERR} | ${t:-?}s | ${sz:-0} B | $(head -c 120 "$dir/$label.err" 2>/dev/null | tr '\n' ' ') |" >> "$SUMMARY"
}

probe_ws() { # host path label
  local host="$1" path="$2" label="$3" dir="$OUT/$1"
  mkdir -p "$dir"
  local hdr="$dir/ws_$label.txt"
  curl -sS -i -N --http1.1 --max-time 8 \
    -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "https://$host$path" > "$hdr" 2>&1
  local status; status=$(grep -m1 -E '^HTTP/' "$hdr" | tr -d '\r')
  echo "| $host | WS $path | ${status:-no HTTP status (see ws_$label.txt)} | | | |" >> "$SUMMARY"
}

echo "" >> "$SUMMARY"
echo "| host | request | status | time | size | note |" >> "$SUMMARY"
echo "|---|---|---|---|---|---|" >> "$SUMMARY"

for host in staging.haven.digipomps.org haven.digipomps.org; do
  probe_http "$host" "/health/build" "health_build"
  probe_http "$host" "/health/ready" "health_ready"
  probe_http "$host" "/personal-copilot-v1/api/catalog" "pc_catalog"
  probe_http "$host" "/personal-copilot-v1/api/catalog/allowed" "pc_catalog_allowed"
  probe_http "$host" "/personal-copilot-v1/api/catalog/unavailable" "pc_catalog_unavailable"
  for s in profile directory matchmaking chat meeting catalog; do
    probe_http "$host" "/personal-copilot-v1/$s/api/configuration" "pc_${s}_configuration"
  done
  probe_http "$host" "/skeleton-parity/api/catalog" "sp_catalog"
  probe_http "$host" "/skeleton-parity/text/api/configuration" "sp_text_configuration"
  probe_http "$host" "/browserhead/porthole/bootstrap" "browserhead_bootstrap"
  UUID=$(uuidgen | tr 'A-Z' 'a-z')
  probe_ws "$host" "/bridgehead/ConfigurationCatalog/$UUID" "bridgehead_catalog"
  probe_ws "$host" "/bridgehead/Porthole/SkeletonParityTextFixture" "bridgehead_parity_fixture"
  probe_ws "$host" "/bridgehead/session" "bridgehead_session"
  probe_ws "$host" "/palazzo-concierge/bridgehead/PalazzoConciergeKnowledge" "palazzo_bridgehead"
done

echo "" >> "$SUMMARY"
echo "## Published configuration names" >> "$SUMMARY"
for host in staging.haven.digipomps.org haven.digipomps.org; do
  f="$OUT/$host/pc_catalog.json"
  echo "" >> "$SUMMARY"; echo "### $host personal-copilot-v1/api/catalog" >> "$SUMMARY"
  if [ -s "$f" ]; then
    python3 - "$f" >> "$SUMMARY" 2>&1 <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
except Exception as e:
    print("not json:", e); sys.exit(0)
def names(v):
    out=[]
    if isinstance(v,list):
        for item in v:
            if isinstance(item,dict):
                out.append(item.get("name") or item.get("configurationName") or item.get("displayName") or str(list(item.keys())[:4]))
            else:
                out.append(str(item)[:60])
    elif isinstance(v,dict):
        out.append("dict keys: "+", ".join(list(v.keys())[:20]))
    else:
        out.append(str(v)[:200])
    return out
print("top-level keys:", list(d.keys()) if isinstance(d,dict) else type(d).__name__)
if isinstance(d,dict):
    for k in ("state","entries","configurations","policySummary"):
        if k in d:
            print(f"- {k}:")
            for n in names(d[k])[:80]:
                print(f"  - {n}")
PY
  else
    echo "(empty)" >> "$SUMMARY"
  fi
  f2="$OUT/$host/sp_catalog.json"
  echo "" >> "$SUMMARY"; echo "### $host skeleton-parity/api/catalog" >> "$SUMMARY"
  if [ -s "$f2" ]; then
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); fx=d.get("fixtures",[]); print(len(fx),"fixtures:", ", ".join(str(f.get("slug") or f.get("kind") or f) for f in fx))' "$f2" >> "$SUMMARY" 2>&1
  else
    echo "(empty)" >> "$SUMMARY"
  fi
done
echo "" >> "$SUMMARY"
echo "DONE $(date -u +%H:%M:%SZ)" >> "$SUMMARY"
