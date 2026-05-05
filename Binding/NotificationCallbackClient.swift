import Foundation

#if os(iOS)
import UIKit
#endif

final class NotificationCallbackClient {
    static let shared = NotificationCallbackClient()
    nonisolated static let defaultBaseURLString = "https://staging.haven.digipomps.org/conference-mvp/api/device"

    private init() {}

    private var baseURL: URL? {
        URL(string: Self.baseURLString())
    }

    nonisolated static func baseURLString(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        if let configured = environment["BINDING_NOTIFICATION_API_BASE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           configured.isEmpty == false {
            return configured
        }
        return defaultBaseURLString
    }

    #if os(iOS)
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard let participantId = NotificationEnrollmentManager.shared.currentParticipantID(),
              let deviceId = NotificationEnrollmentManager.shared.currentDeviceID() else {
            return .failed
        }

        let outcome = await resolveOrStageAction(
            participantId: participantId,
            deviceId: deviceId,
            userInfo: userInfo
        )
        switch outcome {
        case .resolved, .stagedFromPush:
            return .newData
        case .noTicket:
            return .noData
        case .failed:
            return .failed
        }
    }

    func handleNotificationResponse(userInfo: [AnyHashable: Any]) async {
        guard let participantId = NotificationEnrollmentManager.shared.currentParticipantID(),
              let deviceId = NotificationEnrollmentManager.shared.currentDeviceID() else {
            return
        }
        _ = await resolveOrStageAction(
            participantId: participantId,
            deviceId: deviceId,
            userInfo: userInfo
        )
    }
    #else
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {}
    func handleNotificationResponse(userInfo: [AnyHashable: Any]) async {}
    #endif

    @discardableResult
    func resolveTicket(participantId: String, deviceId: String, ticketId: String) async throws -> [String: JSONValue] {
        let payload: [String: JSONValue] = [
            "participantId": .string(participantId),
            "deviceId": .string(deviceId),
            "ticketId": .string(ticketId)
        ]
        let response = try await post(path: "callback/resolve", payload: payload)

        if case let .object(callback)? = response["contract"],
           case let .string(requiredActionKey)? = callback["requiredActionKey"] {
            let actionPayload: [String: JSONValue]
            if case let .object(payload)? = callback["payload"] {
                actionPayload = payload
            } else {
                actionPayload = [:]
            }

            let action = PendingDeviceAction(
                id: ticketId,
                participantId: participantId,
                deviceId: deviceId,
                ticketId: ticketId,
                requiredActionKey: requiredActionKey,
                payload: actionPayload,
                receivedAt: Date()
            )
            await MainActor.run {
                PendingActionInboxViewModel.shared.upsert(action)
            }
        }

        return response
    }

    @discardableResult
    func submitTicketResult(participantId: String, deviceId: String, ticketId: String, result: [String: JSONValue]) async throws -> [String: JSONValue] {
        let payload: [String: JSONValue] = [
            "participantId": .string(participantId),
            "deviceId": .string(deviceId),
            "ticketId": .string(ticketId),
            "result": .object(result)
        ]
        let response = try await post(path: "callback/submit", payload: payload)
        await MainActor.run {
            PendingActionInboxViewModel.shared.remove(ticketId: ticketId)
        }
        return response
    }

    @discardableResult
    func registerDevice(payload: [String: JSONValue]) async throws -> [String: JSONValue] {
        try await post(path: "register", payload: payload)
    }

    private func post(path: String, payload: [String: JSONValue]) async throws -> [String: JSONValue] {
        guard let baseURL else {
            throw URLError(.badURL)
        }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
        return decoded
    }

    private enum NotificationResolutionOutcome {
        case resolved
        case stagedFromPush
        case noTicket
        case failed
    }

    private func resolveOrStageAction(
        participantId: String,
        deviceId: String,
        userInfo: [AnyHashable: Any]
    ) async -> NotificationResolutionOutcome {
        guard let ticketId = stringValue(userInfo["ticketId"]) else {
            if let fallbackAction = pendingAction(from: userInfo, participantId: participantId, deviceId: deviceId) {
                await MainActor.run {
                    PendingActionInboxViewModel.shared.upsert(fallbackAction)
                }
                return .stagedFromPush
            }
            return .noTicket
        }

        do {
            _ = try await resolveTicket(participantId: participantId, deviceId: deviceId, ticketId: ticketId)
            return .resolved
        } catch {
            if let fallbackAction = pendingAction(from: userInfo, participantId: participantId, deviceId: deviceId, ticketIdOverride: ticketId) {
                await MainActor.run {
                    PendingActionInboxViewModel.shared.upsert(fallbackAction)
                }
                print("Notification callback resolve failed, staged local fallback action instead: \(error)")
                return .stagedFromPush
            }
            print("Notification callback resolve failed: \(error)")
            return .failed
        }
    }

    private func pendingAction(
        from userInfo: [AnyHashable: Any],
        participantId: String,
        deviceId: String,
        ticketIdOverride: String? = nil
    ) -> PendingDeviceAction? {
        guard let ticketId = ticketIdOverride ?? stringValue(userInfo["ticketId"]) else {
            return nil
        }

        let requiredActionKey = stringValue(userInfo["requiredActionKey"]) ?? "conference.inbox.review"
        var payload = objectValue(userInfo["payload"]) ?? [:]

        if let title = stringValue(userInfo["title"]) {
            payload["title"] = .string(title)
        }
        if let message = stringValue(userInfo["message"]) {
            payload["message"] = .string(message)
        }
        if let triggerEvent = stringValue(userInfo["triggerEvent"]) {
            payload["triggerEvent"] = .string(triggerEvent)
        }
        if let conferenceId = stringValue(userInfo["conferenceId"]) {
            payload["conferenceId"] = .string(conferenceId)
        }

        return PendingDeviceAction(
            id: ticketId,
            participantId: participantId,
            deviceId: deviceId,
            ticketId: ticketId,
            requiredActionKey: requiredActionKey,
            payload: payload,
            receivedAt: Date()
        )
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private func objectValue(_ value: Any?) -> [String: JSONValue]? {
        guard let dictionary = value as? [AnyHashable: Any] else {
            return nil
        }
        return dictionary.reduce(into: [:]) { partialResult, entry in
            guard let key = entry.key as? String,
                  let converted = jsonValue(entry.value) else {
                return
            }
            partialResult[key] = converted
        }
    }

    private func jsonValue(_ value: Any) -> JSONValue? {
        switch value {
        case let string as String:
            return .string(string)
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .number(Double(int))
        case let double as Double:
            return .number(double)
        case let float as Float:
            return .number(Double(float))
        case let dictionary as [AnyHashable: Any]:
            let converted = dictionary.reduce(into: [String: JSONValue]()) { partialResult, entry in
                guard let key = entry.key as? String,
                      let value = jsonValue(entry.value) else {
                    return
                }
                partialResult[key] = value
            }
            return .object(converted)
        case let array as [Any]:
            return .array(array.compactMap(jsonValue))
        default:
            return nil
        }
    }
}
