import Foundation

#if os(iOS)
import UIKit
#endif

enum NotificationCallbackOperationError: LocalizedError, Equatable {
    case deviceIngressV3CompositionUnavailable

    var errorDescription: String? {
        "Device callback resolve/submit is fail-closed until the reviewed DeviceIngress v3 composition is operational."
    }
}

final class NotificationCallbackClient {
    static let shared = NotificationCallbackClient()

    private init() {}

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
        case .resolved:
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
        _ = (participantId, deviceId, ticketId)
        throw NotificationCallbackOperationError.deviceIngressV3CompositionUnavailable
    }

    @discardableResult
    func submitTicketResult(participantId: String, deviceId: String, ticketId: String, result: [String: JSONValue]) async throws -> [String: JSONValue] {
        _ = (participantId, deviceId, ticketId, result)
        throw NotificationCallbackOperationError.deviceIngressV3CompositionUnavailable
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
        _ = payload
        throw NotificationCallbackOperationError.deviceIngressV3CompositionUnavailable
    }

    private enum NotificationResolutionOutcome {
        case resolved
        case noTicket
        case failed
    }

    private func resolveOrStageAction(
        participantId: String,
        deviceId: String,
        userInfo: [AnyHashable: Any]
    ) async -> NotificationResolutionOutcome {
        guard let ticketId = Self.notificationTicketID(from: userInfo) else {
            return .noTicket
        }

        do {
            _ = try await resolveTicket(participantId: participantId, deviceId: deviceId, ticketId: ticketId)
            return .resolved
        } catch {
            print("Notification callback resolve failed: \(error)")
            return .failed
        }
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
