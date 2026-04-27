#!/bin/zsh
set -euo pipefail

APP_BINARY="${BINDING_APP_BINARY:-/Users/kjetil/Library/Developer/Xcode/DerivedData/Binding-erntjstdfcrbeachccbemadrrbon/Build/Products/Debug/Binding.app/Contents/MacOS/Binding}"
OUT_DIR="${1:-/tmp/binding-conference-smoke-$(date +%Y%m%d-%H%M%S)}"
APP_NAME="Binding"
AUTOMATION_MENU="Conference Automation"
MODULE_CACHE_DIR="${BINDING_MODULE_CACHE_DIR:-$OUT_DIR/clang-module-cache}"

mkdir -p "$OUT_DIR"
mkdir -p "$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"

if [[ ! -x "$APP_BINARY" ]]; then
  echo "Binding binary not found or not executable: $APP_BINARY" >&2
  exit 66
fi

window_id() {
  local target_pid="$1"
  swift -e "import Cocoa; let targetPID = $target_pid; let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []; for info in infos { if let owner = info[kCGWindowOwnerName as String] as? String, owner == \"Binding\", let pid = info[kCGWindowOwnerPID as String] as? Int, pid == targetPID, let id = info[kCGWindowNumber as String] as? Int { print(id); break } }"
}

window_bounds() {
  local target_pid="$1"
  swift -e "import Cocoa
let targetPID = $target_pid
let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for info in infos {
  guard let owner = info[kCGWindowOwnerName as String] as? String, owner == \"Binding\" else { continue }
  let pid = info[kCGWindowOwnerPID as String] as? Int ?? -1
  guard pid == targetPID else { continue }
  let layer = info[kCGWindowLayer as String] as? Int ?? -1
  guard layer == 0 else { continue }
  let bounds = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
  let x = Int((bounds[\"X\"] as? Double) ?? (bounds[\"X\"] as? Int).map(Double.init) ?? -1)
  let y = Int((bounds[\"Y\"] as? Double) ?? (bounds[\"Y\"] as? Int).map(Double.init) ?? -1)
  let width = Int((bounds[\"Width\"] as? Double) ?? (bounds[\"Width\"] as? Int).map(Double.init) ?? -1)
  let height = Int((bounds[\"Height\"] as? Double) ?? (bounds[\"Height\"] as? Int).map(Double.init) ?? -1)
  if x >= 0 && y >= 0 && width > 0 && height > 0 {
    print(\"\\(x),\\(y),\\(width),\\(height)\")
    break
  }
}"
}

wait_for_window() {
  local target_pid="$1"
  local attempts="${2:-30}"
  local id=""
  for _ in $(seq 1 "$attempts"); do
    id="$(window_id "$target_pid" || true)"
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
  local target_pid="$1"
  local attempts="${2:-30}"
  local items=""
  for _ in $(seq 1 "$attempts"); do
    items="$(osascript \
      -e "tell application \"$APP_NAME\" to activate" \
      -e "tell application \"System Events\" to tell (first process whose unix id is $target_pid) to get name of every menu bar item of menu bar 1" 2>/dev/null || true)"
    if [[ "$items" == *"$AUTOMATION_MENU"* ]]; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for Conference Automation menu" >&2
  return 1
}

capture_step() {
  local target_pid="$1"
  local label="$2"
  local step_index="$3"
  local id
  id="$(wait_for_window "$target_pid" 10)"
  local filename
  filename=$(printf "%02d-%s.png" "$step_index" "$label")
  local filepath="$OUT_DIR/$filename"
  local capture_mode="window"
  local bounds=""

  if ! screencapture -x -l "$id" "$filepath" 2>/dev/null; then
    bounds="$(window_bounds "$target_pid" || true)"
    if [[ -n "$bounds" ]]; then
      capture_mode="region"
      if ! screencapture -x -R "$bounds" "$filepath" 2>/dev/null; then
        capture_mode="fullscreen"
        screencapture -x "$filepath"
      fi
    else
      capture_mode="fullscreen"
      screencapture -x "$filepath"
    fi
  fi

  printf '| %s | `%s` (%s) |\n' "$label" "$filepath" "$capture_mode" >> "$OUT_DIR/report.md"
}

run_menu_action() {
  local target_pid="$1"
  local item="$2"
  local delay_seconds="${3:-1.2}"
  osascript \
    -e "tell application \"$APP_NAME\" to activate" \
    -e "tell application \"System Events\" to tell (first process whose unix id is $target_pid) to click menu bar item \"$AUTOMATION_MENU\" of menu bar 1" \
    -e 'delay 0.2' \
    -e "tell application \"System Events\" to tell (first process whose unix id is $target_pid) to click menu item \"$item\" of menu 1 of menu bar item \"$AUTOMATION_MENU\" of menu bar 1" \
    -e "delay $delay_seconds" >/dev/null
}

echo "# Conference Demo Smoke Report" > "$OUT_DIR/report.md"
echo >> "$OUT_DIR/report.md"
echo "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$OUT_DIR/report.md"
echo "- App binary: \`$APP_BINARY\`" >> "$OUT_DIR/report.md"
echo "- Output dir: \`$OUT_DIR\`" >> "$OUT_DIR/report.md"

osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
pkill -f "$APP_BINARY" 2>/dev/null || true
sleep 1

nohup "$APP_BINARY" --enable-conference-automation >"$OUT_DIR/binding.log" 2>&1 &
APP_PID="$!"
echo "- Launch PID: \`$APP_PID\`" >> "$OUT_DIR/report.md"
echo >> "$OUT_DIR/report.md"
echo "| Step | Screenshot |" >> "$OUT_DIR/report.md"
echo "| --- | --- |" >> "$OUT_DIR/report.md"

wait_for_window "$APP_PID" 40 >/dev/null
wait_for_automation_menu "$APP_PID" 40

run_menu_action "$APP_PID" "Viewport: Tall 900 × 1100"
capture_step "$APP_PID" "launcher" 1

run_menu_action "$APP_PID" "Open Conference Participant Portal"
capture_step "$APP_PID" "participant-portal" 2

run_menu_action "$APP_PID" "Focus Ane Solberg"
run_menu_action "$APP_PID" "Start chat with focused participant"
capture_step "$APP_PID" "participant-portal-chat-ready" 3

run_menu_action "$APP_PID" "Open focused chat workbench"
capture_step "$APP_PID" "chat-workbench" 4

run_menu_action "$APP_PID" "Open Conference Public Surface" 20.0
capture_step "$APP_PID" "public-surface" 5

run_menu_action "$APP_PID" "Open Conference Control Tower"
capture_step "$APP_PID" "control-tower" 6

run_menu_action "$APP_PID" "Open Conference AI Assistant" 30.0
capture_step "$APP_PID" "ai-assistant" 7

run_menu_action "$APP_PID" "Open Conference Scaffold Setup & Identity Link"
capture_step "$APP_PID" "identity-link" 8

echo >> "$OUT_DIR/report.md"
echo "- Binding log: \`$OUT_DIR/binding.log\`" >> "$OUT_DIR/report.md"

echo "Conference demo smoke run complete."
echo "Report: $OUT_DIR/report.md"
