#!/bin/zsh
set -euo pipefail

APP_BINARY="${BINDING_APP_BINARY:-/Users/kjetil/Library/Developer/Xcode/DerivedData/Binding-erntjstdfcrbeachccbemadrrbon/Build/Products/Debug/Binding.app/Contents/MacOS/Binding}"
OUT_DIR="${1:-/tmp/binding-conference-smoke-$(date +%Y%m%d-%H%M%S)}"
APP_NAME="Binding"
AUTOMATION_MENU="Conference Automation"

mkdir -p "$OUT_DIR"

if [[ ! -x "$APP_BINARY" ]]; then
  echo "Binding binary not found or not executable: $APP_BINARY" >&2
  exit 66
fi

window_id() {
  swift -e 'import Cocoa; let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []; for info in infos { if let owner = info[kCGWindowOwnerName as String] as? String, owner == "Binding", let id = info[kCGWindowNumber as String] as? Int { print(id); break } }'
}

wait_for_window() {
  local attempts="${1:-30}"
  local id=""
  for _ in $(seq 1 "$attempts"); do
    id="$(window_id || true)"
    if [[ -n "$id" ]]; then
      echo "$id"
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for Binding window" >&2
  return 1
}

wait_for_automation_menu() {
  local attempts="${1:-30}"
  local items=""
  for _ in $(seq 1 "$attempts"); do
    items="$(osascript \
      -e "tell application \"$APP_NAME\" to activate" \
      -e "tell application \"System Events\" to tell process \"$APP_NAME\" to get name of every menu bar item of menu bar 1" 2>/dev/null || true)"
    if [[ "$items" == *"$AUTOMATION_MENU"* ]]; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for Conference Automation menu" >&2
  return 1
}

capture_step() {
  local label="$1"
  local step_index="$2"
  local id
  id="$(wait_for_window 10)"
  local filename
  filename=$(printf "%02d-%s.png" "$step_index" "$label")
  screencapture -x -l "$id" "$OUT_DIR/$filename"
  printf '| %s | `%s` |\n' "$label" "$OUT_DIR/$filename" >> "$OUT_DIR/report.md"
}

run_menu_action() {
  local item="$1"
  local delay_seconds="${2:-1.2}"
  osascript \
    -e "tell application \"$APP_NAME\" to activate" \
    -e "tell application \"System Events\" to tell process \"$APP_NAME\" to click menu bar item \"$AUTOMATION_MENU\" of menu bar 1" \
    -e 'delay 0.2' \
    -e "tell application \"System Events\" to tell process \"$APP_NAME\" to click menu item \"$item\" of menu 1 of menu bar item \"$AUTOMATION_MENU\" of menu bar 1" \
    -e "delay $delay_seconds" >/dev/null
}

echo "# Conference Demo Smoke Report" > "$OUT_DIR/report.md"
echo >> "$OUT_DIR/report.md"
echo "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$OUT_DIR/report.md"
echo "- App binary: \`$APP_BINARY\`" >> "$OUT_DIR/report.md"
echo "- Output dir: \`$OUT_DIR\`" >> "$OUT_DIR/report.md"

pkill -f "$APP_BINARY" 2>/dev/null || true
sleep 1

nohup "$APP_BINARY" --enable-conference-automation >"$OUT_DIR/binding.log" 2>&1 &
APP_PID="$!"
echo "- Launch PID: \`$APP_PID\`" >> "$OUT_DIR/report.md"
echo >> "$OUT_DIR/report.md"
echo "| Step | Screenshot |" >> "$OUT_DIR/report.md"
echo "| --- | --- |" >> "$OUT_DIR/report.md"

wait_for_window 40 >/dev/null
wait_for_automation_menu 40

run_menu_action "Viewport: Tall 900 × 1100"
capture_step "launcher" 1

run_menu_action "Open Conference Participant Portal"
capture_step "participant-portal" 2

run_menu_action "Focus Ane Solberg"
run_menu_action "Start chat with focused participant"
capture_step "participant-portal-chat-ready" 3

run_menu_action "Open focused chat workbench"
capture_step "chat-workbench" 4

run_menu_action "Open Conference Public Surface" 20.0
capture_step "public-surface" 5

run_menu_action "Open Conference Control Tower"
capture_step "control-tower" 6

run_menu_action "Open Conference AI Assistant" 30.0
capture_step "ai-assistant" 7

run_menu_action "Open Conference Scaffold Setup & Identity Link"
capture_step "identity-link" 8

echo >> "$OUT_DIR/report.md"
echo "- Binding log: \`$OUT_DIR/binding.log\`" >> "$OUT_DIR/report.md"

echo "Conference demo smoke run complete."
echo "Report: $OUT_DIR/report.md"
