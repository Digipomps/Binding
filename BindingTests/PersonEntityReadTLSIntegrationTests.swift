// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import CellBase
import CryptoKit
import Foundation
import XCTest
@testable import Binding

#if os(macOS)
import CFNetwork
import Security
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

            // Fresh scope discovery over the shared Bridge must reject the revoked link.
            let reconnect = PersonEntityReadClient { uuid in uuid == phone.uuid ? phone : nil }
            do {
                try await reconnect.connect(entry: entry)
                XCTFail("Revocation must deny fresh native connection")
            } catch {
                XCTAssertEqual(error as? C.Failure, .denied,
                    "The actual gateway Cell must deny; a timeout or TLS failure is not proof of authorization denial")
            }
            await reconnect.close()

            // The same trusted test CA now serves a certificate for a different
            // hostname. The unchanged URLSession trust policy must reject it
            // before any authenticated Bridge message reaches the server.
            let countURL = root.appendingPathComponent("tls-accepted-count")
            let before = try String(contentsOf: countURL, encoding: .utf8)
            let sentURL = root.appendingPathComponent("certificate-sent.json")
            if FileManager.default.fileExists(atPath: sentURL.path) { try FileManager.default.removeItem(at: sentURL) }
            let certificateAttempt = UUID().uuidString.lowercased()
            try Data(certificateAttempt.utf8).write(to: root.appendingPathComponent("bad-certificate"), options: .atomic)
            let wrongCertificate = PersonEntityReadClient { uuid in uuid == phone.uuid ? phone : nil }
            var nativeFailure: NSError?
            do {
                try await wrongCertificate.connect(entry: entry)
            } catch {
                nativeFailure = error as NSError
            }
            await wrongCertificate.close()
            try await waitForFile(sentURL, root: root)
            let witness = try JSONDecoder().decode(TLSCertificateTransmission.self, from: Data(contentsOf: sentURL))
            let policy = try fixtureHostnamePolicy(root: root)
            let after = try String(contentsOf: countURL, encoding: .utf8)
            let evidence = TLSWrongHostRejectionEvidence(nativeFailure: nativeFailure,
                transmission: witness, normalPolicy: policy.normal, wrongHostPolicy: policy.wrong,
                admissionsBefore: Int(before.trimmingCharacters(in: .whitespacesAndNewlines)),
                admissionsAfter: Int(after.trimmingCharacters(in: .whitespacesAndNewlines)))
            try evidence.verify(expectedAttempt: certificateAttempt, expectedFingerprint: policy.fingerprint)
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
            ownerPrivateKey: ownerKey.rawRepresentation, ownerUserID: UUID().uuidString, envelope: envelope,
            channelOrigin: "wss://staging.haven.digipomps.org")
        // Only this newly generated synthetic server key crosses the process
        // boundary. The linked phone's private key remains in this test process.
        return (input, entry, phone)
    }

    /// Separate ordinary OS trust evaluation complements the actual native
    /// rejection and emitted-leaf witness. It does not claim that Foundation's
    /// WebSocket NSError exposes its original hostname-mismatch cause.
    private func fixtureHostnamePolicy(root: URL) throws
        -> (fingerprint: String, normal: TLSFixtureTrustEvaluation, wrong: TLSFixtureTrustEvaluation) {
        func certificate(_ name: String) throws -> (SecCertificate, Data) {
            let pem = try String(contentsOf: root.appendingPathComponent(name + ".pem"), encoding: .utf8)
            let base64 = pem.split(separator: "\n").filter { !$0.hasPrefix("-----") }.joined()
            let data = try XCTUnwrap(Data(base64Encoded: base64))
            return (try XCTUnwrap(SecCertificateCreateWithData(nil, data as CFData)), data)
        }
        let ca = try certificate("ca").0
        let normal = try certificate("server")
        let wrong = try certificate("wrong-host")
        func evaluate(_ leaf: SecCertificate) throws -> TLSFixtureTrustEvaluation {
            let policy = SecPolicyCreateSSL(true, "staging.haven.digipomps.org" as CFString)
            var trust: SecTrust?
            guard SecTrustCreateWithCertificates([leaf, ca] as CFArray, policy, &trust) == errSecSuccess else {
                throw FixtureFailure.invalidSetup
            }
            let actualTrust = try XCTUnwrap(trust)
            var error: CFError?
            let accepted = SecTrustEvaluateWithError(actualTrust, &error)
            return TLSFixtureTrustEvaluation(accepted: accepted,
                errorDomain: error.map { CFErrorGetDomain($0) as String },
                errorCode: error.map { CFErrorGetCode($0) })
        }
        return (SHA256.hash(data: wrong.1).map { String(format: "%02x", $0) }.joined(),
                try evaluate(normal.0), try evaluate(wrong.0))
    }

    private enum FixtureFailure: Error { case peerFailed, timeout, notLoopback, invalidSetup }
    private struct PeerInput: Codable {
        let root: String
        let port: Int
        let ownerUUID: String
        let ownerPrivateKey: Data
        let ownerUserID: String
        let envelope: IdentityLinkCompletionEnvelope
        let channelOrigin: String
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

/// A native error is only one part of this controlled wrong-host proof.
/// Apple TN2232 lists both -1200 and -1202 among server-trust failures. Neither
/// identifies Foundation's private cause on its own; require all independent
/// witnesses below, including ordinary OS hostname evaluation and no admission.
private struct TLSWrongHostRejectionEvidence {
    enum Failure: Error, Equatable {
        case nativeFailure, transmission, hostnamePolicy, admission
    }
    var nativeFailure: NSError?
    var transmission: TLSCertificateTransmission?
    var normalPolicy: TLSFixtureTrustEvaluation?
    var wrongHostPolicy: TLSFixtureTrustEvaluation?
    var admissionsBefore: Int?
    var admissionsAfter: Int?

    func verify(expectedAttempt: String, expectedFingerprint: String) throws {
        guard let nativeFailure, nativeFailure.domain == NSURLErrorDomain,
              [NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted].contains(nativeFailure.code)
        else { throw Failure.nativeFailure }
        guard let transmission,
              UUID(uuidString: expectedAttempt) != nil,
              transmission.attempt == expectedAttempt,
              transmission.serverName == "staging.haven.digipomps.org",
              expectedFingerprint.count == 64,
              expectedFingerprint.allSatisfy({ "0123456789abcdef".contains($0) }),
              transmission.certificateSHA256 == expectedFingerprint,
              transmission.messageType == 11
        else { throw Failure.transmission }
        guard let normalPolicy, normalPolicy.accepted,
              normalPolicy.errorDomain == nil, normalPolicy.errorCode == nil,
              let wrongHostPolicy, !wrongHostPolicy.accepted,
              wrongHostPolicy.errorDomain == NSOSStatusErrorDomain,
              wrongHostPolicy.errorCode == Int(errSecHostNameMismatch)
        else { throw Failure.hostnamePolicy }
        guard let admissionsBefore, admissionsBefore > 0,
              let admissionsAfter, admissionsAfter == admissionsBefore
        else { throw Failure.admission }
    }
}

private struct TLSCertificateTransmission: Decodable {
    var attempt: String
    var serverName: String
    var certificateSHA256: String
    var messageType: Int
}

private struct TLSFixtureTrustEvaluation {
    var accepted: Bool
    var errorDomain: String?
    var errorCode: Int?
}

/// Runs locally without networking, fixture trust, or any host configuration.
/// The hosted integration above supplies real observations to the same verifier.
final class PersonEntityReadTLSRejectionEvidenceTests: XCTestCase {
    private let attempt = "f8e68f4b-4194-4366-a663-6baf33782e7c"
    private let fingerprint = String(repeating: "a1", count: 32)

    private func completeEvidence(code: Int = NSURLErrorSecureConnectionFailed) -> TLSWrongHostRejectionEvidence {
        TLSWrongHostRejectionEvidence(nativeFailure: NSError(domain: NSURLErrorDomain, code: code),
            transmission: TLSCertificateTransmission(attempt: attempt, serverName: "staging.haven.digipomps.org",
                certificateSHA256: fingerprint, messageType: 11),
            normalPolicy: TLSFixtureTrustEvaluation(accepted: true, errorDomain: nil, errorCode: nil),
            wrongHostPolicy: TLSFixtureTrustEvaluation(accepted: false, errorDomain: NSOSStatusErrorDomain,
                errorCode: Int(errSecHostNameMismatch)), admissionsBefore: 3, admissionsAfter: 3)
    }

    private func expectRejected(_ failure: TLSWrongHostRejectionEvidence.Failure,
                                file: StaticString = #filePath, line: UInt = #line,
                                mutate: (inout TLSWrongHostRejectionEvidence) -> Void) {
        // Every negative witness must reject BOTH allowed native error variants.
        for code in [NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted] {
            var evidence = completeEvidence(code: code)
            mutate(&evidence)
            XCTAssertThrowsError(try evidence.verify(expectedAttempt: attempt, expectedFingerprint: fingerprint),
                                 file: file, line: line) {
                XCTAssertEqual($0 as? TLSWrongHostRejectionEvidence.Failure, failure, file: file, line: line)
            }
        }
    }

    func testBothNativeTrustErrorVariantsRequireCompleteEvidence() throws {
        for code in [NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted] {
            try completeEvidence(code: code).verify(expectedAttempt: attempt, expectedFingerprint: fingerprint)
        }
    }

    func testSuccessTimeoutCancellationResetAndGatewayDenialCannotPass() {
        expectRejected(.nativeFailure) { $0.nativeFailure = nil }
        for code in [NSURLErrorTimedOut, NSURLErrorCancelled, NSURLErrorNetworkConnectionLost,
                     NSURLErrorCannotConnectToHost, NSURLErrorBadServerResponse] {
            expectRejected(.nativeFailure) { $0.nativeFailure = NSError(domain: NSURLErrorDomain, code: code) }
        }
        expectRejected(.nativeFailure) { $0.nativeFailure = NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNRESET)) }
        expectRejected(.nativeFailure) { $0.nativeFailure = BindingPersonEntityReadRouteContract.Failure.denied as NSError }
        expectRejected(.nativeFailure) { $0.nativeFailure = NSError(domain: NSPOSIXErrorDomain, code: -1200) }
    }

    func testMissingOrStaleTransmissionCannotPass() {
        expectRejected(.transmission) { $0.transmission = nil }
        expectRejected(.transmission) { $0.transmission?.attempt = "471e0ff2-73bc-452c-ac04-5d2c7183b7bb" }
        expectRejected(.transmission) { $0.transmission?.attempt = "" }
    }

    func testDifferentHostLeafOrHandshakeCannotPass() {
        expectRejected(.transmission) { $0.transmission?.serverName = "wrong-host.invalid" }
        expectRejected(.transmission) { $0.transmission?.certificateSHA256 = String(repeating: "b2", count: 32) }
        expectRejected(.transmission) { $0.transmission?.certificateSHA256 = "" }
        expectRejected(.transmission) { $0.transmission?.messageType = 1 }
    }

    func testMissingOrFailedPositiveTrustControlCannotPass() {
        expectRejected(.hostnamePolicy) { $0.normalPolicy = nil }
        expectRejected(.hostnamePolicy) { $0.normalPolicy?.accepted = false }
        expectRejected(.hostnamePolicy) { $0.normalPolicy?.errorDomain = NSOSStatusErrorDomain }
        expectRejected(.hostnamePolicy) { $0.normalPolicy?.errorCode = Int(errSecHostNameMismatch) }
    }

    func testMissingOrAcceptedWrongHostPolicyCannotPass() {
        expectRejected(.hostnamePolicy) { $0.wrongHostPolicy = nil }
        expectRejected(.hostnamePolicy) { $0.wrongHostPolicy?.accepted = true }
        expectRejected(.hostnamePolicy) { $0.wrongHostPolicy?.errorDomain = nil }
        expectRejected(.hostnamePolicy) { $0.wrongHostPolicy?.errorCode = nil }
    }

    func testUnrelatedNativeTrustFailureCannotPass() {
        expectRejected(.hostnamePolicy) { $0.wrongHostPolicy?.errorDomain = NSURLErrorDomain }
        expectRejected(.hostnamePolicy) { $0.wrongHostPolicy?.errorCode = Int(errSecCertificateExpired) }
        expectRejected(.hostnamePolicy) { $0.wrongHostPolicy?.errorCode = Int(errSSLFatalAlert) }
    }

    func testMissingChangedOrImpossibleAdmissionCountsCannotPass() {
        expectRejected(.admission) { $0.admissionsBefore = nil }
        expectRejected(.admission) { $0.admissionsAfter = nil }
        expectRejected(.admission) { $0.admissionsBefore = -1; $0.admissionsAfter = -1 }
        expectRejected(.admission) { $0.admissionsBefore = 0; $0.admissionsAfter = 0 }
        expectRejected(.admission) { $0.admissionsAfter = 4 }
        expectRejected(.admission) { $0.admissionsAfter = 2 }
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
