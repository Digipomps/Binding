import Foundation
import CellBase
import CoreFoundation
import Darwin

#if os(macOS)
import AppKit
#endif

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

final class AgentEnrollmentCell: GeneralCell {
    private struct LiveControlBridgeConfiguration {
        var enabled: Bool
        var host: String
        var port: Int
        var accessToken: String?
        var routeNamesByTarget: [String: String]

        nonisolated var websocketBaseURL: String {
            "ws://\(host):\(port)/bridgehead"
        }

        nonisolated func endpoint(forTargetCellReference target: String) -> String? {
            guard let routeName = routeNamesByTarget[target] else {
                return nil
            }
            guard var components = URLComponents(string: "\(websocketBaseURL)/\(routeName)") else {
                return nil
            }
            if let accessToken, !accessToken.isEmpty {
                components.queryItems = [URLQueryItem(name: "token", value: accessToken)]
            }
            return components.url?.absoluteString
        }
    }

    private struct AgentIdentityDescriptor: Codable {
        var instanceName: String
        var identityContext: String
        var identityUUID: String
        var displayName: String
        var publicKeyBase64URL: String
        var didKey: String
        var createdAt: String
        var storageKind: String
    }

    private struct AgentEnrollmentAttestation: Codable {
        struct Payload: Codable {
            var version: String
            var instanceName: String
            var agentIdentityUUID: String
            var agentDisplayName: String
            var agentDid: String
            var agentPublicKeyBase64URL: String
            var operatorIdentityUUID: String
            var operatorDid: String
            var operatorPublicKeyBase64URL: String
            var purposeRef: String
            var scaffoldDomain: String
            var challenge: String
            var issuedAt: String
        }

        var payload: Payload
        var signatureAlgorithm: String
        var signatureBase64URL: String

        func canonicalPayloadData() throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(payload)
        }
    }

    private struct OperatorApproval: Codable {
        struct Payload: Codable {
            var version: String
            var pairingID: String
            var scaffoldDomain: String
            var purposeRef: String
            var challenge: String
            var attestationSHA256Base64URL: String
            var operatorIdentityUUID: String
            var operatorDisplayName: String
            var operatorDid: String
            var operatorPublicKeyBase64URL: String
            var approvedAt: String
        }

        var payload: Payload
        var signatureBase64: String
        var curveType: String

        func canonicalPayloadData() throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(payload)
        }
    }

    private struct PairingArtifact: Codable {
        var version: String
        var pairingID: String
        var recordedAt: String
        var verificationStatus: String
        var agentAttestation: AgentEnrollmentAttestation
        var operatorApproval: OperatorApproval
    }

    private struct StarterPurposeInterest: Codable {
        var purpose: String
        var interests: [String]
    }

    private struct ResolverSignatureEnvelope: Codable {
        var alg: String
        var sig: String
    }

    private struct StarterAuthPayload: Codable {
        var version: String
        var domain: String
        var identity_public_key: String
        var created_at: String
        var expires_at: String
        var nonce: String
        var purpose_interest: StarterPurposeInterest
        var signature: ResolverSignatureEnvelope

        func canonicalPayloadData() throws -> Data {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(self)
            return try JCSCanonicalizer.canonicalizeRemovingTopLevelKeys(encoded, keys: ["signature"])
        }
    }

    private struct EntityLinkRevocation: Codable {
        var mode: String
    }

    private struct EntityLinkSignature: Codable {
        var by_pubkey: String
        var alg: String
        var sig: String
    }

    private struct EntityLinkContract: Codable {
        var contract_id: String
        var domain_a: String
        var pubkey_a: String
        var domain_b: String
        var pubkey_b: String
        var scope: String
        var created_at: String
        var revocation: EntityLinkRevocation
        var signatures: [EntityLinkSignature]

        func canonicalPayloadData() throws -> Data {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(self)
            return try JCSCanonicalizer.canonicalizeRemovingTopLevelKeys(encoded, keys: ["signatures"])
        }
    }

    private struct MutableState: Codable {
        var summary: String
        var operatorDisplayName: String
        var operatorDid: String
        var scaffoldDomain: String
        var purposeRef: String
        var controlBridgeEndpoint: String
        var agentIdentityStatus: String
        var agentDisplayName: String
        var agentDid: String
        var agentPublicKeyBase64URL: String
        var agentIdentityContext: String
        var verificationStatus: String
        var lastArtifactPath: String
        var starterAuthStatus: String
        var starterAuthPath: String
        var starterAuthExpiresAt: String
        var entityLinkStatus: String
        var entityLinkPath: String
        var entityLinkContractID: String
        var lastRecordedAt: String
        var lastAction: String
        var lastError: String
    }

    private struct AgentPaths {
        var applicationSupportDirectory: URL
        var agentDirectory: URL
        var configFile: URL
        var outputDirectory: URL
        var pairingArtifactFile: URL
        var starterAuthFile: URL
        var entityLinkFile: URL
    }

    private enum CodingKeys: String, CodingKey {
        case mutableState
    }

    private enum EnrollmentError: LocalizedError {
        case identityVaultUnavailable
        case operatorIdentityUnavailable
        case purposeUnavailable
        case scaffoldDomainUnavailable
        case controlBridgeUnavailable
        case agentIdentityUnavailable
        case attestationInvalid(String)
        case starterAuthInvalid(String)
        case entityLinkInvalid(String)
        case signingFailed

        var errorDescription: String? {
            switch self {
            case .identityVaultUnavailable:
                return "Identity vault is unavailable."
            case .operatorIdentityUnavailable:
                return "Operator identity is unavailable."
            case .purposeUnavailable:
                return "Purpose ref is unavailable."
            case .scaffoldDomainUnavailable:
                return "Scaffold domain is unavailable."
            case .controlBridgeUnavailable:
                return "Local agent control bridge is unavailable."
            case .agentIdentityUnavailable:
                return "Agent identity is unavailable over the local CellProtocol bridge."
            case .attestationInvalid(let reason):
                return "Agent attestation is invalid: \(reason)"
            case .starterAuthInvalid(let reason):
                return "Starter auth payload is invalid: \(reason)"
            case .entityLinkInvalid(let reason):
                return "Entity-link contract is invalid: \(reason)"
            case .signingFailed:
                return "Operator identity failed to sign the pairing approval."
            }
        }
    }

    nonisolated private static let repositoryRoot: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()
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
    nonisolated private let stateQueue = DispatchQueue(label: "Binding.AgentEnrollmentCell.State")
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
        MutableState(
            summary: "Waiting for a local agent identity over the loopback CellProtocol bridge.",
            operatorDisplayName: "private",
            operatorDid: "unknown",
            scaffoldDomain: "staging.haven.digipomps.org",
            purposeRef: "purpose://operate-local-haven-agent",
            controlBridgeEndpoint: defaultControlBridge.websocketBaseURL,
            agentIdentityStatus: "Agent identity not loaded yet.",
            agentDisplayName: "Unknown agent",
            agentDid: "unknown",
            agentPublicKeyBase64URL: "",
            agentIdentityContext: "",
            verificationStatus: "No pairing artifact recorded yet.",
            lastArtifactPath: "",
            starterAuthStatus: "No starter auth materialized yet.",
            starterAuthPath: "",
            starterAuthExpiresAt: "",
            entityLinkStatus: "No entity-link evidence materialized yet.",
            entityLinkPath: "",
            entityLinkContractID: "",
            lastRecordedAt: "",
            lastAction: "Initialized agent enrollment surface.",
            lastError: ""
        )
    }

    private static let readOnlyKeys: [String] = [
        "state",
        "enrollment.state",
        "enrollment.status.summary",
        "enrollment.status.operatorDisplayName",
        "enrollment.status.operatorDid",
        "enrollment.status.scaffoldDomain",
        "enrollment.status.purposeRef",
        "enrollment.status.controlBridgeEndpoint",
        "enrollment.status.agentIdentityStatus",
        "enrollment.status.agentDisplayName",
        "enrollment.status.agentDid",
        "enrollment.status.agentPublicKeyBase64URL",
        "enrollment.status.agentIdentityContext",
        "enrollment.status.verificationStatus",
        "enrollment.status.lastArtifactPath",
        "enrollment.status.starterAuthStatus",
        "enrollment.status.starterAuthPath",
        "enrollment.status.starterAuthExpiresAt",
        "enrollment.status.entityLinkStatus",
        "enrollment.status.entityLinkPath",
        "enrollment.status.entityLinkContractID",
        "enrollment.status.lastRecordedAt",
        "enrollment.status.lastAction",
        "enrollment.status.lastError"
    ]

    private static let actionKeys: [String] = [
        "enrollment.refresh",
        "enrollment.createPairingArtifact"
    ]

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "flow")
        for key in Self.readOnlyKeys {
            agreementTemplate.addGrant("r---", for: key)
        }
        for key in Self.actionKeys {
            agreementTemplate.addGrant("rw--", for: key)
        }
    }

    private func setupKeys(owner: Identity) async {
        for key in Self.readOnlyKeys {
            await addInterceptForGet(requester: owner, key: key, getValueIntercept: { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                return self.value(forReadableKey: key)
            })
        }

        await registerAction(key: "enrollment.refresh", owner: owner) { [weak self] _, requester in
            guard let self else { return .string("failure") }
            await self.refreshState(requester: requester)
            return self.value(forReadableKey: "enrollment.state")
        }

        await registerAction(key: "enrollment.createPairingArtifact", owner: owner) { [weak self] _, requester in
            guard let self else { return .string("failure") }
            return await self.performAction(
                title: "Created pairing artifact",
                requester: requester
            ) {
                try await self.createPairingArtifact(requester: requester)
            }
        }
    }

    private func registerAction(
        key: String,
        owner: Identity,
        handler: @escaping (ValueType, Identity) async -> ValueType
    ) async {
        await addInterceptForSet(requester: owner, key: key, setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
            return await handler(value, requester)
        })

        await addInterceptForGet(requester: owner, key: key, getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
            return await handler(.null, requester)
        })
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
            return value(forReadableKey: "enrollment.state")
        } catch {
            stateQueue.sync {
                mutableState.lastAction = title
                mutableState.lastError = error.localizedDescription
            }
            await refreshState(requester: requester)
            return value(forReadableKey: "enrollment.state")
        }
    }

    private func createPairingArtifact(requester: Identity) async throws {
        let operatorIdentity = try await resolveOperatorIdentity(requester: requester)
        let operatorDid = (try? operatorIdentity.did()) ?? operatorIdentity.uuid
        guard let operatorPublicKey = operatorIdentity.publicSecureKey?.compressedKey else {
            throw EnrollmentError.operatorIdentityUnavailable
        }

        let purposeRef = try await currentPurposeRef(requester: requester)
        let scaffoldDomain = try await currentScaffoldDomain(requester: requester)
        let interests = try await currentInterests(requester: requester)
        let controlBridge = try currentControlBridgeConfiguration()
        guard controlBridge.enabled,
              let identityCell = try await remoteIdentityCell(
                configuration: controlBridge,
                requester: requester
              ) else {
            throw EnrollmentError.controlBridgeUnavailable
        }

        let challenge = "pair-\(UUID().uuidString.lowercased())"
        let attestationResponse = try await identityCell.set(
            keypath: "enrollment.attest",
            value: .object([
                "challenge": .string(challenge),
                "purposeRef": .string(purposeRef),
                "scaffoldDomain": .string(scaffoldDomain),
                "operatorIdentityUUID": .string(operatorIdentity.uuid),
                "operatorDid": .string(operatorDid),
                "operatorPublicKeyBase64URL": .string(Self.base64URLEncode(operatorPublicKey))
            ]),
            requester: requester
        )

        let attestation = try parseAttestation(from: attestationResponse)
        try verify(attestation: attestation)

        let attestationSHA = Self.sha256Base64URL(try attestation.canonicalPayloadData())
        var approval = OperatorApproval(
            payload: .init(
                version: "1.0",
                pairingID: "pairing-\(UUID().uuidString.lowercased())",
                scaffoldDomain: scaffoldDomain,
                purposeRef: purposeRef,
                challenge: challenge,
                attestationSHA256Base64URL: attestationSHA,
                operatorIdentityUUID: operatorIdentity.uuid,
                operatorDisplayName: operatorIdentity.displayName,
                operatorDid: operatorDid,
                operatorPublicKeyBase64URL: Self.base64URLEncode(operatorPublicKey),
                approvedAt: Self.iso8601String(Date())
            ),
            signatureBase64: "",
            curveType: operatorIdentity.publicSecureKey?.curveType.rawValue ?? "unknown"
        )

        guard let operatorSignature = try await operatorIdentity.sign(data: try approval.canonicalPayloadData()) else {
            throw EnrollmentError.signingFailed
        }
        approval.signatureBase64 = operatorSignature.base64EncodedString()

        let artifact = PairingArtifact(
            version: "1.0",
            pairingID: approval.payload.pairingID,
            recordedAt: approval.payload.approvedAt,
            verificationStatus: "agent-attestation-verified",
            agentAttestation: attestation,
            operatorApproval: approval
        )

        let paths = try currentPaths()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(artifact)
        try FileManager.default.createDirectory(
            at: paths.outputDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: paths.pairingArtifactFile, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: paths.pairingArtifactFile.path
        )

        let starterAuth = try await issueStarterAuth(
            using: identityCell,
            scaffoldDomain: scaffoldDomain,
            purposeRef: purposeRef,
            interests: interests,
            requester: requester
        )
        try writeStarterAuth(starterAuth, to: paths.starterAuthFile)

        let entityLink = try await createEntityLinkContract(
            using: identityCell,
            operatorIdentity: operatorIdentity,
            operatorPublicKey: operatorPublicKey,
            agentPublicKeyBase64URL: attestation.payload.agentPublicKeyBase64URL,
            scaffoldDomain: scaffoldDomain,
            purposeRef: purposeRef,
            recordedAt: approval.payload.approvedAt,
            requester: requester
        )
        try writeEntityLink(entityLink, to: paths.entityLinkFile)
    }

    private func refreshState(requester: Identity) async {
        guard let paths = try? currentPaths() else {
            return
        }

        let operatorIdentity = try? await resolveOperatorIdentity(requester: requester)
        let operatorDid = operatorIdentity.flatMap { try? $0.did() } ?? operatorIdentity?.uuid ?? "unknown"
        let purposeRef = (try? await currentPurposeRef(requester: requester)) ?? stateQueue.sync { mutableState.purposeRef }
        let scaffoldDomain = (try? await currentScaffoldDomain(requester: requester)) ?? stateQueue.sync { mutableState.scaffoldDomain }
        let controlBridge = (try? currentControlBridgeConfiguration()) ?? Self.defaultControlBridge
        let liveIdentity = await fetchLiveAgentIdentity(requester: requester, configuration: controlBridge)

        let artifactJSON = Self.readJSONObject(at: paths.pairingArtifactFile)
        let artifactPath = FileManager.default.fileExists(atPath: paths.pairingArtifactFile.path)
            ? paths.pairingArtifactFile.path
            : ""
        let starterAuthJSON = Self.readJSONObject(at: paths.starterAuthFile)
        let starterAuthPath = FileManager.default.fileExists(atPath: paths.starterAuthFile.path)
            ? paths.starterAuthFile.path
            : ""
        let entityLinkJSON = Self.readJSONObject(at: paths.entityLinkFile)
        let entityLinkPath = FileManager.default.fileExists(atPath: paths.entityLinkFile.path)
            ? paths.entityLinkFile.path
            : ""
        let lastRecordedAt = Self.stringValue(fromAny: artifactJSON["recordedAt"]) ?? ""
        let verificationStatus = Self.stringValue(fromAny: artifactJSON["verificationStatus"])
            ?? (liveIdentity == nil ? "No pairing artifact recorded yet." : "Live agent identity available for pairing.")
        let starterAuthStatus: String = {
            if let expiresAt = Self.stringValue(fromAny: starterAuthJSON["expires_at"]), !expiresAt.isEmpty {
                return "Starter auth ready for sprout bootstrap until \(expiresAt)."
            }
            if !starterAuthPath.isEmpty {
                return "Starter auth materialized for sprout bootstrap."
            }
            return "No starter auth materialized yet."
        }()
        let entityLinkStatus: String = {
            if let contractID = Self.stringValue(fromAny: entityLinkJSON["contract_id"]), !contractID.isEmpty {
                return "Entity-link evidence ready as \(contractID)."
            }
            if !entityLinkPath.isEmpty {
                return "Entity-link evidence materialized for sprout bootstrap."
            }
            return "No entity-link evidence materialized yet."
        }()
        let summary: String = {
            if !starterAuthPath.isEmpty, !entityLinkPath.isEmpty, let liveIdentity {
                return "Agent identity \(liveIdentity.displayName) is paired, has a purpose-bound starter auth payload, and a mutual entity-link contract ready for sprout bootstrap evidence."
            }
            if !starterAuthPath.isEmpty, let liveIdentity {
                return "Agent identity \(liveIdentity.displayName) is paired and has a purpose-bound starter auth payload ready for sprout bootstrap."
            }
            if let liveIdentity {
                return "Agent identity \(liveIdentity.displayName) is reachable over the loopback CellProtocol bridge and ready for purpose-bound pairing."
            }
            if controlBridge.enabled == false {
                return "Agent control bridge is disabled in local config."
            }
            return "Waiting for a running agent identity over \(controlBridge.websocketBaseURL)."
        }()

        stateQueue.sync {
            mutableState.summary = summary
            mutableState.operatorDisplayName = operatorIdentity?.displayName ?? "private"
            mutableState.operatorDid = operatorDid
            mutableState.scaffoldDomain = scaffoldDomain
            mutableState.purposeRef = purposeRef
            mutableState.controlBridgeEndpoint = controlBridge.websocketBaseURL
            mutableState.agentIdentityStatus = liveIdentity == nil
                ? "Agent identity is not reachable yet."
                : "Live agent identity verified over the local CellProtocol bridge."
            mutableState.agentDisplayName = liveIdentity?.displayName ?? "Unknown agent"
            mutableState.agentDid = liveIdentity?.didKey ?? "unknown"
            mutableState.agentPublicKeyBase64URL = liveIdentity?.publicKeyBase64URL ?? ""
            mutableState.agentIdentityContext = liveIdentity?.identityContext ?? ""
            mutableState.verificationStatus = verificationStatus
            mutableState.lastArtifactPath = artifactPath
            mutableState.starterAuthStatus = starterAuthStatus
            mutableState.starterAuthPath = starterAuthPath
            mutableState.starterAuthExpiresAt = Self.stringValue(fromAny: starterAuthJSON["expires_at"]) ?? ""
            mutableState.entityLinkStatus = entityLinkStatus
            mutableState.entityLinkPath = entityLinkPath
            mutableState.entityLinkContractID = Self.stringValue(fromAny: entityLinkJSON["contract_id"]) ?? ""
            mutableState.lastRecordedAt = lastRecordedAt
        }
    }

    private func fetchLiveAgentIdentity(
        requester: Identity,
        configuration: LiveControlBridgeConfiguration
    ) async -> AgentIdentityDescriptor? {
        guard configuration.enabled,
              let cell = try? await remoteIdentityCell(configuration: configuration, requester: requester),
              let value = try? await cell.get(keypath: "descriptor", requester: requester) else {
            return nil
        }
        return try? parseAgentIdentity(from: value)
    }

    private func remoteIdentityCell(
        configuration: LiveControlBridgeConfiguration,
        requester: Identity
    ) async throws -> Meddle? {
        guard let endpoint = configuration.endpoint(forTargetCellReference: "agent/identity"),
              let resolver = CellBase.defaultCellResolver as? CellResolver else {
            return nil
        }
        let cell = try await RemoteEndpointAccessSupport.resolveMeddle(
            endpoint: endpoint,
            resolver: resolver,
            requester: requester,
            accessLabel: "agentEnrollment.identityBridge"
        )
        return cell
    }

    private func resolveOperatorIdentity(requester: Identity) async throws -> Identity {
        if requester.displayName.isEmpty == false {
            return requester
        }
        guard let vault = CellBase.defaultIdentityVault else {
            throw EnrollmentError.identityVaultUnavailable
        }
        guard let operatorIdentity = await vault.identity(for: "private", makeNewIfNotFound: true) else {
            throw EnrollmentError.operatorIdentityUnavailable
        }
        return operatorIdentity
    }

    private func currentPurposeRef(requester: Identity) async throws -> String {
        if let resolver = CellBase.defaultCellResolver as? CellResolver,
           let provisioning = try? await resolver.cellAtEndpoint(endpoint: "cell:///AgentProvisioning", requester: requester) as? Meddle,
           let value = try? await provisioning.get(keypath: "agent.setup.purpose.ref", requester: requester),
           let purposeRef = Self.stringValue(fromValue: value),
           !purposeRef.isEmpty {
            return purposeRef
        }
        let configJSON = Self.readJSONObject(at: try currentPaths().configFile)
        if let scaffold = configJSON["scaffold"] as? [String: Any],
           let purposeRef = Self.stringValue(fromAny: scaffold["purpose"]),
           !purposeRef.isEmpty {
            return purposeRef
        }
        throw EnrollmentError.purposeUnavailable
    }

    private func currentScaffoldDomain(requester: Identity) async throws -> String {
        if let resolver = CellBase.defaultCellResolver as? CellResolver,
           let provisioning = try? await resolver.cellAtEndpoint(endpoint: "cell:///AgentProvisioning", requester: requester) as? Meddle,
           let value = try? await provisioning.get(keypath: "agent.setup.status.domain", requester: requester),
           let domain = Self.stringValue(fromValue: value),
           !domain.isEmpty {
            return domain
        }
        let configJSON = Self.readJSONObject(at: try currentPaths().configFile)
        if let scaffold = configJSON["scaffold"] as? [String: Any],
           let domain = Self.stringValue(fromAny: scaffold["domain"]),
           !domain.isEmpty {
            return domain
        }
        throw EnrollmentError.scaffoldDomainUnavailable
    }

    private func currentInterests(requester: Identity) async throws -> [String] {
        if let resolver = CellBase.defaultCellResolver as? CellResolver,
           let provisioning = try? await resolver.cellAtEndpoint(endpoint: "cell:///AgentProvisioning", requester: requester) as? Meddle,
           let value = try? await provisioning.get(keypath: "agent.setup.purpose.interests", requester: requester),
           let interestText = Self.stringValue(fromValue: value) {
            let interests = Self.parseInterests(from: interestText)
            if !interests.isEmpty {
                return interests
            }
        }

        let configJSON = Self.readJSONObject(at: try currentPaths().configFile)
        if let scaffold = configJSON["scaffold"] as? [String: Any],
           let interests = scaffold["interests"] as? [String] {
            let normalized = interests.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !normalized.isEmpty {
                return normalized
            }
        }
        throw EnrollmentError.starterAuthInvalid("purpose interests are unavailable")
    }

    private func currentControlBridgeConfiguration() throws -> LiveControlBridgeConfiguration {
        let configJSON = Self.readJSONObject(at: try currentPaths().configFile)
        return Self.liveControlBridgeConfiguration(configJSON: configJSON)
    }

    private func parseAgentIdentity(from value: ValueType?) throws -> AgentIdentityDescriptor {
        guard case let .object(object)? = value else {
            throw EnrollmentError.agentIdentityUnavailable
        }
        return AgentIdentityDescriptor(
            instanceName: Self.stringValue(object["instanceName"]),
            identityContext: Self.stringValue(object["identityContext"]),
            identityUUID: Self.stringValue(object["identityUUID"]),
            displayName: Self.stringValue(object["displayName"]),
            publicKeyBase64URL: Self.stringValue(object["publicKeyBase64URL"]),
            didKey: Self.stringValue(object["didKey"]),
            createdAt: Self.stringValue(object["createdAt"]),
            storageKind: Self.stringValue(object["storageKind"])
        )
    }

    private func parseAttestation(from value: ValueType?) throws -> AgentEnrollmentAttestation {
        guard case let .object(object)? = value else {
            throw EnrollmentError.agentIdentityUnavailable
        }
        let payload = AgentEnrollmentAttestation.Payload(
            version: Self.stringValue(object["version"]),
            instanceName: Self.stringValue(object["instanceName"]),
            agentIdentityUUID: Self.stringValue(object["agentIdentityUUID"]),
            agentDisplayName: Self.stringValue(object["agentDisplayName"]),
            agentDid: Self.stringValue(object["agentDid"]),
            agentPublicKeyBase64URL: Self.stringValue(object["agentPublicKeyBase64URL"]),
            operatorIdentityUUID: Self.stringValue(object["operatorIdentityUUID"]),
            operatorDid: Self.stringValue(object["operatorDid"]),
            operatorPublicKeyBase64URL: Self.stringValue(object["operatorPublicKeyBase64URL"]),
            purposeRef: Self.stringValue(object["purposeRef"]),
            scaffoldDomain: Self.stringValue(object["scaffoldDomain"]),
            challenge: Self.stringValue(object["challenge"]),
            issuedAt: Self.stringValue(object["issuedAt"])
        )
        let attestation = AgentEnrollmentAttestation(
            payload: payload,
            signatureAlgorithm: Self.stringValue(object["signatureAlgorithm"]),
            signatureBase64URL: Self.stringValue(object["signatureBase64URL"])
        )
        guard attestation.payload.agentIdentityUUID.isEmpty == false else {
            throw EnrollmentError.attestationInvalid("missing agent identity uuid")
        }
        return attestation
    }

    private func verify(attestation: AgentEnrollmentAttestation) throws {
        guard attestation.signatureAlgorithm == "Ed25519" else {
            throw EnrollmentError.attestationInvalid("unexpected signature algorithm")
        }
        let publicKeyData = try Self.base64URLDecode(attestation.payload.agentPublicKeyBase64URL)
        let signatureData = try Self.base64URLDecode(attestation.signatureBase64URL)
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        guard publicKey.isValidSignature(signatureData, for: try attestation.canonicalPayloadData()) else {
            throw EnrollmentError.attestationInvalid("signature verification failed")
        }
    }

    private func issueStarterAuth(
        using identityCell: Meddle,
        scaffoldDomain: String,
        purposeRef: String,
        interests: [String],
        requester: Identity
    ) async throws -> StarterAuthPayload {
        let response = try await identityCell.set(
            keypath: "starterAuth.issue",
            value: .object([
                "domain": .string(scaffoldDomain),
                "purpose": .string(purposeRef),
                "interests": .list(interests.map { .string($0) }),
                "ttlSeconds": .integer(900)
            ]),
            requester: requester
        )

        let payload = try parseStarterAuthPayload(from: response)
        try verify(starterAuth: payload, expectedDomain: scaffoldDomain, expectedPurpose: purposeRef, expectedInterests: interests)
        return payload
    }

    private func parseStarterAuthPayload(from value: ValueType?) throws -> StarterAuthPayload {
        guard case let .object(object)? = value else {
            throw EnrollmentError.starterAuthInvalid("agent did not return a starter auth object")
        }
        guard case let .object(purposeInterest)? = object["purpose_interest"],
              case let .object(signature)? = object["signature"] else {
            throw EnrollmentError.starterAuthInvalid("starter auth is missing purpose or signature")
        }

        return StarterAuthPayload(
            version: Self.stringValue(object["version"]),
            domain: Self.stringValue(object["domain"]),
            identity_public_key: Self.stringValue(object["identity_public_key"]),
            created_at: Self.stringValue(object["created_at"]),
            expires_at: Self.stringValue(object["expires_at"]),
            nonce: Self.stringValue(object["nonce"]),
            purpose_interest: StarterPurposeInterest(
                purpose: Self.stringValue(purposeInterest["purpose"]),
                interests: Self.stringList(purposeInterest["interests"])
            ),
            signature: ResolverSignatureEnvelope(
                alg: Self.stringValue(signature["alg"]),
                sig: Self.stringValue(signature["sig"])
            )
        )
    }

    private func verify(
        starterAuth: StarterAuthPayload,
        expectedDomain: String,
        expectedPurpose: String,
        expectedInterests: [String]
    ) throws {
        guard starterAuth.version == "1.0" else {
            throw EnrollmentError.starterAuthInvalid("unexpected starter auth version")
        }
        guard starterAuth.domain == expectedDomain else {
            throw EnrollmentError.starterAuthInvalid("domain mismatch")
        }
        guard starterAuth.purpose_interest.purpose == expectedPurpose else {
            throw EnrollmentError.starterAuthInvalid("purpose mismatch")
        }
        let actualInterests = starterAuth.purpose_interest.interests
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalizedExpected = expectedInterests
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !starterAuth.identity_public_key.isEmpty else {
            throw EnrollmentError.starterAuthInvalid("identity public key is missing")
        }
        guard !actualInterests.isEmpty else {
            throw EnrollmentError.starterAuthInvalid("interests are missing")
        }
        guard actualInterests.sorted() == normalizedExpected.sorted() else {
            throw EnrollmentError.starterAuthInvalid("interest mismatch")
        }
        guard starterAuth.signature.alg == "Ed25519" else {
            throw EnrollmentError.starterAuthInvalid("unexpected signature algorithm")
        }
        guard try verifyStarterAuthSignature(starterAuth) else {
            throw EnrollmentError.starterAuthInvalid("signature verification failed")
        }
    }

    private func verifyStarterAuthSignature(_ payload: StarterAuthPayload) throws -> Bool {
        let publicKeyData = try Self.base64URLDecode(payload.identity_public_key)
        let signatureData = try Self.base64URLDecode(payload.signature.sig)
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        return publicKey.isValidSignature(signatureData, for: try payload.canonicalPayloadData())
    }

    private func writeStarterAuth(_ payload: StarterAuthPayload, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private func createEntityLinkContract(
        using identityCell: Meddle,
        operatorIdentity: Identity,
        operatorPublicKey: Data,
        agentPublicKeyBase64URL: String,
        scaffoldDomain: String,
        purposeRef: String,
        recordedAt: String,
        requester: Identity
    ) async throws -> EntityLinkContract {
        let operatorPublicKeyBase64URL = Self.base64URLEncode(operatorPublicKey)
        let contractID = "elc_\(Self.sha256Base64URL(Data("\(scaffoldDomain)|\(operatorPublicKeyBase64URL)|\(agentPublicKeyBase64URL)|\(purposeRef)|\(recordedAt)".utf8)).prefix(16))"
        var contract = EntityLinkContract(
            contract_id: contractID,
            domain_a: scaffoldDomain,
            pubkey_a: operatorPublicKeyBase64URL,
            domain_b: scaffoldDomain,
            pubkey_b: agentPublicKeyBase64URL,
            scope: "purpose-bound:\(purposeRef)",
            created_at: recordedAt,
            revocation: EntityLinkRevocation(mode: "mutual"),
            signatures: []
        )

        guard let operatorSignatureData = try await operatorIdentity.sign(data: try contract.canonicalPayloadData()) else {
            throw EnrollmentError.signingFailed
        }
        let operatorSignature = EntityLinkSignature(
            by_pubkey: operatorPublicKeyBase64URL,
            alg: "Ed25519",
            sig: Self.base64URLEncode(operatorSignatureData)
        )

        let response = try await identityCell.set(
            keypath: "entityLink.countersign",
            value: .object([
                "contract_id": .string(contract.contract_id),
                "domain_a": .string(contract.domain_a),
                "pubkey_a": .string(contract.pubkey_a),
                "domain_b": .string(contract.domain_b),
                "pubkey_b": .string(contract.pubkey_b),
                "scope": .string(contract.scope),
                "created_at": .string(contract.created_at),
                "revocation": .object([
                    "mode": .string(contract.revocation.mode)
                ])
            ]),
            requester: requester
        )

        let agentSignature = try parseEntityLinkSignature(from: response)
        contract.signatures = [operatorSignature, agentSignature]
        try verify(entityLink: contract)
        return contract
    }

    private func parseEntityLinkSignature(from value: ValueType?) throws -> EntityLinkSignature {
        guard case let .object(object)? = value else {
            throw EnrollmentError.entityLinkInvalid("agent did not return an entity-link signature")
        }
        return EntityLinkSignature(
            by_pubkey: Self.stringValue(object["by_pubkey"]),
            alg: Self.stringValue(object["alg"]),
            sig: Self.stringValue(object["sig"])
        )
    }

    private func verify(entityLink: EntityLinkContract) throws {
        guard !entityLink.contract_id.isEmpty else {
            throw EnrollmentError.entityLinkInvalid("entity-link contract id is missing")
        }
        guard entityLink.signatures.count == 2 else {
            throw EnrollmentError.entityLinkInvalid("entity-link requires exactly two signatures")
        }
        let canonical = try entityLink.canonicalPayloadData()
        let requiredKeys = Set([entityLink.pubkey_a, entityLink.pubkey_b])
        var verified = Set<String>()

        for signature in entityLink.signatures {
            guard signature.alg == "Ed25519" else {
                throw EnrollmentError.entityLinkInvalid("entity-link signature algorithm mismatch")
            }
            guard requiredKeys.contains(signature.by_pubkey) else {
                throw EnrollmentError.entityLinkInvalid("entity-link signature key mismatch")
            }
            let publicKeyData = try Self.base64URLDecode(signature.by_pubkey)
            let signatureData = try Self.base64URLDecode(signature.sig)
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            guard publicKey.isValidSignature(signatureData, for: canonical) else {
                throw EnrollmentError.entityLinkInvalid("entity-link signature verification failed")
            }
            verified.insert(signature.by_pubkey)
        }

        guard verified == requiredKeys else {
            throw EnrollmentError.entityLinkInvalid("entity-link did not verify both linked identities")
        }
    }

    private func writeEntityLink(_ contract: EntityLinkContract, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(contract)
        try data.write(to: fileURL, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private func currentPaths() throws -> AgentPaths {
        let homeDirectory = Self.userHomeDirectory()
        Self.activatePersistedExternalRuntimeAccess(forHomeDirectory: homeDirectory)
        let applicationSupportDirectory = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        let agentDirectory = applicationSupportDirectory.appendingPathComponent("HAVENAgent", isDirectory: true)
        let outputDirectory = agentDirectory.appendingPathComponent("Out", isDirectory: true)
        return AgentPaths(
            applicationSupportDirectory: applicationSupportDirectory,
            agentDirectory: agentDirectory,
            configFile: agentDirectory.appendingPathComponent("config.json"),
            outputDirectory: outputDirectory,
            pairingArtifactFile: outputDirectory.appendingPathComponent("agent-enrollment-pairing.json"),
            starterAuthFile: agentDirectory.appendingPathComponent("starter-auth.json"),
            entityLinkFile: outputDirectory.appendingPathComponent("agent-operator-entity-link.json")
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
        if runtimeAccessStarted,
           runtimeAccessURL?.standardizedFileURL == homeDirectory.standardizedFileURL {
            return
        }

        guard let bookmarkData = UserDefaults.standard.data(forKey: runtimeAccessBookmarkKey) else {
            return
        }

        var bookmarkIsStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &bookmarkIsStale
        ) else {
            return
        }

        guard resolvedURL.standardizedFileURL == homeDirectory.standardizedFileURL else {
            return
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
#else
        _ = homeDirectory
#endif
    }

    private func value(forReadableKey key: String) -> ValueType {
        switch key {
        case "state":
            return .object(rootObject())
        case "enrollment.state":
            return .object(stateObject())
        default:
            return lookupValue(for: key, in: .object(rootObject())) ?? .null
        }
    }

    private func rootObject() -> Object {
        ["enrollment": .object(stateObject())]
    }

    private func stateObject() -> Object {
        let snapshot = stateQueue.sync { mutableState }
        return [
            "status": .object([
                "summary": .string(snapshot.summary),
                "operatorDisplayName": .string(snapshot.operatorDisplayName),
                "operatorDid": .string(snapshot.operatorDid),
                "scaffoldDomain": .string(snapshot.scaffoldDomain),
                "purposeRef": .string(snapshot.purposeRef),
                "controlBridgeEndpoint": .string(snapshot.controlBridgeEndpoint),
                "agentIdentityStatus": .string(snapshot.agentIdentityStatus),
                "agentDisplayName": .string(snapshot.agentDisplayName),
                "agentDid": .string(snapshot.agentDid),
                "agentPublicKeyBase64URL": .string(snapshot.agentPublicKeyBase64URL),
                "agentIdentityContext": .string(snapshot.agentIdentityContext),
                "verificationStatus": .string(snapshot.verificationStatus),
                "lastArtifactPath": .string(snapshot.lastArtifactPath),
                "starterAuthStatus": .string(snapshot.starterAuthStatus),
                "starterAuthPath": .string(snapshot.starterAuthPath),
                "starterAuthExpiresAt": .string(snapshot.starterAuthExpiresAt),
                "entityLinkStatus": .string(snapshot.entityLinkStatus),
                "entityLinkPath": .string(snapshot.entityLinkPath),
                "entityLinkContractID": .string(snapshot.entityLinkContractID),
                "lastRecordedAt": .string(snapshot.lastRecordedAt),
                "lastAction": .string(snapshot.lastAction),
                "lastError": .string(snapshot.lastError)
            ])
        ]
    }

    private func lookupValue(for keyPath: String, in value: ValueType) -> ValueType? {
        let components = keyPath.split(separator: ".").map(String.init)
        return components.reduce(Optional(value)) { partial, component in
            guard case let .object(object)? = partial else { return nil }
            return object[component]
        }
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

    private static func readJSONObject(at fileURL: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
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

    private static func stringValue(fromValue value: ValueType?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        return string
    }

    private static func stringValue(_ value: ValueType?) -> String {
        stringValue(fromValue: value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func stringList(_ value: ValueType?) -> [String] {
        guard case let .list(items)? = value else {
            return []
        }
        return items.compactMap { entry in
            guard case let .string(string) = entry else {
                return nil
            }
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private static func parseInterests(from text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ value: String) throws -> Data {
        let remainder = value.count % 4
        let padded: String
        switch remainder {
        case 0:
            padded = value
        case 2:
            padded = value + "=="
        case 3:
            padded = value + "="
        default:
            throw EnrollmentError.attestationInvalid("invalid base64url")
        }
        let canonical = padded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: canonical) else {
            throw EnrollmentError.attestationInvalid("invalid base64url")
        }
        return data
    }

    private static func sha256Base64URL(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return base64URLEncode(Data(digest))
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private enum JCSCanonicalizationError: Error {
    case unsupportedType(String)
    case unsupportedNumber(String)
    case integerOutOfRange(String)
}

private enum CanonicalJSONValue {
    case object([String: CanonicalJSONValue])
    case array([CanonicalJSONValue])
    case string(String)
    case integer(Int64)
    case bool(Bool)
    case null

    nonisolated static func parse(jsonData: Data) throws -> CanonicalJSONValue {
        let object = try JSONSerialization.jsonObject(with: jsonData, options: [.fragmentsAllowed])
        return try fromFoundation(object)
    }

    nonisolated static func fromFoundation(_ value: Any) throws -> CanonicalJSONValue {
        switch value {
        case let object as [String: Any]:
            var mapped: [String: CanonicalJSONValue] = [:]
            for (key, entry) in object {
                mapped[key] = try fromFoundation(entry)
            }
            return .object(mapped)
        case let array as [Any]:
            return .array(try array.map(fromFoundation))
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            let raw = number.stringValue
            if raw.contains(".") || raw.lowercased().contains("e") {
                throw JCSCanonicalizationError.unsupportedNumber(raw)
            }
            guard let integer = Int64(raw) else {
                throw JCSCanonicalizationError.integerOutOfRange(raw)
            }
            return .integer(integer)
        case _ as NSNull:
            return .null
        default:
            throw JCSCanonicalizationError.unsupportedType(String(describing: type(of: value)))
        }
    }

    nonisolated func removingTopLevelKeys(_ keys: Set<String>) -> CanonicalJSONValue {
        guard case let .object(object) = self else {
            return self
        }
        var copy = object
        for key in keys {
            copy[key] = nil
        }
        return .object(copy)
    }

    nonisolated func canonicalData() -> Data {
        Data(canonicalString().utf8)
    }

    nonisolated func canonicalString() -> String {
        switch self {
        case let .object(object):
            let body = object.keys.sorted(by: lexicalLessThan).map { key in
                "\"\(escapeJSONString(key))\":\(object[key]!.canonicalString())"
            }
            return "{\(body.joined(separator: ","))}"
        case let .array(array):
            return "[\(array.map { $0.canonicalString() }.joined(separator: ","))]"
        case let .string(string):
            return "\"\(escapeJSONString(string))\""
        case let .integer(integer):
            return String(integer)
        case let .bool(boolean):
            return boolean ? "true" : "false"
        case .null:
            return "null"
        }
    }

    nonisolated private func lexicalLessThan(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.unicodeScalars)
        let right = Array(rhs.unicodeScalars)
        for index in 0..<min(left.count, right.count) {
            if left[index].value == right[index].value {
                continue
            }
            return left[index].value < right[index].value
        }
        return left.count < right.count
    }
}

private enum JCSCanonicalizer {
    nonisolated static func canonicalizeRemovingTopLevelKeys(_ jsonData: Data, keys: Set<String>) throws -> Data {
        try CanonicalJSONValue.parse(jsonData: jsonData)
            .removingTopLevelKeys(keys)
            .canonicalData()
    }
}

nonisolated private func escapeJSONString(_ input: String) -> String {
    var result = ""
    result.reserveCapacity(input.count)

    for scalar in input.unicodeScalars {
        switch scalar.value {
        case 0x22:
            result.append("\\\"")
        case 0x5C:
            result.append("\\\\")
        case 0x08:
            result.append("\\b")
        case 0x09:
            result.append("\\t")
        case 0x0A:
            result.append("\\n")
        case 0x0C:
            result.append("\\f")
        case 0x0D:
            result.append("\\r")
        case 0x00...0x1F:
            let hex = String(scalar.value, radix: 16, uppercase: false)
            let padded = String(repeating: "0", count: max(0, 4 - hex.count)) + hex
            result.append("\\u\(padded)")
        default:
            result.unicodeScalars.append(scalar)
        }
    }

    return result
}
