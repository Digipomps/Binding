import Foundation
import SproutAppSupport
import SproutCore

public struct SproutBootstrapSessionArtifact: Equatable, Sendable {
    public var artifactPath: String
    public var context: BootstrapExecutionContext
    public var session: PortholeClientSession

    public init(
        artifactPath: String,
        context: BootstrapExecutionContext,
        session: PortholeClientSession
    ) {
        self.artifactPath = artifactPath
        self.context = context
        self.session = session
    }
}

public enum SproutBootstrapArtifactLoaderError: Error, LocalizedError, Equatable, Sendable {
    case missingArtifactPath
    case missingPortholeAccessContract(String)
    case unsupportedSessionMode(String)

    public var errorDescription: String? {
        switch self {
        case .missingArtifactPath:
            return "Sprout bootstrap artifact path is missing."
        case .missingPortholeAccessContract(let path):
            return "Sprout bootstrap artifact does not contain a porthole access contract: \(path)"
        case .unsupportedSessionMode(let mode):
            return "Sprout bootstrap artifact is not a native porthole session: \(mode)"
        }
    }
}

public enum SproutBootstrapArtifactLoader {
    public static func loadNativeSession(
        from artifactPath: String?,
        now: Date = Date()
    ) throws -> SproutBootstrapSessionArtifact {
        guard let artifactPath, !artifactPath.isEmpty else {
            throw SproutBootstrapArtifactLoaderError.missingArtifactPath
        }

        let resolvedPath = NSString(string: artifactPath).expandingTildeInPath
        let artifactURL = URL(fileURLWithPath: resolvedPath)
        let data = try Data(contentsOf: artifactURL)
        let context = try JSONDecoder().decode(BootstrapExecutionContext.self, from: data)

        guard let contract = context.portholeAccessContract else {
            throw SproutBootstrapArtifactLoaderError.missingPortholeAccessContract(resolvedPath)
        }

        let session = try PortholeClientSession.fromContract(contract, now: now)
        guard session.mode == .native else {
            throw SproutBootstrapArtifactLoaderError.unsupportedSessionMode(session.mode.rawValue)
        }

        return SproutBootstrapSessionArtifact(
            artifactPath: resolvedPath,
            context: context,
            session: session
        )
    }
}
