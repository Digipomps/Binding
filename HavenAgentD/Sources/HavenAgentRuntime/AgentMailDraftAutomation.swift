import Foundation
import HavenMacAutomation

public enum AgentMailDraftAutomation {
    public static let actionID = "mail.compose-draft"
    public static let endpoint = "cell:///agent/email/outbox"
    public static let controlBridgeRouteName = "email-outbox"
    public static let purposeRef = "personal.agent.email.compose-draft"
    public static let contactFallbackPurposeRef = "personal.chat.assist.external-email-contact"
    public static let goalID = "agent.email.prepare-user-reviewed-draft"
    public static let capabilityRef = "cap.local_email_draft"
    public static let topic = "intent.inbox"

    public static let purposeRefs = [
        purposeRef,
        contactFallbackPurposeRef,
        "personal.chat.assist.entity-contact-request"
    ]

    public static let interests = [
        "agentd",
        "email",
        "e-post",
        "mail",
        "external-contact",
        "contact-fallback",
        "draft-only",
        "local-review",
        "requires-user-approval"
    ]

    public static var appleScriptDefinition: AppleScriptDefinition {
        AppleScriptDefinition(
            id: actionID,
            description: "Create a visible Mail.app email draft for local operator review. Does not send automatically.",
            source: source,
            argumentOrder: ["to", "subject", "body"],
            argumentConstraints: [
                "to": StringConstraint(
                    required: true,
                    maxLength: 320,
                    allowedValues: [],
                    pattern: #"[^@\s]+@[^@\s]+\.[^@\s]+"#
                ),
                "subject": StringConstraint(
                    required: true,
                    maxLength: 180,
                    allowedValues: [],
                    pattern: nil
                ),
                "body": StringConstraint(
                    required: true,
                    maxLength: 8_000,
                    allowedValues: [],
                    pattern: nil,
                    allowsNewlines: true
                )
            ],
            allowedForRemoteExecution: true,
            requiresUserSession: true
        )
    }

    public static var source: String {
        """
        on run argv
            if (count of argv) is less than 3 then error "Expected recipient, subject and body"
            set recipientAddress to item 1 of argv
            set subjectLine to item 2 of argv
            set bodyText to item 3 of argv
            tell application "Mail"
                activate
                set draftMessage to make new outgoing message with properties {subject:subjectLine, content:bodyText, visible:true}
                tell draftMessage
                    make new to recipient at end of to recipients with properties {address:recipientAddress}
                end tell
            end tell
            return "draft-created"
        end run
        """
    }
}
