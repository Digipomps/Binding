import Foundation

public struct SproutBootstrapPlan: Codable, Equatable, Sendable {
    public var scaffoldDomain: String
    public var requestedPortholeKind: String
    public var requestedCapabilities: [String]
    public var resolverBaseURL: String?
    public var starterAuthPath: String?
    public var entityLinkPath: String?
    public var continuityProofPath: String?
    public var admissionContractPath: String?
    public var renewalLeadTimeSeconds: Int

    public init(
        scaffoldDomain: String,
        requestedPortholeKind: String,
        requestedCapabilities: [String],
        resolverBaseURL: String?,
        starterAuthPath: String?,
        entityLinkPath: String?,
        continuityProofPath: String?,
        admissionContractPath: String?,
        renewalLeadTimeSeconds: Int
    ) {
        self.scaffoldDomain = scaffoldDomain
        self.requestedPortholeKind = requestedPortholeKind
        self.requestedCapabilities = requestedCapabilities
        self.resolverBaseURL = resolverBaseURL
        self.starterAuthPath = starterAuthPath
        self.entityLinkPath = entityLinkPath
        self.continuityProofPath = continuityProofPath
        self.admissionContractPath = admissionContractPath
        self.renewalLeadTimeSeconds = renewalLeadTimeSeconds
    }
}

public struct RuntimeBootstrapContext: Equatable, Sendable {
    public var paths: RuntimePaths
    public var createdDirectories: [String]

    public init(paths: RuntimePaths, createdDirectories: [String]) {
        self.paths = paths
        self.createdDirectories = createdDirectories
    }
}

public final class RuntimeBootstrap {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func bootstrap(paths: RuntimePaths) throws -> RuntimeBootstrapContext {
        let directories = [
            paths.agentDirectory,
            paths.stateDirectory,
            paths.cellDocumentDirectory,
            paths.logsDirectory,
            paths.inboxDirectory,
            paths.outputDirectory
        ]

        var createdDirectories: [String] = []
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                createdDirectories.append(directory.path)
            }
        }

        return RuntimeBootstrapContext(paths: paths, createdDirectories: createdDirectories)
    }
}
