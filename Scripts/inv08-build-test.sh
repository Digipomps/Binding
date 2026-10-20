#!/bin/bash
set -euo pipefail
ulimit -S -f unlimited
haven_root="${HAVEN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
repo="$haven_root/_worktrees/inv-binding-push-20261008"
evidence="$haven_root/HAVEN-Deploy/_handoff/INVITE-CHAT/inv08"
guard="$haven_root/_worktrees/inv-push-20261008/scripts/check_build_capacity.sh"
if [[ "${1:-}" == "self-test" ]]; then
  /bin/bash -n "$0"
  [[ -d "$repo" && -f "$guard" ]]
  /usr/bin/git -C "$repo" diff --check
  exit 0
fi
cd "$repo"
/usr/bin/git merge-base --is-ancestor b77b5603245779047f92727c7cd1908b6a62d36d HEAD
/bin/mkdir -p "$evidence"
[[ -z "$(/usr/bin/git status --porcelain)" ]]
/usr/bin/git rev-parse HEAD > "$evidence/REQUESTED-SHA"
if ! /bin/bash "$guard" "$repo" > "$evidence/CAPACITY.log" 2>&1; then
  /bin/cat "$evidence/CAPACITY.log"
  printf 'capacity-blocked\n' > "$evidence/PORT-STATUS"
  exit 75
fi
/usr/bin/xcodebuild -version > "$evidence/XCODE-VERSION.txt"
/usr/bin/python3 scripts/prepare_binding_provenance_inputs.py
/usr/bin/xcrun simctl list devices available -j > "$evidence/SIMULATORS.json"
simulator_id="$(/usr/bin/python3 - "$evidence/SIMULATORS.json" <<'PYTHON'
import json,sys
obj=json.load(open(sys.argv[1]))
# XCTest realizes linked ObjC classes, including the iOS 27 CellApple
# FoundationModels metadata, before selected tests begin.
import re
candidates=[]
for runtime,group in obj['devices'].items():
    match=re.search(r'\.iOS-(\d+)-(\d+)', runtime)
    if not match: continue
    version=tuple(map(int,match.groups()))
    if version < (27,0): continue
    candidates.extend((version,d) for d in group
                      if d.get('isAvailable') and 'iPhone' in d['name'])
if not candidates:
    sys.exit('No available iPhone simulator with iOS >= 27.0; required by linked CellApple metadata')
candidates.sort(key=lambda item:(item[0],item[1]['state']=='Booted',item[1]['udid']), reverse=True)
print(candidates[0][1]['udid'])
PYTHON
)"
common=(-project Binding.xcodeproj -scheme HAVEN -derivedDataPath /private/tmp/inv08-binding-derived -clonedSourcePackagesDirPath /private/tmp/inv08-binding-derived/SourcePackages -onlyUsePackageVersionsFromResolvedFile -jobs 2 CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=17.0 ARCHS=arm64 ONLY_ACTIVE_ARCH=YES)
# Separate process group and bounded wall time, with direct log draining.
run_bounded() {
  /usr/bin/python3 - "$@" <<'PYTHON'
import subprocess,os,signal,sys
p=subprocess.Popen(sys.argv[1:], start_new_session=True)
try:
    code=p.wait(timeout=2100)
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGTERM)
    try: p.wait(timeout=20)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        p.wait()
    code=124
sys.exit(code)
PYTHON
}
set +e
run_bounded /usr/bin/xcodebuild "${common[@]}" -destination 'generic/platform=iOS Simulator' build > "$evidence/IOS-BUILD-HOST.log" 2>&1
build_status=$?
set -e
printf '%s\n' "$build_status" > "$evidence/BUILD-EXIT"
[[ "$build_status" == 0 ]] || { /usr/bin/tail -n 40 "$evidence/IOS-BUILD-HOST.log"; exit "$build_status"; }
/bin/bash "$guard" "$repo" >> "$evidence/CAPACITY.log" 2>&1
set +e
run_bounded /usr/bin/xcodebuild "${common[@]}" -destination "platform=iOS Simulator,id=$simulator_id" -parallel-testing-enabled NO \
  -only-testing:BindingTests/NotificationEnrollmentManagerTests \
  -only-testing:BindingTests/NotificationCallbackClientTests \
  -only-testing:BindingTests/DeviceIngressRegistrationClientTests \
  -only-testing:BindingTests/ChatWorkbenchParityTests/notificationThreadSelectionPreservesScopeAndRejectsUnknownThread \
  test > "$evidence/IOS-TESTS-HOST.log" 2>&1
test_status=$?
set -e
printf '%s\n' "$test_status" > "$evidence/TEST-EXIT"
/usr/bin/tail -n 40 "$evidence/IOS-TESTS-HOST.log"
[[ "$test_status" == 0 ]] || exit "$test_status"
/usr/bin/git diff --exit-code -- Binding BindingTests Binding.xcodeproj
/bin/cp "$evidence/REQUESTED-SHA" "$evidence/TESTED-SHA"
/bin/cp "$evidence/TESTED-SHA" "$evidence/GREEN-SHA"
printf 'green\n' > "$evidence/PORT-STATUS"
