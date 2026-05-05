import Foundation
import HavenMacAutomation
import HavenRuntimeBootstrap

public enum SproutStartupMode: String, Codable, Equatable, Sendable {
    case disabled
    case plan
    case join
}

public struct SproutBootstrapInvocation: Equatable, Sendable {
    public var executablePath: String
    public var mode: SproutStartupMode
    public var arguments: [String]
    public var artifactPath: String?

    public init(
        executablePath: String,
        mode: SproutStartupMode,
        arguments: [String],
        artifactPath: String?
    ) {
        self.executablePath = executablePath
        self.mode = mode
        self.arguments = arguments
        self.artifactPath = artifactPath
    }
}

public struct SproutBootstrapInvocationRecord: Codable, Equatable, Sendable {
    public var mode: SproutStartupMode
    public var executablePath: String
    public var commandArguments: [String]
    public var artifactPath: String?
    public var finalState: String?
    public var resultSummary: String
    public var recordedAt: String

    public init(
        mode: SproutStartupMode,
        executablePath: String,
        commandArguments: [String],
        artifactPath: String?,
        finalState: String?,
        resultSummary: String,
        recordedAt: String
    ) {
        self.mode = mode
        self.executablePath = executablePath
        self.commandArguments = commandArguments
        self.artifactPath = artifactPath
        self.finalState = finalState
        self.resultSummary = resultSummary
        self.recordedAt = recordedAt
    }
}

public enum SproutBootstrapClientError: Error, Equatable, Sendable, LocalizedError {
    case missingPurposeGoalInterests
    case missingResolverBaseURL
    case invalidBinaryPath(String)
    case binaryNotExecutable(String)
    case conflictingEntityEvidence

    public var errorDescription: String? {
        switch self {
        case .missingPurposeGoalInterests:
            return "Sprout bootstrap requires explicit purpose, goal and interests."
        case .missingResolverBaseURL:
            return "enableLiveResolver requires resolverBaseURL."
        case .invalidBinaryPath(let path):
            return "Sprout binary path must be absolute and point to a local executable: \(path)"
        case .binaryNotExecutable(let path):
            return "Sprout binary is not executable: \(path)"
        case .conflictingEntityEvidence:
            return "Configure either entity-link evidence or admission-contract evidence, not both."
        }
    }
}

public final class SproutBootstrapClient: @unchecked Sendable {
    private let processRunner: any ProcessRunning
    private let fileManager: FileManager

    public init(
        processRunner: any ProcessRunning = FoundationProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.processRunner = processRunner
        self.fileManager = fileManager
    }

    public func makeInvocation(config: AgentConfig, paths: RuntimePaths) throws -> SproutBootstrapInvocation? {
        let scaffold = config.scaffold
        guard scaffold.startupMode != .disabled else {
            return nil
        }
        guard let purpose = scaffold.purpose,
              let goal = scaffold.goal,
              !scaffold.interests.isEmpty else {
            throw SproutBootstrapClientError.missingPurposeGoalInterests
        }
        if scaffold.enableLiveResolver && scaffold.resolverBaseURL == nil {
            throw SproutBootstrapClientError.missingResolverBaseURL
        }
        if scaffold.entityLinkPath != nil &&
            (scaffold.admissionContractPath != nil || scaffold.continuityProofPath != nil) {
            throw SproutBootstrapClientError.conflictingEntityEvidence
        }
        if scaffold.continuityProofPath != nil && scaffold.admissionContractPath == nil {
            throw SproutBootstrapClientError.conflictingEntityEvidence
        }

        let executablePath = try expandAndValidateExecutablePath(scaffold.sproutBinaryPath, validateExistence: false)
        let subcommand = scaffold.startupMode == .plan ? "plan" : "join"
        let artifactPath: String? = {
            switch scaffold.startupMode {
            case .disabled:
                return nil
            case .plan:
                return paths.stateDirectory.appendingPathComponent("sprout-bootstrap-plan.json").path
            case .join:
                return paths.stateDirectory.appendingPathComponent("sprout-bootstrap-state.json").path
            }
        }()

        var arguments = [
            "bootstrap",
            subcommand,
            "--domain", scaffold.domain,
            "--runtime", scaffold.runtime,
            "--purpose", purpose,
            "--goal", goal,
            "--interests", scaffold.interests.joined(separator: ","),
            "--porthole", scaffold.requestedPortholeKind
        ]

        if let starterAuthPath = scaffold.starterAuthPath {
            arguments.append(contentsOf: ["--starter", expandPath(starterAuthPath)])
        }
        if let entityLinkPath = scaffold.entityLinkPath {
            arguments.append(contentsOf: ["--entity-link", expandPath(entityLinkPath)])
        }
        if let admissionContractPath = scaffold.admissionContractPath {
            arguments.append(contentsOf: ["--admission-contract", expandPath(admissionContractPath)])
        }
        if let continuityProofPath = scaffold.continuityProofPath {
            arguments.append(contentsOf: ["--continuity-proof", expandPath(continuityProofPath)])
        }
        if let discoveryURL = scaffold.discoveryURL {
            arguments.append(contentsOf: ["--discovery-url", discoveryURL])
        }
        if let catalogPath = scaffold.catalogPath {
            arguments.append(contentsOf: ["--catalog", expandPath(catalogPath)])
        }
        if scaffold.enableLiveResolver {
            arguments.append("--enable-live-resolver")
            arguments.append(contentsOf: ["--resolver-base-url", scaffold.resolverBaseURL!])
        }
        if let trustedResolverKey = scaffold.trustedResolverKey {
            arguments.append(contentsOf: ["--trusted-resolver-key", trustedResolverKey])
        }
        arguments.append(contentsOf: [
            "--trust-root-out",
            paths.stateDirectory.appendingPathComponent("scaffold-admin-trust-root.json").path
        ])
        if let artifactPath {
            if scaffold.startupMode == .plan {
                arguments.append(contentsOf: ["--out", artifactPath])
            } else {
                arguments.append(contentsOf: ["--state-out", artifactPath])
            }
        }

        return SproutBootstrapInvocation(
            executablePath: executablePath,
            mode: scaffold.startupMode,
            arguments: arguments,
            artifactPath: artifactPath
        )
    }

    public func run(config: AgentConfig, paths: RuntimePaths) async throws -> SproutBootstrapInvocationRecord? {
        guard let invocation = try makeInvocation(config: config, paths: paths) else {
            return nil
        }

        let executablePath = try expandAndValidateExecutablePath(invocation.executablePath, validateExistence: true)
        let result = try await processRunner.run(
            executableURL: URL(fileURLWithPath: executablePath),
            arguments: invocation.arguments
        )
        guard result.succeeded else {
            throw SubprocessError.commandFailed(
                command: result.command,
                status: result.terminationStatus,
                standardError: result.standardError
            )
        }

        let summarySource: String = {
            if invocation.mode == .plan,
               let artifactPath = invocation.artifactPath,
               let data = fileManager.contents(atPath: artifactPath),
               let string = String(data: data, encoding: .utf8),
               !string.isEmpty {
                return string
            }
            if !result.standardOutput.isEmpty {
                return result.standardOutput
            }
            return result.standardError
        }()

        return SproutBootstrapInvocationRecord(
            mode: invocation.mode,
            executablePath: executablePath,
            commandArguments: invocation.arguments,
            artifactPath: invocation.artifactPath,
            finalState: extractStringValue(for: "final_state", from: summarySource),
            resultSummary: String(summarySource.prefix(4000)),
            recordedAt: Self.iso8601String(Date())
        )
    }

    private func expandAndValidateExecutablePath(_ rawPath: String, validateExistence: Bool) throws -> String {
        let expanded = expandPath(rawPath)
        guard expanded.hasPrefix("/") else {
            throw SproutBootstrapClientError.invalidBinaryPath(rawPath)
        }
        if validateExistence && !fileManager.isExecutableFile(atPath: expanded) {
            throw SproutBootstrapClientError.binaryNotExecutable(expanded)
        }
        return expanded
    }

    private func expandPath(_ rawPath: String) -> String {
        NSString(string: rawPath).expandingTildeInPath
    }

    private func extractStringValue(for key: String, from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json[key] as? String
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
