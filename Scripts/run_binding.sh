#!/bin/zsh
# Bygger HAVEN og starter NØYAKTIG den app-bundelen bygget produserte.
#
# Bakgrunn: prosjektet har hopet opp titalls DerivedData-mapper, og
# `.app`-katalogens mtime endrer seg ikke når binæren inni byttes ut. Å plukke
# "nyeste" bundle med `ls -t` gir derfor feil app, og man ender med å se på et
# bygg som er uker gammelt. Denne resolver stien fra xcodebuild selv.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

"$ROOT_DIR/Scripts/build_binding.sh" "$@"

APP_DIR="$(xcodebuild \
  -workspace Binding.xcworkspace \
  -scheme HAVEN \
  -destination 'platform=macOS,arch=arm64' \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')"

APP="$APP_DIR/HAVEN.app"
if [[ ! -d "$APP" ]]; then
  echo "Fant ikke $APP" >&2
  exit 1
fi

echo "App: $APP"
echo "Binær: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$APP/Contents/MacOS/HAVEN")"
pkill -f "HAVEN.app/Contents/MacOS/HAVEN" 2>/dev/null || true
sleep 1
open -n "$APP"
