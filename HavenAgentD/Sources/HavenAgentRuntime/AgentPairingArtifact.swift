import Foundation
import CryptoKit
import SproutCrypto

public struct PairedOperatorIdentity: Codable, Equatable, Sendable {
    public var pairingID: String
    public var scaffoldDomain: String
    public var purposeRef: String
    public var operatorIdentityUUID: String
    public var operatorDid: String
    public var operatorPublicKeyBase64URL: String
    public var approvedAt: String

    public init(
        pairingID: String,
        scaffoldDomain: String,
        purposeRef: String,
        operatorIdentityUUID: String,
        operatorDid: String,
        operatorPublicKeyBase64URL: String,
        approvedAt: String
    ) {
        self.pairingID = pairingID
        self.scaffoldDomain = scaffoldDomain
        self.purposeRef = purposeRef
        self.operatorIdentityUUID = operatorIdentityUUID
        self.operatorDid = operatorDid
        self.operatorPublicKeyBase64URL = operatorPublicKeyBase64URL
        self.approvedAt = approvedAt
    }
}

public enum AgentPairingArtifactError: Error, LocalizedError, Sendable {
    case invalidVersion
    case invalidVerificationStatus
    case inconsistentPairingID
    case inconsistentOperatorIdentity
    case inconsistentPurpose
    case inconsistentScaffoldDomain
    case inconsistentChallenge
    case invalidOperatorSignature
    case invalidAgentAttestationSignature

    public var errorDescription: String? {
        switch self {
        case .invalidVersion:
            return "Pairing artifact version is unsupported."
        case .invalidVerificationStatus:
            return "Pairing artifact verification status is invalid."
        case .inconsistentPairingID:
            return "Pairing artifact pairing identifiers do not match."
        case .inconsistentOperatorIdentity:
            return "Pairing artifact operator identity does not match the agent attestation."
        case .inconsistentPurpose:
            return "Pairing artifact purpose does not match the agent attestation."
        case .inconsistentScaffoldDomain:
            return "Pairing artifact scaffold domain does not match the agent attestation."
        case .inconsistentChallenge:
            return "Pairing artifact challenge does not match the agent attestation."
        case .invalidOperatorSignature:
            return "Pairing artifact operator approval signature did not verify."
        case .invalidAgentAttestationSignature:
            return "Pairing artifact agent attestation signature did not verify."
        }
    }
}

public enum AgentPairingArtifactLoader {
    public static func loadPairedOperator(from fileURL: URL) throws -> PairedOperatorIdentity? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let artifact = try JSONDecoder().decode(PairingArtifact.self, from: Data(contentsOf: fileURL))
        try artifact.verify()
        return PairedOperatorIdentity(
            pairingID: artifact.pairingID,
            scaffoldDomain: artifact.operatorApproval.payload.scaffoldDomain,
            purposeRef: artifact.operatorApproval.payload.purposeRef,
            operatorIdentityUUID: artifact.operatorApproval.payload.operatorIdentityUUID,
            operatorDid: artifact.operatorApproval.payload.operatorDid,
            operatorPublicKeyBase64URL: artifact.operatorApproval.payload.operatorPublicKeyBase64URL,
            approvedAt: artifact.operatorApproval.payload.approvedAt
        )
    }
}

private struct PairingArtifact: Codable {
    struct AgentEnrollmentAttestation: Codable {
        struct Payload: Codable {
            var version: String
            var instanceName: String
            var agentIdentityUUID: String
            var agentDisplayName: String
            var agentDid: String
            var agentPublicKeyBase64URL: String
            var operatorIdentityUUID: String
            var operatorDid: String
            var operatorPublicKeyBase64URL: String
            var purposeRef: String
            var scaffoldDomain: String
            var challenge: String
            var issuedAt: String
        }

        var payload: Payload
        var signatureAlgorithm: String
        var signatureBase64URL: String

        func canonicalPayloadData() throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(payload)
        }
    }

    struct OperatorApproval: Codable {
        struct Payload: Codable {
            var version: String
            var pairingID: String
            var scaffoldDomain: String
            var purposeRef: String
            var challenge: String
            var attestationSHA256Base64URL: String
            var operatorIdentityUUID: String
            var operatorDisplayName: String
            var operatorDid: String
            var operatorPublicKeyBase64URL: String
            var approvedAt: String
        }

        var payload: Payload
        var signatureBase64: String
        var curveType: String

        func canonicalPayloadData() throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(payload)
        }
    }

    var version: String
    var pairingID: String
    var recordedAt: String
    var verificationStatus: String
    var agentAttestation: AgentEnrollmentAttestation
    var operatorApproval: OperatorApproval

    func verify() throws {
        guard version == "1.0",
              agentAttestation.payload.version == "1.0",
              operatorApproval.payload.version == "1.0" else {
            throw AgentPairingArtifactError.invalidVersion
        }
        guard verificationStatus == "agent-attestation-verified" else {
            throw AgentPairingArtifactError.invalidVerificationStatus
        }
        guard pairingID == operatorApproval.payload.pairingID else {
            throw AgentPairingArtifactError.inconsistentPairingID
        }
        guard agentAttestation.payload.operatorIdentityUUID == operatorApproval.payload.operatorIdentityUUID,
              agentAttestation.payload.operatorDid == operatorApproval.payload.operatorDid,
              agentAttestation.payload.operatorPublicKeyBase64URL == operatorApproval.payload.operatorPublicKeyBase64URL else {
            throw AgentPairingArtifactError.inconsistentOperatorIdentity
        }
        guard agentAttestation.payload.purposeRef == operatorApproval.payload.purposeRef else {
            throw AgentPairingArtifactError.inconsistentPurpose
        }
        guard agentAttestation.payload.scaffoldDomain == operatorApproval.payload.scaffoldDomain else {
            throw AgentPairingArtifactError.inconsistentScaffoldDomain
        }
        guard agentAttestation.payload.challenge == operatorApproval.payload.challenge else {
            throw AgentPairingArtifactError.inconsistentChallenge
        }

        let operatorPublicKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: Base64URL.decode(operatorApproval.payload.operatorPublicKeyBase64URL)
        )
        let operatorSignature = Data(base64Encoded: operatorApproval.signatureBase64) ?? Data()
        guard operatorPublicKey.isValidSignature(operatorSignature, for: try operatorApproval.canonicalPayloadData()) else {
            throw AgentPairingArtifactError.invalidOperatorSignature
        }

        let agentPublicKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: Base64URL.decode(agentAttestation.payload.agentPublicKeyBase64URL)
        )
        let agentSignature = try Base64URL.decode(agentAttestation.signatureBase64URL)
        guard agentPublicKey.isValidSignature(agentSignature, for: try agentAttestation.canonicalPayloadData()) else {
            throw AgentPairingArtifactError.invalidAgentAttestationSignature
        }
    }
}
