import SwiftUI

struct PendingAgentActionOverlay: View {
    @ObservedObject private var inbox = PendingActionInboxViewModel.shared
    @State private var drafts: [String: String] = [:]
    @State private var sendingTicketID: String?
    @State private var errorMessage: String?

    var body: some View {
        if let action = inbox.actions.first(where: { $0.requiredActionKey == AgentConversationClient.requiredActionKey }) {
            VStack {
                Spacer()
                PendingAgentActionCard(
                    action: action,
                    draft: Binding(
                        get: { drafts[action.ticketId] ?? "" },
                        set: { drafts[action.ticketId] = $0 }
                    ),
                    isSending: sendingTicketID == action.ticketId,
                    errorMessage: errorMessage,
                    onSend: {
                        Task {
                            await send(action: action)
                        }
                    },
                    onDismiss: {
                        inbox.remove(ticketId: action.ticketId)
                    }
                )
                .padding()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @MainActor
    private func send(action: PendingDeviceAction) async {
        let prompt = (drafts[action.ticketId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else {
            errorMessage = "Write the next prompt before sending."
            return
        }

        sendingTicketID = action.ticketId
        errorMessage = nil
        do {
            try await AgentConversationClient.shared.postPrompt(action: action, prompt: prompt)
            drafts[action.ticketId] = ""
            inbox.remove(ticketId: action.ticketId)
        } catch {
            errorMessage = error.localizedDescription
        }
        sendingTicketID = nil
    }
}

private struct PendingAgentActionCard: View {
    var action: PendingDeviceAction
    @Binding var draft: String
    var isSending: Bool
    var errorMessage: String?
    var onSend: () -> Void
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

            TextEditor(text: $draft)
                .frame(minHeight: 88, maxHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                Text("Svar sendes til staging og plukkes opp av HAVENAgent via flow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isSending ? "Sender..." : "Send prompt", action: onSend)
                    .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 12)
    }

    private var title: String {
        stringValue(action.payload["title"]) ?? "HAVENAgent venter på neste prompt"
    }

    private var subtitle: String {
        let message = stringValue(action.payload["message"]) ?? "Skriv hva agenten skal gjøre videre."
        let jobId = stringValue(action.payload["jobId"]).map { "Job \($0)" }
        return [jobId, message].compactMap { $0 }.joined(separator: " · ")
    }

    private func stringValue(_ value: JSONValue?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
