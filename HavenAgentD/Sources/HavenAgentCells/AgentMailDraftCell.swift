import Foundation
import CellBase
import HavenAgentRuntime

public final class AgentMailDraftCell: HavenAgentRuntimeBindingCell {
    private enum CodingKeys: String, CodingKey {
        case version
    }

    public required init(owner: Identity) async {
        await super.init(owner: owner)
        await installRuntimeBindings(owner: owner)
        await markRuntimeBindingsInstalled()
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("1", forKey: .version)
    }

    override func installRuntimeBindings(owner: Identity) async {
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    private func setupPermissions(owner: Identity) async {
        ensureAgreementGrant("r---", for: "state")
        ensureAgreementGrant("r---", for: "contracts")
        ensureAgreementGrant("r---", for: "purposeProfiles")
        ensureAgreementGrant("rw--", for: "draftIntent")
        ensureAgreementGrant("r---", for: "flow")
    }

    private func hasAccess(_ access: String, at key: String, requester: Identity) async -> Bool {
        if await validateAccess(access, at: key, for: requester) { return true }
        return await LocalControlCellAccess.isPairedOperator(requester)
    }

    private func setupKeys(owner: Identity) async {
        await setupExploreContracts(owner: owner)

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "state", requester: requester) else { return .string("denied") }
            return self.stateValue()
        })

        await addInterceptForGet(requester: owner, key: "contracts", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "contracts", requester: requester) else { return .string("denied") }
            return self.contractsValue()
        })

        await addInterceptForGet(requester: owner, key: "purposeProfiles", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "purposeProfiles", requester: requester) else { return .string("denied") }
            return .list([.object(Self.purposeProfile())])
        })

        await addInterceptForSet(requester: owner, key: "draftIntent", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("rw--", at: "draftIntent", requester: requester) else { return .string("denied") }
            return await self.prepareDraftIntent(value: value, requester: requester)
        })
    }

    private func setupExploreContracts(owner: Identity) async {
        let draftInput = ExploreContract.objectSchema(
            properties: [
                "to": ExploreContract.schema(type: "string", description: "Recipient email address."),
                "subject": ExploreContract.schema(type: "string"),
                "body": ExploreContract.schema(type: "string"),
                "correlationID": ExploreContract.schema(type: "string")
            ],
            requiredKeys: ["to", "subject", "body"]
        )
        await registerExploreContract(
            requester: owner,
            key: "state",
            method: .get,
            returns: ExploreContract.objectSchema(),
            permissions: ["r---"],
            description: .string("Returns the local email draft adapter status and purpose metadata.")
        )
        await registerExploreContract(
            requester: owner,
            key: "contracts",
            method: .get,
            returns: ExploreContract.objectSchema(),
            permissions: ["r---"],
            description: .string("Describes the email draft request shape.")
        )
        await registerExploreContract(
            requester: owner,
            key: "purposeProfiles",
            method: .get,
            returns: ExploreContract.listSchema(item: ExploreContract.objectSchema()),
            permissions: ["r---"],
            description: .string("Returns purpose refs and interests Co-Pilot can use for email/contact fallback routing.")
        )
        await registerExploreContract(
            requester: owner,
            key: "draftIntent",
            method: .set,
            input: draftInput,
            returns: ExploreContract.objectSchema(),
            permissions: ["rw--"],
            flowEffects: [ExploreContract.flowEffect(trigger: .set, topic: "agent.email.outbox", contentType: "object")],
            description: .string("Prepares a review-intent for a visible Mail.app draft. Does not send or open Mail by itself.")
        )
    }

    private func stateValue() -> ValueType {
        .object([
            "status": .string("ready"),
            "endpoint": .string(AgentMailDraftAutomation.endpoint),
            "actionID": .string(AgentMailDraftAutomation.actionID),
            "topic": .string(AgentMailDraftAutomation.topic),
            "runtimeTarget": .string("macos-agentd"),
            "deliveryMode": .string("visible_mail_app_draft"),
            "sideEffectBoundary": .string("draftIntent prepares a signed/reviewable intent only; approved execution creates a visible Mail.app draft and never sends automatically."),
            "requiresLocalReview": .bool(true),
            "requiresUserSession": .bool(true),
            "purposeProfiles": .list([.object(Self.purposeProfile())])
        ])
    }

    private func contractsValue() -> ValueType {
        .object([
            "draftIntent": .object([
                "expects": .object([
                    "to": .string("required email address"),
                    "subject": .string("required String, max 180 chars"),
                    "body": .string("required String, max 8000 chars; multiline allowed"),
                    "correlationID": .string("optional String")
                ]),
                "returns": .string("A review-intent payload for RemoteIntentInboxCell / RemoteIntentReviewCell."),
                "sideEffect": .string("none until the returned intent is signed/queued and approved")
            ])
        ])
    }

    private static func purposeProfile() -> Object {
        [
            "id": .string("agent-email-compose-draft"),
            "title": .string("Email Draft"),
            "purposeRef": .string(AgentMailDraftAutomation.purposeRef),
            "purposeRefs": .list(AgentMailDraftAutomation.purposeRefs.map(ValueType.string)),
            "goalID": .string(AgentMailDraftAutomation.goalID),
            "capabilityRef": .string(AgentMailDraftAutomation.capabilityRef),
            "interests": .list(AgentMailDraftAutomation.interests.map(ValueType.string)),
            "privacyLevel": .string("local_review_required"),
            "executionScope": .string("local_agent_mail_app_draft"),
            "sideEffectBoundary": .string("Creates a visible draft only after explicit local review; it does not send automatically.")
        ]
    }

    private func prepareDraftIntent(value: ValueType, requester: Identity) async -> ValueType {
        do {
            let request = try Self.parseRequest(value)
            let intent: Object = [
                "topic": .string(AgentMailDraftAutomation.topic),
                "origin": .string("cell:///agent/email/outbox"),
                "actionID": .string(AgentMailDraftAutomation.actionID),
                "purposeRef": .string(AgentMailDraftAutomation.purposeRef),
                "goalID": .string(AgentMailDraftAutomation.goalID),
                "requiresLocalReview": .bool(true),
                "sideEffectUntilReview": .bool(false),
                "arguments": .object([
                    "to": .string(request.to),
                    "subject": .string(request.subject),
                    "body": .string(request.body)
                ]),
                "correlationID": request.correlationID.map(ValueType.string) ?? .null
            ]
            await publishDraftPreparedEvent(intent: intent, requester: requester)
            return .object([
                "status": .string("draft_intent_prepared"),
                "message": .string("Email draft intent prepared for local review."),
                "intent": .object(intent),
                "purposeProfile": .object(Self.purposeProfile())
            ])
        } catch {
            return .object([
                "status": .string("invalid_request"),
                "message": .string(error.localizedDescription)
            ])
        }
    }

    private func publishDraftPreparedEvent(intent: Object, requester: Identity) async {
        var payload = intent
        payload["preparedAt"] = .string(ISO8601DateFormatter().string(from: Date()))
        var flow = FlowElement(
            title: "agent.email.draft.prepared",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flow.topic = "agent.email.outbox"
        flow.origin = uuid
        pushFlowElement(flow, requester: requester)
    }

    private static func parseRequest(_ value: ValueType) throws -> DraftRequest {
        guard case let .object(object) = value else {
            throw MailDraftError.invalidPayload
        }
        let to = try requiredString("to", in: object)
        let subject = try requiredString("subject", in: object)
        let body = try requiredString("body", in: object)
        let correlationID = optionalString("correlationID", in: object) ?? optionalString("correlationId", in: object)

        guard to.count <= 320, isEmailish(to) else {
            throw MailDraftError.invalidRecipient
        }
        guard !subject.isEmpty, subject.count <= 180, !subject.contains(where: \.isNewline) else {
            throw MailDraftError.invalidSubject
        }
        guard !body.isEmpty, body.count <= 8_000 else {
            throw MailDraftError.invalidBody
        }
        return DraftRequest(to: to, subject: subject, body: body, correlationID: correlationID)
    }

    private static func requiredString(_ key: String, in object: Object) throws -> String {
        guard let value = optionalString(key, in: object), !value.isEmpty else {
            throw MailDraftError.missingRequiredField(key)
        }
        return value
    }

    private static func optionalString(_ key: String, in object: Object) -> String? {
        guard case let .string(value)? = object[key] else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isEmailish(_ value: String) -> Bool {
        let pattern = #"[^@\s]+@[^@\s]+\.[^@\s]+"#
        let range = NSRange(location: 0, length: value.utf16.count)
        return (try? NSRegularExpression(pattern: pattern))
            .flatMap { $0.firstMatch(in: value, options: [], range: range) }?
            .range == range
    }
}

private struct DraftRequest {
    var to: String
    var subject: String
    var body: String
    var correlationID: String?
}

private enum MailDraftError: Error, LocalizedError {
    case invalidPayload
    case missingRequiredField(String)
    case invalidRecipient
    case invalidSubject
    case invalidBody

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "draftIntent requires an object payload."
        case .missingRequiredField(let key):
            return "draftIntent is missing required field '\(key)'."
        case .invalidRecipient:
            return "Recipient must be a single email address."
        case .invalidSubject:
            return "Subject must be non-empty, single-line and at most 180 characters."
        case .invalidBody:
            return "Body must be non-empty and at most 8000 characters."
        }
    }
}
