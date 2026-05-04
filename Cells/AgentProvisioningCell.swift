import Foundation
import CellBase
import Darwin

#if os(macOS)
import AppKit
#endif

final class AgentProvisioningCell: GeneralCell {
    private struct ActivityEntry: Codable {
        var title: String
        var detail: String
        var timestamp: String
        var tone: String

        func asObject() -> Object {
            [
                "title": .string(title),
                "detail": .string(detail),
                "timestamp": .string(timestamp),
                "tone": .string(tone)
            ]
        }
    }

    private struct ReviewIntentEntry: Codable {
        var id: String
        var topic: String
        var origin: String
        var actionID: String
        var issuerID: String
        var verificationStatus: String
        var receivedAt: String
        var expiresAt: String
        var argumentsSummary: String
        var summary: String

        func asObject() -> Object {
            [
                "id": .string(id),
                "topic": .string(topic),
                "origin": .string(origin),
                "actionID": .string(actionID),
                "issuerID": .string(issuerID),
                "verificationStatus": .string(verificationStatus),
                "receivedAt": .string(receivedAt),
                "expiresAt": .string(expiresAt),
                "argumentsSummary": .string(argumentsSummary),
                "summary": .string(summary)
            ]
        }
    }

    private struct ReviewAuditEntry: Codable {
        var intentID: String
        var actionID: String
        var outcome: String
        var reviewer: String
        var note: String
        var recordedAt: String
        var issuerID: String
        var executedActionSummary: String
        var errorMessage: String

        func asObject() -> Object {
            [
                "intentID": .string(intentID),
                "actionID": .string(actionID),
                "outcome": .string(outcome),
                "reviewer": .string(reviewer),
                "note": .string(note),
                "recordedAt": .string(recordedAt),
                "issuerID": .string(issuerID),
                "executedActionSummary": .string(executedActionSummary),
                "errorMessage": .string(errorMessage)
            ]
        }
    }

    private struct SignedTestIntentPayload: Encodable {
        var issuerID: String
        var nonce: String
        var topic: String
        var origin: String
        var actionID: String
        var arguments: [String: String]
        var issuedAt: String
        var expiresAt: String?
    }

    private struct MutableState: Codable {
        var purposeName: String
        var purposeRef: String
        var goal: String
        var interestsText: String
        var purposeSource: String
        var domain: String
        var sourceRootPath: String
        var sproutBinaryPath: String
        var installStage: String
        var runtimeStage: String
        var connectStage: String
        var binaryState: String
        var configState: String
        var launchAgentState: String
        var sproutState: String
        var controlBridgeState: String
        var controlBridgeEndpoint: String
        var portholePhase: String
        var connectedContractID: String
        var lastHeartbeatAt: String
        var lastEventSummary: String
        var lastAction: String
        var lastError: String
        var reviewQueueState: String
        var reviewAuditState: String
        var reviewPendingCount: Int
        var reviewAuditCount: Int
        var reviewSelectedIntentID: String
        var reviewSelectedSummary: String
        var reviewNoteDraft: String
        var reviewLastOutcome: String
        var reviewLastRecordedAt: String
        var pendingIntents: [ReviewIntentEntry]
        var auditEntries: [ReviewAuditEntry]
        var activity: [ActivityEntry]
    }

    private struct AgentPaths {
        var sourceRoot: URL
        var packageDirectory: URL
        var stagingDirectory: URL
        var stagedBinary: URL
        var buildBinary: URL
        var alternateBuildBinary: URL
        var bundledBinary: URL?
        var homeDirectory: URL
        var applicationSupportDirectory: URL
        var agentDirectory: URL
        var binDirectory: URL
        var logsDirectory: URL
        var stateDirectory: URL
        var cellDocumentsDirectory: URL
        var inboxDirectory: URL
        var outDirectory: URL
        var configFile: URL
        var installedBinary: URL
        var launchAgentsDirectory: URL
        var launchAgentPlist: URL
    }

    private struct LiveControlBridgeConfiguration {
        var enabled: Bool
        var host: String
        var port: Int
        var accessToken: String?
        var routeNamesByTarget: [String: String]

        var websocketBaseURL: String {
            "ws://\(host):\(port)/bridgehead"
        }

        func endpoint(forTargetCellReference target: String) -> String? {
            guard let routeName = routeNamesByTarget[target] else {
                return nil
            }
            guard var components = URLComponents(string: "\(websocketBaseURL)/\(routeName)") else {
                return nil
            }
            if let accessToken, !accessToken.isEmpty {
                components.queryItems = [
                    URLQueryItem(name: "token", value: accessToken)
                ]
            }
            return components.url?.absoluteString
        }
    }

    private struct LiveAgentProjection {
        var portholePhase: String
        var connectedContractID: String
        var lastHeartbeatAt: String
        var lastEventSummary: String
        var lastError: String
        var pendingIntents: [ReviewIntentEntry]
        var auditEntries: [ReviewAuditEntry]
        var controlBridgeState: String
        var controlBridgeEndpoint: String
    }

    private struct CommandResult {
        var status: Int32
        var standardOutput: String
        var standardError: String

        var succeeded: Bool { status == 0 }
    }

    private enum ProvisioningError: LocalizedError {
        case invalidStringPayload
        case invalidObjectPayload
        case unsupportedPlatform(String)
        case missingSourceRoot(String)
        case missingAgentPackage(String)
        case buildFailed(String)
        case missingBuiltBinary(String)
        case missingInstalledBinary(String)
        case commandFailed(String)
        case perspectiveUnavailable
        case noActivePurpose
        case noSelectedReviewIntent
        case identityVaultUnavailable
        case operatorIdentityUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidStringPayload:
                return "Expected a string payload."
            case .invalidObjectPayload:
                return "Expected an object payload."
            case .unsupportedPlatform(let feature):
                return "\(feature) is only available when Binding runs on macOS."
            case .missingSourceRoot(let path):
                return "Source root was not found: \(path)"
            case .missingAgentPackage(let path):
                return "HavenAgentD package was not found under: \(path)"
            case .buildFailed(let message):
                return "Agent build failed: \(message)"
            case .missingBuiltBinary(let path):
                return "Built agent binary was not found at \(path)."
            case .missingInstalledBinary(let path):
                return "Installed agent binary is missing: \(path)"
            case .commandFailed(let message):
                return message
            case .perspectiveUnavailable:
                return "Perspective is not available in the current runtime."
            case .noActivePurpose:
                return "Perspective did not return any active purposes."
            case .noSelectedReviewIntent:
                return "Select a pending intent before approving or rejecting review."
            case .identityVaultUnavailable:
                return "Identity vault is unavailable."
            case .operatorIdentityUnavailable:
                return "Operator identity is unavailable."
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case mutableState
    }

    nonisolated private static let launchAgentLabel = "io.digipomps.haven.agentd"
    nonisolated private static let feedTopic = "agent.setup"
    nonisolated private static let maxActivityEntries = 24
    nonisolated private static let defaultDomain = "staging.haven.digipomps.org"
    nonisolated private static let defaultPurposeName = "Operate local HAVEN agent"
    nonisolated private static let defaultPurposeRef = "purpose://operate-local-haven-agent"
    nonisolated private static let defaultGoal = "Install, start and connect a local HAVEN agent without bypassing CellProtocol review boundaries."
    nonisolated private static let defaultInterests = "cellprotocol, agent, automation, review"
    nonisolated private static let defaultTestAppleScriptID = "binding-test-open-url-in-safari"
    nonisolated private static let defaultTestIssuerPrefix = "binding-operator"
    private static let runtimeAccessBookmarkKey = "Binding.AgentRuntimeAccess.userHomeBookmark"
    private static let runtimeAccessLock = NSLock()
    private static var runtimeAccessURL: URL?
    private static var runtimeAccessStarted = false
    nonisolated private static let defaultControlBridge = LiveControlBridgeConfiguration(
        enabled: true,
        host: "127.0.0.1",
        port: 43110,
        accessToken: nil,
        routeNamesByTarget: [
            "agent/identity": "agent-identity",
            "agent/supervisor": "agent-supervisor",
            "agent/intents/inbox": "intent-inbox",
            "agent/intents/review": "intent-review"
        ]
    )
    nonisolated private static let repositoryRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()
    nonisolated private static var supportsLocalAgentRuntime: Bool {
#if os(macOS)
        true
#else
        false
#endif
    }

    nonisolated private let stateQueue = DispatchQueue(label: "Binding.AgentProvisioningCell.State")
    nonisolated(unsafe) private var mutableState: MutableState

    required init(owner: Identity) async {
        mutableState = Self.makeDefaultState()
        await super.init(owner: owner)
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
        await refreshState(requester: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mutableState = try container.decodeIfPresent(MutableState.self, forKey: .mutableState) ?? Self.makeDefaultState()
        try super.init(from: decoder)

        Task {
            if let vault = CellBase.defaultIdentityVault,
               let requester = await vault.identity(for: "private", makeNewIfNotFound: true) {
                await self.setupPermissions(owner: requester)
                await self.setupKeys(owner: requester)
                await self.refreshState(requester: requester)
            }
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync { mutableState }
        try container.encode(snapshot, forKey: .mutableState)
    }

    nonisolated private static func makeDefaultState() -> MutableState {
        let sourceRoot = repositoryRoot.path
        let sproutPath = repositoryRoot
            .deletingLastPathComponent()
            .appendingPathComponent("sprout/.build/debug/sprout")
            .path
        let defaultControlBridgeEndpoint = "ws://127.0.0.1:43110/bridgehead"

        return MutableState(
            purposeName: defaultPurposeName,
            purposeRef: defaultPurposeRef,
            goal: defaultGoal,
            interestsText: defaultInterests,
            purposeSource: "Default profile",
            domain: defaultDomain,
            sourceRootPath: sourceRoot,
            sproutBinaryPath: sproutPath,
            installStage: "Waiting for install",
            runtimeStage: "LaunchAgent not running",
            connectStage: "No scaffold contract yet",
            binaryState: "No installed agent binary yet.",
            configState: "No config written yet.",
            launchAgentState: "No launch agent plist written yet.",
            sproutState: "Sprout path not checked yet.",
            controlBridgeState: "Local CellProtocol bridge not configured yet.",
            controlBridgeEndpoint: defaultControlBridgeEndpoint,
            portholePhase: "idle",
            connectedContractID: "No contract",
            lastHeartbeatAt: "No heartbeat yet.",
            lastEventSummary: "No runtime events recorded yet.",
            lastAction: "Initialized provisioning surface.",
            lastError: "",
            reviewQueueState: "No pending intents detected yet.",
            reviewAuditState: "No review audit detected yet.",
            reviewPendingCount: 0,
            reviewAuditCount: 0,
            reviewSelectedIntentID: "",
            reviewSelectedSummary: "Select a pending intent to inspect its action, issuer and argument summary.",
            reviewNoteDraft: "",
            reviewLastOutcome: "",
            reviewLastRecordedAt: "",
            pendingIntents: [],
            auditEntries: [],
            activity: []
        )
    }

    private static let readOnlyKeys: [String] = [
        "state",
        "agent.setup.state",
        "agent.setup.status.installStage",
        "agent.setup.status.runtimeStage",
        "agent.setup.status.connectStage",
        "agent.setup.status.binaryState",
        "agent.setup.status.configState",
        "agent.setup.status.launchAgentState",
        "agent.setup.status.sproutState",
        "agent.setup.status.controlBridgeState",
        "agent.setup.status.controlBridgeEndpoint",
        "agent.setup.status.portholeStrategy",
        "agent.setup.status.portholePhase",
        "agent.setup.status.connectedContractID",
        "agent.setup.status.lastHeartbeatAt",
        "agent.setup.status.lastEventSummary",
        "agent.setup.status.lastAction",
        "agent.setup.status.lastError",
        "agent.setup.status.purposeBinding",
        "agent.setup.status.domain",
        "agent.setup.status.discoveryURL",
        "agent.setup.status.resolverBaseURL",
        "agent.setup.purpose.name",
        "agent.setup.purpose.ref",
        "agent.setup.purpose.goal",
        "agent.setup.purpose.interests",
        "agent.setup.purpose.source",
        "agent.setup.environment.sourceRoot",
        "agent.setup.environment.sproutBinaryPath",
        "agent.setup.environment.configPath",
        "agent.setup.environment.launchAgentPlistPath",
        "agent.setup.environment.installBinaryPath",
        "agent.setup.review.pendingCount",
        "agent.setup.review.auditCount",
        "agent.setup.review.queueState",
        "agent.setup.review.auditState",
        "agent.setup.review.selectedIntentID",
        "agent.setup.review.selectedSummary",
        "agent.setup.review.noteDraft",
        "agent.setup.review.lastOutcome",
        "agent.setup.review.lastRecordedAt",
        "agent.setup.review.pending",
        "agent.setup.review.audit",
        "agent.setup.pipeline",
        "agent.setup.activity"
    ]

    private static let writableDraftKeys: [String] = [
        "agent.setup.purpose.name",
        "agent.setup.purpose.ref",
        "agent.setup.purpose.goal",
        "agent.setup.purpose.interests",
        "agent.setup.environment.sourceRoot",
        "agent.setup.environment.sproutBinaryPath",
        "agent.setup.status.domain",
        "agent.setup.review.noteDraft"
    ]

    private static let actionKeys: [String] = [
        "agent.setup.refresh",
        "agent.setup.syncFromPerspective",
        "agent.setup.selectPreset",
        "agent.setup.install",
        "agent.setup.start",
        "agent.setup.connect",
        "agent.setup.stop",
        "agent.setup.review.selection",
        "agent.setup.review.queueSafariTest",
        "agent.setup.review.approveSelected",
        "agent.setup.review.rejectSelected"
    ]

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "flow")
        for key in Self.readOnlyKeys {
            agreementTemplate.addGrant("r---", for: key)
        }
        for key in Self.writableDraftKeys + Self.actionKeys {
            agreementTemplate.addGrant("rw--", for: key)
        }
    }

    private func setupKeys(owner: Identity) async {
        for key in Self.readOnlyKeys {
            await addInterceptForGet(requester: owner, key: key, getValueIntercept: { [weak self] _, requester in
                guard let self = self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                return self.value(forReadableKey: key)
            })
        }

        for key in Self.writableDraftKeys {
            await addInterceptForSet(requester: owner, key: key, setValueIntercept: { [weak self] _, value, requester in
                guard let self = self else { return .string("failure") }
                guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
                return await self.applyEditableValue(value, for: key, requester: requester)
            })
        }

        await registerAction(key: "agent.setup.refresh", owner: owner) { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            await self.refreshState(requester: requester)
            return self.value(forReadableKey: "agent.setup.state")
        }

        await registerAction(key: "agent.setup.syncFromPerspective", owner: owner) { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            return await self.performAction(title: "Synced purpose from Perspective", requester: requester) {
                try await self.syncFromPerspective(requester: requester)
            }
        }

        await registerAction(key: "agent.setup.selectPreset", owner: owner) { [weak self] payload, requester in
            guard let self = self else { return .string("failure") }
            return await self.performAction(title: "Applied agent preset", requester: requester) {
                try self.selectPreset(from: payload)
            }
        }

        await registerAction(key: "agent.setup.install", owner: owner) { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            return await self.performAction(title: "Installed haven-agentd", requester: requester) {
                try self.installAgentBinary()
            }
        }

        await registerAction(key: "agent.setup.start", owner: owner) { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            return await self.performAction(title: "Started launch agent", requester: requester) {
                try self.startLaunchAgent()
            }
        }

        await registerAction(key: "agent.setup.connect", owner: owner) { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            return await self.performAction(title: "Ran purpose connect", requester: requester) {
                try await self.connectUsingCurrentPurpose(requester: requester)
            }
        }

        await registerAction(key: "agent.setup.stop", owner: owner) { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            return await self.performAction(title: "Stopped launch agent", requester: requester) {
                try self.stopLaunchAgent()
            }
        }

        await registerAction(key: "agent.setup.review.selection", owner: owner) { [weak self] payload, requester in
            guard let self = self else { return .string("failure") }
            do {
                try self.selectReviewIntent(from: payload)
                await self.emitStateUpdate(
                    title: "Updated review focus",
                    detail: self.stateQueue.sync { self.mutableState.reviewSelectedSummary },
                    tone: "muted",
                    requester: requester
                )
                return self.value(forReadableKey: "agent.setup.review.selectedSummary")
            } catch {
                await self.recordFailure(action: "Updated review focus", error: error, requester: requester)
                return .string("error: \(error.localizedDescription)")
            }
        }

        await registerAction(key: "agent.setup.review.queueSafariTest", owner: owner) { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            return await self.performAction(title: "Queued Safari review test", requester: requester) {
                try await self.queueSafariReviewTestIntent(requester: requester)
            }
        }

        await registerAction(key: "agent.setup.review.approveSelected", owner: owner) { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            return await self.performAction(title: "Approved selected remote intent", requester: requester) {
                try await self.approveSelectedReviewIntent(reviewer: requester.displayName, requester: requester)
            }
        }

        await registerAction(key: "agent.setup.review.rejectSelected", owner: owner) { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            return await self.performAction(title: "Rejected selected remote intent", requester: requester) {
                try await self.rejectSelectedReviewIntent(reviewer: requester.displayName, requester: requester)
            }
        }
    }

    private func registerAction(
        key: String,
        owner: Identity,
        handler: @escaping (ValueType, Identity) async -> ValueType
    ) async {
        await addInterceptForSet(requester: owner, key: key, setValueIntercept: { [weak self] _, value, requester in
            guard let self = self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
            return await handler(value, requester)
        })

        await addInterceptForGet(requester: owner, key: key, getValueIntercept: { [weak self] _, requester in
            guard let self = self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
            return await handler(.null, requester)
        })
    }

    private func applyEditableValue(_ value: ValueType, for key: String, requester: Identity) async -> ValueType {
        do {
            let text = try extractString(from: value)
            stateQueue.sync {
                switch key {
                case "agent.setup.purpose.name":
                    mutableState.purposeName = text
                    mutableState.purposeSource = "Manual draft"
                    if mutableState.purposeRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || mutableState.purposeRef == Self.defaultPurposeRef {
                        mutableState.purposeRef = Self.portablePurposeRef(from: text)
                    }
                case "agent.setup.purpose.ref":
                    mutableState.purposeRef = text
                    mutableState.purposeSource = "Manual draft"
                case "agent.setup.purpose.goal":
                    mutableState.goal = text
                    mutableState.purposeSource = "Manual draft"
                case "agent.setup.purpose.interests":
                    mutableState.interestsText = text
                    mutableState.purposeSource = "Manual draft"
                case "agent.setup.environment.sourceRoot":
                    mutableState.sourceRootPath = text
                case "agent.setup.environment.sproutBinaryPath":
                    mutableState.sproutBinaryPath = text
                case "agent.setup.status.domain":
                    mutableState.domain = text
                case "agent.setup.review.noteDraft":
                    mutableState.reviewNoteDraft = text
                default:
                    break
                }
            }
            await refreshState(requester: requester)
            await emitStateUpdate(title: "Updated draft", detail: key, tone: "muted", requester: requester)
            return self.value(forReadableKey: key)
        } catch {
            await recordFailure(action: "Failed to update draft", error: error, requester: requester)
            return .string("error: \(error.localizedDescription)")
        }
    }

    private func performAction(
        title: String,
        requester: Identity,
        operation: @escaping () async throws -> Void
    ) async -> ValueType {
        do {
            try await operation()
            stateQueue.sync {
                mutableState.lastAction = title
                mutableState.lastError = ""
            }
            await refreshState(requester: requester)
            await emitStateUpdate(title: title, detail: stateQueue.sync { mutableState.connectStage }, tone: "positive", requester: requester)
            return value(forReadableKey: "agent.setup.state")
        } catch {
            await recordFailure(action: title, error: error, requester: requester)
            return value(forReadableKey: "agent.setup.state")
        }
    }

    private func syncFromPerspective(requester: Identity) async throws {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            throw ProvisioningError.perspectiveUnavailable
        }
        guard let perspectiveEmit = try? await resolver.cellAtEndpoint(endpoint: "cell:///Perspective", requester: requester),
              let perspective = perspectiveEmit as? Meddle else {
            throw ProvisioningError.perspectiveUnavailable
        }

        let activePurposeValue = try await perspective.get(keypath: "activePurpose", requester: requester)
        let activeInterestValue = try await perspective.set(
            keypath: "perspective.query.interestsFromActivePurposes",
            value: .object([
                "limit": .integer(24),
                "referenceMode": .string("both")
            ]),
            requester: requester
        ) ?? .null

        guard case let .object(purposeObject) = activePurposeValue,
              case let .list(purposes)? = purposeObject["purposes"],
              let firstPurpose = purposes.first,
              case let .object(firstPurposeObject) = firstPurpose else {
            throw ProvisioningError.noActivePurpose
        }

        let purposeName = stringValue(from: firstPurposeObject["purposeName"]) ?? Self.defaultPurposeName
        let purposeRef = stringValue(from: firstPurposeObject["portablePurposeRef"]) ?? Self.portablePurposeRef(from: purposeName)
        let derivedInterests = extractInterestNames(from: activeInterestValue)
        let interestsText = derivedInterests.isEmpty ? stateQueue.sync { mutableState.interestsText } : derivedInterests.joined(separator: ", ")

        stateQueue.sync {
            mutableState.purposeName = purposeName
            mutableState.purposeRef = purposeRef
            mutableState.goal = "Join scaffold access for '\(purposeName)' while keeping local automation behind reviewed CellProtocol effects."
            mutableState.interestsText = interestsText
            mutableState.purposeSource = "Perspective"
        }
    }

    private func selectPreset(from payload: ValueType) throws {
        guard case let .object(object) = payload else {
            throw ProvisioningError.invalidObjectPayload
        }

        let purposeName = stringValue(from: object["purposeName"]) ?? Self.defaultPurposeName
        let purposeRef = stringValue(from: object["purposeRef"]) ?? Self.portablePurposeRef(from: purposeName)
        let goal = stringValue(from: object["goal"]) ?? Self.defaultGoal
        let interests = extractStringList(from: object["interests"])

        stateQueue.sync {
            mutableState.purposeName = purposeName
            mutableState.purposeRef = purposeRef
            mutableState.goal = goal
            mutableState.interestsText = interests.joined(separator: ", ")
            mutableState.purposeSource = "Preset"
        }
    }

    private func selectReviewIntent(from payload: ValueType) throws {
        let selectedID: String? = {
            if case let .string(intentID) = payload {
                return intentID
            }
            guard case let .object(object) = payload else {
                return nil
            }
            if case let .string(intentID)? = object["selected"] {
                return intentID
            }
            if case .null? = object["selected"] {
                return ""
            }
            return nil
        }()

        guard let normalized = selectedID else {
            throw ProvisioningError.invalidObjectPayload
        }

        stateQueue.sync {
            mutableState.reviewSelectedIntentID = normalized
            if let selected = mutableState.pendingIntents.first(where: { $0.id == normalized }) {
                mutableState.reviewSelectedSummary = selected.summary
            } else {
                mutableState.reviewSelectedSummary = "Select a pending intent to inspect its action, issuer and argument summary."
            }
        }
    }

    private func installAgentBinary() throws {
        guard Self.supportsLocalAgentRuntime else {
            throw ProvisioningError.unsupportedPlatform("Installing haven-agentd")
        }
        let paths = try prepareInstallArtifacts()
        let fileManager = FileManager.default
        if Self.preferredBuiltBinary(paths: paths, fileManager: fileManager) == nil {
            guard fileManager.fileExists(atPath: paths.sourceRoot.path) else {
                throw ProvisioningError.missingSourceRoot(paths.sourceRoot.path)
            }
            guard fileManager.fileExists(atPath: paths.packageDirectory.appendingPathComponent("Package.swift").path) else {
                throw ProvisioningError.missingAgentPackage(paths.packageDirectory.path)
            }

            let build = try Self.runCommand(
                "/usr/bin/swift",
                arguments: ["build", "--product", "haven-agentd"],
                currentDirectory: paths.packageDirectory
            )
            guard build.succeeded else {
                let guidance = "Prebuild HavenAgentD from Terminal with `swift build --package-path \(paths.packageDirectory.path) --product haven-agentd` and retry install."
                throw ProvisioningError.buildFailed("\(Self.trimmedOutput(from: build)) \(guidance)")
            }
        }

        guard let builtBinary = Self.preferredBuiltBinary(paths: paths, fileManager: fileManager) else {
            throw ProvisioningError.missingBuiltBinary(paths.buildBinary.path)
        }

        if fileManager.fileExists(atPath: paths.installedBinary.path) {
            try fileManager.removeItem(at: paths.installedBinary)
        }
        if Self.shouldInstallAsSymlink(sourceBinary: builtBinary, paths: paths) {
            try fileManager.createSymbolicLink(at: paths.installedBinary, withDestinationURL: builtBinary)
        } else {
            try fileManager.copyItem(at: builtBinary, to: paths.installedBinary)
            Self.removeQuarantineAttribute(at: paths.installedBinary)
        }
    }

    private static func regularFileExists(
        at fileURL: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        var isDirectory = ObjCBool(false)
        let exists = fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }

    private static func removeQuarantineAttribute(at fileURL: URL) {
#if os(macOS)
        fileURL.withUnsafeFileSystemRepresentation { fileSystemPath in
            guard let fileSystemPath else { return }
            removexattr(fileSystemPath, "com.apple.quarantine", 0)
        }
#endif
    }

    private static func shouldInstallAsSymlink(sourceBinary: URL, paths: AgentPaths) -> Bool {
        guard paths.applicationSupportDirectory.path.contains("/Library/Containers/com.digipomps.Binding/") else {
            return false
        }
        if sourceBinary.standardizedFileURL == paths.stagedBinary.standardizedFileURL {
            return true
        }
        if let bundledBinary = paths.bundledBinary,
           sourceBinary.standardizedFileURL == bundledBinary.standardizedFileURL {
            return true
        }
        return false
    }

    private static func preferredBuiltBinary(
        paths: AgentPaths,
        fileManager: FileManager = .default
    ) -> URL? {
        if regularFileExists(at: paths.stagedBinary, fileManager: fileManager) {
            return paths.stagedBinary
        }
        if let bundledBinary = paths.bundledBinary,
           regularFileExists(at: bundledBinary, fileManager: fileManager) {
            return bundledBinary
        }
        if regularFileExists(at: paths.buildBinary, fileManager: fileManager) {
            return paths.buildBinary
        }
        if regularFileExists(at: paths.alternateBuildBinary, fileManager: fileManager) {
            return paths.alternateBuildBinary
        }
        return nil
    }

    private func startLaunchAgent() throws {
        guard Self.supportsLocalAgentRuntime else {
            throw ProvisioningError.unsupportedPlatform("Starting the local HAVEN agent")
        }
        let paths = try prepareInstallArtifacts()
        guard Self.regularFileExists(at: paths.installedBinary) else {
            throw ProvisioningError.missingInstalledBinary(paths.installedBinary.path)
        }

        let serviceTarget = Self.launchctlServiceTarget()
        if Self.isLaunchAgentLoaded(label: Self.launchAgentLabel) {
            let kickstart = try Self.runCommand("/bin/launchctl", arguments: ["kickstart", "-k", serviceTarget])
            guard kickstart.succeeded || Self.isLaunchAgentRunning(label: Self.launchAgentLabel) else {
                throw ProvisioningError.commandFailed("launchctl kickstart failed: \(Self.trimmedOutput(from: kickstart))")
            }
            return
        }

        let bootstrap = try Self.runCommand(
            "/bin/launchctl",
            arguments: ["bootstrap", "gui/\(getuid())", paths.launchAgentPlist.path]
        )
        guard bootstrap.succeeded else {
            throw ProvisioningError.commandFailed("launchctl bootstrap failed: \(Self.trimmedOutput(from: bootstrap))")
        }

        if let kickstart = try? Self.runCommand("/bin/launchctl", arguments: ["kickstart", "-k", serviceTarget]),
           kickstart.succeeded == false,
           Self.isLaunchAgentRunning(label: Self.launchAgentLabel) == false {
            throw ProvisioningError.commandFailed("launchctl kickstart failed: \(Self.trimmedOutput(from: kickstart))")
        }
    }

    private func stopLaunchAgent() throws {
        guard Self.supportsLocalAgentRuntime else {
            throw ProvisioningError.unsupportedPlatform("Stopping the local HAVEN agent")
        }
        guard Self.isLaunchAgentLoaded(label: Self.launchAgentLabel) else {
            return
        }
        let result = try Self.runCommand(
            "/bin/launchctl",
            arguments: ["bootout", Self.launchctlServiceTarget()]
        )
        guard result.succeeded else {
            throw ProvisioningError.commandFailed("launchctl bootout failed: \(Self.trimmedOutput(from: result))")
        }
    }

    private func connectUsingCurrentPurpose(requester: Identity) async throws {
        guard Self.supportsLocalAgentRuntime else {
            throw ProvisioningError.unsupportedPlatform("Connecting the local HAVEN agent")
        }
        let paths = try prepareInstallArtifacts()
        guard Self.regularFileExists(at: paths.installedBinary) else {
            throw ProvisioningError.missingInstalledBinary(paths.installedBinary.path)
        }

        try await ensureFreshEnrollmentArtifacts(requester: requester, paths: paths)
        try startLaunchAgent()
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }

    private func ensureFreshEnrollmentArtifacts(requester: Identity, paths: AgentPaths) async throws {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            throw ProvisioningError.commandFailed("CellResolver is unavailable for agent enrollment refresh.")
        }
        guard let enrollment = try await resolver.cellAtEndpoint(endpoint: "cell:///AgentEnrollment", requester: requester) as? Meddle else {
            throw ProvisioningError.commandFailed("Agent enrollment surface is unavailable.")
        }

        _ = try await enrollment.set(
            keypath: "enrollment.createPairingArtifact",
            value: .bool(true),
            requester: requester
        )

        let starterAuthFile = paths.agentDirectory.appendingPathComponent("starter-auth.json")
        let entityLinkFile = paths.outDirectory.appendingPathComponent("agent-operator-entity-link.json")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: starterAuthFile.path) else {
            throw ProvisioningError.commandFailed(
                "Agent enrollment did not materialize starter auth at \(starterAuthFile.path)."
            )
        }
        guard fileManager.fileExists(atPath: entityLinkFile.path) else {
            throw ProvisioningError.commandFailed(
                "Agent enrollment did not materialize entity-link evidence at \(entityLinkFile.path)."
            )
        }
    }

    private func approveSelectedReviewIntent(reviewer: String, requester: Identity) async throws {
        if try await runLiveReviewCommand(keypath: "approve", reviewer: reviewer, requester: requester) {
            stateQueue.sync {
                mutableState.reviewNoteDraft = ""
            }
            return
        }
        try runReviewCommand(subcommand: "review-approve", reviewer: reviewer)
    }

    private func rejectSelectedReviewIntent(reviewer: String, requester: Identity) async throws {
        if try await runLiveReviewCommand(keypath: "reject", reviewer: reviewer, requester: requester) {
            stateQueue.sync {
                mutableState.reviewNoteDraft = ""
            }
            return
        }
        try runReviewCommand(subcommand: "review-reject", reviewer: reviewer)
    }

    private func runLiveReviewCommand(
        keypath: String,
        reviewer: String,
        requester: Identity
    ) async throws -> Bool {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            return false
        }
        let paths = try currentPaths()
        let controlBridge = Self.liveControlBridgeConfiguration(
            configJSON: Self.readJSONObject(at: paths.configFile)
        )
        guard controlBridge.enabled,
              let endpoint = controlBridge.endpoint(forTargetCellReference: "agent/intents/review"),
              let reviewCell = try await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester) as? Meddle else {
            return false
        }

        let snapshot = stateQueue.sync { mutableState }
        let intentID = snapshot.reviewSelectedIntentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !intentID.isEmpty else {
            throw ProvisioningError.noSelectedReviewIntent
        }

        var payload: Object = [
            "intentID": .string(intentID),
            "reviewer": .string(reviewer)
        ]
        let note = snapshot.reviewNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            payload["note"] = .string(note)
        }

        let response = try await reviewCell.set(
            keypath: keypath,
            value: .object(payload),
            requester: requester
        )
        if case let .string(errorText)? = response,
           errorText.hasPrefix("error:") {
            throw ProvisioningError.commandFailed(errorText)
        }
        return true
    }

    private func runReviewCommand(subcommand: String, reviewer: String) throws {
        guard Self.supportsLocalAgentRuntime else {
            throw ProvisioningError.unsupportedPlatform("Running local review commands")
        }
        let paths = try prepareInstallArtifacts()
        guard Self.regularFileExists(at: paths.installedBinary) else {
            throw ProvisioningError.missingInstalledBinary(paths.installedBinary.path)
        }

        let snapshot = stateQueue.sync { mutableState }
        let intentID = snapshot.reviewSelectedIntentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !intentID.isEmpty else {
            throw ProvisioningError.noSelectedReviewIntent
        }

        var arguments = [
            subcommand,
            "--config", paths.configFile.path,
            "--intent-id", intentID,
            "--reviewer", reviewer
        ]

        let note = snapshot.reviewNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            arguments.append(contentsOf: ["--note", note])
        }

        let result = try Self.runCommand(paths.installedBinary.path, arguments: arguments)
        guard result.succeeded else {
            throw ProvisioningError.commandFailed("\(subcommand) failed: \(Self.trimmedOutput(from: result))")
        }

        stateQueue.sync {
            mutableState.reviewNoteDraft = ""
        }
    }

    private func queueSafariReviewTestIntent(requester: Identity) async throws {
        guard Self.supportsLocalAgentRuntime else {
            throw ProvisioningError.unsupportedPlatform("Queueing a local HAVEN agent review test")
        }

        let operatorIdentity = try await resolveOperatorIdentity(requester: requester)
        let paths = try prepareInstallArtifacts(requester: operatorIdentity)
        let configJSON = Self.readJSONObject(at: paths.configFile)
        let controlBridge = Self.liveControlBridgeConfiguration(configJSON: configJSON)
        guard controlBridge.enabled,
              let inbox = try await remoteAgentCell(
                targetCellReference: "agent/intents/inbox",
                configuration: controlBridge,
                requester: requester
              ) else {
            throw ProvisioningError.commandFailed("Agent intent inbox is not reachable over the local control bridge.")
        }

        let envelope = try await Self.makeSignedTestIntentEnvelope(
            requester: operatorIdentity,
            domain: sanitizedBaseURL(for: stateQueue.sync { mutableState.domain })
        )

        let response = try await inbox.set(
            keypath: "enqueueSigned",
            value: .object([
                "remoteIntentEnvelope": Self.signedEnvelopeValue(envelope)
            ]),
            requester: requester
        )

        if case let .string(errorText) = response,
           errorText.hasPrefix("error:") {
            throw ProvisioningError.commandFailed(errorText)
        }

        stateQueue.sync {
            mutableState.reviewSelectedIntentID = envelope.payload.nonce
            if mutableState.reviewNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                mutableState.reviewNoteDraft = "Approved from Binding Safari smoke test."
            }
        }
    }

    private func resolveOperatorIdentity(requester: Identity) async throws -> Identity {
        if requester.displayName.isEmpty == false {
            return requester
        }
        guard let vault = CellBase.defaultIdentityVault else {
            throw ProvisioningError.identityVaultUnavailable
        }
        guard let operatorIdentity = await vault.identity(for: "private", makeNewIfNotFound: true) else {
            throw ProvisioningError.operatorIdentityUnavailable
        }
        return operatorIdentity
    }

    private func prepareInstallArtifacts(requester: Identity? = nil) throws -> AgentPaths {
        let paths = try currentPaths()
        try Self.ensureExternalRuntimeAccess(forHomeDirectory: paths.homeDirectory)
        let fileManager = FileManager.default

        for directory in [
            paths.agentDirectory,
            paths.binDirectory,
            paths.stagingDirectory,
            paths.logsDirectory,
            paths.stateDirectory,
            paths.cellDocumentsDirectory,
            paths.inboxDirectory,
            paths.outDirectory,
            paths.launchAgentsDirectory
        ] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }

        let configObject = makeAgentConfigObject(paths: paths, requester: requester)
        let configData = try JSONSerialization.data(withJSONObject: configObject, options: [.prettyPrinted, .sortedKeys])
        try configData.write(to: paths.configFile, options: [.atomic])

        let launchAgent = Self.renderLaunchAgent(
            executablePath: paths.installedBinary.path,
            configPath: paths.configFile.path,
            logDirectory: paths.logsDirectory.path
        )
        try launchAgent.write(to: paths.launchAgentPlist, atomically: true, encoding: .utf8)

        return paths
    }

    private func currentPaths() throws -> AgentPaths {
        let snapshot = stateQueue.sync { mutableState }
        let sourceRoot = URL(fileURLWithPath: NSString(string: snapshot.sourceRootPath).expandingTildeInPath)
        let homeDirectory = Self.userHomeDirectory()
        Self.activatePersistedExternalRuntimeAccess(forHomeDirectory: homeDirectory)
        let applicationSupportDirectory = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        let agentDirectory = applicationSupportDirectory.appendingPathComponent("HAVENAgent", isDirectory: true)
        let stagingDirectory = agentDirectory.appendingPathComponent("Staging", isDirectory: true)
        let launchAgentsDirectory: URL = {
#if os(macOS)
            homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("LaunchAgents", isDirectory: true)
#else
            agentDirectory.appendingPathComponent("LaunchAgents", isDirectory: true)
#endif
        }()
        let bundledBinary = Bundle.main.resourceURL?.appendingPathComponent("HAVENAgent/haven-agentd")

        return AgentPaths(
            sourceRoot: sourceRoot,
            packageDirectory: sourceRoot.appendingPathComponent("HavenAgentD", isDirectory: true),
            stagingDirectory: stagingDirectory,
            stagedBinary: stagingDirectory.appendingPathComponent("haven-agentd"),
            buildBinary: sourceRoot.appendingPathComponent("HavenAgentD/.build/debug/haven-agentd"),
            alternateBuildBinary: sourceRoot.appendingPathComponent("HavenAgentD/.build/arm64-apple-macosx/debug/haven-agentd"),
            bundledBinary: bundledBinary,
            homeDirectory: homeDirectory,
            applicationSupportDirectory: applicationSupportDirectory,
            agentDirectory: agentDirectory,
            binDirectory: agentDirectory.appendingPathComponent("bin", isDirectory: true),
            logsDirectory: agentDirectory.appendingPathComponent("Logs", isDirectory: true),
            stateDirectory: agentDirectory.appendingPathComponent("State", isDirectory: true),
            cellDocumentsDirectory: agentDirectory.appendingPathComponent("CellDocuments", isDirectory: true),
            inboxDirectory: agentDirectory.appendingPathComponent("Inbox", isDirectory: true),
            outDirectory: agentDirectory.appendingPathComponent("Out", isDirectory: true),
            configFile: agentDirectory.appendingPathComponent("config.json"),
            installedBinary: agentDirectory.appendingPathComponent("bin/haven-agentd"),
            launchAgentsDirectory: launchAgentsDirectory,
            launchAgentPlist: launchAgentsDirectory.appendingPathComponent("\(Self.launchAgentLabel).plist")
        )
    }

    nonisolated private static func userHomeDirectory() -> URL {
        if let entry = getpwuid(getuid()),
           let directory = entry.pointee.pw_dir,
           let resolvedHome = String(validatingUTF8: directory),
           !resolvedHome.isEmpty {
            return URL(fileURLWithPath: resolvedHome, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }

    private static func activatePersistedExternalRuntimeAccess(forHomeDirectory homeDirectory: URL) {
#if os(macOS)
        runtimeAccessLock.lock()
        defer { runtimeAccessLock.unlock() }
        _ = activatePersistedExternalRuntimeAccessLocked(forHomeDirectory: homeDirectory)
#else
        _ = homeDirectory
#endif
    }

    private static func ensureExternalRuntimeAccess(forHomeDirectory homeDirectory: URL) throws {
#if os(macOS)
        runtimeAccessLock.lock()
        let alreadyActive = activatePersistedExternalRuntimeAccessLocked(forHomeDirectory: homeDirectory)
        runtimeAccessLock.unlock()
        if alreadyActive {
            return
        }

        let selectedHomeDirectory = try requestExternalRuntimeAccessFromUser(expectedHomeDirectory: homeDirectory)
        let bookmarkData = try selectedHomeDirectory.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmarkData, forKey: runtimeAccessBookmarkKey)

        runtimeAccessLock.lock()
        defer { runtimeAccessLock.unlock() }
        guard activatePersistedExternalRuntimeAccessLocked(forHomeDirectory: homeDirectory) else {
            throw ProvisioningError.commandFailed(
                "Binding could not activate external runtime access for \(homeDirectory.path)."
            )
        }
#else
        _ = homeDirectory
#endif
    }

#if os(macOS)
    private static func activatePersistedExternalRuntimeAccessLocked(forHomeDirectory homeDirectory: URL) -> Bool {
        if runtimeAccessStarted,
           runtimeAccessURL?.standardizedFileURL == homeDirectory.standardizedFileURL {
            return true
        }

        guard let bookmarkData = UserDefaults.standard.data(forKey: runtimeAccessBookmarkKey) else {
            return false
        }

        var bookmarkIsStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &bookmarkIsStale
        ) else {
            return false
        }

        guard resolvedURL.standardizedFileURL == homeDirectory.standardizedFileURL else {
            return false
        }

        if bookmarkIsStale,
           let refreshedBookmarkData = try? resolvedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
           ) {
            UserDefaults.standard.set(refreshedBookmarkData, forKey: runtimeAccessBookmarkKey)
        }

        runtimeAccessURL = resolvedURL
        runtimeAccessStarted = resolvedURL.startAccessingSecurityScopedResource()
        return runtimeAccessStarted
    }

    private static func requestExternalRuntimeAccessFromUser(expectedHomeDirectory: URL) throws -> URL {
        if Thread.isMainThread {
            return try showExternalRuntimeAccessPanel(expectedHomeDirectory: expectedHomeDirectory)
        }

        return try DispatchQueue.main.sync {
            try showExternalRuntimeAccessPanel(expectedHomeDirectory: expectedHomeDirectory)
        }
    }

    private static func showExternalRuntimeAccessPanel(expectedHomeDirectory: URL) throws -> URL {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Grant HAVENAgent Runtime Access"
        panel.message = "Binding needs access to your home folder to manage ~/Library/Application Support/HAVENAgent and ~/Library/LaunchAgents outside the app container."
        panel.prompt = "Grant Access"
        panel.directoryURL = expectedHomeDirectory
        panel.showsHiddenFiles = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            throw ProvisioningError.commandFailed(
                "Grant access to your home folder to install HAVENAgentD outside the app container."
            )
        }

        guard selectedURL.standardizedFileURL == expectedHomeDirectory.standardizedFileURL else {
            throw ProvisioningError.commandFailed(
                "Select \(expectedHomeDirectory.path) to grant Binding access to the external HAVENAgent runtime."
            )
        }

        return selectedURL
    }
#endif

    private func refreshState(requester: Identity) async {
        let snapshot = stateQueue.sync { mutableState }
        guard let paths = try? currentPaths() else { return }

        let fileManager = FileManager.default
        let stagedBinaryExists = Self.regularFileExists(at: paths.stagedBinary, fileManager: fileManager)
        let bundledBinaryExists = paths.bundledBinary.map { Self.regularFileExists(at: $0, fileManager: fileManager) } ?? false
        let repoBuildBinaryExists = Self.regularFileExists(at: paths.buildBinary, fileManager: fileManager) || Self.regularFileExists(at: paths.alternateBuildBinary, fileManager: fileManager)
        let installedBinaryExists = Self.regularFileExists(at: paths.installedBinary, fileManager: fileManager)
        let configExists = fileManager.fileExists(atPath: paths.configFile.path)
        let starterAuthFile = paths.agentDirectory.appendingPathComponent("starter-auth.json")
        let starterAuthExists = fileManager.fileExists(atPath: starterAuthFile.path)
        let entityLinkFile = paths.outDirectory.appendingPathComponent("agent-operator-entity-link.json")
        let entityLinkExists = fileManager.fileExists(atPath: entityLinkFile.path)
        let launchAgentExists = fileManager.fileExists(atPath: paths.launchAgentPlist.path)
        let launchAgentLoaded = Self.isLaunchAgentLoaded(label: Self.launchAgentLabel)
        let sproutPath = NSString(string: snapshot.sproutBinaryPath).expandingTildeInPath
        let sproutExists = fileManager.isExecutableFile(atPath: sproutPath)

        let stateJSON = Self.readJSONObject(at: paths.stateDirectory.appendingPathComponent("agent-state.json"))
        let configJSON = Self.readJSONObject(at: paths.configFile)
        let cellRuntimeJSON = Self.readJSONObject(at: paths.stateDirectory.appendingPathComponent("cell-runtime.json"))
        let remoteIntentJSON = Self.readJSONObject(at: paths.stateDirectory.appendingPathComponent("remote-intent-state.json"))
        let portholeJSON = stateJSON["portholeIngress"] as? [String: Any]
        let controlBridgeJSON = cellRuntimeJSON["controlBridge"] as? [String: Any]
        let controlBridge = Self.liveControlBridgeConfiguration(configJSON: configJSON)
        let liveProjection = launchAgentLoaded
            ? await fetchLiveAgentProjection(requester: requester, configuration: controlBridge)
            : nil
        let runtimeStatus = Self.stringValue(fromAny: stateJSON["status"]) ?? "idle"
        let portholePhase = liveProjection?.portholePhase
            ?? Self.stringValue(fromAny: portholeJSON?["phase"])
            ?? "idle"
        let contractID = liveProjection?.connectedContractID
            ?? Self.stringValue(fromAny: portholeJSON?["contractID"])
            ?? "No contract"
        let lastHeartbeatAt = liveProjection?.lastHeartbeatAt
            ?? Self.stringValue(fromAny: stateJSON["lastHeartbeatAt"])
            ?? "No heartbeat yet."
        let lastEventSummary = liveProjection?.lastEventSummary
            ?? Self.stringValue(fromAny: stateJSON["lastEventSummary"])
            ?? "No runtime events recorded yet."
        let lastRuntimeError = liveProjection?.lastError
            ?? Self.stringValue(fromAny: stateJSON["lastError"])
            ?? ""
        let pendingIntents = liveProjection?.pendingIntents
            ?? Self.parsePendingReviewIntents(from: remoteIntentJSON["queuedIntents"])
        let auditEntries = liveProjection?.auditEntries
            ?? Self.parseReviewAuditEntries(from: remoteIntentJSON["auditTrail"])
        let selectedIntentID = pendingIntents.first(where: { $0.id == snapshot.reviewSelectedIntentID })?.id ?? pendingIntents.first?.id ?? ""
        let selectedIntentSummary = pendingIntents.first(where: { $0.id == selectedIntentID })?.summary
            ?? "Select a pending intent to inspect its action, issuer and argument summary."
        let reviewQueueState = pendingIntents.isEmpty
            ? "No verified remote intents are waiting for operator review."
            : "\(pendingIntents.count) verified intent(s) are waiting for explicit operator review before local side effects."
        let reviewAuditState = auditEntries.isEmpty
            ? "No persisted review audit exists yet."
            : liveProjection == nil
                ? "\(auditEntries.count) review decision(s) persisted in remote-intent-state.json."
                : "\(auditEntries.count) review decision(s) fetched live over the local CellProtocol bridge."
        let lastAudit = auditEntries.first
        let controlBridgeEndpoint = liveProjection?.controlBridgeEndpoint
            ?? Self.stringValue(fromAny: controlBridgeJSON?["websocketBaseURL"])
            ?? controlBridge.websocketBaseURL
        let controlBridgeState: String = {
            if Self.supportsLocalAgentRuntime == false {
                return "Local HAVEN agent control is disabled on iOS; use Binding as a viewer or connect from macOS."
            }
            if let liveProjection {
                return liveProjection.controlBridgeState
            }
            if controlBridge.enabled == false {
                return "Local CellProtocol bridge disabled in agent config."
            }
            let phase = Self.stringValue(fromAny: controlBridgeJSON?["phase"]) ?? "idle"
            let error = Self.stringValue(fromAny: controlBridgeJSON?["lastError"]) ?? ""
            if phase.caseInsensitiveCompare("running") == .orderedSame {
                return "Local CellProtocol bridge ready at \(controlBridgeEndpoint) with local token access."
            }
            if !error.isEmpty {
                return "Local CellProtocol bridge failed: \(error)"
            }
            if launchAgentLoaded {
                return "LaunchAgent active; waiting for local CellProtocol bridge at \(controlBridgeEndpoint)."
            }
            return "Local CellProtocol bridge planned for \(controlBridgeEndpoint)."
        }()
        let connectStage: String = {
            if Self.supportsLocalAgentRuntime == false {
                return "Local macOS agent connect is unavailable on iOS"
            }
            if portholePhase.caseInsensitiveCompare("connected") == .orderedSame {
                return "Native porthole connected"
            }
            if portholePhase.caseInsensitiveCompare("connecting") == .orderedSame {
                return "Connecting to scaffold bridge"
            }
            if portholePhase.caseInsensitiveCompare("failed") == .orderedSame {
                return "Scaffold join failed"
            }
            if !lastRuntimeError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Join reported an error"
            }
            if launchAgentLoaded {
                return "Agent running; waiting for join"
            }
            return "No scaffold contract yet"
        }()

        let installStage: String = {
            if Self.supportsLocalAgentRuntime == false {
                return "Local HAVEN agent install is only available on macOS"
            }
            if installedBinaryExists { return "Installed in Application Support" }
            if stagedBinaryExists { return "Staged binary ready to install" }
            if bundledBinaryExists { return "Bundled binary ready to install" }
            if repoBuildBinaryExists { return "Build output ready to install" }
            if fileManager.fileExists(atPath: paths.packageDirectory.appendingPathComponent("Package.swift").path) {
                return "Ready to build from source"
            }
            return "HavenAgentD source package not found"
        }()

        let runtimeStage: String = {
            if Self.supportsLocalAgentRuntime == false {
                return "LaunchAgent runtime unavailable on iOS"
            }
            if liveProjection != nil { return "LaunchAgent active with live CellProtocol bridge" }
            if launchAgentLoaded { return "LaunchAgent is active" }
            if launchAgentExists { return "LaunchAgent ready to start" }
            return "LaunchAgent not prepared"
        }()

        let binaryState = installedBinaryExists
            ? "Installed binary: \(paths.installedBinary.path)"
            : (
                stagedBinaryExists ? "Staged binary: \(paths.stagedBinary.path)"
                : (bundledBinaryExists ? "Bundled binary: \(paths.bundledBinary?.path ?? "")"
                : (repoBuildBinaryExists ? "Build available in \(paths.packageDirectory.path)" : "No built agent binary detected."))
            )
        let configState: String = {
            if configExists && starterAuthExists && entityLinkExists {
                return "Config written to \(paths.configFile.path) with starter auth and entity-link evidence."
            }
            if configExists && starterAuthExists {
                return "Config written to \(paths.configFile.path) with starter auth at \(starterAuthFile.path); entity-link evidence is still missing at \(entityLinkFile.path)"
            }
            if configExists {
                return "Config written to \(paths.configFile.path); starter auth is still missing at \(starterAuthFile.path)"
            }
            return "Config will be written to \(paths.configFile.path)"
        }()
        let launchAgentState: String = {
            if Self.supportsLocalAgentRuntime == false {
                return "LaunchAgent plists are only used on macOS."
            }
            if Self.isLaunchAgentRunning(label: Self.launchAgentLabel) {
                return "Running as \(Self.launchctlServiceTarget())"
            }
            return launchAgentLoaded
                ? "Loaded as \(Self.launchctlServiceTarget())"
                : (launchAgentExists ? "Plist ready in \(paths.launchAgentPlist.path)" : "Launch agent plist will be written to \(paths.launchAgentPlist.path)")
        }()
        let sproutState = sproutExists
            ? "Sprout executable present at \(sproutPath)"
            : "Sprout executable missing at \(sproutPath)"
        let lastAction = snapshot.lastAction
        let lastError = lastRuntimeError.isEmpty ? snapshot.lastError : lastRuntimeError

        stateQueue.sync {
            mutableState.installStage = installStage
            mutableState.runtimeStage = runtimeStage
            mutableState.connectStage = connectStage
            mutableState.binaryState = binaryState
            mutableState.configState = configState
            mutableState.launchAgentState = launchAgentState
            mutableState.sproutState = sproutState
            mutableState.controlBridgeState = controlBridgeState
            mutableState.controlBridgeEndpoint = controlBridgeEndpoint
            mutableState.portholePhase = portholePhase
            mutableState.connectedContractID = contractID
            mutableState.lastHeartbeatAt = lastHeartbeatAt
            mutableState.lastEventSummary = lastEventSummary
            mutableState.lastAction = lastAction
            mutableState.lastError = lastError
            mutableState.reviewQueueState = reviewQueueState
            mutableState.reviewAuditState = reviewAuditState
            mutableState.reviewPendingCount = pendingIntents.count
            mutableState.reviewAuditCount = auditEntries.count
            mutableState.reviewSelectedIntentID = selectedIntentID
            mutableState.reviewSelectedSummary = selectedIntentSummary
            mutableState.reviewLastOutcome = lastAudit?.outcome ?? ""
            mutableState.reviewLastRecordedAt = lastAudit?.recordedAt ?? ""
            mutableState.pendingIntents = pendingIntents
            mutableState.auditEntries = auditEntries
        }

        if snapshot.activity.isEmpty {
            await emitStateUpdate(title: "Provisioning surface ready", detail: runtimeStatus, tone: "muted", requester: requester)
        }
    }

    private func fetchLiveAgentProjection(
        requester: Identity,
        configuration: LiveControlBridgeConfiguration
    ) async -> LiveAgentProjection? {
        guard configuration.enabled else {
            return nil
        }

        do {
            guard let supervisor = try await remoteAgentCell(
                targetCellReference: "agent/supervisor",
                configuration: configuration,
                requester: requester
            ),
            let inbox = try await remoteAgentCell(
                targetCellReference: "agent/intents/inbox",
                configuration: configuration,
                requester: requester
            ),
            let review = try await remoteAgentCell(
                targetCellReference: "agent/intents/review",
                configuration: configuration,
                requester: requester
            ) else {
                return nil
            }

            let supervisorState = try await supervisor.get(keypath: "state", requester: requester)
            let queueValue = try await inbox.get(keypath: "queue", requester: requester)
            let auditValue = try await review.get(keypath: "audit", requester: requester)

            guard case let .object(stateObject) = supervisorState else {
                return nil
            }

            let portholeObject = Self.objectValue(from: stateObject["porthole"]) ?? [:]
            let controlBridgeObject = Self.objectValue(from: stateObject["controlBridge"]) ?? [:]
            let controlBridgeEndpoint = Self.valueString(controlBridgeObject["websocketBaseURL"]) ?? configuration.websocketBaseURL
            let controlBridgePhase = Self.valueString(controlBridgeObject["phase"]) ?? "running"
            let controlBridgeState: String = {
                let error = Self.valueString(controlBridgeObject["lastError"]) ?? ""
                if !error.isEmpty {
                    return "Local CellProtocol bridge reported \(controlBridgePhase): \(error)"
                }
                if controlBridgePhase.caseInsensitiveCompare("running") == .orderedSame {
                    return "Live CellProtocol bridge active at \(controlBridgeEndpoint) with local token access."
                }
                return "Local CellProtocol bridge reported \(controlBridgePhase) at \(controlBridgeEndpoint)."
            }()

            return LiveAgentProjection(
                portholePhase: Self.valueString(portholeObject["phase"]) ?? "idle",
                connectedContractID: Self.valueString(portholeObject["contractID"]) ?? "No contract",
                lastHeartbeatAt: Self.valueString(stateObject["lastHeartbeatAt"]) ?? "No heartbeat yet.",
                lastEventSummary: Self.valueString(stateObject["lastEventSummary"]) ?? "No runtime events recorded yet.",
                lastError: Self.valueString(stateObject["lastError"]) ?? "",
                pendingIntents: Self.parsePendingReviewIntents(fromValue: queueValue),
                auditEntries: Self.parseReviewAuditEntries(fromValue: auditValue),
                controlBridgeState: controlBridgeState,
                controlBridgeEndpoint: controlBridgeEndpoint
            )
        } catch {
            return nil
        }
    }

    private func remoteAgentCell(
        targetCellReference: String,
        configuration: LiveControlBridgeConfiguration,
        requester: Identity
    ) async throws -> Meddle? {
        guard let endpoint = configuration.endpoint(forTargetCellReference: targetCellReference),
              let resolver = CellBase.defaultCellResolver as? CellResolver else {
            return nil
        }
        let cell = try await RemoteEndpointAccessSupport.resolveMeddle(
            endpoint: endpoint,
            resolver: resolver,
            requester: requester,
            accessLabel: "agentProvisioning.controlBridge"
        )
        return cell
    }

    private func emitStateUpdate(title: String, detail: String, tone: String, requester: Identity) async {
        let timestamp = Self.iso8601String(Date())
        let entry = ActivityEntry(title: title, detail: detail, timestamp: timestamp, tone: tone)
        stateQueue.sync {
            mutableState.activity.insert(entry, at: 0)
            if mutableState.activity.count > Self.maxActivityEntries {
                mutableState.activity.removeLast(mutableState.activity.count - Self.maxActivityEntries)
            }
        }

        var flowElement = FlowElement(
            id: UUID().uuidString,
            title: title,
            content: .object(entry.asObject()),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = Self.feedTopic
        pushFlowElement(flowElement, requester: requester)
    }

    private func recordFailure(action: String, error: Error, requester: Identity) async {
        let detail = error.localizedDescription
        stateQueue.sync {
            mutableState.lastAction = action
            mutableState.lastError = detail
        }
        await emitStateUpdate(title: action, detail: detail, tone: "critical", requester: requester)
    }

    private func value(forReadableKey key: String) -> ValueType {
        switch key {
        case "state":
            return .object(rootStateObject())
        case "agent.setup.state":
            return .object(setupStateObject())
        default:
            return lookupValue(for: key, in: .object(rootStateObject())) ?? .null
        }
    }

    private func rootStateObject() -> Object {
        [
            "agent": .object([
                "setup": .object(setupStateObject())
            ])
        ]
    }

    private func setupStateObject() -> Object {
        let snapshot = stateQueue.sync { mutableState }
        let paths = try? currentPaths()
        let purposeBinding = "\(snapshot.purposeName) -> \(snapshot.purposeRef) [\(snapshot.purposeSource)]"
        let domain = sanitizedBaseURL(for: snapshot.domain)
        let discovery = "\(domain)/v1/bridges/query"

        return [
            "status": .object([
                "installStage": .string(snapshot.installStage),
                "runtimeStage": .string(snapshot.runtimeStage),
                "connectStage": .string(snapshot.connectStage),
                "binaryState": .string(snapshot.binaryState),
                "configState": .string(snapshot.configState),
                "launchAgentState": .string(snapshot.launchAgentState),
                "sproutState": .string(snapshot.sproutState),
                "controlBridgeState": .string(snapshot.controlBridgeState),
                "controlBridgeEndpoint": .string(snapshot.controlBridgeEndpoint),
                "portholeStrategy": .string("Use one local control porthole for operator workbenches. Remote peers stay headless over CellProtocol without a dedicated porthole per connection."),
                "portholePhase": .string(snapshot.portholePhase),
                "connectedContractID": .string(snapshot.connectedContractID),
                "lastHeartbeatAt": .string(snapshot.lastHeartbeatAt),
                "lastEventSummary": .string(snapshot.lastEventSummary),
                "lastAction": .string(snapshot.lastAction),
                "lastError": .string(snapshot.lastError),
                "purposeBinding": .string(purposeBinding),
                "domain": .string(snapshot.domain),
                "resolverBaseURL": .string(domain),
                "discoveryURL": .string(discovery)
            ]),
            "purpose": .object([
                "name": .string(snapshot.purposeName),
                "ref": .string(snapshot.purposeRef),
                "goal": .string(snapshot.goal),
                "interests": .string(snapshot.interestsText),
                "source": .string(snapshot.purposeSource)
            ]),
            "environment": .object([
                "sourceRoot": .string(snapshot.sourceRootPath),
                "sproutBinaryPath": .string(snapshot.sproutBinaryPath),
                "configPath": .string(paths?.configFile.path ?? ""),
                "launchAgentPlistPath": .string(paths?.launchAgentPlist.path ?? ""),
                "installBinaryPath": .string(paths?.installedBinary.path ?? "")
            ]),
            "review": .object([
                "pendingCount": .integer(snapshot.reviewPendingCount),
                "auditCount": .integer(snapshot.reviewAuditCount),
                "queueState": .string(snapshot.reviewQueueState),
                "auditState": .string(snapshot.reviewAuditState),
                "selectedIntentID": .string(snapshot.reviewSelectedIntentID),
                "selectedSummary": .string(snapshot.reviewSelectedSummary),
                "noteDraft": .string(snapshot.reviewNoteDraft),
                "lastOutcome": .string(snapshot.reviewLastOutcome),
                "lastRecordedAt": .string(snapshot.reviewLastRecordedAt),
                "pending": .list(snapshot.pendingIntents.map { .object($0.asObject()) }),
                "audit": .list(snapshot.auditEntries.map { .object($0.asObject()) })
            ]),
            "pipeline": .list(pipelineObjects(from: snapshot)),
            "activity": .list(snapshot.activity.map { .object($0.asObject()) })
        ]
    }

    private func pipelineObjects(from snapshot: MutableState) -> [ValueType] {
        let interests = parsedInterests(from: snapshot.interestsText)
        return [
            .object([
                "title": .string("Purpose profile"),
                "status": .string(interests.isEmpty ? "Needs interests" : "Ready"),
                "detail": .string("\(snapshot.purposeName) [\(snapshot.purposeSource)]")
            ]),
            .object([
                "title": .string("Config + policy"),
                "status": .string(snapshot.configState.hasPrefix("Config written") ? "Written" : "Pending"),
                "detail": .string(snapshot.configState)
            ]),
            .object([
                "title": .string("Agent binary"),
                "status": .string(snapshot.installStage),
                "detail": .string(snapshot.binaryState)
            ]),
            .object([
                "title": .string("LaunchAgent"),
                "status": .string(snapshot.runtimeStage),
                "detail": .string(snapshot.launchAgentState)
            ]),
            .object([
                "title": .string("Local control bridge"),
                "status": .string(snapshot.controlBridgeState),
                "detail": .string(snapshot.controlBridgeEndpoint)
            ]),
            .object([
                "title": .string("Bridge join"),
                "status": .string(snapshot.connectStage),
                "detail": .string("Porthole phase: \(snapshot.portholePhase), contract: \(snapshot.connectedContractID)")
            ]),
            .object([
                "title": .string("Review boundary"),
                "status": .string(snapshot.reviewPendingCount == 0 ? "Queue empty" : "\(snapshot.reviewPendingCount) pending"),
                "detail": .string(snapshot.reviewQueueState)
            ]),
            .object([
                "title": .string("Topology"),
                "status": .string("Single operator porthole"),
                "detail": .string("CellProtocol for every connection. Porthole only when a human needs a control surface.")
            ])
        ]
    }

    private func lookupValue(for keyPath: String, in value: ValueType) -> ValueType? {
        let parts = keyPath.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return value }

        var current = value
        for part in parts {
            guard case let .object(object) = current,
                  let next = object[part] else {
                return nil
            }
            current = next
        }
        return current
    }

    private func makeAgentConfigObject(paths: AgentPaths, requester: Identity?) -> [String: Any] {
        let snapshot = stateQueue.sync { mutableState }
        let interests = parsedInterests(from: snapshot.interestsText)
        let baseURL = sanitizedBaseURL(for: snapshot.domain)
        let existingConfig = Self.readJSONObject(at: paths.configFile)
        let accessToken = Self.existingControlBridgeAccessToken(configJSON: existingConfig) ?? Self.generatedControlBridgeAccessToken()
        let automationPolicy = Self.mergedAutomationPolicy(existingConfig: existingConfig, defaultDomain: baseURL)
        let remoteIntentPolicy = Self.mergedRemoteIntentPolicy(
            existingConfig: existingConfig,
            trustedOperatorIssuer: Self.trustedOperatorIssuer(from: requester)
        )
        let watchFolders = (existingConfig["watchFolders"] as? [Any]) ?? []

        return [
            "instanceName": "haven-agentd",
            "heartbeatIntervalSeconds": 30,
            "scaffold": [
                "sproutBinaryPath": NSString(string: snapshot.sproutBinaryPath).expandingTildeInPath,
                "startupMode": "join",
                "runtime": "macos-app",
                "domain": snapshot.domain,
                "purpose": snapshot.purposeRef.isEmpty ? Self.portablePurposeRef(from: snapshot.purposeName) : snapshot.purposeRef,
                "goal": snapshot.goal,
                "interests": interests.isEmpty ? ["cellprotocol", "agent", "automation"] : interests,
                "resolverBaseURL": baseURL,
                "starterAuthPath": paths.agentDirectory.appendingPathComponent("starter-auth.json").path,
                "entityLinkPath": paths.outDirectory.appendingPathComponent("agent-operator-entity-link.json").path,
                "discoveryURL": "\(baseURL)/v1/bridges/query",
                "catalogPath": NSNull(),
                "enableLiveResolver": true,
                "trustedResolverKey": NSNull(),
                "requestedCapabilities": [
                    "cap.discover",
                    "cap.native_porthole",
                    "cap.local_automation"
                ],
                "requestedPortholeKind": "native",
                "renewalLeadTimeSeconds": 900,
                "portholeHealthPollSeconds": 5,
                "portholeRetryBaseDelaySeconds": 5,
                "portholeRetryMaxDelaySeconds": 60
            ],
            "localControlBridge": [
                "enabled": true,
                "host": Self.defaultControlBridge.host,
                "port": Self.defaultControlBridge.port,
                "accessToken": accessToken,
                "routes": [
                    [
                        "name": Self.defaultControlBridge.routeNamesByTarget["agent/identity"] ?? "agent-identity",
                        "targetCellReference": "agent/identity",
                        "description": "Stable local agent identity and enrollment attestation surface."
                    ],
                    [
                        "name": Self.defaultControlBridge.routeNamesByTarget["agent/supervisor"] ?? "agent-supervisor",
                        "targetCellReference": "agent/supervisor",
                        "description": "Read-only runtime and porthole status."
                    ],
                    [
                        "name": Self.defaultControlBridge.routeNamesByTarget["agent/intents/inbox"] ?? "intent-inbox",
                        "targetCellReference": "agent/intents/inbox",
                        "description": "Structured remote-intent queue projection."
                    ],
                    [
                        "name": Self.defaultControlBridge.routeNamesByTarget["agent/intents/review"] ?? "intent-review",
                        "targetCellReference": "agent/intents/review",
                        "description": "Operator review boundary for verified intents."
                    ]
                ]
            ],
            "watchFolders": watchFolders,
            "automationPolicy": automationPolicy,
            "remoteIntentPolicy": remoteIntentPolicy
        ]
    }

    private func parsedInterests(from text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func extractInterestNames(from value: ValueType) -> [String] {
        guard case let .object(object) = value,
              case let .list(items)? = object["interests"] else {
            return []
        }
        return items.compactMap { entry in
            guard case let .object(interestObject) = entry else { return nil }
            return stringValue(from: interestObject["interestName"]) ?? stringValue(from: interestObject["portableInterestRef"])
        }
    }

    private func extractString(from value: ValueType) throws -> String {
        guard case let .string(raw) = value else {
            throw ProvisioningError.invalidStringPayload
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractStringList(from value: ValueType?) -> [String] {
        guard let value else { return [] }
        switch value {
        case .list(let items):
            return items.compactMap { stringValue(from: $0) }.filter { !$0.isEmpty }
        case .string(let string):
            return parsedInterests(from: string)
        default:
            return []
        }
    }

    private func stringValue(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case .string(let string):
            return string
        case .integer(let integer):
            return String(integer)
        case .float(let float):
            return String(float)
        case .bool(let bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private static func stringValue(fromAny value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func valueString(_ value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case .string(let string):
            return string
        case .integer(let integer):
            return String(integer)
        case .float(let float):
            return String(float)
        case .bool(let bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private static func objectValue(from value: ValueType?) -> Object? {
        guard let value, case let .object(object) = value else {
            return nil
        }
        return object
    }

    private static func liveControlBridgeConfiguration(configJSON: [String: Any]) -> LiveControlBridgeConfiguration {
        guard let object = configJSON["localControlBridge"] as? [String: Any] else {
            return defaultControlBridge
        }

        let enabled = (object["enabled"] as? Bool) ?? defaultControlBridge.enabled
        let host = stringValue(fromAny: object["host"]) ?? defaultControlBridge.host
        let port = (object["port"] as? NSNumber)?.intValue ?? defaultControlBridge.port
        let accessToken = stringValue(fromAny: object["accessToken"])
        let routeNamesByTarget = (object["routes"] as? [[String: Any]])?.reduce(into: [String: String]()) { partialResult, entry in
            guard let name = stringValue(fromAny: entry["name"]),
                  let targetCellReference = stringValue(fromAny: entry["targetCellReference"]) else {
                return
            }
            partialResult[targetCellReference] = name
        } ?? defaultControlBridge.routeNamesByTarget

        return LiveControlBridgeConfiguration(
            enabled: enabled,
            host: host,
            port: port,
            accessToken: accessToken,
            routeNamesByTarget: routeNamesByTarget
        )
    }

    private static func existingControlBridgeAccessToken(configJSON: [String: Any]) -> String? {
        guard let bridge = configJSON["localControlBridge"] as? [String: Any],
              let accessToken = stringValue(fromAny: bridge["accessToken"]),
              accessToken.isEmpty == false else {
            return nil
        }
        return accessToken
    }

    private static func generatedControlBridgeAccessToken() -> String {
        "haven-control-\(UUID().uuidString.lowercased())"
    }

    private static func trustedOperatorIssuer(from requester: Identity?) -> [String: Any]? {
        guard let requester,
              let publicKey = requester.publicSecureKey?.compressedKey else {
            return nil
        }
        return [
            "issuerID": "\(defaultTestIssuerPrefix).\(requester.uuid.lowercased())",
            "publicSigningKeyBase64": publicKey.base64EncodedString(),
            "allowedTopics": ["intent.inbox"],
            "allowedActionIDs": [defaultTestAppleScriptID]
        ]
    }

    private static func mergedAutomationPolicy(
        existingConfig: [String: Any],
        defaultDomain: String
    ) -> [String: Any] {
        let existingPolicy = existingConfig["automationPolicy"] as? [String: Any] ?? [:]
        let shortcuts = (existingPolicy["shortcuts"] as? [Any]) ?? []
        var appleScripts = (existingPolicy["appleScripts"] as? [[String: Any]]) ?? []
        if !appleScripts.contains(where: { stringValue(fromAny: $0["id"]) == defaultTestAppleScriptID }) {
            appleScripts.append(defaultSafariTestAppleScriptDefinition(defaultDomain: defaultDomain))
        }
        return [
            "shortcuts": shortcuts,
            "appleScripts": appleScripts
        ]
    }

    private static func mergedRemoteIntentPolicy(
        existingConfig: [String: Any],
        trustedOperatorIssuer: [String: Any]?
    ) -> [String: Any] {
        let existingPolicy = existingConfig["remoteIntentPolicy"] as? [String: Any] ?? [:]
        var issuers = (existingPolicy["issuers"] as? [[String: Any]]) ?? []
        if let trustedOperatorIssuer,
           let issuerID = stringValue(fromAny: trustedOperatorIssuer["issuerID"]),
           !issuers.contains(where: { stringValue(fromAny: $0["issuerID"]) == issuerID }) {
            issuers.append(trustedOperatorIssuer)
        }
        return [
            "issuers": issuers,
            "requireExpiry": (existingPolicy["requireExpiry"] as? Bool) ?? true,
            "maxClockSkewSeconds": (existingPolicy["maxClockSkewSeconds"] as? NSNumber)?.intValue ?? 300,
            "maxArgumentCount": (existingPolicy["maxArgumentCount"] as? NSNumber)?.intValue ?? 16
        ]
    }

    private static func defaultSafariTestAppleScriptDefinition(defaultDomain: String) -> [String: Any] {
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
        return [
            "id": defaultTestAppleScriptID,
            "description": "Open a validated URL in Safari from the Binding review smoke test.",
            "source": script,
            "argumentOrder": ["url"],
            "argumentConstraints": [
                "url": [
                    "required": true,
                    "maxLength": 1024,
                    "allowedValues": [],
                    "pattern": #"https://[A-Za-z0-9\.\-/_~:%\?#\[\]@!\$&'\(\)\*\+,;=]+"#
                ]
            ],
            "allowedForRemoteExecution": true,
            "requiresUserSession": true,
            "defaultPreviewURL": defaultDomain
        ]
    }

    private static func makeSignedTestIntentEnvelope(
        requester: Identity,
        domain: String
    ) async throws -> (payload: SignedTestIntentPayload, signatureBase64: String) {
        guard requester.publicSecureKey?.compressedKey != nil else {
            throw ProvisioningError.commandFailed("Operator identity is missing a public signing key.")
        }

        let issuedAt = Date()
        let issuerID = "\(defaultTestIssuerPrefix).\(requester.uuid.lowercased())"
        let payload = SignedTestIntentPayload(
            issuerID: issuerID,
            nonce: "binding-safari-test-\(UUID().uuidString.lowercased())",
            topic: "intent.inbox",
            origin: issuerID,
            actionID: defaultTestAppleScriptID,
            arguments: ["url": domain],
            issuedAt: iso8601String(issuedAt),
            expiresAt: iso8601String(issuedAt.addingTimeInterval(300))
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payloadData = try encoder.encode(payload)
        guard let signature = try await requester.sign(data: payloadData) else {
            throw ProvisioningError.commandFailed("Operator identity failed to sign the review test intent.")
        }

        return (payload: payload, signatureBase64: signature.base64EncodedString())
    }

    private static func signedEnvelopeValue(
        _ envelope: (payload: SignedTestIntentPayload, signatureBase64: String)
    ) -> ValueType {
        .object([
            "payload": .object([
                "issuerID": .string(envelope.payload.issuerID),
                "nonce": .string(envelope.payload.nonce),
                "topic": .string(envelope.payload.topic),
                "origin": .string(envelope.payload.origin),
                "actionID": .string(envelope.payload.actionID),
                "arguments": .object(envelope.payload.arguments.mapValues(ValueType.string)),
                "issuedAt": .string(envelope.payload.issuedAt),
                "expiresAt": envelope.payload.expiresAt.map(ValueType.string) ?? .null
            ]),
            "signatureBase64": .string(envelope.signatureBase64)
        ])
    }

    private static func parsePendingReviewIntents(fromValue value: ValueType?) -> [ReviewIntentEntry] {
        guard let value, case let .list(items) = value else {
            return []
        }

        return items.compactMap { entry in
            guard case let .object(object) = entry else { return nil }
            let id = valueString(object["id"]) ?? ""
            guard !id.isEmpty else { return nil }
            let topic = valueString(object["topic"]) ?? "intent.inbox"
            let origin = valueString(object["origin"]) ?? "unknown-origin"
            let actionID = valueString(object["actionID"]) ?? "unknown-action"
            let issuerID = valueString(object["issuerID"]) ?? "unknown-issuer"
            let verificationStatus = valueString(object["verificationStatus"]) ?? "unknown"
            let receivedAt = valueString(object["receivedAt"]) ?? "Unknown time"
            let expiresAt = valueString(object["expiresAt"]) ?? "No expiry"
            let argumentsSummary = summarizedArguments(fromValue: object["arguments"])
            let summary = "\(actionID) from \(issuerID) via \(origin)"
            return ReviewIntentEntry(
                id: id,
                topic: topic,
                origin: origin,
                actionID: actionID,
                issuerID: issuerID,
                verificationStatus: verificationStatus,
                receivedAt: receivedAt,
                expiresAt: expiresAt,
                argumentsSummary: argumentsSummary,
                summary: summary
            )
        }
    }

    private static func parseReviewAuditEntries(fromValue value: ValueType?) -> [ReviewAuditEntry] {
        guard let value, case let .list(items) = value else {
            return []
        }

        return items.reversed().compactMap { entry in
            guard case let .object(object) = entry else { return nil }
            let intentID = valueString(object["intentID"]) ?? ""
            let actionID = valueString(object["actionID"]) ?? "unknown-action"
            let outcome = valueString(object["outcome"]) ?? "unknown"
            let reviewer = valueString(object["reviewer"]) ?? "unknown-reviewer"
            let note = valueString(object["note"]) ?? ""
            let recordedAt = valueString(object["recordedAt"]) ?? "Unknown time"
            let issuerID = valueString(object["issuerID"]) ?? "unknown-issuer"
            let errorMessage = valueString(object["errorMessage"]) ?? ""
            let executedActionSummary = summarizedExecutedAction(fromValue: object["executedAction"])
            return ReviewAuditEntry(
                intentID: intentID,
                actionID: actionID,
                outcome: outcome,
                reviewer: reviewer,
                note: note.isEmpty ? "No operator note." : note,
                recordedAt: recordedAt,
                issuerID: issuerID,
                executedActionSummary: executedActionSummary,
                errorMessage: errorMessage
            )
        }
    }

    private static func parsePendingReviewIntents(from value: Any?) -> [ReviewIntentEntry] {
        guard let items = value as? [[String: Any]] else {
            return []
        }

        return items.compactMap { object in
            let id = stringValue(fromAny: object["id"]) ?? ""
            guard !id.isEmpty else { return nil }
            let topic = stringValue(fromAny: object["topic"]) ?? "intent.inbox"
            let origin = stringValue(fromAny: object["origin"]) ?? "unknown-origin"
            let actionID = stringValue(fromAny: object["actionID"]) ?? "unknown-action"
            let issuerID = stringValue(fromAny: object["issuerID"]) ?? "unknown-issuer"
            let verificationStatus = stringValue(fromAny: object["verificationStatus"]) ?? "unknown"
            let receivedAt = stringValue(fromAny: object["receivedAt"]) ?? "Unknown time"
            let expiresAt = stringValue(fromAny: object["expiresAt"]) ?? "No expiry"
            let argumentsSummary = summarizedArguments(from: object["arguments"])
            let summary = "\(actionID) from \(issuerID) via \(origin)"
            return ReviewIntentEntry(
                id: id,
                topic: topic,
                origin: origin,
                actionID: actionID,
                issuerID: issuerID,
                verificationStatus: verificationStatus,
                receivedAt: receivedAt,
                expiresAt: expiresAt,
                argumentsSummary: argumentsSummary,
                summary: summary
            )
        }
    }

    private static func parseReviewAuditEntries(from value: Any?) -> [ReviewAuditEntry] {
        guard let items = value as? [[String: Any]] else {
            return []
        }

        return items.reversed().map { object in
            let intentID = stringValue(fromAny: object["intentID"]) ?? ""
            let actionID = stringValue(fromAny: object["actionID"]) ?? "unknown-action"
            let outcome = stringValue(fromAny: object["outcome"]) ?? "unknown"
            let reviewer = stringValue(fromAny: object["reviewer"]) ?? "unknown-reviewer"
            let note = stringValue(fromAny: object["note"]) ?? ""
            let recordedAt = stringValue(fromAny: object["recordedAt"]) ?? "Unknown time"
            let issuerID = stringValue(fromAny: object["issuerID"]) ?? "unknown-issuer"
            let errorMessage = stringValue(fromAny: object["errorMessage"]) ?? ""
            let executedActionSummary = summarizedExecutedAction(from: object["executedAction"])
            return ReviewAuditEntry(
                intentID: intentID,
                actionID: actionID,
                outcome: outcome,
                reviewer: reviewer,
                note: note.isEmpty ? "No operator note." : note,
                recordedAt: recordedAt,
                issuerID: issuerID,
                executedActionSummary: executedActionSummary,
                errorMessage: errorMessage
            )
        }
    }

    private static func summarizedArguments(from value: Any?) -> String {
        guard let arguments = value as? [String: Any], !arguments.isEmpty else {
            return "No arguments"
        }
        return arguments.keys.sorted().compactMap { key in
            guard let text = stringValue(fromAny: arguments[key]) else { return nil }
            return "\(key)=\(text)"
        }
        .joined(separator: ", ")
    }

    private static func summarizedArguments(fromValue value: ValueType?) -> String {
        guard let value, case let .object(arguments) = value, !arguments.isEmpty else {
            return "No arguments"
        }
        return arguments.keys.sorted().compactMap { key in
            guard let text = valueString(arguments[key]) else { return nil }
            return "\(key)=\(text)"
        }
        .joined(separator: ", ")
    }

    private static func summarizedExecutedAction(from value: Any?) -> String {
        guard let object = value as? [String: Any] else {
            return "No local action executed."
        }
        let kind = stringValue(fromAny: object["kind"]) ?? "unknown"
        let id = stringValue(fromAny: object["id"]) ?? "unknown"
        let status = stringValue(fromAny: object["status"]) ?? "unknown"
        return "\(kind) \(id) [\(status)]"
    }

    private static func summarizedExecutedAction(fromValue value: ValueType?) -> String {
        guard let object = objectValue(from: value) else {
            return "No local action executed."
        }
        let kind = valueString(object["kind"]) ?? "unknown"
        let id = valueString(object["id"]) ?? "unknown"
        let status = valueString(object["status"]) ?? "unknown"
        return "\(kind) \(id) [\(status)]"
    }

    private func sanitizedBaseURL(for domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "https://\(Self.defaultDomain)" }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return "https://\(trimmed)"
    }

    private static func portablePurposeRef(from purposeName: String) -> String {
        let lowercase = purposeName.lowercased()
        let allowed = lowercase.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }
        let collapsed = String(allowed)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "purpose://\(collapsed.isEmpty ? "operate-local-haven-agent" : collapsed)"
    }

    private static func launchctlServiceTarget() -> String {
#if os(macOS)
        "gui/\(getuid())/\(launchAgentLabel)"
#else
        launchAgentLabel
#endif
    }

    private static func isLaunchAgentLoaded(label: String) -> Bool {
#if os(macOS)
        guard let result = try? runCommand("/bin/launchctl", arguments: ["print", "gui/\(getuid())/\(label)"]) else {
            return false
        }
        return result.succeeded
#else
        false
#endif
    }

    private static func isLaunchAgentRunning(label: String) -> Bool {
#if os(macOS)
        guard let result = try? runCommand("/bin/launchctl", arguments: ["print", "gui/\(getuid())/\(label)"]),
              result.succeeded else {
            return false
        }
        let output = "\(result.standardOutput)\n\(result.standardError)"
        return output.range(of: "state = running") != nil
#else
        false
#endif
    }

    private static func readJSONObject(at fileURL: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private static func runCommand(
        _ executablePath: String,
        arguments: [String],
        currentDirectory: URL? = nil
    ) throws -> CommandResult {
#if os(macOS)
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        try process.run()
        process.waitUntilExit()

        let standardOutput = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let standardError = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return CommandResult(
            status: process.terminationStatus,
            standardOutput: standardOutput,
            standardError: standardError
        )
#else
        throw ProvisioningError.unsupportedPlatform("Running local process commands")
#endif
    }

    private static func trimmedOutput(from result: CommandResult) -> String {
        let merged = [result.standardError, result.standardOutput]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(merged.prefix(600))
    }

    private static func renderLaunchAgent(executablePath: String, configPath: String, logDirectory: String) -> String {
        let escapedExecutable = xmlEscaped(executablePath)
        let escapedConfig = xmlEscaped(configPath)
        let escapedLogs = xmlEscaped(logDirectory)

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(escapedExecutable)</string>
                <string>run</string>
                <string>--config</string>
                <string>\(escapedConfig)</string>
            </array>
            <key>KeepAlive</key>
            <true/>
            <key>RunAtLoad</key>
            <true/>
            <key>ProcessType</key>
            <string>Interactive</string>
            <key>StandardOutPath</key>
            <string>\(escapedLogs)/stdout.log</string>
            <key>StandardErrorPath</key>
            <string>\(escapedLogs)/stderr.log</string>
        </dict>
        </plist>
        """
    }

    private static func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
