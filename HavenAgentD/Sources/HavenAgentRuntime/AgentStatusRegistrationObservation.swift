import Foundation
import HavenMacAutomation

public struct AgentStatusRegistrationObservation: Codable, Equatable, Sendable {
    public static let schema = "haven.agentd-registration-observation.v1"
    public static let evidenceKind = "haven-agentd.status-json"
    public static let evidenceAuthority = "owner-reported-runtime-observation-not-a-grant"

    public var schema: String
    public var status: String
    public var evidenceKind: String
    public var availableActionIDs: [String]
    public var bridgeEndpoint: String?
    public var observedAt: String
    public var evidenceAuthority: String
    public var containsAccessToken: Bool

    public init(
        status: String,
        availableActionIDs: [String],
        bridgeEndpoint: String?,
        observedAt: String
    ) {
        self.schema = Self.schema
        self.status = status
        self.evidenceKind = Self.evidenceKind
        self.availableActionIDs = availableActionIDs
        self.bridgeEndpoint = bridgeEndpoint
        self.observedAt = observedAt
        self.evidenceAuthority = Self.evidenceAuthority
        self.containsAccessToken = false
    }
}

public enum AgentStatusRegistrationObservationBuilder {
    public static let brokerActionIDs = [
        "mac.finder.close-all-windows",
        "shortcut.binding.wake",
        "binding.absorb.cell-input",
        "folder-watch.changed-input",
        "sprout.sync.local-agent"
    ]

    public static func make(
        config: AgentConfig?,
        controlBridge: AgentStatusControlBridgeReport,
        observedAt: Date = Date()
    ) -> AgentStatusRegistrationObservation {
        let bridgeEndpoint = sanitizedLoopbackEndpoint(controlBridge.websocketBaseURL)
        let registered = config != nil
            && controlBridge.configured
            && controlBridge.enabled == true
            && controlBridge.loopbackOnly == true
            && controlBridge.listening
            && bridgeEndpoint != nil

        return AgentStatusRegistrationObservation(
            status: registered ? "registered" : "installed_not_running",
            availableActionIDs: registered ? availableActionIDs(config: config) : [],
            bridgeEndpoint: registered ? bridgeEndpoint : nil,
            observedAt: ISO8601DateFormatter().string(from: observedAt)
        )
    }

    private static func availableActionIDs(config: AgentConfig?) -> [String] {
        guard let config else { return [] }
        let known = Set(brokerActionIDs)
        var available = Set<String>()

        available.formUnion(
            config.automationPolicy.shortcuts
                .filter(\.allowedForRemoteExecution)
                .map(\.id)
                .filter(known.contains)
        )
        available.formUnion(
            config.automationPolicy.appleScripts
                .filter(\.allowedForRemoteExecution)
                .map(\.id)
                .filter(known.contains)
        )

        let routeNames = Set(config.localControlBridge.routes.map(\.name))
        if routeNames.contains("intent-inbox"), routeNames.contains("intent-review") {
            available.insert("binding.absorb.cell-input")
        }
        if config.watchFolders.isEmpty == false {
            available.insert("folder-watch.changed-input")
        }
        if config.scaffold.startupMode != .disabled, config.scaffold.enableLiveResolver {
            available.insert("sprout.sync.local-agent")
        }

        return brokerActionIDs.filter(available.contains)
    }

    private static func sanitizedLoopbackEndpoint(_ raw: String?) -> String? {
        guard let raw,
              var components = URLComponents(string: raw),
              components.scheme == "ws" || components.scheme == "wss",
              Self.isLoopbackHost(components.host),
              components.user == nil,
              components.password == nil,
              components.query == nil else {
            return nil
        }
        components.fragment = nil
        return components.string
    }

    private static func isLoopbackHost(_ host: String?) -> Bool {
        switch host?.lowercased() {
        case "127.0.0.1", "localhost", "::1", "0:0:0:0:0:0:0:1":
            return true
        default:
            return false
        }
    }
}
