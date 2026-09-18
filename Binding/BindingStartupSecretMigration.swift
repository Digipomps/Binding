import Foundation
import CryptoKit
import Darwin
@_spi(HAVENRuntime) import CellBase

/// Converts the old public-tag-derived CELLENC1 key before the runtime can use
/// the new vault key. All candidates are validated and backed up before writes.
/// This adapter preserves CellProtocol's wire format and never changes globals.
nonisolated enum BindingStartupSecretMigration {
    enum Failure: Error {
        case invalidFile, busy, invalidEnvelope, changedDuringMigration, conflictingBackup
    }
    private struct Envelope: Codable {
        var version: UInt8
        var ownerIdentityUUID: String?
        var combined: Data
    }
    private struct Replacement {
        let source: URL
        let prepared: URL
        let originalDigest: Data
    }
    private static let magic = Data("CELLENC1".utf8)
    private static let backupMagic = Data("HAVEN-STARTUP-BACKUP-1\0".utf8)
    private static let names = ["typedCell.json", "keypathstorage.json", "entity-authority-journal.json"]
    private static let limit = PersistedCellFileIO.maximumStoredCellBytes

    static func legacySeed() -> Data {
        var payload = Data("cell.persistence.master.v1".utf8)
        payload.append(contentsOf: [UInt8](repeating: 0, count: 8))
        return Data(SHA256.hash(data: payload))
    }

    @discardableResult
    static func prepare(documentRoot: URL, newSeed: Data, stopAfterReplacements: Int? = nil) throws -> Int {
        let fm = FileManager.default
        try fm.createDirectory(at: documentRoot, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let lockURL = documentRoot.appendingPathComponent(".startup-secret-migration.lock")
        let fd = Darwin.open(lockURL.path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw Failure.invalidFile }
        defer { Darwin.close(fd) }
        var lockInfo = stat()
        guard fstat(fd, &lockInfo) == 0, lockInfo.st_mode & S_IFMT == S_IFREG,
              lockInfo.st_nlink == 1, lockInfo.st_uid == geteuid() else { throw Failure.invalidFile }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw Failure.busy }
        defer { flock(fd, LOCK_UN) }
        let cells = try CellStoragePathPolicy.component("CellsContainer", under: documentRoot)
        guard fm.fileExists(atPath: cells.path) else { return 0 }
        let newMaster = Data(SHA256.hash(data: newSeed))
        let oldMaster = Data(SHA256.hash(data: legacySeed()))
        let backupRoot = try CellStoragePathPolicy.component(".startup-secret-migration-v1", under: documentRoot)
        var replacements: [Replacement] = []
        // Directory enumeration can canonicalize /var to /private/var on
        // macOS. Rebuild each validated component beneath the original root
        // so confinement compares paths in the same namespace.
        let folders = try fm.contentsOfDirectory(atPath: cells.path)
        for name in folders.sorted() {
            let folder = try CellStoragePathPolicy.component(name, under: cells)
            let properties = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard properties.isSymbolicLink != true else { throw Failure.invalidFile }
            guard properties.isDirectory == true else { continue }
            let confined = try CellStoragePathPolicy.existingURL(folder, under: cells)
            for name in names {
                let source = try CellStoragePathPolicy.filename(name, under: confined)
                guard fm.fileExists(atPath: source.path) else { continue }
                let original = try PersistedCellFileIO.readStoredCell(at: source)
                guard original.starts(with: magic) else { continue }
                let binding = storageBinding(cellUUID: folder.lastPathComponent, filename: name)
                if (try? decrypt(original, binding: binding, master: newMaster)) != nil { continue }
                // Authentication failure stops the entire preflight. No source
                // has been changed yet, including earlier valid candidates.
                let plaintext = try decrypt(original, binding: binding, master: oldMaster)
                let oldEnvelope = try JSONDecoder().decode(Envelope.self, from: original.dropFirst(magic.count))
                let encoded = try encrypt(plaintext, binding: binding, owner: oldEnvelope.ownerIdentityUUID, master: newMaster)
                guard encoded.count <= limit,
                      try decrypt(encoded, binding: binding, master: newMaster) == plaintext else { throw Failure.invalidEnvelope }
                try ensurePrivateDirectory(backupRoot)
                let backupFolder = try CellStoragePathPolicy.component(folder.lastPathComponent, under: backupRoot)
                try ensurePrivateDirectory(backupFolder)
                let backup = try CellStoragePathPolicy.filename(name + ".original.sealed", under: backupFolder)
                let backupAAD = Data(("binding.startup.backup.v1:" + binding).utf8)
                if fm.fileExists(atPath: backup.path) {
                    guard try restoreBackup(at: backup, binding: binding, newSeed: newSeed) == original else { throw Failure.conflictingBackup }
                } else {
                    let box = try ChaChaPoly.seal(original, using: SymmetricKey(data: newMaster), authenticating: backupAAD)
                    var protected = backupMagic
                    protected.append(box.combined)
                    try writeNew(protected, to: backup)
                }
                let prepared = try CellStoragePathPolicy.filename(name + ".prepared", under: backupFolder)
                try encoded.write(to: prepared, options: [.atomic])
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: prepared.path)
                replacements.append(Replacement(source: source, prepared: prepared, originalDigest: Data(SHA256.hash(data: original))))
            }
        }
        var count = 0
        for replacement in replacements {
            guard Data(SHA256.hash(data: try PersistedCellFileIO.readStoredCell(at: replacement.source))) == replacement.originalDigest else {
                throw Failure.changedDuringMigration
            }
            let prepared = try PersistedCellFileIO.readStoredCell(at: replacement.prepared)
            try prepared.write(to: replacement.source, options: [.atomic])
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: replacement.source.path)
            count += 1
            // Only a local test can request this interruption. No wire action
            // or environment variable exposes migration controls.
            if let stopAfterReplacements, count >= stopAfterReplacements { throw Failure.busy }
        }
        return count
    }

    static func storageBinding(cellUUID: String, filename: String) -> String {
        filename == "typedCell.json" ? cellUUID
            : "entity-anchor-side-file-v1:\(cellUUID.utf8.count):\(cellUUID):\(filename)"
    }

    static func restoreBackup(at url: URL, binding: String, newSeed: Data) throws -> Data {
        let bytes = try readBackup(at: url)
        guard bytes.starts(with: backupMagic) else { throw Failure.invalidEnvelope }
        let box = try ChaChaPoly.SealedBox(combined: bytes.dropFirst(backupMagic.count))
        return try ChaChaPoly.open(box, using: SymmetricKey(data: Data(SHA256.hash(data: newSeed))),
            authenticating: Data(("binding.startup.backup.v1:" + binding).utf8))
    }

    private static func encrypt(_ data: Data, binding: String, owner: String?, master: Data) throws -> Data {
        let box = try ChaChaPoly.seal(data, using: key(master: master, owner: owner, binding: binding),
                                    authenticating: aad(owner: owner, binding: binding))
        var output = magic
        output.append(try JSONEncoder().encode(Envelope(version: 1, ownerIdentityUUID: owner, combined: box.combined)))
        return output
    }

    private static func decrypt(_ data: Data, binding: String, master: Data) throws -> Data {
        guard data.starts(with: magic) else { throw Failure.invalidEnvelope }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data.dropFirst(magic.count))
        guard envelope.version == 1 else { throw Failure.invalidEnvelope }
        return try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: envelope.combined),
            using: key(master: master, owner: envelope.ownerIdentityUUID, binding: binding),
            authenticating: aad(owner: envelope.ownerIdentityUUID, binding: binding))
    }

    private static func key(master: Data, owner: String?, binding: String) -> SymmetricKey {
        var data = master
        data.append(Data(((owner ?? "_") + "." + binding).utf8))
        return SymmetricKey(data: Data(SHA256.hash(data: data)))
    }

    private static func aad(owner: String?, binding: String) -> Data {
        Data(("cell-persistence-v1\0" + (owner ?? "_") + "\0" + binding).utf8)
    }

    private static func writeNew(_ data: Data, to url: URL) throws {
        let fd = Darwin.open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw Failure.invalidFile }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    private static func ensurePrivateDirectory(_ url: URL) throws {
        guard mkdir(url.path, 0o700) == 0 || errno == EEXIST else { throw Failure.invalidFile }
        var info = stat()
        guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == geteuid(), chmod(url.path, 0o700) == 0 else { throw Failure.invalidFile }
    }

    private static func readBackup(at url: URL) throws -> Data {
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw Failure.invalidFile }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        let maximum = limit + backupMagic.count + 28
        guard fstat(fd, &info) == 0, info.st_nlink == 1,
              info.st_mode & S_IFMT == S_IFREG, info.st_size >= 0, info.st_size <= maximum else { throw Failure.invalidFile }
        let data = try handle.read(upToCount: maximum + 1) ?? Data()
        guard data.count <= maximum else { throw Failure.invalidFile }
        return data
    }
}
