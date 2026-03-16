import Foundation

public struct RuntimePaths: Equatable, Sendable {
    public var homeDirectory: URL
    public var applicationSupportDirectory: URL
    public var agentDirectory: URL
    public var stateDirectory: URL
    public var cellDocumentDirectory: URL
    public var logsDirectory: URL
    public var inboxDirectory: URL
    public var outputDirectory: URL
    public var configFile: URL
    public var stateFile: URL
    public var cellRuntimeFile: URL
    public var remoteIntentStateFile: URL
    public var agentIdentityFile: URL
    public var pairingArtifactFile: URL

    public init(
        homeDirectory: URL,
        applicationSupportDirectory: URL,
        agentDirectory: URL,
        stateDirectory: URL,
        cellDocumentDirectory: URL,
        logsDirectory: URL,
        inboxDirectory: URL,
        outputDirectory: URL,
        configFile: URL,
        stateFile: URL,
        cellRuntimeFile: URL,
        remoteIntentStateFile: URL,
        agentIdentityFile: URL,
        pairingArtifactFile: URL
    ) {
        self.homeDirectory = homeDirectory
        self.applicationSupportDirectory = applicationSupportDirectory
        self.agentDirectory = agentDirectory
        self.stateDirectory = stateDirectory
        self.cellDocumentDirectory = cellDocumentDirectory
        self.logsDirectory = logsDirectory
        self.inboxDirectory = inboxDirectory
        self.outputDirectory = outputDirectory
        self.configFile = configFile
        self.stateFile = stateFile
        self.cellRuntimeFile = cellRuntimeFile
        self.remoteIntentStateFile = remoteIntentStateFile
        self.agentIdentityFile = agentIdentityFile
        self.pairingArtifactFile = pairingArtifactFile
    }

    public static func `default`(fileManager: FileManager = .default) throws -> RuntimePaths {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let applicationSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let agentDirectory = applicationSupportDirectory.appendingPathComponent("HAVENAgent", isDirectory: true)
        let stateDirectory = agentDirectory.appendingPathComponent("State", isDirectory: true)
        let cellDocumentDirectory = agentDirectory.appendingPathComponent("CellDocuments", isDirectory: true)
        let logsDirectory = agentDirectory.appendingPathComponent("Logs", isDirectory: true)
        let inboxDirectory = agentDirectory.appendingPathComponent("Inbox", isDirectory: true)
        let outputDirectory = agentDirectory.appendingPathComponent("Out", isDirectory: true)
        return RuntimePaths(
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory,
            agentDirectory: agentDirectory,
            stateDirectory: stateDirectory,
            cellDocumentDirectory: cellDocumentDirectory,
            logsDirectory: logsDirectory,
            inboxDirectory: inboxDirectory,
            outputDirectory: outputDirectory,
            configFile: agentDirectory.appendingPathComponent("config.json"),
            stateFile: stateDirectory.appendingPathComponent("agent-state.json"),
            cellRuntimeFile: stateDirectory.appendingPathComponent("cell-runtime.json"),
            remoteIntentStateFile: stateDirectory.appendingPathComponent("remote-intent-state.json"),
            agentIdentityFile: stateDirectory.appendingPathComponent("agent-identity.json"),
            pairingArtifactFile: outputDirectory.appendingPathComponent("agent-enrollment-pairing.json")
        )
    }

    public static func rooted(at rootDirectory: URL) -> RuntimePaths {
        let rootDirectory = rootDirectory.standardizedFileURL
        let agentDirectory = rootDirectory.appendingPathComponent("HAVENAgent", isDirectory: true)
        let stateDirectory = agentDirectory.appendingPathComponent("State", isDirectory: true)
        let cellDocumentDirectory = agentDirectory.appendingPathComponent("CellDocuments", isDirectory: true)
        let logsDirectory = agentDirectory.appendingPathComponent("Logs", isDirectory: true)
        let inboxDirectory = agentDirectory.appendingPathComponent("Inbox", isDirectory: true)
        let outputDirectory = agentDirectory.appendingPathComponent("Out", isDirectory: true)

        return RuntimePaths(
            homeDirectory: rootDirectory,
            applicationSupportDirectory: rootDirectory,
            agentDirectory: agentDirectory,
            stateDirectory: stateDirectory,
            cellDocumentDirectory: cellDocumentDirectory,
            logsDirectory: logsDirectory,
            inboxDirectory: inboxDirectory,
            outputDirectory: outputDirectory,
            configFile: agentDirectory.appendingPathComponent("config.json"),
            stateFile: stateDirectory.appendingPathComponent("agent-state.json"),
            cellRuntimeFile: stateDirectory.appendingPathComponent("cell-runtime.json"),
            remoteIntentStateFile: stateDirectory.appendingPathComponent("remote-intent-state.json"),
            agentIdentityFile: stateDirectory.appendingPathComponent("agent-identity.json"),
            pairingArtifactFile: outputDirectory.appendingPathComponent("agent-enrollment-pairing.json")
        )
    }
}
