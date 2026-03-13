import Foundation

public final class ShortcutRunner: @unchecked Sendable {
    private let processRunner: any ProcessRunning

    public init(processRunner: any ProcessRunning = FoundationProcessRunner()) {
        self.processRunner = processRunner
    }

    public func run(_ invocation: ShortcutInvocation, policy: AutomationPolicy) async throws -> SubprocessResult {
        let authorized = try policy.authorize(invocation)
        var arguments = ["run", authorized.definition.shortcutName]
        if let inputPath = authorized.invocation.inputPath {
            arguments.append(contentsOf: ["--input-path", inputPath])
        }
        if let outputPath = authorized.definition.outputPath {
            arguments.append(contentsOf: ["--output-path", outputPath])
        }
        if let outputType = authorized.definition.outputType {
            arguments.append(contentsOf: ["--output-type", outputType])
        }

        let result = try await processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/shortcuts"),
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
