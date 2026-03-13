import Foundation

public final class AppleScriptRunner: @unchecked Sendable {
    private let processRunner: any ProcessRunning

    public init(processRunner: any ProcessRunning = FoundationProcessRunner()) {
        self.processRunner = processRunner
    }

    public func run(_ invocation: AppleScriptInvocation, policy: AutomationPolicy) async throws -> SubprocessResult {
        let authorized = try policy.authorize(invocation)
        var arguments = ["-l", "AppleScript", "-e", authorized.definition.source]
        if !authorized.orderedArgumentValues.isEmpty {
            arguments.append("--")
            arguments.append(contentsOf: authorized.orderedArgumentValues)
        }

        let result = try await processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: arguments
        )
        guard result.succeeded else {
            throw SubprocessError.commandFailed(
                command: result.command,
                status: result.terminationStatus,
                standardError: result.standardError
            )
        }
        return result
    }
}
