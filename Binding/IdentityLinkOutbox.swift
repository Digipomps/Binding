import Foundation
import CryptoKit
import Security
import CellBase

/// One locally verified, exact completion package. A pending entry grants no
/// authority; the remote person ceremony must still accept it on every retry.
nonisolated struct IdentityLinkPendingCompletion: Codable, @unchecked Sendable {
    var ticket: IdentityLinkTicket
    var envelope: IdentityLinkCompletionEnvelope
    var verifiedAt: Date
    var completeURL: String
    var requestID: String { envelope.request.requestID }
}

nonisolated protocol IdentityLinkOutbox: Sendable {
    func load() async throws -> IdentityLinkPendingCompletion?
    func save(_ entry: IdentityLinkPendingCompletion) async throws
    func remove(requestID: String) async throws
}

nonisolated enum IdentityLinkOutboxError: Error { case occupied, invalidFile, keychain(OSStatus) }

/// Atomic encrypted file, device-only Keychain key, excluded from backup. One
/// actor owns this directory. No plaintext fallback or key regeneration when a
/// pending file exists; an unavailable/corrupt store blocks new ceremonies.
actor EncryptedIdentityLinkOutbox: IdentityLinkOutbox {
    static let shared = EncryptedIdentityLinkOutbox()
    private let directory: URL
    private let keyProvider: @Sendable (Bool) throws -> Data
    private let authenticatedContext = Data("haven.person-link-outbox.v1".utf8)

    init(directory: URL = IdentityLinkCompletionStore.directory.appendingPathComponent("Pending", isDirectory: true),
         keyProvider: @escaping @Sendable (Bool) throws -> Data = IdentityLinkOutboxKeychain.key) {
        self.directory = directory
        self.keyProvider = keyProvider
    }

    private var file: URL { directory.appendingPathComponent("completion.sealed") }

    func load() throws -> IdentityLinkPendingCompletion? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= 512 * 1024 else { throw IdentityLinkOutboxError.invalidFile }
        let sealed = try AES.GCM.SealedBox(combined: Data(contentsOf: file))
        let key = try keyProvider(false)
        guard key.count == 32 else { throw IdentityLinkOutboxError.invalidFile }
        let data = try AES.GCM.open(sealed, using: SymmetricKey(data: key), authenticating: authenticatedContext)
        return try JSONDecoder().decode(IdentityLinkPendingCompletion.self, from: data)
    }

    func save(_ entry: IdentityLinkPendingCompletion) throws {
        if let previous = try load() {
            guard try IdentityLinkWire.encoder.encode(previous) == IdentityLinkWire.encoder.encode(entry) else {
                throw IdentityLinkOutboxError.occupied
            }
            return
        }
        let data = try IdentityLinkWire.encoder.encode(entry)
        guard data.count <= 500 * 1024 else { throw IdentityLinkOutboxError.invalidFile }
        let key = try keyProvider(true)
        guard key.count == 32 else { throw IdentityLinkOutboxError.invalidFile }
        guard let combined = try AES.GCM.seal(data, using: SymmetricKey(data: key), authenticating: authenticatedContext).combined else {
            throw IdentityLinkOutboxError.invalidFile
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var protectedDirectory = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try protectedDirectory.setResourceValues(values)
        #if os(iOS)
        try combined.write(to: file, options: [.atomic, .completeFileProtection])
        #else
        try combined.write(to: file, options: [.atomic])
        #endif
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        // Read back the authenticated entry before allowing a remote mutation.
        guard let saved = try load(), try IdentityLinkWire.encoder.encode(saved) == data else {
            throw IdentityLinkOutboxError.invalidFile
        }
    }

    func remove(requestID: String) throws {
        guard let current = try load() else { return }
        guard current.requestID == requestID else { throw IdentityLinkOutboxError.occupied }
        try FileManager.default.removeItem(at: file)
    }
}

nonisolated private enum IdentityLinkOutboxKeychain {
    static func key(create: Bool) throws -> Data {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "org.digipomps.binding.person-link-outbox.v1",
            kSecAttrAccount as String: "device-key", kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true]
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, data.count == 32 { return data }
        guard status == errSecItemNotFound, create else { throw IdentityLinkOutboxError.keychain(status) }
        let data = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        var insertion = base
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let added = SecItemAdd(insertion as CFDictionary, nil)
        if added == errSecDuplicateItem { return try key(create: false) }
        guard added == errSecSuccess else { throw IdentityLinkOutboxError.keychain(added) }
        return data
    }
}
