# Handoff: host-aware WebSocket scheme (ATS -1022)

Date: 2026-08-24
From: Claude (Cowork session, working on Binding)
To: Codex (local, on Kjetil's Mac)

## What happened

HAVEN failed to open `ArendalsukaParticipantProgram` with:

    NSURLErrorDomain Code=-1022 "The resource could not be loaded because the
    App Transport Security policy requires the use of a secure connection."
    http://haven.digipomps.org/bridgehead/ArendalsukaParticipantProgram/68766AAD-...

It is not an HTTP fetch. It is a CellProtocol bridgehead WebSocket; URLSession
reports ATS failures on a ws task using the http:// form of the URL. ATS blocked
a cleartext `ws://` connection to a public host, correctly.

## Root cause, two layers

1. **CellProtocol.** `RemoteCellHostRoute.SchemePreference.automatic` resolved as
   `CellBase.allowsInsecureWebSockets ? "ws" : "wss"` with no knowledge of the
   host. That flag is DEBUG-only and intended for loopback development, but it
   downgraded *every* remote host to cleartext in debug builds.
2. **Binding.** There was no rule, only a hardcoded allowlist: only
   `staging.haven.digipomps.org` got `.wss`; everything else fell through to
   `.automatic`. `haven.digipomps.org` (production, the applinks domain) was not
   on the list.

## The rule now

Cleartext `ws` only for loopback (`127.0.0.1`, `::1`, `[::1]`, `localhost`, and
`.local` in CellProtocol). Everything else is `wss`, regardless of build
configuration. A rule about the host, not a list of known hosts.

## State of the work

**Layer 1 — CellProtocol — DONE by Codex, unverified.**
`Sources/CellBase/Cells/CellResolver/CellResolver.swift`: new private
`allowsAutomaticInsecureWebSocket(for:)`, both `.automatic` sites route through
it, and `remoteWebSocketScheme(for:endpoint:)` gained a `host:` parameter with
all four call sites updated. No test added yet. Uncommitted.

**Layer 2 — Binding — DONE by Claude, unverified.**
- `Binding/RemoteCatalogSupport.swift`: `defaultRemoteRoute`/`stagingRemoteRoute`
  replaced by `loopbackRemoteRoute` (`.automatic`) and `secureRemoteRoute`
  (`.wss`); `route(forHost:)` is now `isLoopbackHost(host) ? loopback : secure`;
  `isLoopbackHost` is internal and covers `::1`/`[::1]`; new
  `websocketScheme(forHost:)`. An explicit `ws://` endpoint to a non-loopback
  host is now upgraded to `wss` instead of attempted in cleartext.
- `Binding/ContentView.swift`: `remoteRoute(forHost:)`, `catalogOrigin` and the
  staging fallback in `tryProbeEndpointWithFallbackRoutes` all delegate to
  `RemoteEndpointAccessSupport`; four now-unused constants removed.
- `BindingTests/BindingTests.swift`: two new tests —
  `remoteRoutesNeverDowngradeAPublicHostToCleartext` and
  `explicitCleartextEndpointsAreUpgradedUnlessTheyAreLoopback`.

## What is asked of Codex

Nothing has been compiled. The Cowork VM has no Swift toolchain, so layer 2 was
written without a compiler. Please:

1. Add the missing CellProtocol test (see the task list below) and run it.
2. Build Binding and run the Binding tests, including the two new ones.
3. Fix whatever does not compile or does not pass, in either repo.
4. Report back in the file named at the end.

## Constraints

- Both worktrees are dirty with unrelated in-progress work (EntityRadar/Nearby in
  CellProtocol; several files in Binding). Do NOT stage, commit, revert or
  overwrite anything you did not change yourself.
- Smallest possible diff. No unrelated refactors, no reformatting.
- If a behaviour change is needed that goes beyond the rule above, stop and write
  it in the report as an open question rather than deciding it alone.

## Open question to check

Two Codex sessions may have been launched against layer 1 by mistake (the MCP
call timed out twice at 60s before the caller noticed). The diff in
CellResolver.swift looks like a single coherent change, but please confirm there
is no duplicated helper or half-applied second edit.
