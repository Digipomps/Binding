import Foundation

#if os(iOS)
import UIKit
#endif

final class NotificationCallbackClient {
    static let shared = NotificationCallbackClient()
    nonisolated static let defaultBaseURLString = "https://staging.haven.digipomps.org/conference-mvp/api/device"
    nonisolated static let ingressTokenEnvironmentKey = "BINDING_DEVICE_CALLBACK_INGRESS_TOKEN"

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

    nonisolated static func ingressToken(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        guard let token = environment[ingressTokenEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              token.utf8.count >= 32 else {
            return nil
        }
        return token
    }

    nonisolated static func configureIngressAuthorization(
        on request: inout URLRequest,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        guard let token = ingressToken(environment: environment) else {
            throw NotificationCallbackClientError.ingressCapabilityUnavailable
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        let payload = Self.callbackSubmitPayload(
            participantId: participantId,
            deviceId: deviceId,
            ticketId: ticketId,
            result: result
        )
        let response = try await post(path: "callback/submit", payload: payload)
        await MainActor.run {
            PendingActionInboxViewModel.shared.remove(ticketId: ticketId)
        }
        return response
    }

    nonisolated static func callbackSubmitPayload(
        participantId: String,
        deviceId: String,
        ticketId: String,
        result: [String: JSONValue]
    ) -> [String: JSONValue] {
        var payload: [String: JSONValue] = [
            "participantId": .string(participantId),
            "deviceId": .string(deviceId),
            "ticketId": .string(ticketId),
            "result": .object(result)
        ]
        for key in ["sourceCellEndpoint", "endpointId", "sourceTicketId", "contactTicketId", "notificationTicketId"] {
            if let value = stringValue(result[key]) {
                payload[key] = .string(value)
            }
        }
        return payload
    }

    nonisolated static func ticketPromptResult(
        action: PendingDeviceAction,
        prompt: String
    ) -> [String: JSONValue] {
        var result: [String: JSONValue] = [
            "requiredActionKey": .string(action.requiredActionKey),
            "responseKind": .string("prompt"),
            "prompt": .string(prompt)
        ]
        mergeSourceRoutingHints(from: action, into: &result)
        return result
    }

    nonisolated static func ticketDecisionResult(
        action: PendingDeviceAction,
        decision: AgentConversationDecision,
        note: String? = nil
    ) -> [String: JSONValue] {
        var result: [String: JSONValue] = [
            "requiredActionKey": .string(action.requiredActionKey),
            "responseKind": .string("decision"),
            "decision": .string(decision.rawValue),
            "prompt": .string(decision.defaultPrompt)
        ]
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines),
           note.isEmpty == false {
            result["note"] = .string(note)
        }
        mergeSourceRoutingHints(from: action, into: &result)
        return result
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
        try Self.configureIngressAuthorization(on: &request)
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
        guard let ticketId = Self.notificationTicketID(from: userInfo) else {
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
        var payload = Self.notificationPayloadObject(from: userInfo) ?? [:]
        guard let ticketId = ticketIdOverride ?? Self.notificationTicketID(from: userInfo) else {
            return nil
        }

        let requiredActionKey = Self.stringValue(fromAny: userInfo["requiredActionKey"])
            ?? Self.stringValue(payload["requiredActionKey"])
            ?? "conference.inbox.review"

        if let title = Self.stringValue(fromAny: userInfo["title"]) {
            payload["title"] = .string(title)
        }
        if let message = Self.stringValue(fromAny: userInfo["message"]) {
            payload["message"] = .string(message)
        }
        if let triggerEvent = Self.stringValue(fromAny: userInfo["triggerEvent"]) {
            payload["triggerEvent"] = .string(triggerEvent)
        }
        if let conferenceId = Self.stringValue(fromAny: userInfo["conferenceId"]) {
            payload["conferenceId"] = .string(conferenceId)
        }
        for key in ["sourceCellEndpoint", "endpointId", "sourceTicketId", "notificationTicketId"] {
            if payload[key] == nil, let value = Self.stringValue(fromAny: userInfo[key]) {
                payload[key] = .string(value)
            }
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

    nonisolated static func notificationTicketID(from userInfo: [AnyHashable: Any]) -> String? {
        if let ticketId = stringValue(fromAny: userInfo["ticketId"]) {
            return ticketId
        }
        return stringValue(notificationPayloadObject(from: userInfo)?["ticketId"])
    }

    nonisolated static func notificationPayloadObject(from userInfo: [AnyHashable: Any]) -> [String: JSONValue]? {
        objectValue(fromAny: userInfo["payload"])
            ?? objectValue(fromAny: userInfo["payloadJSON"])
    }

    private func stringValue(_ value: Any?) -> String? {
        Self.stringValue(fromAny: value)
    }

    private func objectValue(_ value: Any?) -> [String: JSONValue]? {
        Self.objectValue(fromAny: value)
    }

    private func jsonValue(_ value: Any) -> JSONValue? {
        Self.jsonValue(fromAny: value)
    }

    nonisolated private static func mergeSourceRoutingHints(
        from action: PendingDeviceAction,
        into result: inout [String: JSONValue]
    ) {
        for key in [
            "sourceCellEndpoint",
            "endpointId",
            "sourceTicketId",
            "contactTicketId",
            "requestTopic",
            "notificationTicketId",
            "conversationId",
            "requestId",
            "jobId",
            "title",
            "message",
            "purpose",
            "purposeDescription"
        ] {
            if let value = stringValue(action.payload[key]) {
                result[key] = .string(value)
            }
        }
        if result["interests"] == nil,
           case let .array(interests)? = action.payload["interests"] {
            result["interests"] = .array(interests)
        }
        if result["sourceTicketId"] == nil,
           let contactTicketId = stringValue(action.payload["contactTicketId"]) {
            result["sourceTicketId"] = .string(contactTicketId)
        }
    }

    nonisolated private static func stringValue(_ value: JSONValue?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static func stringValue(fromAny value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    nonisolated private static func objectValue(fromAny value: Any?) -> [String: JSONValue]? {
        if let dictionary = value as? [AnyHashable: Any] {
            return dictionary.reduce(into: [:]) { partialResult, entry in
                guard let key = entry.key as? String,
                      let converted = jsonValue(fromAny: entry.value) else {
                    return
                }
                partialResult[key] = converted
            }
        }

        if let string = stringValue(fromAny: value),
           let data = string.data(using: .utf8),
           let object = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            return object
        }

        return nil
    }

    nonisolated private static func jsonValue(fromAny value: Any) -> JSONValue? {
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
                      let value = jsonValue(fromAny: entry.value) else {
                    return
                }
                partialResult[key] = value
            }
            return .object(converted)
        case let array as [Any]:
            return .array(array.compactMap(jsonValue(fromAny:)))
        default:
            return nil
        }
    }
}

enum NotificationCallbackClientError: LocalizedError {
    case ingressCapabilityUnavailable

    var errorDescription: String? {
        "HAVEN device callback ingress capability is unavailable on this device."
    }
}
