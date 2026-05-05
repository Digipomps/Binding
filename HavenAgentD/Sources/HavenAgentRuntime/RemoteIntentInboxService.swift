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

        await AgentRuntimeBridge.shared.enqueue(intent: intent)
        return intent
    }
}
