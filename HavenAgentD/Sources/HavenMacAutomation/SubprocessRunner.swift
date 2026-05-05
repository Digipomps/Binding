import Foundation

public struct SubprocessResult: Equatable, Sendable {
    public var command: [String]
    public var terminationStatus: Int32
    public var standardOutput: String
    public var standardError: String

    public var succeeded: Bool {
        terminationStatus == 0
    }

    public init(
        command: [String],
        terminationStatus: Int32,
        standardOutput: String,
        standardError: String
    ) {
        self.command = command
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum SubprocessError: Error, Equatable, Sendable, LocalizedError {
    case launchFailed(String)
    case commandFailed(command: [String], status: Int32, standardError: String)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            return "Failed to launch subprocess: \(message)"
        case .commandFailed(let command, let status, let standardError):
            let renderedCommand = command.joined(separator: " ")
            if standardError.isEmpty {
                return "Command failed with status \(status): \(renderedCommand)"
            }
            return "Command failed with status \(status): \(renderedCommand)\n\(standardError)"
        }
    }
}

public protocol ProcessRunning: Sendable {
    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult
}

public struct FoundationProcessRunner: ProcessRunning {
    public init() {}

    public func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let result = SubprocessResult(
                    command: [executableURL.path] + arguments,
                    terminationStatus: process.terminationStatus,
                    standardOutput: String(decoding: stdoutData, as: UTF8.self),
                    standardError: String(decoding: stderrData, as: UTF8.self)
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: SubprocessError.launchFailed(error.localizedDescription))
            }
        }
    }
}
