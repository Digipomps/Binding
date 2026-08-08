import Foundation
import Testing
@testable import HavenAgentRuntime
@testable import HavenMacAutomation

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

private actor ButlerInboxRecordingProcessRunner: ProcessRunning {
    private(set) var arguments: [[String]] = []

    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        self.arguments.append(arguments)
        return SubprocessResult(
            command: [executableURL.path] + arguments,
            terminationStatus: 0,
            standardOutput: "",
            standardError: ""
        )
    }

    func callArguments() -> [[String]] { arguments }
}

@Suite(.serialized)
struct PersonalButlerRemoteIntentInboxTests {
    @Test
    func verifiedWakeIsAuditedAndNotAddedToManualReviewQueue() async throws {
        await PersonalButlerBridgeTestLock.shared.acquire()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("haven-butler-inbox-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let runner = ButlerInboxRecordingProcessRunner()
        let service = PersonalButlerScheduleService(
            fileURL: directoryURL.appendingPathComponent("personal-butler-schedule.json"),
            processRunner: runner
        )
        try await service.start(runWorker: false)
        try await service.configure(PersonalButlerDaemonPreferences(
            ownerApproved: true,
            enabled: true,
            quietHoursEnabled: false,
            appLaunchEnabled: true,
            stagingWakeEnabled: true
        ))

        let privateKey = Curve25519.Signing.PrivateKey()
        let issuerID = "staging.butler.test"
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let payload = SignedRemoteIntentPayload(
            issuerID: issuerID,
            nonce: "butler-signed-wake-\(UUID().uuidString)",
            topic: PersonalButlerScheduleService.remoteWakeTopic,
            origin: "staging",
            actionID: PersonalButlerScheduleService.remoteWakeActionID,
            arguments: ["url": "file:///tmp/not-authority"],
            issuedAt: formatter.string(from: now),
            expiresAt: formatter.string(from: now.addingTimeInterval(300))
        )
        let signature = try privateKey.signature(
            for: RemoteIntentVerifier.canonicalPayloadData(payload)
        )
        let envelope = SignedRemoteIntentEnvelope(
            payload: payload,
            signatureBase64: signature.base64EncodedString()
        )
        let policy = RemoteIntentPolicy(
            issuers: [
                TrustedRemoteIntentIssuer(
                    issuerID: issuerID,
                    publicSigningKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString(),
                    allowedTopics: [PersonalButlerScheduleService.remoteWakeTopic],
                    allowedActionIDs: [PersonalButlerScheduleService.remoteWakeActionID]
                )
            ]
        )

        await AgentRuntimeBridge.shared.resetRemoteIntentState()
        await AgentRuntimeBridge.shared.update(remoteIntentPolicy: policy)
        await AgentRuntimeBridge.shared.update(personalButlerScheduleService: service)
        defer {
            Task {
                await AgentRuntimeBridge.shared.update(personalButlerScheduleService: nil)
                await AgentRuntimeBridge.shared.update(remoteIntentPolicy: nil)
                await AgentRuntimeBridge.shared.resetRemoteIntentState()
                await PersonalButlerBridgeTestLock.shared.release()
            }
        }

        let accepted = try await RemoteIntentInboxService.enqueueSignedEnvelope(envelope)

        #expect(accepted.id == payload.nonce)
        #expect(await AgentRuntimeBridge.shared.queuedIntentSnapshot().isEmpty)
        let audit = try #require(await AgentRuntimeBridge.shared.remoteIntentAuditSnapshot().last)
        #expect(audit.outcome == .automaticDispatched)
        #expect(audit.reviewer == "owner_preapproved_butler_policy")
        #expect(audit.intentID == payload.nonce)
        let calls = await runner.callArguments()
        #expect(calls.count == 1)
        let call = try #require(calls.first)
        #expect(call.joined(separator: " ").contains("file:///tmp/not-authority") == false)

        do {
            _ = try await RemoteIntentInboxService.enqueueSignedEnvelope(envelope)
            Issue.record("Expected replayed wake nonce to be rejected.")
        } catch let error as RemoteIntentVerificationError {
            #expect(error == .replayDetected(payload.nonce))
        }
    }
}

