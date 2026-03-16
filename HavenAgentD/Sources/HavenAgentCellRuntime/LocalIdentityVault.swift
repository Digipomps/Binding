import Foundation
import Security
@preconcurrency import CellBase
import HavenAgentRuntime

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public final class LocalIdentityVault: IdentityVaultProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var identitiesByContext: [String: Identity] = [:]
    private var signingKeysByIdentityUUID: [String: Curve25519.Signing.PrivateKey] = [:]

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
        guard let key = randomData(count: 32)?.base64EncodedString(),
              let iv = randomData(count: 16)?.base64EncodedString() else {
            throw IdentityVaultError.noKey
        }
        return (key: key, iv: iv)
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
