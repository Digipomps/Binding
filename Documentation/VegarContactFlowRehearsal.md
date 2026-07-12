# Vegar contact-flow rehearsal

Date: 2026-07-11
Status: local two-identity rehearsal implemented; real remote transport not yet verified

## Purpose

Prepare the complete HAVEN contact-invitation lifecycle without contacting a
real recipient. The rehearsal uses two vault-backed identities and the same
`ContactEndpoint` ticket contract intended for a later two-installation test.

## Implemented lifecycle

1. The sender selects a public-safe contact descriptor.
2. `PersonalChatHub.invite` creates and signs a
   `cellprotocol.contact.request.v1` request.
3. The recipient's `ContactEndpoint` validates the signed request and returns a
   ticket receipt.
4. The recipient refreshes `contactInbox`, selects the ticket, and explicitly
   accepts or declines it.
5. `ContactEndpoint.ticket.respond` stores the response.
6. The original signing identity reads only the public ticket status through
   `ContactEndpoint.ticket.status`.
7. The sender refreshes outgoing invitations and sees a human-readable
   accepted, declined, expired, or waiting state.

The focused test covers both accepted and declined outcomes.

## Security boundaries

- The contact request is signed by the sender's vault-backed identity.
- A ticket status is returned only when the runtime requester hashes to the
  identity that signed the original request.
- The status response does not expose the recipient's private request payload.
- A foreign requester cannot submit `ticket.respond` without Resolver access.
- Selecting an inbox row has no outward side effect. Accept or decline is a
  separate action.
- A bootstrap draft is explicitly non-authoritative. Possession of the draft,
  a link, or a future QR payload must never grant access.

## Recipient without a ContactEndpoint

Binding now creates a local `haven.contact.bootstrap-draft.v1` object. It is:

- marked `not_sent`
- marked `authority=false`
- limited to seven days
- explicit that recipient enrollment is required
- explicit that a fresh signed contact request is required after enrollment

No email, message, deep link, or notification is sent automatically.

## Real rehearsal checklist

The real test should use two separate HAVEN installations or processes:

1. Confirm both installations use distinct vault-backed identities.
2. Publish the recipient's public-safe ContactEndpoint descriptor.
3. Confirm the descriptor routes to the recipient's remote bridgehead, not the
   sender's local identity-unique cell.
4. Send one invitation and record the returned ticket ID.
5. Refresh the recipient inbox and verify the sender display name and title.
6. Accept once; verify the sender observes `accepted` after status refresh.
7. Send a second invitation and decline it; verify the sender observes
   `declined`.
8. Retry the original signed request and verify replay rejection.
9. Query the ticket using a third identity and verify requester mismatch or
   Resolver denial.
10. Restart both installations and confirm persisted endpoint, ticket, inbox,
    and outgoing-invite state remain consistent.

## Remaining implementation boundary

The local rehearsal does not prove remote `cell://host/ContactEndpoint`
routing, WebSocket/TLS bridge admission, notification delivery, or persistence
across two independently running scaffolds. Those are the only reasons a real
recipient or second installation is still needed.

Binding now obtains a canonical `IdentityDomainBinding` from the active identity
vault, includes the domain and binding inside the signed contact request, and
validates UUID, signing-key fingerprint, and domain consistency before applying
an endpoint's allow/block policy. A domain-policy request fails closed when the
binding is absent, ambiguous, or invalid. Endpoints without domain policy remain
compatible with older signed requests.

The binding is context evidence only (`grantsAuthority = false`). It is not a
membership credential or capability; Resolver, Agreement, Contract, purpose,
and explicit grant checks remain authoritative. The local rehearsal still does
not prove a remote vault or organization trust chain beyond the requester's
signed identity, so any stronger domain claim must travel as separately trusted
proof material.
