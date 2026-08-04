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
        #expect(intent.signatureBase64 == signature.base64EncodedString())
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

    @Test
    func rejectsIssuerWithEmptyAllowedTopics() throws {
        let fixture = try makeFixture(
            issuer: TrustedRemoteIntentIssuer(
                issuerID: "trusted.issuer",
                publicSigningKeyBase64: "",
                allowedTopics: [],
                allowedActionIDs: ["open-url-in-safari"]
            )
        )
        var issuer = fixture.policy.issuers[0]
        issuer.publicSigningKeyBase64 = fixture.publicKeyBase64
        let policy = RemoteIntentPolicy(issuers: [issuer])

        #expect(throws: RemoteIntentVerificationError.issuerTopicsNotConfigured("trusted.issuer")) {
            _ = try RemoteIntentVerifier.verify(
                envelope: fixture.envelope,
                policy: policy,
                now: fixture.admissionTime
            )
        }
    }

    @Test
    func rejectsIssuerWithEmptyAllowedActions() throws {
        let fixture = try makeFixture(
            issuer: TrustedRemoteIntentIssuer(
                issuerID: "trusted.issuer",
                publicSigningKeyBase64: "",
                allowedTopics: ["intent.inbox"],
                allowedActionIDs: []
            )
        )
        var issuer = fixture.policy.issuers[0]
        issuer.publicSigningKeyBase64 = fixture.publicKeyBase64
        let policy = RemoteIntentPolicy(issuers: [issuer])

        #expect(throws: RemoteIntentVerificationError.issuerActionsNotConfigured("trusted.issuer")) {
            _ = try RemoteIntentVerifier.verify(
                envelope: fixture.envelope,
                policy: policy,
                now: fixture.admissionTime
            )
        }
    }

    @Test
    func rejectsDuplicateIssuerConfiguration() throws {
        let fixture = try makeFixture()
        let issuer = try #require(fixture.policy.issuers.first)
        let policy = RemoteIntentPolicy(issuers: [issuer, issuer])

        #expect(throws: RemoteIntentVerificationError.ambiguousIssuer("trusted.issuer")) {
            _ = try RemoteIntentVerifier.verify(
                envelope: fixture.envelope,
                policy: policy,
                now: fixture.admissionTime
            )
        }
    }

    @Test
    func queuedIntentReverificationRejectsTamperedPayload() throws {
        let fixture = try makeFixture()
        var intent = try RemoteIntentVerifier.verify(
            envelope: fixture.envelope,
            policy: fixture.policy,
            now: fixture.admissionTime
        )
        intent.arguments["url"] = "https://attacker.example"

        #expect(throws: RemoteIntentVerificationError.invalidSignature) {
            _ = try RemoteIntentVerifier.reverifyQueuedIntent(
                intent,
                policy: fixture.policy,
                now: fixture.admissionTime
            )
        }
    }

    @Test
    func queuedIntentReverificationRejectsLegacyVerifiedStatusWithoutSignature() throws {
        let fixture = try makeFixture()
        let intent = QueuedRemoteIntent(
            id: fixture.envelope.payload.nonce,
            topic: fixture.envelope.payload.topic,
            origin: fixture.envelope.payload.origin,
            actionID: fixture.envelope.payload.actionID,
            arguments: fixture.envelope.payload.arguments,
            receivedAt: ISO8601DateFormatter().string(from: fixture.admissionTime),
            issuerID: fixture.envelope.payload.issuerID,
            issuedAt: fixture.envelope.payload.issuedAt,
            expiresAt: fixture.envelope.payload.expiresAt,
            verificationStatus: "verified"
        )

        #expect(throws: RemoteIntentVerificationError.invalidPayload("queuedIntent.signatureBase64")) {
            _ = try RemoteIntentVerifier.reverifyQueuedIntent(
                intent,
                policy: fixture.policy,
                now: fixture.admissionTime
            )
        }
    }

    private func makeFixture(
        issuer suppliedIssuer: TrustedRemoteIntentIssuer? = nil
    ) throws -> (
        envelope: SignedRemoteIntentEnvelope,
        policy: RemoteIntentPolicy,
        admissionTime: Date,
        publicKeyBase64: String
    ) {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()
        let admissionTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-13T09:01:00Z")
        )
        let payload = SignedRemoteIntentPayload(
            issuerID: "trusted.issuer",
            nonce: "nonce-fixture",
            topic: "intent.inbox",
            origin: "trusted.issuer",
            actionID: "open-url-in-safari",
            arguments: ["url": "https://example.com"],
            issuedAt: "2026-03-13T09:00:00Z",
            expiresAt: "2026-03-13T09:05:00Z"
        )
        let signature = try privateKey.signature(
            for: RemoteIntentVerifier.canonicalPayloadData(payload)
        )
        let issuer = suppliedIssuer ?? TrustedRemoteIntentIssuer(
            issuerID: payload.issuerID,
            publicSigningKeyBase64: publicKeyBase64,
            allowedTopics: [payload.topic],
            allowedActionIDs: [payload.actionID]
        )
        return (
            SignedRemoteIntentEnvelope(
                payload: payload,
                signatureBase64: signature.base64EncodedString()
            ),
            RemoteIntentPolicy(issuers: [issuer]),
            admissionTime,
            publicKeyBase64
        )
    }
}
