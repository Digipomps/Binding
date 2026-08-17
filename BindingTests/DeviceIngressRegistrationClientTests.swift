import Foundation
import Testing
import Darwin
@_spi(HAVENRuntime) import CellBase
@testable import Binding

@Suite(.serialized)
struct DeviceIngressRegistrationClientTests {
    private let now = Date(timeIntervalSince1970: 1_784_454_400)
    private let audience = "staging.haven.digipomps.org"
    private let body = Data(#"{"participantId":"binding-participant","pushToken":"test-apns-token"}"#.utf8)

    @Test
    func registerPersistsExpectationBeforeSendAndRestoresVerifiedReceipt() async throws {
        let fixture = try await makeFixture()
        let buildProvenance = try makeBuildProvenance()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )

        let completed = try await client.register(
            protectedBody: body,
            entityLinkAuthorization: fixture.entityLinkAuthorization,
            consentEvidence: consent,
            now: now
        )
        let receipt = completed.receipt

        #expect(receipt.state == .activeConsented)
        #expect(receipt.deviceIdentityUUID == fixture.subject.uuid)
        #expect(await transport.sawPersistedExpectationBeforeSubmit())
        #expect(try await store.pendingExpectation() == nil)
        #expect(try await store.verifiedEvidence() != nil)
        #expect(fixture.entityLinkAuthorization.retainsEnvelopeForTesting() == false)

        let restartedStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let restartedClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: InertDeviceIngressRegistrationTransport(),
            evidenceStore: restartedStore,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )
        let restored = try await restartedClient.restoreHistoricalRegistrationEvidence()
        #expect(restored?.receiptAtMutation == receipt)
        #expect(restored?.admissionID.isEmpty == false)
        #expect(restored?.authorityGeneration == 1)
        #expect(restored?.revocationGeneration == 1)

        let persistedText = try persistedEvidenceText(in: fixture.evidenceDirectory)
        #expect(!persistedText.contains("test-apns-token"))
        #expect(!persistedText.contains("pushToken"))
    }

    @Test
    func oneShotProviderRetainsFailureAndConsumesOnlyAfterVerifiedReceipt() async throws {
        let provider = DeviceIngressOneShotCompletionEnvelopeProvider()
        let canonicalEnvelope = Data(#"{"schema":"fixture"}"#.utf8)
        try await provider.stage(canonicalCompletionEnvelope: canonicalEnvelope)
        #expect(await provider.hasStagedEnvelopeForTesting())
        let firstLease = try await provider.acquireCanonicalCompletionEnvelope()
        #expect(firstLease.canonicalCompletionEnvelope == canonicalEnvelope)
        #expect(await provider.hasStagedEnvelopeForTesting() == false)
        #expect(await provider.hasLeasedEnvelopeForTesting())
        await #expect(
            throws: DeviceIngressRegistrationClientError.completionEnvelopeUnavailable
        ) {
            try await provider.acquireCanonicalCompletionEnvelope()
        }

        try await provider.releaseCanonicalCompletionEnvelope(firstLease)
        #expect(await provider.hasStagedEnvelopeForTesting())
        #expect(await provider.hasLeasedEnvelopeForTesting() == false)

        let retryLease = try await provider.acquireCanonicalCompletionEnvelope()
        #expect(retryLease.canonicalCompletionEnvelope == canonicalEnvelope)
        try await provider.consumeCanonicalCompletionEnvelopeAfterVerifiedReceipt(
            retryLease
        )
        #expect(await provider.hasStagedEnvelopeForTesting() == false)
        #expect(await provider.hasLeasedEnvelopeForTesting() == false)
        await #expect(
            throws: DeviceIngressRegistrationClientError.completionEnvelopeUnavailable
        ) {
            try await provider.acquireCanonicalCompletionEnvelope()
        }
    }

    @Test
    func identityLinkIntakeSelectsNotificationIdentityOnlyForExactDeviceIngressPurpose() throws {
        let exact = #"{"audience":"staging.haven.digipomps.org","entityBinding":{"audience":"staging.haven.digipomps.org","bindingID":"entity-pairwise:fixture","mode":"pairwise"},"origin":"https://staging.haven.digipomps.org","purpose":"link_identity","requestedDomains":["domain:device:notification-callback"],"requestedIdentityContexts":["ios","device-ingress"],"requestedScopes":["device-ingress.register"]}"#
        let parsed = try #require(ConferenceIdentityLinkSupport.parse(raw: exact))
        #expect(parsed.requestsDeviceIngressRegistrationIdentity)
        #expect(parsed.entityBindingMode == "pairwise")
        #expect(parsed.entityBindingID == "entity-pairwise:fixture")
        #expect(parsed.entityBindingAudience == audience)

        let extraScope = exact.replacingOccurrences(
            of: #""device-ingress.register"]"#,
            with: #""device-ingress.register","device-ingress.admin"]"#
        )
        let rejected = try #require(
            ConferenceIdentityLinkSupport.parse(raw: extraScope)
        )
        #expect(rejected.requestsDeviceIngressRegistrationIdentity == false)
    }

    @Test
    func exactDeviceIngressChallengeKeepsIssuerPairwiseBindingWhenPhoneSigns() async throws {
        let store = ConferenceIdentityLinkInboxStore.shared
        await store.clear()
        let vault = await BindingStartupIdentityVault.shared.initialize()
        let identity = try #require(await vault.identity(
            for: DeviceIngressEnvelope.identityDomain,
            makeNewIfNotFound: true
        ))
        let expiresAt = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(600)
        )
        let nonce = Data((0..<32).map(UInt8.init))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let challenge = #"{"audience":"staging.haven.digipomps.org","entityBinding":{"audience":"staging.haven.digipomps.org","bindingID":"entity-pairwise:fixture","mode":"pairwise"},"expiresAt":"\#(expiresAt)","nonce":"\#(nonce)","origin":"https://staging.haven.digipomps.org","purpose":"link_identity","requestId":"device-ingress-fixture","requestedDomains":["domain:device:notification-callback"],"requestedIdentityContexts":["ios","device-ingress"],"requestedScopes":["device-ingress.register"]}"#
        await store.setDraftInput(challenge)
        #expect(await store.importDraft())
        await store.confirmLocalReview(with: identity)
        let state = await store.stateObject()
        guard case let .object(review)? = state["review"],
              case let .string(canonicalJSON)? = review["enrollmentRequestJSON"] else {
            Issue.record("Expected canonical signed enrollment request JSON")
            return
        }
        let request = try JSONDecoder().decode(
            IdentityEnrollmentRequest.self,
            from: Data(canonicalJSON.utf8)
        )
        #expect(request.entityBinding?.mode == .pairwise)
        #expect(request.entityBinding?.bindingID == "entity-pairwise:fixture")
        #expect(request.entityBinding?.audience == audience)
        #expect(request.newIdentity.uuid == identity.uuid)
        #expect(request.platform == "ios")
        #expect(request.proof != nil)
    }

    @Test
    func tamperedResponseNeverBecomesVerifiedAndLeavesPendingEvidence() async throws {
        let fixture = try await makeFixture()
        let buildProvenance = try makeBuildProvenance()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .nonCanonical
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )

        await #expect(throws: DeviceIngressResponseValidationError.nonCanonicalResponse) {
            try await client.register(
                protectedBody: body,
                entityLinkAuthorization: fixture.entityLinkAuthorization,
                consentEvidence: consent,
                now: now
            )
        }
        #expect(try await store.pendingExpectation() != nil)
        #expect(try await store.verifiedEvidence() == nil)
        #expect(await transport.submitCount() == 1)

        await #expect(throws: DeviceIngressRegistrationClientError.pendingRegistrationExists) {
            try await client.register(
                protectedBody: body,
                entityLinkAuthorization: fixture.entityLinkAuthorization,
                consentEvidence: consent,
                now: now
            )
        }
        #expect(await transport.submitCount() == 1)
    }

    @Test
    func missingPersistentDomainIdentityFailsBeforeTransport() async throws {
        let fixture = try await makeFixture()
        let emptyVault = EphemeralIdentityVault()
        let transport = CountingInertTransport()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(emptyVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: try makeBuildProvenance()
        )

        await #expect(throws: DeviceIngressRegistrationClientError.notificationIdentityUnavailable) {
            try await client.register(
                protectedBody: body,
                entityLinkAuthorization: fixture.entityLinkAuthorization,
                consentEvidence: try makeConsentEvidence(),
                now: now
            )
        }
        #expect(await transport.fetchCount() == 0)
        #expect(await emptyVault.identity(
            for: DeviceIngressEnvelope.identityDomain,
            makeNewIfNotFound: false
        ) == nil)
    }

    @Test
    func exactPersistedTermsAcceptanceIsRequiredBeforeSubmit() async throws {
        let fixture = try await makeFixture()
        let persistedConsent = try makeConsentEvidence(acceptanceID: "persisted")
        let presentedConsent = try makeConsentEvidence(acceptanceID: "presented")
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        try store.persistTermsAcceptance(persistedConsent)
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: try makeBuildProvenance()
        )

        await #expect(
            throws: DeviceIngressRegistrationClientError
                .persistedTermsAcceptanceRequired
        ) {
            try await client.register(
                protectedBody: body,
                entityLinkAuthorization: fixture.entityLinkAuthorization,
                consentEvidence: presentedConsent,
                now: now
            )
        }
        #expect(await transport.submitCount() == 0)
        #expect(try store.pendingExpectation() == nil)
        #expect(try store.termsConsentSnapshot().state == .accepted)
        #expect(try store.termsConsentSnapshot().acceptedEvidence == persistedConsent)
    }

    @Test
    func fileSynchronizationFailurePreventsSubmitAndLeavesNoPendingClaim() async throws {
        let fixture = try await makeFixture()
        let consent = try makeConsentEvidence()
        try FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        ).persistTermsAcceptance(consent)
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory,
            synchronizer: FailingDurabilitySynchronizer(failure: .file)
        )
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: try makeBuildProvenance()
        )

        await #expect(throws: TestDurabilityError.file) {
            try await client.register(
                protectedBody: body,
                entityLinkAuthorization: fixture.entityLinkAuthorization,
                consentEvidence: consent,
                now: now
            )
        }
        #expect(await transport.submitCount() == 0)
        #expect(try await store.pendingExpectation() == nil)
    }

    @Test
    func directorySynchronizationFailurePreventsSubmitAndFailsClosedOnRetry() async throws {
        let fixture = try await makeFixture()
        try createPrivateDirectory(fixture.evidenceDirectory)
        let consent = try makeConsentEvidence()
        try FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        ).persistTermsAcceptance(consent)
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory,
            synchronizer: FailingDurabilitySynchronizer(failure: .directory)
        )
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: try makeBuildProvenance()
        )

        await #expect(throws: TestDurabilityError.directory) {
            try await client.register(
                protectedBody: body,
                entityLinkAuthorization: fixture.entityLinkAuthorization,
                consentEvidence: consent,
                now: now
            )
        }
        #expect(await transport.submitCount() == 0)
        #expect(throws: DeviceIngressRegistrationClientError.invalidEvidenceJournal) {
            try store.pendingExpectation()
        }

        await #expect(throws: DeviceIngressRegistrationClientError.invalidEvidenceJournal) {
            try await client.register(
                protectedBody: body,
                entityLinkAuthorization: fixture.entityLinkAuthorization,
                consentEvidence: consent,
                now: now
            )
        }
        #expect(await transport.submitCount() == 0)
    }

    @Test
    func separateStoreInstancesPermitOnlyOneInFlightSubmit() async throws {
        let fixture = try await makeFixture()
        let firstStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let secondStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let consent = try makeConsentEvidence()
        try firstStore.persistTermsAcceptance(consent)
        let underlyingTransport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: firstStore,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let transport = GatedRegistrationTransport(underlying: underlyingTransport)
        let buildProvenance = try makeBuildProvenance()
        let firstClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: firstStore,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )
        let secondClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: secondStore,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )

        let firstRegistration = Task {
            try await firstClient.register(
                protectedBody: body,
                entityLinkAuthorization: fixture.entityLinkAuthorization,
                consentEvidence: consent,
                now: now
            )
        }
        await transport.waitUntilSubmitStarted()

        await #expect(throws: DeviceIngressRegistrationClientError.pendingRegistrationExists) {
            try await secondClient.register(
                protectedBody: body,
                entityLinkAuthorization: fixture.entityLinkAuthorization,
                consentEvidence: consent,
                now: now
            )
        }
        await transport.releaseSubmit()
        let receipt = try await firstRegistration.value

        #expect(receipt.receipt.state == .activeConsented)
        #expect(await underlyingTransport.submitCount() == 1)
    }

    #if os(macOS)
    @Test
    func canonicalPOSIXLockSerializesASeparateProcess() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lockf")
        process.arguments = [
            "-k",
            fixture.evidenceDirectory
                .appendingPathComponent("registration.lock").path,
            "/bin/sleep",
            "1"
        ]
        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
            }
            process.waitUntilExit()
        }

        // Give the separate process a bounded window to enter its command
        // after acquiring the same POSIX record lock. A missing/incompatible
        // OS lock makes this assertion fail quickly instead of hanging.
        try await Task.sleep(for: .milliseconds(100))
        let startedAt = Date().timeIntervalSinceReferenceDate
        let snapshot = try store.termsConsentSnapshot()
        let elapsed = Date().timeIntervalSinceReferenceDate - startedAt

        #expect(snapshot.acceptedEvidence == consent)
        #expect(elapsed >= 0.5)
    }
    #endif

    @Test
    func copiedVerifiedEvidenceIsRejectedByCurrentVaultIdentity() async throws {
        let fixture = try await makeFixture()
        let buildProvenance = try makeBuildProvenance()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let registeringClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )
        _ = try await registeringClient.register(
            protectedBody: body,
            entityLinkAuthorization: fixture.entityLinkAuthorization,
            consentEvidence: consent,
            now: now
        )

        let otherVault = EphemeralIdentityVault()
        var otherDeviceIdentity = Identity(
            fixture.subject.uuid,
            displayName: DeviceIngressEnvelope.identityDomain,
            identityVault: otherVault
        )
        await otherVault.addIdentity(
            identity: &otherDeviceIdentity,
            for: DeviceIngressEnvelope.identityDomain
        )
        #expect(otherDeviceIdentity.signingPublicKeyFingerprint
            != fixture.subject.signingPublicKeyFingerprint)

        let restoringClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(otherVault),
            transport: InertDeviceIngressRegistrationTransport(),
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )
        await #expect(
            throws: DeviceIngressRegistrationClientError
                .verifiedEvidenceDeviceIdentityMismatch
        ) {
            try await restoringClient.restoreHistoricalRegistrationEvidence()
        }
    }

    @Test
    func verifiedEvidenceFromDifferentBuildProvenanceIsRejected() async throws {
        let fixture = try await makeFixture()
        let registrationProvenance = try makeBuildProvenance()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let registeringClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: registrationProvenance
        )
        _ = try await registeringClient.register(
            protectedBody: body,
            entityLinkAuthorization: fixture.entityLinkAuthorization,
            consentEvidence: consent,
            now: now
        )

        let restoringClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: InertDeviceIngressRegistrationTransport(),
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: try makeBuildProvenance(bindingRevisionHex: "e")
        )
        await #expect(throws: DeviceIngressRegistrationClientError.buildProvenanceMismatch) {
            try await restoringClient.restoreHistoricalRegistrationEvidence()
        }
    }

    @Test
    func symlinkEvidenceIsRejectedWithoutFollowingIt() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        #expect(try await store.containsRegistrationEvidence() == false)
        let pendingURL = fixture.evidenceDirectory
            .appendingPathComponent("registration-state-journal.json")
        try FileManager.default.createSymbolicLink(
            at: pendingURL,
            withDestinationURL: fixture.evidenceDirectory
                .appendingPathComponent("nonexistent-target")
        )

        await #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "not-regular")
        ) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func hardLinkedEvidenceIsRejected() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)
        try await store.persistPending(
            try await makeExpectation(fixture),
            consentEvidence: consent
        )
        let pendingURL = fixture.evidenceDirectory
            .appendingPathComponent("registration-state-journal.json")
        try FileManager.default.linkItem(
            at: pendingURL,
            to: fixture.evidenceDirectory.appendingPathComponent("attacker-hardlink")
        )

        await #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "file-link-count")
        ) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func wrongModeEvidenceIsRejected() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)
        try await store.persistPending(
            try await makeExpectation(fixture),
            consentEvidence: consent
        )
        let path = fixture.evidenceDirectory
            .appendingPathComponent("registration-state-journal.json").path
        #expect(Darwin.chmod(path, 0o640) == 0)

        await #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "file-mode")
        ) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func applicationSupportLayoutAcceptsOwnedReadOnlyNamespacesAndKeepsEvidencePrivate() throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("BindingDeviceIngressApplicationSupportTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let applicationSupport = workspace
            .appendingPathComponent("Application Support", isDirectory: true)
        let bindingNamespace = applicationSupport
            .appendingPathComponent("Binding", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bindingNamespace,
            withIntermediateDirectories: true
        )
        #expect(Darwin.chmod(applicationSupport.path, 0o755) == 0)
        #expect(Darwin.chmod(bindingNamespace.path, 0o755) == 0)

        let store = FileDeviceIngressRegistrationEvidenceStore(
            testingAnchorDirectoryURL: applicationSupport,
            relativeDirectoryComponents: ["Binding", "DeviceIngressRegistration"]
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)

        #expect(try store.termsConsentSnapshot().acceptedEvidence == consent)
        let evidenceDirectory = bindingNamespace
            .appendingPathComponent("DeviceIngressRegistration", isDirectory: true)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: evidenceDirectory.path
        )
        #expect(
            (attributes[.posixPermissions] as? NSNumber)?.uint16Value == 0o700
        )
    }

    @Test
    func applicationSupportLayoutRejectsGroupWritableNamespace() throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("BindingDeviceIngressApplicationSupportTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let applicationSupport = workspace
            .appendingPathComponent("Application Support", isDirectory: true)
        let bindingNamespace = applicationSupport
            .appendingPathComponent("Binding", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bindingNamespace,
            withIntermediateDirectories: true
        )
        #expect(Darwin.chmod(applicationSupport.path, 0o755) == 0)
        #expect(Darwin.chmod(bindingNamespace.path, 0o775) == 0)

        let store = FileDeviceIngressRegistrationEvidenceStore(
            testingAnchorDirectoryURL: applicationSupport,
            relativeDirectoryComponents: ["Binding", "DeviceIngressRegistration"]
        )

        #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(
                reason: "directory-group-or-other-writable"
            )
        ) {
            try store.termsConsentSnapshot()
        }
    }

    @Test
    func applicationSupportLayoutRejectsMissingPrivateEvidenceDirectory() throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        try FileManager.default.createDirectory(
            at: workspace,
            withIntermediateDirectories: true
        )

        let store = FileDeviceIngressRegistrationEvidenceStore(
            testingAnchorDirectoryURL: workspace,
            relativeDirectoryComponents: []
        )

        #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(
                reason: "private-evidence-directory-missing"
            )
        ) {
            try store.termsConsentSnapshot()
        }
    }

    @Test
    func wrongOwnerMetadataIsRejectedByPolicy() {
        let metadata = DeviceIngressEvidenceMetadataSnapshot(
            device: 1,
            inode: 2,
            mode: UInt32(S_IFREG) | 0o600,
            owner: UInt32(geteuid()) &+ 1,
            linkCount: 1,
            size: 1,
            modificationSeconds: 1,
            modificationNanoseconds: 0,
            changeSeconds: 1,
            changeNanoseconds: 0
        )

        #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "file-owner")
        ) {
            try DeviceIngressEvidenceMetadataPolicy.validateRegularFile(
                metadata,
                expectedOwner: UInt32(geteuid()),
                maximumSize: 10
            )
        }
    }

    @Test
    func fifoEvidenceIsRejected() async throws {
        let fixture = try await makeFixture()
        try createPrivateDirectory(fixture.evidenceDirectory)
        let pendingPath = fixture.evidenceDirectory
            .appendingPathComponent("registration-state-journal.json").path
        #expect(Darwin.mkfifo(pendingPath, 0o600) == 0)
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )

        await #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "not-regular")
        ) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func pinnedDirectoryRejectsPathSwap() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        #expect(try await store.containsRegistrationEvidence() == false)
        let displaced = fixture.evidenceDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("displaced-evidence")
        try FileManager.default.moveItem(at: fixture.evidenceDirectory, to: displaced)
        try createPrivateDirectory(fixture.evidenceDirectory)

        await #expect(throws: DeviceIngressEvidenceFileError.pathIdentityChanged) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func concurrentWriterIsDetectedByBeforeAfterMetadata() async throws {
        let fixture = try await makeFixture()
        let pendingURL = fixture.evidenceDirectory
            .appendingPathComponent("registration-state-journal.json")
        let observer = ConcurrentEvidenceWriter(fileURL: pendingURL)
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory,
            readObserver: observer
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)
        try await store.persistPending(
            try await makeExpectation(fixture),
            consentEvidence: consent
        )
        observer.arm()

        await #expect(
            throws: DeviceIngressEvidenceFileError.contentChangedDuringAccess
        ) {
            try await store.pendingExpectation()
        }
        #expect(observer.didMutate)
    }

    @Test
    func canonicalLockReplacementAfterAcquisitionFailsClosed() async throws {
        let fixture = try await makeFixture()
        let observer = CanonicalLockReplacer(
            directoryURL: fixture.evidenceDirectory
        )
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory,
            readObserver: observer
        )

        await #expect(throws: DeviceIngressEvidenceFileError.pathIdentityChanged) {
            try await store.containsRegistrationEvidence()
        }
        #expect(observer.didReplace)
    }

    @Test
    func journalHashTamperingIsRejectedAfterRestart() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        try store.persistTermsAcceptance(try makeConsentEvidence())
        let journalURL = fixture.evidenceDirectory
            .appendingPathComponent("registration-state-journal.json")
        try replaceFirstByte(
            in: journalURL,
            matching: UInt8(ascii: "f"),
            with: UInt8(ascii: "e")
        )

        let restartedStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        #expect(throws: DeviceIngressRegistrationClientError.invalidEvidenceJournal) {
            try restartedStore.termsConsentSnapshot()
        }
    }

    @Test
    func validPrefixJournalRollbackIsRejectedAfterRestart() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let consent = try makeConsentEvidence()
        try store.persistTermsAcceptance(consent)
        let journalURL = fixture.evidenceDirectory
            .appendingPathComponent("registration-state-journal.json")
        let acceptedOnlyPrefix = try Data(contentsOf: journalURL)
        try store.persistPending(
            try await makeExpectation(fixture),
            consentEvidence: consent
        )

        try overwriteFileInPlace(acceptedOnlyPrefix, at: journalURL)

        let restartedStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        #expect(throws: DeviceIngressRegistrationClientError.invalidEvidenceJournal) {
            try restartedStore.termsConsentSnapshot()
        }
    }

    @Test
    func fullJournalRewriteAndRehashRollbackIsRejectedAfterRestart() async throws {
        let fixture = try await makeFixture()
        let targetStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let targetConsent = try makeConsentEvidence(acceptanceID: "target-acceptance")
        try targetStore.persistTermsAcceptance(targetConsent)
        try targetStore.persistPending(
            try await makeExpectation(fixture),
            consentEvidence: targetConsent
        )

        let rewrittenDirectory = fixture.evidenceDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("rewritten-evidence", isDirectory: true)
        let rewritingStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: rewrittenDirectory
        )
        try rewritingStore.persistTermsAcceptance(try makeConsentEvidence(
            acceptanceID: "attacker-rewritten-acceptance"
        ))
        let rewrittenJournal = try Data(contentsOf: rewrittenDirectory
            .appendingPathComponent("registration-state-journal.json"))
        try overwriteFileInPlace(
            rewrittenJournal,
            at: fixture.evidenceDirectory
                .appendingPathComponent("registration-state-journal.json")
        )

        let restartedStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        #expect(throws: DeviceIngressRegistrationClientError.invalidEvidenceJournal) {
            try restartedStore.termsConsentSnapshot()
        }
    }

    @Test
    func legacyPreJournalPendingEvidenceFailsClosedInsteadOfMigratingAuthority() async throws {
        let fixture = try await makeFixture()
        try createPrivateDirectory(fixture.evidenceDirectory)
        let legacyURL = fixture.evidenceDirectory
            .appendingPathComponent("pending-register-expectation.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(try await makeExpectation(fixture)).write(to: legacyURL)
        #expect(Darwin.chmod(legacyURL.path, 0o600) == 0)

        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        #expect(throws: DeviceIngressRegistrationClientError.invalidEvidenceJournal) {
            try store.termsConsentSnapshot()
        }
    }

    @Test
    func durablePreRegistrationDeclineBlocksPreparedRegisterUntilExplicitAccept() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let expectation = try await makeExpectation(fixture)
        let consent = try makeConsentEvidence()
        var clearedLocalState = false

        try store.performPreRegistrationDecline {
            clearedLocalState = true
        }

        #expect(clearedLocalState)
        await #expect(throws: DeviceIngressRegistrationClientError.preRegistrationDeclined) {
            try await store.persistPending(
                expectation,
                consentEvidence: consent
            )
        }

        try store.persistTermsAcceptance(consent)
        try await store.persistPending(
            expectation,
            consentEvidence: consent
        )
        #expect(try await store.pendingExpectation() == expectation)
    }

    @Test
    func declineAndPendingPersistenceRaceNeverBothCrossTheGate() async throws {
        let fixture = try await makeFixture()
        try createPrivateDirectory(fixture.evidenceDirectory)
        let expectation = try await makeExpectation(fixture)

        for iteration in 0..<16 {
            let directory = fixture.evidenceDirectory
                .appendingPathComponent("race-\(iteration)", isDirectory: true)
            let declineStore = FileDeviceIngressRegistrationEvidenceStore(
                directoryURL: directory
            )
            let registrationStore = FileDeviceIngressRegistrationEvidenceStore(
                directoryURL: directory
            )
            let consent = try makeConsentEvidence(acceptanceID: "race-\(iteration)")
            try registrationStore.persistTermsAcceptance(consent)

            let outcomes = await withTaskGroup(
                of: DeclineRegistrationRaceOutcome.self,
                returning: [DeclineRegistrationRaceOutcome].self
            ) { group in
                group.addTask {
                    do {
                        try declineStore.performPreRegistrationDecline {}
                        return .declineSucceeded
                    } catch {
                        return .declineRejected
                    }
                }
                group.addTask {
                    do {
                        try registrationStore.persistPending(
                            expectation,
                            consentEvidence: consent
                        )
                        return .registrationSucceeded
                    } catch {
                        return .registrationRejected
                    }
                }
                var values: [DeclineRegistrationRaceOutcome] = []
                for await value in group { values.append(value) }
                return values
            }

            let declineWon = outcomes.contains(.declineSucceeded)
                && outcomes.contains(.registrationRejected)
            let registrationWon = outcomes.contains(.registrationSucceeded)
                && outcomes.contains(.declineRejected)
            #expect(declineWon != registrationWon)
        }
    }

    @Test @MainActor
    func promptFreeStartupVaultCannotBeUsedAsAuthenticatedDeviceVault() async {
        let previousVault = CellBase.defaultIdentityVault
        defer { CellBase.defaultIdentityVault = previousVault }
        CellBase.defaultIdentityVault = BindingStartupIdentityVault.shared

        await #expect(
            throws: DeviceIngressRegistrationClientError.authenticatedIdentityVaultUnavailable
        ) {
            try await DeviceIngressAuthenticatedVaultHandle.current()
        }
        await #expect(
            throws: DeviceIngressRegistrationClientError.authenticatedIdentityVaultUnavailable
        ) {
            try await DeviceIngressAuthenticatedVaultHandle
                .prepareCurrentForExplicitEnrollment()
        }
    }

    @Test
    func explicitEnrollmentProvisioningCreatesOnlyTheRequiredPrivateBinding() async throws {
        let emptyVault = EphemeralIdentityVault()
        #expect(await emptyVault.identity(
            for: "private",
            makeNewIfNotFound: false
        ) == nil)

        await #expect(
            throws: DeviceIngressRegistrationClientError.authenticatedIdentityVaultUnavailable
        ) {
            try await DeviceIngressAuthenticatedVaultHandle.testingValidated(
                emptyVault,
                provisionPrivateIdentityIfMissing: false
            )
        }

        _ = try await DeviceIngressAuthenticatedVaultHandle.testingValidated(
            emptyVault,
            provisionPrivateIdentityIfMissing: true
        )
        let privateIdentity = try #require(await emptyVault.identity(
            for: "private",
            makeNewIfNotFound: false
        ))
        let binding = try #require(await emptyVault.identityDomainBinding(
            for: privateIdentity
        ))
        #expect(binding.domain == "private")
        #expect(binding.matches(identity: privateIdentity))
        #expect(binding.grantsAuthority == false)
    }

    @Test @MainActor
    func runtimeCompositionFailsClosedWithoutAuthenticatedVault() async {
        await #expect(throws: DeviceIngressRegistrationClientError.authenticatedIdentityVaultUnavailable) {
            try await BindingDeviceIngressRegistrationComposition.register(
                protectedBody: Data("test".utf8),
                consentEvidence: try makeConsentEvidence(),
                buildProvenance: try makeBuildProvenance()
            )
        }
    }

    @Test
    func identityBoundRegistrationBodyReplacesCallerIdentityAndConsent() throws {
        let consent = try makeConsentEvidence()
        let callerBody = try JSONEncoder().encode([
            "schema": JSONValue.string(
                "binding.device-registration.body.v3-candidate"
            ),
            "participantId": .string("caller-participant"),
            "deviceId": .string("caller-device"),
            "termsAccepted": .bool(true),
            "termsConsentState": .string("declined"),
            "termsAcceptanceEvidence": .object(["state": .string("declined")])
        ])

        let protectedBody = try BindingDeviceIngressRegistrationComposition
            .identityBoundRegistrationBody(
                callerBody,
                participantID: "entity-pairwise:test-binding",
                deviceIdentityUUID: "device-identity",
                consentEvidence: consent
            )
        let payload = try JSONDecoder().decode(
            [String: JSONValue].self,
            from: protectedBody
        )

        #expect(payload["participantId"] == .string("entity-pairwise:test-binding"))
        #expect(payload["deviceId"] == .string("device-identity"))
        #expect(payload["termsAccepted"] == nil)
        #expect(payload["termsConsentState"] == .string("accepted"))
        #expect(
            payload["termsAcceptanceEvidence"]
                == .object(consent.registrationObject)
        )
    }

    @Test
    func runtimeConfigurationAcceptsExplicitMatchingIssuerDescriptor() throws {
        let configuration = try BindingDeviceIngressRuntimeConfiguration.validated(
            originText: "https://staging.haven.digipomps.org",
            audienceText: "staging.haven.digipomps.org",
            issuerBase64Text: "eyJhbGdvcml0aG0iOiJFZERTQSIsImN1cnZlVHlwZSI6IkN1cnZlMjU1MTkiLCJwdWJsaWNLZXkiOiJPb0tqN3Q4L2dXajVKRFhwbjVuZmdUcFZoMTAxbWtGcFNIeG9JOWtoOEdJPSIsInV1aWQiOiI2N0YxMjU2Ny1BMUFBLTQ0NjUtQUNBRi1GRkQ5RUE0RUQzOTIifQ==",
            rolloutEnvironmentText: "staging"
        )

        #expect(configuration.origin.absoluteString == "https://staging.haven.digipomps.org")
        #expect(configuration.trust.expectedAudience == "staging.haven.digipomps.org")
        #expect(
            configuration.trust.expectedChallengeIssuer.uuid
                == "67F12567-A1AA-4465-ACAF-FFD9EA4ED392"
        )
        #expect(
            configuration.trust.expectedChallengeIssuer.publicKey
                == Data(base64Encoded: "OoKj7t8/gWj5JDXpn5nfgTpVh101mkFpSHxoI9kh8GI=")
        )
    }

    @Test
    func runtimeConfigurationRejectsAudienceOrIssuerSubstitution() {
        let issuer = "eyJhbGdvcml0aG0iOiJFZERTQSIsImN1cnZlVHlwZSI6IkN1cnZlMjU1MTkiLCJwdWJsaWNLZXkiOiJPb0tqN3Q4L2dXajVKRFhwbjVuZmdUcFZoMTAxbWtGcFNIeG9JOWtoOEdJPSIsInV1aWQiOiI2N0YxMjU2Ny1BMUFBLTQ0NjUtQUNBRi1GRkQ5RUE0RUQzOTIifQ=="

        #expect(throws: DeviceIngressRegistrationClientError.invalidTransportConfiguration) {
            try BindingDeviceIngressRuntimeConfiguration.validated(
                originText: "https://staging.haven.digipomps.org",
                audienceText: "attacker.example",
                issuerBase64Text: issuer,
                rolloutEnvironmentText: "staging"
            )
        }
        #expect(throws: DeviceIngressRegistrationClientError.invalidTransportConfiguration) {
            try BindingDeviceIngressRuntimeConfiguration.validated(
                originText: "https://staging.haven.digipomps.org",
                audienceText: "staging.haven.digipomps.org",
                issuerBase64Text: "not-a-public-identity",
                rolloutEnvironmentText: "staging"
            )
        }
    }

    @Test
    func rolloutRequiresExplicitEnvironmentAndExactEndpointBinding() {
        #expect(BindingDeviceIngressRolloutPolicy.isEnrollmentEnabled(
            environmentText: "staging",
            platformIsIOS: true,
            configurationIsValid: true
        ))
        #expect(BindingDeviceIngressRolloutPolicy.isEnrollmentEnabled(
            environmentText: "production",
            platformIsIOS: true,
            configurationIsValid: true
        ))
        #expect(!BindingDeviceIngressRolloutPolicy.isEnrollmentEnabled(
            environmentText: "disabled",
            platformIsIOS: true,
            configurationIsValid: true
        ))
        #expect(!BindingDeviceIngressRolloutPolicy.isEnrollmentEnabled(
            environmentText: nil,
            platformIsIOS: true,
            configurationIsValid: true
        ))
        #expect(!BindingDeviceIngressRolloutPolicy.isEnrollmentEnabled(
            environmentText: "$(HAVEN_DEVICE_INGRESS_ROLLOUT_ENVIRONMENT)",
            platformIsIOS: true,
            configurationIsValid: true
        ))
        #expect(!BindingDeviceIngressRolloutPolicy.isEnrollmentEnabled(
            environmentText: "staging",
            platformIsIOS: false,
            configurationIsValid: true
        ))
        #expect(!BindingDeviceIngressRolloutPolicy.isEnrollmentEnabled(
            environmentText: "staging",
            platformIsIOS: true,
            configurationIsValid: false
        ))

        let issuer = "eyJhbGdvcml0aG0iOiJFZERTQSIsImN1cnZlVHlwZSI6IkN1cnZlMjU1MTkiLCJwdWJsaWNLZXkiOiJPb0tqN3Q4L2dXajVKRFhwbjVuZmdUcFZoMTAxbWtGcFNIeG9JOWtoOEdJPSIsInV1aWQiOiI2N0YxMjU2Ny1BMUFBLTQ0NjUtQUNBRi1GRkQ5RUE0RUQzOTIifQ=="
        #expect(throws: DeviceIngressRegistrationClientError.invalidTransportConfiguration) {
            try BindingDeviceIngressRuntimeConfiguration.validated(
                originText: "https://haven.digipomps.org",
                audienceText: "haven.digipomps.org",
                issuerBase64Text: issuer,
                rolloutEnvironmentText: "staging"
            )
        }
        #expect(throws: DeviceIngressRegistrationClientError.invalidTransportConfiguration) {
            try BindingDeviceIngressRuntimeConfiguration.validated(
                originText: "https://staging.haven.digipomps.org",
                audienceText: "staging.haven.digipomps.org",
                issuerBase64Text: issuer,
                rolloutEnvironmentText: "disabled"
            )
        }
    }

    @Test
    func httpsTransportPostsCanonicalChallengeAndRegisterEnvelopes() async throws {
        let fixture = try await makeFixture()
        let challengeResponse = Data("challenge-response".utf8)
        let registerResponse = Data("register-response".utf8)
        DeviceIngressFixtureURLProtocol.install { request in
            let responseBody: Data
            switch request.url?.path {
            case "/conference-mvp/api/device/challenge":
                responseBody = challengeResponse
            case "/conference-mvp/api/device/register":
                responseBody = registerResponse
            default:
                return (404, Data())
            }
            return (200, responseBody)
        }
        defer { DeviceIngressFixtureURLProtocol.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeviceIngressFixtureURLProtocol.self]
        let transport = try URLSessionDeviceIngressRegistrationTransport(
            origin: try #require(URL(string: "https://staging.haven.digipomps.org")),
            session: URLSession(configuration: configuration)
        )
        let subject = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: fixture.subject)
        )

        #expect(try await transport.fetchRegisterChallenge(
            subject: subject,
            canonicalEntityLink: Data("entity-link".utf8)
        ) == challengeResponse)
        #expect(try await transport.submitRegister(
            canonicalChallengeData: Data("challenge".utf8),
            canonicalRequestData: Data("request".utf8),
            protectedBody: Data("body".utf8)
        ) == registerResponse)

        let requests = DeviceIngressFixtureURLProtocol.capturedRequests()
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.method == "POST" })
        #expect(requests.allSatisfy { $0.host == "staging.haven.digipomps.org" })
        #expect(requests.map(\.path) == [
            "/conference-mvp/api/device/challenge",
            "/conference-mvp/api/device/register"
        ])

        let challengeJSON = try #require(
            try JSONSerialization.jsonObject(with: requests[0].body) as? [String: Any]
        )
        #expect(challengeJSON["schema"] as? String == "haven.device-ingress.challenge-request.v2")
        #expect(challengeJSON["operation"] as? String == "register")
        #expect(challengeJSON["canonicalEntityLink"] as? String
            == Data("entity-link".utf8).base64EncodedString())

        let registerJSON = try #require(
            try JSONSerialization.jsonObject(with: requests[1].body) as? [String: Any]
        )
        #expect(registerJSON["schema"] as? String == "haven.device-callback.transport.v3")
        #expect(registerJSON["canonicalChallenge"] as? String
            == Data("challenge".utf8).base64EncodedString())
        #expect(registerJSON["canonicalRequest"] as? String
            == Data("request".utf8).base64EncodedString())
        #expect(registerJSON["protectedBody"] as? String
            == Data("body".utf8).base64EncodedString())
    }

    @Test
    func httpsTransportRejectsInsecureOriginAndNonSuccessResponse() async throws {
        #expect(throws: DeviceIngressRegistrationClientError.invalidTransportConfiguration) {
            _ = try URLSessionDeviceIngressRegistrationTransport(
                origin: try #require(URL(string: "http://staging.haven.digipomps.org"))
            )
        }

        let fixture = try await makeFixture()
        DeviceIngressFixtureURLProtocol.install { _ in
            (
                503,
                Data(#"{"code":"device-callback-admission-unavailable","error":true}"#.utf8)
            )
        }
        defer { DeviceIngressFixtureURLProtocol.reset() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeviceIngressFixtureURLProtocol.self]
        let transport = try URLSessionDeviceIngressRegistrationTransport(
            origin: try #require(URL(string: "https://staging.haven.digipomps.org")),
            session: URLSession(configuration: configuration)
        )
        let subject = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: fixture.subject)
        )

        do {
            try await transport.fetchRegisterChallenge(
                subject: subject,
                canonicalEntityLink: Data("entity-link".utf8)
            )
            Issue.record("Expected safe DeviceIngress transport failure")
        } catch let failure as DeviceIngressTransportFailure {
            #expect(failure.stage == .challenge)
            #expect(failure.httpStatus == 503)
            #expect(failure.serverCode == "device-callback-admission-unavailable")
            #expect(failure.urlErrorCode == nil)
            #expect(failure.localizedDescription.contains("entity-link") == false)
        } catch {
            Issue.record("Unexpected transport error: \(type(of: error))")
        }
    }

    #if os(macOS)
    @Test
    func ignoredSourceLikeFileOutsideSwiftFileListIsRejectedByProvenanceGenerator() throws {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("BindingProvenanceGeneratorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: workspace) }

        let syntheticRoot = workspace.appendingPathComponent("Binding", isDirectory: true)
        let bindingRoot = syntheticRoot.appendingPathComponent("Binding", isDirectory: true)
        let ignoredRoot = bindingRoot.appendingPathComponent(".sprout", isDirectory: true)
        let cellsRoot = syntheticRoot.appendingPathComponent("Cells", isDirectory: true)
        let objectRoot = workspace.appendingPathComponent("Objects/arm64", isDirectory: true)
        let productsRoot = workspace.appendingPathComponent("Products", isDirectory: true)
        let sdkRoot = workspace.appendingPathComponent("SDK", isDirectory: true)
        let projectRoot = syntheticRoot.appendingPathComponent(
            "Binding.xcodeproj",
            isDirectory: true
        )
        let packageRoot = projectRoot.appendingPathComponent(
            "project.xcworkspace/xcshareddata/swiftpm",
            isDirectory: true
        )
        for directory in [
            ignoredRoot,
            cellsRoot,
            objectRoot,
            productsRoot,
            sdkRoot,
            packageRoot,
            workspace.appendingPathComponent("CellProtocol", isDirectory: true),
            workspace.appendingPathComponent("TargetTemp/DerivedSources", isDirectory: true),
            workspace.appendingPathComponent("Output", isDirectory: true)
        ] {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        let includedBinding = bindingRoot.appendingPathComponent("Included.swift")
        let ignoredBinding = ignoredRoot.appendingPathComponent("Unattested.swift")
        let includedCell = cellsRoot.appendingPathComponent("IncludedCell.swift")
        try writeTestFile("struct Included {}\n", to: includedBinding)
        try writeTestFile("struct Unattested {}\n", to: ignoredBinding)
        try writeTestFile("struct IncludedCell {}\n", to: includedCell)
        try writeTestFile("Binding/.sprout/\n", to: syntheticRoot.appendingPathComponent(".gitignore"))
        try writeTestFile(
            "\(includedBinding.path)\n\(includedCell.path)\n",
            to: objectRoot.appendingPathComponent("HAVEN.SwiftFileList")
        )
        for file in [
            objectRoot.appendingPathComponent("HAVEN.LinkFileList"),
            objectRoot.appendingPathComponent("Binding.swiftmodule"),
            productsRoot.appendingPathComponent("CellBase.o"),
            productsRoot.appendingPathComponent("CellApple.o"),
            sdkRoot.appendingPathComponent("SDKSettings.plist"),
            projectRoot.appendingPathComponent("project.pbxproj"),
            packageRoot.appendingPathComponent("Package.resolved")
        ] {
            try writeTestFile("fixture\n", to: file)
        }

        try initializeGitRepository(at: syntheticRoot)
        try initializeGitRepository(
            at: workspace.appendingPathComponent("CellProtocol", isDirectory: true)
        )

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let generator = repositoryRoot
            .appendingPathComponent("Scripts/generate_binding_build_provenance.sh")
        let standardError = Pipe()
        let process = Process()
        process.executableURL = generator
        process.arguments = [
            workspace.appendingPathComponent("Output/provenance.plist").path,
            workspace.appendingPathComponent("Output/manifest.txt").path
        ]
        process.standardError = standardError
        process.environment = ProcessInfo.processInfo.environment.merging([
            "SRCROOT": syntheticRoot.path,
            "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer",
            "TOOLCHAIN_DIR": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain",
            "OBJECT_FILE_DIR_normal": workspace.appendingPathComponent("Objects").path,
            "ARCHS": "arm64",
            "CURRENT_ARCH": "undefined_arch",
            "PRODUCT_NAME": "HAVEN",
            "PRODUCT_MODULE_NAME": "Binding",
            "BUILT_PRODUCTS_DIR": productsRoot.path,
            "SDKROOT": sdkRoot.path,
            "PROJECT_FILE_PATH": projectRoot.path,
            "TARGET_TEMP_DIR": workspace.appendingPathComponent("TargetTemp").path,
            "CODE_SIGNING_ALLOWED": "NO"
        ]) { _, fixture in fixture }

        try process.run()
        process.waitUntilExit()
        let errorText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        #expect(process.terminationStatus == 65)
        #expect(errorText.contains("ignored source-like file is not attested"))
    }

    @Test
    func dirtyReleaseSourceIsRejectedByProvenanceGenerator() throws {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("BindingDirtyReleaseTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: workspace) }

        let syntheticRoot = workspace.appendingPathComponent("Binding", isDirectory: true)
        let bindingRoot = syntheticRoot.appendingPathComponent("Binding", isDirectory: true)
        let cellsRoot = syntheticRoot.appendingPathComponent("Cells", isDirectory: true)
        let cellProtocolRoot = workspace.appendingPathComponent(
            "CellProtocol",
            isDirectory: true
        )
        let objectRoot = workspace.appendingPathComponent("Objects/arm64", isDirectory: true)
        let productsRoot = workspace.appendingPathComponent("Products", isDirectory: true)
        let sdkRoot = workspace.appendingPathComponent("SDK", isDirectory: true)
        let projectRoot = syntheticRoot.appendingPathComponent(
            "Binding.xcodeproj",
            isDirectory: true
        )
        let packageRoot = projectRoot.appendingPathComponent(
            "project.xcworkspace/xcshareddata/swiftpm",
            isDirectory: true
        )
        for directory in [
            bindingRoot,
            cellsRoot,
            cellProtocolRoot,
            objectRoot,
            productsRoot,
            sdkRoot,
            packageRoot,
            workspace.appendingPathComponent("TargetTemp/DerivedSources", isDirectory: true),
            workspace.appendingPathComponent("Output", isDirectory: true)
        ] {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        for file in [
            objectRoot.appendingPathComponent("HAVEN.SwiftFileList"),
            objectRoot.appendingPathComponent("HAVEN.LinkFileList"),
            objectRoot.appendingPathComponent("Binding.swiftmodule"),
            productsRoot.appendingPathComponent("CellBase.o"),
            productsRoot.appendingPathComponent("CellApple.o"),
            sdkRoot.appendingPathComponent("SDKSettings.plist"),
            projectRoot.appendingPathComponent("project.pbxproj"),
            packageRoot.appendingPathComponent("Package.resolved")
        ] {
            try writeTestFile("fixture\n", to: file)
        }
        try initializeGitRepository(at: syntheticRoot)
        try initializeGitRepository(at: cellProtocolRoot)
        try writeTestFile(
            "struct DirtyReleaseSource {}\n",
            to: bindingRoot.appendingPathComponent("DirtyReleaseSource.swift")
        )

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let generator = repositoryRoot
            .appendingPathComponent("Scripts/generate_binding_build_provenance.sh")
        let standardError = Pipe()
        let process = Process()
        process.executableURL = generator
        process.arguments = [
            workspace.appendingPathComponent("Output/provenance.plist").path,
            workspace.appendingPathComponent("Output/manifest.txt").path
        ]
        process.standardError = standardError
        process.environment = ProcessInfo.processInfo.environment.merging([
            "SRCROOT": syntheticRoot.path,
            "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer",
            "TOOLCHAIN_DIR": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain",
            "OBJECT_FILE_DIR_normal": workspace.appendingPathComponent("Objects").path,
            "ARCHS": "arm64",
            "CURRENT_ARCH": "undefined_arch",
            "PRODUCT_NAME": "HAVEN",
            "PRODUCT_MODULE_NAME": "Binding",
            "BUILT_PRODUCTS_DIR": productsRoot.path,
            "SDKROOT": sdkRoot.path,
            "PROJECT_FILE_PATH": projectRoot.path,
            "TARGET_TEMP_DIR": workspace.appendingPathComponent("TargetTemp").path,
            "CONFIGURATION": "Release",
            "CODE_SIGNING_ALLOWED": "NO"
        ]) { _, fixture in fixture }

        try process.run()
        process.waitUntilExit()
        let errorText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        #expect(process.terminationStatus == 65)
        #expect(errorText.contains("release build attestation refuses dirty"))
    }
    #endif

    private struct Fixture {
        let subjectVault: EphemeralIdentityVault
        let subject: Identity
        let targetOwner: Identity
        let challengeData: Data
        let trust: DeviceIngressRegistrationTrustConfiguration
        let entityLinkAuthorization: DeviceIngressVerifiedEntityLinkAuthorization
        let evidenceDirectory: URL
    }

    private func makeFixture() async throws -> Fixture {
        let issuerVault = EphemeralIdentityVault()
        var issuer = Identity(
            "11111111-1111-4111-8111-111111111111",
            displayName: "fixture-issuer",
            identityVault: issuerVault
        )
        await issuerVault.addIdentity(
            identity: &issuer,
            for: "domain:test:device-ingress-issuer"
        )
        let issuerDescriptor = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: issuer)
        )

        let subjectVault = EphemeralIdentityVault()
        var subject = Identity(
            "22222222-2222-4222-8222-222222222222",
            displayName: DeviceIngressEnvelope.identityDomain,
            identityVault: subjectVault
        )
        await subjectVault.addIdentity(
            identity: &subject,
            for: DeviceIngressEnvelope.identityDomain
        )
        let subjectDescriptor = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: subject)
        )

        let ownerVault = EphemeralIdentityVault()
        var targetOwner = Identity(
            "33333333-3333-4333-8333-333333333333",
            displayName: "fixture-owner",
            identityVault: ownerVault
        )
        await ownerVault.addIdentity(
            identity: &targetOwner,
            for: "domain:test:device-registration-owner"
        )

        let contentPolicy = DeviceIngressContentPolicy(
            requestBodyContentContractSHA256: Data(repeating: 0xA1, count: 32),
            responseContentContractSHA256: Data(repeating: 0xB2, count: 32)
        )
        let authority = DeviceIngressAuthorityReference(
            authorityID: "fixture-authority-1",
            agreementID: "fixture-agreement-1",
            targetCellUUID: "66666666-6666-4666-8666-666666666666",
            targetOwnerIdentityUUID: targetOwner.uuid,
            targetOwnerSigningKeyFingerprint: try #require(targetOwner.signingPublicKeyFingerprint),
            signedAgreementSHA256: Data(repeating: 0xC3, count: 32),
            subjectIdentityUUID: subject.uuid,
            subjectSigningKeyFingerprint: try #require(subject.signingPublicKeyFingerprint),
            authorityGeneration: 1,
            revocationLedgerID: "fixture-revocations-1",
            revocationGeneration: 1,
            contentPolicy: contentPolicy,
            issuedAtMilliseconds: milliseconds(now.addingTimeInterval(-60)),
            validUntilMilliseconds: milliseconds(now.addingTimeInterval(3_600))
        )
        let challengeData = try await DeviceIngressChallengeFactory.issue(
            operation: .register,
            audience: audience,
            subject: subjectDescriptor,
            authority: authority,
            issuer: issuer,
            now: now,
            lifetimeMilliseconds: 120_000
        )

        let evidenceAnchor = FileManager.default.temporaryDirectory
            .appendingPathComponent("BindingDeviceIngressTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try createPrivateDirectory(evidenceAnchor)

        let trust = DeviceIngressRegistrationTrustConfiguration(
            expectedAudience: audience,
            expectedChallengeIssuer: issuerDescriptor
        )
        let entityLinkAuthorization = try await makeEntityLinkAuthorization(
            subject: subject,
            issuer: issuer,
            trust: trust
        )

        return Fixture(
            subjectVault: subjectVault,
            subject: subject,
            targetOwner: targetOwner,
            challengeData: challengeData,
            trust: trust,
            entityLinkAuthorization: entityLinkAuthorization,
            evidenceDirectory: evidenceAnchor
                .appendingPathComponent("evidence", isDirectory: true)
        )
    }

    private func makeEntityLinkAuthorization(
        subject: Identity,
        issuer: Identity,
        trust: DeviceIngressRegistrationTrustConfiguration
    ) async throws -> DeviceIngressVerifiedEntityLinkAuthorization {
        let subjectDescriptor = try IdentityLinkProtocolService.descriptor(for: subject)
        let issuerDescriptor = try IdentityLinkProtocolService.descriptor(for: issuer)
        let bindingID = try pairwiseBindingID(
            entity: issuerDescriptor,
            audience: trust.expectedAudience
        )
        var request = IdentityEnrollmentRequest(
            requestID: "device-ingress-fixture-\(UUID().uuidString)",
            purpose: "link_identity",
            entityBinding: EntityBindingDescriptor(
                mode: .pairwise,
                entityAnchorReference: nil,
                bindingID: bindingID,
                audience: trust.expectedAudience
            ),
            newIdentity: subjectDescriptor,
            requestedDomains: [DeviceIngressEnvelope.identityDomain],
            requestedIdentityContexts: ["ios", "device-ingress"],
            requestedScopes: ["device-ingress.register"],
            audience: trust.expectedAudience,
            origin: "https://\(trust.expectedAudience)",
            createdAt: IdentityLinkProtocolService.iso8601(now),
            expiresAt: IdentityLinkProtocolService.iso8601(
                now.addingTimeInterval(600)
            ),
            nonce: Data((0..<32).map(UInt8.init)),
            platform: "iOS",
            deviceLabel: "Binding fixture"
        )
        let payload = try request.canonicalPayloadData()
        request.proof = IdentityEnrollmentRequestProof(
            byIdentityUUID: subject.uuid,
            algorithm: subjectDescriptor.algorithm,
            curveType: subjectDescriptor.curveType,
            signature: try #require(try await subject.sign(data: payload))
        )
        let approval = try await IdentityLinkProtocolService.approveEnrollmentRequest(
            request,
            issuerIdentity: issuer,
            issuerType: .existingDevice,
            createdAt: now,
            expiresAt: now.addingTimeInterval(300),
            jti: "device-ingress-fixture-approval-\(UUID().uuidString)",
            freshAuthRequired: true,
            freshAuthPerformedAt: now
        )
        let credential = try await IdentityLinkProtocolService.issueSameEntityCredential(
            request: request,
            approval: approval,
            issuerIdentity: issuer,
            validUntil: now.addingTimeInterval(600),
            revocationReference: "cell:///EntityAnchor/device-ingress/fixture"
        )
        let presentation = try await IdentityLinkProtocolService.makeVerifierBoundPresentation(
            credential: credential,
            holderIdentity: subject,
            challenge: request.nonce,
            domain: DeviceIngressEnvelope.identityDomain
        )
        let envelope = IdentityLinkCompletionEnvelope(
            request: request,
            approval: approval,
            sameEntityCredential: credential,
            presentation: presentation,
            issuerIdentity: issuerDescriptor,
            expectedAudience: trust.expectedAudience,
            expectedOrigin: "https://\(trust.expectedAudience)",
            expectedPresentationChallenge: request.nonce,
            expectedPresentationDomain: DeviceIngressEnvelope.identityDomain
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try await DeviceIngressEntityLinkAuthorizationVerifier.verify(
            canonicalCompletionEnvelope: encoder.encode(envelope),
            subject: subjectDescriptor,
            trust: trust,
            now: now
        )
    }

    private func pairwiseBindingID(
        entity: IdentityPublicKeyDescriptor,
        audience: String
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var material = Data("haven.entity-pairwise.v1".utf8)
        material.append(0)
        material.append(try encoder.encode(entity))
        material.append(0)
        material.append(Data(audience.utf8))
        let digest = DeviceIngressCanonicalWire.base64URL(
            DeviceIngressCanonicalWire.sha256(material)
        )
        return "entity-pairwise:\(digest)"
    }

    private func makeExpectation(
        _ fixture: Fixture
    ) async throws -> DeviceIngressResponseExpectation {
        let binding = try #require(
            await fixture.subjectVault.identityDomainBinding(for: fixture.subject)
        )
        return try await DeviceIngressRequestFactory.prepare(
            canonicalChallengeData: fixture.challengeData,
            protectedBody: body,
            requester: fixture.subject,
            domainBinding: binding,
            expectedAudience: fixture.trust.expectedAudience,
            expectedChallengeIssuer: fixture.trust.expectedChallengeIssuer,
            now: now
        ).expectation
    }

    private func createPrivateDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        guard Darwin.chmod(url.path, 0o700) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test directory chmod",
                code: errno
            )
        }
    }

    #if os(macOS)
    private func writeTestFile(_ value: String, to url: URL) throws {
        try Data(value.utf8).write(to: url)
    }

    private func initializeGitRepository(at url: URL) throws {
        let commands = [
            ["init", "-q"],
            ["add", "-A"],
            [
                "-c", "user.name=Binding Fixture",
                "-c", "user.email=binding-fixture@example.invalid",
                "commit", "-q", "--allow-empty", "-m", "fixture"
            ]
        ]
        for command in commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", url.path] + command
            try process.run()
            process.waitUntilExit()
            try #require(process.terminationStatus == 0)
        }
    }
    #endif

    private func replaceFirstByte(
        in url: URL,
        matching expected: UInt8,
        with replacement: UInt8
    ) throws {
        let data = try Data(contentsOf: url)
        guard let offset = data.firstIndex(of: expected) else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        let descriptor = Darwin.open(url.path, O_RDWR | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test journal tamper open",
                code: errno
            )
        }
        defer { _ = Darwin.close(descriptor) }
        var byte = replacement
        guard Darwin.pwrite(descriptor, &byte, 1, off_t(offset)) == 1 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test journal tamper write",
                code: errno
            )
        }
    }

    private func overwriteFileInPlace(_ data: Data, at url: URL) throws {
        let descriptor = Darwin.open(url.path, O_WRONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test journal rewrite open",
                code: errno
            )
        }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.ftruncate(descriptor, 0) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test journal rewrite truncate",
                code: errno
            )
        }
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(
                    descriptor,
                    buffer.baseAddress!.advanced(by: offset),
                    buffer.count - offset
                )
                if count < 0, errno == EINTR { continue }
                guard count > 0 else {
                    throw DeviceIngressEvidenceFileError.posix(
                        operation: "test journal rewrite write",
                        code: errno
                    )
                }
                offset += count
            }
        }
    }

    private func persistedEvidenceText(in directory: URL) throws -> String {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return try urls.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
    }

    private func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded(.towardZero))
    }

    private func makeConsentEvidence(
        acceptanceID: String = "fixture-terms-acceptance"
    ) throws -> NotificationTermsConsentEvidence {
        try #require(NotificationTermsConsentEvidence(
            termsVersion: "v1",
            acceptedAt: now.timeIntervalSince1970,
            acceptanceID: acceptanceID
        ))
    }

    private func makeBuildProvenance(
        bindingRevisionHex: Character = "a"
    ) throws -> BindingBuildProvenance {
        try BindingBuildProvenance(
            bindingGitRevision: String(repeating: bindingRevisionHex, count: 40),
            cellProtocolGitRevision: String(repeating: "c", count: 40),
            bindingSourceTreeDirty: false,
            cellProtocolSourceTreeDirty: false,
            compilerInputManifestSHA256: String(repeating: "b", count: 64),
            compilerInputCount: 2,
            generatedCompilerInputCount: 1,
            filesystemSynchronizedSourceCount: 1,
            ignoredSourceLikeInputCount: 0,
            bindingCompilerArtifactSHA256: String(repeating: "d", count: 64),
            cellProtocolArtifactSHA256: String(repeating: "e", count: 64),
            linkInputManifestSHA256: String(repeating: "f", count: 64),
            compilerFlagsSHA256: String(repeating: "1", count: 64),
            toolchainSHA256: String(repeating: "2", count: 64),
            codeSigningMode: .certificate,
            codeSigningIdentityFingerprint: String(repeating: "3", count: 40),
            codeSigningTeamIdentifier: "TESTTEAM01",
            codeSigningEntitlementsSHA256: String(repeating: "4", count: 64),
            buildConfiguration: "Test",
            sdkName: "test-sdk",
            generatedAtUTC: "2026-07-21T00:00:00Z"
        )
    }
}

private enum TestDurabilityError: Error, Equatable {
    case file
    case directory
}

private enum DeclineRegistrationRaceOutcome: Sendable {
    case declineSucceeded
    case declineRejected
    case registrationSucceeded
    case registrationRejected
}

private final class CanonicalLockReplacer:
    DeviceIngressEvidenceReadObserving,
    @unchecked Sendable
{
    private let directoryURL: URL
    private let lock = NSLock()
    private var hasReplaced = false

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    var didReplace: Bool {
        lock.withLock { hasReplaced }
    }

    func didOpenForRead(fileName: String) throws {}

    func didAcquireCanonicalLock(fileName: String) throws {
        let shouldReplace = lock.withLock { () -> Bool in
            guard hasReplaced == false else { return false }
            hasReplaced = true
            return true
        }
        guard shouldReplace else { return }

        let canonicalURL = directoryURL.appendingPathComponent(fileName)
        let displacedURL = directoryURL.appendingPathComponent("displaced-lock")
        try FileManager.default.moveItem(at: canonicalURL, to: displacedURL)
        let descriptor = Darwin.open(
            canonicalURL.path,
            O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            0o600
        )
        guard descriptor >= 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test replacement lock open",
                code: errno
            )
        }
        _ = Darwin.close(descriptor)
    }
}

private final class ConcurrentEvidenceWriter:
    DeviceIngressEvidenceReadObserving,
    @unchecked Sendable
{
    private let fileURL: URL
    private let lock = NSLock()
    private var hasMutated = false
    private var isArmed = false

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    var didMutate: Bool {
        lock.withLock { hasMutated }
    }

    func arm() {
        lock.withLock { isArmed = true }
    }

    func didOpenForRead(fileName: String) throws {
        guard fileName == "registration-state-journal.json" else { return }
        let shouldMutate = lock.withLock { () -> Bool in
            guard isArmed, hasMutated == false else { return false }
            hasMutated = true
            return true
        }
        guard shouldMutate else { return }

        let descriptor = Darwin.open(fileURL.path, O_WRONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test concurrent writer open",
                code: errno
            )
        }
        defer { _ = Darwin.close(descriptor) }
        var replacement = UInt8(ascii: " ")
        guard Darwin.pwrite(descriptor, &replacement, 1, 0) == 1 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test concurrent writer pwrite",
                code: errno
            )
        }
    }
}

nonisolated private struct FailingDurabilitySynchronizer:
    DeviceIngressDurabilitySynchronizing
{
    let failure: TestDurabilityError
    private let system = DarwinDeviceIngressDurabilitySynchronizer()

    func synchronizeFile(_ descriptor: Int32) throws {
        if failure == .file { throw TestDurabilityError.file }
        try system.synchronizeFile(descriptor)
    }

    func synchronizeDirectory(_ descriptor: Int32) throws {
        if failure == .directory { throw TestDurabilityError.directory }
        try system.synchronizeDirectory(descriptor)
    }
}

private actor GatedRegistrationTransport: DeviceIngressRegistrationTransport {
    private let underlying: FixtureTransport
    private var submitStarted = false
    private var submitReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(underlying: FixtureTransport) {
        self.underlying = underlying
    }

    func fetchRegisterChallenge(
        subject: IdentityPublicKeyDescriptor,
        canonicalEntityLink: Data
    ) async throws -> Data {
        try await underlying.fetchRegisterChallenge(
            subject: subject,
            canonicalEntityLink: canonicalEntityLink
        )
    }

    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data {
        submitStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        if submitReleased == false {
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }
        return try await underlying.submitRegister(
            canonicalChallengeData: canonicalChallengeData,
            canonicalRequestData: canonicalRequestData,
            protectedBody: protectedBody
        )
    }

    func waitUntilSubmitStarted() async {
        if submitStarted { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseSubmit() {
        submitReleased = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters.removeAll()
    }
}

private actor CountingInertTransport: DeviceIngressRegistrationTransport {
    private var fetches = 0

    func fetchRegisterChallenge(
        subject: IdentityPublicKeyDescriptor,
        canonicalEntityLink: Data
    ) throws -> Data {
        _ = canonicalEntityLink
        fetches += 1
        throw DeviceIngressRegistrationClientError.operationalCompositionUnavailable
    }

    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) throws -> Data {
        throw DeviceIngressRegistrationClientError.operationalCompositionUnavailable
    }

    func fetchCount() -> Int { fetches }
}

private actor FixtureTransport: DeviceIngressRegistrationTransport {
    enum ResponseMode {
        case valid
        case nonCanonical
    }

    private let challengeData: Data
    private let evidenceStore: any DeviceIngressRegistrationEvidenceStoring
    private let targetOwner: Identity
    private let responseMode: ResponseMode
    private var expectationWasPresent = false
    private var submits = 0

    init(
        challengeData: Data,
        evidenceStore: any DeviceIngressRegistrationEvidenceStoring,
        targetOwner: Identity,
        responseMode: ResponseMode
    ) {
        self.challengeData = challengeData
        self.evidenceStore = evidenceStore
        self.targetOwner = targetOwner
        self.responseMode = responseMode
    }

    func fetchRegisterChallenge(
        subject: IdentityPublicKeyDescriptor,
        canonicalEntityLink: Data
    ) -> Data {
        _ = canonicalEntityLink
        return challengeData
    }

    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data {
        submits += 1
        let expectation = try #require(await evidenceStore.pendingExpectation())
        expectationWasPresent = true
        var response = try await Self.signedRegistrationResponse(
            expectation: expectation,
            targetOwner: targetOwner
        )
        if responseMode == .nonCanonical {
            response.append(0x20)
        }
        return response
    }

    func sawPersistedExpectationBeforeSubmit() -> Bool {
        expectationWasPresent
    }

    func submitCount() -> Int { submits }

    private static func signedRegistrationResponse(
        expectation: DeviceIngressResponseExpectation,
        targetOwner: Identity
    ) async throws -> Data {
        let committedAt = expectation.requestIssuedAtMilliseconds + 1
        let registrationReceipt = DeviceIngressRegistrationReceipt(
            registrationID: "fixture-registration-1",
            deviceIdentityUUID: expectation.subjectIdentityUUID,
            registrationGeneration: 1,
            durableSequence: 1,
            state: .activeConsented,
            registrationRecordSHA256: Data(repeating: 0xD4, count: 32),
            committedAtMilliseconds: committedAt
        )
        let result = DeviceIngressOperationResult.registration(registrationReceipt)
        let resultSHA256 = DeviceIngressCanonicalWire.sha256(try result.canonicalData())
        let mutationRecordSHA256 = Data(repeating: 0xE5, count: 32)
        let responseID = try DeviceIngressMutationReceipt.responseID(
            admissionID: expectation.admissionID,
            requestSHA256: expectation.requestSHA256,
            mutationRecordSHA256: mutationRecordSHA256,
            operationResultSHA256: resultSHA256
        )
        let mutationReceipt = DeviceIngressMutationReceipt(
            responseID: responseID,
            operation: .register,
            admissionID: expectation.admissionID,
            requestSHA256: expectation.requestSHA256,
            challengeSHA256: expectation.challengeSHA256,
            bodySHA256: expectation.bodySHA256,
            targetCellUUID: expectation.targetCellUUID,
            targetOwnerIdentityUUID: expectation.targetOwnerIdentityUUID,
            targetOwnerSigningKeyFingerprint: expectation.targetOwnerSigningKeyFingerprint,
            subjectIdentityUUID: expectation.subjectIdentityUUID,
            subjectSigningKeyFingerprint: expectation.subjectSigningKeyFingerprint,
            signedAgreementSHA256: expectation.signedAgreementSHA256,
            authorityGeneration: expectation.authorityGeneration,
            revocationLedgerID: expectation.revocationLedgerID,
            revocationGeneration: expectation.revocationGeneration,
            contentPolicySHA256: try expectation.contentPolicy.canonicalSHA256(),
            mutationRecordSHA256: mutationRecordSHA256,
            operationResultSHA256: resultSHA256,
            durableSequence: 1,
            committedAtMilliseconds: committedAt
        )
        let signer = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: targetOwner)
        )
        let unsignedFixture = OperationResponseFixture(
            responseID: responseID,
            operation: .register,
            admissionID: expectation.admissionID,
            requestSHA256: expectation.requestSHA256,
            challengeSHA256: expectation.challengeSHA256,
            bodySHA256: expectation.bodySHA256,
            mutationReceiptSHA256: DeviceIngressCanonicalWire.sha256(
                try mutationReceipt.canonicalData()
            ),
            operationResultSHA256: resultSHA256,
            targetCellUUID: expectation.targetCellUUID,
            targetOwnerIdentityUUID: expectation.targetOwnerIdentityUUID,
            targetOwnerSigningKeyFingerprint: expectation.targetOwnerSigningKeyFingerprint,
            subjectIdentityUUID: expectation.subjectIdentityUUID,
            subjectSigningKeyFingerprint: expectation.subjectSigningKeyFingerprint,
            signedAgreementSHA256: expectation.signedAgreementSHA256,
            authorityGeneration: expectation.authorityGeneration,
            revocationLedgerID: expectation.revocationLedgerID,
            revocationGeneration: expectation.revocationGeneration,
            contentPolicySHA256: try expectation.contentPolicy.canonicalSHA256(),
            mutationReceipt: mutationReceipt,
            result: result,
            issuedAtMilliseconds: committedAt,
            expiresAtMilliseconds: expectation.requestExpiresAtMilliseconds,
            signer: signer,
            proof: nil
        )
        var response = try JSONDecoder().decode(
            DeviceIngressOperationResponse.self,
            from: JSONEncoder().encode(unsignedFixture)
        )
        let signature = try #require(
            try await targetOwner.sign(data: response.canonicalPayloadData())
        )
        response.proof = DeviceIngressIdentityProof(
            signerIdentityUUID: targetOwner.uuid,
            signature: signature
        )
        return try response.canonicalWireData()
    }
}

private struct OperationResponseFixture: Codable {
    var schema = DeviceIngressOperationResponse.currentSchema
    let responseID: String
    let operation: DeviceIngressOperation
    let admissionID: String
    let requestSHA256: Data
    let challengeSHA256: Data
    let bodySHA256: Data
    let mutationReceiptSHA256: Data
    let operationResultSHA256: Data
    let targetCellUUID: String
    let targetOwnerIdentityUUID: String
    let targetOwnerSigningKeyFingerprint: String
    let subjectIdentityUUID: String
    let subjectSigningKeyFingerprint: String
    let signedAgreementSHA256: Data
    let authorityGeneration: UInt64
    let revocationLedgerID: String
    let revocationGeneration: UInt64
    let contentPolicySHA256: Data
    let mutationReceipt: DeviceIngressMutationReceipt
    let result: DeviceIngressOperationResult
    let issuedAtMilliseconds: Int64
    let expiresAtMilliseconds: Int64
    let signer: IdentityPublicKeyDescriptor
    var proof: DeviceIngressIdentityProof?
}

private final class DeviceIngressFixtureURLProtocol: URLProtocol, @unchecked Sendable {
    struct CapturedRequest: Sendable {
        let method: String
        let host: String
        let path: String
        let body: Data
    }

    typealias Handler = @Sendable (URLRequest) -> (status: Int, body: Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    nonisolated(unsafe) private static var requests: [CapturedRequest] = []

    static func install(_ newHandler: @escaping Handler) {
        lock.lock()
        handler = newHandler
        requests = []
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        handler = nil
        requests = []
        lock.unlock()
    }

    static func capturedRequests() -> [CapturedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body = Self.requestBody(request)
        Self.lock.lock()
        let currentHandler = Self.handler
        Self.requests.append(CapturedRequest(
            method: request.httpMethod ?? "",
            host: url.host ?? "",
            path: url.path,
            body: body
        ))
        Self.lock.unlock()

        guard let currentHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        let result = currentHandler(request)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: result.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func requestBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            body.append(buffer, count: count)
        }
        return body
    }
}
