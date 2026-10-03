#!/bin/bash
# 1) ekte fetch (uten `timeout`, som ikke finnes på macOS)
# 2) list worktrees
# 3) skriv ut origin/main-versjonen av filene bro-arbeidet trenger, til en
#    mappe mounten kan lese. Hovedtreet er 226 commits bak, så filene der lyver.
set -u
ROOT=/Users/kjetil/Build/Digipomps/HAVEN
DEST="$ROOT/Binding/_audit-skeleton-render-20260828/originmain"
OUT="$ROOT/Binding/_audit-skeleton-render-20260828/state-fetch-$(date +%Y%m%d-%H%M%S).md"
mkdir -p "$DEST"
exec > >(tee "$OUT") 2>&1
echo "# Fetch + uttrekk $(date -u +%Y-%m-%dT%H:%M:%SZ)"

for r in CellScaffold CellProtocol Binding; do
  cd "$ROOT/$r" || continue
  echo; echo "## $r"; echo '```'
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10' \
    git fetch --all --prune 2>&1 | tail -6
  echo "origin/main: $(git log -1 --format='%h %ad %s' --date=short origin/main)"
  git rev-list --left-right --count origin/main...HEAD | awk '{print "  HEAD bak: "$1"  foran: "$2}'
  echo "worktrees:"; git worktree list | sed 's/^/  /'
  echo '```'
done

echo; echo "## Filer fra CellScaffold origin/main"
cd "$ROOT/CellScaffold"
for f in \
  Sources/ScaffoldKit/AdminScaffoldBridgeRoutes.swift \
  Sources/ScaffoldKit/AdminScaffoldRuntime.swift \
  Sources/ScaffoldKit/AdminControlPlaneRouting.swift \
  Sources/ScaffoldKit/AdminAuthenticatedVaporBridgeTransport.swift \
  Sources/App/routes.swift \
  Sources/App/Controllers/VaporBridgehead.swift \
  Sources/App/Services/SproutBridgeDiscoveryCompatibility.swift ; do
  n=$(echo "$f" | tr '/' '_')
  if git show "origin/main:$f" > "$DEST/$n" 2>/dev/null; then
    echo "  ok  $(wc -l < "$DEST/$n" | tr -d ' ') linjer  $f"
  else
    echo "  MANGLER på origin/main: $f"; rm -f "$DEST/$n"
  fi
done

echo; echo "## Hvem eier handshake-verifiseringen på origin/main"
echo '```'
git grep -n "handshakeVerifier\|struct AdminBridgeHandshake\|func validate(request" origin/main -- Sources/ScaffoldKit | head -20
echo '```'
echo; echo "RAPPORT: $OUT"; echo "FILER:   $DEST"
