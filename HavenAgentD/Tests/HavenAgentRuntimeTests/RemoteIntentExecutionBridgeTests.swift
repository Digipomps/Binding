import Foundation
import Testing
@testable import HavenAgentRuntime
@testable import HavenMacAutomation

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

private actor RemoteIntentExecutionRecordingRunner: ProcessRunning {
    private(set) var calls: [(URL, [String])] = []

    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        calls.append((executableURL, arguments))
        return SubprocessResult(
            command: [executableURL.path] + arguments,
            terminationStatus: 0,
            standardOutput: "ok",
            standardError: ""
        )
    }

    func callCount() -> Int {
        calls.count
    }
}

struct RemoteIntentExecutionBridgeTests {
    @Test
    func executionRevalidatesExpiryAndDoesNotLaunchExpiredIntent() async throws {
        let fixture = try makeFixture()
        let runner = RemoteIntentExecutionRecordingRunner()
        let afterExpiry = try #require(
            ISO8601DateFormatter().date(from: "2026-03-13T09:07:00Z")
        )
        let bridge = await makeBridge(
            runner: runner,
            policy: fixture.policy,
            now: afterExpiry
        )

        await #expect(throws: RemoteIntentVerificationError.envelopeExpired) {
            _ = try await bridge.execute(intent: fixture.intent)
        }
        #expect(await runner.callCount() == 0)
    }

    @Test
    func executionRevalidatesSignatureAndDoesNotLaunchTamperedIntent() async throws {
        let fixture = try makeFixture()
        var tamperedIntent = fixture.intent
        tamperedIntent.arguments["inputPath"] = "/tmp/tampered"
        let runner = RemoteIntentExecutionRecordingRunner()
        let bridge = await makeBridge(
            runner: runner,
            policy: fixture.policy,
            now: fixture.admissionTime
        )

        await #expect(throws: RemoteIntentVerificationError.invalidSignature) {
            _ = try await bridge.execute(intent: tamperedIntent)
        }
        #expect(await runner.callCount() == 0)
    }

    @Test
    func executionUsesCurrentIssuerPolicyAndDoesNotLaunchRevokedAction() async throws {
        let fixture = try makeFixture()
        var issuer = try #require(fixture.policy.issuers.first)
        issuer.allowedActionIDs = ["some-other-action"]
        let currentPolicy = RemoteIntentPolicy(
            issuers: [issuer],
            requireExpiry: true,
            maxClockSkewSeconds: 60,
            maxArgumentCount: 8
        )
        let runner = RemoteIntentExecutionRecordingRunner()
        let bridge = await makeBridge(
            runner: runner,
            policy: currentPolicy,
            now: fixture.admissionTime
        )

        await #expect(throws: RemoteIntentVerificationError.actionNotAllowed("run-approved-shortcut")) {
            _ = try await bridge.execute(intent: fixture.intent)
        }
        #expect(await runner.callCount() == 0)
    }

    @Test
    func executionUsesCurrentIssuerTrustAndDoesNotLaunchRemovedIssuer() async throws {
        let fixture = try makeFixture()
        let runner = RemoteIntentExecutionRecordingRunner()
        let bridge = await makeBridge(
            runner: runner,
            policy: RemoteIntentPolicy(issuers: []),
            now: fixture.admissionTime
        )

        await #expect(throws: RemoteIntentVerificationError.untrustedIssuer("trusted.issuer")) {
            _ = try await bridge.execute(intent: fixture.intent)
        }
        #expect(await runner.callCount() == 0)
    }

    private func makeBridge(
        runner: RemoteIntentExecutionRecordingRunner,
        policy: RemoteIntentPolicy,
        now: Date
    ) async -> RemoteIntentExecutionBridge {
        let bridge = RemoteIntentExecutionBridge(
            processRunner: runner,
            verificationNow: { now },
            verificationPolicyProvider: { policy }
        )
        await bridge.update(
            policy: AutomationPolicy(
                shortcuts: [
                    ShortcutDefinition(
                        id: "run-approved-shortcut",
                        shortcutName: "HAVEN Approved Shortcut",
                        acceptsInputPath: true,
                        allowedForRemoteExecution: true
                    )
                ]
            )
        )
        return bridge
    }

    private func makeFixture() throws -> (
        intent: QueuedRemoteIntent,
        policy: RemoteIntentPolicy,
        admissionTime: Date
    ) {
        let privateKey = Curve25519.Signing.PrivateKey()
        let admissionTime = try #require(
            ISO8601DateFormatter().date(from: "2026-03-13T09:01:00Z")
        )
        let payload = SignedRemoteIntentPayload(
            issuerID: "trusted.issuer",
            nonce: "nonce-execution-fixture",
            topic: "intent.inbox",
            origin: "trusted.issuer",
            actionID: "run-approved-shortcut",
            arguments: [:],
            issuedAt: "2026-03-13T09:00:00Z",
            expiresAt: "2026-03-13T09:05:00Z"
        )
        let envelope = SignedRemoteIntentEnvelope(
            payload: payload,
            signatureBase64: try privateKey.signature(
                for: RemoteIntentVerifier.canonicalPayloadData(payload)
            ).base64EncodedString()
        )
        let policy = RemoteIntentPolicy(
            issuers: [
                TrustedRemoteIntentIssuer(
                    issuerID: payload.issuerID,
                    publicSigningKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString(),
                    allowedTopics: [payload.topic],
                    allowedActionIDs: [payload.actionID]
                )
            ],
            requireExpiry: true,
            maxClockSkewSeconds: 60,
            maxArgumentCount: 8
        )
        return (
            try RemoteIntentVerifier.verify(
                envelope: envelope,
                policy: policy,
                now: admissionTime
            ),
            policy,
            admissionTime
        )
    }
}
