import Foundation

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public struct TrustedRemoteIntentIssuer: Codable, Equatable, Sendable {
    public var issuerID: String
    public var publicSigningKeyBase64: String
    public var allowedTopics: [String]
    public var allowedActionIDs: [String]

    public init(
        issuerID: String,
        publicSigningKeyBase64: String,
        allowedTopics: [String] = [],
        allowedActionIDs: [String] = []
    ) {
        self.issuerID = issuerID
        self.publicSigningKeyBase64 = publicSigningKeyBase64
        self.allowedTopics = allowedTopics
        self.allowedActionIDs = allowedActionIDs
    }
}

public struct RemoteIntentPolicy: Codable, Equatable, Sendable {
    public var issuers: [TrustedRemoteIntentIssuer]
    public var requireExpiry: Bool
    public var maxClockSkewSeconds: Int
    public var maxArgumentCount: Int

    public init(
        issuers: [TrustedRemoteIntentIssuer] = [],
        requireExpiry: Bool = true,
        maxClockSkewSeconds: Int = 300,
        maxArgumentCount: Int = 16
    ) {
        self.issuers = issuers
        self.requireExpiry = requireExpiry
        self.maxClockSkewSeconds = maxClockSkewSeconds
        self.maxArgumentCount = maxArgumentCount
    }

    public func issuer(for issuerID: String) -> TrustedRemoteIntentIssuer? {
        issuers.first { $0.issuerID == issuerID }
    }
}

public struct SignedRemoteIntentPayload: Codable, Equatable, Sendable {
    public var issuerID: String
    public var nonce: String
    public var topic: String
    public var origin: String
    public var actionID: String
    public var arguments: [String: String]
    public var issuedAt: String
    public var expiresAt: String?

    public init(
        issuerID: String,
        nonce: String,
        topic: String,
        origin: String,
        actionID: String,
        arguments: [String: String],
        issuedAt: String,
        expiresAt: String?
    ) {
        self.issuerID = issuerID
        self.nonce = nonce
        self.topic = topic
        self.origin = origin
        self.actionID = actionID
        self.arguments = arguments
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }
}

public struct SignedRemoteIntentEnvelope: Codable, Equatable, Sendable {
    public var payload: SignedRemoteIntentPayload
    public var signatureBase64: String

    public init(payload: SignedRemoteIntentPayload, signatureBase64: String) {
        self.payload = payload
        self.signatureBase64 = signatureBase64
    }
}

public enum RemoteIntentVerificationError: Error, Equatable, Sendable, LocalizedError {
    case policyUnavailable
    case untrustedIssuer(String)
    case invalidIssuerKey(String)
    case missingExpiry
    case invalidTimestamp(String)
    case envelopeExpired
    case issuedInFuture
    case topicNotAllowed(String)
    case actionNotAllowed(String)
    case invalidSignatureEncoding
    case invalidSignature
    case invalidPayload(String)
    case replayDetected(String)

    public var errorDescription: String? {
        switch self {
        case .policyUnavailable:
            return "Remote intent policy is not configured."
        case .untrustedIssuer(let issuerID):
            return "Remote issuer is not trusted: \(issuerID)"
        case .invalidIssuerKey(let issuerID):
            return "Trusted issuer key is invalid for: \(issuerID)"
        case .missingExpiry:
            return "Signed remote intent is missing expiresAt."
        case .invalidTimestamp(let field):
            return "Signed remote intent has an invalid timestamp in \(field)."
        case .envelopeExpired:
            return "Signed remote intent has expired."
        case .issuedInFuture:
            return "Signed remote intent is outside the allowed clock skew."
        case .topicNotAllowed(let topic):
            return "Signed remote intent topic is not allowed: \(topic)"
        case .actionNotAllowed(let actionID):
            return "Signed remote intent action is not allowed: \(actionID)"
        case .invalidSignatureEncoding:
            return "Signed remote intent signature is not valid base64."
        case .invalidSignature:
            return "Signed remote intent signature verification failed."
        case .invalidPayload(let reason):
            return "Signed remote intent payload is invalid: \(reason)"
        case .replayDetected(let nonce):
            return "Signed remote intent nonce was already seen: \(nonce)"
        }
    }
}

public enum RemoteIntentVerifier {
    public static func verify(
        envelope: SignedRemoteIntentEnvelope,
        policy: RemoteIntentPolicy,
        now: Date = Date()
    ) throws -> QueuedRemoteIntent {
        let payload = envelope.payload
        try validatePayloadShape(payload, policy: policy)

        guard let issuer = policy.issuer(for: payload.issuerID) else {
            throw RemoteIntentVerificationError.untrustedIssuer(payload.issuerID)
        }
        if !issuer.allowedTopics.isEmpty && !issuer.allowedTopics.contains(payload.topic) {
            throw RemoteIntentVerificationError.topicNotAllowed(payload.topic)
        }
        if !issuer.allowedActionIDs.isEmpty && !issuer.allowedActionIDs.contains(payload.actionID) {
            throw RemoteIntentVerificationError.actionNotAllowed(payload.actionID)
        }

        let issuedAt = try parseTimestamp(payload.issuedAt, field: "issuedAt")
        let expiresAt = try parseExpiry(payload.expiresAt, requireExpiry: policy.requireExpiry)
        let nowWithSkew = TimeInterval(policy.maxClockSkewSeconds)

        if issuedAt.timeIntervalSince(now) > nowWithSkew {
            throw RemoteIntentVerificationError.issuedInFuture
        }
        if let expiresAt, now.timeIntervalSince(expiresAt) > nowWithSkew {
            throw RemoteIntentVerificationError.envelopeExpired
        }

        let publicKeyData = Data(base64Encoded: issuer.publicSigningKeyBase64)
        guard let publicKeyData else {
            throw RemoteIntentVerificationError.invalidIssuerKey(issuer.issuerID)
        }
        let signatureData = Data(base64Encoded: envelope.signatureBase64)
        guard let signatureData else {
            throw RemoteIntentVerificationError.invalidSignatureEncoding
        }

        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        } catch {
            throw RemoteIntentVerificationError.invalidIssuerKey(issuer.issuerID)
        }

        let payloadData = try canonicalPayloadData(payload)
        guard publicKey.isValidSignature(signatureData, for: payloadData) else {
            throw RemoteIntentVerificationError.invalidSignature
        }

        return QueuedRemoteIntent(
            id: payload.nonce,
            topic: payload.topic,
            origin: payload.origin,
            actionID: payload.actionID,
            arguments: payload.arguments,
            receivedAt: ISO8601DateFormatter().string(from: now),
            issuerID: payload.issuerID,
            issuedAt: payload.issuedAt,
            expiresAt: payload.expiresAt,
            verificationStatus: "verified"
        )
    }

    public static func canonicalPayloadData(_ payload: SignedRemoteIntentPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }

    private static func validatePayloadShape(
        _ payload: SignedRemoteIntentPayload,
        policy: RemoteIntentPolicy
    ) throws {
        guard !payload.issuerID.isEmpty, payload.issuerID.count <= 256 else {
            throw RemoteIntentVerificationError.invalidPayload("issuerID")
        }
        guard !payload.nonce.isEmpty, payload.nonce.count <= 256 else {
            throw RemoteIntentVerificationError.invalidPayload("nonce")
        }
        guard !payload.topic.isEmpty, payload.topic.count <= 256 else {
            throw RemoteIntentVerificationError.invalidPayload("topic")
        }
        guard !payload.origin.isEmpty, payload.origin.count <= 512 else {
            throw RemoteIntentVerificationError.invalidPayload("origin")
        }
        guard !payload.actionID.isEmpty, payload.actionID.count <= 256 else {
            throw RemoteIntentVerificationError.invalidPayload("actionID")
        }
        if payload.arguments.count > policy.maxArgumentCount {
            throw RemoteIntentVerificationError.invalidPayload("arguments.count")
        }
        for (key, value) in payload.arguments {
            guard !key.isEmpty, key.count <= 128 else {
                throw RemoteIntentVerificationError.invalidPayload("argument.key")
            }
            guard !value.contains(where: \.isNewline), value.count <= 2048 else {
                throw RemoteIntentVerificationError.invalidPayload("argument.value")
            }
        }
    }

    private static func parseTimestamp(_ value: String, field: String) throws -> Date {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            throw RemoteIntentVerificationError.invalidTimestamp(field)
        }
        return date
    }

    private static func parseExpiry(_ value: String?, requireExpiry: Bool) throws -> Date? {
        guard let value else {
            if requireExpiry {
                throw RemoteIntentVerificationError.missingExpiry
            }
            return nil
        }
        return try parseTimestamp(value, field: "expiresAt")
    }
}
