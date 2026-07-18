# HavenAgentD Operator Runbook

This runbook is the current step-by-step guide for installing, configuring, starting, and operating `haven-agentd` as a standalone macOS agent.

It is intentionally narrower than the older Binding-embedded runbook:

- `Binding` no longer installs or exposes agent setup UX by default
- `HavenAgentD` is now the product boundary for agent runtime and operator workflows
- pairing/bootstrap evidence is delivered as a signed **provisioning pack** that the agent imports itself (no more "operator tooling drops files by hand")

## Two install paths

There are two ways to get `haven-agentd` onto a machine. Pick one deliberately.

| | **Recommended: pkg + `setup` + `provisioning-import`** | **Dev-only: `swift run` + manual copy** |
|---|---|---|
| Audience | pilot users (e.g. Victoria), real installs | developers iterating on this machine |
| Binary delivery | signed + notarized `.pkg` → `/usr/local/libexec/havenagent/` | `swift build` + `cp` into the runtime root |
| Config + LaunchAgent | one `haven-agentd setup` command | hand-edited config + `print-launch-agent` |
| Provisioning | `provisioning-request` / `provisioning-import` | same (or pre-placed artifacts) |
| Gatekeeper | passes on a clean Mac | unsigned, local only |

The recommended path folds what used to be separate runbook phases (create config, edit config, install binary, render/install the LaunchAgent) into the package install plus a single `setup` command. The dev-only path keeps the old manual steps for local iteration and is documented in [Part B](#part-b--dev-only-manual-flow).

Cross-references:

- **Building/signing the pkg:** [/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Packaging/README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Packaging/README.md)
- **Provisioning pack format + round trip:** [/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/ProvisioningPack.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/ProvisioningPack.md)

## Scope

Use this runbook for:

- building, signing, and notarizing the installer pkg
- installing `haven-agentd` on a clean target Mac
- running `setup` to create the runtime tree, config, token, and LaunchAgent
- provisioning the agent so it can join the scaffold
- validating config and preflighting bootstrap before first real start
- inspecting and deciding queued remote intents
- local development runs under `--root`

Do not use this runbook as proof that scaffold admission is complete unless `bootstrap-probe --run-bootstrap` succeeds with real pairing artifacts and a real `sprout` binary.

## Current truth

What is fully supported and verified now:

- `swift test`, `swift build`, and the deterministic smoke test
- the signed + notarized `.pkg` (`Packaging/build_pkg.sh`, `Packaging/notarize_pkg.sh`)
- `setup` (creates dirs, config + generated token, LaunchAgent, provisioning readiness)
- `provisioning-request` and `provisioning-import`
- `print-example-config`
- `validate-config`
- `run --once`
- `review-state`
- `review-approve` and `review-reject`
- `print-launch-agent`
- `bootstrap-probe` preflight behavior

What still depends on external operator material:

- the signed **provisioning pack** (`pack.json`) carrying:
  - the agent-enrollment pairing artifact
  - `starter-auth`
  - the mutually signed entity-link contract
- a real executable `sproutBinaryPath`

`haven-agentd` imports and verifies the pack, but **minting** it (signing pairing approval, issuing starter-auth, building the mutually signed entity-link, updating the scaffold entity-anchor snapshot) is operator-side tooling and is **not** part of `haven-agentd`. See [ProvisioningPack.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/ProvisioningPack.md) for the format that tooling must produce.

## Prerequisites

For the **recommended (pkg)** path:

- an operator/build machine with the Developer ID certs and a notarytool keychain profile (see [Packaging/README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Packaging/README.md))
- a built `sprout` release binary matching the target arch
- the target Mac: macOS with a logged-in user session
- for real bootstrap: a signed provisioning pack for that exact agent identity

For the **dev-only** path:

- macOS with a logged-in user session
- Xcode command line tools
- this workspace checked out locally
- a buildable `HavenAgentD` package
- for real bootstrap: a working `sprout` binary plus valid pairing/evidence artifacts

Workspace root used below:

```bash
/Users/kjetil/Build/Digipomps/HAVEN/Binding
```

## Important paths

Binaries installed by the **pkg**:

```text
/usr/local/libexec/havenagent/haven-agentd
/usr/local/libexec/havenagent/sprout
/usr/local/share/havenagent/io.digipomps.haven.agentd.plist.template
```

LaunchAgent installed by `setup` (standard per-user location):

```text
~/Library/LaunchAgents/io.digipomps.haven.agentd.plist
```

Per-user runtime root (both paths — config, state, evidence, logs live here):

```text
~/Library/Application Support/HAVENAgent/
```

Important files under that root:

```text
~/Library/Application Support/HAVENAgent/config.json
~/Library/Application Support/HAVENAgent/starter-auth.json
~/Library/Application Support/HAVENAgent/State/agent-state.json
~/Library/Application Support/HAVENAgent/State/cell-runtime.json
~/Library/Application Support/HAVENAgent/State/remote-intent-state.json
~/Library/Application Support/HAVENAgent/State/agent-identity.json
~/Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json
~/Library/Application Support/HAVENAgent/Out/agent-operator-entity-link.json
~/Library/Application Support/HAVENAgent/Logs/stdout.log
~/Library/Application Support/HAVENAgent/Logs/stderr.log
```

`State/agent-identity.json` is descriptor metadata only in the production path.
The private agent signing seed is stored in Apple Keychain under service
`no.haven.agentd.identity`; `haven-agentd status` reports the descriptor
`storageKind` so operator tooling and GUI surfaces can show whether the agent is
using the hardened path.

Dev-only manual-copy binary location (NOT used by the pkg path):

```text
~/Library/Application Support/HAVENAgent/haven-agentd
~/Library/Application Support/HAVENAgent/Launchd/io.digipomps.haven.agentd.plist
```

Disposable development root:

```text
/tmp/haven-dev/HAVENAgent/
```

---

# Part A — Recommended flow (pkg + `setup` + `provisioning-import`)

## Phase 1: Verify the package (build machine)

Before producing an installer, confirm the package is healthy. From the workspace root:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding
./Scripts/test_haven_agentd.sh
```

Expected result:

- the Swift package builds
- package tests pass
- the smoke test finishes with JSON showing `finalPhase = connected`

Do not continue to packaging until this passes.

## Phase 2: Build, sign, and notarize the pkg

This produces the first-install artifact for a clean Mac. Full prerequisites, env overrides, and the architecture note live in [Packaging/README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Packaging/README.md); the short form:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD

# Build + sign universal2 (produces pkg + package/payload checksums + manifest)
ARCHS="arm64 x86_64" VERSION=0.3.1 ./Packaging/build_pkg.sh

# Notarize + staple (passes Gatekeeper on a Mac that has never seen our dev account)
./Packaging/notarize_pkg.sh dist/HAVENAgentD-0.3.1-universal2.pkg
```

The pkg installs **binaries only**. It does not start the agent — a usable agent still needs a `config.json` plus per-user provisioning, which the next phases create.

## Phase 3: Install the pkg on the target Mac

```bash
sudo installer -pkg HAVENAgentD-0.3.1-universal2.pkg -target /
```

This places `haven-agentd` and `sprout` under `/usr/local/libexec/havenagent/` and the LaunchAgent template under `/usr/local/share/havenagent/`. No runtime state is created yet.

## Phase 4: Run `setup` (folds old phases 2–5 and 9)

`setup` is idempotent and folds what used to be four separate manual phases — create config, edit config, install binary path into the LaunchAgent, install the LaunchAgent — into one command. It creates the runtime directory tree, writes `config.json` with a freshly generated loopback bridge token, installs the per-user LaunchAgent pointing at the installed binary, and reports provisioning readiness.

```bash
/usr/local/libexec/havenagent/haven-agentd setup \
  --domain staging.haven.digipomps.org \
  --resolver-url https://staging.haven.digipomps.org \
  --discovery-url https://staging.haven.digipomps.org/v1/bridges/query \
  --instance-name victoria-mac \
  --sprout-path /usr/local/libexec/havenagent/sprout
```

What `setup` guarantees:

- creates `~/Library/Application Support/HAVENAgent/` and its `State/`, `Out/`, `Logs/` tree
- writes `config.json` and generates a strong `localControlBridge.accessToken` (no placeholder left behind)
- installs `~/Library/LaunchAgents/io.digipomps.haven.agentd.plist` pointing at the installed binary
- keeps `startupMode = disabled` by default — local-only and safe to load before provisioning
- runs a `bootstrap-probe` and prints provisioning readiness + next steps as JSON
- **refuses `--load`** for a scaffold-bound startup that has no provisioning yet (it would crashloop under `KeepAlive`)

`setup` is idempotent: re-running without `--force` keeps the existing config and token and just re-installs the LaunchAgent. Use `--force` to regenerate config + token. Other useful flags: `--purpose`, `--access-token`, `--startup-mode disabled|plan|join`, `--executable-path`, `--no-launch-agent`, `--load`, and `--root` (dev roots).

Validation is folded into `setup`, but you can re-check at any time:

```bash
/usr/local/libexec/havenagent/haven-agentd validate-config \
  --config ~/Library/Application\ Support/HAVENAgent/config.json
```

Expected result:

```text
Config OK: ...
```

> `config.json` is local admin policy, not remote content. Edit it directly if you need to change automation/remote-intent policy after `setup`.

## Phase 5: Provision the agent (`provisioning-request` / `provisioning-import`)

This replaces the old "operator tooling drops files into `Out/`" step. The agent prints its own identity, the operator mints a pack bound to that exact key, and the agent imports it. The full format, binding rules, and what import verifies are in [ProvisioningPack.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/ProvisioningPack.md).

1. Print the request and send it to the operator:

   ```bash
   haven-agentd provisioning-request \
     --config ~/Library/Application\ Support/HAVENAgent/config.json
   ```

   This prints the agent's stable identity (`agentPublicKeyBase64URL` + UUID + DID) plus the configured scaffold domain / purpose / interests. It materializes the identity if the agent has never run.

2. The operator mints a `pack.json` bound to that exact agent public key, signs the three artifacts (pairing, starter-auth, entity-link), and returns it. **Minting is operator-side tooling, not part of `haven-agentd`.**

3. Import and verify the pack:

   ```bash
   haven-agentd provisioning-import \
     --pack pack.json \
     --config ~/Library/Application\ Support/HAVENAgent/config.json
   ```

   Import refuses any pack whose `boundAgent.agentPublicKeyBase64URL` does not match the local identity, verifies every embedded artifact against that key and the configured scaffold domain *before* writing anything, then runs a `bootstrap-probe` and reports `readyForBootstrap`. A failure installs nothing. Until a pack is imported, the agent runs local-only.

## Phase 6: Preflight and real bootstrap probe (security gate)

This security gate is unchanged and must stay intact. Even though `setup` and `provisioning-import` both run a preflight probe, run it explicitly before any real bootstrap.

Preflight only (no bootstrap attempted):

```bash
haven-agentd bootstrap-probe \
  --config ~/Library/Application\ Support/HAVENAgent/config.json
```

Expected result when evidence is ready:

- `readyForBootstrap = true`
- pairing artifact present and valid
- starter auth present and valid
- entity-link evidence present and valid

Expected result when evidence is not ready:

- JSON report with `readyForBootstrap = false`
- explicit summaries such as `Pairing artifact is missing.`, `Starter auth is not configured.`, `Entity-link evidence is not configured.`

This is the correct stopping point if provisioning has not completed yet.

Run a **real** bootstrap probe only when `scaffold.sproutBinaryPath` is real and pairing + starter-auth + entity-link are all installed:

```bash
haven-agentd bootstrap-probe \
  --config ~/Library/Application\ Support/HAVENAgent/config.json \
  --run-bootstrap
```

Interpretation:

- `readyForBootstrap = false` — local operator setup is incomplete.
- `readyForBootstrap = true` and bootstrap succeeds — agent admission and native contract bootstrap succeeded.
- `readyForBootstrap = true` and bootstrap fails — local evidence is valid, but scaffold admission or resolver-side state still blocks the agent.

If the resolver reports `identity not found in accepted anchor snapshot`, the remaining action is scaffold-side admission of the paired contract (e.g. `sprout-admin entity-anchor accept-entity-link`; see [README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/README.md)).

## Phase 7: Activate at login

`setup` installed the LaunchAgent but left it unloaded (and refuses to load an unprovisioned scaffold-bound startup). Once provisioning is ready — or for a local-only agent — activate it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.digipomps.haven.agentd.plist
launchctl kickstart -k gui/$(id -u)/io.digipomps.haven.agentd
```

Alternatively, re-run `setup --load` once provisioned (or for a `startupMode = disabled` local-only agent) and it will load the LaunchAgent for you.

Verify:

```bash
launchctl list | grep io.digipomps.haven.agentd
```

Check logs:

```bash
tail -n 200 ~/Library/Application\ Support/HAVENAgent/Logs/stdout.log
tail -n 200 ~/Library/Application\ Support/HAVENAgent/Logs/stderr.log
```

Grant Automation / Accessibility consent in the logged-in user session the first time an action runs.

---

# Part B — Dev-only manual flow

> **Dev-only.** These steps use `swift run` and a hand-copied unsigned binary. They are for developers iterating on this machine. Do **not** use them for pilot installs — use the pkg + `setup` flow in Part A. Each manual step below has a one-line note pointing at the `setup` step it replaces.

## D1: Create config (replaces `setup` config creation)

### Option A: disposable local dev root

```bash
rm -rf /tmp/haven-dev
mkdir -p /tmp/haven-dev/HAVENAgent
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd print-example-config > /tmp/haven-dev/HAVENAgent/config.json
```

### Option B: real user install root

```bash
mkdir -p ~/Library/Application\ Support/HAVENAgent
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd print-example-config > ~/Library/Application\ Support/HAVENAgent/config.json
```

## D2: Edit config before first run (replaces `setup` flags + generated token)

At minimum, update these fields in `config.json`:

- `instanceName`
- `scaffold.domain`
- `scaffold.resolverBaseURL`
- `scaffold.discoveryURL`
- `scaffold.sproutBinaryPath`
- `localControlBridge.accessToken`
- `remoteIntentPolicy`
- `automationPolicy`

Important notes:

- `scaffold.sproutBinaryPath` must be an absolute path to an executable binary
- the placeholder `/absolute/path/to/sprout` will fail at runtime until replaced
- `localControlBridge.accessToken` must be changed from the placeholder before a real install (`setup` generates this automatically)
- `config.json` is local policy, not remote content

Validate after editing:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd validate-config --config ~/Library/Application\ Support/HAVENAgent/config.json
# disposable root:
swift run haven-agentd validate-config --config /tmp/haven-dev/HAVENAgent/config.json
```

Expected result:

```text
Config OK: ...
```

## D3: Build and install the binary (replaces the pkg)

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift build --product haven-agentd

mkdir -p ~/Library/Application\ Support/HAVENAgent
cp .build/debug/haven-agentd ~/Library/Application\ Support/HAVENAgent/haven-agentd
chmod 755 ~/Library/Application\ Support/HAVENAgent/haven-agentd
test -x ~/Library/Application\ Support/HAVENAgent/haven-agentd
```

## D4: Run the agent locally before launchd

### Disposable root validation (safest first run)

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd run --config /tmp/haven-dev/HAVENAgent/config.json --root /tmp/haven-dev --once
```

Expected result:

- state files are written under `/tmp/haven-dev/HAVENAgent/State/`
- `CellDocuments/` is created
- if `sproutBinaryPath` is invalid, the command fails clearly before pretending bootstrap worked

### Real local root validation

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd run --config ~/Library/Application\ Support/HAVENAgent/config.json --once
```

Expected result: `State/agent-state.json`, `State/cell-runtime.json`, `State/agent-identity.json`. If this fails with `Sprout binary is not executable`, fix `scaffold.sproutBinaryPath` first.

## D5: Render and install the LaunchAgent (replaces `setup` LaunchAgent install)

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD
swift run haven-agentd print-launch-agent > /tmp/io.digipomps.haven.agentd.plist
```

Review it, then install and load:

```bash
mkdir -p ~/Library/Application\ Support/HAVENAgent/Launchd
cp /tmp/io.digipomps.haven.agentd.plist ~/Library/Application\ Support/HAVENAgent/Launchd/io.digipomps.haven.agentd.plist
launchctl bootout gui/$(id -u)/io.digipomps.haven.agentd >/dev/null 2>&1 || true
launchctl bootstrap gui/$(id -u) ~/Library/Application\ Support/HAVENAgent/Launchd/io.digipomps.haven.agentd.plist
launchctl kickstart -k gui/$(id -u)/io.digipomps.haven.agentd
```

Provisioning (Part A, Phase 5) and the bootstrap-probe gate (Part A, Phase 6) apply identically to the dev path — run them with `swift run haven-agentd ...` against your dev config.

---

# Operating the agent (both paths)

## Inspect and decide queued intents (security gate)

This review gate is unchanged and must stay intact. Substitute the installed binary (`/usr/local/libexec/havenagent/haven-agentd`) or `swift run haven-agentd` as appropriate for your path.

Inspect queue and audit:

```bash
haven-agentd review-state --config ~/Library/Application\ Support/HAVENAgent/config.json
```

Approve a verified intent:

```bash
haven-agentd review-approve \
  --config ~/Library/Application\ Support/HAVENAgent/config.json \
  --intent-id <intent-id> \
  --reviewer "Local Operator" \
  --note "Approved from CLI"
```

Reject a verified intent:

```bash
haven-agentd review-reject \
  --config ~/Library/Application\ Support/HAVENAgent/config.json \
  --intent-id <intent-id> \
  --reviewer "Local Operator" \
  --note "Rejected from CLI"
```

Expected behavior:

- `review-state` reflects the persisted queue and audit snapshot for the config you point it at
- `review-reject` removes the pending item and appends an audit record
- `review-approve` appends audit and attempts local execution through the configured allowlist

An `approved_failed` outcome means the review path itself worked, but execution failed against local policy or action lookup.

## Health checks after install

After first successful start, verify these files exist:

```bash
test -f ~/Library/Application\ Support/HAVENAgent/State/agent-state.json
test -f ~/Library/Application\ Support/HAVENAgent/State/cell-runtime.json
test -f ~/Library/Application\ Support/HAVENAgent/State/agent-identity.json
```

If remote intents are expected, also inspect:

```bash
plutil -p ~/Library/Application\ Support/HAVENAgent/State/remote-intent-state.json
```

## Troubleshooting

`Config OK`, but `run --once` fails:

- check `scaffold.sproutBinaryPath`
- ensure the binary is absolute and executable

`setup` warns about a placeholder token or sprout path:

- the existing config still has the example token/sprout path; re-run with `--force` to regenerate, or edit `config.json` and set `scaffold.sproutBinaryPath`

`bootstrap-probe` says pairing artifact missing:

- check `Out/agent-enrollment-pairing.json`
- confirm the config path points to the intended agent root
- if you have a `pack.json`, run `provisioning-import` instead of placing files by hand

`bootstrap-probe` says starter auth or entity-link missing:

- provisioning has not completed yet — import the provisioning pack
- do not proceed to real bootstrap until those files exist

`provisioning-import` refuses the pack:

- the pack's `boundAgent.agentPublicKeyBase64URL` must match this agent; re-run `provisioning-request` and have the operator mint a pack bound to the printed key
- the pack's `scaffoldDomain` must equal `config.scaffold.domain`

`review-state` shows no pending intents when you expected some:

- confirm you are pointing at the same `config.json` root as the running agent
- inspect the matching `State/remote-intent-state.json` directly

`review-approve` returns `approved_failed`:

- the intent was reviewable, but the action was not executable under current local allowlist or policy
- inspect `errorMessage` in the returned audit record

`launchctl` starts the agent but GUI automation does not work:

- confirm the process is installed as a per-user `LaunchAgent`, not a daemon
- confirm Automation / Accessibility permissions were granted in the logged-in user session

## Recommended release gate

Before calling the operator flow healthy, require all of these:

1. `./Scripts/test_haven_agentd.sh`
2. a signed + notarized pkg that passes `stapler validate` and `spctl --assess --type install` (Part A, Phase 2)
3. `installer -pkg ...` on a clean target, then `setup` produces config + token + LaunchAgent
4. `validate-config`
5. `provisioning-request` → `provisioning-import` of a real pack
6. `bootstrap-probe` (preflight) reporting `readyForBootstrap = true`
7. `review-state` plus one real `review-reject` or `review-approve` decision against a queued test intent
8. one successful local launchd start via the installed LaunchAgent

## Related docs

- [README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/README.md)
- [Packaging/README.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Packaging/README.md)
- [Docs/ProvisioningPack.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/ProvisioningPack.md)
- [SecurityModel.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/SecurityModel.md)
- [BindingBoundary.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/BindingBoundary.md)
- [Legacy/BindingProvisioningRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/HavenAgentD/Docs/Legacy/BindingProvisioningRunbook.md)
</content>
</invoke>
