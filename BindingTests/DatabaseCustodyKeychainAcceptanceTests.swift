import XCTest
import CellBase
import CellApple
import Security

/// Opt-in only: a signed app host and real human presence are necessary to substantiate this boundary.
/// All items use a unique test service and are removed; no existing owner identities/keys are read.
final class DatabaseCustodyKeychainAcceptanceTests: XCTestCase {
    func testSignedKeychainPresenceRecoveryAndReopen() async throws {
        guard ProcessInfo.processInfo.environment["HAVEN_RUN_KEYCHAIN_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Requires a signed host and local user presence; enable HAVEN_RUN_KEYCHAIN_ACCEPTANCE=1.")
        }
        let service = "no.haven.database-secret.acceptance." + UUID().uuidString
        let primaryID = UUID().uuidString, recoveryID = UUID().uuidString
        defer {
            for id in [primaryID, recoveryID] {
                SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service, kSecAttrAccount as String: id.lowercased(),
                    kSecUseDataProtectionKeychain as String: true] as CFDictionary)
            }
        }
        let primary = try await AppleDatabaseSecretUnwrapper.create(service: service, handleID: primaryID)
        let recovery = try await AppleDatabaseSecretUnwrapper.create(service: service, handleID: recoveryID)
        do {
            _ = try await AppleDatabaseSecretUnwrapper.create(service: service, handleID: primaryID)
            XCTFail("Duplicate setup must preserve the existing key")
        } catch { XCTAssertEqual(error as? SecretCredentialError, .alreadyExists) }
        let vault = await EphemeralIdentityVault().initialize()
        let resolved = await vault.identity(for: "synthetic-custody-acceptance", makeNewIfNotFound: true)
        let owner = try XCTUnwrap(resolved)
        let context = try DatabaseSecretContext(secretID: UUID().uuidString, cellUUID: UUID().uuidString,
            ownerFingerprint: XCTUnwrap(owner.signingPublicKeyFingerprint), domain: "test", audience: UUID().uuidString)
        let expected = SecretKeyMaterial.generate()
        let record = try await DatabaseSecretCrypto.seal(expected, context: context,
            recipients: [primary.recipient(), recovery.recipient()], owner: owner)
        for provider in [primary, recovery] {
            let recipient = try await provider.recipient()
            let envelope = try XCTUnwrap(record.envelopes.first { $0.recipient == recipient })
            let material = try await provider.open(envelope, context: context)
            XCTAssertTrue(material.withBytes { bytes in expected.withBytes { $0 == bytes } })
        }
        let reopened = try await AppleDatabaseSecretUnwrapper(service: service, handleID: primaryID, recipient: primary.recipient())
        let recipient = try await reopened.recipient()
        let envelope = try XCTUnwrap(record.envelopes.first { $0.recipient == recipient })
        let material = try await reopened.open(envelope, context: context)
        XCTAssertTrue(material.withBytes { bytes in expected.withBytes { $0 == bytes } })
        let missing = try AppleDatabaseSecretUnwrapper(service: service, handleID: UUID().uuidString, recipient: recipient)
        do { _ = try await missing.open(envelope, context: context); XCTFail("Missing key must not be replaced") }
        catch { XCTAssertEqual(error as? SecretCredentialError, .missing) }
    }
}
