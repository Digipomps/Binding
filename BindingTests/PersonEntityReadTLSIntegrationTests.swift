// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import CellBase
import CryptoKit
import Foundation
import XCTest
@testable import Binding

#if os(macOS)
import CFNetwork
/// CI-only pairing with the actual CellScaffold route in a separate process.
/// The ephemeral CI host maps the trusted staging hostname to loopback and
/// trusts a generated test CA. Production client networking is unchanged.
/// Person signatures are real; the server's WebAuthn verifier is synthetic.
final class PersonEntityReadTLSIntegrationTests: XCTestCase {
    private typealias C = BindingPersonEntityReadRouteContract

    func testActualTLSDiscoverySigningReadRevocationAndFreshReconnectDenial() async throws {
        guard ProcessInfo.processInfo.environment["HAVEN_SYNTHETIC_NATIVE_TLS"] == "1",
              ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true",
              ProcessInfo.processInfo.environment["RUNNER_ENVIRONMENT"] == "github-hosted",
              let temporaryDirectory = ProcessInfo.processInfo.environment["RUNNER_TEMP"],
              let directory = ProcessInfo.processInfo.environment["HAVEN_SYNTHETIC_NATIVE_TLS_ROOT"] else {
            throw XCTSkip("Requires the isolated TLS/server CI harness; never contact real staging from this test")
        }
        let root = URL(fileURLWithPath: directory)
        let expectedRoot = URL(fileURLWithPath: temporaryDirectory).appendingPathComponent("person-entity-native-tls")
        let rootProperties = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard root.standardizedFileURL.path == expectedRoot.standardizedFileURL.path,
              root.resolvingSymlinksInPath().path == expectedRoot.resolvingSymlinksInPath().path,
              rootProperties.isDirectory == true, rootProperties.isSymbolicLink != true else {
            throw FixtureFailure.invalidSetup
        }
        guard Set(Host(name: "staging.haven.digipomps.org").addresses ?? []) == ["127.0.0.1"] else {
            throw FixtureFailure.notLoopback
        }
        let proxyNames = ["HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"]
        guard proxyNames.allSatisfy({ ProcessInfo.processInfo.environment[$0]?.isEmpty ?? true }),
              let proxies = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              proxySettingsAreDisabled(proxies) else { throw FixtureFailure.invalidSetup }
        // The orchestrator writes this only after certificate/hostname setup.
        guard try String(contentsOf: root.appendingPathComponent("loopback-tls-ready"), encoding: .utf8)
                == "synthetic-loopback-only\n" else { throw FixtureFailure.invalidSetup }
        let (input, entry, phone) = try await fixture(root: root)
        try JSONEncoder().encode(input).write(to: root.appendingPathComponent("input.json"), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600],
            ofItemAtPath: root.appendingPathComponent("input.json").path)
        let readyURL = root.appendingPathComponent("ready.json")
        try await waitForFile(readyURL, root: root)
        let ready = try JSONDecoder().decode(PeerReady.self, from: Data(contentsOf: readyURL))
        XCTAssertNotEqual(ready.pid, ProcessInfo.processInfo.processIdentifier)
        XCTAssertEqual(ready.linkID, entry.record.linkID)
        XCTAssertEqual(ready.reference, entry.personEvidenceReference)

        CellBase.defaultCellResolver = CellResolver.sharedInstance
        CellBase.sendDataAsText = true
        let client = PersonEntityReadClient { uuid in uuid == phone.uuid ? phone : nil }
        do {
            try await client.connect(entry: entry)
            for _ in 0..<2 {
                let result = try await client.read(keypaths: ["entityRepresentation.name"])
                XCTAssertEqual(result.status, .complete)
                let fragment = try XCTUnwrap(result.fragments.first)
                XCTAssertEqual(fragment.value, .string("synthetic-person-in-another-process"))
                XCTAssertEqual(fragment.sourceOrigin, entry.origin)
                XCTAssertEqual(fragment.sourceReference, "cell:///" + ready.anchorUUID)
            }
            try Data().write(to: root.appendingPathComponent("revoke"), options: .atomic)
            try await waitForFile(root.appendingPathComponent("revoked"), root: root)
            let revoked = try await client.read(keypaths: ["entityRepresentation.name"])
            XCTAssertEqual(revoked.status, .denied)
            XCTAssertTrue(revoked.fragments.isEmpty)
            await client.close()

            // Fresh HTTPS discovery must not reopen the now-revoked link.
            let reconnect = PersonEntityReadClient { uuid in uuid == phone.uuid ? phone : nil }
            do {
                try await reconnect.connect(entry: entry)
                XCTFail("Revocation must deny fresh native connection")
            } catch {
                XCTAssertEqual(error as? C.Failure, .unavailable,
                    "The actual discovery endpoint must deny; a timeout or TLS failure is not proof of authorization denial")
            }
            await reconnect.close()

            // The same trusted test CA now serves a certificate for a different
            // hostname. The unchanged URLSession trust policy must reject it
            // before any authenticated HTTP request reaches the proxy handler.
            let countURL = root.appendingPathComponent("tls-accepted-count")
            let before = try String(contentsOf: countURL, encoding: .utf8)
            try Data().write(to: root.appendingPathComponent("bad-certificate"), options: .atomic)
            let wrongCertificate = PersonEntityReadClient { uuid in uuid == phone.uuid ? phone : nil }
            do {
                try await wrongCertificate.connect(entry: entry)
                XCTFail("A trusted issuer must not bypass TLS hostname validation")
            } catch {
                let tlsError = try XCTUnwrap(error as? URLError)
                XCTAssertTrue([URLError.Code.serverCertificateUntrusted, .secureConnectionFailed].contains(tlsError.code),
                    "A timeout or application denial is not evidence of TLS hostname validation")
            }
            await wrongCertificate.close()
            XCTAssertEqual(try String(contentsOf: countURL, encoding: .utf8), before)
            try Data().write(to: root.appendingPathComponent("stop"), options: .atomic)
        } catch {
            await client.close()
            try? Data().write(to: root.appendingPathComponent("stop"), options: .atomic)
            throw error
        }
    }

    private func waitForFile(_ url: URL, root: URL) async throws {
        let deadline = Date().addingTimeInterval(30)
        while !FileManager.default.fileExists(atPath: url.path) {
            if FileManager.default.fileExists(atPath: root.appendingPathComponent("peer-failed").path) {
                throw FixtureFailure.peerFailed
            }
            guard Date() < deadline else { throw FixtureFailure.timeout }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func proxySettingsAreDisabled(_ value: Any) -> Bool {
        if let values = value as? [String: Any] {
            let flags = ["HTTPEnable", "HTTPSEnable", "SOCKSEnable", "ProxyAutoConfigEnable", "ProxyAutoDiscoveryEnable"]
            return values.allSatisfy { key, value in
                if flags.contains(key) { return (value as? NSNumber)?.boolValue == false }
                return proxySettingsAreDisabled(value)
            }
        }
        if let values = value as? [Any] { return values.allSatisfy(proxySettingsAreDisabled) }
        return true
    }

    private func fixture(root: URL) async throws -> (PeerInput, IdentityLinkCompletionStore.Entry, Identity) {
        let origin = "https://staging.haven.digipomps.org", audience = "staging.haven.digipomps.org"
        let vault = EphemeralIdentityVault()
        var phone = Identity(UUID().uuidString, displayName: "Synthetic TLS phone", identityVault: vault)
        await vault.addIdentity(identity: &phone, for: "private")
        let ownerKey = Curve25519.Signing.PrivateKey()
        let ownerVault = try TLSFixtureOwnerVault(privateKey: ownerKey.rawRepresentation, uuid: UUID().uuidString)
        let owner = await ownerVault.identityValue()
        let now = Date(), expires = now.addingTimeInterval(600)
        let descriptor = try IdentityLinkProtocolService.descriptor(for: phone)
        var request = IdentityEnrollmentRequest(requestID: UUID().uuidString,
            entityBinding: .init(mode: .localEntityAnchor, entityAnchorReference: "cell:///EntityAnchor", audience: audience),
            newIdentity: descriptor, requestedDomains: ["private", "scaffold"], requestedIdentityContexts: ["binding"],
            requestedScopes: [IdentityLinkScope.sameEntity], audience: audience, origin: origin,
            createdAt: IdentityLinkProtocolService.iso8601(now), expiresAt: IdentityLinkProtocolService.iso8601(expires),
            nonce: Data(repeating: 0x31, count: 32), platform: "synthetic", deviceLabel: "Synthetic TLS phone")
        let signature = try await phone.sign(data: request.canonicalPayloadData())
        request.proof = .init(byIdentityUUID: phone.uuid, algorithm: descriptor.algorithm,
            curveType: descriptor.curveType, signature: try XCTUnwrap(signature))
        let requestHash = try IdentityLinkProtocolService.requestHash(for: request)
        var authData = Data(repeating: 0, count: 37); authData[32] = 0x05
        // Exact synthetic evidence expected by the existing server fixture.
        let evidence = IdentityLinkFreshAuthEvidence(method: "webauthn", challenge: requestHash,
            performedAt: IdentityLinkProtocolService.iso8601(now), credentialID: Data("synthetic-credential".utf8),
            authenticatorData: authData, clientDataJSON: Data("synthetic-client-data".utf8),
            signature: Data("synthetic-authenticator-signature".utf8))
        let approval = try await IdentityLinkProtocolService.approveEnrollmentRequest(request, issuerIdentity: owner,
            createdAt: now, expiresAt: expires, freshAuthPerformedAt: now, freshAuthEvidence: evidence)
        let credential = try await IdentityLinkProtocolService.issueSameEntityCredential(request: request,
            approval: approval, issuerIdentity: owner, validUntil: expires, revocationReference: nil)
        let challenge = Data(repeating: 0x37, count: 32)
        let presentation = try await IdentityLinkProtocolService.makeVerifierBoundPresentation(credential: credential,
            holderIdentity: phone, challenge: challenge, domain: origin)
        // Match Binding's real saved envelope: the server separately enforces
        // current person evidence; historical client validation checks signatures.
        let envelope = IdentityLinkCompletionEnvelope(request: request, approval: approval,
            sameEntityCredential: credential, presentation: presentation,
            issuerIdentity: try IdentityLinkProtocolService.descriptor(for: owner), expectedAudience: audience,
            expectedOrigin: origin, expectedPresentationChallenge: challenge, expectedPresentationDomain: origin)
        let verified = try await IdentityLinkProtocolService.verifyCompletion(envelope, now: now)
        let entry = IdentityLinkCompletionStore.Entry(origin: origin, record: verified.record, envelope: envelope,
            storedAt: IdentityLinkProtocolService.iso8601(now), personEvidenceReference: C.digest(verified.requestHash))
        let input = PeerInput(root: root.path, port: 19089, ownerUUID: owner.uuid,
            ownerPrivateKey: ownerKey.rawRepresentation, ownerUserID: UUID().uuidString, envelope: envelope)
        // Only this newly generated synthetic server key crosses the process
        // boundary. The linked phone's private key remains in this test process.
        return (input, entry, phone)
    }

    private enum FixtureFailure: Error { case peerFailed, timeout, notLoopback, invalidSetup }
    private struct PeerInput: Codable {
        let root: String
        let port: Int
        let ownerUUID: String
        let ownerPrivateKey: Data
        let ownerUserID: String
        let envelope: IdentityLinkCompletionEnvelope
    }
    private struct PeerReady: Codable {
        let pid: Int32
        let linkID: String
        let reference: String
        let anchorUUID: String
        let queryUUID: String
        let gatewayUUID: String
    }
}

/// Mirrors the existing server fixture's exact synthetic owner/home-vault
/// contract so the receiving process can restore its own key without aliases.
private actor TLSFixtureOwnerVault: IdentityVaultProtocol {
    private enum Failure: Error { case wrongIdentity }
    private let key: Curve25519.Signing.PrivateKey
    private let uuid: String
    private var vaultReference: String { "synthetic-process-vault:" + uuid }
    init(privateKey: Data, uuid: String) throws {
        key = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
        self.uuid = uuid
    }
    func identityValue() -> Identity {
        let identity = Identity(uuid, displayName: "Synthetic TLS server owner", identityVault: self)
        identity.homeVaultReference = vaultReference
        identity.publicSecureKey = SecureKey(date: Date(), privateKey: false, use: .signature, algorithm: .EdDSA,
            size: 32, curveType: .Curve25519, x: nil, y: nil, compressedKey: key.publicKey.rawRepresentation)
        return identity
    }
    func identityVaultReference() async -> String? { vaultReference }
    func initialize() async -> any IdentityVaultProtocol { self }
    func addIdentity(identity: inout Identity, for identityContext: String) async {}
    func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? { identityValue() }
    func identity(forUUID uuid: String) async -> Identity? { uuid == self.uuid ? identityValue() : nil }
    func identityExistInVault(_ identity: Identity) async -> Bool { matches(identity) }
    func identityDomainBinding(for identity: Identity) async -> IdentityDomainBinding? {
        matches(identity) ? IdentityDomainBinding(domain: "synthetic-replica", identity: identity) : nil
    }
    func saveIdentity(_ identity: Identity) async {}
    func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        guard matches(identity) else { throw Failure.wrongIdentity }
        return try key.signature(for: messageData)
    }
    func verifySignature(signature: Data, messageData: Data, for identity: Identity) async throws -> Bool {
        matches(identity) && key.publicKey.isValidSignature(signature, for: messageData)
    }
    func randomBytes64() async -> Data? { Data((0..<64).map { _ in UInt8.random(in: .min ... .max) }) }
    func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) { throw Failure.wrongIdentity }
    private func matches(_ identity: Identity) -> Bool {
        identity.uuid == uuid && identity.homeVaultReference == vaultReference
            && identity.publicSecureKey?.compressedKey == key.publicKey.rawRepresentation
    }
}
#endif
