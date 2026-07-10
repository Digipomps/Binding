import Foundation

public final class LocalTaskRunner: @unchecked Sendable {
    private let processRunner: any ProcessRunning

    public init(processRunner: any ProcessRunning = FoundationProcessRunner()) {
        self.processRunner = processRunner
    }

    public func run(_ invocation: LocalTaskInvocation, policy: AutomationPolicy) async throws -> SubprocessResult {
        let definition = try policy.authorize(invocation)
        let result = try await processRunner.run(
            executableURL: URL(fileURLWithPath: definition.executablePath),
            arguments: definition.arguments
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
