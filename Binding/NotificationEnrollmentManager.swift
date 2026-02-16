import Foundation
import Combine

#if os(iOS)
import UIKit
import UserNotifications
#endif

@MainActor
final class NotificationEnrollmentManager: ObservableObject {
    static let shared = NotificationEnrollmentManager()

    @Published private(set) var needsTermsAcceptance: Bool = true
    @Published private(set) var pushPermissionGranted: Bool = false
    @Published private(set) var lastRegistrationError: String?

    private let defaults = UserDefaults.standard

    private let deviceIDKey = "binding.notifications.deviceId"
    private let termsVersionKey = "binding.notifications.termsVersion"
    private let termsAcceptedAtKey = "binding.notifications.termsAcceptedAt"
    private let apnsTokenKey = "binding.notifications.apnsToken"
    private let participantIDKey = "binding.notifications.participantId"

    private var participantID: String?
    private var deviceID: String?

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

        let currentTermsVersion = termsVersion()
        needsTermsAcceptance = defaults.string(forKey: termsVersionKey) != currentTermsVersion || defaults.double(forKey: termsAcceptedAtKey) <= 0
    }

    func currentParticipantID() -> String? {
        participantID
    }

    func currentDeviceID() -> String? {
        deviceID
    }

    func acceptTermsAndEnableNotifications() async {
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
            }
        } catch {
            lastRegistrationError = "Permission request failed: \(error.localizedDescription)"
        }
        #endif

        await registerCurrentDeviceIfReady()
    }

    func declineTerms() {
        needsTermsAcceptance = false
    }

    func updateAPNSToken(_ token: String) async {
        defaults.set(token, forKey: apnsTokenKey)
        await registerCurrentDeviceIfReady()
    }

    func registerCurrentDeviceIfReady() async {
        guard !needsTermsAcceptance,
              let participantID,
              let deviceID,
              let token = defaults.string(forKey: apnsTokenKey),
              !token.isEmpty
        else {
            return
        }

        let payload: [String: JSONValue] = [
            "participantId": .string(participantID),
            "deviceId": .string(deviceID),
            "platform": .string("ios"),
            "pushToken": .string(token),
            "termsVersion": .string(termsVersion()),
            "termsAccepted": .bool(true),
            "callbackCapabilities": .array([.string("http"), .string("background")])
        ]

        do {
            _ = try await NotificationCallbackClient.shared.registerDevice(payload: payload)
            lastRegistrationError = nil
        } catch {
            lastRegistrationError = "Device registration failed: \(error.localizedDescription)"
        }
    }

    private func termsVersion() -> String {
        ProcessInfo.processInfo.environment["BINDING_NOTIFICATION_TERMS_VERSION"] ?? "v1"
    }

    #if os(iOS)
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
