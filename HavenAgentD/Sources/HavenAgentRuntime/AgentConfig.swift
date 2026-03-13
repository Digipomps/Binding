import Foundation
import HavenMacAutomation
import HavenRuntimeBootstrap

public enum AutomationActionKind: String, Codable, Equatable, Sendable {
    case shortcut
    case appleScript
}

public struct AutomationActionRequest: Codable, Equatable, Sendable {
    public var kind: AutomationActionKind
    public var id: String
    public var inputPath: String?
    public var arguments: [String: String]

    public init(
        kind: AutomationActionKind,
        id: String,
        inputPath: String? = nil,
        arguments: [String: String] = [:]
    ) {
        self.kind = kind
        self.id = id
        self.inputPath = inputPath
        self.arguments = arguments
    }
}

public enum FolderWatchEventName: String, Codable, CaseIterable, Sendable {
    case write
    case delete
    case extend
    case attrib
    case link
    case rename
    case revoke
}

public struct WatchFolderConfig: Codable, Equatable, Sendable {
    public var id: String
    public var path: String
    public var topic: String
    public var events: [FolderWatchEventName]
    public var actions: [AutomationActionRequest]

    public init(
        id: String,
        path: String,
        topic: String,
        events: [FolderWatchEventName],
        actions: [AutomationActionRequest]
    ) {
        self.id = id
        self.path = path
        self.topic = topic
        self.events = events
        self.actions = actions
    }
}

public struct ScaffoldConnectionConfig: Codable, Equatable, Sendable {
    public var sproutBinaryPath: String
    public var startupMode: SproutStartupMode
    public var runtime: String
    public var domain: String
    public var purpose: String?
    public var goal: String?
    public var interests: [String]
    public var resolverBaseURL: String?
    public var starterAuthPath: String?
    public var discoveryURL: String?
    public var catalogPath: String?
    public var enableLiveResolver: Bool
    public var trustedResolverKey: String?
    public var requestedCapabilities: [String]
    public var requestedPortholeKind: String
    public var renewalLeadTimeSeconds: Int
    public var portholeHealthPollSeconds: Int
    public var portholeRetryBaseDelaySeconds: Int
    public var portholeRetryMaxDelaySeconds: Int

    public init(
        sproutBinaryPath: String,
        startupMode: SproutStartupMode = .disabled,
        runtime: String = "mac-agent",
        domain: String,
        purpose: String? = nil,
        goal: String? = nil,
        interests: [String] = [],
        resolverBaseURL: String? = nil,
        starterAuthPath: String? = nil,
        discoveryURL: String? = nil,
        catalogPath: String? = nil,
        enableLiveResolver: Bool = false,
        trustedResolverKey: String? = nil,
        requestedCapabilities: [String],
        requestedPortholeKind: String = "native",
        renewalLeadTimeSeconds: Int = 900,
        portholeHealthPollSeconds: Int = 5,
        portholeRetryBaseDelaySeconds: Int = 5,
        portholeRetryMaxDelaySeconds: Int = 60
    ) {
        self.sproutBinaryPath = sproutBinaryPath
        self.startupMode = startupMode
        self.runtime = runtime
        self.domain = domain
        self.purpose = purpose
        self.goal = goal
        self.interests = interests
        self.resolverBaseURL = resolverBaseURL
        self.starterAuthPath = starterAuthPath
        self.discoveryURL = discoveryURL
        self.catalogPath = catalogPath
        self.enableLiveResolver = enableLiveResolver
        self.trustedResolverKey = trustedResolverKey
        self.requestedCapabilities = requestedCapabilities
        self.requestedPortholeKind = requestedPortholeKind
        self.renewalLeadTimeSeconds = renewalLeadTimeSeconds
        self.portholeHealthPollSeconds = portholeHealthPollSeconds
        self.portholeRetryBaseDelaySeconds = portholeRetryBaseDelaySeconds
        self.portholeRetryMaxDelaySeconds = portholeRetryMaxDelaySeconds
    }
}

public struct AgentConfig: Codable, Equatable, Sendable {
    public var instanceName: String
    public var heartbeatIntervalSeconds: Int
    public var scaffold: ScaffoldConnectionConfig
    public var watchFolders: [WatchFolderConfig]
    public var automationPolicy: AutomationPolicy
    public var remoteIntentPolicy: RemoteIntentPolicy

    public init(
        instanceName: String,
        heartbeatIntervalSeconds: Int = 30,
        scaffold: ScaffoldConnectionConfig,
        watchFolders: [WatchFolderConfig],
        automationPolicy: AutomationPolicy,
        remoteIntentPolicy: RemoteIntentPolicy = .init()
    ) {
        self.instanceName = instanceName
        self.heartbeatIntervalSeconds = heartbeatIntervalSeconds
        self.scaffold = scaffold
        self.watchFolders = watchFolders
        self.automationPolicy = automationPolicy
        self.remoteIntentPolicy = remoteIntentPolicy
    }

    public static func load(from fileURL: URL) throws -> AgentConfig {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AgentConfig.self, from: data)
    }

    public func write(to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    public func makeSproutBootstrapPlan() -> SproutBootstrapPlan {
        SproutBootstrapPlan(
            scaffoldDomain: scaffold.domain,
            requestedPortholeKind: scaffold.requestedPortholeKind,
            requestedCapabilities: scaffold.requestedCapabilities,
            resolverBaseURL: scaffold.resolverBaseURL,
            starterAuthPath: scaffold.starterAuthPath,
            renewalLeadTimeSeconds: scaffold.renewalLeadTimeSeconds
        )
    }

    public static func example(paths: RuntimePaths) -> AgentConfig {
        let script = """
        on run argv
            if (count of argv) is less than 1 then error "Expected a URL argument"
            set targetURL to item 1 of argv
            tell application "Safari"
                activate
                open location targetURL
            end tell
        end run
        """

        return AgentConfig(
            instanceName: "haven-agentd",
            heartbeatIntervalSeconds: 30,
            scaffold: ScaffoldConnectionConfig(
                sproutBinaryPath: "/absolute/path/to/sprout",
                startupMode: .plan,
                runtime: "mac-agent",
                domain: "staging.haven.example",
                purpose: "bootstrap.join_scaffold",
                goal: "Join scaffold and prepare native porthole access for local automation",
                interests: [
                    "haven.core.bootstrap",
                    "haven.core.bridge",
                    "haven.local.automation"
                ],
                resolverBaseURL: "https://staging.haven.example",
                starterAuthPath: paths.agentDirectory.appendingPathComponent("starter-auth.json").path,
                discoveryURL: "https://staging.haven.example/v1/bridges/query",
                catalogPath: nil,
                enableLiveResolver: true,
                trustedResolverKey: nil,
                requestedCapabilities: [
                    "cap.discover",
                    "cap.native_porthole",
                    "cap.local_automation"
                ],
                requestedPortholeKind: "native",
                renewalLeadTimeSeconds: 900,
                portholeHealthPollSeconds: 5,
                portholeRetryBaseDelaySeconds: 5,
                portholeRetryMaxDelaySeconds: 60
            ),
            watchFolders: [
                WatchFolderConfig(
                    id: "downloads-watch",
                    path: paths.homeDirectory.appendingPathComponent("Downloads").path,
                    topic: "filesystem.watch",
                    events: [.write, .rename],
                    actions: [
                        AutomationActionRequest(
                            kind: .shortcut,
                            id: "ingest-download"
                        )
                    ]
                )
            ],
            automationPolicy: AutomationPolicy(
                shortcuts: [
                    ShortcutDefinition(
                        id: "ingest-download",
                        shortcutName: "HAVEN Ingest Download",
                        acceptsInputPath: false,
                        allowedForRemoteExecution: false,
                        outputPath: paths.outputDirectory.appendingPathComponent("shortcut-output.txt").path,
                        outputType: "public.plain-text"
                    )
                ],
                appleScripts: [
                    AppleScriptDefinition(
                        id: "open-url-in-safari",
                        description: "Open a validated URL in Safari.",
                        source: script,
                        argumentOrder: ["url"],
                        argumentConstraints: [
                            "url": StringConstraint(
                                required: true,
                                maxLength: 1024,
                                allowedValues: [],
                                pattern: #"https://[A-Za-z0-9\.\-/_~:%\?#\[\]@!\$&'\(\)\*\+,;=]+"#
                            )
                        ],
                        allowedForRemoteExecution: false,
                        requiresUserSession: true
                    )
                ]
            ),
            remoteIntentPolicy: RemoteIntentPolicy(
                issuers: [
                    TrustedRemoteIntentIssuer(
                        issuerID: "scaffold-entity.example",
                        publicSigningKeyBase64: "BASE64_PUBLIC_KEY_HERE",
                        allowedTopics: ["intent.inbox"],
                        allowedActionIDs: ["open-url-in-safari"]
                    )
                ],
                requireExpiry: true,
                maxClockSkewSeconds: 300,
                maxArgumentCount: 16
            )
        )
    }
}
