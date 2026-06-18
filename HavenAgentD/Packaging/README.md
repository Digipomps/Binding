# Packaging HavenAgentD

Builds a signed, notarized macOS installer package (`.pkg`) for distributing
`haven-agentd` to external pilot users (e.g. Victoria) on a clean Mac.

This is the **first-install** path. Updates are intended to flow later through
the staging scaffold + `sprout-updater` policy path, not through this pkg.

## What the pkg contains

| Path | Contents |
|------|----------|
| `/usr/local/libexec/havenagent/haven-agentd` | signed agent binary (hardened runtime) |
| `/usr/local/libexec/havenagent/sprout` | signed sprout binary (agent calls it as a subprocess) |
| `/usr/local/share/havenagent/io.digipomps.haven.agentd.plist.template` | LaunchAgent template for the setup step |

The pkg installs binaries only. It does **not** start the agent: a usable
agent still needs a `config.json` plus the per-user provisioning artifacts
(pairing / starter-auth / entity-link), which are produced by operator tooling.
Loading launchd before those exist would just crashloop.

Per-user runtime state stays where it always has:
`~/Library/Application Support/HAVENAgent/`.

## One-time prerequisites (operator machine)

1. Developer ID certs in the login keychain (already present):
   - `Developer ID Application: Stiftelsen Digipomps (5UT5HQTCV9)`
   - `Developer ID Installer: Stiftelsen Digipomps (5UT5HQTCV9)`
2. A stored notarytool keychain profile:
   ```bash
   xcrun notarytool store-credentials "DIGIPOMPS_NOTARY" \
     --apple-id "kjetil.hustveit@digipomps.org" \
     --team-id "5UT5HQTCV9" \
     --password "<app-specific-password>"
   ```
3. A built `sprout` release binary (matching arch):
   ```bash
   (cd ../../sprout && swift build -c release --product sprout)
   ```

## Build + sign

```bash
cd HavenAgentD
VERSION=0.1.0 ./Packaging/build_pkg.sh
```

Produces under `dist/`:
- `HAVENAgentD-<version>-<arch>.pkg` — signed, ready to notarize
- `SHA256SUMS` — hashes of the staged binaries
- `release-manifest.json` — version / arch / signing / per-artifact hashes

Override defaults via env: `VERSION`, `DIST_DIR`, `SPROUT_BIN`,
`APP_IDENTITY`, `INSTALLER_IDENTITY`, `STRIP`.

## Notarize + staple

```bash
./Packaging/notarize_pkg.sh dist/HAVENAgentD-0.1.0-arm64.pkg
```

Submits to Apple, waits, staples the ticket, then verifies with
`stapler validate` and `spctl --assess --type install`. After this the pkg
passes Gatekeeper on a Mac that has never seen our developer account.

## Architecture note

The pkg is **single-arch** (whatever the build machine is — currently
`arm64`). If a pilot user is on an Intel Mac, build an `x86_64` pkg on/at an
Intel toolchain, or move to a universal2 binary first.

## Installing on the target Mac (pilot)

```bash
sudo installer -pkg HAVENAgentD-0.1.0-arm64.pkg -target /
```

Then run `setup`, which creates the runtime tree, writes `config.json` with a
freshly generated loopback token, and installs the per-user LaunchAgent
pointing at the installed binary:

```bash
/usr/local/libexec/havenagent/haven-agentd setup \
  --domain staging.haven.digipomps.org \
  --resolver-url https://staging.haven.digipomps.org \
  --discovery-url https://staging.haven.digipomps.org/v1/bridges/query \
  --instance-name victoria-mac \
  --sprout-path /usr/local/libexec/havenagent/sprout
```

`setup` keeps `startupMode = disabled` by default (local-only, safe to load),
prints provisioning readiness, and refuses `--load` for a scaffold-bound
startup that has no provisioning yet (it would crashloop under `KeepAlive`).

Remaining steps:

1. Import the provisioning pack so the agent can join the scaffold (format and
   round trip in [../Docs/ProvisioningPack.md](../Docs/ProvisioningPack.md)):
   ```bash
   haven-agentd provisioning-request                 # send this to the operator
   haven-agentd provisioning-import --pack pack.json # install their signed pack
   ```
   Until then the agent runs local-only.
2. Activate at login (or pass `--load` to `setup` once provisioned / local-only):
   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.digipomps.haven.agentd.plist
   launchctl kickstart -k gui/$(id -u)/io.digipomps.haven.agentd
   ```
3. Grant Automation / Accessibility consent in the logged-in session.

`setup` is idempotent: re-running without `--force` keeps the existing config
and token, and just re-installs the LaunchAgent.

See [../Docs/OperatorRunbook.md](../Docs/OperatorRunbook.md) for the full
operator flow and [../Docs/SecurityModel.md](../Docs/SecurityModel.md) for the
trust boundary.
