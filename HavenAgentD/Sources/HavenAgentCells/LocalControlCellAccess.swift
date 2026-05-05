import Foundation
import CellBase
import HavenAgentRuntime
import SproutCrypto

enum LocalControlCellAccess {
    static func allowsIdentityDiscovery(_ requester: Identity) -> Bool {
        requester.publicSecureKey?.compressedKey != nil
    }

    static func allowsEnrollmentAttestation(
        requester: Identity,
        claimedOperatorPublicKeyBase64URL: String
    ) -> Bool {
        guard let requesterPublicKey = requester.publicSecureKey?.compressedKey else {
            return false
        }
        return Base64URL.encode(requesterPublicKey) == claimedOperatorPublicKeyBase64URL
    }

    static func isPairedOperator(_ requester: Identity) async -> Bool {
        guard let requesterPublicKey = requester.publicSecureKey?.compressedKey else {
            return false
        }
        guard let pairedOperator = await AgentRuntimeBridge.shared.pairedOperatorSnapshot(refresh: true) else {
            return false
        }
        return pairedOperator.operatorPublicKeyBase64URL == Base64URL.encode(requesterPublicKey)
    }
}
