import Testing
import Foundation
@_spi(HAVENRuntime) import CellBase
@testable import Binding

@MainActor
@Suite(.serialized)
struct NotificationEnrollmentManagerTests {

    @Test func registrationPayloadCarriesWorkflowSubscriptions() throws {
        let consent = try #require(NotificationTermsConsentEvidence(
            termsVersion: "v1",
            acceptedAt: 1_784_454_400
        ))
        let provenance = try makeBuildProvenance()
        let payload = NotificationEnrollmentManager.registrationPayload(
            participantID: "participant-1",
            deviceID: "device-1",
            pushToken: "apns-token",
            platform: "ios",
            consent: consent,
            conferenceID: "conf-1",
            subscriptionTopics: WorkflowNotificationPreferences.defaultSubscriptionTopics,
            mutedEventTypes: [],
            buildProvenance: provenance
        )

        #expect(stringValue(payload["conferenceId"]) == "conf-1")
        #expect(stringArray(payload["subscriptionTopics"]) == WorkflowNotificationPreferences.defaultSubscriptionTopics)
        #expect(stringArray(payload["callbackCapabilities"]) == ["http", "background", "notification-response", "bridge"])
        #expect(payload["termsAccepted"] == nil)
        #expect(payload["termsConsentState"] == .string("accepted"))
        #expect(payload["termsAcceptanceEvidence"] == .object(consent.registrationObject))
    }

    @Test func termsAcceptanceDoesNotPersistBeforeAuthenticatedRuntime() async throws {
        let suiteName = "NotificationEnrollmentManagerTests.auth.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let evidence = EnrollmentEvidenceStore(containsEvidence: false)
        let manager = NotificationEnrollmentManager.testing(
            defaults: defaults,
            evidenceInspector: evidence,
            authenticatedRuntimePreparer: {
                throw DeviceIngressRegistrationClientError
                    .authenticatedIdentityVaultUnavailable
            }
        )

        await manager.acceptTermsAndEnableNotifications()

        #expect(try evidence.termsConsentSnapshot().state == .unknown)
        #expect(manager.needsTermsAcceptance)
        #expect(manager.lastRegistrationError?.contains("Authentication is required") == true)
    }

    @Test func bridgePresenceQueryItemsCarryDeviceIdentityAndTopics() {
        let items = NotificationEnrollmentManager.bridgePresenceQueryItems(
            participantID: "participant-1",
            deviceID: "device-1",
            topics: WorkflowNotificationPreferences.activeBridgeTopics
        )

        #expect(items.first(where: { $0.name == "participantId" })?.value == "participant-1")
        #expect(items.first(where: { $0.name == "deviceId" })?.value == "device-1")
        #expect(items.filter { $0.name == "bridgeTopic" }.compactMap(\.value) == WorkflowNotificationPreferences.activeBridgeTopics)
        #expect(WorkflowNotificationPreferences.activeBridgeTopics.contains(WorkflowNotificationPreferences.contactRequestReceivedTopic))
    }

    @Test func normalizeTopicsDeduplicatesAndTrimsValues() {
        let normalized = NotificationEnrollmentManager.normalizeTopics([
            " workflow.run ",
            "workflow.review",
            "WORKFLOW.RUN",
            "",
            "conference.broadcast"
        ])

        #expect(normalized == ["workflow.run", "workflow.review", "conference.broadcast"])
    }

    @Test func tokenRefreshThrottleAllowsFirstAndStaleRequestsOnly() {
        let now = Date(timeIntervalSince1970: 1_000)

        #expect(NotificationEnrollmentManager.shouldRequestTokenRefresh(
            now: now,
            lastRequestedAt: nil,
            minimumInterval: 30
        ))
        #expect(!NotificationEnrollmentManager.shouldRequestTokenRefresh(
            now: now,
            lastRequestedAt: now.addingTimeInterval(-10),
            minimumInterval: 30
        ))
        #expect(NotificationEnrollmentManager.shouldRequestTokenRefresh(
            now: now,
            lastRequestedAt: now.addingTimeInterval(-31),
            minimumInterval: 30
        ))
    }

    @Test func APNSTokenNormalizationHasNoStoredFallback() {
        #expect(NotificationEnrollmentManager.normalizedAPNSToken(" pending-token ") == "pending-token")
        #expect(NotificationEnrollmentManager.normalizedAPNSToken(" ") == nil)
        #expect(NotificationEnrollmentManager.normalizedAPNSToken(nil) == nil)
    }

    @Test func declinedTermsRemainClosedAndCannotReachRegistrationComposition() async throws {
        let suiteName = "Binding.NotificationEnrollmentManagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("v1", forKey: "binding.notifications.termsVersion")
        defaults.set(1_784_454_400.0, forKey: "binding.notifications.termsAcceptedAt")

        let evidence = EnrollmentEvidenceStore(containsEvidence: false)
        try evidence.persistTermsAcceptance(try #require(
            NotificationTermsConsentEvidence(
                termsVersion: "v1",
                acceptedAt: 1_784_454_400,
                acceptanceID: "decline-fixture"
            )
        ))
        let manager = NotificationEnrollmentManager.testing(
            defaults: defaults,
            evidenceInspector: evidence
        )
        #expect(manager.needsTermsAcceptance == false)

        #expect(await manager.declineTermsBeforeRegistration())
        await manager.updateAPNSToken("test-apns-token")

        #expect(manager.needsTermsAcceptance)
        #expect(manager.termsConsentState == .declined)
        #expect(manager.isDeviceRegistered == false)
        #expect(manager.lastRegistrationError == nil)
        #expect(defaults.object(forKey: "binding.notifications.termsVersion") == nil)
        #expect(defaults.object(forKey: "binding.notifications.termsAcceptedAt") == nil)
    }

    @Test func declineFailsClosedWhenRegistrationEvidenceExists() async throws {
        let suiteName = "Binding.NotificationEnrollmentManagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("v1", forKey: "binding.notifications.termsVersion")
        defaults.set(1_784_454_400.0, forKey: "binding.notifications.termsAcceptedAt")
        let evidence = EnrollmentEvidenceStore(containsEvidence: true)
        try evidence.persistTermsAcceptance(try #require(
            NotificationTermsConsentEvidence(
                termsVersion: "v1",
                acceptedAt: 1_784_454_400,
                acceptanceID: "registered-fixture"
            )
        ))
        let manager = NotificationEnrollmentManager.testing(
            defaults: defaults,
            evidenceInspector: evidence
        )

        #expect(await manager.declineTermsBeforeRegistration() == false)

        #expect(manager.needsTermsAcceptance == false)
        #expect(manager.isDeviceRegistered == false)
        #expect(manager.lastRegistrationError?.contains("signed revoke/deregister") == true)
        #expect(defaults.object(forKey: "binding.notifications.termsVersion") == nil)
        #expect(defaults.object(forKey: "binding.notifications.termsAcceptedAt") == nil)
    }

    @Test func invalidConsentCannotConstructConsentEvidence() {
        #expect(NotificationTermsConsentEvidence(termsVersion: "v1", acceptedAt: 0) == nil)
        #expect(NotificationTermsConsentEvidence(termsVersion: " ", acceptedAt: 1) == nil)
    }

    @Test func legacyImplicitAcceptanceIsDeletedAndMigratesToUnknown() throws {
        let suiteName = "Binding.NotificationEnrollmentManagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("v1", forKey: "binding.notifications.termsVersion")
        defaults.set(1_784_454_400.0, forKey: "binding.notifications.termsAcceptedAt")

        let manager = NotificationEnrollmentManager.testing(
            defaults: defaults,
            evidenceInspector: EnrollmentEvidenceStore(containsEvidence: false)
        )

        #expect(manager.termsConsentState == .unknown)
        #expect(manager.needsTermsAcceptance)
        #expect(defaults.object(forKey: "binding.notifications.termsVersion") == nil)
        #expect(defaults.object(forKey: "binding.notifications.termsAcceptedAt") == nil)
    }

    @Test func termsVersionRolloverRequiresFreshAcceptanceBeforeRegistration() async throws {
        let suiteName = "Binding.NotificationEnrollmentManagerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let evidence = EnrollmentEvidenceStore(containsEvidence: false)
        try evidence.persistTermsAcceptance(try #require(
            NotificationTermsConsentEvidence(
                termsVersion: "v1",
                acceptedAt: 1_784_454_400,
                acceptanceID: "superseded-v1-acceptance"
            )
        ))

        let manager = NotificationEnrollmentManager.testing(
            defaults: defaults,
            evidenceInspector: evidence,
            requiredTermsVersion: "v2"
        )
        await manager.updateAPNSToken("test-apns-token")

        #expect(manager.termsConsentState == .unknown)
        #expect(manager.needsTermsAcceptance)
        #expect(manager.isDeviceRegistered == false)
        #expect(manager.lastRegistrationError == nil)
    }

    @Test func protectedRegistrationBodyEmbedsGeneratedBuildProvenance() throws {
        let consent = try #require(NotificationTermsConsentEvidence(
            termsVersion: "v1",
            acceptedAt: 1_784_454_400
        ))
        let provenance = try makeBuildProvenance()
        let payload = NotificationEnrollmentManager.registrationPayload(
            participantID: "participant-1",
            deviceID: "device-1",
            pushToken: "test-apns-token",
            platform: "ios",
            consent: consent,
            conferenceID: nil,
            subscriptionTopics: [],
            mutedEventTypes: [],
            buildProvenance: provenance
        )
        let body = try NotificationEnrollmentManager.registrationProtectedBody(payload)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: body)

        #expect(decoded["schema"] == .string("binding.device-registration.body.v3-candidate"))
        #expect(decoded["buildProvenance"] == .object(provenance.registrationObject))
    }

    @Test func currentBuildLoadsCleanOrDirtyScopedCompilerInputAttestation() throws {
        let provenance = try BindingBuildProvenance.current(
            requireCertificateSignature: false
        )
        let manifestURL = try #require(Bundle.main.url(
            forResource: BindingBuildProvenance.compilerInputManifestResourceName,
            withExtension: "txt"
        ))
        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)

        #expect([40, 64].contains(provenance.bindingGitRevision.count))
        #expect([40, 64].contains(provenance.cellProtocolGitRevision.count))
        #expect(manifest.contains(
            "source-control\\tbinding-dirty\\t\(provenance.bindingSourceTreeDirty)"
        ))
        #expect(manifest.contains(
            "source-control\\tcellprotocol-dirty\\t\(provenance.cellProtocolSourceTreeDirty)"
        ))
        #expect(provenance.compilerInputManifestSHA256.count == 64)
        #expect(provenance.compilerInputCount > 0)
        #expect(provenance.filesystemSynchronizedSourceCount > 0)
        #expect(provenance.bindingCompilerArtifactSHA256.count == 64)
        #expect(provenance.cellProtocolArtifactSHA256.count == 64)
        #expect(provenance.compilerFlagsSHA256.count == 64)
        #expect(provenance.toolchainSHA256.count == 64)
        #expect(
            provenance.codeSigningMode == .certificate
                || provenance.codeSigningMode == .unsigned
        )
        #expect(provenance.generatedAtUTC.isEmpty == false)
    }

    @Test func notificationCallbackHTTPErrorSurfacesStatusAndBody() {
        let data = #"{"reason":"Invalid device callback ingress capability.","error":true}"#
            .data(using: .utf8)!
        let body = NotificationCallbackClient.responseBodySnippet(from: data)
        let error = NotificationCallbackHTTPError(statusCode: 401, responseBody: body)

        #expect(error.localizedDescription.contains("HTTP 401"))
        #expect(error.localizedDescription.contains("Invalid device callback ingress capability"))
    }

    @Test func iOSPlatformSigningAcceptsCanonicalPhysicalDeviceBuild() throws {
        let provenance = try makeBuildProvenance(
            teamIdentifier: BindingBuildProvenance.canonicalIOSTeamIdentifier,
            sdkName: "iphoneos26.2"
        )

        try BindingBuildProvenance.validateIOSPlatformSigning(
            provenance,
            bundleIdentifier: BindingBuildProvenance.canonicalIOSBundleIdentifier
        )
    }

    @Test func iOSPlatformSigningRejectsWrongBundleOrTeam() throws {
        let canonical = try makeBuildProvenance(
            teamIdentifier: BindingBuildProvenance.canonicalIOSTeamIdentifier,
            sdkName: "iphoneos26.2"
        )
        let wrongTeam = try makeBuildProvenance(
            teamIdentifier: "WRONGTEAM1",
            sdkName: "iphoneos26.2"
        )

        #expect(throws: BindingBuildProvenanceError.codeSigningAuthorityMismatch) {
            try BindingBuildProvenance.validateIOSPlatformSigning(
                canonical,
                bundleIdentifier: "org.example.resigned"
            )
        }
        #expect(throws: BindingBuildProvenanceError.codeSigningAuthorityMismatch) {
            try BindingBuildProvenance.validateIOSPlatformSigning(
                wrongTeam,
                bundleIdentifier: BindingBuildProvenance.canonicalIOSBundleIdentifier
            )
        }
    }

    @Test func iOSPlatformSigningRejectsSimulatorAndMissingBundleIdentity() throws {
        let simulator = try makeBuildProvenance(
            teamIdentifier: BindingBuildProvenance.canonicalIOSTeamIdentifier,
            sdkName: "iphonesimulator26.2"
        )

        #expect(throws: BindingBuildProvenanceError.codeSigningAuthorityMismatch) {
            try BindingBuildProvenance.validateIOSPlatformSigning(
                simulator,
                bundleIdentifier: BindingBuildProvenance.canonicalIOSBundleIdentifier
            )
        }
        #expect(throws: BindingBuildProvenanceError.codeSigningAuthorityUnavailable) {
            try BindingBuildProvenance.validateIOSPlatformSigning(
                simulator,
                bundleIdentifier: nil
            )
        }
    }

    private func stringArray(_ value: JSONValue?) -> [String] {
        guard case let .array(items)? = value else { return [] }
        return items.compactMap { item in
            guard case let .string(value) = item else { return nil }
            return value
        }
    }

    private func stringValue(_ value: JSONValue?) -> String? {
        guard case let .string(value)? = value else { return nil }
        return value
    }

    private func makeBuildProvenance(
        teamIdentifier: String = "TESTTEAM01",
        sdkName: String = "test-sdk"
    ) throws -> BindingBuildProvenance {
        try BindingBuildProvenance(
            bindingGitRevision: String(repeating: "a", count: 40),
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
            codeSigningTeamIdentifier: teamIdentifier,
            codeSigningEntitlementsSHA256: String(repeating: "4", count: 64),
            buildConfiguration: "Test",
            sdkName: sdkName,
            generatedAtUTC: "2026-07-21T00:00:00Z"
        )
    }
}

private final class EnrollmentEvidenceStore:
    DeviceIngressRegistrationEvidenceStoring,
    @unchecked Sendable
{
    private let containsEvidenceValue: Bool
    private let lock = NSLock()
    private var consentSnapshot = NotificationTermsConsentSnapshot(
        state: .unknown,
        acceptedEvidence: nil
    )

    init(containsEvidence: Bool) {
        containsEvidenceValue = containsEvidence
    }

    func termsConsentSnapshot() throws -> NotificationTermsConsentSnapshot {
        lock.withLock { consentSnapshot }
    }

    func persistTermsAcceptance(_ evidence: NotificationTermsConsentEvidence) throws {
        lock.withLock {
            consentSnapshot = NotificationTermsConsentSnapshot(
                state: .accepted,
                acceptedEvidence: evidence
            )
        }
    }

    func persistPending(
        _ expectation: DeviceIngressResponseExpectation,
        consentEvidence: NotificationTermsConsentEvidence
    ) throws {}

    func pendingExpectation() throws -> DeviceIngressResponseExpectation? { nil }

    func commitVerified(
        expectation: DeviceIngressResponseExpectation,
        canonicalResponseData: Data,
        buildProvenance: BindingBuildProvenance,
        vaultBinding: DeviceIngressPersistedVaultBinding
    ) throws {}

    func verifiedEvidence() throws -> DeviceIngressVerifiedRegistrationEvidence? { nil }

    func containsRegistrationEvidence() throws -> Bool { containsEvidenceValue }

    func performPreRegistrationDecline(_ localStateClear: () -> Void) throws {
        guard containsEvidenceValue == false else {
            throw DeviceIngressRegistrationClientError
                .registrationEvidencePreventsPreRegistrationDecline
        }
        lock.withLock {
            consentSnapshot = NotificationTermsConsentSnapshot(
                state: .declined,
                acceptedEvidence: nil
            )
        }
        localStateClear()
    }
}
