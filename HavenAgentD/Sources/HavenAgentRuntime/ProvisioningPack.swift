import Foundation

/// A minimal, faithful JSON value used to carry artifacts whose concrete Swift
/// type is not public (e.g. the pairing artifact) verbatim inside a pack.
/// Re-encoding preserves field values; the artifact verifiers recompute their
/// own canonical form from decoded values, so byte-for-byte file identity is
/// not required for signature checks.
public indirect enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value in provisioning pack."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// Serializes this value to pretty, key-sorted JSON for writing to disk.
    public func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

/// The agent a pack is minted for. Import refuses any pack whose `boundAgent`
/// does not match the local agent identity — a pack signed for one agent must
/// not silently install on another.
public struct ProvisioningPackBoundAgent: Codable, Equatable, Sendable {
    public var agentIdentityUUID: String
    public var agentPublicKeyBase64URL: String

    public init(agentIdentityUUID: String, agentPublicKeyBase64URL: String) {
        self.agentIdentityUUID = agentIdentityUUID
        self.agentPublicKeyBase64URL = agentPublicKeyBase64URL
    }
}

/// A transferable bundle of already-signed provisioning evidence for one agent.
///
/// The operator mints this out-of-band (after receiving the agent's identity via
/// `provisioning-request`) and hands it to the pilot user, who installs it with
/// `haven-agentd provisioning-import`. The pack carries evidence only; local
/// admin policy (`config.json`) is written separately by `setup`.
public struct ProvisioningPack: Codable, Equatable, Sendable {
    public static let kind = "haven-agentd-provisioning-pack"
    public static let currentVersion = "1.0"

    public var version: String
    public var kind: String
    public var scaffoldDomain: String
    public var purposeRef: String?
    public var boundAgent: ProvisioningPackBoundAgent
    public var createdAt: String
    public var issuedBy: String?

    /// Pairing artifact (concrete type is internal to the verifier), carried verbatim.
    public var pairing: JSONValue
    public var starterAuth: AgentStarterAuthPayload
    public var entityLink: AgentEntityLinkContract

    /// Optional scaffold-side evidence, written only when configured paths exist.
    public var trustRoot: JSONValue?
    public var admissionContract: JSONValue?
    public var continuityProof: JSONValue?

    public init(
        version: String = ProvisioningPack.currentVersion,
        kind: String = ProvisioningPack.kind,
        scaffoldDomain: String,
        purposeRef: String?,
        boundAgent: ProvisioningPackBoundAgent,
        createdAt: String,
        issuedBy: String?,
        pairing: JSONValue,
        starterAuth: AgentStarterAuthPayload,
        entityLink: AgentEntityLinkContract,
        trustRoot: JSONValue? = nil,
        admissionContract: JSONValue? = nil,
        continuityProof: JSONValue? = nil
    ) {
        self.version = version
        self.kind = kind
        self.scaffoldDomain = scaffoldDomain
        self.purposeRef = purposeRef
        self.boundAgent = boundAgent
        self.createdAt = createdAt
        self.issuedBy = issuedBy
        self.pairing = pairing
        self.starterAuth = starterAuth
        self.entityLink = entityLink
        self.trustRoot = trustRoot
        self.admissionContract = admissionContract
        self.continuityProof = continuityProof
    }

    public static func load(from fileURL: URL) throws -> ProvisioningPack {
        try JSONDecoder().decode(ProvisioningPack.self, from: Data(contentsOf: fileURL))
    }
}
