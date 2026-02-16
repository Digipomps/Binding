import Foundation

#if os(iOS)
import UIKit
#endif

final class NotificationCallbackClient {
    static let shared = NotificationCallbackClient()

    private init() {}

    private var baseURL: URL? {
        if let configured = ProcessInfo.processInfo.environment["BINDING_NOTIFICATION_API_BASE"],
           let url = URL(string: configured),
           !configured.isEmpty {
            return url
        }
        return URL(string: "http://localhost:9089/conference-mvp/api/device")
    }

    #if os(iOS)
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard let ticketId = userInfo["ticketId"] as? String, !ticketId.isEmpty else {
            return .noData
        }
        guard let participantId = NotificationEnrollmentManager.shared.currentParticipantID(),
              let deviceId = NotificationEnrollmentManager.shared.currentDeviceID() else {
            return .failed
        }

        do {
            _ = try await resolveTicket(participantId: participantId, deviceId: deviceId, ticketId: ticketId)
            return .newData
        } catch {
            print("Notification callback resolve failed: \(error)")
            return .failed
        }
    }
    #else
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {}
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
}
