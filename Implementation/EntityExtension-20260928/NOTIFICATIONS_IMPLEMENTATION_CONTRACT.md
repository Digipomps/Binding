# APNs and browser notifications: implementation contract and release gaps

Status checked 2026-09-28 against Binding `8ce634f6` and CellScaffold `adf48d46`.
This is a source audit and implementation specification, **not a delivery test**.

## Existing code and the concrete missing pieces

- Binding's native registration and callback/ack clients exist and have local
  contract tests. Debug targets staging with a pinned challenge issuer.
- Native `BindingDeviceIngressRolloutPolicy.currentEnabled` is iOS-only; macOS
  returns false. A staging pin in the Mac app does not enable native Mac push.
- Binding Release explicitly sets `HAVEN_DEVICE_INGRESS_ROLLOUT_ENVIRONMENT = disabled`
  and an empty `HAVEN_DEVICE_INGRESS_CHALLENGE_ISSUER_BASE64`. Production enrollment
  cannot work with these settings. Do not fix this by disabling verification or
  copying the staging issuer into production.
- CellScaffold `EnvironmentPushProviderAdapter` routes iOS to APNs and android/web
  to FCM. Missing provider configuration is an explicit failure. Production
  `NotificationOutboxCell` uses this adapter, not the successful no-op test adapter.
- Outbox targets the specified active device or the most recently updated active
  participant registration. This is not an entity-wide preference/availability
  algorithm. Review the existing fallback from a missing explicit device before
  integrating stricter endpoint-selection intent.
- No browser PushManager subscription, application service worker or browser
  enrollment UI was found in main. The FCM `webpush` payload alone is insufficient.
- This audit has not inspected provider secrets, enabled production enrollment,
  sent a notification, or established delivery to a physical device/browser.

## Browser vertical slice

Prefer standards-based Web Push (Push API + Notifications API + service worker)
with an adapter independent of the human identity protocol. FCM is already an
adapter option but does not replace browser enrollment. Evaluate the maintained
Swift WebPush library below before adding it; do not implement payload encryption
or VAPID signing ad hoc.

1. Explicit user gesture enables browser notifications. Show capability and
   installation prerequisites before requesting OS permission. Permission denial
   remains a normal usable state, with another authorized channel available.
2. Install a same-origin service worker and create `PushSubscription` with the
   configured public VAPID key. No identity private key enters the service worker.
3. Register subscription endpoint + p256dh + auth through the existing protected
   owner/requester boundary, bound to the verified human entity context, exact
   origin, browser/device key and stated notification purpose. No participant ID
   or pasted subscription alone confers ownership. Include CSRF/origin protection,
   size limits, replay handling and idempotent registration.
4. Store subscription material privately, encrypted at rest where the runtime
   requires it. Public inventories/diagnostics expose neither endpoint nor token.
5. The server validates allowed HTTPS push-service endpoints, port, redirect policy
   and resolved addresses (including re-resolution) to prevent SSRF. Standard
   encrypted Web Push payloads use a reviewed library and bounded expiry. A 404/410
   deactivates a subscription; transient failures use bounded retry/backoff.
6. Service worker always displays a visible notification; push is not silent
   background synchronization. Neutral lock-screen content is the default.
7. Clicking opens only an allowlisted same-origin inbox/event route. A notification
   click is not a cryptographic approval. Fetch details and authorize actions in
   the ordinary authenticated runtime. No capabilities in the URL.
8. Unsubscribe/revoke closes the server registration and browser subscription;
   logout/account switch cannot rebind an old subscription to another entity.
9. The entity's durable delivery ledger arbitrates attempts across scaffolds.
   Record provider acceptance, receipt/display evidence and user action separately.
   Fallback requires policy and a deadline, not an immediate parallel fanout.

## Acceptance matrix before enabling production

| Flow | Required evidence |
| --- | --- |
| Native APNs | Correct bundle/topic + sandbox/production token; accepted provider request; physical iPhone visible receipt; authorized resolve/action/ack |
| Safari and Chrome on Mac | Explicit subscribe; real external push while page closed; click reaches correct owner-scoped event; unsubscribe |
| iPhone web app | Installed to Home Screen; permission from user gesture; receive/click; no native entitlement assumptions |
| Security | Wrong owner, origin and audience; replay; revoked/expired enrollment; pasted other subscription; malformed token; denied permission; SSRF/redirect rejection |
| Reliability | Token rotation, worker update, browser restart, duplicate event on two scaffolds, provider timeout/410, offline device, expiry, bounded fallback |
| Privacy | No private content in provider payload/logs; account switch; lock screen; endpoint not exposed through Explore |

Existing tests of the transport and callback contracts do not satisfy physical
APNs/browser delivery rows. Production requires its own verified issuer pin,
credentials/topic, release build and recipient enrollment.

## Primary sources checked

- [Apple: sending Web Push](https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers)
- [WebKit: Web Push on iOS/iPadOS](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)
- [Apple: sending APNs requests](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)
- [Firebase: Web enrollment](https://firebase.google.com/docs/cloud-messaging/web/get-started)
- [Swift WebPush source](https://github.com/mochidev/swift-webpush)

Apple documents support in Safari 16/macOS 13 and iOS/iPadOS 16.4 Home Screen web
apps, with user-granted permission. Browser permission is not entity-link consent.
