import Foundation
import Testing
@testable import HavenAgentRuntime

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

struct RemoteIntentVerifierTests {
    @Test
    func verifiesSignedEnvelopeAgainstTrustedIssuer() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let payload = SignedRemoteIntentPayload(
            issuerID: "trusted.issuer",
            nonce: "nonce-verify-1",
            topic: "intent.inbox",
            origin: "trusted.issuer",
            actionID: "open-url-in-safari",
            arguments: ["url": "https://example.com"],
            issuedAt: "2026-03-13T09:00:00Z",
            expiresAt: "2026-03-13T09:05:00Z"
        )
        let signature = try privateKey.signature(for: RemoteIntentVerifier.canonicalPayloadData(payload))
        let envelope = SignedRemoteIntentEnvelope(
            payload: payload,
            signatureBase64: signature.base64EncodedString()
        )
        let policy = RemoteIntentPolicy(
            issuers: [
                TrustedRemoteIntentIssuer(
                    issuerID: "trusted.issuer",
                    publicSigningKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString(),
                    allowedTopics: ["intent.inbox"],
                    allowedActionIDs: ["open-url-in-safari"]
                )
            ],
            requireExpiry: true,
            maxClockSkewSeconds: 60,
            maxArgumentCount: 8
        )

        let intent = try RemoteIntentVerifier.verify(
            envelope: envelope,
            policy: policy,
            now: ISO8601DateFormatter().date(from: "2026-03-13T09:01:00Z") ?? Date()
        )

        #expect(intent.id == "nonce-verify-1")
        #expect(intent.verificationStatus == "verified")
        #expect(intent.issuerID == "trusted.issuer")
    }

    @Test
    func rejectsEnvelopeFromUntrustedIssuer() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let payload = SignedRemoteIntentPayload(
            issuerID: "unknown.issuer",
            nonce: "nonce-verify-2",
            topic: "intent.inbox",
            origin: "unknown.issuer",
            actionID: "open-url-in-safari",
            arguments: [:],
            issuedAt: "2026-03-13T09:00:00Z",
            expiresAt: "2026-03-13T09:05:00Z"
        )
        let signature = try privateKey.signature(for: RemoteIntentVerifier.canonicalPayloadData(payload))
        let envelope = SignedRemoteIntentEnvelope(
            payload: payload,
            signatureBase64: signature.base64EncodedString()
        )
        let policy = RemoteIntentPolicy(
            issuers: [
                TrustedRemoteIntentIssuer(
                    issuerID: "trusted.issuer",
                    publicSigningKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString(),
                    allowedTopics: ["intent.inbox"],
                    allowedActionIDs: ["open-url-in-safari"]
                )
            ]
        )

        do {
            _ = try RemoteIntentVerifier.verify(
                envelope: envelope,
                policy: policy,
                now: ISO8601DateFormatter().date(from: "2026-03-13T09:01:00Z") ?? Date()
            )
            Issue.record("Expected untrusted issuer verification to fail.")
        } catch let error as RemoteIntentVerificationError {
            #expect(error == .untrustedIssuer("unknown.issuer"))
        }
    }
}
