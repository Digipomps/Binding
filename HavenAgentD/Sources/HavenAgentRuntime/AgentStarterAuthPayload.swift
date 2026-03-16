import Foundation
import SproutCrypto

public struct AgentStarterPurposeInterest: Codable, Equatable, Sendable {
    public var purpose: String
    public var interests: [String]

    public init(purpose: String, interests: [String]) {
        self.purpose = purpose
        self.interests = interests
    }
}

public struct AgentResolverSignatureEnvelope: Codable, Equatable, Sendable {
    public var alg: String
    public var sig: String

    public init(alg: String, sig: String) {
        self.alg = alg
        self.sig = sig
    }
}

public struct AgentStarterAuthPayload: Codable, Equatable, Sendable {
    public var version: String
    public var domain: String
    public var identity_public_key: String
    public var created_at: String
    public var expires_at: String
    public var nonce: String
    public var purpose_interest: AgentStarterPurposeInterest
    public var signature: AgentResolverSignatureEnvelope

    public init(
        version: String = "1.0",
        domain: String,
        identity_public_key: String,
        created_at: String,
        expires_at: String,
        nonce: String,
        purpose_interest: AgentStarterPurposeInterest,
        signature: AgentResolverSignatureEnvelope
    ) {
        self.version = version
        self.domain = domain
        self.identity_public_key = identity_public_key
        self.created_at = created_at
        self.expires_at = expires_at
        self.nonce = nonce
        self.purpose_interest = purpose_interest
        self.signature = signature
    }

    public func canonicalPayloadData() throws -> Data {
        let encoded = try JSONEncoder().encode(self)
        return try JCSCanonicalizer.canonicalizeRemovingTopLevelKeys(encoded, keys: ["signature"])
    }

    public func verifySignature() throws -> Bool {
        guard signature.alg == "Ed25519" else {
            return false
        }
        return Ed25519.verifyBase64URL(
            data: try canonicalPayloadData(),
            signatureBase64URL: signature.sig,
            publicKeyBase64URL: identity_public_key
        )
    }

    public func isExpired(now: Date = Date()) -> Bool {
        let formatter = ISO8601DateFormatter()
        guard let expiry = formatter.date(from: expires_at) else {
            return true
        }
        return now >= expiry
    }
}
