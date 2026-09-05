#!/bin/zsh
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
derived_data_root="/private/tmp/haven-xcode-derived/Binding-DeviceIngress-Staging"
marker_path="${derived_data_root}/.haven-binding-derived-data.v1"
lease_path="${derived_data_root}/.haven-binding-build.lease"
minimum_available_kib=$((40 * 1024 * 1024))
minimum_available_percent=4
maximum_adoption_kib=$((32 * 1024 * 1024))
adopt_existing=0
preflight_only=0

usage() {
  print -u2 "usage: $0 [--adopt-existing-root] [--preflight-only]"
}

for argument in "$@"; do
  case "$argument" in
    --adopt-existing-root)
      adopt_existing=1
      ;;
    --preflight-only)
      preflight_only=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if [[ "$derived_data_root" != "/private/tmp/haven-xcode-derived/Binding-DeviceIngress-Staging" ]]; then
  print -u2 "refusing an unexpected DerivedData root"
  exit 65
fi

cd "$root_dir"
if [[ -n "$(git status --porcelain=v1 --untracked-files=all)" ]]; then
  print -u2 "staging candidate builds require a clean Binding source tree"
  exit 65
fi
binding_revision="$(git rev-parse --verify 'HEAD^{commit}')"
if [[ ! "$binding_revision" =~ '^[0-9a-f]{40}$' ]]; then
  print -u2 "Binding HEAD is not a full Git revision"
  exit 65
fi

disk_gate() {
  local available_kib capacity_percent available_percent
  available_kib="$(/bin/df -Pk /private/tmp | /usr/bin/awk 'NR == 2 { print $4 }')"
  capacity_percent="$(/bin/df -Pk /private/tmp | /usr/bin/awk 'NR == 2 { value=$5; gsub(/%/, "", value); print value }')"
  if [[ ! "$available_kib" =~ '^[0-9]+$' || ! "$capacity_percent" =~ '^[0-9]+$' ]]; then
    print -u2 "could not parse the data-filesystem capacity"
    return 65
  fi
  available_percent=$((100 - capacity_percent))
  print "disk.available_kib=${available_kib}"
  print "disk.available_percent=${available_percent}"
  if (( available_kib < minimum_available_kib || available_percent < minimum_available_percent )); then
    print -u2 "disk gate failed: at least 40 GiB and 4% must be available"
    return 69
  fi
}

validate_known_derived_data_children() {
  local child name
  while IFS= read -r child; do
    name="${child:t}"
    case "$name" in
      Build|CompilationCache.noindex|Index.noindex|Logs|ModuleCache.noindex|SDKStatCaches.noindex|SourcePackages|TestResults|info.plist)
        ;;
      *)
        print -u2 "refusing to adopt DerivedData with an unknown top-level child: $name"
        return 65
        ;;
    esac
  done < <(/usr/bin/find "$derived_data_root" -mindepth 1 -maxdepth 1 -print)
}

write_marker() {
  local temporary_marker
  temporary_marker="$(/usr/bin/mktemp "${marker_path}.tmp.XXXXXX")"
  /bin/chmod 600 "$temporary_marker"
  {
    print 'schema=binding-derived-data.v1'
    print 'owner=Binding/HAVEN-staging-candidate'
    print "path=${derived_data_root}"
    print "created_at_utc=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } > "$temporary_marker"
  /bin/mv -f "$temporary_marker" "$marker_path"
}

disk_gate
/bin/mkdir -p "${derived_data_root:h}"
if [[ ! -d "$derived_data_root" ]]; then
  /bin/mkdir "$derived_data_root"
  write_marker
elif [[ ! -f "$marker_path" ]]; then
  derived_size_kib="$(/usr/bin/du -sk "$derived_data_root" | /usr/bin/awk '{ print $1 }')"
  if [[ -n "$(/usr/bin/find "$derived_data_root" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    if (( ! adopt_existing )); then
      print -u2 "existing unmarked DerivedData requires --adopt-existing-root"
      exit 65
    fi
    validate_known_derived_data_children
    if (( derived_size_kib > maximum_adoption_kib )); then
      print -u2 "refusing to adopt DerivedData larger than 32 GiB"
      exit 65
    fi
  fi
  write_marker
fi

if ! /usr/bin/grep -Fxq 'schema=binding-derived-data.v1' "$marker_path" ||
   ! /usr/bin/grep -Fxq 'owner=Binding/HAVEN-staging-candidate' "$marker_path" ||
   ! /usr/bin/grep -Fxq "path=${derived_data_root}" "$marker_path"; then
  print -u2 "DerivedData ownership marker is invalid"
  exit 65
fi

if [[ -e "$lease_path" ]]; then
  lease_age_seconds=$(( $(/bin/date '+%s') - $(/usr/bin/stat -f '%m' "$lease_path") ))
  print -u2 "an existing build lease blocks this build (age_seconds=${lease_age_seconds})"
  exit 75
fi

lease_created=0
cleanup_lease() {
  if (( lease_created )); then
    /bin/rm -f -- "$lease_path"
  fi
}
trap cleanup_lease EXIT INT TERM
(
  set -o noclobber
  umask 077
  {
    print 'schema=binding-build-lease.v1'
    print "pid=$$"
    print "binding_revision=${binding_revision}"
    print "started_at_utc=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } > "$lease_path"
) 2>/dev/null || {
  print -u2 "could not acquire the build lease"
  exit 75
}
lease_created=1

before_size_kib="$(/usr/bin/du -sk "$derived_data_root" | /usr/bin/awk '{ print $1 }')"
print "derived_data.before_kib=${before_size_kib}"
print "candidate.binding_revision=${binding_revision}"
if (( preflight_only )); then
  print 'preflight=passed'
  exit 0
fi

set +e
xcodebuild \
  -workspace Binding.xcworkspace \
  -scheme HAVEN \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$derived_data_root" \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \
  build 2>&1 | /usr/bin/sed -E \
    -e 's/^([[:space:]]*Signing Identity:).*/\1 <redacted>/' \
    -e 's/^([[:space:]]*Provisioning Profile:).*/\1 <redacted>/' \
    -e 's#(/Provisioning Profiles/)[^[:space:]]+#\1<redacted>#g' \
    -e 's/--sign [0-9A-Fa-f]{40}/--sign <redacted>/g' \
    -e 's/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/<identifier-redacted>/g'
xcode_status="${pipestatus[1]}"
set -e
if (( xcode_status != 0 )); then
  print -u2 "xcodebuild failed with status ${xcode_status}"
  exit "$xcode_status"
fi

candidate_app="${derived_data_root}/Build/Products/Debug-iphoneos/HAVEN.app"
provenance_plist="${candidate_app}/BindingBuildProvenance.plist"
if [[ ! -d "$candidate_app" || ! -f "$provenance_plist" ||
      ! -f "${candidate_app}/embedded.mobileprovision" ]]; then
  print -u2 "signed staging candidate or its provenance is incomplete"
  exit 66
fi

bundle_identifier="$(/usr/bin/plutil -extract CFBundleIdentifier raw "${candidate_app}/Info.plist")"
display_name="$(/usr/bin/plutil -extract CFBundleDisplayName raw "${candidate_app}/Info.plist")"
rollout_environment="$(/usr/bin/plutil -extract HAVENDeviceIngressRolloutEnvironment raw "${candidate_app}/Info.plist")"
public_origin="$(/usr/bin/plutil -extract HAVENDeviceIngressPublicOrigin raw "${candidate_app}/Info.plist")"
audience="$(/usr/bin/plutil -extract HAVENDeviceIngressAudience raw "${candidate_app}/Info.plist")"
issuer_pin="$(/usr/bin/plutil -extract HAVENDeviceIngressChallengeIssuerBase64 raw "${candidate_app}/Info.plist")"
build_version="$(/usr/bin/plutil -extract CFBundleVersion raw "${candidate_app}/Info.plist")"
attested_revision="$(/usr/bin/plutil -extract bindingGitRevision raw "$provenance_plist")"
attested_cellprotocol_revision="$(/usr/bin/plutil -extract cellProtocolGitRevision raw "$provenance_plist")"
binding_dirty="$(/usr/bin/plutil -extract bindingSourceTreeDirty raw "$provenance_plist")"
cellprotocol_dirty="$(/usr/bin/plutil -extract cellProtocolSourceTreeDirty raw "$provenance_plist")"
signing_mode="$(/usr/bin/plutil -extract codeSigningMode raw "$provenance_plist")"
locked_cellprotocol_revision="$(/usr/bin/awk '
  /"identity" : "cellprotocol"/ { found=1 }
  found && /"revision" :/ { gsub(/[",]/, "", $3); print $3; exit }
' Binding.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)"
apns_environment="$(/usr/bin/codesign -d --entitlements :- "$candidate_app" 2>/dev/null | /usr/bin/plutil -extract aps-environment raw -)"
profile_bundle_identifier="$(/usr/bin/security cms -D -i "${candidate_app}/embedded.mobileprovision" 2>/dev/null | /usr/bin/plutil -extract Entitlements.application-identifier raw -)"
profile_bundle_identifier="${profile_bundle_identifier#*.}"
profile_apns_environment="$(/usr/bin/security cms -D -i "${candidate_app}/embedded.mobileprovision" 2>/dev/null | /usr/bin/plutil -extract Entitlements.aps-environment raw -)"

if [[ "$bundle_identifier" != 'org.digipomps.haven' ||
      "$display_name" != 'HAVEN Staging' ||
      "$rollout_environment" != 'staging' ||
      "$public_origin" != 'https://staging.haven.digipomps.org' ||
      "$audience" != 'staging.haven.digipomps.org' ||
      -z "$issuer_pin" ||
      "$attested_revision" != "$binding_revision" ||
      "$attested_cellprotocol_revision" != "$locked_cellprotocol_revision" ||
      "$binding_dirty" != 'false' || "$cellprotocol_dirty" != 'false' ||
      "$signing_mode" != 'certificate' ||
      "$apns_environment" != 'development' ||
      "$profile_bundle_identifier" != "$bundle_identifier" ||
      "$profile_apns_environment" != "$apns_environment" ]]; then
  print -u2 "candidate metadata or provenance did not satisfy the staging contract"
  exit 65
fi

if ! print -rn -- "$issuer_pin" | /usr/bin/base64 -D | /usr/bin/plutil -extract publicKey raw - >/dev/null 2>&1; then
  print -u2 "candidate issuer pin is not a base64-encoded public-key descriptor"
  exit 65
fi

/usr/bin/codesign --verify --deep --strict "$candidate_app"
executable_sha256="$(/usr/bin/shasum -a 256 "${candidate_app}/HAVEN" | /usr/bin/awk '{ print $1 }')"
provenance_sha256="$(/usr/bin/shasum -a 256 "$provenance_plist" | /usr/bin/awk '{ print $1 }')"
issuer_pin_sha256="$(print -rn -- "$issuer_pin" | /usr/bin/shasum -a 256 | /usr/bin/awk '{ print $1 }')"
after_size_kib="$(/usr/bin/du -sk "$derived_data_root" | /usr/bin/awk '{ print $1 }')"
print "candidate.bundle_identifier=${bundle_identifier}"
print "candidate.display_name=${display_name}"
print "candidate.build_version=${build_version}"
print "candidate.rollout_environment=${rollout_environment}"
print "candidate.public_origin=${public_origin}"
print "candidate.audience=${audience}"
print "candidate.issuer_pin_sha256=${issuer_pin_sha256}"
print "candidate.apns_environment=${apns_environment}"
print "candidate.cellprotocol_revision=${attested_cellprotocol_revision}"
print "candidate.executable_sha256=${executable_sha256}"
print "candidate.provenance_sha256=${provenance_sha256}"
print 'candidate.signature=verified'
print 'candidate.embedded_profile=compatible'
print "derived_data.after_kib=${after_size_kib}"
disk_gate
print 'candidate=passed'
