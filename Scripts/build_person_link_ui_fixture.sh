#!/bin/zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
if (( $# != 0 )); then
  print -u2 "This isolated fixture builder accepts no overrides."
  exit 2
fi
# A dedicated, disposable product. Never install it as the normal HAVEN app.
products="/private/tmp/haven-person-link-ui-products"
scripts/build_binding.sh -configuration Debug \
  -derivedDataPath /private/tmp/haven-xcode-derived/Binding-EntityContinuity \
  -disableAutomaticPackageResolution \
  CONFIGURATION_BUILD_DIR="$products" \
  PRODUCT_BUNDLE_IDENTIFIER=org.digipomps.haven.person-link-ui-test \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS=
python3 Scripts/isolate_identity_link_fixture.py "$products/HAVEN.app" --apply
