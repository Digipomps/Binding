# NetworkSentinelCell

A native HAVEN cell, hosted by `haven-agentd`, that watches the local link for
**flooding** and surfaces a *harmful* flood to the operator as a purpose-matched
alert — over macOS-native notifications and as a CellProtocol `FlowElement`.

It replaces the earlier throwaway bash watchdog (`~/wifimon`). Findings from that
prototype shaped this design: most "flooding" on a home link is just the user's
own large downloads saturating the link (benign), and ICMP-loss probing produces
false positives while the machine sleeps. This cell avoids both traps.

- Endpoint: `cell:///agent/network/sentinel`
- Kind: `AgentCellKind.networkSentinel`
- Side-effect boundary: read-only interface-counter observation; emits
  FlowElements; may trigger a bounded local packet capture and a user
  notification when enabled.

## Architecture

```
                         AgentRuntimeBridge (actor)
                          ▲  networkHealth snapshot
                          │  networkSentinelControl
   ┌───────────────────┐  │   ┌──────────────────────────┐
   │ NetworkSentinel   │──┘   │ NetworkSentinelCell       │  cell:///agent/network/sentinel
   │ Service (actor)   │◀─────│  get state/events/config  │
   │  native measure   │ ctrl │  set notificationsEnabled │
   │  classify         │      │      / thresholds / ack   │
   │  event lifecycle  │      │  emits FlowElements        │
   └─────────┬─────────┘      └──────────────────────────┘
             │ sink(snapshot, transition)
             ├───────────────▶ cell.emitNetworkEvent(...)   → in-HAVEN FlowElement (.alert/.event)
             └───────────────▶ NetworkAlertNotificationDispatcher → macOS osascript notification
                                          ▲
                                          │ purpose gate
                              NetworkHealthPurposeCatalog
                              (GoalDefinition + GoalEvaluationEngine)
```

The **cell** is the protocol surface only. The **service** does native
measurement. The **dispatcher** delivers the OS notification. The **purpose
catalog** decides salience. This keeps automation/network concerns out of cell
logic.

## Detection (native, no privileges, no subprocess)

`NetworkSentinelService` samples kernel interface counters via `getifaddrs`
(`AF_LINK` / `if_data`) on a fixed cadence and computes per-second deltas for
packets, bytes (in/out) and **interface errors**. No raw sockets, no `sudo`, no
shelling out for the measurement itself.

### Time is monotonic, never wall-clock

Rate math divides counter deltas by the elapsed interval. The interval is taken
from a **monotonic uptime clock** (`DispatchTime.now().uptimeNanoseconds`,
matching `SystemMonotonicTimeSource`), never `Date()`. A wall-clock jump — DST
fall-back, an NTP step, a manual clock change — would otherwise yield a bogus
`dt` and therefore a phantom flood or a missed one. Wall-clock time is used
*only* for human-readable display timestamps, never for any duration.

`ingest(reading:monotonicNanos:wallClock:)` makes this explicit and is the
deterministic test seam.

## Classification & event lifecycle

A sample is "hot" when it crosses any threshold (pps, Mbps, or errors/s). A flood
is collapsed into **one event** with a lifecycle — `started → ongoing →
resolved` — so a sustained condition does not re-alert every sample (a concrete
flaw observed in the prototype).

Classifications:

| class | meaning | harmful? |
|---|---|---|
| `bulkDownload` | high inbound bytes, no errors | no (benign saturation) |
| `bulkUpload` | high outbound bytes | yes |
| `highPacketRate` | very high pps, low byte volume | yes |
| `interfaceDistress` | rising input/output errors | yes |
| `unknown` | none of the above | no |

## Purpose / formål

A flood is not a hardcoded popup. It is turned into a `GoalObservation` and
evaluated against a `GoalDefinition` by the shared `GoalEvaluationEngine`
(`NetworkHealthPurposeCatalog`). The goal **"keep the local link healthy"**
(`purpose://haven.network.health`) becomes:

- `satisfied` — link healthy, or only a *benign* saturation (e.g. a big
  download). No notification.
- `atRisk` — a *harmful* flood is active. **This is what surfaces the alert.**
- `missed` — a harmful flood persists.

Notification (both channels) is gated on the evaluation, and the evaluation
(`purpose`, `goalID`, `goalStatus`, `goalProgress`) rides along in the
FlowElement payload so an in-HAVEN surface sees *why* it matters.

## Notification channels (toggleable)

Controlled by `notificationsEnabled` (authoritative cell state; the audit flow
still emits when muted — only user-facing delivery is silenced).

1. **macOS native** — `NetworkAlertNotificationDispatcher` runs an allowlisted,
   local-only `display notification` AppleScript through `AppleScriptRunner` /
   `AutomationPolicy` (the same sandboxed automation path as the rest of the
   agent). Works whether or not a HAVEN surface is open.
2. **In-HAVEN** — the `.alert` FlowElement on topic `network.health.flood`,
   consumed by Binding/Porthole.

## Evidence capture

On a flood, `BoundedPacketCapture` runs a single `tcpdump` capture bounded by
**both** a packet count (`-c`) and a hard **wall-clock duration** (a monotonic
`Task.sleep` + SIGTERM). It can never hang waiting for packets that stop
arriving. The pcap path is recorded on the event.

## Cell contract

| keypath | access | meaning |
|---|---|---|
| `state` | `r---` | live pps/Mbps/errors, status, active event, thresholds |
| `events` | `r---` | recent flood events |
| `config` | `r---` | `notificationsEnabled` + thresholds |
| `notificationsEnabled` | `rw--` | read/toggle user notifications on/off |
| `thresholds` | `rw--` | adjust pps/Mbps/errors/sustained/resolve |
| `acknowledge` | `rw--` | acknowledge the active event |
| `selectTab` | `rw--` | switch the GUI's active tab (navigation state) |
| `probeTarget` · `probe` | `rw--` | set "host:port" · run on-demand TCP reachability probe |
| `captureNow` | `rw--` | trigger an immediate bounded packet capture |

Reads are gated by `validateAccess` + `LocalControlCellAccess.isPairedOperator`,
like the other agent cells.

The read-only `state` is a single rich, display-ready projection (status text,
formatted metrics, formål/goal status, `navigation.{activeTab,tabs}`, probe and
capture summaries, and nested `events` / `interfaces` / `history` lists) so a GUI
can bind to one subscription.

Flow topics: `network.health` (`.event`) for routine/resolution,
`network.health.flood` (`.alert`) for an active flood.

## Local operation (no staging)

This monitors *this machine's* link, so it runs entirely on the local Mac —
staging is a different network and cannot see your traffic. There is no remote
dependency:

- `AgentCellRuntimeHost.start()` boots the cell + service locally with no scaffold
  and no network (the smoke harness proves this with `enableLiveResolver: false`
  and a stubbed process runner).
- **`haven-agentd network-status [--seconds N]`** runs the measurement engine
  standalone (no bootstrap, no resolver, no network) and prints the live snapshot
  — native interface inventory + real per-second rates from `en0`. Verified on
  the host: `status: calm`, `en0` 349 pk/s / 0 errors, 30 interfaces enumerated.
- **GUI:** the native SwiftUI skeleton renderer in Binding, connected to agentd's
  loopback control bridge (`AgentControlBridgeServer`). The CellConfiguration is
  rendered natively against the local cell — no web Porthole, no staging.
  *Remaining integration:* wiring Binding's renderer/resolver to the loopback
  bridge transport and loading `CellConfiguration.network-sentinel.json` into
  Binding's local Library.

## Configuration

`AgentConfig.networkSentinel` (`NetworkSentinelConfig`) is operator-tunable and
lenient: omit the whole key, or any field, and the built-in defaults apply.

```jsonc
{
  "networkSentinel": {
    "enabled": true,
    "interface": "en0",
    "intervalSeconds": 2.0,
    "notificationsEnabled": true,
    "captureEnabled": true,
    "captureDurationSeconds": 12.0,
    "capturePacketLimit": 20000,
    "captureSnaplen": 160,
    "thresholds": {
      "packetsPerSecond": 12000,
      "megabitsPerSecond": 500.0,
      "errorsPerSecond": 50,
      "sustainedSamples": 2,
      "resolveSamples": 3
    },
    "purpose": "purpose://haven.network.health",
    "goal": "goal.haven.network.health.no-harmful-flood",
    "interests": ["haven.local.network", "haven.local.health", "haven.local.security"]
  }
}
```

Defaults treat **benign high throughput as not a flood** (a saturated link with
no errors is normal); a flood is sustained very high packet rate, or rising
interface errors.

## On-demand tools (beyond passive monitoring)

The cell makes the sensor a more complete network tool:

- **Interface inventory** — native `getifaddrs` enumeration of every interface
  (name, up/down, MAC, IPv4/IPv6).
- **Rolling history** — the last samples, for a trend view.
- **Reachability probe** — `NetworkReachabilityProbe` opens a bounded TCP
  connection (Network framework, monotonic timing) to a `host:port` and reports
  reachability + handshake latency. Set `probeTarget`, then `probe`.
- **Capture now** — `captureNow` fires an immediate `BoundedPacketCapture` (the
  same time+count bounded capture used on a flood), non-blocking.

## GUI (CellConfiguration)

`Docs/CellConfiguration.network-sentinel.json` is a **working skeleton**
(schema-validated by `NetworkSentinelConfigurationTests`: decode + round-trip +
action-target checks). It binds a tabbed surface to `cell:///agent/network/sentinel`:

- **Header card** — status, live metrics, active-event banner, formål/goal status.
- **Tabs** (`Oversikt` / `Enheter` / `Hendelser` / `Verktøy` / `Innstillinger`):
  - Oversikt — live pps/Mbps + trend list (`state.history`).
  - Enheter — interface inventory list (`state.interfaces`).
  - Hendelser — flood events (`state.events`) + "kvitter ut" button.
  - Verktøy — reachability test (`TextField` + `Button` → result) + capture-now.
  - Innstillinger — notifications `Toggle` + thresholds (read-only).

Binding conventions (mirroring the proven conference-dashboard config):
- Display reads use the reference-label keypaths `networkSentinel.state.*`,
  resolving nested into the cell's `state` object.
- Action `Button`s set `url: cell:///agent/network/sentinel` + a bare action
  keypath (`probe`, `captureNow`, `acknowledge`).
- `Tabs` read labels from `state.navigation.tabs`, the active tab from
  `state.navigation.activeTab`, and write selections back via `selectTab`.

UX: dark card theme, sentence-case Norwegian labels, and the formål surfaced so a
benign download reads "Sunt nett" (quiet) while a harmful flood reads "Formål
truet" (alerts).

**Remaining verification:** visual/interaction proof via the Porthole
skeleton-iteration workflow (`npm run skeleton:iterate -- --mode preview
--configurationName "Network Sentinel" --sourceCellEndpoint
cell:///agent/network/sentinel --skeletonFile <file>`). The decode test
guarantees schema validity; Porthole confirms rendering on desktop + mobile.

## Files

Runtime (`HavenAgentRuntime`):
- `NetworkReachabilityProbe.swift` — on-demand TCP reachability probe
- `NetworkHealth.swift` — value types, `NetworkSentinelControlling`, flow topics
- `InterfaceCounters.swift` — native `getifaddrs` reader
- `NetworkSentinelService.swift` — measurement loop (monotonic timing)
- `NetworkAlertNotificationDispatcher.swift` — macOS notification (purpose-gated)
- `NetworkHealthPurposeCatalog.swift` — goal definition + evaluation
- `BoundedPacketCapture.swift` — time + count bounded capture
- `AgentConfig.swift` — `NetworkSentinelConfig`
- `AgentRuntimeBridge.swift` — snapshot + control storage

Cells (`HavenAgentCells`): `NetworkSentinelCell.swift`, registry/blueprint entries.
Host (`HavenAgentCellRuntime`): `AgentCellRuntimeHost.swift` constructs & wires the service.

## Tests

`HavenAgentRuntimeTests`:
- `NetworkSentinelServiceTests` — lifecycle (one event), classification, the
  **monotonic-clock-ignores-wall-jumps** test, notification toggle.
- `NetworkHealthPurposeCatalogTests` — harmful → at-risk/notify, benign →
  satisfied/quiet, unavailable → unknown.
- `BoundedPacketCaptureTests` — missing binary fails fast (no hang).
- `NetworkSentinelConfigTests` — lenient partial decode, defaults, round-trip.
