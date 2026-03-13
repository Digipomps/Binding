import Foundation
@preconcurrency import CellBase
import Testing
@testable import HavenAgentCellRuntime
@testable import HavenAgentCells
@testable import HavenRuntimeBootstrap

struct AgentCellRuntimeHostTests {
    @Test
    func hostRegistersConcreteCellsIntoResolverAndWritesSnapshot() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.documentRootPath = nil

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentDTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths(
            homeDirectory: root,
            applicationSupportDirectory: root.appendingPathComponent("Library/Application Support", isDirectory: true),
            agentDirectory: root.appendingPathComponent("Library/Application Support/HAVENAgent", isDirectory: true),
            stateDirectory: root.appendingPathComponent("Library/Application Support/HAVENAgent/State", isDirectory: true),
            cellDocumentDirectory: root.appendingPathComponent("Library/Application Support/HAVENAgent/CellDocuments", isDirectory: true),
            logsDirectory: root.appendingPathComponent("Library/Application Support/HAVENAgent/Logs", isDirectory: true),
            inboxDirectory: root.appendingPathComponent("Library/Application Support/HAVENAgent/Inbox", isDirectory: true),
            outputDirectory: root.appendingPathComponent("Library/Application Support/HAVENAgent/Out", isDirectory: true),
            configFile: root.appendingPathComponent("Library/Application Support/HAVENAgent/config.json"),
            stateFile: root.appendingPathComponent("Library/Application Support/HAVENAgent/State/agent-state.json"),
            cellRuntimeFile: root.appendingPathComponent("Library/Application Support/HAVENAgent/State/cell-runtime.json"),
            remoteIntentStateFile: root.appendingPathComponent("Library/Application Support/HAVENAgent/State/remote-intent-state.json")
        )

        let host = AgentCellRuntimeHost(paths: paths)
        let snapshot = try await host.start(instanceName: "agent")

        #expect(snapshot.status == "running")
        #expect(snapshot.cells.count == 3)
        #expect(snapshot.cells.map(\.endpoint) == AgentCellRegistry.concreteDescriptors.map(\.endpoint))
        #expect(FileManager.default.fileExists(atPath: paths.cellRuntimeFile.path))
        #expect(CellBase.documentRootPath == paths.cellDocumentDirectory.path)

        let requester = Identity(snapshot.ownerUUID, displayName: snapshot.ownerDisplayName, identityVault: CellBase.defaultIdentityVault)
        let cell = try await CellResolver.sharedInstance.cellAtEndpoint(
            endpoint: "cell:///agent/supervisor",
            requester: requester
        )
        #expect(cell is AgentSupervisorCell)

        await host.stop()
        let stoppedSnapshot = await host.snapshot()
        #expect(stoppedSnapshot?.status == "stopped")
        #expect(stoppedSnapshot?.cells.isEmpty == true)
        #expect(CellBase.documentRootPath == nil)
    }
}
