import Foundation
import Combine
import CellBase

#if os(iOS)
import UIKit
import UserNotifications
#endif

enum NotificationRegistrationValidationError: LocalizedError {
    case invalidServerResponse

    var errorDescription: String? {
        "Staging returned an invalid notification device registration response."
    }
}

@MainActor
final class NotificationEnrollmentManager: ObservableObject {
    static let shared = NotificationEnrollmentManager()

    @Published private(set) var needsTermsAcceptance: Bool = true
    @Published private(set) var pushPermissionGranted: Bool = false
    @Published private(set) var lastRegistrationError: String?
    @Published private(set) var isDeviceRegistered: Bool = false

    private let defaults = UserDefaults.standard

    private let deviceIDKey = "binding.notifications.deviceId"
    private let termsVersionKey = "binding.notifications.termsVersion"
    private let termsAcceptedAtKey = "binding.notifications.termsAcceptedAt"
    private let legacyAPNSTokenKey = "binding.notifications.apnsToken"
    private let currentAPNSTokenKey = "binding.notifications.currentAPNSToken"
    private let registrationSucceededAtKey = "binding.notifications.registrationSucceededAt"
    private let participantIDKey = "binding.notifications.participantId"
    private var participantID: String?
    private var deviceID: String?
    private var pendingAPNSToken: String?
    private var lastTokenRefreshRequestedAt: Date?

    private init() {
        bootstrapIfNeeded()
    }

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

        let currentTermsVersion = termsVersion()
        needsTermsAcceptance = defaults.string(forKey: termsVersionKey) != currentTermsVersion || defaults.double(forKey: termsAcceptedAtKey) <= 0
        pendingAPNSToken = Self.preferredAPNSToken(
            pending: pendingAPNSToken,
            stored: defaults.string(forKey: currentAPNSTokenKey) ?? defaults.string(forKey: legacyAPNSTokenKey)
        )
        defaults.removeObject(forKey: legacyAPNSTokenKey)
        isDeviceRegistered = defaults.double(forKey: registrationSucceededAtKey) > 0

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

    func declineTerms() {
        needsTermsAcceptance = false
    }

    func updateAPNSToken(_ token: String) async {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else { return }
        pendingAPNSToken = normalizedToken
        defaults.set(normalizedToken, forKey: currentAPNSTokenKey)
        defaults.removeObject(forKey: legacyAPNSTokenKey)
        await registerCurrentDeviceIfReady()
    }

    func recordAPNSRegistrationFailure(_ error: Error) {
        pushPermissionGranted = false
        isDeviceRegistered = false
        lastRegistrationError = "APNS registration failed: \(error.localizedDescription)"
    }

    func registerCurrentDeviceIfReady() async {
        pendingAPNSToken = Self.preferredAPNSToken(
            pending: pendingAPNSToken,
            stored: defaults.string(forKey: currentAPNSTokenKey)
        )
        guard !needsTermsAcceptance,
              let participantID,
              let deviceID,
              let token = pendingAPNSToken,
              !token.isEmpty
        else {
            return
        }

        let payload = Self.registrationPayload(
            participantID: participantID,
            deviceID: deviceID,
            pushToken: token,
            platform: "ios",
            termsVersion: termsVersion(),
            conferenceID: conferenceID(),
            subscriptionTopics: subscriptionTopics(),
            mutedEventTypes: mutedEventTypes()
        )

        do {
            let response = try await NotificationCallbackClient.shared.registerDevice(payload: payload)
            try Self.validateRegistrationResponse(
                response,
                expectedParticipantID: participantID,
                expectedDeviceID: deviceID
            )
            pendingAPNSToken = nil
            defaults.set(token, forKey: currentAPNSTokenKey)
            defaults.set(Date().timeIntervalSince1970, forKey: registrationSucceededAtKey)
            isDeviceRegistered = true
            lastRegistrationError = nil
        } catch {
            lastRegistrationError = "Device registration failed: \(error.localizedDescription)"
            isDeviceRegistered = false
            print("HAVEN notification device registration failed: \(error)")
        }
    }

    nonisolated static func validateRegistrationResponse(
        _ response: [String: JSONValue],
        expectedParticipantID: String,
        expectedDeviceID: String
    ) throws {
        guard case let .string(participantID)? = response["participantId"],
              participantID == expectedParticipantID,
              case let .string(deviceID)? = response["deviceId"],
              deviceID == expectedDeviceID,
              case let .bool(isActive)? = response["isActive"],
              isActive,
              case let .string(pushTokenHash)? = response["pushTokenHash"],
              !pushTokenHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw NotificationRegistrationValidationError.invalidServerResponse
        }
    }

    private func termsVersion() -> String {
        ProcessInfo.processInfo.environment["BINDING_NOTIFICATION_TERMS_VERSION"] ?? "v1"
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
        termsVersion: String,
        conferenceID: String?,
        subscriptionTopics: [String],
        mutedEventTypes: [String]
    ) -> [String: JSONValue] {
        [
            "participantId": .string(participantID),
            "deviceId": .string(deviceID),
            "platform": .string(platform),
            "pushToken": .string(pushToken),
            "termsVersion": .string(termsVersion),
            "termsAccepted": .bool(true),
            "callbackCapabilities": .array(defaultCallbackCapabilities().map(JSONValue.string)),
            "conferenceId": conferenceID.map(JSONValue.string) ?? .null,
            "subscriptionTopics": .array(normalizeTopics(subscriptionTopics).map(JSONValue.string)),
            "mutedEventTypes": .array(normalizeTopics(mutedEventTypes).map(JSONValue.string))
        ]
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

    nonisolated static func preferredAPNSToken(pending: String?, stored: String?) -> String? {
        normalizedIdentifier(pending) ?? normalizedIdentifier(stored)
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
