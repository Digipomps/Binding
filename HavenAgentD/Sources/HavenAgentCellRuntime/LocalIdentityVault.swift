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
    private var signingKeysByIdentityUUID: [String: Curve25519.Signing.PrivateKey] = [:]
    private var keyAgreementKeysByIdentityUUID: [String: Curve25519.KeyAgreement.PrivateKey] = [:]
    private var scopedSecretsByTag: [String: Data] = [:]

    public init() {}

    public func initialize() async -> IdentityVaultProtocol {
        self
    }

    public func addIdentity(identity: inout Identity, for identityContext: String) async {
        withLock {
            installBackingKeyIfNeeded(for: &identity)
            identity.identityVault = self
            identitiesByContext[identityContext] = identity
        }
    }

    public func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? {
        withLock {
            if let existing = identitiesByContext[identityContext] {
                return existing
            }
            guard makeNewIfNotFound else {
                return nil
            }

            var identity = Identity(identityContext, displayName: identityContext, identityVault: self)
            installBackingKeyIfNeeded(for: &identity)
            identitiesByContext[identityContext] = identity
            return identity
        }
    }

    public func saveIdentity(_ identity: Identity) async {
        withLock {
            var identity = identity
            installBackingKeyIfNeeded(for: &identity)
            identitiesByContext[identity.displayName] = identity
            identitiesByContext[identity.uuid] = identity
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
            identitiesByContext[descriptor.identityContext] = identity
            identitiesByContext[descriptor.identityUUID] = identity
            return identity
        }
    }

    public func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        let privateKey: Curve25519.Signing.PrivateKey? = withLock {
            signingKeysByIdentityUUID[identity.uuid]
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

    public func privateKeyData(for identity: Identity, role: IdentityKeyRole) async throws -> Data? {
        withLock {
            switch role {
            case .signing:
                return signingKeysByIdentityUUID[identity.uuid]?.rawRepresentation
            case .keyAgreement:
                return keyAgreementKeysByIdentityUUID[identity.uuid]?.rawRepresentation
            }
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
