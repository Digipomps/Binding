import SwiftUI

struct CorrespondenceApprovalInspection: Equatable {
    static let actionKey = "haven.assistant-correspondence.issue-access-proof"
    static let schema = "haven.assistant-correspondence.approval-inspection.v1"
    static let endpoint = "cell:///AssistantCorrespondence"
    static let operations: Set<String> = [
        "inbox.list", "message.read", "message.send", "message.ack"
    ]
    static let purposeRefs: Set<String> = [
        "purpose://contact.communication", "purpose://digital-work.coordinate"
    ]

    let accessRequestID: String?
    let displayName: String?
    let entityRef: String?
    let principalID: String?
    let requesterDeviceID: String?
    let requesterIdentityUUID: String?
    let publicKeyFingerprint: String?
    let resourceRefs: [String]
    let allowedPeerIDs: [String]
    let allowedOperations: [String]
    let allowedPurposeRefs: [String]
    let requestExpiresAt: String?
    let grantExpiresAt: String?
    let executionAuthority: Bool?
    let validationIssues: [String]

    init?(action: PendingDeviceAction, now: Date = Date()) {
        guard action.requiredActionKey == Self.actionKey else { return nil }
        let object: [String: JSONValue]
        if case let .object(value)? = action.payload["approvalInspection"] {
            object = value
        } else {
            object = [:]
        }

        accessRequestID = Self.string(object["accessRequestID"])
        displayName = Self.string(object["displayName"])
        entityRef = Self.string(object["entityRef"])
        principalID = Self.string(object["principalID"])
        requesterDeviceID = Self.string(object["requesterDeviceID"])
        requesterIdentityUUID = Self.string(object["requesterIdentityUUID"])
        publicKeyFingerprint = Self.string(object["publicKeyFingerprint"])
        resourceRefs = Self.strings(object["resourceRefs"])
        allowedPeerIDs = Self.strings(object["allowedPeerIDs"])
        allowedOperations = Self.strings(object["allowedOperations"])
        allowedPurposeRefs = Self.strings(object["allowedPurposeRefs"])
        requestExpiresAt = Self.string(object["requestExpiresAt"])
        grantExpiresAt = Self.string(object["grantExpiresAt"])
        if case let .bool(value)? = object["executionAuthority"] {
            executionAuthority = value
        } else {
            executionAuthority = nil
        }

        var issues: [String] = []
        if Self.string(action.payload["schema"])
            != "cellscaffold.device-ingress.callback-payload.correspondence-approval.v1" {
            issues.append("Den device-signerte detaljkontrakten mangler eller har feil versjon.")
        }
        if Self.string(object["schema"]) != Self.schema {
            issues.append("Kontrollgrunnlaget har feil skjema.")
        }
        Self.require(accessRequestID, label: "request-ID", issues: &issues)
        Self.require(displayName, label: "visningsnavn", issues: &issues)
        Self.require(entityRef, label: "Entity", issues: &issues)
        Self.require(principalID, label: "principal", issues: &issues)
        Self.require(requesterDeviceID, label: "søkerens device-ID", issues: &issues)
        Self.require(requesterIdentityUUID, label: "søkerens identity-UUID", issues: &issues)
        if let publicKeyFingerprint {
            if Self.validFingerprint(publicKeyFingerprint) == false {
                issues.append("Nøkkelfingerprinten er ikke en gyldig SHA-256-verdi.")
            }
        } else {
            issues.append("Nøkkelfingerprint mangler.")
        }
        if resourceRefs != [Self.endpoint] {
            issues.append("Ressursen er ikke avgrenset til Assistant Correspondence.")
        }
        if allowedPeerIDs.isEmpty || Set(allowedPeerIDs).count != allowedPeerIDs.count {
            issues.append("Peer-listen mangler eller inneholder duplikater.")
        }
        if Set(allowedOperations) != Self.operations
            || allowedOperations.count != Self.operations.count {
            issues.append("Operasjonene er ikke nøyaktig de fire meldingsoperasjonene.")
        }
        let purposes = Set(allowedPurposeRefs)
        if purposes.isEmpty || purposes.count != allowedPurposeRefs.count
            || purposes.isSubset(of: Self.purposeRefs) == false {
            issues.append("Formålene er tomme, dupliserte eller utenfor correspondence-avgrensningen.")
        }
        if executionAuthority != false {
            issues.append("Forespørselen bekrefter ikke executionAuthority=false.")
        }
        let requestExpiry = requestExpiresAt.flatMap(Self.date)
        let grantExpiry = grantExpiresAt.flatMap(Self.date)
        if let requestExpiry {
            if requestExpiry <= now {
                issues.append("Tilgangsforespørselen er utløpt.")
            }
        } else {
            issues.append("Forespørselens utløp mangler eller er ugyldig.")
        }
        if let grantExpiry {
            if grantExpiry <= now {
                issues.append("Adgangsbevisets utløp er passert.")
            }
        } else {
            issues.append("Adgangsbevisets utløp mangler eller er ugyldig.")
        }
        if let requestExpiry, let grantExpiry, grantExpiry <= requestExpiry {
            issues.append("Adgangsbeviset utløper ikke etter forespørselen.")
        }
        validationIssues = issues
    }

    var isComplete: Bool { validationIssues.isEmpty }

    private static func require(
        _ value: String?,
        label: String,
        issues: inout [String]
    ) {
        if value == nil { issues.append("\(label) mangler.") }
    }

    private static func string(_ value: JSONValue?) -> String? {
        guard case let .string(string)? = value else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func strings(_ value: JSONValue?) -> [String] {
        guard case let .array(values)? = value else { return [] }
        return values.compactMap(Self.string)
    }

    private static func validFingerprint(_ value: String) -> Bool {
        let prefix = "sha256:"
        guard value.hasPrefix(prefix) else { return false }
        let digest = value.dropFirst(prefix.count)
        return digest.count == 43
            && digest.unicodeScalars.allSatisfy { scalar in
                (scalar.value >= 0x30 && scalar.value <= 0x39)
                    || (scalar.value >= 0x41 && scalar.value <= 0x5A)
                    || (scalar.value >= 0x61 && scalar.value <= 0x7A)
                    || scalar == "-" || scalar == "_"
            }
    }

    private static func date(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

struct PendingAgentActionOverlay: View {
    @ObservedObject private var inbox = PendingActionInboxViewModel.shared
    @State private var drafts: [String: String] = [:]
    @State private var identityComparedTicketIDs: Set<String> = []
    @State private var sendingTicketID: String?
    @State private var errorMessage: String?

    var body: some View {
        if let action = inbox.actions.first {
            VStack {
                Spacer()
                PendingAgentActionCard(
                    action: action,
                    draft: Binding(
                        get: { drafts[action.ticketId] ?? "" },
                        set: { drafts[action.ticketId] = $0 }
                    ),
                    identityCompared: Binding(
                        get: { identityComparedTicketIDs.contains(action.ticketId) },
                        set: { isCompared in
                            if isCompared {
                                identityComparedTicketIDs.insert(action.ticketId)
                            } else {
                                identityComparedTicketIDs.remove(action.ticketId)
                            }
                        }
                    ),
                    isSending: sendingTicketID == action.ticketId,
                    errorMessage: errorMessage,
                    onSendPrompt: {
                        Task {
                            await sendPrompt(action: action)
                        }
                    },
                    onApprove: {
                        Task {
                            await sendDecision(action: action, decision: .approved)
                        }
                    },
                    onReject: {
                        Task {
                            await sendDecision(action: action, decision: .rejected)
                        }
                    },
                    onDismiss: {
                        identityComparedTicketIDs.remove(action.ticketId)
                        inbox.remove(ticketId: action.ticketId)
                    }
                )
                .padding()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @MainActor
    private func sendPrompt(action: PendingDeviceAction) async {
        let prompt = (drafts[action.ticketId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else {
            errorMessage = "Write the next prompt before sending."
            return
        }

        sendingTicketID = action.ticketId
        errorMessage = nil
        do {
            if AgentConversationClient.shouldRouteToAgentInbox(action: action) {
                try await submitAgentPrompt(action: action, prompt: prompt)
            } else {
                try await NotificationCallbackClient.shared.submitTicketResult(
                    participantId: action.participantId,
                    deviceId: action.deviceId,
                    ticketId: action.ticketId,
                    result: NotificationCallbackClient.ticketPromptResult(action: action, prompt: prompt)
                )
            }
            drafts[action.ticketId] = ""
            identityComparedTicketIDs.remove(action.ticketId)
            inbox.remove(ticketId: action.ticketId)
        } catch {
            errorMessage = error.localizedDescription
        }
        sendingTicketID = nil
    }

    @MainActor
    private func sendDecision(action: PendingDeviceAction, decision: AgentConversationDecision) async {
        sendingTicketID = action.ticketId
        errorMessage = nil
        do {
            if AgentConversationClient.shouldRouteToAgentInbox(action: action) {
                try await submitAgentDecision(action: action, decision: decision)
            } else {
                try await NotificationCallbackClient.shared.submitTicketResult(
                    participantId: action.participantId,
                    deviceId: action.deviceId,
                    ticketId: action.ticketId,
                    result: NotificationCallbackClient.ticketDecisionResult(action: action, decision: decision)
                )
            }
            drafts[action.ticketId] = ""
            identityComparedTicketIDs.remove(action.ticketId)
            inbox.remove(ticketId: action.ticketId)
        } catch {
            errorMessage = error.localizedDescription
        }
        sendingTicketID = nil
    }

    private func submitAgentPrompt(action: PendingDeviceAction, prompt: String) async throws {
        do {
            try await NotificationCallbackClient.shared.submitTicketResult(
                participantId: action.participantId,
                deviceId: action.deviceId,
                ticketId: action.ticketId,
                result: NotificationCallbackClient.ticketPromptResult(action: action, prompt: prompt)
            )
        } catch {
            try await AgentConversationClient.shared.postPrompt(action: action, prompt: prompt)
        }
    }

    private func submitAgentDecision(action: PendingDeviceAction, decision: AgentConversationDecision) async throws {
        do {
            try await NotificationCallbackClient.shared.submitTicketResult(
                participantId: action.participantId,
                deviceId: action.deviceId,
                ticketId: action.ticketId,
                result: NotificationCallbackClient.ticketDecisionResult(action: action, decision: decision)
            )
        } catch {
            try await AgentConversationClient.shared.postDecision(action: action, decision: decision)
        }
    }
}

private struct PendingAgentActionCard: View {
    var action: PendingDeviceAction
    @Binding var draft: String
    @Binding var identityCompared: Bool
    var isSending: Bool
    var errorMessage: String?
    var onSendPrompt: () -> Void
    var onApprove: () -> Void
    var onReject: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Lukk", action: onDismiss)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            if requiresPrompt {
                TextEditor(text: $draft)
                    .frame(minHeight: 88, maxHeight: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
            }

            if let inspection = CorrespondenceApprovalInspection(action: action) {
                Divider()
                correspondenceInspection(inspection)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                Text(actionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if requiresPrompt {
                    Button(isSending ? "Sender..." : "Send prompt", action: onSendPrompt)
                        .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(rejectButtonTitle, action: onReject)
                        .disabled(isSending)
                        .buttonStyle(.bordered)
                    Button(isSending ? "Sender..." : approveButtonTitle, action: onApprove)
                        .disabled(isSending || correspondenceApprovalIsBlocked)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("correspondence-approval-approve")
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 12)
        .frame(maxWidth: 760)
    }

    @ViewBuilder
    private func correspondenceInspection(
        _ inspection: CorrespondenceApprovalInspection
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: inspection.isComplete
                    ? "checkmark.shield.fill"
                    : "exclamationmark.shield.fill")
                Text(inspection.isComplete
                    ? "Kontrollgrunnlag komplett"
                    : "Godkjenning blokkert – kontrollgrunnlaget er ufullstendig")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(inspection.isComplete ? .green : .red)

            Text("Sammenlign disse verdiene med `haven-correspondence-mcp identity --profile …` på maskinen som ber om adgang.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ApprovalInspectionRow(label: "Forespørsel", value: inspection.accessRequestID)
                    ApprovalInspectionRow(label: "Navn", value: inspection.displayName)
                    ApprovalInspectionRow(label: "Entity", value: inspection.entityRef)
                    ApprovalInspectionRow(label: "Principal", value: inspection.principalID)
                    ApprovalInspectionRow(label: "Søkerens device-ID", value: inspection.requesterDeviceID)
                    ApprovalInspectionRow(label: "Søkerens identity-UUID", value: inspection.requesterIdentityUUID)
                    ApprovalInspectionRow(label: "SHA-256 nøkkelfingerprint", value: inspection.publicKeyFingerprint)
                    ApprovalInspectionRow(label: "Ressurs", values: inspection.resourceRefs)
                    ApprovalInspectionRow(label: "Peers", values: inspection.allowedPeerIDs)
                    ApprovalInspectionRow(label: "Operasjoner", values: inspection.allowedOperations)
                    ApprovalInspectionRow(label: "Formål", values: inspection.allowedPurposeRefs)
                    ApprovalInspectionRow(label: "Forespørsel utløper", value: inspection.requestExpiresAt)
                    ApprovalInspectionRow(label: "Adgangsbevis utløper", value: inspection.grantExpiresAt)
                    ApprovalInspectionRow(
                        label: "Kode-/shellmyndighet",
                        value: inspection.executionAuthority == false ? "Nei" : "Mangler/ugyldig"
                    )
                }
            }
            .frame(maxHeight: 330)

            if inspection.validationIssues.isEmpty == false {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(inspection.validationIssues, id: \.self) { issue in
                        Text("• \(issue)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.red)
            }

            Toggle(
                "Jeg har sammenlignet request-ID, Entity, device, identity og nøkkelfingerprint med søkerens lokale `identity`-utskrift.",
                isOn: $identityCompared
            )
            .disabled(inspection.isComplete == false)
            .font(.caption)
            .accessibilityIdentifier("correspondence-approval-identity-confirmation")
        }
    }

    private var title: String {
        stringValue(action.payload["title"]) ?? "HAVENAgent venter på neste prompt"
    }

    private var subtitle: String {
        let message = stringValue(action.payload["message"]) ?? defaultMessage
        let jobId = stringValue(action.payload["jobId"]).map { "Job \($0)" }
        return [jobId, message].compactMap { $0 }.joined(separator: " · ")
    }

    private var requiresPrompt: Bool {
        action.requiredActionKey == AgentConversationClient.requiredActionKey
            || stringValue(action.payload["responseMode"]) == "prompt"
    }

    private var defaultMessage: String {
        requiresPrompt
            ? "Skriv hva agenten skal gjøre videre."
            : "Godkjenn eller avvis om agenten skal fortsette."
    }

    private var actionHint: String {
        if isCorrespondenceAccessRequest {
            return "Beviset bindes til Entitet, nøkkel, enhet, formål og fire meldingsoperasjoner."
        }
        return requiresPrompt
            ? "Svar sendes til staging og plukkes opp av HAVENAgent via flow."
            : "Beslutningen sendes tilbake via staging og havner i agentens reply-inbox."
    }

    private var isCorrespondenceAccessRequest: Bool {
        action.requiredActionKey == CorrespondenceApprovalInspection.actionKey
    }

    private var correspondenceApprovalIsBlocked: Bool {
        guard let inspection = CorrespondenceApprovalInspection(action: action) else {
            return false
        }
        return inspection.isComplete == false || identityCompared == false
    }

    private var approveButtonTitle: String {
        isCorrespondenceAccessRequest ? "Utsted adgangsbevis" : "Approve"
    }

    private var rejectButtonTitle: String {
        isCorrespondenceAccessRequest ? "Avslå" : "Reject"
    }

    private func stringValue(_ value: JSONValue?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ApprovalInspectionRow: View {
    var label: String
    var value: String?

    init(label: String, value: String?) {
        self.label = label
        self.value = value
    }

    init(label: String, values: [String]) {
        self.label = label
        self.value = values.isEmpty ? nil : values.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value ?? "Mangler")
                .font(.caption.monospaced())
                .foregroundStyle(value == nil ? .red : .primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
