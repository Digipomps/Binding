import Foundation
import CryptoKit
import CellBase

actor BindingStartupIdentityVault: IdentityVaultProtocol, ScopedSecretProviderProtocol, IdentityKeyRoleProviderProtocol {
    static let shared = BindingStartupIdentityVault()

    private struct StoredIdentity {
        var identity: Identity
        let signingPrivateKey: P256.Signing.PrivateKey
        let keyAgreementPrivateKey: P256.KeyAgreement.PrivateKey
    }

    private var identityUUIDsByContext: [String: String] = [:]
    private var identitiesByUUID: [String: StoredIdentity] = [:]

    func initialize() async -> any IdentityVaultProtocol {
        self
    }

    func addIdentity(identity: inout Identity, for identityContext: String) async {
        if let existingUUID = identityUUIDsByContext[identityContext],
           let existing = identitiesByUUID[existingUUID] {
            existing.identity.displayName = identity.displayName
            existing.identity.properties = identity.properties
            existing.identity.identityVault = self
            identity = existing.identity
            identitiesByUUID[existingUUID] = existing
            return
        }

        let signingPrivateKey = P256.Signing.PrivateKey()
        let keyAgreementPrivateKey = P256.KeyAgreement.PrivateKey()

        identity.identityVault = self
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
            algorithm: .ECDH,
            size: 256,
            curveType: .P256,
            x: nil,
            y: nil,
            compressedKey: keyAgreementPrivateKey.publicKey.x963Representation
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
            return stored.identity
        }

        guard makeNewIfNotFound else {
            return nil
        }

        var createdIdentity = Identity()
        createdIdentity.displayName = "Binding Local Session"
        await addIdentity(identity: &createdIdentity, for: identityContext)
        return await self.identity(for: identityContext, makeNewIfNotFound: false)
    }

    func identityExistInVault(_ identity: Identity) async -> Bool {
        identitiesByUUID[identity.uuid] != nil
    }

    func saveIdentity(_ identity: Identity) async {
        guard let stored = identitiesByUUID[identity.uuid] else {
            return
        }
        let updatedIdentity = stored.identity
        updatedIdentity.displayName = identity.displayName
        updatedIdentity.properties = identity.properties
        updatedIdentity.identityVault = self
        identitiesByUUID[identity.uuid] = StoredIdentity(
            identity: updatedIdentity,
            signingPrivateKey: stored.signingPrivateKey,
            keyAgreementPrivateKey: stored.keyAgreementPrivateKey
        )
    }

    func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        guard let stored = identitiesByUUID[identity.uuid] else {
            throw ScopedSecretProviderError.unavailable
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
        Data((0..<64).map { _ in UInt8.random(in: 0...255) })
    }

    func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) {
        let secret = try await scopedSecretData(tag: tag, minimumLength: 48)
        let key = hexEncodedString(secret.prefix(32))
        let iv = hexEncodedString(secret.dropFirst(32).prefix(16))
        return (key: key, iv: iv)
    }

    func scopedSecretData(tag: String, minimumLength: Int) async throws -> Data {
        let requiredLength = max(32, minimumLength)
        var buffer = Data()
        var counter: UInt64 = 0

        while buffer.count < requiredLength {
            var payload = Data(tag.utf8)
            payload.append(contentsOf: withUnsafeBytes(of: counter.bigEndian, Array.init))
            buffer.append(contentsOf: SHA256.hash(data: payload))
            counter += 1
        }

        return buffer.prefix(requiredLength)
    }

    func publicSecureKey(for identity: Identity, role: IdentityKeyRole) async throws -> SecureKey? {
        switch role {
        case .signing:
            return identity.publicSecureKey
        case .keyAgreement:
            return identity.publicKeyAgreementSecureKey
        }
    }

    func privateKeyData(for identity: Identity, role: IdentityKeyRole) async throws -> Data? {
        guard let stored = identitiesByUUID[identity.uuid] else {
            return nil
        }

        switch role {
        case .signing:
            return stored.signingPrivateKey.rawRepresentation
        case .keyAgreement:
            return stored.keyAgreementPrivateKey.rawRepresentation
        }
    }
}

private nonisolated func hexEncodedString<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
    bytes.map { String(format: "%02x", $0) }.joined()
}
