import Foundation
import SproutCrypto

public struct AgentEntityLinkRevocation: Codable, Equatable, Sendable {
    public var mode: String

    public init(mode: String) {
        self.mode = mode
    }
}

public struct AgentEntityLinkSignature: Codable, Equatable, Sendable {
    public var by_pubkey: String
    public var alg: String
    public var sig: String

    public init(by_pubkey: String, alg: String, sig: String) {
        self.by_pubkey = by_pubkey
        self.alg = alg
        self.sig = sig
    }
}

public struct AgentEntityLinkContract: Codable, Equatable, Sendable {
    public var contract_id: String
    public var domain_a: String
    public var pubkey_a: String
    public var domain_b: String
    public var pubkey_b: String
    public var scope: String
    public var created_at: String
    public var revocation: AgentEntityLinkRevocation
    public var signatures: [AgentEntityLinkSignature]

    public init(
        contract_id: String,
        domain_a: String,
        pubkey_a: String,
        domain_b: String,
        pubkey_b: String,
        scope: String,
        created_at: String,
        revocation: AgentEntityLinkRevocation,
        signatures: [AgentEntityLinkSignature]
    ) {
        self.contract_id = contract_id
        self.domain_a = domain_a
        self.pubkey_a = pubkey_a
        self.domain_b = domain_b
        self.pubkey_b = pubkey_b
        self.scope = scope
        self.created_at = created_at
        self.revocation = revocation
        self.signatures = signatures
    }

    public func canonicalPayloadData() throws -> Data {
        let encoded = try JSONEncoder().encode(self)
        return try JCSCanonicalizer.canonicalizeRemovingTopLevelKeys(encoded, keys: ["signatures"])
    }

    public func verifyMutualSignatures() throws -> Bool {
        let canonical = try canonicalPayloadData()
        let requiredKeys: Set<String> = [pubkey_a, pubkey_b]
        guard signatures.count >= 2 else {
            return false
        }

        var verifiedKeys = Set<String>()
        for signature in signatures {
            guard signature.alg == "Ed25519" else {
                return false
            }
            guard requiredKeys.contains(signature.by_pubkey) else {
                return false
            }
            let valid = Ed25519.verifyBase64URL(
                data: canonical,
                signatureBase64URL: signature.sig,
                publicKeyBase64URL: signature.by_pubkey
            )
            guard valid else {
                return false
            }
            verifiedKeys.insert(signature.by_pubkey)
        }

        return verifiedKeys == requiredKeys
    }
}
