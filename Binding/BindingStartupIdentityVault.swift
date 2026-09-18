import Foundation
import CryptoKit
import CellBase
import Security

/// The identity the app boots with, and the one every `.identityUnique` cell
/// is keyed on. It used to be minted fresh on every launch, which meant a new
/// UUID, a new cell container, and nothing to restore: Perspective, Relations
/// and the chronicle were written under a name nobody would ever ask for again.
///
/// The keys now live in the Keychain, per identity context, so the same
/// identity comes back on the next launch and the entity data written under it
/// is found. Under XCTest, or when explicitly asked, the vault stays in memory
/// exactly as before — tests must not inherit a person from an earlier run.
actor BindingStartupIdentityVault: IdentityVaultProtocol, ScopedSecretProviderProtocol, IdentityKeyRoleProviderProtocol {
    static let shared = BindingStartupIdentityVault()

    private struct StoredIdentity {
        var identity: Identity
        let signingPrivateKey: P256.Signing.PrivateKey
        let keyAgreementPrivateKey: P256.KeyAgreement.PrivateKey
    }

    /// What survives a relaunch. Private keys are raw P256 scalars; the
    /// public halves are re-derived on restore so they can never drift apart.
    private struct PersistedIdentity: Codable {
        var uuid: String
        var displayName: String
        var properties: [String: ValueType]?
        var signingPrivateKey: Data
        var keyAgreementPrivateKey: Data
    }

    private var identityUUIDsByContext: [String: String] = [:]
    private var identitiesByUUID: [String: StoredIdentity] = [:]
    private let durable: Bool
    private let store: any BindingStartupIdentityStore
    private let vaultReference: String

    static let keychainService = "org.digipomps.haven.startup-identity"

    init(
        durable: Bool = BindingStartupIdentityVault.shouldPersistAcrossLaunches(),
        store: any BindingStartupIdentityStore = BindingKeychainStartupIdentityStore()
    ) {
        self.durable = durable
        self.store = store
        // A durable vault needs a stable name: `homeVaultReference` travels with
        // the identity, and a name that changed per launch would make the
        // restored identity look foreign to its own data.
        self.vaultReference = durable
            ? "binding.startup.identityvault:durable"
            : "binding.startup.identityvault:\(UUID().uuidString)"
    }

    /// Tests get a fresh person per process (as the document root does), and
    /// `--haven-ephemeral-identity` / `HAVEN_EPHEMERAL_IDENTITY=1` let a human
    /// ask for the same on purpose.
    nonisolated static func shouldPersistAcrossLaunches(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        launchArguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if environment["XCTestConfigurationFilePath"] != nil { return false }
        if launchArguments.contains("--haven-ephemeral-identity") { return false }
        if let flag = environment["HAVEN_EPHEMERAL_IDENTITY"],
           ["1", "true", "yes"].contains(flag.lowercased()) { return false }
        return true
    }

    func identityVaultReference() async -> String? {
        vaultReference
    }

    func initialize() async -> any IdentityVaultProtocol {
        self
    }

    func addIdentity(identity: inout Identity, for identityContext: String) async {
        // A context that already has a person on disk keeps that person.
        // Minting here would overwrite the stored keys and orphan the data.
        if identityUUIDsByContext[identityContext] == nil {
            do {
                if let restored = try restore(for: identityContext) {
                    identityUUIDsByContext[identityContext] = restored.identity.uuid
                    identitiesByUUID[restored.identity.uuid] = restored
                }
            } catch {
                // An unreadable or corrupt record is not an absent identity.
                // Never overwrite its keys with a newly generated identity.
                return
            }
        }
        if let existingUUID = identityUUIDsByContext[identityContext],
           let existing = identitiesByUUID[existingUUID] {
            existing.identity.displayName = identity.displayName
            existing.identity.properties = identity.properties
            existing.identity.identityVault = self
            existing.identity.homeVaultReference = vaultReference
            identity = existing.identity
            identitiesByUUID[existingUUID] = existing
            return
        }

        let signingPrivateKey = P256.Signing.PrivateKey()
        let keyAgreementPrivateKey = P256.KeyAgreement.PrivateKey()

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
        do {
            try persist(stored, for: identityContext)
            identityUUIDsByContext[identityContext] = identity.uuid
            identitiesByUUID[identity.uuid] = stored
        } catch {
            // Do not advertise a durable identity that cannot survive restart.
            return
        }
    }

    func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? {
        if let uuid = identityUUIDsByContext[identityContext],
           let stored = identitiesByUUID[uuid] {
            stored.identity.identityVault = self
            stored.identity.homeVaultReference = vaultReference
            return stored.identity
        }

        do {
            if let restored = try restore(for: identityContext) {
                identityUUIDsByContext[identityContext] = restored.identity.uuid
                identitiesByUUID[restored.identity.uuid] = restored
                restored.identity.identityVault = self
                restored.identity.homeVaultReference = vaultReference
                return restored.identity
            }
        } catch {
            return nil
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
        guard let stored = identitiesByUUID[identity.uuid] else {
            return
        }
        let updatedIdentity = stored.identity
        updatedIdentity.displayName = identity.displayName
        updatedIdentity.properties = identity.properties
        updatedIdentity.identityVault = self
        updatedIdentity.homeVaultReference = vaultReference
        let refreshed = StoredIdentity(
            identity: updatedIdentity,
            signingPrivateKey: stored.signingPrivateKey,
            keyAgreementPrivateKey: stored.keyAgreementPrivateKey
        )
        identitiesByUUID[identity.uuid] = refreshed
        if let context = identityUUIDsByContext.first(where: { $0.value == identity.uuid })?.key {
            try? persist(refreshed, for: context)
        }
    }

    // MARK: - Durable storage

    private func persist(_ stored: StoredIdentity, for identityContext: String) throws {
        guard durable else { return }
        let payload = PersistedIdentity(
            uuid: stored.identity.uuid,
            displayName: stored.identity.displayName,
            properties: stored.identity.properties,
            signingPrivateKey: stored.signingPrivateKey.rawRepresentation,
            keyAgreementPrivateKey: stored.keyAgreementPrivateKey.rawRepresentation
        )
        let data = try JSONEncoder().encode(payload)
        try store.write(account: identityContext, data: data)
    }

    private func restore(for identityContext: String) throws -> StoredIdentity? {
        guard durable,
              let data = try store.read(account: identityContext)
        else { return nil }
        let payload = try JSONDecoder().decode(PersistedIdentity.self, from: data)
        let signingPrivateKey = try P256.Signing.PrivateKey(rawRepresentation: payload.signingPrivateKey)
        let keyAgreementPrivateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: payload.keyAgreementPrivateKey)

        let identity = Identity(payload.uuid, displayName: payload.displayName, identityVault: self)
        identity.properties = payload.properties ?? [:]
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
            algorithm: .ECDH,
            size: 256,
            curveType: .P256,
            x: nil,
            y: nil,
            compressedKey: keyAgreementPrivateKey.publicKey.x963Representation
        )
        return StoredIdentity(
            identity: identity,
            signingPrivateKey: signingPrivateKey,
            keyAgreementPrivateKey: keyAgreementPrivateKey
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

/// Where the startup identity's keys sleep between launches.
protocol BindingStartupIdentityStore: Sendable {
    /// Only a genuinely absent item returns nil; access/corruption errors throw.
    func read(account: String) throws -> Data?
    func write(account: String, data: Data) throws
}

enum BindingStartupIdentityStoreError: Error {
    case keychainStatus(OSStatus)
    case invalidData
}

/// The real one: a generic-password item per identity context, this device
/// only, readable after first unlock so the app can boot before the person
/// authenticates.
struct BindingKeychainStartupIdentityStore: BindingStartupIdentityStore {
    private func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: BindingStartupIdentityVault.keychainService,
            kSecAttrAccount as String: account
        ]
    }

    func read(account: String) throws -> Data? {
        var query = query(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw BindingStartupIdentityStoreError.keychainStatus(status)
        }
        guard let data = result as? Data else {
            throw BindingStartupIdentityStoreError.invalidData
        }
        return data
    }

    func write(account: String, data: Data) throws {
        let query = query(account: account)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else {
            throw BindingStartupIdentityStoreError.keychainStatus(status)
        }
        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let inserted = SecItemAdd(insert as CFDictionary, nil)
        guard inserted == errSecSuccess else {
            throw BindingStartupIdentityStoreError.keychainStatus(inserted)
        }
    }
}

/// For tests: two vaults sharing one of these behave like one app across
/// two launches.
final class BindingInMemoryStartupIdentityStore: BindingStartupIdentityStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]

    init() {}

    func read(account: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return items[account]
    }

    func write(account: String, data: Data) {
        lock.lock(); defer { lock.unlock() }
        items[account] = data
    }
}

private nonisolated func hexEncodedString<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
    bytes.map { String(format: "%02x", $0) }.joined()
}
