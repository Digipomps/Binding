import Foundation
import Combine
import CellBase

#if os(iOS)
import UIKit
import UserNotifications
#endif

nonisolated struct NotificationTermsConsentEvidence: Equatable, Sendable {
    let termsVersion: String
    let acceptedAt: TimeInterval

    init?(termsVersion: String, acceptedAt: TimeInterval) {
        let normalizedVersion = termsVersion.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard normalizedVersion.isEmpty == false,
              acceptedAt.isFinite,
              acceptedAt > 0 else {
            return nil
        }
        self.termsVersion = normalizedVersion
        self.acceptedAt = acceptedAt
    }
}

nonisolated enum NotificationEnrollmentStateError: LocalizedError, Equatable {
    case declineRequiresSignedRevocation

    var errorDescription: String? {
        switch self {
        case .declineRequiresSignedRevocation:
            return "Notifications were previously registered or have an ambiguous pending registration. ‘Not now’ is pre-registration only; a signed revoke/deregister flow is required."
        }
    }
}

@MainActor
final class NotificationEnrollmentManager: ObservableObject {
    static let shared = NotificationEnrollmentManager()

    @Published private(set) var needsTermsAcceptance: Bool = true
    @Published private(set) var pushPermissionGranted: Bool = false
    @Published private(set) var lastRegistrationError: String?
    @Published private(set) var isDeviceRegistered: Bool = false

    private let defaults: UserDefaults
    private let evidenceInspectorFactory:
        @Sendable () throws -> any DeviceIngressRegistrationEvidenceStoring

    private let deviceIDKey = "binding.notifications.deviceId"
    private let termsVersionKey = "binding.notifications.termsVersion"
    private let termsAcceptedAtKey = "binding.notifications.termsAcceptedAt"
    // Migration-only keys. Values are deleted without being read so raw APNS
    // tokens and unsigned legacy success state cannot enter the v3 runtime.
    private let legacyAPNSTokenKey = "binding.notifications.apnsToken"
    private let currentAPNSTokenKey = "binding.notifications.currentAPNSToken"
    private let registrationSucceededAtKey = "binding.notifications.registrationSucceededAt"
    private let participantIDKey = "binding.notifications.participantId"
    private var participantID: String?
    private var deviceID: String?
    private var pendingAPNSToken: String?
    private var lastTokenRefreshRequestedAt: Date?

    private init(
        defaults: UserDefaults = .standard,
        evidenceInspectorFactory: @escaping @Sendable () throws
            -> any DeviceIngressRegistrationEvidenceStoring = {
                try FileDeviceIngressRegistrationEvidenceStore.applicationSupport()
            }
    ) {
        self.defaults = defaults
        self.evidenceInspectorFactory = evidenceInspectorFactory
        bootstrapIfNeeded()
    }

    #if DEBUG
    static func testing(
        defaults: UserDefaults,
        evidenceInspector: any DeviceIngressRegistrationEvidenceStoring
    ) -> NotificationEnrollmentManager {
        NotificationEnrollmentManager(
            defaults: defaults,
            evidenceInspectorFactory: { evidenceInspector }
        )
    }
    #endif

    func bootstrapIfNeeded() {
        if participantID == nil {
            let envParticipant = ProcessInfo.processInfo.environment["BINDING_PARTICIPANT_ID"]
            participantID = defaults.string(forKey: participantIDKey) ?? envParticipant ?? "binding-participant"
            defaults.set(participantID, forKey: participantIDKey)
        }

        if deviceID == nil {
            if let existing = defaults.string(forKey: deviceIDKey), !existing.isEmpty {
                deviceID = existing
            } else {
                #if os(iOS)
                let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
                #else
                let generated = UUID().uuidString
                #endif
                defaults.set(generated, forKey: deviceIDKey)
                deviceID = generated
            }
        }

        configureRemoteBridgePresenceProvider()

        needsTermsAcceptance = currentTermsConsentEvidence() == nil
        pendingAPNSToken = Self.normalizedAPNSToken(pendingAPNSToken)
        defaults.removeObject(forKey: legacyAPNSTokenKey)
        defaults.removeObject(forKey: currentAPNSTokenKey)
        defaults.removeObject(forKey: registrationSucceededAtKey)
        isDeviceRegistered = false

        Task { @MainActor in
            #if os(iOS)
            await refreshPushAuthorizationStatus()
            if !needsTermsAcceptance, pushPermissionGranted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            #else
            pushPermissionGranted = false
            #endif
            await registerCurrentDeviceIfReady()
        }
    }

    func currentParticipantID() -> String? {
        participantID
    }

    func currentDeviceID() -> String? {
        deviceID
    }

    func acceptTermsAndEnableNotifications() async {
        lastRegistrationError = nil
        do {
            // Re-open the durable local registration gate before consent can
            // be represented as accepted. This is synchronous and therefore
            // has no MainActor reentrancy window.
            try evidenceInspectorFactory().clearPreRegistrationDecline()
        } catch {
            needsTermsAcceptance = true
            isDeviceRegistered = false
            lastRegistrationError = "Cannot accept notification terms: \(error.localizedDescription)"
            return
        }
        let acceptedAt = Date().timeIntervalSince1970
        defaults.set(termsVersion(), forKey: termsVersionKey)
        defaults.set(acceptedAt, forKey: termsAcceptedAtKey)
        needsTermsAcceptance = false

        #if os(iOS)
        do {
            let granted = try await requestPushAuthorization()
            pushPermissionGranted = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                isDeviceRegistered = false
                lastRegistrationError = "Varslingstillatelse mangler. Slå på varsler for HAVEN i iOS Settings."
            }
        } catch {
            isDeviceRegistered = false
            lastRegistrationError = "Permission request failed: \(error.localizedDescription)"
        }
        #endif

        await registerCurrentDeviceIfReady()
    }

    func retryDeviceRegistration() async {
        lastRegistrationError = nil
        #if os(iOS)
        await refreshPushAuthorizationStatus()
        if pushPermissionGranted {
            UIApplication.shared.registerForRemoteNotifications()
        } else if !needsTermsAcceptance {
            lastRegistrationError = "Varslingstillatelse mangler. Slå på varsler for HAVEN i iOS Settings."
            isDeviceRegistered = false
            return
        }
        #endif
        await registerCurrentDeviceIfReady()
    }

    #if os(iOS)
    func refreshDeviceRegistrationOnActivation() async {
        if participantID == nil || deviceID == nil {
            bootstrapIfNeeded()
        }
        guard !needsTermsAcceptance else { return }

        await refreshPushAuthorizationStatus()
        guard pushPermissionGranted else {
            isDeviceRegistered = false
            return
        }

        let now = Date()
        guard Self.shouldRequestTokenRefresh(
            now: now,
            lastRequestedAt: lastTokenRefreshRequestedAt,
            minimumInterval: 30
        ) else {
            await registerCurrentDeviceIfReady()
            return
        }

        lastTokenRefreshRequestedAt = now
        UIApplication.shared.registerForRemoteNotifications()
        await registerCurrentDeviceIfReady()
    }
    #endif

    /// "Not now" is deliberately pre-registration-only. Once any verified or
    /// ambiguous pending evidence exists, removing local consent would falsely
    /// imply server revocation. Until a signed revoke operation exists, this
    /// API fails closed and preserves consent state.
    @discardableResult
    func declineTermsBeforeRegistration() async -> Bool {
        lastRegistrationError = nil
        do {
            let evidenceInspector = try evidenceInspectorFactory()
            // Evidence decision, durable gate and local state clear execute
            // synchronously while the same descriptor-relative cross-process
            // transaction remains held. There is no MainActor reentrancy
            // window in which persistPending can cross this decision.
            try evidenceInspector.performPreRegistrationDecline {
                defaults.removeObject(forKey: termsVersionKey)
                defaults.removeObject(forKey: termsAcceptedAtKey)
                pendingAPNSToken = nil
                needsTermsAcceptance = true
                isDeviceRegistered = false
            }
            return true
        } catch {
            isDeviceRegistered = false
            needsTermsAcceptance = currentTermsConsentEvidence() == nil
            lastRegistrationError = "Cannot decline notification terms: \(error.localizedDescription)"
            return false
        }
    }

    func updateAPNSToken(_ token: String) async {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else { return }
        pendingAPNSToken = normalizedToken
        defaults.removeObject(forKey: legacyAPNSTokenKey)
        defaults.removeObject(forKey: currentAPNSTokenKey)
        await registerCurrentDeviceIfReady()
    }

    func recordAPNSRegistrationFailure(_ error: Error) {
        pushPermissionGranted = false
        isDeviceRegistered = false
        lastRegistrationError = "APNS registration failed: \(error.localizedDescription)"
    }

    func registerCurrentDeviceIfReady() async {
        pendingAPNSToken = Self.normalizedAPNSToken(pendingAPNSToken)
        guard let consent = currentTermsConsentEvidence(),
              let participantID,
              let deviceID,
              let token = pendingAPNSToken,
              !token.isEmpty
        else {
            needsTermsAcceptance = currentTermsConsentEvidence() == nil
            isDeviceRegistered = false
            return
        }

        do {
            let buildProvenance = try BindingBuildProvenance.current()
            let payload = Self.registrationPayload(
                participantID: participantID,
                deviceID: deviceID,
                pushToken: token,
                platform: "ios",
                consent: consent,
                conferenceID: conferenceID(),
                subscriptionTopics: subscriptionTopics(),
                mutedEventTypes: mutedEventTypes(),
                buildProvenance: buildProvenance
            )
            let protectedBody = try Self.registrationProtectedBody(payload)
            let receipt = try await BindingDeviceIngressRegistrationComposition.register(
                protectedBody: protectedBody,
                buildProvenance: buildProvenance
            )
            guard receipt.state == .activeConsented else {
                throw DeviceIngressRegistrationClientError.registrationWasNotActiveAndConsented
            }
            // A register mutation receipt is durable historical evidence, not
            // current status. The register-only v3 candidate has no canonical
            // status/read-back operation, so it must not claim current
            // registration even immediately after this response.
            pendingAPNSToken = nil
            isDeviceRegistered = false
            lastRegistrationError = "Registration evidence was verified, but a fresh signed status read-back is required before this device can be shown as registered."
        } catch {
            lastRegistrationError = "Device registration failed: \(error.localizedDescription)"
            isDeviceRegistered = false
            print("HAVEN notification device registration failed: \(error)")
        }
    }

    private func termsVersion() -> String {
        ProcessInfo.processInfo.environment["BINDING_NOTIFICATION_TERMS_VERSION"] ?? "v1"
    }

    private func currentTermsConsentEvidence() -> NotificationTermsConsentEvidence? {
        guard defaults.string(forKey: termsVersionKey) == termsVersion() else {
            return nil
        }
        return NotificationTermsConsentEvidence(
            termsVersion: termsVersion(),
            acceptedAt: defaults.double(forKey: termsAcceptedAtKey)
        )
    }

    private func conferenceID() -> String? {
        normalize(ProcessInfo.processInfo.environment["BINDING_CONFERENCE_ID"])
    }

    private func subscriptionTopics() -> [String] {
        parseCSVEnvironment(
            "BINDING_NOTIFICATION_SUBSCRIPTION_TOPICS",
            defaultValue: WorkflowNotificationPreferences.defaultSubscriptionTopics
        )
    }

    private func mutedEventTypes() -> [String] {
        parseCSVEnvironment("BINDING_NOTIFICATION_MUTED_EVENT_TYPES", defaultValue: [])
    }

    private func parseCSVEnvironment(_ key: String, defaultValue: [String]) -> [String] {
        parseCSV(ProcessInfo.processInfo.environment[key], defaultValue: defaultValue)
    }

    private func parseCSV(_ value: String?, defaultValue: [String]) -> [String] {
        let values = Self.normalizeTopics(
            (value ?? "")
                .split(separator: ",")
                .compactMap { normalize(String($0)) }
        )
        return values.isEmpty ? Self.normalizeTopics(defaultValue) : values
    }

    private func normalize(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func configureRemoteBridgePresenceProvider() {
        let participantID = self.participantID
        let deviceID = self.deviceID
        let topics = WorkflowNotificationPreferences.activeBridgeTopics
        CellBase.remoteWebSocketQueryItemsProvider = { _ in
            Self.bridgePresenceQueryItems(
                participantID: participantID,
                deviceID: deviceID,
                topics: topics
            )
        }
    }

    nonisolated static func registrationPayload(
        participantID: String,
        deviceID: String,
        pushToken: String,
        platform: String,
        consent: NotificationTermsConsentEvidence,
        conferenceID: String?,
        subscriptionTopics: [String],
        mutedEventTypes: [String],
        buildProvenance: BindingBuildProvenance
    ) -> [String: JSONValue] {
        [
            "schema": .string("binding.device-registration.body.v3-candidate"),
            "participantId": .string(participantID),
            "deviceId": .string(deviceID),
            "platform": .string(platform),
            "pushToken": .string(pushToken),
            "termsVersion": .string(consent.termsVersion),
            "termsAccepted": .bool(true),
            "callbackCapabilities": .array(defaultCallbackCapabilities().map(JSONValue.string)),
            "conferenceId": conferenceID.map(JSONValue.string) ?? .null,
            "subscriptionTopics": .array(normalizeTopics(subscriptionTopics).map(JSONValue.string)),
            "mutedEventTypes": .array(normalizeTopics(mutedEventTypes).map(JSONValue.string)),
            "buildProvenance": .object(buildProvenance.registrationObject)
        ]
    }

    nonisolated static func registrationProtectedBody(
        _ payload: [String: JSONValue]
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }

    nonisolated static func bridgePresenceQueryItems(
        participantID: String?,
        deviceID: String?,
        topics: [String]
    ) -> [URLQueryItem] {
        guard let participantID = normalizedIdentifier(participantID),
              let deviceID = normalizedIdentifier(deviceID) else {
            return []
        }

        return [
            URLQueryItem(name: "participantId", value: participantID),
            URLQueryItem(name: "deviceId", value: deviceID)
        ] + normalizeTopics(topics).map { topic in
            URLQueryItem(name: "bridgeTopic", value: topic)
        }
    }

    nonisolated static func defaultCallbackCapabilities() -> [String] {
        normalizeTopics(["http", "background", "notification-response", "bridge"])
    }

    nonisolated static func normalizeTopics(_ topics: [String]) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        for topic in topics {
            let normalized = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.isEmpty == false else { continue }
            let dedupeKey = normalized.lowercased()
            guard seen.insert(dedupeKey).inserted else { continue }
            ordered.append(normalized)
        }
        return ordered
    }

    nonisolated static func shouldRequestTokenRefresh(
        now: Date,
        lastRequestedAt: Date?,
        minimumInterval: TimeInterval
    ) -> Bool {
        guard let lastRequestedAt else { return true }
        return now.timeIntervalSince(lastRequestedAt) >= minimumInterval
    }

    nonisolated static func normalizedAPNSToken(_ token: String?) -> String? {
        normalizedIdentifier(token)
    }

    private nonisolated static func normalizedIdentifier(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    #if os(iOS)
    private func refreshPushAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        pushPermissionGranted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    private func requestPushAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    #endif
}
