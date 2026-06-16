import Foundation
@preconcurrency import CellBase
import Darwin
import Testing
@testable import HavenAgentCellRuntime
@testable import HavenAgentCells
@testable import HavenAgentRuntime
@testable import HavenRuntimeBootstrap

@Suite(.serialized)
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
            remoteIntentStateFile: root.appendingPathComponent("Library/Application Support/HAVENAgent/State/remote-intent-state.json"),
            agentIdentityFile: root.appendingPathComponent("Library/Application Support/HAVENAgent/State/agent-identity.json"),
            pairingArtifactFile: root.appendingPathComponent("Library/Application Support/HAVENAgent/Out/agent-enrollment-pairing.json")
        )

        let host = AgentCellRuntimeHost(paths: paths)
        let snapshot = try await host.start(instanceName: "agent")

        #expect(snapshot.status == "running")
        #expect(snapshot.cells.count == AgentCellRegistry.concreteDescriptors.count)
        #expect(snapshot.cells.map(\.endpoint) == AgentCellRegistry.concreteDescriptors.map(\.endpoint))
        #expect(FileManager.default.fileExists(atPath: paths.cellRuntimeFile.path))
        #expect(CellBase.documentRootPath == paths.cellDocumentDirectory.path)
        #expect(CellResolver.sharedInstance.registeredTransportSchemesSnapshot().contains("ws"))
        #expect(CellResolver.sharedInstance.registeredTransportSchemesSnapshot().contains("wss"))

        let requester = Identity(snapshot.ownerUUID, displayName: snapshot.ownerDisplayName, identityVault: CellBase.defaultIdentityVault)
        let cell = try await CellResolver.sharedInstance.cellAtEndpoint(
            endpoint: "cell:///agent/supervisor",
            requester: requester
        )
        #expect(cell is AgentSupervisorCell)
        let localModelCell = try await CellResolver.sharedInstance.cellAtEndpoint(
            endpoint: "cell:///agent/local-model",
            requester: requester
        )
        #expect(localModelCell is AgentLocalModelCell)

        await host.stop()
        let stoppedSnapshot = await host.snapshot()
        #expect(stoppedSnapshot?.status == "stopped")
        #expect(stoppedSnapshot?.cells.isEmpty == true)
        #expect(CellBase.documentRootPath == nil)
    }

    @Test
    func hostExposesAgentSupervisorOverLocalControlBridge() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.documentRootPath = nil

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentDBridgeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let host = AgentCellRuntimeHost(paths: paths)
        let bridgePort = try Self.allocateLoopbackPort()
        let bridgeConfiguration = LocalControlBridgeConfig(
            host: "127.0.0.1",
            port: bridgePort,
            accessToken: "local-test-token"
        )
        let snapshot = try await host.start(instanceName: "agent", controlBridge: bridgeConfiguration)

        #expect(snapshot.controlBridge?.phase == .running)
        #expect(snapshot.controlBridge?.port == bridgePort)

        guard let controlBridge = snapshot.controlBridge else {
            Issue.record("Failed to reach AgentSupervisor over the local control bridge.")
            await host.stop()
            return
        }

        let publicBridgeEndpoint = controlBridge.endpoint(for: "agent-supervisor")
        guard Self.authorizedEndpoint(
                baseEndpoint: publicBridgeEndpoint,
                accessToken: bridgeConfiguration.accessToken ?? ""
              ) != nil else {
            Issue.record("Failed to reach AgentSupervisor over the local control bridge.")
            await host.stop()
            return
        }

        let unauthorizedHealthURL = URL(string: "http://\(controlBridge.host):\(controlBridge.port)/health")!
        let unauthorizedStatus = try await Self.fetchHTTPStatus(unauthorizedHealthURL)
        #expect(unauthorizedStatus == 401)
        let authorizedHealthURL = URL(string: "http://\(controlBridge.host):\(controlBridge.port)/health?token=\(bridgeConfiguration.accessToken ?? "")")!
        let authorizedStatus = try await Self.fetchHTTPStatus(authorizedHealthURL)
        #expect(authorizedStatus == 200)
        await host.stop()
    }

    @Test
    func hostRejectsNonLoopbackControlBridgeBinding() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.documentRootPath = nil

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HavenAgentDBridgeLoopbackTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = RuntimePaths.rooted(at: root)
        let host = AgentCellRuntimeHost(paths: paths)
        let snapshot = try await host.start(
            instanceName: "agent",
            controlBridge: LocalControlBridgeConfig(host: "0.0.0.0", port: 43110, accessToken: "loopback-test-token")
        )

        #expect(snapshot.controlBridge?.phase == .failed)
        #expect(snapshot.controlBridge?.lastError?.contains("not loopback-only") == true)
        await host.stop()
    }

    private static func allocateLoopbackPort() throws -> Int {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        #expect(descriptor >= 0)
        defer { close(descriptor) }

        var value: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        #expect(bindResult == 0)

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &length)
            }
        }
        #expect(nameResult == 0)
        return Int(UInt16(bigEndian: boundAddress.sin_port))
    }

    private static func authorizedEndpoint(baseEndpoint: String, accessToken: String) -> URL? {
        guard var components = URLComponents(string: baseEndpoint) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "token", value: accessToken)
        ]
        return components.url
    }

    private static func fetchHTTPStatus(_ url: URL) async throws -> Int {
        let (_, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AgentCellRuntimeHostTests", code: 2)
        }
        return httpResponse.statusCode
    }
}
