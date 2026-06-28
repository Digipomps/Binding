import Testing
@testable import HavenMacAutomation

struct AutomationPolicyTests {
    @Test
    func deniesRemoteExecutionForLocalOnlyShortcut() throws {
        let policy = AutomationPolicy(
            shortcuts: [
                ShortcutDefinition(
                    id: "local-only",
                    shortcutName: "Local Only",
                    acceptsInputPath: false,
                    allowedForRemoteExecution: false
                )
            ]
        )

        do {
            _ = try policy.authorize(
                ShortcutInvocation(id: "local-only", origin: .trustedRemote)
            )
            Issue.record("Expected remote execution to be denied.")
        } catch let error as AutomationPolicyError {
            #expect(error == .remoteExecutionDenied("local-only"))
        }
    }

    @Test
    func deniesUnexpectedAppleScriptArguments() throws {
        let policy = AutomationPolicy(
            appleScripts: [
                AppleScriptDefinition(
                    id: "open-url",
                    description: "Open a URL",
                    source: "on run argv\nreturn argv\nend run",
                    argumentOrder: ["url"],
                    argumentConstraints: [
                        "url": StringConstraint(pattern: #"https://.*"#)
                    ]
                )
            ]
        )

        do {
            _ = try policy.authorize(
                AppleScriptInvocation(
                    id: "open-url",
                    origin: .local,
                    arguments: [
                        "url": "https://example.com",
                        "title": "Extra"
                    ]
                )
            )
            Issue.record("Expected unexpected arguments to be rejected.")
        } catch let error as AutomationPolicyError {
            #expect(error == .unexpectedArgument("title"))
        }
    }

    @Test
    func validatesAppleScriptArgumentPattern() throws {
        let policy = AutomationPolicy(
            appleScripts: [
                AppleScriptDefinition(
                    id: "open-url",
                    description: "Open a URL",
                    source: "on run argv\nreturn argv\nend run",
                    argumentOrder: ["url"],
                    argumentConstraints: [
                        "url": StringConstraint(pattern: #"https://[A-Za-z0-9\.\-/_]+"#)
                    ]
                )
            ]
        )

        do {
            _ = try policy.authorize(
                AppleScriptInvocation(
                    id: "open-url",
                    origin: .local,
                    arguments: ["url": "javascript:alert(1)"]
                )
            )
            Issue.record("Expected invalid argument to be rejected.")
        } catch let error as AutomationPolicyError {
            #expect(error == .invalidArgument("url", "Value does not match expected pattern"))
        }
    }

    @Test
    func allowsNewlinesOnlyWhenConstraintOptsIn() throws {
        let policy = AutomationPolicy(
            appleScripts: [
                AppleScriptDefinition(
                    id: "mail.compose-draft",
                    description: "Prepare email draft.",
                    source: "on run argv\nreturn argv\nend run",
                    argumentOrder: ["body"],
                    argumentConstraints: [
                        "body": StringConstraint(maxLength: 500, allowsNewlines: true)
                    ],
                    allowedForRemoteExecution: true
                ),
                AppleScriptDefinition(
                    id: "single-line",
                    description: "Single line only.",
                    source: "on run argv\nreturn argv\nend run",
                    argumentOrder: ["body"],
                    argumentConstraints: [
                        "body": StringConstraint(maxLength: 500)
                    ]
                )
            ]
        )

        let authorized = try policy.authorize(
            AppleScriptInvocation(
                id: "mail.compose-draft",
                origin: .trustedRemote,
                arguments: ["body": "Line 1\nLine 2"]
            )
        )
        #expect(authorized.orderedArgumentValues == ["Line 1\nLine 2"])

        do {
            _ = try policy.authorize(
                AppleScriptInvocation(
                    id: "single-line",
                    origin: .local,
                    arguments: ["body": "Line 1\nLine 2"]
                )
            )
            Issue.record("Expected newline to be denied for default StringConstraint.")
        } catch let error as AutomationPolicyError {
            #expect(error == .invalidArgument("body", "Value contains a newline"))
        }
    }
}
