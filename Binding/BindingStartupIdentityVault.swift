import Foundation
import CryptoKit
import CellBase
import Security

actor BindingStartupIdentityVault: IdentityVaultProtocol, ScopedSecretProviderProtocol, IdentityKeyRoleProviderProtocol {
    static let shared = BindingStartupIdentityVault()

    private struct StoredIdentity {
        var identity: Identity
        let signingPrivateKey: P256.Signing.PrivateKey
        let keyAgreementPrivateKey: Curve25519.KeyAgreement.PrivateKey
    }

    private var identityUUIDsByContext: [String: String] = [:]
    private var identitiesByUUID: [String: StoredIdentity] = [:]
    private var scopedSecretsByTag: [String: Data] = [:]
    private let vaultReference = "binding-startup:\(UUID().uuidString.lowercased())"

    func identityVaultReference() async -> String? {
        vaultReference
    }

    func initialize() async -> any IdentityVaultProtocol {
        self
    }

    func addIdentity(identity: inout Identity, for identityContext: String) async {
        if let existingUUID = identityUUIDsByContext[identityContext],
           let existing = identitiesByUUID[existingUUID] {
            guard identity.uuid == existingUUID,
                  identity.signingPublicKeyFingerprint == existing.identity.signingPublicKeyFingerprint,
                  identity.homeVaultReference == vaultReference else {
                identity.identityVault = nil
                identity.homeVaultReference = nil
                return
            }
            existing.identity.displayName = identity.displayName
            existing.identity.properties = identity.properties
            existing.identity.identityVault = self
            existing.identity.homeVaultReference = vaultReference
            identity = existing.identity
            identitiesByUUID[existingUUID] = existing
            return
        }

        let signingPrivateKey = P256.Signing.PrivateKey()
        let keyAgreementPrivateKey = Curve25519.KeyAgreement.PrivateKey()

        identity.identityVault = self
        identity.homeVaultReference = vaultReference
        identity.publicSecureKey = SecureKey(
            date: Date(),
            privateKey: false,
            use: .signature,
            algorithm: .ECDSA,
            size: 256,
            curveType: .P256,
            x: nil,
            y: nil,
            compressedKey: signingPrivateKey.publicKey.x963Representation
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
            compressedKey: keyAgreementPrivateKey.publicKey.rawRepresentation
        )

        let stored = StoredIdentity(
            identity: identity,
            signingPrivateKey: signingPrivateKey,
            keyAgreementPrivateKey: keyAgreementPrivateKey
        )
        identityUUIDsByContext[identityContext] = identity.uuid
        identitiesByUUID[identity.uuid] = stored
    }

    func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? {
        if let uuid = identityUUIDsByContext[identityContext],
           let stored = identitiesByUUID[uuid] {
            stored.identity.identityVault = self
            stored.identity.homeVaultReference = vaultReference
            return stored.identity
        }

        guard makeNewIfNotFound else {
            return nil
        }

        var createdIdentity = Identity()
        createdIdentity.displayName = "HAVEN Local Session"
        await addIdentity(identity: &createdIdentity, for: identityContext)
        return await self.identity(for: identityContext, makeNewIfNotFound: false)
    }

    func identity(forUUID uuid: String) async -> Identity? {
        guard let stored = identitiesByUUID[uuid] else {
            return nil
        }
        stored.identity.identityVault = self
        stored.identity.homeVaultReference = vaultReference
        return stored.identity
    }

    func identityExistInVault(_ identity: Identity) async -> Bool {
        guard let stored = identitiesByUUID[identity.uuid],
              identity.homeVaultReference == vaultReference,
              let requestedFingerprint = identity.signingPublicKeyFingerprint,
              let storedFingerprint = stored.identity.signingPublicKeyFingerprint else {
            return false
        }
        return requestedFingerprint == storedFingerprint
    }

    func identityDomainBinding(for identity: Identity) async -> IdentityDomainBinding? {
        guard await identityExistInVault(identity) else {
            return nil
        }
        let matchingContexts = identityUUIDsByContext.compactMap { context, uuid in
            uuid == identity.uuid ? context : nil
        }
        guard matchingContexts.count == 1, let domain = matchingContexts.first else {
            return nil
        }
        return IdentityDomainBinding(domain: domain, identity: identity)
    }

    func saveIdentity(_ identity: Identity) async {
        guard await identityExistInVault(identity),
              let stored = identitiesByUUID[identity.uuid] else {
            return
        }
        let updatedIdentity = stored.identity
        updatedIdentity.displayName = identity.displayName
        updatedIdentity.properties = identity.properties
        updatedIdentity.identityVault = self
        updatedIdentity.homeVaultReference = vaultReference
        identitiesByUUID[identity.uuid] = StoredIdentity(
            identity: updatedIdentity,
            signingPrivateKey: stored.signingPrivateKey,
            keyAgreementPrivateKey: stored.keyAgreementPrivateKey
        )
    }

    func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        guard await identityExistInVault(identity),
              let stored = identitiesByUUID[identity.uuid] else {
            throw IdentityVaultError.wrongVault
        }
        let signature = try stored.signingPrivateKey.signature(for: messageData)
        return signature.derRepresentation
    }

    func verifySignature(signature: Data, messageData: Data, for identity: Identity) async throws -> Bool {
        guard let compressedKey = identity.publicSecureKey?.compressedKey else {
            return false
        }
        let publicKey = try P256.Signing.PublicKey(x963Representation: compressedKey)
        let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signature)
        return publicKey.isValidSignature(ecdsaSignature, for: messageData)
    }

    func randomBytes64() async -> Data? {
        var bytes = [UInt8](repeating: 0, count: 64)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return nil
        }
        return Data(bytes)
    }

    func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) {
        let secret = try await scopedSecretData(tag: tag, minimumLength: 48)
        let key = hexEncodedString(secret.prefix(32))
        let iv = hexEncodedString(secret.dropFirst(32).prefix(16))
        return (key: key, iv: iv)
    }

    func scopedSecretData(tag: String, minimumLength: Int) async throws -> Data {
        let requiredLength = max(32, minimumLength)
        if let existing = scopedSecretsByTag[tag], existing.count >= requiredLength {
            return existing
        }
        guard let generated = secureRandomData(count: requiredLength) else {
            throw ScopedSecretProviderError.unavailable
        }
        scopedSecretsByTag[tag] = generated
        return generated
    }

    func publicSecureKey(for identity: Identity, role: IdentityKeyRole) async throws -> SecureKey? {
        switch role {
        case .signing:
            return identity.publicSecureKey
        case .keyAgreement:
            return identity.publicKeyAgreementSecureKey
        }
    }

    func openContentEnvelope(
        for identity: Identity,
        ephemeralPublicKey: Data,
        wrappedKeyMaterial: Data,
        encryptedContent: Data,
        keyDerivationSalt: Data,
        keyDerivationInfo: Data,
        authenticatedData: Data
    ) async throws -> Data? {
        guard await identityExistInVault(identity),
              let stored = identitiesByUUID[identity.uuid],
              identity.publicKeyAgreementSecureKey?.compressedKey
                == stored.identity.publicKeyAgreementSecureKey?.compressedKey else {
            return nil
        }
        do {
            let ephemeralKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicKey)
            let sharedSecret = try stored.keyAgreementPrivateKey.sharedSecretFromKeyAgreement(with: ephemeralKey)
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

    private func secureRandomData(count: Int) -> Data? {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            return nil
        }
        return Data(bytes)
    }
}

private nonisolated func hexEncodedString<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
    bytes.map { String(format: "%02x", $0) }.joined()
}
