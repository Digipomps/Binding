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
}
