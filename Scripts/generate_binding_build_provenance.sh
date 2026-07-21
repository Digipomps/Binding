#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
  print -u2 "usage: $0 OUTPUT_PROVENANCE_PLIST OUTPUT_COMPILER_INPUT_MANIFEST"
  exit 64
fi

root_dir="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cellprotocol_dir="${root_dir}/../CellProtocol"
output_plist="$1"
output_manifest="$2"
git_bin="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}/usr/bin/git"
swiftc_bin="${TOOLCHAIN_DIR:?TOOLCHAIN_DIR is required}/usr/bin/swiftc"
typeset -a configured_architectures
configured_architectures=(${=ARCHS:-})
if [[ ${#configured_architectures[@]} -ne 1 ]]; then
  print -u2 "build attestation currently requires exactly one architecture; got: ${ARCHS:-none}"
  exit 65
fi
attested_arch="${configured_architectures[1]}"
if [[ -n "${CURRENT_ARCH:-}" && "${CURRENT_ARCH}" != "undefined_arch" &&
      "${CURRENT_ARCH}" != "$attested_arch" ]]; then
  print -u2 "CURRENT_ARCH does not match the sole configured architecture"
  exit 65
fi
swift_file_list="${OBJECT_FILE_DIR_normal:?OBJECT_FILE_DIR_normal is required}/${attested_arch}/${PRODUCT_NAME:?PRODUCT_NAME is required}.SwiftFileList"
link_file_list="${OBJECT_FILE_DIR_normal}/${attested_arch}/${PRODUCT_NAME}.LinkFileList"
binding_module="${OBJECT_FILE_DIR_normal}/${attested_arch}/${PRODUCT_MODULE_NAME:?PRODUCT_MODULE_NAME is required}.swiftmodule"
cellbase_artifact="${BUILT_PRODUCTS_DIR:?BUILT_PRODUCTS_DIR is required}/CellBase.o"
cellapple_artifact="${BUILT_PRODUCTS_DIR}/CellApple.o"

for required in \
  "$git_bin" \
  "$swiftc_bin" \
  "$swift_file_list" \
  "$link_file_list" \
  "$binding_module" \
  "$cellbase_artifact" \
  "$cellapple_artifact" \
  "${SDKROOT:?SDKROOT is required}/SDKSettings.plist" \
  "${PROJECT_FILE_PATH:?PROJECT_FILE_PATH is required}/project.pbxproj"; do
  if [[ ! -f "$required" && ! -x "$required" ]]; then
    print -u2 "required build-attestation input is missing: $required"
    exit 66
  fi
done

if [[ ! -d "$cellprotocol_dir" ]]; then
  print -u2 "CellProtocol sibling is missing: $cellprotocol_dir"
  exit 66
fi

sha256_file() {
  /usr/bin/shasum -a 256 -- "$1" | /usr/bin/awk '{print $1}'
}

reject_control_text() {
  local label="$1"
  local value="$2"
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *$'\t'* ]]; then
    print -u2 "$label contains a forbidden control character"
    return 1
  fi
}

git_revision() {
  local repo="$1"
  local revision
  revision="$("$git_bin" -C "$repo" rev-parse --verify 'HEAD^{commit}')"
  if [[ ! "$revision" =~ '^[0-9a-f]{40}([0-9a-f]{24})?$' ]]; then
    print -u2 "invalid git revision for $repo"
    return 1
  fi
  print -r -- "$revision"
}

logical_compiler_path() {
  local path="$1"
  case "$path" in
    "$root_dir"/*)
      print -r -- "binding:${path#${root_dir}/}"
      ;;
    "${TARGET_TEMP_DIR:?TARGET_TEMP_DIR is required}/DerivedSources"/*)
      print -r -- "generated:${path#${TARGET_TEMP_DIR}/DerivedSources/}"
      ;;
    *)
      print -u2 "unallowlisted HAVEN compiler input: $path"
      return 1
      ;;
  esac
}

manifest_dir="$(/usr/bin/dirname "$output_manifest")"
plist_dir="$(/usr/bin/dirname "$output_plist")"
/bin/mkdir -p "$manifest_dir" "$plist_dir"
temporary_manifest="${output_manifest}.tmp.$$"
temporary_unsorted="${output_manifest}.unsorted.$$"
temporary_config="${output_manifest}.config.$$"
temporary_plist="${output_plist}.tmp.$$"
trap '/bin/rm -f "$temporary_manifest" "$temporary_unsorted" "$temporary_config" "$temporary_plist"' EXIT

: > "$temporary_unsorted"
: > "$temporary_config"
print -r -- $'schema\tbinding.compiler-input-attestation.v3' >> "$temporary_unsorted"
print -r -- $'coverage\txcode-swift-file-list+fs-synchronized-root-inventory+generated-swift+linked-cellprotocol-artifacts+declared-build-settings' >> "$temporary_unsorted"

typeset -A compiler_sources
compiler_input_count=0
generated_input_count=0
while IFS= read -r compiler_path || [[ -n "$compiler_path" ]]; do
  reject_control_text "compiler input path" "$compiler_path"
  if [[ ! -f "$compiler_path" || -L "$compiler_path" ]]; then
    print -u2 "compiler input is not a regular non-symlink file: $compiler_path"
    exit 65
  fi
  logical_path="$(logical_compiler_path "$compiler_path")"
  compiler_sources[$logical_path]=1
  print -r -- "compiler-input\t${logical_path}\t$(sha256_file "$compiler_path")" \
    >> "$temporary_unsorted"
  (( compiler_input_count += 1 ))
  if [[ "$logical_path" == generated:* ]]; then
    (( generated_input_count += 1 ))
  fi
done < "$swift_file_list"

filesystem_source_count=0
ignored_source_count=0
for synchronized_root in Binding Cells; do
  source_root="${root_dir}/${synchronized_root}"
  if [[ ! -d "$source_root" || -L "$source_root" ]]; then
    print -u2 "filesystem-synchronized root is unavailable or a symlink: $source_root"
    exit 65
  fi
  while IFS= read -r source_path || [[ -n "$source_path" ]]; do
    reject_control_text "filesystem source path" "$source_path"
    logical_path="binding:${source_path#${root_dir}/}"
    if [[ -z "${compiler_sources[$logical_path]-}" ]]; then
      if "$git_bin" -C "$root_dir" check-ignore -q -- "${source_path#${root_dir}/}"; then
        print -u2 "ignored source-like file is not attested by Xcode's SwiftFileList: $logical_path"
      else
        print -u2 "source-like file in synchronized root is not attested by Xcode's SwiftFileList: $logical_path"
      fi
      exit 65
    fi
    ignored=0
    if "$git_bin" -C "$root_dir" check-ignore -q -- "${source_path#${root_dir}/}"; then
      ignored=1
      (( ignored_source_count += 1 ))
    fi
    print -r -- "synchronized-root-source\t${logical_path}\tignored=${ignored}\t$(sha256_file "$source_path")" \
      >> "$temporary_unsorted"
    (( filesystem_source_count += 1 ))
  done < <(/usr/bin/find "$source_root" -type f -name '*.swift' -print | LC_ALL=C /usr/bin/sort)
done

append_config() {
  local key="$1"
  local value="$2"
  reject_control_text "build setting $key" "$value"
  print -r -- "build-setting\t${key}\t${value}" >> "$temporary_config"
  print -r -- "build-setting\t${key}\t${value}" >> "$temporary_unsorted"
}

append_config ACTION "${ACTION:-unknown}"
append_config ARCHS "${ARCHS:-unknown}"
append_config ATTESTED_ARCH "$attested_arch"
append_config CURRENT_ARCH "${CURRENT_ARCH:-undefined}"
append_config CONFIGURATION "${CONFIGURATION:-unknown}"
append_config EFFECTIVE_PLATFORM_NAME "${EFFECTIVE_PLATFORM_NAME:-none}"
append_config ENABLE_TESTABILITY "${ENABLE_TESTABILITY:-unknown}"
append_config GCC_PREPROCESSOR_DEFINITIONS "${GCC_PREPROCESSOR_DEFINITIONS:-}"
append_config IPHONEOS_DEPLOYMENT_TARGET "${IPHONEOS_DEPLOYMENT_TARGET:-none}"
append_config MACOSX_DEPLOYMENT_TARGET "${MACOSX_DEPLOYMENT_TARGET:-none}"
append_config ONLY_ACTIVE_ARCH "${ONLY_ACTIVE_ARCH:-unknown}"
append_config OTHER_CFLAGS "${OTHER_CFLAGS:-}"
append_config OTHER_LDFLAGS "${OTHER_LDFLAGS:-}"
append_config OTHER_SWIFT_FLAGS "${OTHER_SWIFT_FLAGS:-}"
append_config SDK_NAME "${SDK_NAME:-unknown}"
append_config SWIFT_ACTIVE_COMPILATION_CONDITIONS "${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-}"
append_config SWIFT_APPROACHABLE_CONCURRENCY "${SWIFT_APPROACHABLE_CONCURRENCY:-unknown}"
append_config SWIFT_COMPILATION_MODE "${SWIFT_COMPILATION_MODE:-unknown}"
append_config SWIFT_DEFAULT_ACTOR_ISOLATION "${SWIFT_DEFAULT_ACTOR_ISOLATION:-unknown}"
append_config SWIFT_ENABLE_EXPLICIT_MODULES "${SWIFT_ENABLE_EXPLICIT_MODULES:-unknown}"
append_config SWIFT_OPTIMIZATION_LEVEL "${SWIFT_OPTIMIZATION_LEVEL:-unknown}"
append_config SWIFT_VERSION "${SWIFT_VERSION:-unknown}"

swiftc_version="$($swiftc_bin -version | /usr/bin/tr '\n' ' ')"
reject_control_text "swiftc version" "$swiftc_version"
swiftc_sha256="$(sha256_file "$swiftc_bin")"
sdk_settings_sha256="$(sha256_file "$SDKROOT/SDKSettings.plist")"
print -r -- "toolchain\tswiftc-version\t${swiftc_version}" >> "$temporary_unsorted"
print -r -- "toolchain\tswiftc-binary-sha256\t${swiftc_sha256}" >> "$temporary_unsorted"
print -r -- "toolchain\tsdk-settings-sha256\t${sdk_settings_sha256}" >> "$temporary_unsorted"

project_sha256="$(sha256_file "$PROJECT_FILE_PATH/project.pbxproj")"
package_resolved="${PROJECT_FILE_PATH}/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [[ ! -f "$package_resolved" ]]; then
  print -u2 "Package.resolved is missing: $package_resolved"
  exit 66
fi
package_resolved_sha256="$(sha256_file "$package_resolved")"
binding_module_sha256="$(sha256_file "$binding_module")"
link_file_list_sha256="$(sha256_file "$link_file_list")"
cellbase_sha256="$(sha256_file "$cellbase_artifact")"
cellapple_sha256="$(sha256_file "$cellapple_artifact")"
cellprotocol_artifact_sha256="$({
  print -r -- "CellBase.o\t${cellbase_sha256}"
  print -r -- "CellApple.o\t${cellapple_sha256}"
} | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"
print -r -- "build-input\tproject-pbxproj\t${project_sha256}" >> "$temporary_unsorted"
print -r -- "build-input\tpackage-resolved\t${package_resolved_sha256}" >> "$temporary_unsorted"
print -r -- "build-artifact\tbinding-swiftmodule\t${binding_module_sha256}" >> "$temporary_unsorted"
print -r -- "link-input-list\tHAVEN.LinkFileList\t${link_file_list_sha256}" >> "$temporary_unsorted"
print -r -- "cellprotocol-artifact\tCellBase.o\t${cellbase_sha256}" >> "$temporary_unsorted"
print -r -- "cellprotocol-artifact\tCellApple.o\t${cellapple_sha256}" >> "$temporary_unsorted"

code_signing_allowed="${CODE_SIGNING_ALLOWED:-NO}"
expanded_identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
development_team="${DEVELOPMENT_TEAM:-}"
if [[ "$code_signing_allowed" != "YES" || -z "$expanded_identity" ||
      "$expanded_identity" == "-" ]]; then
  code_signing_mode="unsigned"
  expanded_identity="unsigned"
  development_team="unsigned"
elif [[ "$expanded_identity" =~ '^[0-9A-Fa-f]{40}$' ]]; then
  code_signing_mode="certificate"
  expanded_identity="${expanded_identity:l}"
  if [[ -z "$development_team" ]]; then
    print -u2 "certificate-signed build has no DEVELOPMENT_TEAM"
    exit 65
  fi
else
  print -u2 "code-signing identity is not an attested certificate fingerprint"
  exit 65
fi

entitlements_sha256="$(printf 'none' | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"
if [[ -n "${CODE_SIGN_ENTITLEMENTS:-}" ]]; then
  entitlements_path="${root_dir}/${CODE_SIGN_ENTITLEMENTS}"
  if [[ ! -f "$entitlements_path" || -L "$entitlements_path" ]]; then
    print -u2 "code-sign entitlements are unavailable or a symlink: $entitlements_path"
    exit 65
  fi
  entitlements_sha256="$(sha256_file "$entitlements_path")"
fi
print -r -- "code-signing\tmode\t${code_signing_mode}" >> "$temporary_unsorted"
print -r -- "code-signing\tidentity-fingerprint\t${expanded_identity}" >> "$temporary_unsorted"
print -r -- "code-signing\tdevelopment-team\t${development_team}" >> "$temporary_unsorted"
print -r -- "code-signing\tentitlements-sha256\t${entitlements_sha256}" >> "$temporary_unsorted"

LC_ALL=C /usr/bin/sort "$temporary_unsorted" > "$temporary_manifest"
/bin/mv -f "$temporary_manifest" "$output_manifest"
manifest_sha256="$(sha256_file "$output_manifest")"
compiler_flags_sha256="$(LC_ALL=C /usr/bin/sort "$temporary_config" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"
toolchain_sha256="$({
  print -r -- "$swiftc_version"
  print -r -- "$swiftc_sha256"
  print -r -- "$sdk_settings_sha256"
} | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"

binding_revision="$(git_revision "$root_dir")"
cellprotocol_revision="$(git_revision "$cellprotocol_dir")"
generated_at="$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"

/usr/bin/plutil -create xml1 "$temporary_plist"
/usr/bin/plutil -insert schema -string 'binding.build-provenance.v3' "$temporary_plist"
/usr/bin/plutil -insert coverageDeclaration -string 'xcode-swift-file-list+fs-synchronized-root-inventory+generated-swift+linked-cellprotocol-artifacts+declared-build-settings' "$temporary_plist"
/usr/bin/plutil -insert bindingGitRevision -string "$binding_revision" "$temporary_plist"
/usr/bin/plutil -insert cellProtocolGitRevision -string "$cellprotocol_revision" "$temporary_plist"
/usr/bin/plutil -insert compilerInputManifestSHA256 -string "$manifest_sha256" "$temporary_plist"
/usr/bin/plutil -insert compilerInputCount -integer "$compiler_input_count" "$temporary_plist"
/usr/bin/plutil -insert generatedCompilerInputCount -integer "$generated_input_count" "$temporary_plist"
/usr/bin/plutil -insert filesystemSynchronizedSourceCount -integer "$filesystem_source_count" "$temporary_plist"
/usr/bin/plutil -insert ignoredSourceLikeInputCount -integer "$ignored_source_count" "$temporary_plist"
/usr/bin/plutil -insert bindingCompilerArtifactSHA256 -string "$binding_module_sha256" "$temporary_plist"
/usr/bin/plutil -insert cellProtocolArtifactSHA256 -string "$cellprotocol_artifact_sha256" "$temporary_plist"
/usr/bin/plutil -insert linkInputManifestSHA256 -string "$link_file_list_sha256" "$temporary_plist"
/usr/bin/plutil -insert compilerFlagsSHA256 -string "$compiler_flags_sha256" "$temporary_plist"
/usr/bin/plutil -insert toolchainSHA256 -string "$toolchain_sha256" "$temporary_plist"
/usr/bin/plutil -insert codeSigningMode -string "$code_signing_mode" "$temporary_plist"
/usr/bin/plutil -insert codeSigningIdentityFingerprint -string "$expanded_identity" "$temporary_plist"
/usr/bin/plutil -insert codeSigningTeamIdentifier -string "$development_team" "$temporary_plist"
/usr/bin/plutil -insert codeSigningEntitlementsSHA256 -string "$entitlements_sha256" "$temporary_plist"
/usr/bin/plutil -insert buildConfiguration -string "${CONFIGURATION:-unknown}" "$temporary_plist"
/usr/bin/plutil -insert sdkName -string "${SDK_NAME:-unknown}" "$temporary_plist"
/usr/bin/plutil -insert generatedAtUTC -string "$generated_at" "$temporary_plist"
/bin/mv -f "$temporary_plist" "$output_plist"
trap - EXIT
/bin/rm -f "$temporary_unsorted" "$temporary_config"
