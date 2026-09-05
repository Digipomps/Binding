import Foundation
import CellBase

#if os(iOS)
import UIKit
#endif

enum NotificationCallbackOperationError: LocalizedError, Equatable {
    case deviceIngressV3CompositionUnavailable
    case invalidBinding
    case invalidResult
    case invalidResponse
    case transportRejected

    var errorDescription: String? {
        switch self {
        case .deviceIngressV3CompositionUnavailable:
            return "Device callback resolve/submit is unavailable without the reviewed DeviceIngress v3 composition."
        case .invalidBinding:
            return "The callback request is not bound to this registered device and Entity."
        case .invalidResult:
            return "The callback result is outside the approved DeviceIngress decision contract."
        case .invalidResponse:
            return "The owner-signed DeviceIngress callback response failed exact verification."
        case .transportRejected:
            return "The DeviceIngress callback HTTPS carrier rejected the request or returned invalid bytes."
        }
    }
}

nonisolated protocol DeviceIngressCallbackTransport: Sendable {
    func fetchChallenge(
        operation: DeviceIngressOperation,
        subject: IdentityPublicKeyDescriptor
    ) async throws -> Data

    func submit(
        operation: DeviceIngressOperation,
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data
}

nonisolated private struct DeviceIngressCallbackChallengeTransportRequest: Codable {
    static let currentSchema = "haven.device-ingress.callback-challenge-request.v1"

    let schema: String
    let operation: DeviceIngressOperation
    let subject: IdentityPublicKeyDescriptor

    init(operation: DeviceIngressOperation, subject: IdentityPublicKeyDescriptor) {
        schema = Self.currentSchema
        self.operation = operation
        self.subject = subject
    }
}

nonisolated private struct DeviceIngressCallbackTransportEnvelope: Codable {
    static let currentSchema = "haven.device-callback.transport.v3"

    let schema: String
    let canonicalChallenge: Data
    let canonicalRequest: Data
    let protectedBody: Data

    init(canonicalChallenge: Data, canonicalRequest: Data, protectedBody: Data) {
        schema = Self.currentSchema
        self.canonicalChallenge = canonicalChallenge
        self.canonicalRequest = canonicalRequest
        self.protectedBody = protectedBody
    }
}

nonisolated struct URLSessionDeviceIngressCallbackTransport:
    DeviceIngressCallbackTransport,
    @unchecked Sendable
{
    private let origin: URL
    private let session: URLSession

    init(origin: URL, session: URLSession? = nil) throws {
        guard origin.scheme?.lowercased() == "https",
              origin.user == nil,
              origin.password == nil,
              origin.query == nil,
              origin.fragment == nil,
              origin.path.isEmpty || origin.path == "/",
              origin.host?.isEmpty == false else {
            throw DeviceIngressRegistrationClientError.invalidTransportConfiguration
        }
        self.origin = origin
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.httpShouldSetCookies = false
            configuration.httpCookieAcceptPolicy = .never
            self.session = URLSession(
                configuration: configuration,
                delegate: DeviceIngressNoRedirectSessionDelegate(),
                delegateQueue: nil
            )
        }
    }

    func fetchChallenge(
        operation: DeviceIngressOperation,
        subject: IdentityPublicKeyDescriptor
    ) async throws -> Data {
        guard operation == .resolve || operation == .submit else {
            throw NotificationCallbackOperationError.invalidBinding
        }
        return try await post(
            path: "/conference-mvp/api/device/challenge",
            body: try Self.encoded(DeviceIngressCallbackChallengeTransportRequest(
                operation: operation,
                subject: subject
            )),
            maximumResponseBytes: DeviceIngressEnvelope.maximumEncodedBytes
        )
    }

    func submit(
        operation: DeviceIngressOperation,
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data {
        let path: String
        switch operation {
        case .resolve:
            path = "/conference-mvp/api/device/callback/resolve"
        case .submit:
            path = "/conference-mvp/api/device/callback/submit"
        case .register:
            throw NotificationCallbackOperationError.invalidBinding
        }
        return try await post(
            path: path,
            body: try Self.encoded(DeviceIngressCallbackTransportEnvelope(
                canonicalChallenge: canonicalChallengeData,
                canonicalRequest: canonicalRequestData,
                protectedBody: protectedBody
            )),
            maximumResponseBytes: DeviceIngressOperationResponse.maximumEncodedBytes
        )
    }

    private func post(
        path: String,
        body: Data,
        maximumResponseBytes: Int
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: origin)?.absoluteURL,
              url.scheme == origin.scheme,
              url.host == origin.host,
              url.port == origin.port else {
            throw DeviceIngressRegistrationClientError.invalidTransportConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              data.isEmpty == false,
              data.count <= maximumResponseBytes,
              http.url?.scheme == origin.scheme,
              http.url?.host == origin.host,
              http.url?.port == origin.port else {
            throw NotificationCallbackOperationError.transportRejected
        }
        return data
    }

    private static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

nonisolated private struct DeviceIngressCallbackResolveBody: Codable {
    static let currentSchema = "cellscaffold.device-ingress.callback-resolve.body.v1"
    let schema: String
    let ticketID: String
}

nonisolated private struct DeviceIngressCallbackSubmitBody: Codable {
    static let currentSchema = "cellscaffold.device-ingress.callback-submit.body.v1"
    let schema: String
    let ticketID: String
    let result: [String: JSONValue]
}

nonisolated private struct DeviceIngressResolvedCallbackPayload: Codable {
    struct CorrespondenceApprovalInspection: Codable {
        let schema: String
        let accessRequestID: String
        let displayName: String
        let entityRef: String
        let principalID: String
        let requesterDeviceID: String
        let requesterIdentityUUID: String
        let publicKeyFingerprint: String
        let resourceRefs: [String]
        let allowedPeerIDs: [String]
        let allowedOperations: [String]
        let allowedPurposeRefs: [String]
        let requestExpiresAt: String
        let grantExpiresAt: String
        let executionAuthority: Bool

        var jsonValue: JSONValue {
            .object([
                "schema": .string(schema),
                "accessRequestID": .string(accessRequestID),
                "displayName": .string(displayName),
                "entityRef": .string(entityRef),
                "principalID": .string(principalID),
                "requesterDeviceID": .string(requesterDeviceID),
                "requesterIdentityUUID": .string(requesterIdentityUUID),
                "publicKeyFingerprint": .string(publicKeyFingerprint),
                "resourceRefs": .array(resourceRefs.map(JSONValue.string)),
                "allowedPeerIDs": .array(allowedPeerIDs.map(JSONValue.string)),
                "allowedOperations": .array(allowedOperations.map(JSONValue.string)),
                "allowedPurposeRefs": .array(allowedPurposeRefs.map(JSONValue.string)),
                "requestExpiresAt": .string(requestExpiresAt),
                "grantExpiresAt": .string(grantExpiresAt),
                "executionAuthority": .bool(executionAuthority)
            ])
        }
    }

    struct Content: Codable {
        let schema: String
        let title: String
        let message: String
        let approvalInspection: CorrespondenceApprovalInspection?
    }

    let schema: String
    let ticketID: String
    let triggerEvent: String
    let requiredActionKey: String
    let payload: Content
}

nonisolated actor DeviceIngressCallbackClient {
    private let identityVault: any IdentityVaultProtocol
    private let transport: any DeviceIngressCallbackTransport
    private let trust: DeviceIngressRegistrationTrustConfiguration

    init(
        authenticatedVault: DeviceIngressAuthenticatedVaultHandle,
        transport: any DeviceIngressCallbackTransport,
        trust: DeviceIngressRegistrationTrustConfiguration
    ) {
        identityVault = authenticatedVault.identityVault
        self.transport = transport
        self.trust = trust
    }

    func resolve(
        participantID: String,
        deviceID: String,
        ticketID: String,
        now: Date = Date()
    ) async throws -> [String: JSONValue] {
        let context = try await requesterContext(
            participantID: participantID,
            deviceID: deviceID,
            ticketID: ticketID
        )
        let body = try Self.encoded(DeviceIngressCallbackResolveBody(
            schema: DeviceIngressCallbackResolveBody.currentSchema,
            ticketID: ticketID
        ))
        let response = try await perform(
            operation: .resolve,
            protectedBody: body,
            context: context,
            now: now
        )
        guard response.result.kind == .resolvedTicket,
              let ticket = response.result.resolvedTicket,
              ticket.ticketID == ticketID,
              ticket.recipientDeviceIdentityUUID == context.descriptor.uuid,
              ticket.payloadSchema == "cellscaffold.device-ingress.resolved-payload.v1",
              ticket.payloadContentContractSHA256 == DeviceIngressCanonicalWire.sha256(
                  Data("cellscaffold.device-ingress.resolved-payload.v1".utf8)
              ),
              let payload = try? JSONDecoder().decode(
                  DeviceIngressResolvedCallbackPayload.self,
                  from: ticket.canonicalPayload
              ),
              (try? Self.encoded(payload)) == ticket.canonicalPayload,
              payload.schema == "cellscaffold.device-ingress.resolved-payload.v1",
              payload.ticketID == ticketID,
              Self.validResolvedPayloadContract(payload) else {
            throw NotificationCallbackOperationError.invalidResponse
        }
        var content: [String: JSONValue] = [
            "schema": .string(payload.payload.schema),
            "title": .string(payload.payload.title),
            "message": .string(payload.payload.message)
        ]
        if let approvalInspection = payload.payload.approvalInspection {
            content["approvalInspection"] = approvalInspection.jsonValue
        }
        return [
            "schema": .string(payload.schema),
            "ticketId": .string(payload.ticketID),
            "triggerEvent": .string(payload.triggerEvent),
            "requiredActionKey": .string(payload.requiredActionKey),
            "payload": .object(content)
        ]
    }

    func submit(
        participantID: String,
        deviceID: String,
        ticketID: String,
        result: [String: JSONValue],
        now: Date = Date()
    ) async throws -> [String: JSONValue] {
        let context = try await requesterContext(
            participantID: participantID,
            deviceID: deviceID,
            ticketID: ticketID
        )
        guard case let .string(decision)? = result["decision"],
              decision == "approved" || decision == "rejected" else {
            throw NotificationCallbackOperationError.invalidResult
        }
        let canonicalResult = ["decision": JSONValue.string(decision)]
        let body = try Self.encoded(DeviceIngressCallbackSubmitBody(
            schema: DeviceIngressCallbackSubmitBody.currentSchema,
            ticketID: ticketID,
            result: canonicalResult
        ))
        let response = try await perform(
            operation: .submit,
            protectedBody: body,
            context: context,
            now: now
        )
        guard response.result.kind == .submissionReceipt,
              let receipt = response.result.submissionReceipt,
              receipt.ticketID == ticketID,
              receipt.submittedBodySHA256 == DeviceIngressCanonicalWire.sha256(body),
              receipt.disposition == .accepted,
              receipt.persistenceSemantics
                == DeviceIngressSubmissionReceipt.durableSameCellSubmission else {
            throw NotificationCallbackOperationError.invalidResponse
        }
        return [
            "schema": .string(receipt.schema),
            "ticketId": .string(receipt.ticketID),
            "disposition": .string(receipt.disposition.rawValue),
            "persistenceSemantics": .string(receipt.persistenceSemantics)
        ]
    }

    private func perform(
        operation: DeviceIngressOperation,
        protectedBody: Data,
        context: RequesterContext,
        now: Date
    ) async throws -> DeviceIngressOperationResponse {
        let challenge = try await transport.fetchChallenge(
            operation: operation,
            subject: context.descriptor
        )
        let prepared = try await DeviceIngressRequestFactory.prepare(
            canonicalChallengeData: challenge,
            protectedBody: protectedBody,
            requester: context.identity,
            domainBinding: context.binding,
            expectedAudience: trust.expectedAudience,
            expectedChallengeIssuer: trust.expectedChallengeIssuer,
            now: now
        )
        guard prepared.expectation.operation == operation,
              prepared.expectation.targetOwnerIdentityUUID
                == trust.expectedChallengeIssuer.uuid,
              prepared.expectation.targetOwnerSigningKeyFingerprint
                == IdentityLinkProtocolService.identity(
                    from: trust.expectedChallengeIssuer
                ).signingPublicKeyFingerprint else {
            throw NotificationCallbackOperationError.invalidResponse
        }
        let responseData = try await transport.submit(
            operation: operation,
            canonicalChallengeData: challenge,
            canonicalRequestData: prepared.canonicalRequestData,
            protectedBody: protectedBody
        )
        return try DeviceIngressOperationResponseVerifier.verify(
            canonicalData: responseData,
            expectation: prepared.expectation
        )
    }

    private struct RequesterContext {
        let identity: Identity
        let binding: IdentityDomainBinding
        let descriptor: IdentityPublicKeyDescriptor
    }

    private func requesterContext(
        participantID: String,
        deviceID: String,
        ticketID: String
    ) async throws -> RequesterContext {
        guard participantID.hasPrefix("entity-pairwise:"),
              Self.validIdentifier(ticketID),
              let identity = await identityVault.identity(
                  for: DeviceIngressEnvelope.identityDomain,
                  makeNewIfNotFound: false
              ),
              let binding = await identityVault.identityDomainBinding(for: identity),
              binding.schema == IdentityDomainBinding.currentSchema,
              binding.bindingKind == IdentityDomainBinding.vaultContextKind,
              binding.domain == DeviceIngressEnvelope.identityDomain,
              binding.matches(identity: identity),
              binding.grantsAuthority == false,
              let descriptor = DeviceIngressIdentityDescriptor.publicDescriptor(for: identity),
              deviceID == descriptor.uuid else {
            throw NotificationCallbackOperationError.invalidBinding
        }
        return RequesterContext(
            identity: identity,
            binding: binding,
            descriptor: descriptor
        )
    }

    private static func validIdentifier(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == value
            && trimmed.isEmpty == false
            && trimmed.utf8.count <= 128
            && trimmed.unicodeScalars.allSatisfy { scalar in
                (scalar.value >= 0x30 && scalar.value <= 0x39)
                    || (scalar.value >= 0x41 && scalar.value <= 0x5A)
                    || (scalar.value >= 0x61 && scalar.value <= 0x7A)
                    || scalar == "." || scalar == "_" || scalar == ":" || scalar == "-"
            }
    }

    private static func validResolvedPayloadContract(
        _ payload: DeviceIngressResolvedCallbackPayload
    ) -> Bool {
        let correspondenceAction =
            "haven.assistant-correspondence.issue-access-proof"
        if payload.requiredActionKey == correspondenceAction {
            return payload.payload.schema
                == "cellscaffold.device-ingress.callback-payload.correspondence-approval.v1"
                && payload.payload.approvalInspection?.schema
                    == "haven.assistant-correspondence.approval-inspection.v1"
        }
        return payload.payload.schema == "cellscaffold.device-ingress.callback-payload.v1"
            && payload.payload.approvalInspection == nil
    }

    private static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

nonisolated protocol DeviceIngressCallbackOperating: Sendable {
    func resolve(
        participantID: String,
        deviceID: String,
        ticketID: String,
        now: Date
    ) async throws -> [String: JSONValue]

    func submit(
        participantID: String,
        deviceID: String,
        ticketID: String,
        result: [String: JSONValue],
        now: Date
    ) async throws -> [String: JSONValue]
}

extension DeviceIngressCallbackClient: DeviceIngressCallbackOperating {}

@MainActor
private enum BindingDeviceIngressCallbackComposition {
    static func makeClient() async throws -> any DeviceIngressCallbackOperating {
        guard BindingDeviceIngressRolloutPolicy.currentEnabled else {
            throw NotificationCallbackOperationError
                .deviceIngressV3CompositionUnavailable
        }
        let configuration = try BindingDeviceIngressRuntimeConfiguration.current()
        let vaultHandle = try await DeviceIngressAuthenticatedVaultHandle.current()
        let transport = try URLSessionDeviceIngressCallbackTransport(
            origin: configuration.origin
        )
        return DeviceIngressCallbackClient(
            authenticatedVault: vaultHandle,
            transport: transport,
            trust: configuration.trust
        )
    }
}

final class NotificationCallbackClient {
    static let shared = NotificationCallbackClient()

    private typealias CallbackClientProvider = @MainActor @Sendable () async throws
        -> any DeviceIngressCallbackOperating

    private let rolloutEnabled: @Sendable () -> Bool
    private let callbackClientProvider: CallbackClientProvider

    private init(
        rolloutEnabled: @escaping @Sendable () -> Bool = {
            BindingDeviceIngressRolloutPolicy.currentEnabled
        },
        callbackClientProvider: @escaping CallbackClientProvider = {
            try await BindingDeviceIngressCallbackComposition.makeClient()
        }
    ) {
        self.rolloutEnabled = rolloutEnabled
        self.callbackClientProvider = callbackClientProvider
    }

    #if DEBUG
    static func testing(
        rolloutEnabled: Bool,
        callbackOperator: any DeviceIngressCallbackOperating
    ) -> NotificationCallbackClient {
        NotificationCallbackClient(
            rolloutEnabled: { rolloutEnabled },
            callbackClientProvider: { callbackOperator }
        )
    }
    #endif

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
        guard rolloutEnabled() else {
            throw NotificationCallbackOperationError
                .deviceIngressV3CompositionUnavailable
        }
        let client = try await callbackClientProvider()
        return try await client.resolve(
            participantID: participantId,
            deviceID: deviceId,
            ticketID: ticketId,
            now: Date()
        )
    }

    @discardableResult
    func submitTicketResult(participantId: String, deviceId: String, ticketId: String, result: [String: JSONValue]) async throws -> [String: JSONValue] {
        guard rolloutEnabled() else {
            throw NotificationCallbackOperationError
                .deviceIngressV3CompositionUnavailable
        }
        let client = try await callbackClientProvider()
        return try await client.submit(
            participantID: participantId,
            deviceID: deviceId,
            ticketID: ticketId,
            result: result,
            now: Date()
        )
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

    nonisolated static func responseBodySnippet(from data: Data, maxLength: Int = 512) -> String? {
        guard data.isEmpty == false else {
            return nil
        }
        guard var body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              body.isEmpty == false else {
            return nil
        }
        if body.count > maxLength {
            let endIndex = body.index(body.startIndex, offsetBy: maxLength)
            body = "\(body[..<endIndex])..."
        }
        return body
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
            let resolved = try await resolveTicket(
                participantId: participantId,
                deviceId: deviceId,
                ticketId: ticketId
            )
            guard let action = Self.pendingDeviceAction(
                participantId: participantId,
                deviceId: deviceId,
                expectedTicketId: ticketId,
                resolvedTicket: resolved
            ) else {
                return .failed
            }
            await MainActor.run {
                PendingActionInboxViewModel.shared.upsert(action)
            }
            return .resolved
        } catch {
            print("Notification callback resolve failed: \(error)")
            return .failed
        }
    }

    nonisolated static func pendingDeviceAction(
        participantId: String,
        deviceId: String,
        expectedTicketId: String,
        resolvedTicket: [String: JSONValue],
        receivedAt: Date = Date()
    ) -> PendingDeviceAction? {
        guard stringValue(resolvedTicket["schema"])
                == "cellscaffold.device-ingress.resolved-payload.v1",
              let ticketId = stringValue(resolvedTicket["ticketId"]),
              ticketId == expectedTicketId,
              let requiredActionKey = stringValue(resolvedTicket["requiredActionKey"]),
              case let .object(payload)? = resolvedTicket["payload"] else {
            return nil
        }
        return PendingDeviceAction(
            id: ticketId,
            participantId: participantId,
            deviceId: deviceId,
            ticketId: ticketId,
            requiredActionKey: requiredActionKey,
            payload: payload,
            receivedAt: receivedAt
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

struct NotificationCallbackHTTPError: LocalizedError, CustomStringConvertible {
    var statusCode: Int
    var responseBody: String?

    var errorDescription: String? {
        if let responseBody, responseBody.isEmpty == false {
            return "Staging returned HTTP \(statusCode): \(responseBody)"
        }
        return "Staging returned HTTP \(statusCode) during notification callback."
    }

    var description: String {
        errorDescription ?? "Staging returned an unexpected HTTP response."
    }
}
