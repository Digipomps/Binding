import Foundation
import HavenMacAutomation
import HavenRuntimeBootstrap
import SproutCore
import SproutResolverAdapter

public struct BootstrapProbeConfigSummary: Codable, Equatable, Sendable {
    public var instanceName: String
    public var scaffoldDomain: String
    public var startupMode: String
    public var purpose: String?
    public var goal: String?
    public var interests: [String]
    public var resolverBaseURL: String?
    public var discoveryURL: String?

    public init(
        instanceName: String,
        scaffoldDomain: String,
        startupMode: String,
        purpose: String?,
        goal: String?,
        interests: [String],
        resolverBaseURL: String?,
        discoveryURL: String?
    ) {
        self.instanceName = instanceName
        self.scaffoldDomain = scaffoldDomain
        self.startupMode = startupMode
        self.purpose = purpose
        self.goal = goal
        self.interests = interests
        self.resolverBaseURL = resolverBaseURL
        self.discoveryURL = discoveryURL
    }
}

public struct BootstrapProbeArtifactStatus: Codable, Equatable, Sendable {
    public var path: String?
    public var configured: Bool
    public var exists: Bool
    public var valid: Bool
    public var summary: String
    public var details: [String: String]

    public init(
        path: String?,
        configured: Bool,
        exists: Bool,
        valid: Bool,
        summary: String,
        details: [String: String] = [:]
    ) {
        self.path = path
        self.configured = configured
        self.exists = exists
        self.valid = valid
        self.summary = summary
        self.details = details
    }
}

public struct BootstrapProbeRunStatus: Codable, Equatable, Sendable {
    public var attempted: Bool
    public var succeeded: Bool
    public var mode: String
    public var artifactPath: String?
    public var finalState: String?
    public var contractID: String?
    public var expiresAt: String?
    public var summary: String
    public var error: String?

    public init(
        attempted: Bool,
        succeeded: Bool,
        mode: String,
        artifactPath: String?,
        finalState: String?,
        contractID: String?,
        expiresAt: String?,
        summary: String,
        error: String?
    ) {
        self.attempted = attempted
        self.succeeded = succeeded
        self.mode = mode
        self.artifactPath = artifactPath
        self.finalState = finalState
        self.contractID = contractID
        self.expiresAt = expiresAt
        self.summary = summary
        self.error = error
    }
}

public struct BootstrapProbeReport: Codable, Equatable, Sendable {
    public var runtimeRoot: String
    public var configPath: String
    public var readyForBootstrap: Bool
    public var config: BootstrapProbeConfigSummary
    public var pairingArtifact: BootstrapProbeArtifactStatus
    public var starterAuth: BootstrapProbeArtifactStatus
    public var entityLink: BootstrapProbeArtifactStatus
    public var bootstrap: BootstrapProbeRunStatus?

    public init(
        runtimeRoot: String,
        configPath: String,
        readyForBootstrap: Bool,
        config: BootstrapProbeConfigSummary,
        pairingArtifact: BootstrapProbeArtifactStatus,
        starterAuth: BootstrapProbeArtifactStatus,
        entityLink: BootstrapProbeArtifactStatus,
        bootstrap: BootstrapProbeRunStatus?
    ) {
        self.runtimeRoot = runtimeRoot
        self.configPath = configPath
        self.readyForBootstrap = readyForBootstrap
        self.config = config
        self.pairingArtifact = pairingArtifact
        self.starterAuth = starterAuth
        self.entityLink = entityLink
        self.bootstrap = bootstrap
    }
}

private struct PairingArtifactInspection {
    var status: BootstrapProbeArtifactStatus
    var pairedOperator: PairedOperatorIdentity?
}

private struct StarterAuthInspection {
    var status: BootstrapProbeArtifactStatus
    var payload: StarterAuthPayload?
}

private struct EntityLinkInspection {
    var status: BootstrapProbeArtifactStatus
    var contract: EntityLinkContract?
}

public actor BootstrapProbeService {
    private let paths: RuntimePaths
    private let sproutBootstrapClient: SproutBootstrapClient
    private let fileManager: FileManager

    public init(
        paths: RuntimePaths,
        processRunner: any ProcessRunning = FoundationProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.paths = paths
        self.sproutBootstrapClient = SproutBootstrapClient(processRunner: processRunner, fileManager: fileManager)
        self.fileManager = fileManager
    }

    public func probe(configURL: URL, runBootstrap: Bool = false) async -> BootstrapProbeReport {
        let resolvedConfigURL = configURL.standardizedFileURL

        do {
            let config = try AgentConfig.load(from: resolvedConfigURL)
            let configSummary = BootstrapProbeConfigSummary(
                instanceName: config.instanceName,
                scaffoldDomain: config.scaffold.domain,
                startupMode: config.scaffold.startupMode.rawValue,
                purpose: config.scaffold.purpose,
                goal: config.scaffold.goal,
                interests: config.scaffold.interests,
                resolverBaseURL: config.scaffold.resolverBaseURL,
                discoveryURL: config.scaffold.discoveryURL
            )

            let pairingArtifact = inspectPairingArtifact()
            let starterAuth = inspectStarterAuth(config: config)
            let entityLink = inspectEntityLink(
                config: config,
                starterAuth: starterAuth.payload,
                pairedOperator: pairingArtifact.pairedOperator
            )
            let readyForBootstrap = preflightIsReady(
                config: config,
                pairingArtifact: pairingArtifact.status,
                starterAuth: starterAuth.status,
                entityLink: entityLink.status
            )
            let bootstrapStatus = await executeBootstrapIfRequested(
                config: config,
                runBootstrap: runBootstrap,
                readyForBootstrap: readyForBootstrap
            )

            return BootstrapProbeReport(
                runtimeRoot: paths.homeDirectory.path,
                configPath: resolvedConfigURL.path,
                readyForBootstrap: readyForBootstrap,
                config: configSummary,
                pairingArtifact: pairingArtifact.status,
                starterAuth: starterAuth.status,
                entityLink: entityLink.status,
                bootstrap: bootstrapStatus
            )
        } catch {
            let invalidStatus = BootstrapProbeArtifactStatus(
                path: nil,
                configured: false,
                exists: false,
                valid: false,
                summary: error.localizedDescription
            )
            return BootstrapProbeReport(
                runtimeRoot: paths.homeDirectory.path,
                configPath: resolvedConfigURL.path,
                readyForBootstrap: false,
                config: BootstrapProbeConfigSummary(
                    instanceName: "unknown",
                    scaffoldDomain: "unknown",
                    startupMode: "unknown",
                    purpose: nil,
                    goal: nil,
                    interests: [],
                    resolverBaseURL: nil,
                    discoveryURL: nil
                ),
                pairingArtifact: invalidStatus,
                starterAuth: invalidStatus,
                entityLink: invalidStatus,
                bootstrap: runBootstrap
                    ? BootstrapProbeRunStatus(
                        attempted: false,
                        succeeded: false,
                        mode: "unknown",
                        artifactPath: nil,
                        finalState: nil,
                        contractID: nil,
                        expiresAt: nil,
                        summary: "Bootstrap skipped because config loading failed.",
                        error: error.localizedDescription
                    )
                    : nil
            )
        }
    }

    private func inspectPairingArtifact() -> PairingArtifactInspection {
        let path = paths.pairingArtifactFile.path
        guard fileManager.fileExists(atPath: path) else {
            return PairingArtifactInspection(
                status: BootstrapProbeArtifactStatus(
                    path: path,
                    configured: true,
                    exists: false,
                    valid: false,
                    summary: "Pairing artifact is missing."
                ),
                pairedOperator: nil
            )
        }

        do {
            guard let pairedOperator = try AgentPairingArtifactLoader.loadPairedOperator(from: paths.pairingArtifactFile) else {
                return PairingArtifactInspection(
                    status: BootstrapProbeArtifactStatus(
                        path: path,
                        configured: true,
                        exists: true,
                        valid: false,
                        summary: "Pairing artifact file exists but did not decode to a paired operator."
                    ),
                    pairedOperator: nil
                )
            }
            return PairingArtifactInspection(
                status: BootstrapProbeArtifactStatus(
                    path: path,
                    configured: true,
                    exists: true,
                    valid: true,
                    summary: "Pairing artifact verified for operator \(pairedOperator.operatorDid).",
                    details: [
                        "pairingID": pairedOperator.pairingID,
                        "operatorDid": pairedOperator.operatorDid,
                        "operatorPublicKeyBase64URL": pairedOperator.operatorPublicKeyBase64URL,
                        "purposeRef": pairedOperator.purposeRef,
                        "scaffoldDomain": pairedOperator.scaffoldDomain,
                        "approvedAt": pairedOperator.approvedAt
                    ]
                ),
                pairedOperator: pairedOperator
            )
        } catch {
            return PairingArtifactInspection(
                status: BootstrapProbeArtifactStatus(
                    path: path,
                    configured: true,
                    exists: true,
                    valid: false,
                    summary: "Pairing artifact verification failed: \(error.localizedDescription)"
                ),
                pairedOperator: nil
            )
        }
    }

    private func inspectStarterAuth(config: AgentConfig) -> StarterAuthInspection {
        guard let rawPath = config.scaffold.starterAuthPath, rawPath.isEmpty == false else {
            return StarterAuthInspection(
                status: BootstrapProbeArtifactStatus(
                    path: nil,
                    configured: false,
                    exists: false,
                    valid: false,
                    summary: "Starter auth is not configured."
                ),
                payload: nil
            )
        }

        let resolvedPath = NSString(string: rawPath).expandingTildeInPath
        guard fileManager.fileExists(atPath: resolvedPath) else {
            return StarterAuthInspection(
                status: BootstrapProbeArtifactStatus(
                    path: resolvedPath,
                    configured: true,
                    exists: false,
                    valid: false,
                    summary: "Starter auth file is missing."
                ),
                payload: nil
            )
        }

        do {
            let payload = try JSONDecoder().decode(StarterAuthPayload.self, from: Data(contentsOf: URL(fileURLWithPath: resolvedPath)))
            let interestsMatch = normalized(payload.purpose_interest.interests) == normalized(config.scaffold.interests)
            let purposeMatches = config.scaffold.purpose.map { payload.purpose_interest.purpose == $0 } ?? true
            let domainMatches = payload.domain == config.scaffold.domain
            let signatureValid = try payload.verifySignature()
            let expired = payload.isExpired()
            let valid = interestsMatch && purposeMatches && domainMatches && signatureValid && !expired

            let summary: String = {
                if valid {
                    return "Starter auth signature verified for \(payload.identity_public_key) until \(payload.expires_at)."
                }
                var reasons: [String] = []
                if !domainMatches { reasons.append("domain mismatch") }
                if !purposeMatches { reasons.append("purpose mismatch") }
                if !interestsMatch { reasons.append("interest mismatch") }
                if !signatureValid { reasons.append("signature invalid") }
                if expired { reasons.append("expired") }
                return "Starter auth is invalid: \(reasons.joined(separator: ", "))."
            }()

            return StarterAuthInspection(
                status: BootstrapProbeArtifactStatus(
                    path: resolvedPath,
                    configured: true,
                    exists: true,
                    valid: valid,
                    summary: summary,
                    details: [
                        "identityPublicKey": payload.identity_public_key,
                        "domain": payload.domain,
                        "purpose": payload.purpose_interest.purpose,
                        "interests": payload.purpose_interest.interests.joined(separator: ","),
                        "expiresAt": payload.expires_at
                    ]
                ),
                payload: payload
            )
        } catch {
            return StarterAuthInspection(
                status: BootstrapProbeArtifactStatus(
                    path: resolvedPath,
                    configured: true,
                    exists: true,
                    valid: false,
                    summary: "Starter auth verification failed: \(error.localizedDescription)"
                ),
                payload: nil
            )
        }
    }

    private func inspectEntityLink(
        config: AgentConfig,
        starterAuth: StarterAuthPayload?,
        pairedOperator: PairedOperatorIdentity?
    ) -> EntityLinkInspection {
        guard let rawPath = config.scaffold.entityLinkPath, rawPath.isEmpty == false else {
            return EntityLinkInspection(
                status: BootstrapProbeArtifactStatus(
                    path: nil,
                    configured: false,
                    exists: false,
                    valid: false,
                    summary: "Entity-link evidence is not configured."
                ),
                contract: nil
            )
        }

        let resolvedPath = NSString(string: rawPath).expandingTildeInPath
        guard fileManager.fileExists(atPath: resolvedPath) else {
            return EntityLinkInspection(
                status: BootstrapProbeArtifactStatus(
                    path: resolvedPath,
                    configured: true,
                    exists: false,
                    valid: false,
                    summary: "Entity-link evidence file is missing."
                ),
                contract: nil
            )
        }

        do {
            let contract = try EntityLinkContractIO.load(from: URL(fileURLWithPath: resolvedPath))
            let signaturesValid = try contract.verifyMutualSignatures()
            let domainsMatch = contract.domain_a == config.scaffold.domain && contract.domain_b == config.scaffold.domain
            let expectedScope = config.scaffold.purpose.map { "purpose-bound:\($0)" }
            let scopeMatches = expectedScope.map { contract.scope == $0 } ?? true
            let agentKeyMatches = starterAuth.map { Set([contract.pubkey_a, contract.pubkey_b]).contains($0.identity_public_key) } ?? false
            let operatorKeyMatches = pairedOperator.map { Set([contract.pubkey_a, contract.pubkey_b]).contains($0.operatorPublicKeyBase64URL) } ?? false
            let valid = signaturesValid && domainsMatch && scopeMatches && agentKeyMatches && operatorKeyMatches

            let summary: String = {
                if valid {
                    return "Entity-link contract \(contract.contract_id) verifies both linked identities."
                }
                var reasons: [String] = []
                if !signaturesValid { reasons.append("signature invalid") }
                if !domainsMatch { reasons.append("domain mismatch") }
                if !scopeMatches { reasons.append("scope mismatch") }
                if !agentKeyMatches { reasons.append("agent key missing") }
                if !operatorKeyMatches { reasons.append("operator key missing") }
                return "Entity-link evidence is invalid: \(reasons.joined(separator: ", "))."
            }()

            return EntityLinkInspection(
                status: BootstrapProbeArtifactStatus(
                    path: resolvedPath,
                    configured: true,
                    exists: true,
                    valid: valid,
                    summary: summary,
                    details: [
                        "contractID": contract.contract_id,
                        "scope": contract.scope,
                        "pubkeyA": contract.pubkey_a,
                        "pubkeyB": contract.pubkey_b,
                        "createdAt": contract.created_at
                    ]
                ),
                contract: contract
            )
        } catch {
            return EntityLinkInspection(
                status: BootstrapProbeArtifactStatus(
                    path: resolvedPath,
                    configured: true,
                    exists: true,
                    valid: false,
                    summary: "Entity-link verification failed: \(error.localizedDescription)"
                ),
                contract: nil
            )
        }
    }

    private func executeBootstrapIfRequested(
        config: AgentConfig,
        runBootstrap: Bool,
        readyForBootstrap: Bool
    ) async -> BootstrapProbeRunStatus? {
        guard runBootstrap else {
            return nil
        }

        guard readyForBootstrap else {
            return BootstrapProbeRunStatus(
                attempted: false,
                succeeded: false,
                mode: config.scaffold.startupMode.rawValue,
                artifactPath: nil,
                finalState: nil,
                contractID: nil,
                expiresAt: nil,
                summary: "Bootstrap skipped because preflight is not ready.",
                error: "Preflight failed."
            )
        }

        do {
            let record = try await sproutBootstrapClient.run(config: config, paths: paths)
            var contractID: String?
            var expiresAt: String?
            if config.scaffold.startupMode == .join {
                let artifact = try SproutBootstrapArtifactLoader.loadNativeSession(from: record?.artifactPath)
                contractID = artifact.session.contract.contract_id
                expiresAt = artifact.session.contract.expires_at
            }

            return BootstrapProbeRunStatus(
                attempted: true,
                succeeded: true,
                mode: config.scaffold.startupMode.rawValue,
                artifactPath: record?.artifactPath,
                finalState: record?.finalState,
                contractID: contractID,
                expiresAt: expiresAt,
                summary: record?.resultSummary ?? "Sprout bootstrap completed.",
                error: nil
            )
        } catch {
            return BootstrapProbeRunStatus(
                attempted: true,
                succeeded: false,
                mode: config.scaffold.startupMode.rawValue,
                artifactPath: nil,
                finalState: nil,
                contractID: nil,
                expiresAt: nil,
                summary: "Sprout bootstrap failed.",
                error: error.localizedDescription
            )
        }
    }

    private func preflightIsReady(
        config: AgentConfig,
        pairingArtifact: BootstrapProbeArtifactStatus,
        starterAuth: BootstrapProbeArtifactStatus,
        entityLink: BootstrapProbeArtifactStatus
    ) -> Bool {
        guard config.scaffold.startupMode != .disabled else {
            return false
        }

        let starterAuthReady = config.scaffold.starterAuthPath == nil || starterAuth.valid
        let entityEvidenceReady: Bool = {
            if config.scaffold.entityLinkPath != nil {
                return pairingArtifact.valid && entityLink.valid
            }
            if config.scaffold.admissionContractPath != nil {
                return true
            }
            return false
        }()

        return starterAuthReady && entityEvidenceReady
    }

    private func normalized(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }
}
