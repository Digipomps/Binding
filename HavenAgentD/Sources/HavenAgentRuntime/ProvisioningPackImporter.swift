import Foundation
import HavenRuntimeBootstrap

public struct ProvisioningArtifactInstall: Codable, Equatable, Sendable {
    public var name: String
    public var path: String
    public var installed: Bool
    public var summary: String

    public init(name: String, path: String, installed: Bool, summary: String) {
        self.name = name
        self.path = path
        self.installed = installed
        self.summary = summary
    }
}

public struct ProvisioningImportReport: Codable, Equatable, Sendable {
    public var runtimeRoot: String
    public var configPath: String
    public var packVersion: String
    public var scaffoldDomain: String
    public var boundAgentMatches: Bool
    public var installed: Bool
    public var artifacts: [ProvisioningArtifactInstall]
    public var readyForBootstrap: Bool
    public var warnings: [String]
    public var nextSteps: [String]

    public init(
        runtimeRoot: String,
        configPath: String,
        packVersion: String,
        scaffoldDomain: String,
        boundAgentMatches: Bool,
        installed: Bool,
        artifacts: [ProvisioningArtifactInstall],
        readyForBootstrap: Bool,
        warnings: [String],
        nextSteps: [String]
    ) {
        self.runtimeRoot = runtimeRoot
        self.configPath = configPath
        self.packVersion = packVersion
        self.scaffoldDomain = scaffoldDomain
        self.boundAgentMatches = boundAgentMatches
        self.installed = installed
        self.artifacts = artifacts
        self.readyForBootstrap = readyForBootstrap
        self.warnings = warnings
        self.nextSteps = nextSteps
    }
}

/// The agent-side information an operator needs to mint a provisioning pack.
/// Emitted by `haven-agentd provisioning-request`.
public struct ProvisioningRequest: Codable, Equatable, Sendable {
    public var scaffoldDomain: String
    public var purposeRef: String?
    public var interests: [String]
    public var agentDid: String
    public var boundAgent: ProvisioningPackBoundAgent
    public var instructions: String

    public init(
        scaffoldDomain: String,
        purposeRef: String?,
        interests: [String],
        agentDid: String,
        boundAgent: ProvisioningPackBoundAgent,
        instructions: String
    ) {
        self.scaffoldDomain = scaffoldDomain
        self.purposeRef = purposeRef
        self.interests = interests
        self.agentDid = agentDid
        self.boundAgent = boundAgent
        self.instructions = instructions
    }
}

public enum ProvisioningImportError: Error, LocalizedError, Sendable {
    case unsupportedKind(String)
    case unsupportedVersion(String)
    case agentIdentityMissing
    case boundAgentMismatch(expected: String, found: String)
    case scaffoldDomainMismatch(packDomain: String, configDomain: String)
    case verificationFailed([String])

    public var errorDescription: String? {
        switch self {
        case .unsupportedKind(let kind):
            return "Not a provisioning pack (kind: \(kind))."
        case .unsupportedVersion(let version):
            return "Unsupported provisioning pack version: \(version)."
        case .agentIdentityMissing:
            return "No agent identity yet. Run `haven-agentd provisioning-request` (or `run --once`) first so the pack can be bound to this agent's key."
        case .boundAgentMismatch(let expected, let found):
            return "Pack is bound to a different agent key. This agent: \(expected); pack: \(found)."
        case .scaffoldDomainMismatch(let packDomain, let configDomain):
            return "Pack scaffold domain (\(packDomain)) does not match config (\(configDomain))."
        case .verificationFailed(let reasons):
            return "Provisioning artifacts failed verification: \(reasons.joined(separator: "; "))."
        }
    }
}

public actor ProvisioningPackImporter {
    private let paths: RuntimePaths
    private let fileManager: FileManager

    public init(paths: RuntimePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    /// Emits the agent identity + scaffold context an operator needs to mint a
    /// pack. Materializes a stable identity if none exists yet.
    public func makeRequest(configURL: URL) async throws -> ProvisioningRequest {
        let config = try AgentConfig.load(from: configURL)
        let descriptor = try await AgentIdentityStore(fileURL: paths.agentIdentityFile)
            .loadOrCreate(instanceName: config.instanceName)
            .descriptor
        return ProvisioningRequest(
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
    }

    public func performImport(packURL: URL, configURL: URL) async throws -> ProvisioningImportReport {
        let pack = try ProvisioningPack.load(from: packURL)
        guard pack.kind == ProvisioningPack.kind else {
            throw ProvisioningImportError.unsupportedKind(pack.kind)
        }
        guard pack.version == ProvisioningPack.currentVersion else {
            throw ProvisioningImportError.unsupportedVersion(pack.version)
        }

        let config = try AgentConfig.load(from: configURL)

        guard let descriptor = try await AgentIdentityStore(fileURL: paths.agentIdentityFile)
            .loadExistingDescriptor() else {
            throw ProvisioningImportError.agentIdentityMissing
        }
        let agentKey = descriptor.publicKeyBase64URL

        guard pack.boundAgent.agentPublicKeyBase64URL == agentKey else {
            throw ProvisioningImportError.boundAgentMismatch(
                expected: agentKey,
                found: pack.boundAgent.agentPublicKeyBase64URL
            )
        }
        guard pack.scaffoldDomain == config.scaffold.domain else {
            throw ProvisioningImportError.scaffoldDomainMismatch(
                packDomain: pack.scaffoldDomain,
                configDomain: config.scaffold.domain
            )
        }

        var warnings: [String] = []
        if pack.boundAgent.agentIdentityUUID != descriptor.identityUUID {
            warnings.append("Pack agentIdentityUUID differs from local identity, but the signing key matches; proceeding on key identity.")
        }

        // Verify everything in a temp directory before touching the real paths.
        let stagingDir = fileManager.temporaryDirectory
            .appendingPathComponent("haven-provisioning-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDir) }

        var failures: [String] = []

        // --- pairing (verify via the file-based loader) ---
        let pairingStaged = stagingDir.appendingPathComponent("pairing.json")
        try pack.pairing.encodedData().write(to: pairingStaged, options: [.atomic])
        var pairedOperator: PairedOperatorIdentity?
        do {
            pairedOperator = try AgentPairingArtifactLoader.loadPairedOperator(from: pairingStaged)
            if pairedOperator == nil {
                failures.append("pairing: file did not decode to a paired operator")
            } else if pairedOperator?.scaffoldDomain != config.scaffold.domain {
                failures.append("pairing: scaffold domain mismatch")
            }
        } catch {
            failures.append("pairing: \(error.localizedDescription)")
        }

        // --- starter auth (verify in memory) ---
        let starterAuth = pack.starterAuth
        if (try? starterAuth.verifySignature()) != true {
            failures.append("starterAuth: signature invalid")
        }
        if starterAuth.identity_public_key != agentKey {
            failures.append("starterAuth: not bound to this agent's key")
        }
        if starterAuth.domain != config.scaffold.domain {
            failures.append("starterAuth: domain mismatch")
        }
        if starterAuth.isExpired() {
            warnings.append("starterAuth is expired; run `haven-agentd refresh-starter-auth` before bootstrap.")
        }

        // --- entity link (verify in memory) ---
        let entityLink = pack.entityLink
        if (try? entityLink.verifyMutualSignatures()) != true {
            failures.append("entityLink: mutual signatures invalid")
        }
        if !(entityLink.domain_a == config.scaffold.domain && entityLink.domain_b == config.scaffold.domain) {
            failures.append("entityLink: domain mismatch")
        }
        if ![entityLink.pubkey_a, entityLink.pubkey_b].contains(agentKey) {
            failures.append("entityLink: agent key not present")
        }
        if let pairedOperator,
           ![entityLink.pubkey_a, entityLink.pubkey_b].contains(pairedOperator.operatorPublicKeyBase64URL) {
            failures.append("entityLink: paired operator key not present")
        }

        guard failures.isEmpty else {
            throw ProvisioningImportError.verificationFailed(failures)
        }

        // --- all verified: install atomically to configured paths ---
        var artifacts: [ProvisioningArtifactInstall] = []

        let pairingTarget = paths.pairingArtifactFile
        try writeData(try pack.pairing.encodedData(), to: pairingTarget)
        artifacts.append(.init(name: "pairing", path: pairingTarget.path, installed: true,
                               summary: "Verified for operator \(pairedOperator?.operatorDid ?? "unknown")."))

        let starterTarget = resolvedPath(config.scaffold.starterAuthPath)
            ?? paths.agentDirectory.appendingPathComponent("starter-auth.json")
        try writeEncodable(starterAuth, to: starterTarget)
        artifacts.append(.init(name: "starterAuth", path: starterTarget.path, installed: true,
                               summary: "Signed for \(starterAuth.identity_public_key) until \(starterAuth.expires_at)."))

        let entityTarget = resolvedPath(config.scaffold.entityLinkPath)
            ?? paths.outputDirectory.appendingPathComponent("agent-operator-entity-link.json")
        try writeEncodable(entityLink, to: entityTarget)
        artifacts.append(.init(name: "entityLink", path: entityTarget.path, installed: true,
                               summary: "Contract \(entityLink.contract_id) links agent + operator."))

        if let admission = pack.admissionContract, let target = resolvedPath(config.scaffold.admissionContractPath) {
            try writeData(try admission.encodedData(), to: target)
            artifacts.append(.init(name: "admissionContract", path: target.path, installed: true, summary: "Installed."))
        }
        if let continuity = pack.continuityProof, let target = resolvedPath(config.scaffold.continuityProofPath) {
            try writeData(try continuity.encodedData(), to: target)
            artifacts.append(.init(name: "continuityProof", path: target.path, installed: true, summary: "Installed."))
        }
        if let trustRoot = pack.trustRoot {
            let target = paths.agentDirectory.appendingPathComponent("scaffold-admin-trust-root.json")
            try writeData(try trustRoot.encodedData(), to: target)
            artifacts.append(.init(name: "trustRoot", path: target.path, installed: true,
                                   summary: "Installed (reference it via the sprout --trust-root path if needed)."))
        }

        // --- readiness ---
        let probe = await BootstrapProbeService(paths: paths).probe(configURL: configURL, runBootstrap: false)

        var nextSteps: [String] = []
        if probe.readyForBootstrap {
            nextSteps.append("Provisioning verified. Confirm with `haven-agentd bootstrap-probe --run-bootstrap`, then load the LaunchAgent (or re-run `setup --load`).")
        } else {
            nextSteps.append("Imported, but bootstrap-probe still reports not ready: pairing=\(probe.pairingArtifact.valid) starterAuth=\(probe.starterAuth.valid) entityLink=\(probe.entityLink.valid). See its summaries.")
            if !probe.starterAuth.valid {
                nextSteps.append("If starter-auth is expired, run `haven-agentd refresh-starter-auth`.")
            }
        }

        return ProvisioningImportReport(
            runtimeRoot: paths.homeDirectory.path,
            configPath: configURL.path,
            packVersion: pack.version,
            scaffoldDomain: pack.scaffoldDomain,
            boundAgentMatches: true,
            installed: true,
            artifacts: artifacts,
            readyForBootstrap: probe.readyForBootstrap,
            warnings: warnings,
            nextSteps: nextSteps
        )
    }

    // MARK: - Helpers

    private func resolvedPath(_ rawPath: String?) -> URL? {
        guard let rawPath, !rawPath.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: rawPath).expandingTildeInPath)
    }

    private func writeData(_ data: Data, to fileURL: URL) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    private func writeEncodable<T: Encodable>(_ value: T, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try writeData(try encoder.encode(value), to: fileURL)
    }
}
