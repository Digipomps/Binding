# Person Entity read client — local implementation checkpoint

Based on Binding b12b0414eefdd13088d0cefb522d0cc6fd0d36fe with its unchanged
CellProtocol pin 436b6a77d42da1317e71f3024dfc0d3e18de796f. Work is isolated in
`/private/tmp/entity-fabric-binding-client`; the identity-link task's active
checkout, ceremony/scanner/outbox and signed pilot have not been modified.
The source task's cancellation fix and UI-fixture isolation were fast-forwarded
from b12b0414 before adding this client's checkpoint; source reports its 12/12
identity-link tests passed. The old 3a41745f IPA is not a final device candidate.

The new client is not connected to a UI or enabled against production. Its
server counterpart is local work after CellScaffold 195c5f01, not a deployed
route. No build, typecheck, real handshake or device data journey is claimed.
Swift parser/diff checks pass, and the mirrored wire contract matches the
server source after only module and namespace substitutions.

`PersonEntityReadClient.connect(entry:)` requires an explicitly selected saved
receipt, trusted HTTPS origin, matching historical request/approval/VC/VP
signatures, same_entity scope, scaffold domain and the exact existing local
UUID/signing key/vault. Historical validation is not current server permission.
The default existing-key resolver uses BindingStartupIdentityVault without
provisioning. That vault is in memory: after relaunch a missing original key
must be reported as unavailable, never replaced or normalized into another key.

The client signs separate discovery and open challenges. It validates the
authenticated descriptor's evidence/link/key/origin/request digest, exact three
roles/domains/Cell UUIDs, short expiry and connection lifetime before supplying
those scopes to BridgeBase. The proof travels in a header, not a URL. HTTP and
WebSocket networking are ephemeral with no cookies, redirects or shared caches;
requests, responses and connection lifetime are bounded. Concurrent or cancelled
connect attempts cannot silently replace an active connection. Closing resets
core bridge proof scopes and releases transport registrations.

The actual pinned BridgeBase correlates SET responses by keypath, so the
client permits only one in-flight entityData.query per connection. It rejects
an overlapping call as busy, checks cancellation before work and discards a
reply if close/reconnect or expiry occurred while awaiting it. This source-
grounded guard is syntax-checked only; client concurrency/runtime proof remains
part of the unexecuted integration requirements below.

The local connection deadline starts before socket setup; time spent fetching
the remote description cannot extend it. A close observed after signing but
before route discovery also prevents starting that HTTP request. An already
sent metadata request can still finish under its short HTTP timeout, but its
result cannot activate a cancelled/replaced connection.

AppleBridgeTransport cannot safely supply this header merely by injecting a
connection: setup replaces the connection and sets private local-vault state,
while skipping setup omits that state. The new app transport therefore uses
the existing BridgeInboundPayloadValidator, BridgeBase, BridgeCommand and
BridgeIdentityVault with the exact local signing key's real vault. It neither
reimplements resolver policy nor broadens signing authorization.

Four unexecuted client tests cover a missing post-relaunch key, another key,
changed evidence reference and descriptor binding failures. Required remaining
proofs include an actual production-route process handshake, client signing
over that connection, repeat reads/revoke/close/reconnect, bounds and shutdown,
actual Binding builds/tests and UI integration with source origin and honest
partial/unavailable/denied status. A current signed device ceremony and exact
staging journey are required before any release claim.

This is one-direction reading only. It provides no person-authorized journalled
write, reciprocal identity, retained index, storage grant or migration authority.
