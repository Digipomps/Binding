# Binding Apple Release M0 Preflight

This is a deliberately unsigned, fail-closed gate before any Apple archive,
TestFlight upload, or App Store operation. It does not choose or modify HAVEN's
Apple identity. It produces deterministic JSON audit material that binds the
resolved iPhoneOS Release configuration to an exact Git revision.

## Safety boundary

The M0 preflight:

- statically resolves the project-level and HAVEN-target `Release` settings,
  including the `sdk=iphoneos*` conditional override, from `project.pbxproj`;
- reads only the repository Git revision/status, Xcode project metadata, and
  the selected iOS entitlements plist;
- emits an explicit allowlist of non-secret facts;
- never invokes signing, archives, upload tools, Keychain, Apple accounts, or
  provisioning profile inspection;
- never evaluates or sources policy JSON as shell code;
- has no CLI option for injecting facts or changing repository root: production
  CLI facts always come from the script's live Binding repository, project
  metadata, and entitlements;
- never resolves Swift packages and never includes environment variables,
  certificate material, provisioning profile names/content, or proof text in
  its report.

The policy's `evidenceReference` strings point to separately controlled proof;
they are not the proof material itself. The JSON report records only whether an
evidence reference is present.

## Run it

The committed policy is intentionally pending, so this command must return exit
code `1` and status `BLOCKED` until Kjetil records the decisions and external
proofs:

```sh
Scripts/apple_release_m0_preflight.sh \
  --output /tmp/binding-apple-release-m0-audit.json
```

Create a local, uncommitted policy when the decisions have been made:

```sh
cp Documentation/AppleReleaseM0Policy.template.json \
  /tmp/binding-apple-release-m0-policy.json
```

After editing that local JSON, run:

```sh
Scripts/apple_release_m0_preflight.sh \
  --policy /tmp/binding-apple-release-m0-policy.json \
  --output /tmp/binding-apple-release-m0-audit.json
```

Exit codes are part of the contract:

- `0`: every M0 gate passed;
- `1`: valid audit completed but one or more release blockers remain;
- `2`: facts or policy could not be collected or validated safely.

The report omits timestamps on purpose. For identical allowlisted facts and
policy, both the JSON and its `attestationDigest` are reproducible. The
top-level `sourceRevision` is always a full 40-character Git revision. A dirty
tree is a blocker because uncommitted content cannot be attested by that
revision.

## Decisions Kjetil must record

Set `status` to `decided`, supply the exact `value`, and add a non-secret
`decisionRecord` reference for each item. Do not put credentials or Apple
account exports in the policy.

A `decided` value cannot be `null`. Team ID, bundle ID, and APNs environment
must be non-empty strings. APNs accepts only Apple's `development` or
`production` values. Associated Domains may be an explicitly decided empty
array, but duplicate, empty, or whitespace-padded entries are rejected.

| Policy item | Decision required | Match enforced by M0 |
| --- | --- | --- |
| `developmentTeam` | The Apple Developer team that owns the explicit App ID and App Store Connect app | Statically resolved `DEVELOPMENT_TEAM` for HAVEN Release/iphoneos |
| `bundleIdentifier` | The final stable bundle ID | Statically resolved `PRODUCT_BUNDLE_IDENTIFIER` |
| `associatedDomains` | The complete service-qualified domain list; an empty array is allowed only as an explicit decision | Sorted `com.apple.developer.associated-domains` entitlement values |
| `apsEnvironment` | The APNs environment expected in release entitlements | Resolved source `aps-environment` value |
| `expectedRevision` | The exact release-candidate commit | Full Git `HEAD` with a clean tree |

Apple documents that an explicit App ID's bundle ID must match the Xcode target
bundle ID. App Store Connect also uses bundle ID, marketing version, and build
string to associate an upload with an app/version record. The Associated
Domains entitlement is an array of `<service>:<fully qualified domain>` values;
`applinks` and `webcredentials` are separate services and should be selected
only when the product contract requires them.

The M0 gate also requires non-empty marketing version/build number and resolved
`Release` + `iphoneos` settings. It reports but does not mutate signing style or
identity class.

The static resolver fails closed if a Release configuration starts using a
base `.xcconfig`, if a critical value retains an unresolved variable, or if the
HAVEN/Release object graph is ambiguous. This avoids Swift package resolution,
network activity, DerivedData writes, signing, and Keychain access. A later
authorized archive gate must still compare these source facts with Xcode's
resolved and signed distribution product.

## External proof gates

Both proof statuses remain `unproved` until a later, explicitly authorized
Apple workflow has produced evidence:

1. `signingAndProvisioning`: prove that the selected team, explicit App ID,
   distribution signing, provisioning profile, and final signed entitlements
   agree. This M0 tool cannot prove that from an unsigned build.
2. `appStoreConnectRecord`: prove that the app record exists under the selected
   team and has the same bundle ID. No account access is performed here.

For APNs, Apple's entitlement documentation says `development` selects the
sandbox while production provisioning and beta distribution use `production`;
Xcode derives the signed value from the provisioning profile. Therefore this
unsigned source audit is necessary but not sufficient: final signed archive
entitlements and an end-to-end device/APNs test remain a later gate owned by the
separate APNs/release workflow.

Associated Domains likewise require later proof across all three surfaces:

- the selected Xcode entitlement values;
- the App ID/provisioning capability;
- the public `apple-app-site-association` contract for the selected domains.

M0 treats the decision as an exact string-array match but does not contact the
domains or alter AASA.

## Tests

The fixture suite imports the audit functions directly, uses synthetic
identities, and never consults signing state. Synthetic facts are deliberately
unavailable through the production CLI or shell wrapper:

```sh
/usr/bin/python3 Tests/apple_release_m0_preflight_tests.py -v
```

It covers a complete pass, deterministic output/digest, pending decisions,
configuration mismatches, a dirty source tree, malformed input, missing/invalid
APNs, invalid Associated Domains, and rejection of arbitrary/provisioning fields
from serialized audit material.

## Current repository state versus release readiness

The policy template contains no selected production values. Consequently a
default run is expected to report `BLOCKED`, not to infer approval from the
values currently present in the project. No M0 implementation file changes
`Binding.xcodeproj/project.pbxproj`, `Binding/Info.plist`,
`Binding/Binding-iOS.entitlements`, Team ID, bundle ID, Associated Domains, APNs
environment, or signing/provisioning settings.

## Official Apple references

- [Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/)
- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Create an App Store Connect provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/)
- [Associated Domains entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.associated-domains)
- [APS Environment entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment)
- [Checking Distribution Entitlements](https://developer.apple.com/library/archive/qa/qa1798/_index.html)
