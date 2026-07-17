import Foundation
import Security
@preconcurrency import CellBase
import HavenAgentRuntime

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public final class LocalIdentityVault: IdentityVaultProtocol, ScopedSecretProviderProtocol, IdentityKeyRoleProviderProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var identitiesByContext: [String: Identity] = [:]
    private var identityContextByUUID: [String: String] = [:]
    private var signingKeysByIdentityUUID: [String: Curve25519.Signing.PrivateKey] = [:]
    private var keyAgreementKeysByIdentityUUID: [String: Curve25519.KeyAgreement.PrivateKey] = [:]
    private var scopedSecretsByTag: [String: Data] = [:]
    private let vaultReference = "haven-agent-local:v1"

    public init() {}

    public func identityVaultReference() async -> String? {
        vaultReference
    }

    public func initialize() async -> IdentityVaultProtocol {
        self
    }

    public func addIdentity(identity: inout Identity, for identityContext: String) async {
        withLock {
            if let stored = identityForUUIDLocked(identity.uuid) {
                guard identitiesReferenceSame(identity, stored),
                      identity.homeVaultReference == vaultReference else {
                    identity.identityVault = nil
                    identity.homeVaultReference = nil
                    return
                }
            }
            installBackingKeyIfNeeded(for: &identity)
            identity.identityVault = self
            identity.homeVaultReference = vaultReference
            identitiesByContext[identityContext] = identity
            identityContextByUUID[identity.uuid] = identityContext
        }
    }

    public func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? {
        withLock {
            if let existing = identitiesByContext[identityContext] {
                existing.identityVault = self
                existing.homeVaultReference = vaultReference
                identityContextByUUID[existing.uuid] = identityContext
                return existing
            }
            guard makeNewIfNotFound else {
                return nil
            }

            var identity = Identity(identityContext, displayName: identityContext, identityVault: self)
            installBackingKeyIfNeeded(for: &identity)
            identitiesByContext[identityContext] = identity
            identityContextByUUID[identity.uuid] = identityContext
            return identity
        }
    }

    public func identity(forUUID uuid: String) async -> Identity? {
        withLock {
            guard let identity = identityForUUIDLocked(uuid) else {
                return nil
            }
            identity.identityVault = self
            identity.homeVaultReference = vaultReference
            return identity
        }
    }

    public func saveIdentity(_ identity: Identity) async {
        withLock {
            guard let stored = identityForUUIDLocked(identity.uuid),
                  identitiesReferenceSame(identity, stored),
                  identity.homeVaultReference == vaultReference else {
                return
            }
            stored.displayName = identity.displayName
            stored.properties = identity.properties
            stored.identityVault = self
            stored.homeVaultReference = vaultReference
            identitiesByContext[stored.displayName] = stored
            identitiesByContext[stored.uuid] = stored
        }
    }

    public func identityExistInVault(_ identity: Identity) async -> Bool {
        withLock {
            guard identity.homeVaultReference == vaultReference,
                  let stored = identityForUUIDLocked(identity.uuid) else {
                return false
            }
            return identitiesReferenceSame(identity, stored)
        }
    }

    public func identityDomainBinding(for identity: Identity) async -> IdentityDomainBinding? {
        guard await identityExistInVault(identity) else {
            return nil
        }
        return withLock {
            guard let context = identityContextByUUID[identity.uuid] else {
                return nil
            }
            return IdentityDomainBinding(domain: context, identity: identity)
        }
    }

    public func installIdentity(
        descriptor: AgentIdentityDescriptor,
        privateKey: Curve25519.Signing.PrivateKey
    ) async -> Identity {
        withLock {
            let identity = Identity(
                descriptor.identityUUID,
                displayName: descriptor.displayName,
                identityVault: self
            )
            signingKeysByIdentityUUID[descriptor.identityUUID] = privateKey
            let keyAgreementKey = Curve25519.KeyAgreement.PrivateKey()
            keyAgreementKeysByIdentityUUID[descriptor.identityUUID] = keyAgreementKey
            identity.publicSecureKey = SecureKey(
                date: Date(),
                privateKey: false,
                use: .signature,
                algorithm: .EdDSA,
                size: 256,
                curveType: .Curve25519,
                x: nil,
                y: nil,
                compressedKey: privateKey.publicKey.rawRepresentation
            )
            identity.publicKeyAgreementSecureKey = SecureKey(
                date: Date(),
                privateKey: false,
                use: .keyAgreement,
                algorithm: .X25519,
                size: 256,
                curveType: .Curve25519,
                x: nil,
                y: nil,
                compressedKey: keyAgreementKey.publicKey.rawRepresentation
            )
            identity.identityVault = self
            identity.homeVaultReference = vaultReference
            identitiesByContext[descriptor.identityContext] = identity
            identitiesByContext[descriptor.identityUUID] = identity
            identityContextByUUID[descriptor.identityUUID] = descriptor.identityContext
            return identity
        }
    }

    public func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        let privateKey: Curve25519.Signing.PrivateKey? = withLock {
            guard identity.homeVaultReference == vaultReference,
                  let stored = identityForUUIDLocked(identity.uuid),
                  identitiesReferenceSame(identity, stored) else {
                return nil
            }
            return signingKeysByIdentityUUID[identity.uuid]
        }
        guard let privateKey else {
            throw IdentityVaultError.noKey
        }
        return try privateKey.signature(for: messageData)
    }

    public func verifySignature(signature: Data, messageData: Data, for identity: Identity) async throws -> Bool {
        guard let compressedKey = identity.publicSecureKey?.compressedKey else {
            throw IdentityVaultError.noKey
        }
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: compressedKey)
        return publicKey.isValidSignature(signature, for: messageData)
    }

    public func randomBytes64() async -> Data? {
        randomData(count: 64)
    }

    public func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) {
        let secret = try await scopedSecretData(tag: tag, minimumLength: 48)
        let keyData = secret.prefix(32)
        let ivData = secret.dropFirst(32).prefix(16)
        guard !keyData.isEmpty, !ivData.isEmpty else {
            throw IdentityVaultError.noKey
        }
        return (key: Data(keyData).base64EncodedString(), iv: Data(ivData).base64EncodedString())
    }

    public func scopedSecretData(tag: String, minimumLength: Int) async throws -> Data {
        try withLock {
            if let existing = scopedSecretsByTag[tag], existing.count >= minimumLength {
                return existing
            }
            guard let generated = randomData(count: max(minimumLength, 32)) else {
                throw IdentityVaultError.noKey
            }
            scopedSecretsByTag[tag] = generated
            return generated
        }
    }

    public func publicSecureKey(for identity: Identity, role: IdentityKeyRole) async throws -> SecureKey? {
        switch role {
        case .signing:
            return identity.publicSecureKey
        case .keyAgreement:
            return identity.publicKeyAgreementSecureKey
        }
    }

    public func openContentEnvelope(
        for identity: Identity,
        ephemeralPublicKey: Data,
        wrappedKeyMaterial: Data,
        encryptedContent: Data,
        keyDerivationSalt: Data,
        keyDerivationInfo: Data,
        authenticatedData: Data
    ) async throws -> Data? {
        let privateKey: Curve25519.KeyAgreement.PrivateKey? = withLock {
            guard identity.homeVaultReference == vaultReference,
                  let stored = identityForUUIDLocked(identity.uuid),
                  identitiesReferenceSame(identity, stored),
                  identity.publicKeyAgreementSecureKey?.compressedKey
                    == stored.publicKeyAgreementSecureKey?.compressedKey else {
                return nil
            }
            return keyAgreementKeysByIdentityUUID[identity.uuid]
        }
        guard let privateKey else { return nil }
        do {
            let ephemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicKey)
            let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeralKey)
            let wrappingKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: keyDerivationSalt,
                sharedInfo: keyDerivationInfo,
                outputByteCount: 32
            )
            let wrappedKeyBox = try ChaChaPoly.SealedBox(combined: wrappedKeyMaterial)
            let contentKeyData = try ChaChaPoly.open(wrappedKeyBox, using: wrappingKey)
            let contentBox = try ChaChaPoly.SealedBox(combined: encryptedContent)
            return try ChaChaPoly.open(
                contentBox,
                using: SymmetricKey(data: contentKeyData),
                authenticating: authenticatedData
            )
        } catch {
            return nil
        }
    }

    private func installBackingKeyIfNeeded(for identity: inout Identity) {
        if signingKeysByIdentityUUID[identity.uuid] == nil {
            let privateKey = Curve25519.Signing.PrivateKey()
            signingKeysByIdentityUUID[identity.uuid] = privateKey
            identity.publicSecureKey = SecureKey(
                date: Date(),
                privateKey: false,
                use: .signature,
                algorithm: .EdDSA,
                size: 256,
                curveType: .Curve25519,
                x: nil,
                y: nil,
                compressedKey: privateKey.publicKey.rawRepresentation
            )
        }
        if keyAgreementKeysByIdentityUUID[identity.uuid] == nil {
            let keyAgreementKey = Curve25519.KeyAgreement.PrivateKey()
            keyAgreementKeysByIdentityUUID[identity.uuid] = keyAgreementKey
            identity.publicKeyAgreementSecureKey = SecureKey(
                date: Date(),
                privateKey: false,
                use: .keyAgreement,
                algorithm: .X25519,
                size: 256,
                curveType: .Curve25519,
                x: nil,
                y: nil,
                compressedKey: keyAgreementKey.publicKey.rawRepresentation
            )
        } else if identity.publicKeyAgreementSecureKey == nil,
                  let publicKey = keyAgreementKeysByIdentityUUID[identity.uuid]?.publicKey.rawRepresentation {
            identity.publicKeyAgreementSecureKey = SecureKey(
                date: Date(),
                privateKey: false,
                use: .keyAgreement,
                algorithm: .X25519,
                size: 256,
                curveType: .Curve25519,
                x: nil,
                y: nil,
                compressedKey: publicKey
            )
        }
        identity.identityVault = self
        identity.homeVaultReference = vaultReference
    }

    private func identityForUUIDLocked(_ uuid: String) -> Identity? {
        identitiesByContext.values.first { $0.uuid == uuid }
    }

    private func identitiesReferenceSame(_ lhs: Identity, _ rhs: Identity) -> Bool {
        guard lhs.uuid == rhs.uuid,
              let lhsFingerprint = lhs.signingPublicKeyFingerprint,
              let rhsFingerprint = rhs.signingPublicKeyFingerprint else {
            return false
        }
        return lhsFingerprint == rhsFingerprint
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    private func randomData(count: Int) -> Data? {
        var bytes = [UInt8](repeating: 0, count: count)
        let result = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard result == errSecSuccess else {
            return nil
        }
        return Data(bytes)
    }
}
