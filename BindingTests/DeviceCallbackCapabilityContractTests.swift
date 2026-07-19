import Foundation
import Testing
import CellBase
@testable import Binding

@Suite(.serialized)
struct DeviceCallbackCapabilityContractTests {
    private let now = Date(timeIntervalSince1970: 1_784_454_400)

    @Test
    func signsExactRegistrationRequestWithDomainBoundIdentity() async throws {
        let fixture = try await makeFixture()
        let body = Data(#"{"participantId":"binding-participant","pushToken":"private-token"}"#.utf8)

        let request = try await fixture.issuer.issue(
            operation: .register,
            body: body,
            challenge: fixture.challenge,
            authority: fixture.authority,
            expectedAudience: DeviceCallbackCapabilityContract.stagingAudience,
            expectedOrigin: DeviceCallbackCapabilityContract.stagingOrigin,
            now: now
        )

        #expect(request.schema == DeviceCallbackCapabilityContract.requestSchema)
        #expect(request.method == "POST")
        #expect(request.path == "/conference-mvp/api/device/register")
        #expect(request.capability == "device.registration.write")
        #expect(request.bodySHA256 == DeviceCallbackCapabilityContract.sha256(body))
        #expect(request.requester.uuid == fixture.identity.uuid)
        #expect(request.domainBinding.domain == DeviceCallbackCapabilityContract.identityContext)
        #expect(request.domainBinding.grantsAuthority == false)

        let proof = try #require(request.proof)
        #expect(proof.byIdentityUUID == fixture.identity.uuid)
        #expect(IdentityPublicKeySignatureVerifier.verify(
            signature: proof.signature,
            messageData: try request.canonicalPayloadData(),
            descriptor: request.requester
        ))
    }

    @Test
    func bodyTamperingInvalidatesProof() async throws {
        let fixture = try await makeFixture()
        let body = Data("original".utf8)
        var request = try await fixture.issuer.issue(
            operation: .register,
            body: body,
            challenge: fixture.challenge,
            authority: fixture.authority,
            expectedAudience: DeviceCallbackCapabilityContract.stagingAudience,
            expectedOrigin: DeviceCallbackCapabilityContract.stagingOrigin,
            now: now
        )
        let proof = try #require(request.proof)
        request.bodySHA256 = DeviceCallbackCapabilityContract.sha256(Data("tampered".utf8))

        #expect(!IdentityPublicKeySignatureVerifier.verify(
            signature: proof.signature,
            messageData: try request.canonicalPayloadData(),
            descriptor: request.requester
        ))
    }

    @Test
    func authorizationUsesProofSchemeAndNeverBearer() async throws {
        let fixture = try await makeFixture()
        let request = try await fixture.issuer.issue(
            operation: .register,
            body: Data("body".utf8),
            challenge: fixture.challenge,
            authority: fixture.authority,
            expectedAudience: DeviceCallbackCapabilityContract.stagingAudience,
            expectedOrigin: DeviceCallbackCapabilityContract.stagingOrigin,
            now: now
        )

        let value = try DeviceCallbackCapabilityContract.authorizationValue(for: request)
        #expect(value.hasPrefix("HAVEN-Device-Proof "))
        #expect(!value.hasPrefix("Bearer "))
        #expect(!value.contains("private-token"))
    }

    @Test
    func refusesToCreateMissingNotificationIdentity() async throws {
        let vault = EphemeralIdentityVault()
        let fixture = try await makeFixture(vault: vault, createIdentity: false)

        await #expect(throws: DeviceCallbackCapabilityError.notificationIdentityUnavailable) {
            try await fixture.issuer.issue(
                operation: .register,
                body: Data("body".utf8),
                challenge: fixture.challenge,
                authority: fixture.authority,
                expectedAudience: DeviceCallbackCapabilityContract.stagingAudience,
                expectedOrigin: DeviceCallbackCapabilityContract.stagingOrigin,
                now: now
            )
        }
        #expect(await vault.identity(
            for: DeviceCallbackCapabilityContract.identityContext,
            makeNewIfNotFound: false
        ) == nil)
    }

    @Test @MainActor
    func refusesPromptFreeStartupVault() async throws {
        let previousVault = CellBase.defaultIdentityVault
        defer { CellBase.defaultIdentityVault = previousVault }
        CellBase.defaultIdentityVault = BindingStartupIdentityVault.shared

        #expect(throws: DeviceCallbackCapabilityError.authenticatedIdentityVaultUnavailable) {
            try DeviceCallbackAuthenticatedVaultHandle.current()
        }
    }

    @Test
    func rejectsWrongAudienceAndOrigin() async throws {
        let fixture = try await makeFixture()
        var wrongAudience = fixture.challenge
        wrongAudience.audience = "attacker.example"
        await expectInvalidChallenge(fixture: fixture, challenge: wrongAudience)

        var wrongOrigin = fixture.challenge
        wrongOrigin.origin = "https://attacker.example"
        await expectInvalidChallenge(fixture: fixture, challenge: wrongOrigin)
    }

    @Test
    func rejectsExpiredAndOverlongChallenges() async throws {
        let fixture = try await makeFixture()
        var expired = fixture.challenge
        expired.issuedAt = iso(now.addingTimeInterval(-60))
        expired.expiresAt = iso(now.addingTimeInterval(-1))
        await #expect(throws: DeviceCallbackCapabilityError.challengeExpired) {
            try await issue(fixture: fixture, challenge: expired)
        }

        var overlong = fixture.challenge
        overlong.expiresAt = iso(now.addingTimeInterval(301))
        await #expect(throws: DeviceCallbackCapabilityError.challengeLifetimeTooLong) {
            try await issue(fixture: fixture, challenge: overlong)
        }
    }

    @Test
    func rejectsMethodPathOrCapabilitySubstitution() async throws {
        let fixture = try await makeFixture()
        await #expect(throws: DeviceCallbackCapabilityError.challengeOperationMismatch) {
            try await fixture.issuer.issue(
                operation: .submit,
                body: Data("body".utf8),
                challenge: fixture.challenge,
                authority: fixture.authority,
                expectedAudience: DeviceCallbackCapabilityContract.stagingAudience,
                expectedOrigin: DeviceCallbackCapabilityContract.stagingOrigin,
                now: now
            )
        }

        var changedCapability = fixture.challenge
        changedCapability.capability = "device.callback.submit"
        await #expect(throws: DeviceCallbackCapabilityError.challengeOperationMismatch) {
            try await issue(fixture: fixture, challenge: changedCapability)
        }

        var changedMethod = fixture.challenge
        changedMethod.method = "GET"
        await #expect(throws: DeviceCallbackCapabilityError.challengeOperationMismatch) {
            try await issue(fixture: fixture, challenge: changedMethod)
        }

        var changedPath = fixture.challenge
        changedPath.path = "/conference-mvp/api/device/callback/submit"
        await #expect(throws: DeviceCallbackCapabilityError.challengeOperationMismatch) {
            try await issue(fixture: fixture, challenge: changedPath)
        }
    }

    @Test
    func rejectsWrongPurposeOrMalformedNonce() async throws {
        let fixture = try await makeFixture()
        var wrongPurpose = fixture.challenge
        wrongPurpose.purpose = "purpose://scaffold.operations"
        await expectInvalidChallenge(fixture: fixture, challenge: wrongPurpose)

        var shortNonce = fixture.challenge
        shortNonce.nonce = Data(repeating: 1, count: 15)
        await expectInvalidChallenge(fixture: fixture, challenge: shortNonce)

        var oversizedNonce = fixture.challenge
        oversizedNonce.nonce = Data(repeating: 1, count: 65)
        await expectInvalidChallenge(fixture: fixture, challenge: oversizedNonce)
    }

    @Test
    func rejectsAuthorityForAnotherIdentityOrExpiredAuthority() async throws {
        let fixture = try await makeFixture()
        var otherSubject = fixture.authority
        otherSubject.subjectIdentityUUID = UUID().uuidString
        await #expect(throws: DeviceCallbackCapabilityError.authoritySubjectMismatch) {
            try await issue(fixture: fixture, authority: otherSubject)
        }

        var otherFingerprint = fixture.authority
        otherFingerprint.subjectSigningKeyFingerprint = "another-fingerprint"
        await #expect(throws: DeviceCallbackCapabilityError.authoritySubjectMismatch) {
            try await issue(fixture: fixture, authority: otherFingerprint)
        }

        var expired = fixture.authority
        expired.issuedAt = iso(now.addingTimeInterval(-3_600))
        expired.validUntil = iso(now)
        await #expect(throws: DeviceCallbackCapabilityError.authorityExpired) {
            try await issue(fixture: fixture, authority: expired)
        }

        var overlong = fixture.authority
        overlong.validUntil = iso(
            now.addingTimeInterval(DeviceCallbackCapabilityContract.maximumAuthorityTTL + 1)
        )
        await #expect(throws: DeviceCallbackCapabilityError.invalidAuthorityReference) {
            try await issue(fixture: fixture, authority: overlong)
        }
    }

    @Test
    func operationContractBindsEveryProtectedPath() {
        #expect(Set(DeviceCallbackCapabilityContract.Operation.allCases.map(\.path)) == Set([
            "/conference-mvp/api/device/register",
            "/conference-mvp/api/device/callback/resolve",
            "/conference-mvp/api/device/callback/submit"
        ]))
        #expect(Set(DeviceCallbackCapabilityContract.Operation.allCases.map(\.capability)).count == 3)
    }

    @Test
    func rejectsEmptyAndOversizedBodiesBeforeSigning() async throws {
        let fixture = try await makeFixture()
        await #expect(throws: DeviceCallbackCapabilityError.requestBodyInvalid) {
            try await fixture.issuer.issue(
                operation: .register,
                body: Data(),
                challenge: fixture.challenge,
                authority: fixture.authority,
                expectedAudience: DeviceCallbackCapabilityContract.stagingAudience,
                expectedOrigin: DeviceCallbackCapabilityContract.stagingOrigin,
                now: now
            )
        }

        await #expect(throws: DeviceCallbackCapabilityError.requestBodyInvalid) {
            try await fixture.issuer.issue(
                operation: .register,
                body: Data(repeating: 0, count: DeviceCallbackCapabilityContract.maximumBodySize + 1),
                challenge: fixture.challenge,
                authority: fixture.authority,
                expectedAudience: DeviceCallbackCapabilityContract.stagingAudience,
                expectedOrigin: DeviceCallbackCapabilityContract.stagingOrigin,
                now: now
            )
        }
    }

    private struct Fixture {
        var issuer: DeviceCallbackCapabilityProofIssuer
        var challenge: DeviceCallbackCapabilityChallenge
        var authority: DeviceCallbackAuthorityReference
        var identity: Identity
    }

    private func makeFixture(
        vault: EphemeralIdentityVault = EphemeralIdentityVault(),
        createIdentity: Bool = true
    ) async throws -> Fixture {
        let identity = if createIdentity {
            try #require(await vault.identity(
                for: DeviceCallbackCapabilityContract.identityContext,
                makeNewIfNotFound: true
            ))
        } else {
            Identity(UUID().uuidString, displayName: "unprovisioned", identityVault: nil)
        }
        let challenge = DeviceCallbackCapabilityChallenge(
            challengeID: "challenge-1",
            nonce: Data(repeating: 7, count: 32),
            audience: DeviceCallbackCapabilityContract.stagingAudience,
            origin: DeviceCallbackCapabilityContract.stagingOrigin,
            operation: .register,
            issuedAt: iso(now),
            expiresAt: iso(now.addingTimeInterval(120))
        )
        let authority = DeviceCallbackAuthorityReference(
            credentialID: "credential-1",
            agreementID: "agreement-1",
            participantID: "binding-participant",
            deviceID: "device-1",
            subjectIdentityUUID: identity.uuid,
            subjectSigningKeyFingerprint: identity.signingPublicKeyFingerprint ?? "missing",
            issuedAt: iso(now),
            validUntil: iso(now.addingTimeInterval(3_600))
        )
        return Fixture(
            issuer: DeviceCallbackCapabilityProofIssuer(
                authenticatedVault: .testing(vault)
            ),
            challenge: challenge,
            authority: authority,
            identity: identity
        )
    }

    private func issue(
        fixture: Fixture,
        challenge: DeviceCallbackCapabilityChallenge? = nil,
        authority: DeviceCallbackAuthorityReference? = nil
    ) async throws -> DeviceCallbackSignedRequest {
        try await fixture.issuer.issue(
            operation: .register,
            body: Data("body".utf8),
            challenge: challenge ?? fixture.challenge,
            authority: authority ?? fixture.authority,
            expectedAudience: DeviceCallbackCapabilityContract.stagingAudience,
            expectedOrigin: DeviceCallbackCapabilityContract.stagingOrigin,
            now: now
        )
    }

    private func expectInvalidChallenge(
        fixture: Fixture,
        challenge: DeviceCallbackCapabilityChallenge
    ) async {
        await #expect(throws: DeviceCallbackCapabilityError.invalidChallenge) {
            try await issue(fixture: fixture, challenge: challenge)
        }
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
