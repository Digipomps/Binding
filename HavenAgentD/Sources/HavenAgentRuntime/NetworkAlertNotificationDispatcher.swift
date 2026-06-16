// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import HavenMacAutomation

/// Delivers the macOS-native side of a network flood alert.
///
/// The in-HAVEN channel is the `.alert` FlowElement the cell already emits
/// (carrying `notificationsEnabled` in its payload so a HAVEN surface can gate
/// its own popup). This dispatcher handles the OS-level notification through a
/// fixed, allowlisted, local-only AppleScript — the same sandboxed path the rest
/// of the agent uses for automation. Delivery is gated by `notificationsEnabled`;
/// the audit flow still fires when muted.
public struct NetworkAlertNotificationDispatcher: Sendable {
    public static let notificationScriptID = "haven.network-sentinel.display-notification"

    private let runner: AppleScriptRunner
    private let policy: AutomationPolicy

    public init(runner: AppleScriptRunner = AppleScriptRunner()) {
        self.runner = runner
        self.policy = Self.makePolicy()
    }

    public func handle(snapshot: NetworkHealthSnapshot, transition: NetworkFloodEvent?) async {
        guard let event = transition, snapshot.notificationsEnabled else { return }

        let title: String
        let message: String
        switch event.phase {
        case .started:
            // Purpose gate: only interrupt the operator when the flood actually puts
            // the network-health goal at risk. A benign saturation (e.g. a large
            // download) evaluates as `satisfied` and is intentionally NOT shown.
            let evaluation = NetworkHealthPurposeCatalog.evaluate(snapshot: snapshot, transition: transition)
            guard NetworkHealthPurposeCatalog.warrantsNotification(evaluation) else { return }
            title = "Nettverk: mulig flooding (\(event.classification.rawValue))"
            message = event.summary
        case .resolved:
            // Only announce resolution for a harmful flood we would have alerted on.
            guard NetworkHealthPurposeCatalog.isHarmful(event.classification) else { return }
            title = "Nettverk normalisert"
            message = "Hendelsen er over (\(event.classification.rawValue))."
        case .ongoing:
            return
        }

        let invocation = AppleScriptInvocation(
            id: Self.notificationScriptID,
            origin: .local,
            arguments: [
                "title": Self.sanitize(title),
                "message": Self.sanitize(message)
            ]
        )
        _ = try? await runner.run(invocation, policy: policy)
    }

    private static func sanitize(_ value: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return String(collapsed.prefix(200))
    }

    private static func makePolicy() -> AutomationPolicy {
        let source = """
        on run argv
            if (count of argv) is less than 2 then error "Expected title and message"
            set theTitle to item 1 of argv
            set theMessage to item 2 of argv
            display notification theMessage with title theTitle
        end run
        """
        let constraint = StringConstraint(required: true, maxLength: 256, allowedValues: [], pattern: nil)
        return AutomationPolicy(appleScripts: [
            AppleScriptDefinition(
                id: notificationScriptID,
                description: "Display a local macOS notification for a network flood alert.",
                source: source,
                argumentOrder: ["title", "message"],
                argumentConstraints: ["title": constraint, "message": constraint],
                allowedForRemoteExecution: false,
                requiresUserSession: true
            )
        ])
    }
}
