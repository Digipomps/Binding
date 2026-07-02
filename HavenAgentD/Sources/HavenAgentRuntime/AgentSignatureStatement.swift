import Foundation
import CryptoKit
import CellBase
import SproutCrypto

public enum AgentSignatureStatement {
    public static let endpoint = "cell:///agent/identity/signatures"
    public static let controlBridgeRouteName = "identity-signatures"
    public static let purposeRef = "personal.identity.sign.statement"
    public static let goalID = "agent.identity.issue-audience-bound-signature"
    public static let capabilityRef = "cap.local_identity_sign_statement"
    public static let topic = "agent.identity.signatures"
    public static let maxPayloadBytes = 65_536
    public static let maxValiditySeconds: TimeInterval = 86_400
    public static let minNonceLength = 16
    public static let maxNonceLength = 160

    public static let purposeRefs = [
        purposeRef,
        "personal.identity.prove-data-integrity",
        "personal.entity.send-verifiable-statement"
    ]

    public static let interests = [
        "agentd",
        "identity",
        "signature",
        "signering",
        "signed-data",
        "verifiable-statement",
        "detached-payload",
        "audience-bound",
        "nonce-protected",
        "local-key-use"
    ]
}

public struct AgentSignatureAudience: Codable, Equatable, Sendable {
    public var entityRef: String
    public var publicKeyBase64URL: String?
    public var publicKeyFingerprint: String?

    public init(
        entityRef: String,
        publicKeyBase64URL: String? = nil,
        publicKeyFingerprint: String? = nil
    ) {
        self.entityRef = entityRef
        self.publicKeyBase64URL = publicKeyBase64URL
        self.publicKeyFingerprint = publicKeyFingerprint
    }
}

public struct AgentSignStatementRequest: Codable, Equatable, Sendable {
    public var purposeRef: String
    public var payloadBase64URL: String?
    public var payloadSHA256Base64URL: String?
    public var payloadMediaType: String?
    public var payloadDescription: String?
    public var signerIdentityUUID: String?
    public var audience: AgentSignatureAudience
    public var expiresAt: String
    public var nonce: String
    public var correlationID: String?

    public init(
        purposeRef: String = AgentSignatureStatement.purposeRef,
        payloadBase64URL: String? = nil,
        payloadSHA256Base64URL: String? = nil,
        payloadMediaType: String? = nil,
        payloadDescription: String? = nil,
        signerIdentityUUID: String? = nil,
        audience: AgentSignatureAudience,
        expiresAt: String,
        nonce: String,
        correlationID: String? = nil
    ) {
        self.purposeRef = purposeRef
        self.payloadBase64URL = payloadBase64URL
        self.payloadSHA256Base64URL = payloadSHA256Base64URL
        self.payloadMediaType = payloadMediaType
        self.payloadDescription = payloadDescription
        self.signerIdentityUUID = signerIdentityUUID
        self.audience = audience
        self.expiresAt = expiresAt
        self.nonce = nonce
        self.correlationID = correlationID
    }
}

public struct AgentSignedStatementPayloadDescriptor: Codable, Equatable, Sendable {
    public var encoding: String
    public var sha256Base64URL: String
    public var sizeBytes: Int?
    public var mediaType: String?
    public var description: String?

    public init(
        encoding: String,
        sha256Base64URL: String,
        sizeBytes: Int? = nil,
        mediaType: String? = nil,
        description: String? = nil
    ) {
        self.encoding = encoding
        self.sha256Base64URL = sha256Base64URL
        self.sizeBytes = sizeBytes
        self.mediaType = mediaType
        self.description = description
    }
}

public struct AgentSignedStatementSignerIdentity: Codable, Equatable, Sendable {
    public var identityUUID: String
    public var displayName: String
    public var didKey: String
    public var domain: String
    public var publicKeyBase64URL: String

    public init(
        identityUUID: String,
        displayName: String,
        didKey: String,
        domain: String,
        publicKeyBase64URL: String
    ) {
        self.identityUUID = identityUUID
        self.displayName = displayName
        self.didKey = didKey
        self.domain = domain
        self.publicKeyBase64URL = publicKeyBase64URL
    }
}

public struct AgentSignedStatementSigningPayload: Codable, Equatable, Sendable {
    public var type: String
    public var version: String
    public var purposeRef: String
    public var signerIdentity: AgentSignedStatementSignerIdentity
    public var audience: AgentSignatureAudience
    public var payload: AgentSignedStatementPayloadDescriptor
    public var issuedAt: String
    public var expiresAt: String
    public var nonce: String
    public var correlationID: String?
    public var canonicalization: String

    public init(
        type: String = "haven.signed-data.v1",
        version: String = "1.0",
        purposeRef: String,
        signerIdentity: AgentSignedStatementSignerIdentity,
        audience: AgentSignatureAudience,
        payload: AgentSignedStatementPayloadDescriptor,
        issuedAt: String,
        expiresAt: String,
        nonce: String,
        correlationID: String? = nil,
        canonicalization: String = "json.encoder.sortedKeys.utf8"
    ) {
        self.type = type
        self.version = version
        self.purposeRef = purposeRef
        self.signerIdentity = signerIdentity
        self.audience = audience
        self.payload = payload
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.nonce = nonce
        self.correlationID = correlationID
        self.canonicalization = canonicalization
    }

    public func canonicalPayloadData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

public struct AgentSignedStatementEnvelope: Codable, Equatable, Sendable {
    public var signed: AgentSignedStatementSigningPayload
    public var signatureAlgorithm: String
    public var signatureBase64URL: String
    public var signingInputSHA256Base64URL: String

    public init(
        signed: AgentSignedStatementSigningPayload,
        signatureAlgorithm: String = "Ed25519",
        signatureBase64URL: String,
        signingInputSHA256Base64URL: String
    ) {
        self.signed = signed
        self.signatureAlgorithm = signatureAlgorithm
        self.signatureBase64URL = signatureBase64URL
        self.signingInputSHA256Base64URL = signingInputSHA256Base64URL
    }

    public func canonicalPayloadData() throws -> Data {
        try signed.canonicalPayloadData()
    }
}

public struct AgentSignStatementResult: Codable, Equatable, Sendable {
    public var status: String
    public var actionID: String
    public var deliveryMode: String
    public var envelope: AgentSignedStatementEnvelope
    public var message: String

    public init(
        status: String,
        actionID: String,
        deliveryMode: String,
        envelope: AgentSignedStatementEnvelope,
        message: String
    ) {
        self.status = status
        self.actionID = actionID
        self.deliveryMode = deliveryMode
        self.envelope = envelope
        self.message = message
    }
}

public enum AgentSignStatementError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedPurposeRef(String)
    case missingPayloadHash
    case conflictingPayloadInputs
    case invalidPayloadHash
    case payloadTooLarge(Int)
    case missingAudience
    case invalidAudience
    case invalidSignerIdentity(expected: String, actual: String)
    case invalidExpiry
    case expiryInPast
    case expiryTooLong(maxSeconds: Int)
    case invalidNonce
    case nonceAlreadyUsed(String)
    case signingUnavailable

    public var errorDescription: String? {
        switch self {
        case .unsupportedPurposeRef(let purposeRef):
            return "Unsupported signature purposeRef: \(purposeRef)"
        case .missingPayloadHash:
            return "Either payloadBase64URL or payloadSHA256Base64URL is required."
        case .conflictingPayloadInputs:
            return "Provide either payloadBase64URL or payloadSHA256Base64URL, not both."
        case .invalidPayloadHash:
            return "Payload SHA-256 hash is invalid."
        case .payloadTooLarge(let size):
            return "Payload is \(size) bytes, above the \(AgentSignatureStatement.maxPayloadBytes) byte limit."
        case .missingAudience:
            return "Audience entityRef and public key material are required."
        case .invalidAudience:
            return "Audience fields must be single-line bounded strings."
        case .invalidSignerIdentity(let expected, let actual):
            return "Requested signer identity '\(actual)' does not match local agent identity '\(expected)'."
        case .invalidExpiry:
            return "expiresAt must be an ISO-8601 timestamp."
        case .expiryInPast:
            return "expiresAt must be in the future."
        case .expiryTooLong(let maxSeconds):
            return "expiresAt must be no more than \(maxSeconds) seconds in the future."
        case .invalidNonce:
            return "nonce must be a single-line value between \(AgentSignatureStatement.minNonceLength) and \(AgentSignatureStatement.maxNonceLength) characters."
        case .nonceAlreadyUsed(let nonce):
            return "nonce has already been used: \(nonce)"
        case .signingUnavailable:
            return "Local agent identity failed to sign the statement."
        }
    }
}

public actor AgentSignatureNonceStore {
    private struct Ledger: Codable {
        var entries: [String: String]
    }

    private let fileURL: URL
    private let maxEntries: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL, maxEntries: Int = 2_000) {
        self.fileURL = fileURL
        self.maxEntries = maxEntries
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func reserve(nonce: String, issuedAt: String) throws {
        var ledger = try load()
        if ledger.entries[nonce] != nil {
            throw AgentSignStatementError.nonceAlreadyUsed(nonce)
        }
        ledger.entries[nonce] = issuedAt
        if ledger.entries.count > maxEntries {
            let removeCount = ledger.entries.count - maxEntries
            let oldest = ledger.entries
                .sorted { $0.value < $1.value }
                .prefix(removeCount)
                .map(\.key)
            for key in oldest {
                ledger.entries.removeValue(forKey: key)
            }
        }
        try write(ledger)
    }

    private func load() throws -> Ledger {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Ledger(entries: [:])
        }
        return try decoder.decode(Ledger.self, from: Data(contentsOf: fileURL))
    }

    private func write(_ ledger: Ledger) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try encoder.encode(ledger)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}

public actor AgentSignStatementCommandService {
    private let owner: Identity
    private let identityDescriptor: AgentIdentityDescriptor
    private let nonceStore: AgentSignatureNonceStore
    private let now: @Sendable () -> Date
    private let iso8601: ISO8601DateFormatter

    public init(
        owner: Identity,
        identityDescriptor: AgentIdentityDescriptor,
        nonceStore: AgentSignatureNonceStore,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.owner = owner
        self.identityDescriptor = identityDescriptor
        self.nonceStore = nonceStore
        self.now = now
        self.iso8601 = ISO8601DateFormatter()
    }

    public func signStatement(_ request: AgentSignStatementRequest) async throws -> AgentSignStatementResult {
        try validatePurpose(request.purposeRef)
        if let requestedIdentity = request.signerIdentityUUID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !requestedIdentity.isEmpty,
           requestedIdentity != identityDescriptor.identityUUID {
            throw AgentSignStatementError.invalidSignerIdentity(
                expected: identityDescriptor.identityUUID,
                actual: requestedIdentity
            )
        }

        let currentDate = now()
        let issuedAt = iso8601.string(from: currentDate)
        let expiresAt = try validateExpiry(request.expiresAt, now: currentDate)
        try validateNonce(request.nonce)
        try validateAudience(request.audience)
        let payloadDescriptor = try makePayloadDescriptor(request)

        let signerIdentity = AgentSignedStatementSignerIdentity(
            identityUUID: identityDescriptor.identityUUID,
            displayName: identityDescriptor.displayName,
            didKey: identityDescriptor.didKey,
            domain: identityDescriptor.identityContext,
            publicKeyBase64URL: identityDescriptor.publicKeyBase64URL
        )
        let signed = AgentSignedStatementSigningPayload(
            purposeRef: request.purposeRef,
            signerIdentity: signerIdentity,
            audience: request.audience,
            payload: payloadDescriptor,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            nonce: request.nonce,
            correlationID: normalizedOptional(request.correlationID)
        )
        let signingData = try signed.canonicalPayloadData()
        try await nonceStore.reserve(nonce: request.nonce, issuedAt: issuedAt)
        guard let signature = try await owner.sign(data: signingData) else {
            throw AgentSignStatementError.signingUnavailable
        }
        let signingInputDigest = Data(SHA256.hash(data: signingData))
        let envelope = AgentSignedStatementEnvelope(
            signed: signed,
            signatureBase64URL: Base64URL.encode(signature),
            signingInputSHA256Base64URL: Base64URL.encode(signingInputDigest)
        )
        return AgentSignStatementResult(
            status: "signed_statement_created",
            actionID: "identity.sign-statement",
            deliveryMode: "detached_signed_statement",
            envelope: envelope,
            message: "Audience-bound signed statement created by local HAVENAgentD identity."
        )
    }

    public static func verifyEnvelope(_ envelope: AgentSignedStatementEnvelope) throws -> Bool {
        let publicKey = try Curve25519.Signing.PublicKey(
            rawRepresentation: Base64URL.decode(envelope.signed.signerIdentity.publicKeyBase64URL)
        )
        let signingData = try envelope.signed.canonicalPayloadData()
        let signature = try Base64URL.decode(envelope.signatureBase64URL)
        let digest = Data(SHA256.hash(data: signingData))
        guard Base64URL.encode(digest) == envelope.signingInputSHA256Base64URL else {
            return false
        }
        return publicKey.isValidSignature(signature, for: signingData)
    }

    private func validatePurpose(_ purposeRef: String) throws {
        guard AgentSignatureStatement.purposeRefs.contains(purposeRef) else {
            throw AgentSignStatementError.unsupportedPurposeRef(purposeRef)
        }
    }

    private func validateExpiry(_ raw: String, now: Date) throws -> String {
        guard let date = iso8601.date(from: raw) else {
            throw AgentSignStatementError.invalidExpiry
        }
        guard date > now else {
            throw AgentSignStatementError.expiryInPast
        }
        let maxSeconds = Int(AgentSignatureStatement.maxValiditySeconds)
        guard date.timeIntervalSince(now) <= AgentSignatureStatement.maxValiditySeconds else {
            throw AgentSignStatementError.expiryTooLong(maxSeconds: maxSeconds)
        }
        return iso8601.string(from: date)
    }

    private func validateNonce(_ nonce: String) throws {
        guard nonce.count >= AgentSignatureStatement.minNonceLength,
              nonce.count <= AgentSignatureStatement.maxNonceLength,
              nonce.contains(where: \.isNewline) == false else {
            throw AgentSignStatementError.invalidNonce
        }
    }

    private func validateAudience(_ audience: AgentSignatureAudience) throws {
        let entityRef = audience.entityRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entityRef.isEmpty,
              !containsInvalidLine(audience.entityRef),
              oneLine(audience.publicKeyBase64URL, maxLength: 256),
              oneLine(audience.publicKeyFingerprint, maxLength: 128),
              (normalizedOptional(audience.publicKeyBase64URL) != nil || normalizedOptional(audience.publicKeyFingerprint) != nil) else {
            throw AgentSignStatementError.missingAudience
        }
        guard audience.entityRef.count <= 512 else {
            throw AgentSignStatementError.invalidAudience
        }
    }

    private func makePayloadDescriptor(_ request: AgentSignStatementRequest) throws -> AgentSignedStatementPayloadDescriptor {
        let payloadBase64URL = normalizedOptional(request.payloadBase64URL)
        let payloadSHA256Base64URL = normalizedOptional(request.payloadSHA256Base64URL)
        if payloadBase64URL != nil && payloadSHA256Base64URL != nil {
            throw AgentSignStatementError.conflictingPayloadInputs
        }
        guard payloadBase64URL != nil || payloadSHA256Base64URL != nil else {
            throw AgentSignStatementError.missingPayloadHash
        }

        if let payloadBase64URL {
            let payload = try Base64URL.decode(payloadBase64URL)
            guard payload.count <= AgentSignatureStatement.maxPayloadBytes else {
                throw AgentSignStatementError.payloadTooLarge(payload.count)
            }
            let digest = Data(SHA256.hash(data: payload))
            return AgentSignedStatementPayloadDescriptor(
                encoding: "detached-sha256",
                sha256Base64URL: Base64URL.encode(digest),
                sizeBytes: payload.count,
                mediaType: boundedOptional(request.payloadMediaType, maxLength: 160),
                description: boundedOptional(request.payloadDescription, maxLength: 512)
            )
        }

        guard let payloadSHA256Base64URL,
              (try? Base64URL.decode(payloadSHA256Base64URL).count) == 32 else {
            throw AgentSignStatementError.invalidPayloadHash
        }
        return AgentSignedStatementPayloadDescriptor(
            encoding: "detached-sha256",
            sha256Base64URL: payloadSHA256Base64URL,
            sizeBytes: nil,
            mediaType: boundedOptional(request.payloadMediaType, maxLength: 160),
            description: boundedOptional(request.payloadDescription, maxLength: 512)
        )
    }

    private func boundedOptional(_ value: String?, maxLength: Int) -> String? {
        guard let trimmed = normalizedOptional(value), trimmed.count <= maxLength else { return nil }
        guard !containsInvalidLine(trimmed) else { return nil }
        return trimmed
    }

    private func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func oneLine(_ value: String?, maxLength: Int) -> Bool {
        guard let value = normalizedOptional(value) else { return true }
        return value.count <= maxLength && !containsInvalidLine(value)
    }

    private func containsInvalidLine(_ value: String) -> Bool {
        value.contains(where: \.isNewline)
    }
}
