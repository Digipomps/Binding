import XCTest
import Foundation
import CryptoKit
import CellBase
@testable import Binding

@MainActor
final class StartupSecretMigrationTests: XCTestCase {
    func testVaultSecretsArePrivateStableScopedAndPrefixCompatible() async throws {
        let store = BindingInMemoryStartupIdentityStore()
        let one = BindingStartupIdentityVault(durable: true, store: store)
        let two = BindingStartupIdentityVault(durable: true, store: store)
        let other = BindingStartupIdentityVault(durable: true, store: BindingInMemoryStartupIdentityStore())
        let first = try await one.scopedSecretData(tag: "synthetic-secret", minimumLength: 32)
        let larger = try await two.scopedSecretData(tag: "synthetic-secret", minimumLength: 64)
        let separateVault = try await other.scopedSecretData(tag: "synthetic-secret", minimumLength: 32)
        let separateTag = try await one.scopedSecretData(tag: "different-tag", minimumLength: 32)
        XCTAssertEqual(first, larger.prefix(32))
        XCTAssertNotEqual(first, separateVault)
        XCTAssertNotEqual(first, separateTag)
        let memoryA = BindingStartupIdentityVault(durable: false, store: store)
        let memoryB = BindingStartupIdentityVault(durable: false, store: store)
        let a = try await memoryA.scopedSecretData(tag: "synthetic-secret", minimumLength: 32)
        let b = try await memoryB.scopedSecretData(tag: "synthetic-secret", minimumLength: 32)
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(first, a)
    }

    func testCorruptRootSecretIsPreservedAndNeverReplaced() async throws {
        let store = BindingInMemoryStartupIdentityStore()
        let corrupt = Data("corrupt".utf8)
        store.write(account: BindingStartupIdentityVault.scopedSecretAccount, data: corrupt)
        let vault = BindingStartupIdentityVault(durable: true, store: store)
        do {
            _ = try await vault.scopedSecretData(tag: "synthetic-secret", minimumLength: 32)
            XCTFail("Corrupt root must not produce a secret")
        } catch {}
        XCTAssertEqual(store.read(account: BindingStartupIdentityVault.scopedSecretAccount), corrupt)
    }

    func testSecretStorageFailuresLeaveExistingCellsUntouched() async throws {
        let saved = CellBase.persistedCellMasterKey
        defer { CellBase.persistedCellMasterKey = saved }
        for failReads in [true, false] {
            let root = try temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let fixtures = try makeFixtures(root: root)
            let store = FailingStartupIdentityStore(failReads: failReads)
            let vault = BindingStartupIdentityVault(durable: true, store: store, persistenceRoot: root)
            do {
                _ = try await vault.scopedSecretData(tag: "cell.persistence.master.v1", minimumLength: 32)
                XCTFail("An unavailable durable secret must stop before migration")
            } catch {}
            XCTAssertEqual(store.writeCount, failReads ? 0 : 1)
            for fixture in fixtures { XCTAssertEqual(try Data(contentsOf: fixture.url), fixture.original) }
        }
    }

    func testConcurrentEphemeralSecretCallsUseTheSameRoot() async throws {
        let vault = BindingStartupIdentityVault(durable: false, store: BindingInMemoryStartupIdentityStore())
        let results = try await withThrowingTaskGroup(of: Data.self) { group in
            for _ in 0..<20 {
                group.addTask { try await vault.scopedSecretData(tag: "concurrent", minimumLength: 32) }
            }
            var results: [Data] = []
            for try await result in group { results.append(result) }
            return results
        }
        XCTAssertEqual(Set(results).count, 1)
    }

    func testTypedCellAndEntitySideFilesMigrateWithExactPlaintextAndProtectedBackups() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let saved = CellBase.persistedCellMasterKey
        defer { CellBase.persistedCellMasterKey = saved }
        let newSeed = Data(repeating: 0xA7, count: 32)
        let fixtures = try makeFixtures(root: root)
        XCTAssertEqual(try BindingStartupSecretMigration.prepare(documentRoot: root, newSeed: newSeed), 3)
        CellBase.configurePersistedCellMasterKey(seedData: newSeed)
        for fixture in fixtures {
            let updated = try Data(contentsOf: fixture.url)
            XCTAssertNotEqual(updated, fixture.original)
            XCTAssertEqual(try CellPersistenceCrypto.decodeFromStorage(stored: updated, uuid: fixture.binding), fixture.plaintext)
            let backup = root.appendingPathComponent(".startup-secret-migration-v1/cell-a/" + fixture.url.lastPathComponent + ".original.sealed")
            XCTAssertEqual(try BindingStartupSecretMigration.restoreBackup(at: backup, binding: fixture.binding, newSeed: newSeed), fixture.original)
            XCTAssertFalse(try Data(contentsOf: backup).starts(with: Data("CELLENC1".utf8)))
        }
        XCTAssertEqual(try BindingStartupSecretMigration.prepare(documentRoot: root, newSeed: newSeed), 0)
    }

    func testMigrationResumesAnInterruptedMixedGeneration() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let saved = CellBase.persistedCellMasterKey
        defer { CellBase.persistedCellMasterKey = saved }
        let newSeed = Data(repeating: 0xB8, count: 32)
        let fixtures = try makeFixtures(root: root)
        XCTAssertThrowsError(try BindingStartupSecretMigration.prepare(documentRoot: root, newSeed: newSeed, stopAfterReplacements: 1))
        XCTAssertEqual(try BindingStartupSecretMigration.prepare(documentRoot: root, newSeed: newSeed), 2)
        CellBase.configurePersistedCellMasterKey(seedData: newSeed)
        for fixture in fixtures {
            XCTAssertEqual(try CellPersistenceCrypto.decodeFromStorage(stored: Data(contentsOf: fixture.url), uuid: fixture.binding), fixture.plaintext)
        }
    }

    func testCorruptCiphertextPreflightDoesNotChangeEarlierValidFiles() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let saved = CellBase.persistedCellMasterKey
        defer { CellBase.persistedCellMasterKey = saved }
        let fixtures = try makeFixtures(root: root)
        let corruptURL = root.appendingPathComponent("CellsContainer/cell-z/typedCell.json")
        try FileManager.default.createDirectory(at: corruptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("CELLENC1broken-envelope".utf8)
        try corrupt.write(to: corruptURL)
        XCTAssertThrowsError(try BindingStartupSecretMigration.prepare(documentRoot: root, newSeed: Data(repeating: 9, count: 32)))
        for fixture in fixtures { XCTAssertEqual(try Data(contentsOf: fixture.url), fixture.original) }
        XCTAssertEqual(try Data(contentsOf: corruptURL), corrupt)
    }

    func testMigrationRejectsSymbolicAndHardLinkedStorage() throws {
        for hardLink in [false, true] {
            let root = try temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let source = root.appendingPathComponent("outside.json")
            try Data("CELLENC1not-user-data".utf8).write(to: source)
            let target = root.appendingPathComponent("CellsContainer/cell-a/typedCell.json")
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if hardLink { try FileManager.default.linkItem(at: source, to: target) }
            else { try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source) }
            XCTAssertThrowsError(try BindingStartupSecretMigration.prepare(documentRoot: root, newSeed: Data(repeating: 9, count: 32)))
            XCTAssertEqual(try Data(contentsOf: source), Data("CELLENC1not-user-data".utf8))
        }
    }

    func testVaultReturnsPersistenceSeedOnlyAfterExistingStorageHasMigrated() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let saved = CellBase.persistedCellMasterKey
        defer { CellBase.persistedCellMasterKey = saved }
        let fixtures = try makeFixtures(root: root)
        let store = BindingInMemoryStartupIdentityStore()
        let vault = BindingStartupIdentityVault(durable: true, store: store, persistenceRoot: root)
        let seed = try await vault.scopedSecretData(tag: "cell.persistence.master.v1", minimumLength: 32)
        CellBase.configurePersistedCellMasterKey(seedData: seed)
        for fixture in fixtures {
            XCTAssertEqual(try CellPersistenceCrypto.decodeFromStorage(stored: Data(contentsOf: fixture.url), uuid: fixture.binding), fixture.plaintext)
        }
        let restarted = BindingStartupIdentityVault(durable: true, store: store, persistenceRoot: root)
        let afterRestart = try await restarted.scopedSecretData(tag: "cell.persistence.master.v1", minimumLength: 32)
        XCTAssertEqual(seed, afterRestart)
    }

    private struct Fixture { let url: URL; let binding: String; let plaintext: Data; let original: Data }
    private func makeFixtures(root: URL) throws -> [Fixture] {
        // Independently reproduce the previously shipped derivation.
        var seedInput = Data("cell.persistence.master.v1".utf8)
        seedInput.append(contentsOf: [UInt8](repeating: 0, count: 8))
        CellBase.configurePersistedCellMasterKey(seedData: Data(SHA256.hash(data: seedInput)))
        // Encode typed-cell and side-file bindings using the runtime's actual
        // crypto, so a copied migration formula cannot validate itself.
        return try ["typedCell.json", "keypathstorage.json", "entity-authority-journal.json"].map { name in
            let binding = name == "typedCell.json" ? "cell-a" : "entity-anchor-side-file-v1:6:cell-a:\(name)"
            let plaintext = Data(("synthetic private state: " + name).utf8)
            let original = try CellPersistenceCrypto.encodeForStorage(plaintext: plaintext, uuid: binding,
                options: .init(ownerIdentityUUID: "synthetic-owner", encryptedAtRestRequired: true))
            let url = root.appendingPathComponent("CellsContainer/cell-a/" + name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try original.write(to: url)
            return Fixture(url: url, binding: binding, plaintext: plaintext, original: original)
        }
    }
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("binding-secret-migration-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
