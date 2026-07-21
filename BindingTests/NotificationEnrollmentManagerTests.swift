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
        #expect(payload["termsAccepted"] == .bool(true))
        #expect(payload["termsVersion"] == .string(consent.termsVersion))
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
        let manager = NotificationEnrollmentManager.testing(
            defaults: defaults,
            evidenceInspector: evidence
        )
        #expect(manager.needsTermsAcceptance == false)

        #expect(await manager.declineTermsBeforeRegistration())
        await manager.updateAPNSToken("test-apns-token")

        #expect(manager.needsTermsAcceptance)
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
        let manager = NotificationEnrollmentManager.testing(
            defaults: defaults,
            evidenceInspector: EnrollmentEvidenceStore(containsEvidence: true)
        )

        #expect(await manager.declineTermsBeforeRegistration() == false)

        #expect(manager.needsTermsAcceptance == false)
        #expect(manager.isDeviceRegistered == false)
        #expect(manager.lastRegistrationError?.contains("signed revoke/deregister") == true)
        #expect(defaults.string(forKey: "binding.notifications.termsVersion") == "v1")
        #expect(defaults.double(forKey: "binding.notifications.termsAcceptedAt") > 0)
    }

    @Test func invalidConsentCannotConstructConsentEvidence() {
        #expect(NotificationTermsConsentEvidence(termsVersion: "v1", acceptedAt: 0) == nil)
        #expect(NotificationTermsConsentEvidence(termsVersion: " ", acceptedAt: 1) == nil)
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

    @Test func currentBuildLoadsScopedCompilerInputAttestation() throws {
        let provenance = try BindingBuildProvenance.current(
            requireCertificateSignature: false
        )

        #expect([40, 64].contains(provenance.bindingGitRevision.count))
        #expect([40, 64].contains(provenance.cellProtocolGitRevision.count))
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

    private func makeBuildProvenance() throws -> BindingBuildProvenance {
        try BindingBuildProvenance(
            bindingGitRevision: String(repeating: "a", count: 40),
            cellProtocolGitRevision: String(repeating: "c", count: 40),
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

private final class EnrollmentEvidenceStore:
    DeviceIngressRegistrationEvidenceStoring,
    @unchecked Sendable
{
    private let containsEvidenceValue: Bool

    init(containsEvidence: Bool) {
        containsEvidenceValue = containsEvidence
    }

    func persistPending(_ expectation: DeviceIngressResponseExpectation) throws {}

    func pendingExpectation() throws -> DeviceIngressResponseExpectation? { nil }

    func commitVerified(
        expectation: DeviceIngressResponseExpectation,
        canonicalResponseData: Data,
        buildProvenance: BindingBuildProvenance
    ) throws {}

    func verifiedEvidence() throws -> DeviceIngressVerifiedRegistrationEvidence? { nil }

    func containsRegistrationEvidence() throws -> Bool { containsEvidenceValue }

    func performPreRegistrationDecline(_ localStateClear: () -> Void) throws {
        guard containsEvidenceValue == false else {
            throw DeviceIngressRegistrationClientError
                .registrationEvidencePreventsPreRegistrationDecline
        }
        localStateClear()
    }

    func clearPreRegistrationDecline() throws {}
}
