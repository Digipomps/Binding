#!/bin/zsh
set -euo pipefail

APP_BINARY="${HAVEN_APP_BINARY:-${BINDING_APP_BINARY:-/Users/kjetil/Library/Developer/Xcode/DerivedData/Binding-erntjstdfcrbeachccbemadrrbon/Build/Products/Debug/HAVEN.app/Contents/MacOS/HAVEN}}"
OUT_DIR="${1:-/tmp/binding-conference-smoke-$(date +%Y%m%d-%H%M%S)}"
APP_NAME="HAVEN"
AUTOMATION_MENU="Conference Automation"
MODULE_CACHE_DIR="${BINDING_MODULE_CACHE_DIR:-$OUT_DIR/clang-module-cache}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${BINDING_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AGENT_BUILD_BINARY="${BINDING_HAVEN_AGENTD_BINARY:-$REPO_ROOT/HavenAgentD/.build/debug/haven-agentd}"
AGENT_ALT_BUILD_BINARY="${BINDING_HAVEN_AGENTD_ALT_BINARY:-$REPO_ROOT/HavenAgentD/.build/arm64-apple-macosx/debug/haven-agentd}"
AGENT_STAGING_DIR="${BINDING_AGENT_STAGING_DIR:-$HOME/Library/Application Support/HAVENAgent/Staging}"
AGENT_ROOT="${BINDING_AGENT_ROOT:-$HOME/Library/Application Support/HAVENAgent}"
AGENT_CONFIG_FILE="$AGENT_ROOT/config.json"
AGENT_INSTALLED_BINARY="$AGENT_ROOT/bin/haven-agentd"
AGENT_STAGING_BINARY="$AGENT_STAGING_DIR/haven-agentd"
SPROUT_BUILD_BINARY="${BINDING_SPROUT_BINARY:-$REPO_ROOT/../sprout/.build/debug/sprout}"
SPROUT_ALT_BUILD_BINARY="${BINDING_SPROUT_ALT_BINARY:-$REPO_ROOT/../sprout/.build/arm64-apple-macosx/debug/sprout}"
SPROUT_RELEASE_BINARY="${BINDING_SPROUT_RELEASE_BINARY:-$REPO_ROOT/../sprout/.build/arm64-apple-macosx/release/sprout}"
SPROUT_STAGING_BINARY="$AGENT_STAGING_DIR/sprout"

mkdir -p "$OUT_DIR"
mkdir -p "$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"

if [[ ! -x "$APP_BINARY" ]]; then
  echo "HAVEN binary not found or not executable: $APP_BINARY" >&2
  exit 66
fi

window_id() {
  local target_pid="$1"
  swift -e "import Cocoa; let targetPID = $target_pid; let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []; for info in infos { let pid = info[kCGWindowOwnerPID as String] as? Int ?? -1; let layer = info[kCGWindowLayer as String] as? Int ?? -1; guard pid == targetPID && layer == 0 else { continue }; guard let id = info[kCGWindowNumber as String] as? Int else { continue }; print(id); break }"
}

window_bounds() {
  local target_pid="$1"
  swift -e "import Cocoa
let targetPID = $target_pid
let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for info in infos {
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
  echo "Timed out waiting for HAVEN window" >&2
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

run_menu_action_async() {
  local target_pid="$1"
  local item="$2"
  osascript \
    -e "tell application \"$APP_NAME\" to activate" \
    -e "tell application \"System Events\" to tell (first process whose unix id is $target_pid) to click menu bar item \"$AUTOMATION_MENU\" of menu bar 1" \
    -e 'delay 0.2' \
    -e "tell application \"System Events\" to tell (first process whose unix id is $target_pid) to click menu item \"$item\" of menu 1 of menu bar item \"$AUTOMATION_MENU\" of menu bar 1" >/dev/null &
}

approve_runtime_access_if_needed() {
  local target_pid="$1"
  local attempts="${2:-12}"
  local result=""
  local clicked_any="0"

  for _ in $(seq 1 "$attempts"); do
    result="$(osascript \
      -e "tell application \"$APP_NAME\" to activate" \
      -e "tell application \"System Events\" to tell (first process whose unix id is $target_pid)
            repeat with candidateWindow in windows
              try
                if exists button \"Grant Access\" of candidateWindow then
                  click button \"Grant Access\" of candidateWindow
                  return \"accepted\"
                end if
              end try
              try
                if exists sheet 1 of candidateWindow then
                  if exists button \"Grant Access\" of sheet 1 of candidateWindow then
                    click button \"Grant Access\" of sheet 1 of candidateWindow
                    return \"accepted\"
                  end if
                end if
              end try
              try
                repeat with candidateElement in entire contents of candidateWindow
                  try
                    if role of candidateElement is \"AXButton\" and name of candidateElement is \"Grant Access\" then
                      click candidateElement
                      return \"accepted\"
                    end if
                  end try
                end repeat
              end try
              try
                if (description of candidateWindow contains \"dialog\") or (name of candidateWindow contains \"access\") then
                  key code 36
                  return \"accepted-return\"
                end if
              end try
            end repeat
            return \"waiting\"
          end tell" 2>/dev/null || true)"
    if [[ "$result" == *"accepted"* ]]; then
      clicked_any="1"
      sleep 2
      continue
    fi
    if [[ "$clicked_any" == "1" ]]; then
      sleep 1
      continue
    fi
    sleep 1
  done

  return 0
}

validate_capture_hashes() {
  typeset -A seen_hashes=()
  local capture_count=0
  local image hash

  for image in "$OUT_DIR"/*.png; do
    [[ -e "$image" ]] || continue
    hash="$(md5 -q "$image")"
    seen_hashes["$hash"]=1
    (( capture_count += 1 ))
  done

  if (( capture_count == 0 )); then
    echo "- Screenshot validation: failed (no captures produced)." >> "$OUT_DIR/report.md"
    echo "Smoke capture validation failed: no screenshots were produced." >&2
    return 1
  fi

  local unique_hash_count="${#seen_hashes}"
  echo "- Screenshot validation: ${unique_hash_count} unique hash(es) across ${capture_count} capture(s)." >> "$OUT_DIR/report.md"

  if (( unique_hash_count <= 1 )); then
    echo "Smoke capture validation failed: all screenshots were identical. Screen capture likely returned blank or blocked frames." >&2
    return 1
  fi
}

validate_agent_progression() {
  local installed="$OUT_DIR/12-agent-installed.png"
  local connected="$OUT_DIR/13-agent-connected.png"
  local approved="$OUT_DIR/14-agent-review-approved.png"

  if [[ ! -f "$installed" || ! -f "$connected" || ! -f "$approved" ]]; then
    echo "- Agent progression validation: skipped (agent screenshots missing)." >> "$OUT_DIR/report.md"
    return 0
  fi

  local installed_hash connected_hash approved_hash
  installed_hash="$(md5 -q "$installed")"
  connected_hash="$(md5 -q "$connected")"
  approved_hash="$(md5 -q "$approved")"

  if [[ "$installed_hash" == "$connected_hash" && "$connected_hash" == "$approved_hash" ]]; then
    echo "- Agent progression validation: failed (agent install/connect/review captures were identical)." >> "$OUT_DIR/report.md"
    echo "Smoke capture validation failed: agent install/connect/review screenshots were identical. Runtime access may still be blocked by an approval dialog." >&2
    return 1
  fi

  echo "- Agent progression validation: passed." >> "$OUT_DIR/report.md"
}

validate_agent_runtime_state() {
  local state_file="$AGENT_ROOT/State/agent-state.json"
  local config_file="$AGENT_CONFIG_FILE"

  if [[ ! -f "$config_file" ]]; then
    echo "- Agent runtime validation: failed (missing config.json)." >> "$OUT_DIR/report.md"
    echo "Agent runtime validation failed: missing $config_file" >&2
    return 1
  fi

  local sprout_path
  sprout_path="$(plutil -extract scaffold.sproutBinaryPath raw -o - "$config_file" 2>/dev/null || true)"
  if [[ -z "$sprout_path" || ! -x "$sprout_path" ]]; then
    echo "- Agent runtime validation: failed (sprout binary is not executable: ${sprout_path:-missing})." >> "$OUT_DIR/report.md"
    echo "Agent runtime validation failed: sprout binary is not executable: ${sprout_path:-missing}" >&2
    return 1
  fi

  if [[ ! -f "$state_file" ]]; then
    echo "- Agent runtime validation: failed (missing agent-state.json)." >> "$OUT_DIR/report.md"
    echo "Agent runtime validation failed: missing $state_file" >&2
    return 1
  fi

  local phase last_error
  phase="$(plutil -extract portholeIngress.phase raw -o - "$state_file" 2>/dev/null || true)"
  last_error="$(plutil -extract portholeIngress.lastError raw -o - "$state_file" 2>/dev/null || true)"
  if [[ "$phase" != "connected" ]]; then
    if [[ "$last_error" == *"error: expired"* ]]; then
      echo "- Agent runtime validation: failed (staging bridge/porthole contract is expired)." >> "$OUT_DIR/report.md"
      echo "Agent runtime validation failed: staging bridge/porthole contract is expired. Refresh staging scaffold bridge descriptors before expecting portholeIngress.phase=connected." >&2
      return 1
    fi
    echo "- Agent runtime validation: failed (porthole phase: ${phase:-missing})." >> "$OUT_DIR/report.md"
    echo "Agent runtime validation failed: expected portholeIngress.phase=connected, got ${phase:-missing}. ${last_error}" >&2
    return 1
  fi

  echo "- Agent runtime validation: passed (sprout: \`$sprout_path\`, porthole phase: connected)." >> "$OUT_DIR/report.md"
}

refresh_starter_auth_if_possible() {
  local refresh_binary=""
  if [[ -x "$AGENT_INSTALLED_BINARY" ]]; then
    refresh_binary="$AGENT_INSTALLED_BINARY"
  elif [[ -x "$AGENT_STAGING_BINARY" ]]; then
    refresh_binary="$AGENT_STAGING_BINARY"
  fi

  if [[ -z "$refresh_binary" ]]; then
    echo "- Starter auth refresh: failed (haven-agentd binary is not executable)." >> "$OUT_DIR/report.md"
    echo "Starter auth refresh failed: haven-agentd binary is not executable." >&2
    return 1
  fi

  if [[ ! -f "$AGENT_CONFIG_FILE" ]]; then
    echo "- Starter auth refresh: failed (missing config at $AGENT_CONFIG_FILE)." >> "$OUT_DIR/report.md"
    echo "Starter auth refresh failed: missing $AGENT_CONFIG_FILE" >&2
    return 1
  fi

  if "$refresh_binary" refresh-starter-auth --config "$AGENT_CONFIG_FILE" --ttl-seconds 3600 >"$OUT_DIR/starter-auth-refresh.json" 2>"$OUT_DIR/starter-auth-refresh.err"; then
    local expires_at
    expires_at="$(plutil -extract expiresAt raw -o - "$OUT_DIR/starter-auth-refresh.json" 2>/dev/null || true)"
    echo "- Starter auth refresh: passed (expires: ${expires_at:-unknown}; summary: \`$OUT_DIR/starter-auth-refresh.json\`)." >> "$OUT_DIR/report.md"
    return 0
  fi

  echo "- Starter auth refresh: failed (see \`$OUT_DIR/starter-auth-refresh.err\`)." >> "$OUT_DIR/report.md"
  echo "Starter auth refresh failed; see $OUT_DIR/starter-auth-refresh.err" >&2
  return 1
}

stage_agent_binary() {
  local source_binary=""

  if [[ -x "$AGENT_BUILD_BINARY" ]]; then
    source_binary="$AGENT_BUILD_BINARY"
  elif [[ -x "$AGENT_ALT_BUILD_BINARY" ]]; then
    source_binary="$AGENT_ALT_BUILD_BINARY"
  fi

  if [[ -n "$source_binary" ]]; then
    mkdir -p "$AGENT_STAGING_DIR"
    cp -f "$source_binary" "$AGENT_STAGING_BINARY"
    chmod 755 "$AGENT_STAGING_BINARY"
    echo "- Agent staging binary: \`$AGENT_STAGING_BINARY\` (from \`$source_binary\`)" >> "$OUT_DIR/report.md"
    return 0
  fi

  if [[ -x "$AGENT_STAGING_BINARY" ]]; then
    echo "- Agent staging binary: reusing existing \`$AGENT_STAGING_BINARY\`" >> "$OUT_DIR/report.md"
    return 0
  fi

  echo "- Agent staging binary: unavailable (no built haven-agentd found)." >> "$OUT_DIR/report.md"
}

stage_sprout_binary() {
  local source_binary=""

  if [[ -x "$SPROUT_BUILD_BINARY" ]]; then
    source_binary="$SPROUT_BUILD_BINARY"
  elif [[ -x "$SPROUT_ALT_BUILD_BINARY" ]]; then
    source_binary="$SPROUT_ALT_BUILD_BINARY"
  elif [[ -x "$SPROUT_RELEASE_BINARY" ]]; then
    source_binary="$SPROUT_RELEASE_BINARY"
  fi

  if [[ -n "$source_binary" ]]; then
    mkdir -p "$AGENT_STAGING_DIR"
    cp -f "$source_binary" "$SPROUT_STAGING_BINARY"
    chmod 755 "$SPROUT_STAGING_BINARY"
    echo "- Sprout staging binary: \`$SPROUT_STAGING_BINARY\` (from \`$source_binary\`)" >> "$OUT_DIR/report.md"
    return 0
  fi

  if [[ -x "$SPROUT_STAGING_BINARY" ]]; then
    echo "- Sprout staging binary: reusing existing \`$SPROUT_STAGING_BINARY\`" >> "$OUT_DIR/report.md"
    return 0
  fi

  echo "- Sprout staging binary: unavailable (no built sprout found)." >> "$OUT_DIR/report.md"
}

echo "# Conference Demo Smoke Report" > "$OUT_DIR/report.md"
echo >> "$OUT_DIR/report.md"
echo "- Date: $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$OUT_DIR/report.md"
echo "- App binary: \`$APP_BINARY\`" >> "$OUT_DIR/report.md"
echo "- Output dir: \`$OUT_DIR\`" >> "$OUT_DIR/report.md"
stage_agent_binary
stage_sprout_binary

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

run_menu_action "$APP_PID" "Open Conference Sponsor Follow-up" 20.0
capture_step "$APP_PID" "sponsor-follow-up" 7

run_menu_action "$APP_PID" "Open Conference MVP" 20.0
capture_step "$APP_PID" "conference-mvp" 8

run_menu_action "$APP_PID" "Open Conference AI Assistant" 30.0
capture_step "$APP_PID" "ai-assistant" 9

run_menu_action "$APP_PID" "Open Conference Scaffold Setup & Identity Link"
capture_step "$APP_PID" "identity-link" 10

run_menu_action "$APP_PID" "Open Agent Setup Workbench" 4.0
capture_step "$APP_PID" "agent-setup" 11

run_menu_action "$APP_PID" "Stop HAVENAgentD" 3.0
run_menu_action_async "$APP_PID" "Install HAVENAgentD"
sleep 1
approve_runtime_access_if_needed "$APP_PID" 20
sleep 23
capture_step "$APP_PID" "agent-installed" 12
refresh_starter_auth_if_possible

run_menu_action "$APP_PID" "Start HAVENAgentD" 8.0
run_menu_action "$APP_PID" "Run HAVENAgentD Once" 10.0
approve_runtime_access_if_needed "$APP_PID" 20
capture_step "$APP_PID" "agent-connected" 13

run_menu_action "$APP_PID" "Queue Agent Safari Review" 5.0
run_menu_action "$APP_PID" "Approve Agent Review" 5.0
capture_step "$APP_PID" "agent-review-approved" 14

echo >> "$OUT_DIR/report.md"
echo "- HAVEN log: \`$OUT_DIR/binding.log\`" >> "$OUT_DIR/report.md"

validation_status=0
validate_capture_hashes || validation_status=1
validate_agent_progression || validation_status=1
validate_agent_runtime_state || validation_status=1
if (( validation_status != 0 )); then
  exit "$validation_status"
fi

echo "Conference demo smoke run complete."
echo "Report: $OUT_DIR/report.md"
