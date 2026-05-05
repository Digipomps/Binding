import Foundation
import CellBase
import HavenAgentRuntime

public final class RemoteIntentInboxCell: GeneralCell {
    private enum CodingKeys: String, CodingKey {
        case version
    }

    public required init(owner: Identity) async {
        await super.init(owner: owner)
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let cell = UncheckedSendableReference(value: self)
        Task {
            let requester = Identity()
            let decodedOwner = (try? await cell.value.getOwner(requester: requester)) ?? requester
            await cell.value.setupPermissions(owner: decodedOwner)
            await cell.value.setupKeys(owner: decodedOwner)
        }
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("1", forKey: .version)
    }

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "queue")
        agreementTemplate.addGrant("rw--", for: "enqueue")
        agreementTemplate.addGrant("rw--", for: "enqueueSigned")
        agreementTemplate.addGrant("rw--", for: "clear")
        agreementTemplate.addGrant("r---", for: "flow")
    }

    private func setupKeys(owner: Identity) async {
        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "state", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeStateValue()
        })

        await addInterceptForGet(requester: owner, key: "queue", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "queue", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeQueueValue()
        })

        await addInterceptForSet(requester: owner, key: "enqueue", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "enqueue", for: requester) else { return .string("denied") }
            do {
                let intent = try self.parseIntent(from: value)
                await AgentRuntimeBridge.shared.enqueue(intent: intent)
                await self.publishIntentEvent(intent: intent, requester: requester)
                return await self.makeStateValue()
            } catch {
                return .string("error: \(error.localizedDescription)")
            }
        })

        await addInterceptForSet(requester: owner, key: "enqueueSigned", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "enqueueSigned", for: requester) else { return .string("denied") }
            do {
                let intent = try await self.parseSignedIntent(from: value)
                await self.publishIntentEvent(intent: intent, requester: requester)
                return await self.makeStateValue()
            } catch {
                await self.publishRejectedIntentEvent(
                    message: error.localizedDescription,
                    requester: requester
                )
                return .string("error: \(error.localizedDescription)")
            }
        })

        await addInterceptForSet(requester: owner, key: "clear", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("rw--", at: "clear", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            await AgentRuntimeBridge.shared.clearQueuedIntents()
            await self.publishClearEvent(requester: requester)
            return await self.makeStateValue()
        })
    }

    private func parseIntent(from value: ValueType) throws -> QueuedRemoteIntent {
        guard case let .object(object) = value else {
            throw InboxError.invalidPayload
        }
        guard case let .string(topic)? = object["topic"],
              case let .string(origin)? = object["origin"],
              case let .string(actionID)? = object["actionID"] else {
            throw InboxError.invalidPayload
        }

        let arguments: [String: String] = try {
            guard case let .object(argumentObject)? = object["arguments"] else {
                return [:]
            }
            return try argumentObject.reduce(into: [String: String]()) { partialResult, entry in
                guard case let .string(stringValue) = entry.value else {
                    throw InboxError.invalidPayload
                }
                partialResult[entry.key] = stringValue
            }
        }()

        return QueuedRemoteIntent(
            topic: topic,
            origin: origin,
            actionID: actionID,
            arguments: arguments,
            receivedAt: ISO8601DateFormatter().string(from: Date()),
            verificationStatus: "local"
        )
    }

    private func parseSignedIntent(from value: ValueType) async throws -> QueuedRemoteIntent {
        let envelope = try SignedRemoteIntentEnvelopeValueCodec.decode(from: value)
        return try await RemoteIntentInboxService.enqueueSignedEnvelope(envelope)
    }

    private func publishIntentEvent(intent: QueuedRemoteIntent, requester: Identity) async {
        var payload: Object = [
            "id": .string(intent.id),
            "topic": .string(intent.topic),
            "origin": .string(intent.origin),
            "actionID": .string(intent.actionID),
            "receivedAt": .string(intent.receivedAt),
            "verificationStatus": .string(intent.verificationStatus)
        ]
        payload["issuerID"] = intent.issuerID.map(ValueType.string) ?? .null
        var flowElement = FlowElement(
            title: "intent.inbox.enqueued",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "intent.inbox"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func publishRejectedIntentEvent(message: String, requester: Identity) async {
        let payload: Object = [
            "rejectedAt": .string(ISO8601DateFormatter().string(from: Date())),
            "message": .string(message)
        ]
        var flowElement = FlowElement(
            title: "intent.inbox.rejected",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "intent.inbox"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func publishClearEvent(requester: Identity) async {
        let payload: Object = [
            "clearedAt": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        var flowElement = FlowElement(
            title: "intent.inbox.cleared",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "intent.inbox"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func makeStateValue() async -> ValueType {
        let queue = await AgentRuntimeBridge.shared.queuedIntentSnapshot()
        return .object([
            "count": .integer(queue.count),
            "lastIntentID": queue.last.map { .string($0.id) } ?? .null,
            "lastTopic": queue.last.map { .string($0.topic) } ?? .null,
            "lastVerificationStatus": queue.last.map { .string($0.verificationStatus) } ?? .null,
            "lastIssuerID": queue.last?.issuerID.map(ValueType.string) ?? .null
        ])
    }

    private func makeQueueValue() async -> ValueType {
        let queue = await AgentRuntimeBridge.shared.queuedIntentSnapshot()
        return .list(queue.map { intent in
            .object([
                "id": .string(intent.id),
                "topic": .string(intent.topic),
                "origin": .string(intent.origin),
                "actionID": .string(intent.actionID),
                "receivedAt": .string(intent.receivedAt),
                "issuedAt": intent.issuedAt.map(ValueType.string) ?? .null,
                "expiresAt": intent.expiresAt.map(ValueType.string) ?? .null,
                "issuerID": intent.issuerID.map(ValueType.string) ?? .null,
                "verificationStatus": .string(intent.verificationStatus),
                "arguments": .object(intent.arguments.mapValues(ValueType.string))
            ])
        })
    }
}

private enum InboxError: Error, LocalizedError {
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid intent payload"
        }
    }
}
