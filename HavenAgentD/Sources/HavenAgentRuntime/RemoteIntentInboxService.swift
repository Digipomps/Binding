import Foundation

public enum RemoteIntentInboxService {
    @discardableResult
    public static func enqueueSignedEnvelope(_ envelope: SignedRemoteIntentEnvelope) async throws -> QueuedRemoteIntent {
        guard let policy = await AgentRuntimeBridge.shared.remoteIntentPolicySnapshot() else {
            throw RemoteIntentVerificationError.policyUnavailable
        }

        let intent = try RemoteIntentVerifier.verify(envelope: envelope, policy: policy)
        let nonceWasNew = await AgentRuntimeBridge.shared.recordRemoteIntentNonceIfNew(intent.id)
        guard nonceWasNew else {
            throw RemoteIntentVerificationError.replayDetected(intent.id)
        }

        if let scheduleService = await AgentRuntimeBridge.shared.personalButlerScheduleServiceSnapshot() {
            let outcome = await scheduleService.handleRemoteWake(intent: intent)
            if outcome != .notApplicable {
                let audit = makeAutomaticAuditRecord(intent: intent, outcome: outcome)
                await AgentRuntimeBridge.shared.appendRemoteIntentAuditRecord(audit)
                return intent
            }
        } else if intent.actionID == PersonalButlerScheduleService.remoteWakeActionID {
            let audit = makeAutomaticAuditRecord(
                intent: intent,
                outcome: .suppressed("daemon_schedule_unavailable")
            )
            await AgentRuntimeBridge.shared.appendRemoteIntentAuditRecord(audit)
            return intent
        }

        await AgentRuntimeBridge.shared.enqueue(intent: intent)
        return intent
    }

    private static func makeAutomaticAuditRecord(
        intent: QueuedRemoteIntent,
        outcome: PersonalButlerWakeOutcome
    ) -> RemoteIntentAuditRecord {
        let auditOutcome: RemoteIntentAuditOutcome
        let note: String?
        let errorMessage: String?
        switch outcome {
        case .launched:
            auditOutcome = .automaticDispatched
            note = "Fixed HAVEN wake dispatched under the owner-approved Butler policy."
            errorMessage = nil
        case .suppressed(let reason):
            auditOutcome = .automaticSuppressed
            note = "Fixed HAVEN wake suppressed by local Butler policy: \(reason)."
            errorMessage = nil
        case .failed(let message):
            auditOutcome = .automaticFailed
            note = "Fixed HAVEN wake failed after local policy approval."
            errorMessage = message
        case .notApplicable:
            auditOutcome = .automaticSuppressed
            note = "Intent was not applicable to the Butler wake handler."
            errorMessage = nil
        }
        return RemoteIntentAuditRecord(
            intentID: intent.id,
            actionID: intent.actionID,
            issuerID: intent.issuerID,
            verificationStatus: intent.verificationStatus,
            outcome: auditOutcome,
            reviewer: "owner_preapproved_butler_policy",
            note: note,
            recordedAt: ISO8601DateFormatter().string(from: Date()),
            errorMessage: errorMessage
        )
    }
}
