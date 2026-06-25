import Foundation
@preconcurrency import CellBase
import HavenAgentRuntime
import HavenRuntimeBootstrap

struct AgentOnboardingProvisioningRequestSnapshot: Encodable, Sendable {
    var available: Bool
    var payload: ProvisioningRequest?
    var error: String?
}

struct AgentOnboardingStepStatus: Encodable, Sendable {
    var id: String
    var title: String
    var state: String
    var summary: String
    var command: String?
}

struct AgentOnboardingCellState: Encodable, Sendable {
    var routeName: String
    var targetCellReference: String
    var description: String
    var keypath: String
    var value: AgentOnboardingJSONValue?
    var error: String?
}

struct AgentOnboardingCellsReport: Encodable, Sendable {
    var runtimeSnapshot: AgentCellRuntimeSnapshot?
    var routeStates: [AgentOnboardingCellState]
}

struct AgentOnboardingStatusReport: Encodable {
    var recordedAt: String
    var status: AgentStatusReport
    var bootstrapProbe: BootstrapProbeReport
    var provisioningRequest: AgentOnboardingProvisioningRequestSnapshot
    var steps: [AgentOnboardingStepStatus]
    var cells: AgentOnboardingCellsReport
}

enum AgentOnboardingJSONValue: Encodable, Sendable {
    case null
    case bool(Bool)
    case integer(Int)
    case double(Double)
    case string(String)
    case array([AgentOnboardingJSONValue])
    case object([String: AgentOnboardingJSONValue])

    init(_ value: ValueType) {
        switch value {
        case .null:
            self = .null
        case let .bool(value):
            self = .bool(value)
        case let .number(value), let .integer(value):
            self = .integer(value)
        case let .float(value):
            self = .double(value)
        case let .string(value):
            self = .string(value)
        case let .data(value):
            self = .string(value.base64EncodedString())
        case let .object(value):
            self = .object(value.mapValues { AgentOnboardingJSONValue($0) })
        case let .list(value):
            self = .array(value.map { AgentOnboardingJSONValue($0) })
        default:
            self = Self.encodedFallback(value)
        }
    }

    private static func encodedFallback(_ value: ValueType) -> AgentOnboardingJSONValue {
        guard let data = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: data),
              let converted = AgentOnboardingJSONValue(jsonObject: object) else {
            return .string(String(describing: value))
        }
        return converted
    }

    private init?(jsonObject: Any) {
        switch jsonObject {
        case is NSNull:
            self = .null
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .integer(value)
        case let value as Double:
            self = .double(value)
        case let value as String:
            self = .string(value)
        case let value as [Any]:
            self = .array(value.compactMap { AgentOnboardingJSONValue(jsonObject: $0) })
        case let value as [String: Any]:
            self = .object(value.compactMapValues { AgentOnboardingJSONValue(jsonObject: $0) })
        default:
            return nil
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .integer(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .double(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(value):
            var container = encoder.unkeyedContainer()
            for item in value {
                try container.encode(item)
            }
        case let .object(value):
            var container = encoder.container(keyedBy: AgentOnboardingDynamicCodingKey.self)
            for key in value.keys.sorted() {
                if let item = value[key] {
                    try container.encode(item, forKey: AgentOnboardingDynamicCodingKey(stringValue: key))
                }
            }
        }
    }
}

private struct AgentOnboardingDynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct AgentOnboardingStatusBuilder {
    var paths: RuntimePaths
    var configURL: URL
    var owner: Identity
    var routes: [LocalControlBridgeRoute]
    var runtimeSnapshot: AgentCellRuntimeSnapshot?

    func build() async -> AgentOnboardingStatusReport {
        let statusReport = await StatusService(paths: paths, configURL: configURL).report(
            options: AgentStatusOptions(
                executablePath: Self.executablePath(),
                configPathArgument: configURL.path
            )
        )
        let bootstrapReport = await BootstrapProbeService(paths: paths).probe(
            configURL: configURL,
            runBootstrap: false
        )
        let provisioningRequest = await makeProvisioningRequest()
        let cellStates = await readCellStates()

        return AgentOnboardingStatusReport(
            recordedAt: Self.iso8601String(Date()),
            status: statusReport,
            bootstrapProbe: bootstrapReport,
            provisioningRequest: provisioningRequest,
            steps: Self.steps(
                status: statusReport,
                bootstrapProbe: bootstrapReport
            ),
            cells: AgentOnboardingCellsReport(
                runtimeSnapshot: runtimeSnapshot,
                routeStates: cellStates
            )
        )
    }

    private func makeProvisioningRequest() async -> AgentOnboardingProvisioningRequestSnapshot {
        do {
            let config = try AgentConfig.load(from: configURL)
            guard let descriptor = try await AgentIdentityStore(fileURL: paths.agentIdentityFile)
                .loadExistingDescriptor() else {
                return AgentOnboardingProvisioningRequestSnapshot(
                    available: false,
                    payload: nil,
                    error: "Agent identity is not present yet."
                )
            }
            let request = ProvisioningRequest(
                scaffoldDomain: config.scaffold.domain,
                purposeRef: config.scaffold.purpose,
                interests: config.scaffold.interests,
                agentDid: descriptor.didKey,
                boundAgent: ProvisioningPackBoundAgent(
                    agentIdentityUUID: descriptor.identityUUID,
                    agentPublicKeyBase64URL: descriptor.publicKeyBase64URL
                ),
                instructions: "Send this to the operator. They mint a provisioning pack bound to boundAgent.agentPublicKeyBase64URL, then return it for `haven-agentd provisioning-import`."
            )
            return AgentOnboardingProvisioningRequestSnapshot(
                available: true,
                payload: request,
                error: nil
            )
        } catch {
            return AgentOnboardingProvisioningRequestSnapshot(
                available: false,
                payload: nil,
                error: error.localizedDescription
            )
        }
    }

    private func readCellStates() async -> [AgentOnboardingCellState] {
        guard let resolver = CellBase.defaultCellResolver else {
            return routes.map { route in
                AgentOnboardingCellState(
                    routeName: route.name,
                    targetCellReference: route.targetCellReference,
                    description: route.description,
                    keypath: "state",
                    value: nil,
                    error: "Cell resolver unavailable."
                )
            }
        }

        var states: [AgentOnboardingCellState] = []
        for route in routes {
            let endpoint = Self.endpoint(for: route.targetCellReference)
            do {
                let emit = try await resolver.cellAtEndpoint(endpoint: endpoint, requester: owner)
                guard let meddle = emit as? Meddle else {
                    throw AgentOnboardingStatusError.cellIsNotReadable(endpoint)
                }
                let value = try await meddle.get(keypath: "state", requester: owner)
                states.append(AgentOnboardingCellState(
                    routeName: route.name,
                    targetCellReference: route.targetCellReference,
                    description: route.description,
                    keypath: "state",
                    value: AgentOnboardingJSONValue(value),
                    error: nil
                ))
            } catch {
                states.append(AgentOnboardingCellState(
                    routeName: route.name,
                    targetCellReference: route.targetCellReference,
                    description: route.description,
                    keypath: "state",
                    value: nil,
                    error: error.localizedDescription
                ))
            }
        }
        return states
    }

    private static func endpoint(for reference: String) -> String {
        if reference.hasPrefix("cell://") {
            return reference
        }
        return "cell:///\(reference)"
    }

    private static func steps(
        status: AgentStatusReport,
        bootstrapProbe: BootstrapProbeReport
    ) -> [AgentOnboardingStepStatus] {
        let setupComplete = status.config.present && status.config.valid && status.identity.present
        let provisioningComplete = bootstrapProbe.readyForBootstrap
        let bootstrapComplete = status.bootstrapArtifact?.exists == true

        return [
            AgentOnboardingStepStatus(
                id: "setup",
                title: "Setup",
                state: setupComplete ? "complete" : "active",
                summary: setupComplete
                    ? "Config and local agent identity are present."
                    : "Create the local runtime config and identity.",
                command: setupComplete ? nil : status.nextStep.command
            ),
            AgentOnboardingStepStatus(
                id: "provisioning",
                title: "Provisioning request / import",
                state: provisioningComplete ? "complete" : (setupComplete ? "active" : "blocked"),
                summary: provisioningComplete
                    ? "Provisioning artifacts are installed and valid."
                    : "Copy the provisioning request to the operator, then import the returned pack.",
                command: provisioningComplete ? nil : status.nextStep.command
            ),
            AgentOnboardingStepStatus(
                id: "bootstrap-probe",
                title: "Bootstrap probe",
                state: bootstrapComplete ? "complete" : (provisioningComplete ? "active" : "blocked"),
                summary: bootstrapComplete
                    ? "Bootstrap artifact is present."
                    : "Run the bootstrap probe once provisioning is ready.",
                command: bootstrapComplete ? nil : status.nextStep.command
            )
        ]
    }

    private static func executablePath() -> String {
        if let executableURL = Bundle.main.executableURL {
            return executableURL.resolvingSymlinksInPath().path
        }
        return CommandLine.arguments.first ?? "haven-agentd"
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

enum AgentOnboardingStatusError: Error, LocalizedError {
    case cellIsNotReadable(String)

    var errorDescription: String? {
        switch self {
        case let .cellIsNotReadable(endpoint):
            return "Cell at \(endpoint) does not support read access."
        }
    }
}

enum AgentOnboardingAssetLoader {
    static let productionIndexHTMLPath = "/usr/local/share/havenagent/onboarding/index.html"

    static func loadIndexHTML() throws -> String {
        let candidates = [
            Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Onboarding"),
            Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Resources/Onboarding"),
            URL(fileURLWithPath: productionIndexHTMLPath)
        ].compactMap { $0 }

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return try String(contentsOf: url, encoding: .utf8)
        }

        throw AgentOnboardingAssetError.indexHTMLMissing(
            candidates.map(\.path).joined(separator: ", ")
        )
    }
}

enum AgentOnboardingAssetError: Error, LocalizedError {
    case indexHTMLMissing(String)

    var errorDescription: String? {
        switch self {
        case let .indexHTMLMissing(paths):
            return "Onboarding index.html is missing. Looked in: \(paths)"
        }
    }
}
