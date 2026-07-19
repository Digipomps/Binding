import Foundation
import CellBase
import CellApple
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Versioned proof-of-possession contract for the device registration and
/// notification callback HTTP boundary.
///
/// The proof is context evidence bound to an already-issued Agreement/credential
/// reference. It never grants authority by itself. The server remains responsible
/// for resolving the referenced authority, checking revocation and consuming the
/// challenge exactly once.
nonisolated enum DeviceCallbackCapabilityContract {
    static let challengeSchema = "haven.device-callback.challenge.v1"
    static let authorityReferenceSchema = "haven.device-callback.authority-reference.v1"
    static let requestSchema = "haven.device-callback.request-proof.v1"
    static let proofType = "identity_signature"
    static let authorizationScheme = "HAVEN-Device-Proof"
    static let purpose = "purpose://access.audit.privacy/device-notification-callback"
    static let identityContext = "domain:device:notification-callback"
    static let stagingAudience = "staging.haven.digipomps.org"
    static let stagingOrigin = "https://staging.haven.digipomps.org"
    static let maximumChallengeTTL: TimeInterval = 300
    static let maximumRequestTTL: TimeInterval = 120
    static let maximumAuthorityTTL: TimeInterval = 30 * 24 * 60 * 60
    static let maximumClockSkew: TimeInterval = 30
    static let maximumBodySize = 1_048_576

    enum Operation: String, Codable, CaseIterable, Sendable {
        case register
        case resolve
        case submit

        var method: String { "POST" }

        var path: String {
            switch self {
            case .register:
                "/conference-mvp/api/device/register"
            case .resolve:
                "/conference-mvp/api/device/callback/resolve"
            case .submit:
                "/conference-mvp/api/device/callback/submit"
            }
        }

        var capability: String {
            switch self {
            case .register:
                "device.registration.write"
            case .resolve:
                "device.callback.resolve"
            case .submit:
                "device.callback.submit"
            }
        }
    }

    static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    static func authorizationValue(for request: DeviceCallbackSignedRequest) throws -> String {
        let data = try JSONEncoder().encode(request)
        return "\(authorizationScheme) \(base64URL(data))"
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

nonisolated struct DeviceCallbackCapabilityChallenge: Codable, Equatable, Sendable {
    var schema: String
    var challengeID: String
    var nonce: Data
    var purpose: String
    var audience: String
    var origin: String
    var method: String
    var path: String
    var capability: String
    var issuedAt: String
    var expiresAt: String

    init(
        schema: String = DeviceCallbackCapabilityContract.challengeSchema,
        challengeID: String,
        nonce: Data,
        purpose: String = DeviceCallbackCapabilityContract.purpose,
        audience: String,
        origin: String,
        operation: DeviceCallbackCapabilityContract.Operation,
        issuedAt: String,
        expiresAt: String
    ) {
        self.schema = schema
        self.challengeID = challengeID
        self.nonce = nonce
        self.purpose = purpose
        self.audience = audience
        self.origin = origin
        self.method = operation.method
        self.path = operation.path
        self.capability = operation.capability
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }
}

/// Non-secret reference to an authority record already persisted by the server.
/// IDs are never accepted as authority without server-side Agreement/credential
/// resolution, subject matching, expiry and revocation checks.
nonisolated struct DeviceCallbackAuthorityReference: Codable, Equatable, Sendable {
    var schema: String
    var credentialID: String
    var agreementID: String
    var participantID: String
    var deviceID: String
    var subjectIdentityUUID: String
    var subjectSigningKeyFingerprint: String
    var issuedAt: String
    var validUntil: String

    init(
        schema: String = DeviceCallbackCapabilityContract.authorityReferenceSchema,
        credentialID: String,
        agreementID: String,
        participantID: String,
        deviceID: String,
        subjectIdentityUUID: String,
        subjectSigningKeyFingerprint: String,
        issuedAt: String,
        validUntil: String
    ) {
        self.schema = schema
        self.credentialID = credentialID
        self.agreementID = agreementID
        self.participantID = participantID
        self.deviceID = deviceID
        self.subjectIdentityUUID = subjectIdentityUUID
        self.subjectSigningKeyFingerprint = subjectSigningKeyFingerprint
        self.issuedAt = issuedAt
        self.validUntil = validUntil
    }
}

nonisolated struct DeviceCallbackRequestProof: Codable, Equatable, Sendable {
    var type: String
    var byIdentityUUID: String
    var algorithm: CurveAlgorithm
    var curveType: CurveType
    var signature: Data
}

nonisolated struct DeviceCallbackSignedRequest: Codable, Equatable, Sendable, CanonicalPayloadSignable {
    var schema: String
    var challengeID: String
    var nonce: Data
    var purpose: String
    var audience: String
    var origin: String
    var method: String
    var path: String
    var capability: String
    var bodySHA256: Data
    var requester: IdentityPublicKeyDescriptor
    var domainBinding: IdentityDomainBinding
    var authority: DeviceCallbackAuthorityReference
    var createdAt: String
    var expiresAt: String
    var proof: DeviceCallbackRequestProof?

    func canonicalPayloadData() throws -> Data {
        try CanonicalPayloadEncoder.data(for: self, excludingTopLevelKeys: ["proof"])
    }
}

nonisolated enum DeviceCallbackCapabilityError: Error, Equatable, LocalizedError {
    case authenticatedIdentityVaultUnavailable
    case notificationIdentityUnavailable
    case domainBindingUnavailable
    case invalidChallenge
    case challengeExpired
    case challengeLifetimeTooLong
    case challengeOperationMismatch
    case invalidAuthorityReference
    case authoritySubjectMismatch
    case authorityExpired
    case requestBodyInvalid
    case signingUnavailable

    var errorDescription: String? {
        switch self {
        case .authenticatedIdentityVaultUnavailable:
            "The authenticated HAVEN identity vault is unavailable."
        case .notificationIdentityUnavailable:
            "The device notification identity is unavailable."
        case .domainBindingUnavailable:
            "The notification identity has no unambiguous vault domain binding."
        case .invalidChallenge:
            "The device capability challenge is invalid."
        case .challengeExpired:
            "The device capability challenge has expired."
        case .challengeLifetimeTooLong:
            "The device capability challenge exceeds the maximum lifetime."
        case .challengeOperationMismatch:
            "The device capability challenge does not match this request."
        case .invalidAuthorityReference:
            "The device callback authority reference is invalid."
        case .authoritySubjectMismatch:
            "The device callback authority is bound to another identity."
        case .authorityExpired:
            "The device callback authority has expired."
        case .requestBodyInvalid:
            "The protected request body is empty or too large."
        case .signingUnavailable:
            "The device notification identity could not sign the request."
        }
    }
}

/// A capability signer may only be created from the authenticated, persistent
/// CellApple vault. The prompt-free startup vault is intentionally excluded:
/// its identity is process-local and would break device continuity at restart.
nonisolated struct DeviceCallbackAuthenticatedVaultHandle: Sendable {
    fileprivate let identityVault: any IdentityVaultProtocol

    @MainActor
    static func current() throws -> DeviceCallbackAuthenticatedVaultHandle {
        guard BindingRuntimeBootstrap.authenticatedRuntimeIsReady,
              let identityVault = CellBase.defaultIdentityVault,
              identityVault is IdentityVault else {
            throw DeviceCallbackCapabilityError.authenticatedIdentityVaultUnavailable
        }
        return DeviceCallbackAuthenticatedVaultHandle(identityVault: identityVault)
    }

    #if DEBUG
    /// Unit tests exercise the wire contract without opening LocalAuthentication.
    /// Production call sites cannot construct this handle from an arbitrary vault.
    static func testing(
        _ identityVault: any IdentityVaultProtocol
    ) -> DeviceCallbackAuthenticatedVaultHandle {
        DeviceCallbackAuthenticatedVaultHandle(identityVault: identityVault)
    }
    #endif
}

nonisolated struct DeviceCallbackCapabilityProofIssuer: Sendable {
    let identityVault: any IdentityVaultProtocol
    let identityContext: String

    init(
        authenticatedVault: DeviceCallbackAuthenticatedVaultHandle,
        identityContext: String = DeviceCallbackCapabilityContract.identityContext
    ) {
        self.identityVault = authenticatedVault.identityVault
        self.identityContext = identityContext
    }

    func issue(
        operation: DeviceCallbackCapabilityContract.Operation,
        body: Data,
        challenge: DeviceCallbackCapabilityChallenge,
        authority: DeviceCallbackAuthorityReference,
        expectedAudience: String,
        expectedOrigin: String,
        now: Date = Date()
    ) async throws -> DeviceCallbackSignedRequest {
        guard body.isEmpty == false,
              body.count <= DeviceCallbackCapabilityContract.maximumBodySize else {
            throw DeviceCallbackCapabilityError.requestBodyInvalid
        }

        let challengeDates = try validate(
            challenge: challenge,
            operation: operation,
            expectedAudience: expectedAudience,
            expectedOrigin: expectedOrigin,
            now: now
        )

        guard authority.schema == DeviceCallbackCapabilityContract.authorityReferenceSchema,
              normalizedIdentifier(authority.credentialID) != nil,
              normalizedIdentifier(authority.agreementID) != nil,
              normalizedIdentifier(authority.participantID) != nil,
              normalizedIdentifier(authority.deviceID) != nil,
              normalizedIdentifier(authority.subjectIdentityUUID) != nil,
              normalizedIdentifier(authority.subjectSigningKeyFingerprint) != nil,
              let authorityIssuedAt = parseDate(authority.issuedAt),
              let authorityExpiry = parseDate(authority.validUntil) else {
            throw DeviceCallbackCapabilityError.invalidAuthorityReference
        }
        guard authorityExpiry > authorityIssuedAt,
              authorityIssuedAt <= now.addingTimeInterval(DeviceCallbackCapabilityContract.maximumClockSkew) else {
            throw DeviceCallbackCapabilityError.invalidAuthorityReference
        }
        guard authorityExpiry > now else {
            throw DeviceCallbackCapabilityError.authorityExpired
        }
        guard authorityExpiry.timeIntervalSince(authorityIssuedAt)
                <= DeviceCallbackCapabilityContract.maximumAuthorityTTL else {
            throw DeviceCallbackCapabilityError.invalidAuthorityReference
        }

        guard let identity = await identityVault.identity(
            for: identityContext,
            makeNewIfNotFound: false
        ), let requester = IdentityPublicKeySignatureVerifier.descriptor(for: identity) else {
            throw DeviceCallbackCapabilityError.notificationIdentityUnavailable
        }
        guard authority.subjectIdentityUUID == identity.uuid else {
            throw DeviceCallbackCapabilityError.authoritySubjectMismatch
        }
        guard authority.subjectSigningKeyFingerprint == identity.signingPublicKeyFingerprint else {
            throw DeviceCallbackCapabilityError.authoritySubjectMismatch
        }
        guard let domainBinding = await identityVault.identityDomainBinding(for: identity),
              domainBinding.matches(identity: identity),
              domainBinding.domain == identityContext,
              domainBinding.grantsAuthority == false else {
            throw DeviceCallbackCapabilityError.domainBindingUnavailable
        }

        let requestExpiry = min(
            challengeDates.expiresAt,
            authorityExpiry,
            now.addingTimeInterval(DeviceCallbackCapabilityContract.maximumRequestTTL)
        )
        guard requestExpiry > now else {
            throw DeviceCallbackCapabilityError.challengeExpired
        }

        var request = DeviceCallbackSignedRequest(
            schema: DeviceCallbackCapabilityContract.requestSchema,
            challengeID: challenge.challengeID,
            nonce: challenge.nonce,
            purpose: challenge.purpose,
            audience: challenge.audience,
            origin: challenge.origin,
            method: challenge.method,
            path: challenge.path,
            capability: challenge.capability,
            bodySHA256: DeviceCallbackCapabilityContract.sha256(body),
            requester: requester,
            domainBinding: domainBinding,
            authority: authority,
            createdAt: formatDate(now),
            expiresAt: formatDate(requestExpiry),
            proof: nil
        )

        let canonicalPayload = try request.canonicalPayloadData()
        guard let signature = try await identity.sign(data: canonicalPayload),
              IdentityPublicKeySignatureVerifier.verify(
                signature: signature,
                messageData: canonicalPayload,
                descriptor: requester
              ) else {
            throw DeviceCallbackCapabilityError.signingUnavailable
        }
        request.proof = DeviceCallbackRequestProof(
            type: DeviceCallbackCapabilityContract.proofType,
            byIdentityUUID: identity.uuid,
            algorithm: requester.algorithm,
            curveType: requester.curveType,
            signature: signature
        )
        return request
    }

    private func validate(
        challenge: DeviceCallbackCapabilityChallenge,
        operation: DeviceCallbackCapabilityContract.Operation,
        expectedAudience: String,
        expectedOrigin: String,
        now: Date
    ) throws -> (issuedAt: Date, expiresAt: Date) {
        guard challenge.schema == DeviceCallbackCapabilityContract.challengeSchema,
              challenge.purpose == DeviceCallbackCapabilityContract.purpose,
              normalizedIdentifier(challenge.challengeID) != nil,
              challenge.nonce.count >= 16,
              challenge.nonce.count <= 64,
              challenge.audience == expectedAudience,
              challenge.origin == expectedOrigin,
              let issuedAt = parseDate(challenge.issuedAt),
              let expiresAt = parseDate(challenge.expiresAt),
              expiresAt > issuedAt,
              issuedAt <= now.addingTimeInterval(DeviceCallbackCapabilityContract.maximumClockSkew) else {
            throw DeviceCallbackCapabilityError.invalidChallenge
        }
        guard expiresAt > now else {
            throw DeviceCallbackCapabilityError.challengeExpired
        }
        guard expiresAt.timeIntervalSince(issuedAt) <= DeviceCallbackCapabilityContract.maximumChallengeTTL else {
            throw DeviceCallbackCapabilityError.challengeLifetimeTooLong
        }
        guard challenge.method == operation.method,
              challenge.path == operation.path,
              challenge.capability == operation.capability else {
            throw DeviceCallbackCapabilityError.challengeOperationMismatch
        }
        return (issuedAt, expiresAt)
    }

    private func normalizedIdentifier(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              trimmed.utf8.count <= 512 else {
            return nil
        }
        return trimmed
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
