import Foundation
import CryptoKit
import CellBase
import CellApple
import Darwin
import Security

nonisolated enum DeviceIngressRegistrationClientError: LocalizedError, Equatable {
    case operationalCompositionUnavailable
    case authenticatedIdentityVaultUnavailable
    case notificationIdentityUnavailable
    case notificationDomainBindingUnavailable
    case notificationIdentityDescriptorUnavailable
    case invalidProtectedBody
    case pendingRegistrationExists
    case verifiedRegistrationExists
    case preRegistrationDeclined
    case persistedTermsAcceptanceRequired
    case registrationEvidencePreventsPreRegistrationDecline
    case pendingExpectationMissing
    case pendingExpectationMismatch
    case evidenceTooLarge
    case evidenceDirectoryUnavailable
    case verifiedEvidenceDeviceIdentityMismatch
    case buildProvenanceMismatch
    case invalidEvidenceJournal
    case responseWasNotRegistration
    case registrationWasNotActiveAndConsented
    case invalidTransportConfiguration
    case transportRejected

    var errorDescription: String? {
        switch self {
        case .operationalCompositionUnavailable:
            return "DeviceIngress v3 registration is fail-closed until the reviewed server composition and pinned trust configuration are operational."
        case .authenticatedIdentityVaultUnavailable:
            return "The authenticated persistent CellApple identity vault is unavailable."
        case .notificationIdentityUnavailable:
            return "The persistent notification-callback identity has not been provisioned."
        case .notificationDomainBindingUnavailable:
            return "The notification-callback identity is not uniquely bound to its required domain."
        case .notificationIdentityDescriptorUnavailable:
            return "The notification-callback identity has no usable public signing descriptor."
        case .invalidProtectedBody:
            return "The protected registration body is empty or exceeds the DeviceIngress limit."
        case .pendingRegistrationExists:
            return "An unresolved DeviceIngress registration request already exists; automatic replay is disabled."
        case .verifiedRegistrationExists:
            return "Historical verified registration evidence already exists; a fresh signed status/read-back is required before another register attempt."
        case .preRegistrationDeclined:
            return "Notification registration is locally closed by a durable pre-registration decline."
        case .persistedTermsAcceptanceRequired:
            return "The exact accepted notification-terms evidence is not durably persisted."
        case .registrationEvidencePreventsPreRegistrationDecline:
            return "Pending or verified registration evidence exists; pre-registration decline cannot represent server revocation, so a signed revoke/deregister flow is required."
        case .pendingExpectationMissing:
            return "The persisted response expectation is missing."
        case .pendingExpectationMismatch:
            return "The persisted response expectation does not match this registration response."
        case .evidenceTooLarge:
            return "The persisted DeviceIngress evidence exceeds its local size limit."
        case .evidenceDirectoryUnavailable:
            return "The persistent DeviceIngress evidence directory is unavailable."
        case .verifiedEvidenceDeviceIdentityMismatch:
            return "The verified registration evidence belongs to a different device identity."
        case .buildProvenanceMismatch:
            return "The verified registration evidence belongs to a different Binding build."
        case .invalidEvidenceJournal:
            return "The DeviceIngress evidence journal is missing its exact monotonic anchor, has an invalid hash chain, or contains an invalid state transition."
        case .responseWasNotRegistration:
            return "The signed DeviceIngress response was not a registration receipt."
        case .registrationWasNotActiveAndConsented:
            return "The signed registration receipt did not confirm active consent."
        case .invalidTransportConfiguration:
            return "DeviceIngress HTTPS origin, audience, or pinned challenge issuer is missing or invalid."
        case .transportRejected:
            return "The DeviceIngress HTTPS carrier rejected the request or returned invalid bytes."
        }
    }
}

nonisolated struct DeviceIngressRegistrationTrustConfiguration: Sendable {
    let expectedAudience: String
    let expectedChallengeIssuer: IdentityPublicKeyDescriptor
}

nonisolated protocol DeviceIngressRegistrationTransport: Sendable {
    /// Retrieves exact canonical challenge bytes. Transport framing is outside
    /// this protocol and must come from a separately reviewed composition.
    func fetchRegisterChallenge(
        subject: IdentityPublicKeyDescriptor
    ) async throws -> Data

    /// Carries the three byte strings without decoding, re-encoding or making
    /// an authority decision.
    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data
}

nonisolated struct InertDeviceIngressRegistrationTransport: DeviceIngressRegistrationTransport {
    func fetchRegisterChallenge(
        subject: IdentityPublicKeyDescriptor
    ) async throws -> Data {
        throw DeviceIngressRegistrationClientError.operationalCompositionUnavailable
    }

    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data {
        throw DeviceIngressRegistrationClientError.operationalCompositionUnavailable
    }
}

nonisolated private struct DeviceIngressRegisterChallengeTransportRequest:
    Codable,
    Sendable
{
    static let currentSchema = "haven.device-ingress.challenge-request.v1"

    let schema: String
    let operation: DeviceIngressOperation
    let subject: IdentityPublicKeyDescriptor

    init(subject: IdentityPublicKeyDescriptor) {
        schema = Self.currentSchema
        operation = .register
        self.subject = subject
    }
}

nonisolated private struct DeviceIngressRegisterTransportEnvelope:
    Codable,
    Sendable
{
    static let currentSchema = "haven.device-callback.transport.v3"

    let schema: String
    let canonicalChallenge: Data
    let canonicalRequest: Data
    let protectedBody: Data

    init(
        canonicalChallenge: Data,
        canonicalRequest: Data,
        protectedBody: Data
    ) {
        schema = Self.currentSchema
        self.canonicalChallenge = canonicalChallenge
        self.canonicalRequest = canonicalRequest
        self.protectedBody = protectedBody
    }
}

nonisolated final class DeviceIngressNoRedirectSessionDelegate:
    NSObject,
    URLSessionTaskDelegate,
    @unchecked Sendable
{
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

nonisolated struct URLSessionDeviceIngressRegistrationTransport:
    DeviceIngressRegistrationTransport,
    @unchecked Sendable
{
    private let origin: URL
    private let session: URLSession

    init(origin: URL, session: URLSession? = nil) throws {
        guard origin.scheme?.lowercased() == "https",
              origin.user == nil,
              origin.password == nil,
              origin.query == nil,
              origin.fragment == nil,
              origin.path.isEmpty || origin.path == "/",
              origin.host?.isEmpty == false else {
            throw DeviceIngressRegistrationClientError.invalidTransportConfiguration
        }
        self.origin = origin
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.httpShouldSetCookies = false
            configuration.httpCookieAcceptPolicy = .never
            self.session = URLSession(
                configuration: configuration,
                delegate: DeviceIngressNoRedirectSessionDelegate(),
                delegateQueue: nil
            )
        }
    }

    func fetchRegisterChallenge(
        subject: IdentityPublicKeyDescriptor
    ) async throws -> Data {
        try await post(
            path: "/conference-mvp/api/device/challenge",
            body: try Self.encoded(
                DeviceIngressRegisterChallengeTransportRequest(subject: subject)
            ),
            maximumResponseBytes: DeviceIngressEnvelope.maximumEncodedBytes
        )
    }

    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data {
        try await post(
            path: "/conference-mvp/api/device/register",
            body: try Self.encoded(DeviceIngressRegisterTransportEnvelope(
                canonicalChallenge: canonicalChallengeData,
                canonicalRequest: canonicalRequestData,
                protectedBody: protectedBody
            )),
            maximumResponseBytes: DeviceIngressOperationResponse.maximumEncodedBytes
        )
    }

    private func post(
        path: String,
        body: Data,
        maximumResponseBytes: Int
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: origin)?.absoluteURL,
              url.scheme == origin.scheme,
              url.host == origin.host,
              url.port == origin.port else {
            throw DeviceIngressRegistrationClientError.invalidTransportConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              responseData.isEmpty == false,
              responseData.count <= maximumResponseBytes,
              http.url?.scheme == origin.scheme,
              http.url?.host == origin.host,
              http.url?.port == origin.port else {
            throw DeviceIngressRegistrationClientError.transportRejected
        }
        return responseData
    }

    private static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

nonisolated struct BindingDeviceIngressRuntimeConfiguration:
    Sendable
{
    static let originKey = "HAVENDeviceIngressPublicOrigin"
    static let audienceKey = "HAVENDeviceIngressAudience"
    static let issuerKey = "HAVENDeviceIngressChallengeIssuerBase64"

    let origin: URL
    let trust: DeviceIngressRegistrationTrustConfiguration

    static func current(bundle: Bundle = .main) throws -> Self {
        try validated(
            originText: bundle.object(
            forInfoDictionaryKey: originKey
            ) as? String,
            audienceText: bundle.object(
                  forInfoDictionaryKey: audienceKey
            ) as? String,
            issuerBase64Text: bundle.object(
                  forInfoDictionaryKey: issuerKey
            ) as? String
        )
    }

    static func validated(
        originText: String?,
        audienceText: String?,
        issuerBase64Text: String?
    ) throws -> Self {
        guard let originText = normalized(originText),
              let audience = normalized(audienceText),
              let issuerBase64 = normalized(issuerBase64Text),
              let origin = URL(string: originText),
              origin.scheme?.lowercased() == "https",
              origin.user == nil,
              origin.password == nil,
              origin.query == nil,
              origin.fragment == nil,
              origin.path.isEmpty || origin.path == "/",
              let host = origin.host?.lowercased(),
              audience == "\(host)\(origin.port.map { ":\($0)" } ?? "")",
              let issuerData = Data(base64Encoded: issuerBase64),
              let issuer = try? JSONDecoder().decode(
                  IdentityPublicKeyDescriptor.self,
                  from: issuerData
              ),
              issuer.displayName == nil,
              IdentityLinkProtocolService.identity(from: issuer)
                .signingPublicKeyFingerprint != nil else {
            throw DeviceIngressRegistrationClientError.invalidTransportConfiguration
        }
        return Self(
            origin: origin,
            trust: DeviceIngressRegistrationTrustConfiguration(
                expectedAudience: audience,
                expectedChallengeIssuer: issuer
            )
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              trimmed.contains("$(") == false else {
            return nil
        }
        return trimmed
    }
}

nonisolated struct DeviceIngressVerifiedRegistrationEvidence: Codable, Equatable, Sendable {
    static let currentSchema = "binding.device-ingress.registration-evidence.v3"

    let schema: String
    let expectation: DeviceIngressResponseExpectation
    let canonicalResponseData: Data
    let buildProvenance: BindingBuildProvenance
    let vaultBinding: DeviceIngressPersistedVaultBinding

    init(
        expectation: DeviceIngressResponseExpectation,
        canonicalResponseData: Data,
        buildProvenance: BindingBuildProvenance,
        vaultBinding: DeviceIngressPersistedVaultBinding
    ) {
        schema = Self.currentSchema
        self.expectation = expectation
        self.canonicalResponseData = canonicalResponseData
        self.buildProvenance = buildProvenance
        self.vaultBinding = vaultBinding
    }
}

nonisolated struct DeviceIngressPersistedVaultBinding: Codable, Equatable, Sendable {
    static let currentSchema = "binding.device-ingress.vault-binding.v1"

    let schema: String
    let identityDomain: String
    let identityUUID: String
    let signingKeyFingerprint: String

    init(
        binding: IdentityDomainBinding,
        identity: Identity,
        descriptor: IdentityPublicKeyDescriptor
    ) throws {
        guard binding.schema == IdentityDomainBinding.currentSchema,
              binding.bindingKind == IdentityDomainBinding.vaultContextKind,
              binding.grantsAuthority == false,
              binding.domain == DeviceIngressEnvelope.identityDomain,
              binding.identityUUID == descriptor.uuid,
              binding.matches(identity: identity),
              DeviceIngressIdentityDescriptor.publicDescriptor(for: identity) == descriptor,
              binding.identityUUID.isEmpty == false,
              binding.signingKeyFingerprint.isEmpty == false else {
            throw DeviceIngressRegistrationClientError.notificationDomainBindingUnavailable
        }
        schema = Self.currentSchema
        identityDomain = binding.domain
        identityUUID = binding.identityUUID
        signingKeyFingerprint = binding.signingKeyFingerprint
    }
}

/// Cryptographically verified history from an earlier register mutation.
/// This type intentionally cannot represent current registration state. A
/// current-state claim requires a new signed server status/read-back bound to
/// current admission and revocation generations, which the register-only
/// Binding composition does not implement.
nonisolated struct DeviceIngressHistoricalRegistrationEvidence: Equatable, Sendable {
    let receiptAtMutation: DeviceIngressRegistrationReceipt
    let admissionID: String
    let authorityGeneration: UInt64
    let revocationLedgerID: String
    let revocationGeneration: UInt64
    let signedResponseIssuedAtMilliseconds: Int64
    let buildProvenance: BindingBuildProvenance
}

nonisolated struct DeviceIngressPreRegistrationDeclineTombstone:
    Codable,
    Equatable,
    Sendable
{
    static let currentSchema = "binding.device-ingress.pre-registration-decline.v1"

    let schema: String

    init() {
        schema = Self.currentSchema
    }
}

nonisolated private enum DeviceIngressEvidenceMutation: String, Codable, Sendable {
    case acceptTerms
    case declineTerms
    case persistPending
    case commitVerified
}

nonisolated private struct DeviceIngressEvidenceStateSnapshot:
    Codable,
    Equatable,
    Sendable
{
    let consentState: NotificationTermsConsentState
    let acceptedConsentEvidence: NotificationTermsConsentEvidence?
    let pendingExpectation: DeviceIngressResponseExpectation?
    let verifiedEvidence: DeviceIngressVerifiedRegistrationEvidence?

    static let empty = Self(
        consentState: .unknown,
        acceptedConsentEvidence: nil,
        pendingExpectation: nil,
        verifiedEvidence: nil
    )

    func validate() throws {
        switch consentState {
        case .unknown, .declined:
            guard acceptedConsentEvidence == nil else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
        case .accepted:
            guard let acceptedConsentEvidence,
                  acceptedConsentEvidence.schema
                    == NotificationTermsConsentEvidence.currentSchema,
                  acceptedConsentEvidence.state == .accepted,
                  acceptedConsentEvidence.acceptanceID.isEmpty == false,
                  acceptedConsentEvidence.termsVersion.isEmpty == false,
                  acceptedConsentEvidence.acceptedAtMilliseconds > 0 else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
        }
        guard pendingExpectation == nil || verifiedEvidence == nil else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
        if pendingExpectation != nil || verifiedEvidence != nil {
            guard consentState == .accepted,
                  acceptedConsentEvidence != nil else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
        }
        if let verifiedEvidence {
            guard verifiedEvidence.schema
                    == DeviceIngressVerifiedRegistrationEvidence.currentSchema,
                  verifiedEvidence.expectation.operation == .register,
                  verifiedEvidence.vaultBinding.schema
                    == DeviceIngressPersistedVaultBinding.currentSchema,
                  verifiedEvidence.vaultBinding.identityDomain
                    == DeviceIngressEnvelope.identityDomain,
                  verifiedEvidence.vaultBinding.identityUUID
                    == verifiedEvidence.expectation.subjectIdentityUUID,
                  verifiedEvidence.vaultBinding.signingKeyFingerprint
                    == verifiedEvidence.expectation.subjectSigningKeyFingerprint else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
        }
    }
}

nonisolated private struct DeviceIngressEvidenceJournalEntry:
    Codable,
    Equatable,
    Sendable
{
    struct HashPayload: Codable {
        let sequence: UInt64
        let previousEntrySHA256: String
        let mutation: DeviceIngressEvidenceMutation
        let state: DeviceIngressEvidenceStateSnapshot
    }

    let sequence: UInt64
    let previousEntrySHA256: String
    let mutation: DeviceIngressEvidenceMutation
    let state: DeviceIngressEvidenceStateSnapshot
    let entrySHA256: String

    init(
        sequence: UInt64,
        previousEntrySHA256: String,
        mutation: DeviceIngressEvidenceMutation,
        state: DeviceIngressEvidenceStateSnapshot
    ) throws {
        self.sequence = sequence
        self.previousEntrySHA256 = previousEntrySHA256
        self.mutation = mutation
        self.state = state
        entrySHA256 = try Self.hash(
            sequence: sequence,
            previousEntrySHA256: previousEntrySHA256,
            mutation: mutation,
            state: state
        )
    }

    func validateHash() throws {
        let expectedEntrySHA256 = try Self.hash(
            sequence: sequence,
            previousEntrySHA256: previousEntrySHA256,
            mutation: mutation,
            state: state
        )
        guard entrySHA256 == expectedEntrySHA256 else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
    }

    private static func hash(
        sequence: UInt64,
        previousEntrySHA256: String,
        mutation: DeviceIngressEvidenceMutation,
        state: DeviceIngressEvidenceStateSnapshot
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(HashPayload(
            sequence: sequence,
            previousEntrySHA256: previousEntrySHA256,
            mutation: mutation,
            state: state
        ))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated private struct DeviceIngressEvidenceJournal:
    Codable,
    Equatable,
    Sendable
{
    static let currentSchema = "binding.device-ingress.evidence-journal.v1"
    static let genesisSHA256 = String(repeating: "0", count: 64)
    static let maximumEntryCount = 1_024

    let schema: String
    let entries: [DeviceIngressEvidenceJournalEntry]

    init(entries: [DeviceIngressEvidenceJournalEntry]) {
        schema = Self.currentSchema
        self.entries = entries
    }

    var currentState: DeviceIngressEvidenceStateSnapshot {
        entries.last?.state ?? .empty
    }

    var currentAnchor: DeviceIngressEvidenceJournalAnchor? {
        entries.last.map {
            DeviceIngressEvidenceJournalAnchor(
                sequence: $0.sequence,
                journalHeadSHA256: $0.entrySHA256
            )
        }
    }

    var previousAnchor: DeviceIngressEvidenceJournalAnchor? {
        entries.dropLast().last.map {
            DeviceIngressEvidenceJournalAnchor(
                sequence: $0.sequence,
                journalHeadSHA256: $0.entrySHA256
            )
        }
    }

    func appending(
        mutation: DeviceIngressEvidenceMutation,
        state: DeviceIngressEvidenceStateSnapshot
    ) throws -> Self {
        guard entries.count < Self.maximumEntryCount else {
            throw DeviceIngressRegistrationClientError.evidenceTooLarge
        }
        let entry = try DeviceIngressEvidenceJournalEntry(
            sequence: UInt64(entries.count + 1),
            previousEntrySHA256: entries.last?.entrySHA256 ?? Self.genesisSHA256,
            mutation: mutation,
            state: state
        )
        let result = Self(entries: entries + [entry])
        try result.validate()
        return result
    }

    func validate() throws {
        guard schema == Self.currentSchema,
              entries.isEmpty == false,
              entries.count <= Self.maximumEntryCount else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
        var previousState = DeviceIngressEvidenceStateSnapshot.empty
        var previousHash = Self.genesisSHA256
        for (index, entry) in entries.enumerated() {
            guard entry.sequence == UInt64(index + 1),
                  entry.previousEntrySHA256 == previousHash else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
            try entry.validateHash()
            try entry.state.validate()
            try Self.validateTransition(
                mutation: entry.mutation,
                from: previousState,
                to: entry.state
            )
            previousState = entry.state
            previousHash = entry.entrySHA256
        }
    }

    private static func validateTransition(
        mutation: DeviceIngressEvidenceMutation,
        from old: DeviceIngressEvidenceStateSnapshot,
        to new: DeviceIngressEvidenceStateSnapshot
    ) throws {
        switch mutation {
        case .acceptTerms:
            guard old.pendingExpectation == nil,
                  old.verifiedEvidence == nil,
                  new.consentState == .accepted,
                  new.acceptedConsentEvidence != nil,
                  new.pendingExpectation == nil,
                  new.verifiedEvidence == nil else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
        case .declineTerms:
            guard old.pendingExpectation == nil,
                  old.verifiedEvidence == nil,
                  new.consentState == .declined,
                  new.acceptedConsentEvidence == nil,
                  new.pendingExpectation == nil,
                  new.verifiedEvidence == nil else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
        case .persistPending:
            guard old.consentState == .accepted,
                  old.acceptedConsentEvidence == new.acceptedConsentEvidence,
                  old.pendingExpectation == nil,
                  old.verifiedEvidence == nil,
                  new.consentState == .accepted,
                  new.pendingExpectation != nil,
                  new.verifiedEvidence == nil else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
        case .commitVerified:
            guard old.consentState == .accepted,
                  old.acceptedConsentEvidence == new.acceptedConsentEvidence,
                  let pending = old.pendingExpectation,
                  old.verifiedEvidence == nil,
                  new.consentState == .accepted,
                  new.pendingExpectation == nil,
                  new.verifiedEvidence?.expectation == pending else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
        }
    }
}

/// The current journal head is anchored outside the replaceable journal. The
/// production anchor lives in the device-local Keychain; the file-backed form
/// is available only to DEBUG tests that use an isolated temporary directory.
nonisolated private struct DeviceIngressEvidenceJournalAnchor:
    Codable,
    Equatable,
    Sendable
{
    static let currentSchema = "binding.device-ingress.evidence-journal-anchor.v1"

    let schema: String
    let sequence: UInt64
    let journalHeadSHA256: String

    init(sequence: UInt64, journalHeadSHA256: String) {
        schema = Self.currentSchema
        self.sequence = sequence
        self.journalHeadSHA256 = journalHeadSHA256
    }

    func validate() throws {
        guard schema == Self.currentSchema,
              sequence > 0,
              journalHeadSHA256.count == 64,
              journalHeadSHA256.allSatisfy({
                $0.isHexDigit && $0.isUppercase == false
              }) else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
    }

    func validateAdvance(after previous: Self?) throws {
        try validate()
        guard sequence == (previous?.sequence ?? 0) + 1 else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
    }
}

nonisolated protocol DeviceIngressRegistrationEvidenceStoring: Sendable {
    func termsConsentSnapshot() throws -> NotificationTermsConsentSnapshot
    func persistTermsAcceptance(_ evidence: NotificationTermsConsentEvidence) throws
    func persistPending(
        _ expectation: DeviceIngressResponseExpectation,
        consentEvidence: NotificationTermsConsentEvidence
    ) throws
    func pendingExpectation() throws -> DeviceIngressResponseExpectation?
    func commitVerified(
        expectation: DeviceIngressResponseExpectation,
        canonicalResponseData: Data,
        buildProvenance: BindingBuildProvenance,
        vaultBinding: DeviceIngressPersistedVaultBinding
    ) throws
    func verifiedEvidence() throws -> DeviceIngressVerifiedRegistrationEvidence?
    func containsRegistrationEvidence() throws -> Bool
    func performPreRegistrationDecline(_ localStateClear: () -> Void) throws
}

nonisolated enum DeviceIngressEvidenceFileError: LocalizedError, Equatable {
    case posix(operation: String, code: Int32)
    case secureAnchor(operation: String, status: OSStatus)
    case invalidPathComponent
    case metadataRejected(reason: String)
    case pathIdentityChanged
    case contentChangedDuringAccess

    var errorDescription: String? {
        switch self {
        case let .posix(operation, code):
            return "DeviceIngress evidence \(operation) failed with errno \(code)."
        case let .secureAnchor(operation, status):
            return "DeviceIngress secure journal anchor \(operation) failed with status \(status)."
        case .invalidPathComponent:
            return "DeviceIngress evidence contains an invalid path component."
        case let .metadataRejected(reason):
            return "DeviceIngress evidence metadata was rejected: \(reason)."
        case .pathIdentityChanged:
            return "DeviceIngress evidence path identity changed during access."
        case .contentChangedDuringAccess:
            return "DeviceIngress evidence content changed during access."
        }
    }
}

nonisolated private struct KeychainDeviceIngressJournalAnchorStore: Sendable {
    private static let service = "org.digipomps.binding.device-ingress-journal-anchor"
    private let account: String

    init(namespace: String) {
        account = SHA256.hash(data: Data(namespace.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func load() throws -> DeviceIngressEvidenceJournalAnchor? {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw DeviceIngressEvidenceFileError.secureAnchor(
                operation: "read",
                status: status
            )
        }
        do {
            let anchor = try JSONDecoder().decode(
                DeviceIngressEvidenceJournalAnchor.self,
                from: data
            )
            try anchor.validate()
            return anchor
        } catch {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
    }

    func compareAndSwap(
        expected: DeviceIngressEvidenceJournalAnchor?,
        new: DeviceIngressEvidenceJournalAnchor
    ) throws {
        let actual = try load()
        guard actual == expected else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
        try new.validateAdvance(after: expected)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(new)
        let status: OSStatus
        if actual == nil {
            var query = baseQuery
            query[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            query[kSecAttrSynchronizable as String] = false
            query[kSecValueData as String] = data
            status = SecItemAdd(query as CFDictionary, nil)
        } else {
            status = SecItemUpdate(
                baseQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
        }
        guard status == errSecSuccess else {
            throw DeviceIngressEvidenceFileError.secureAnchor(
                operation: actual == nil ? "create" : "advance",
                status: status
            )
        }
        guard try load() == new else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ]
    }
}

nonisolated struct DeviceIngressEvidenceMetadataSnapshot: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let mode: UInt32
    let owner: UInt32
    let linkCount: UInt64
    let size: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64

    init(
        device: UInt64,
        inode: UInt64,
        mode: UInt32,
        owner: UInt32,
        linkCount: UInt64,
        size: Int64,
        modificationSeconds: Int64,
        modificationNanoseconds: Int64,
        changeSeconds: Int64,
        changeNanoseconds: Int64
    ) {
        self.device = device
        self.inode = inode
        self.mode = mode
        self.owner = owner
        self.linkCount = linkCount
        self.size = size
        self.modificationSeconds = modificationSeconds
        self.modificationNanoseconds = modificationNanoseconds
        self.changeSeconds = changeSeconds
        self.changeNanoseconds = changeNanoseconds
    }

    init(_ value: stat) {
        device = UInt64(bitPattern: Int64(value.st_dev))
        inode = UInt64(value.st_ino)
        mode = UInt32(value.st_mode)
        owner = UInt32(value.st_uid)
        linkCount = UInt64(value.st_nlink)
        size = Int64(value.st_size)
        modificationSeconds = Int64(value.st_mtimespec.tv_sec)
        modificationNanoseconds = Int64(value.st_mtimespec.tv_nsec)
        changeSeconds = Int64(value.st_ctimespec.tv_sec)
        changeNanoseconds = Int64(value.st_ctimespec.tv_nsec)
    }

    func hasSameIdentity(as other: Self) -> Bool {
        device == other.device && inode == other.inode
    }
}

nonisolated enum DeviceIngressEvidenceMetadataPolicy {
    static func validateOwnedDirectory(
        _ metadata: DeviceIngressEvidenceMetadataSnapshot,
        expectedOwner: UInt32
    ) throws {
        guard metadata.mode & UInt32(S_IFMT) == UInt32(S_IFDIR) else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "not-directory")
        }
        guard metadata.mode & 0o022 == 0 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(
                reason: "directory-group-or-other-writable"
            )
        }
        guard metadata.owner == expectedOwner else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "directory-owner")
        }
    }

    static func validateDirectory(
        _ metadata: DeviceIngressEvidenceMetadataSnapshot,
        expectedOwner: UInt32
    ) throws {
        guard metadata.mode & UInt32(S_IFMT) == UInt32(S_IFDIR) else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "not-directory")
        }
        guard metadata.mode & 0o7777 == 0o700 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "directory-mode")
        }
        guard metadata.owner == expectedOwner else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "directory-owner")
        }
    }

    static func validateRegularFile(
        _ metadata: DeviceIngressEvidenceMetadataSnapshot,
        expectedOwner: UInt32,
        maximumSize: Int
    ) throws {
        guard metadata.mode & UInt32(S_IFMT) == UInt32(S_IFREG) else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "not-regular")
        }
        guard metadata.mode & 0o7777 == 0o600 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "file-mode")
        }
        guard metadata.owner == expectedOwner else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "file-owner")
        }
        guard metadata.linkCount == 1 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "file-link-count")
        }
        guard metadata.size >= 0, metadata.size <= Int64(maximumSize) else {
            throw DeviceIngressRegistrationClientError.evidenceTooLarge
        }
    }
}

nonisolated protocol DeviceIngressEvidenceReadObserving: Sendable {
    func didOpenForRead(fileName: String) throws
    func didAcquireCanonicalLock(fileName: String) throws
}

nonisolated extension DeviceIngressEvidenceReadObserving {
    func didAcquireCanonicalLock(fileName: String) throws {}
}

nonisolated struct NoopDeviceIngressEvidenceReadObserver:
    DeviceIngressEvidenceReadObserving
{
    func didOpenForRead(fileName: String) throws {}
}

nonisolated protocol DeviceIngressDurabilitySynchronizing: Sendable {
    func synchronizeFile(_ descriptor: Int32) throws
    func synchronizeDirectory(_ descriptor: Int32) throws
}

nonisolated struct DarwinDeviceIngressDurabilitySynchronizer:
    DeviceIngressDurabilitySynchronizing
{
    func synchronizeFile(_ descriptor: Int32) throws {
        guard Darwin.fsync(descriptor) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "file fsync",
                code: errno
            )
        }
        guard Darwin.fcntl(descriptor, F_FULLFSYNC) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "file fullfsync",
                code: errno
            )
        }
    }

    func synchronizeDirectory(_ descriptor: Int32) throws {
        guard Darwin.fsync(descriptor) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "directory fsync",
                code: errno
            )
        }
    }
}

nonisolated final class FileDeviceIngressRegistrationEvidenceStore:
    DeviceIngressRegistrationEvidenceStoring,
    @unchecked Sendable
{
    private static let maximumEvidenceBytes = 256 * 1_024
    private static let processLock = NSLock()
    private let anchorPath: String
    private let relativeDirectoryComponents: [String]
    private let synchronizer: any DeviceIngressDurabilitySynchronizing
    private let readObserver: any DeviceIngressEvidenceReadObserving
    private let journalAnchorStorage: JournalAnchorStorage
    private var pinnedDirectories: [PinnedDirectory] = []
    private var activeTransactionValidator: (() throws -> Void)?

    private struct PinnedDirectory: Sendable {
        let descriptor: Int32
        let parentIndex: Int?
        let nameInParent: String?
        let requiresOwnedMetadata: Bool
        let requiresPrivateMetadata: Bool
    }

    private enum JournalAnchorStorage: Sendable {
        case keychain(KeychainDeviceIngressJournalAnchorStore)
        #if DEBUG
        case testFile
        #endif
    }

    #if DEBUG
    init(
        directoryURL: URL,
        synchronizer: any DeviceIngressDurabilitySynchronizing =
            DarwinDeviceIngressDurabilitySynchronizer(),
        readObserver: any DeviceIngressEvidenceReadObserving =
            NoopDeviceIngressEvidenceReadObserver()
    ) {
        anchorPath = Self.canonicalExistingPath(
            directoryURL.deletingLastPathComponent().standardizedFileURL.path
        )
        relativeDirectoryComponents = [directoryURL.lastPathComponent]
        self.synchronizer = synchronizer
        self.readObserver = readObserver
        journalAnchorStorage = .testFile
    }

    init(
        testingAnchorDirectoryURL: URL,
        relativeDirectoryComponents: [String],
        synchronizer: any DeviceIngressDurabilitySynchronizing =
            DarwinDeviceIngressDurabilitySynchronizer(),
        readObserver: any DeviceIngressEvidenceReadObserving =
            NoopDeviceIngressEvidenceReadObserver()
    ) {
        anchorPath = Self.canonicalExistingPath(
            testingAnchorDirectoryURL.standardizedFileURL.path
        )
        self.relativeDirectoryComponents = relativeDirectoryComponents
        self.synchronizer = synchronizer
        self.readObserver = readObserver
        journalAnchorStorage = .testFile
    }
    #endif

    init(
        anchorDirectoryURL: URL,
        relativeDirectoryComponents: [String],
        synchronizer: any DeviceIngressDurabilitySynchronizing =
            DarwinDeviceIngressDurabilitySynchronizer(),
        readObserver: any DeviceIngressEvidenceReadObserving =
            NoopDeviceIngressEvidenceReadObserver()
    ) {
        let canonicalAnchorPath = Self.canonicalExistingPath(
            anchorDirectoryURL.standardizedFileURL.path
        )
        anchorPath = canonicalAnchorPath
        self.relativeDirectoryComponents = relativeDirectoryComponents
        self.synchronizer = synchronizer
        self.readObserver = readObserver
        journalAnchorStorage = .keychain(KeychainDeviceIngressJournalAnchorStore(
            namespace: relativeDirectoryComponents.joined(separator: "/")
        ))
    }

    /// Foundation's `resolvingSymlinksInPath()` does not resolve macOS's
    /// top-level `/var` and `/tmp` aliases consistently. Canonicalize only the
    /// already-existing anchor once; every descendant is still opened and
    /// revalidated descriptor-relatively without following symlinks.
    private static func canonicalExistingPath(_ path: String) -> String {
        let macOSCanonicalPath: String
        if path == "/var" || path.hasPrefix("/var/") {
            macOSCanonicalPath = "/private\(path)"
        } else if path == "/tmp" || path.hasPrefix("/tmp/") {
            macOSCanonicalPath = "/private\(path)"
        } else {
            macOSCanonicalPath = path
        }
        let resolved = macOSCanonicalPath.withCString {
            Darwin.realpath($0, nil)
        }
        guard let resolved else { return macOSCanonicalPath }
        defer { Darwin.free(resolved) }
        return String(cString: resolved)
    }

    deinit {
        for directory in pinnedDirectories.reversed() {
            _ = Darwin.close(directory.descriptor)
        }
    }

    static func applicationSupport(fileManager: FileManager = .default) throws -> Self {
        guard let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
        }
        return Self(
            anchorDirectoryURL: base,
            relativeDirectoryComponents: ["Binding", "DeviceIngressRegistration"]
        )
    }

    func termsConsentSnapshot() throws -> NotificationTermsConsentSnapshot {
        try withExclusiveAccess { directoryDescriptor in
            let state = try loadJournalUnlocked(
                directoryDescriptor: directoryDescriptor
            )?.currentState ?? .empty
            return NotificationTermsConsentSnapshot(
                state: state.consentState,
                acceptedEvidence: state.acceptedConsentEvidence
            )
        }
    }

    func persistTermsAcceptance(
        _ evidence: NotificationTermsConsentEvidence
    ) throws {
        guard evidence.schema == NotificationTermsConsentEvidence.currentSchema,
              evidence.state == .accepted,
              evidence.acceptanceID.isEmpty == false,
              evidence.termsVersion.isEmpty == false,
              evidence.acceptedAtMilliseconds > 0 else {
            throw DeviceIngressRegistrationClientError.persistedTermsAcceptanceRequired
        }
        try withExclusiveAccess { directoryDescriptor in
            let existing = try loadJournalUnlocked(
                directoryDescriptor: directoryDescriptor
            )
            let old = existing?.currentState ?? .empty
            guard old.pendingExpectation == nil,
                  old.verifiedEvidence == nil else {
                throw DeviceIngressRegistrationClientError.verifiedRegistrationExists
            }
            let state = DeviceIngressEvidenceStateSnapshot(
                consentState: .accepted,
                acceptedConsentEvidence: evidence,
                pendingExpectation: nil,
                verifiedEvidence: nil
            )
            try persistJournalUnlocked(
                try (existing ?? DeviceIngressEvidenceJournal(entries: []))
                    .appending(mutation: .acceptTerms, state: state),
                replacingExisting: existing != nil,
                directoryDescriptor: directoryDescriptor
            )
        }
    }

    func persistPending(
        _ expectation: DeviceIngressResponseExpectation,
        consentEvidence: NotificationTermsConsentEvidence
    ) throws {
        try withExclusiveAccess { directoryDescriptor in
            let existing = try loadJournalUnlocked(
                directoryDescriptor: directoryDescriptor
            )
            let old = existing?.currentState ?? .empty
            guard old.consentState != .declined else {
                throw DeviceIngressRegistrationClientError.preRegistrationDeclined
            }
            guard old.consentState == .accepted,
                  old.acceptedConsentEvidence == consentEvidence else {
                throw DeviceIngressRegistrationClientError.persistedTermsAcceptanceRequired
            }
            guard old.pendingExpectation == nil else {
                throw DeviceIngressRegistrationClientError.pendingRegistrationExists
            }
            guard old.verifiedEvidence == nil else {
                throw DeviceIngressRegistrationClientError.verifiedRegistrationExists
            }
            let state = DeviceIngressEvidenceStateSnapshot(
                consentState: .accepted,
                acceptedConsentEvidence: consentEvidence,
                pendingExpectation: expectation,
                verifiedEvidence: nil
            )
            try persistJournalUnlocked(
                try (existing ?? DeviceIngressEvidenceJournal(entries: []))
                    .appending(mutation: .persistPending, state: state),
                replacingExisting: existing != nil,
                directoryDescriptor: directoryDescriptor
            )
        }
    }

    func pendingExpectation() throws -> DeviceIngressResponseExpectation? {
        try withExclusiveAccess {
            try loadJournalUnlocked(directoryDescriptor: $0)?
                .currentState.pendingExpectation
        }
    }

    func commitVerified(
        expectation: DeviceIngressResponseExpectation,
        canonicalResponseData: Data,
        buildProvenance: BindingBuildProvenance,
        vaultBinding: DeviceIngressPersistedVaultBinding
    ) throws {
        try withExclusiveAccess { directoryDescriptor in
            guard let existing = try loadJournalUnlocked(
                directoryDescriptor: directoryDescriptor
            ) else {
                throw DeviceIngressRegistrationClientError.pendingExpectationMissing
            }
            let old = existing.currentState
            guard let pending = old.pendingExpectation else {
                throw DeviceIngressRegistrationClientError.pendingExpectationMissing
            }
            guard pending == expectation else {
                throw DeviceIngressRegistrationClientError.pendingExpectationMismatch
            }

            let evidence = DeviceIngressVerifiedRegistrationEvidence(
                expectation: expectation,
                canonicalResponseData: canonicalResponseData,
                buildProvenance: buildProvenance,
                vaultBinding: vaultBinding
            )
            let state = DeviceIngressEvidenceStateSnapshot(
                consentState: old.consentState,
                acceptedConsentEvidence: old.acceptedConsentEvidence,
                pendingExpectation: nil,
                verifiedEvidence: evidence
            )
            try persistJournalUnlocked(
                try existing.appending(mutation: .commitVerified, state: state),
                replacingExisting: true,
                directoryDescriptor: directoryDescriptor
            )
        }
    }

    func verifiedEvidence() throws -> DeviceIngressVerifiedRegistrationEvidence? {
        try withExclusiveAccess {
            try loadJournalUnlocked(directoryDescriptor: $0)?
                .currentState.verifiedEvidence
        }
    }

    func containsRegistrationEvidence() throws -> Bool {
        try withExclusiveAccess {
            let state = try loadJournalUnlocked(directoryDescriptor: $0)?
                .currentState ?? .empty
            return state.pendingExpectation != nil || state.verifiedEvidence != nil
        }
    }

    /// Atomically establishes a durable local pre-registration gate only if
    /// there is no pending or verified register evidence. Once this method
    /// returns, a register attempt prepared from stale in-memory consent still
    /// cannot persist its expectation.
    func performPreRegistrationDecline(_ localStateClear: () -> Void) throws {
        try withExclusiveAccess { directoryDescriptor in
            let existing = try loadJournalUnlocked(
                directoryDescriptor: directoryDescriptor
            )
            let old = existing?.currentState ?? .empty
            guard old.pendingExpectation == nil,
                  old.verifiedEvidence == nil else {
                throw DeviceIngressRegistrationClientError
                    .registrationEvidencePreventsPreRegistrationDecline
            }
            let state = DeviceIngressEvidenceStateSnapshot(
                consentState: .declined,
                acceptedConsentEvidence: nil,
                pendingExpectation: nil,
                verifiedEvidence: nil
            )
            try persistJournalUnlocked(
                try (existing ?? DeviceIngressEvidenceJournal(entries: []))
                    .appending(mutation: .declineTerms, state: state),
                replacingExisting: existing != nil,
                directoryDescriptor: directoryDescriptor
            )
            localStateClear()
            try validateActiveTransaction()
        }
    }

    private let journalFileName = "registration-state-journal.json"
    private let testJournalAnchorFileName = "registration-state-journal-anchor.json"
    private let legacyPendingFileName = "pending-register-expectation.json"
    private let legacyVerifiedFileName = "verified-register-evidence.json"
    private let legacyPreRegistrationDeclineFileName = "pre-registration-decline.json"
    private let lockFileName = "registration.lock"

    private func loadJournalUnlocked(
        directoryDescriptor: Int32
    ) throws -> DeviceIngressEvidenceJournal? {
        if let journal = try readUnlocked(
            DeviceIngressEvidenceJournal.self,
            from: journalFileName,
            directoryDescriptor: directoryDescriptor
        ) {
            try journal.validate()
            guard let journalAnchor = journal.currentAnchor,
                  try readJournalAnchorUnlocked(
                    directoryDescriptor: directoryDescriptor
                  ) == journalAnchor else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
            return journal
        }

        // Pre-journal files cannot prove an explicit accepted decision or the
        // v3 vault binding. Validate their metadata without granting a silent
        // migration, then fail closed if any are present.
        let legacyPending = try readUnlocked(
            DeviceIngressResponseExpectation.self,
            from: legacyPendingFileName,
            directoryDescriptor: directoryDescriptor
        )
        let legacyVerified = try readUnlocked(
            DeviceIngressVerifiedRegistrationEvidence.self,
            from: legacyVerifiedFileName,
            directoryDescriptor: directoryDescriptor
        )
        let legacyDecline = try readUnlocked(
            DeviceIngressPreRegistrationDeclineTombstone.self,
            from: legacyPreRegistrationDeclineFileName,
            directoryDescriptor: directoryDescriptor
        )
        guard legacyPending == nil,
              legacyVerified == nil,
              legacyDecline == nil else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
        guard try readJournalAnchorUnlocked(
            directoryDescriptor: directoryDescriptor
        ) == nil else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
        return nil
    }

    private func persistJournalUnlocked(
        _ journal: DeviceIngressEvidenceJournal,
        replacingExisting: Bool,
        directoryDescriptor: Int32
    ) throws {
        try journal.validate()
        guard let newAnchor = journal.currentAnchor else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
        let expectedAnchor = journal.previousAnchor
        guard replacingExisting == (expectedAnchor != nil) else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
        guard try readJournalAnchorUnlocked(
            directoryDescriptor: directoryDescriptor
        ) == expectedAnchor else {
            throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
        }
        try writeUnlocked(
            journal,
            to: journalFileName,
            directoryDescriptor: directoryDescriptor,
            replaceExisting: replacingExisting
        )
        guard let readBack = try readUnlocked(
            DeviceIngressEvidenceJournal.self,
            from: journalFileName,
            directoryDescriptor: directoryDescriptor
        ), readBack == journal else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        try readBack.validate()
        try compareAndSwapJournalAnchorUnlocked(
            expected: expectedAnchor,
            new: newAnchor,
            directoryDescriptor: directoryDescriptor
        )
    }

    private func readJournalAnchorUnlocked(
        directoryDescriptor: Int32
    ) throws -> DeviceIngressEvidenceJournalAnchor? {
        switch journalAnchorStorage {
        case let .keychain(store):
            return try store.load()
        #if DEBUG
        case .testFile:
            let anchor = try readUnlocked(
                DeviceIngressEvidenceJournalAnchor.self,
                from: testJournalAnchorFileName,
                directoryDescriptor: directoryDescriptor
            )
            try anchor?.validate()
            return anchor
        #endif
        }
    }

    private func compareAndSwapJournalAnchorUnlocked(
        expected: DeviceIngressEvidenceJournalAnchor?,
        new: DeviceIngressEvidenceJournalAnchor,
        directoryDescriptor: Int32
    ) throws {
        switch journalAnchorStorage {
        case let .keychain(store):
            try store.compareAndSwap(expected: expected, new: new)
        #if DEBUG
        case .testFile:
            let actual = try readJournalAnchorUnlocked(
                directoryDescriptor: directoryDescriptor
            )
            guard actual == expected else {
                throw DeviceIngressRegistrationClientError.invalidEvidenceJournal
            }
            try new.validateAdvance(after: expected)
            try writeUnlocked(
                new,
                to: testJournalAnchorFileName,
                directoryDescriptor: directoryDescriptor,
                replaceExisting: actual != nil
            )
            guard try readJournalAnchorUnlocked(
                directoryDescriptor: directoryDescriptor
            ) == new else {
                throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
            }
        #endif
        }
    }

    /// NSLock closes the same-process gap in POSIX record-lock semantics;
    /// lockf then serializes cooperating app/extension processes using the
    /// same store.
    private func withExclusiveAccess<T>(_ body: (Int32) throws -> T) throws -> T {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }

        let directoryDescriptor = try pinnedDirectoryDescriptor()
        try validatePinnedDirectoryChain()
        let descriptor = try openFileAt(
            directoryDescriptor,
            name: lockFileName,
            flags: O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW,
            mode: 0o600,
            operation: "lock open"
        )
        defer { _ = Darwin.close(descriptor) }
        let lockMetadata = try metadataForDescriptor(descriptor, operation: "lock stat")
        try validateRegularFile(lockMetadata)
        let lockPathMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: lockFileName
        )
        guard lockMetadata.hasSameIdentity(as: lockPathMetadata) else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }

        while Darwin.lockf(descriptor, F_LOCK, 0) != 0 {
            guard errno == EINTR else {
                throw DeviceIngressEvidenceFileError.posix(
                    operation: "lock acquire",
                    code: errno
                )
            }
        }
        defer { _ = Darwin.lockf(descriptor, F_ULOCK, 0) }
        try readObserver.didAcquireCanonicalLock(fileName: lockFileName)
        let validateCanonicalLock = { [unowned self] in
            try self.validateCanonicalLockBinding(
                descriptor: descriptor,
                expectedMetadata: lockMetadata,
                directoryDescriptor: directoryDescriptor
            )
        }
        try validateCanonicalLock()
        activeTransactionValidator = validateCanonicalLock
        defer { activeTransactionValidator = nil }
        do {
            let result = try body(directoryDescriptor)
            try validateCanonicalLock()
            return result
        } catch let bodyError {
            // If the canonical name was replaced while the body failed for a
            // different reason, the split-lock condition takes precedence.
            try validateCanonicalLock()
            throw bodyError
        }
    }

    private func validateCanonicalLockBinding(
        descriptor: Int32,
        expectedMetadata: DeviceIngressEvidenceMetadataSnapshot,
        directoryDescriptor: Int32
    ) throws {
        try validatePinnedDirectoryChain()
        let descriptorMetadata = try metadataForDescriptor(
            descriptor,
            operation: "locked descriptor stat"
        )
        try validateRegularFile(descriptorMetadata)
        guard descriptorMetadata.size == 0 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "lock-size")
        }
        let canonicalMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: lockFileName
        )
        try validateRegularFile(canonicalMetadata)
        guard canonicalMetadata.size == 0 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "lock-size")
        }
        guard descriptorMetadata == expectedMetadata,
              canonicalMetadata == expectedMetadata else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
    }

    private func validateActiveTransaction() throws {
        guard let activeTransactionValidator else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try activeTransactionValidator()
    }

    private func pinnedDirectoryDescriptor() throws -> Int32 {
        if let descriptor = pinnedDirectories.last?.descriptor {
            try validatePinnedDirectoryChain()
            return descriptor
        }

        var opened: [PinnedDirectory] = []
        do {
            #if os(iOS)
            // iOS permits the app to open its own sandbox container path, but
            // denies opening system-owned ancestors such as `/private` while
            // walking from `/` with directory descriptors. `anchorPath` is
            // already canonicalized from Foundation's app-owned Application
            // Support URL. Pin that existing anchor directly, then keep every
            // app-created descendant descriptor-relative and no-follow.
            let anchorDescriptor = Darwin.open(
                anchorPath,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
            guard anchorDescriptor >= 0 else {
                throw DeviceIngressEvidenceFileError.posix(
                    operation: "sandbox anchor directory open",
                    code: errno
                )
            }
            let anchorMetadata = try metadataForDescriptor(
                anchorDescriptor,
                operation: "anchor directory stat"
            )
            try DeviceIngressEvidenceMetadataPolicy.validateOwnedDirectory(
                anchorMetadata,
                expectedOwner: UInt32(geteuid())
            )
            opened.append(PinnedDirectory(
                descriptor: anchorDescriptor,
                parentIndex: nil,
                nameInParent: nil,
                requiresOwnedMetadata: true,
                requiresPrivateMetadata: false
            ))
            #else
            let rootDescriptor = Darwin.open(
                "/",
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
            guard rootDescriptor >= 0 else {
                throw DeviceIngressEvidenceFileError.posix(
                    operation: "root directory open",
                    code: errno
                )
            }
            opened.append(PinnedDirectory(
                descriptor: rootDescriptor,
                parentIndex: nil,
                nameInParent: nil,
                requiresOwnedMetadata: false,
                requiresPrivateMetadata: false
            ))

            // `standardizedFileURL` rewrites `/private/var` back to the
            // top-level `/var` symlink on macOS, undoing the canonical anchor.
            // The anchor is already absolute and canonical, so split it
            // without another Foundation path normalization pass.
            let anchorComponents = anchorPath.split(
                separator: "/",
                omittingEmptySubsequences: true
            ).map(String.init)
            for component in anchorComponents {
                try appendPinnedDirectory(
                    component,
                    createIfMissing: false,
                    requiresOwnedMetadata: false,
                    requiresPrivateMetadata: false,
                    to: &opened
                )
            }
            guard opened.count > 1 else {
                throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
            }
            let anchorIndex = opened.index(before: opened.endIndex)
            opened[anchorIndex] = PinnedDirectory(
                descriptor: opened[anchorIndex].descriptor,
                parentIndex: opened[anchorIndex].parentIndex,
                nameInParent: opened[anchorIndex].nameInParent,
                requiresOwnedMetadata: true,
                requiresPrivateMetadata: false
            )
            try DeviceIngressEvidenceMetadataPolicy.validateOwnedDirectory(
                try metadataForDescriptor(
                    opened[anchorIndex].descriptor,
                    operation: "anchor directory stat"
                ),
                expectedOwner: UInt32(geteuid())
            )
            #endif

            guard let privateDirectoryIndex = relativeDirectoryComponents.indices.last else {
                throw DeviceIngressEvidenceFileError.metadataRejected(
                    reason: "private-evidence-directory-missing"
                )
            }
            for (index, component) in relativeDirectoryComponents.enumerated() {
                try appendPinnedDirectory(
                    component,
                    createIfMissing: true,
                    requiresOwnedMetadata: true,
                    // Shared app namespaces may be 0755, but the evidence leaf remains 0700.
                    requiresPrivateMetadata: index == privateDirectoryIndex,
                    to: &opened
                )
            }
            pinnedDirectories = opened
            try validatePinnedDirectoryChain()
            return try requirePinnedDirectoryDescriptor()
        } catch {
            pinnedDirectories = []
            for directory in opened.reversed() {
                _ = Darwin.close(directory.descriptor)
            }
            throw error
        }
    }

    private func appendPinnedDirectory(
        _ component: String,
        createIfMissing: Bool,
        requiresOwnedMetadata: Bool,
        requiresPrivateMetadata: Bool,
        to opened: inout [PinnedDirectory]
    ) throws {
        try validatePathComponent(component)
        guard let parent = opened.last else {
            throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
        }
        if try metadataAt(parent.descriptor, name: component) == nil {
            guard createIfMissing else {
                throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
            }
            let result = component.withCString {
                Darwin.mkdirat(parent.descriptor, $0, 0o700)
            }
            guard result == 0 || errno == EEXIST else {
                throw DeviceIngressEvidenceFileError.posix(
                    operation: "directory create",
                    code: errno
                )
            }
            try synchronizer.synchronizeDirectory(parent.descriptor)
        }
        let before = try requiredMetadataAt(parent.descriptor, name: component)
        if requiresPrivateMetadata {
            try DeviceIngressEvidenceMetadataPolicy.validateDirectory(
                before,
                expectedOwner: UInt32(geteuid())
            )
        } else if requiresOwnedMetadata {
            try DeviceIngressEvidenceMetadataPolicy.validateOwnedDirectory(
                before,
                expectedOwner: UInt32(geteuid())
            )
        } else {
            guard before.mode & UInt32(S_IFMT) == UInt32(S_IFDIR) else {
                throw DeviceIngressEvidenceFileError.metadataRejected(
                    reason: "path-not-directory:\(component)"
                )
            }
        }
        let descriptor = try openFileAt(
            parent.descriptor,
            name: component,
            flags: O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
            mode: 0,
            operation: "directory open"
        )
        let after = try metadataForDescriptor(descriptor, operation: "directory stat")
        guard before.hasSameIdentity(as: after) else {
            _ = Darwin.close(descriptor)
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        opened.append(PinnedDirectory(
            descriptor: descriptor,
            parentIndex: opened.index(before: opened.endIndex),
            nameInParent: component,
            requiresOwnedMetadata: requiresOwnedMetadata,
            requiresPrivateMetadata: requiresPrivateMetadata
        ))
    }

    private func validatePinnedDirectoryChain() throws {
        guard pinnedDirectories.isEmpty == false else { return }
        for (index, directory) in pinnedDirectories.enumerated() {
            let descriptorMetadata = try metadataForDescriptor(
                directory.descriptor,
                operation: "pinned directory stat"
            )
            if directory.requiresPrivateMetadata {
                try DeviceIngressEvidenceMetadataPolicy.validateDirectory(
                    descriptorMetadata,
                    expectedOwner: UInt32(geteuid())
                )
            } else if directory.requiresOwnedMetadata {
                try DeviceIngressEvidenceMetadataPolicy.validateOwnedDirectory(
                    descriptorMetadata,
                    expectedOwner: UInt32(geteuid())
                )
            } else {
                guard descriptorMetadata.mode & UInt32(S_IFMT) == UInt32(S_IFDIR) else {
                    throw DeviceIngressEvidenceFileError.metadataRejected(
                        reason: "pinned-path-not-directory"
                    )
                }
            }
            if let parentIndex = directory.parentIndex,
               let name = directory.nameInParent {
                guard parentIndex < index else {
                    throw DeviceIngressEvidenceFileError.pathIdentityChanged
                }
                let pathMetadata = try requiredMetadataAt(
                    pinnedDirectories[parentIndex].descriptor,
                    name: name
                )
                guard descriptorMetadata.hasSameIdentity(as: pathMetadata) else {
                    throw DeviceIngressEvidenceFileError.pathIdentityChanged
                }
            }
        }
    }

    private func requirePinnedDirectoryDescriptor() throws -> Int32 {
        guard let descriptor = pinnedDirectories.last?.descriptor else {
            throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
        }
        return descriptor
    }

    private func writeUnlocked<T: Encodable>(
        _ value: T,
        to fileName: String,
        directoryDescriptor: Int32,
        replaceExisting: Bool
    ) throws {
        try validateActiveTransaction()
        try validatePathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard data.count <= Self.maximumEvidenceBytes else {
            throw DeviceIngressRegistrationClientError.evidenceTooLarge
        }

        let temporaryName = ".\(fileName).\(UUID().uuidString).tmp"
        var descriptor = try openFileAt(
            directoryDescriptor,
            name: temporaryName,
            flags: O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode: 0o600,
            operation: "temporary file open"
        )
        var renamed = false
        defer {
            if descriptor >= 0 {
                _ = Darwin.close(descriptor)
            }
            if renamed == false {
                _ = temporaryName.withCString {
                    Darwin.unlinkat(directoryDescriptor, $0, 0)
                }
            }
        }

        try validateActiveTransaction()
        let createdMetadata = try metadataForDescriptor(
            descriptor,
            operation: "temporary file stat"
        )
        try validateRegularFile(createdMetadata)
        try writeAll(data, to: descriptor)
        try synchronizer.synchronizeFile(descriptor)
        let persistedData = try readAll(
            descriptor: descriptor,
            expectedSize: data.count,
            operation: "temporary file read-back"
        )
        guard persistedData == data else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        let persistedMetadata = try metadataForDescriptor(
            descriptor,
            operation: "persisted temporary file stat"
        )
        try validateRegularFile(persistedMetadata)
        guard persistedMetadata.size == Int64(data.count) else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        let temporaryPathMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: temporaryName
        )
        guard persistedMetadata == temporaryPathMetadata else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try validateActiveTransaction()

        if let existing = try metadataAt(directoryDescriptor, name: fileName) {
            guard replaceExisting else {
                throw DeviceIngressRegistrationClientError.pendingRegistrationExists
            }
            try validateRegularFile(existing)
        }
        let renameResult = temporaryName.withCString { source in
            fileName.withCString { destination in
                if replaceExisting {
                    Darwin.renameat(
                        directoryDescriptor,
                        source,
                        directoryDescriptor,
                        destination
                    )
                } else {
                    Darwin.renameatx_np(
                        directoryDescriptor,
                        source,
                        directoryDescriptor,
                        destination,
                        UInt32(RENAME_EXCL)
                    )
                }
            }
        }
        guard renameResult == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "atomic rename",
                code: errno
            )
        }
        renamed = true
        try validateActiveTransaction()
        let installedMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: fileName
        )
        // APFS updates ctime when the temporary inode is renamed into its
        // canonical name. Bind the installation to the same inode/device and
        // byte length here; the caller immediately reopens and verifies the
        // exact journal bytes after the directory durability barrier.
        guard installedMetadata.hasSameIdentity(as: persistedMetadata),
              installedMetadata.size == persistedMetadata.size else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try synchronizer.synchronizeDirectory(directoryDescriptor)
        let postSyncMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: fileName
        )
        guard postSyncMetadata == installedMetadata else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        try validateActiveTransaction()
        guard Darwin.close(descriptor) == 0 else {
            descriptor = -1
            throw DeviceIngressEvidenceFileError.posix(
                operation: "installed file close",
                code: errno
            )
        }
        descriptor = -1
    }

    private func readUnlocked<T: Decodable>(
        _ type: T.Type,
        from fileName: String,
        directoryDescriptor: Int32
    ) throws -> T? {
        try validateActiveTransaction()
        try validatePathComponent(fileName)
        guard let before = try metadataAt(directoryDescriptor, name: fileName) else {
            return nil
        }
        try validateRegularFile(before)
        let descriptor = try openFileAt(
            directoryDescriptor,
            name: fileName,
            flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW,
            mode: 0,
            operation: "evidence open"
        )
        defer { _ = Darwin.close(descriptor) }
        let opened = try metadataForDescriptor(descriptor, operation: "evidence stat")
        try validateRegularFile(opened)
        guard opened == before else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try validateActiveTransaction()
        try readObserver.didOpenForRead(fileName: fileName)
        let data = try readAll(
            descriptor: descriptor,
            expectedSize: Int(opened.size),
            operation: "evidence read"
        )
        let after = try metadataForDescriptor(descriptor, operation: "post-read stat")
        let pathAfter = try requiredMetadataAt(directoryDescriptor, name: fileName)
        try validateRegularFile(after)
        guard after == opened, pathAfter == opened else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        try validateActiveTransaction()
        return try JSONDecoder().decode(type, from: data)
    }

    private func removeUnlocked(
        _ fileName: String,
        directoryDescriptor: Int32
    ) throws {
        try validateActiveTransaction()
        try validatePathComponent(fileName)
        guard let before = try metadataAt(directoryDescriptor, name: fileName) else {
            return
        }
        try validateRegularFile(before)
        let result = fileName.withCString {
            Darwin.unlinkat(directoryDescriptor, $0, 0)
        }
        guard result == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "evidence unlink",
                code: errno
            )
        }
        try validateActiveTransaction()
        guard try metadataAt(directoryDescriptor, name: fileName) == nil else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try synchronizer.synchronizeDirectory(directoryDescriptor)
        try validateActiveTransaction()
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(
                    descriptor,
                    buffer.baseAddress!.advanced(by: offset),
                    buffer.count - offset
                )
                if count < 0 {
                    if errno == EINTR { continue }
                    throw DeviceIngressEvidenceFileError.posix(
                        operation: "evidence write",
                        code: errno
                    )
                }
                guard count > 0 else {
                    throw DeviceIngressEvidenceFileError.posix(
                        operation: "evidence short write",
                        code: EIO
                    )
                }
                offset += count
            }
        }
    }

    private func readAll(
        descriptor: Int32,
        expectedSize: Int,
        operation: String
    ) throws -> Data {
        var data = Data(count: expectedSize)
        try data.withUnsafeMutableBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.pread(
                    descriptor,
                    buffer.baseAddress!.advanced(by: offset),
                    buffer.count - offset,
                    off_t(offset)
                )
                if count < 0 {
                    if errno == EINTR { continue }
                    throw DeviceIngressEvidenceFileError.posix(
                        operation: operation,
                        code: errno
                    )
                }
                guard count > 0 else {
                    throw DeviceIngressEvidenceFileError.posix(
                        operation: "\(operation) short read",
                        code: EIO
                    )
                }
                offset += count
            }
        }
        return data
    }

    private func metadataAt(_ directoryDescriptor: Int32, name: String) throws
        -> DeviceIngressEvidenceMetadataSnapshot?
    {
        var value = stat()
        let result = name.withCString {
            Darwin.fstatat(directoryDescriptor, $0, &value, AT_SYMLINK_NOFOLLOW)
        }
        if result != 0 {
            if errno == ENOENT { return nil }
            throw DeviceIngressEvidenceFileError.posix(
                operation: "path stat",
                code: errno
            )
        }
        return DeviceIngressEvidenceMetadataSnapshot(value)
    }

    private func requiredMetadataAt(_ directoryDescriptor: Int32, name: String) throws
        -> DeviceIngressEvidenceMetadataSnapshot
    {
        guard let metadata = try metadataAt(directoryDescriptor, name: name) else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        return metadata
    }

    private func metadataForDescriptor(_ descriptor: Int32, operation: String) throws
        -> DeviceIngressEvidenceMetadataSnapshot
    {
        var value = stat()
        guard Darwin.fstat(descriptor, &value) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: operation,
                code: errno
            )
        }
        return DeviceIngressEvidenceMetadataSnapshot(value)
    }

    private func validateRegularFile(
        _ metadata: DeviceIngressEvidenceMetadataSnapshot
    ) throws {
        try DeviceIngressEvidenceMetadataPolicy.validateRegularFile(
            metadata,
            expectedOwner: UInt32(geteuid()),
            maximumSize: Self.maximumEvidenceBytes
        )
    }

    private func validatePathComponent(_ value: String) throws {
        guard value.isEmpty == false,
              value != ".",
              value != "..",
              value.contains("/") == false,
              value.contains("\0") == false else {
            throw DeviceIngressEvidenceFileError.invalidPathComponent
        }
    }

    private func openFileAt(
        _ directoryDescriptor: Int32,
        name: String,
        flags: Int32,
        mode: mode_t,
        operation: String
    ) throws -> Int32 {
        try validatePathComponent(name)
        let descriptor = name.withCString {
            Darwin.openat(directoryDescriptor, $0, flags, mode)
        }
        guard descriptor >= 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: operation,
                code: errno
            )
        }
        return descriptor
    }
}

nonisolated struct DeviceIngressAuthenticatedVaultHandle: Sendable {
    fileprivate let identityVault: any IdentityVaultProtocol

    @MainActor
    static func current() async throws -> Self {
        guard BindingRuntimeBootstrap.authenticatedRuntimeIsReady,
              let identityVault = CellBase.defaultIdentityVault,
              identityVault is IdentityVault else {
            throw DeviceIngressRegistrationClientError.authenticatedIdentityVaultUnavailable
        }
        guard let privateIdentity = await identityVault.identity(
            for: "private",
            makeNewIfNotFound: false
        ),
              let privateBinding = await identityVault.identityDomainBinding(
                for: privateIdentity
              ),
              privateBinding.domain == "private",
              privateBinding.matches(identity: privateIdentity),
              privateBinding.grantsAuthority == false else {
            throw DeviceIngressRegistrationClientError.authenticatedIdentityVaultUnavailable
        }
        return Self(identityVault: identityVault)
    }

    #if DEBUG
    static func testing(_ identityVault: any IdentityVaultProtocol) -> Self {
        Self(identityVault: identityVault)
    }
    #endif
}

nonisolated actor DeviceIngressRegistrationClient {
    private let identityVault: any IdentityVaultProtocol
    private let transport: any DeviceIngressRegistrationTransport
    private let evidenceStore: any DeviceIngressRegistrationEvidenceStoring
    private let trust: DeviceIngressRegistrationTrustConfiguration
    private let buildProvenance: BindingBuildProvenance

    init(
        authenticatedVault: DeviceIngressAuthenticatedVaultHandle,
        transport: any DeviceIngressRegistrationTransport,
        evidenceStore: any DeviceIngressRegistrationEvidenceStoring,
        trust: DeviceIngressRegistrationTrustConfiguration,
        buildProvenance: BindingBuildProvenance
    ) {
        identityVault = authenticatedVault.identityVault
        self.transport = transport
        self.evidenceStore = evidenceStore
        self.trust = trust
        self.buildProvenance = buildProvenance
    }

    func register(
        protectedBody: Data,
        consentEvidence: NotificationTermsConsentEvidence,
        now: Date = Date()
    ) async throws -> DeviceIngressRegistrationReceipt {
        guard protectedBody.isEmpty == false,
              protectedBody.count <= DeviceIngressEnvelope.maximumBodyBytes else {
            throw DeviceIngressRegistrationClientError.invalidProtectedBody
        }
        let requesterContext = try await currentRequesterContext()
        let requester = requesterContext.identity
        let binding = requesterContext.binding
        let subject = requesterContext.descriptor
        let persistedVaultBinding = try DeviceIngressPersistedVaultBinding(
            binding: binding,
            identity: requester,
            descriptor: subject
        )

        let challengeData = try await transport.fetchRegisterChallenge(subject: subject)
        let prepared = try await DeviceIngressRequestFactory.prepare(
            canonicalChallengeData: challengeData,
            protectedBody: protectedBody,
            requester: requester,
            domainBinding: binding,
            expectedAudience: trust.expectedAudience,
            expectedChallengeIssuer: trust.expectedChallengeIssuer,
            now: now
        )
        guard prepared.expectation.operation == .register else {
            throw DeviceIngressRegistrationClientError.responseWasNotRegistration
        }

        // This durable write intentionally precedes the first mutation-capable
        // transport call. An ambiguous send leaves evidence pending and blocks
        // silent retry.
        try evidenceStore.persistPending(
            prepared.expectation,
            consentEvidence: consentEvidence
        )
        let responseData = try await transport.submitRegister(
            canonicalChallengeData: challengeData,
            canonicalRequestData: prepared.canonicalRequestData,
            protectedBody: protectedBody
        )
        let response = try DeviceIngressOperationResponseVerifier.verify(
            canonicalData: responseData,
            expectation: prepared.expectation
        )
        guard response.operation == .register,
              response.result.kind == .registrationReceipt,
              let receipt = response.result.registrationReceipt else {
            throw DeviceIngressRegistrationClientError.responseWasNotRegistration
        }
        guard receipt.state == .activeConsented else {
            throw DeviceIngressRegistrationClientError.registrationWasNotActiveAndConsented
        }
        guard receipt.deviceIdentityUUID == subject.uuid else {
            throw DeviceIngressRegistrationClientError.registrationWasNotActiveAndConsented
        }

        // Marking succeeds only after cryptographic verification and durable
        // local evidence replacement. No HTTP status can reach this branch.
        try evidenceStore.commitVerified(
            expectation: prepared.expectation,
            canonicalResponseData: responseData,
            buildProvenance: buildProvenance,
            vaultBinding: persistedVaultBinding
        )
        return receipt
    }

    func restoreHistoricalRegistrationEvidence() async throws
        -> DeviceIngressHistoricalRegistrationEvidence?
    {
        guard let evidence = try evidenceStore.verifiedEvidence() else {
            return nil
        }
        guard evidence.schema == DeviceIngressVerifiedRegistrationEvidence.currentSchema else {
            throw DeviceIngressRegistrationClientError.pendingExpectationMismatch
        }
        guard evidence.buildProvenance == buildProvenance else {
            throw DeviceIngressRegistrationClientError.buildProvenanceMismatch
        }

        // A valid owner signature is portable evidence, not proof that this
        // installation controls the registered device identity. Rebind it to
        // the currently authenticated persistent vault before accepting it.
        let requesterContext = try await currentRequesterContext()
        guard evidence.vaultBinding.schema
                == DeviceIngressPersistedVaultBinding.currentSchema,
              evidence.vaultBinding.identityDomain
                == DeviceIngressEnvelope.identityDomain,
              evidence.vaultBinding.identityUUID
                == requesterContext.descriptor.uuid,
              evidence.vaultBinding.identityUUID
                == requesterContext.binding.identityUUID,
              evidence.vaultBinding.signingKeyFingerprint
                == requesterContext.binding.signingKeyFingerprint,
              evidence.expectation.subjectIdentityUUID
                == requesterContext.descriptor.uuid,
              evidence.expectation.subjectSigningKeyFingerprint
                == requesterContext.binding.signingKeyFingerprint else {
            throw DeviceIngressRegistrationClientError
                .verifiedEvidenceDeviceIdentityMismatch
        }
        let response = try DeviceIngressOperationResponseVerifier.verify(
            canonicalData: evidence.canonicalResponseData,
            expectation: evidence.expectation
        )
        guard response.operation == .register,
              response.result.kind == .registrationReceipt,
              let receipt = response.result.registrationReceipt else {
            throw DeviceIngressRegistrationClientError.responseWasNotRegistration
        }
        guard receipt.state == .activeConsented,
              receipt.deviceIdentityUUID == requesterContext.descriptor.uuid else {
            throw DeviceIngressRegistrationClientError.registrationWasNotActiveAndConsented
        }
        return DeviceIngressHistoricalRegistrationEvidence(
            receiptAtMutation: receipt,
            admissionID: response.admissionID,
            authorityGeneration: response.authorityGeneration,
            revocationLedgerID: response.revocationLedgerID,
            revocationGeneration: response.revocationGeneration,
            signedResponseIssuedAtMilliseconds: response.issuedAtMilliseconds,
            buildProvenance: evidence.buildProvenance
        )
    }

    private func currentRequesterContext() async throws -> (
        identity: Identity,
        binding: IdentityDomainBinding,
        descriptor: IdentityPublicKeyDescriptor
    ) {
        guard let requester = await identityVault.identity(
            for: DeviceIngressEnvelope.identityDomain,
            makeNewIfNotFound: false
        ) else {
            throw DeviceIngressRegistrationClientError.notificationIdentityUnavailable
        }
        guard let binding = await identityVault.identityDomainBinding(for: requester),
              binding.schema == IdentityDomainBinding.currentSchema,
              binding.bindingKind == IdentityDomainBinding.vaultContextKind,
              binding.domain == DeviceIngressEnvelope.identityDomain,
              binding.matches(identity: requester),
              binding.grantsAuthority == false else {
            throw DeviceIngressRegistrationClientError.notificationDomainBindingUnavailable
        }
        guard let descriptor = DeviceIngressIdentityDescriptor.publicDescriptor(
            for: requester
        ) else {
            throw DeviceIngressRegistrationClientError.notificationIdentityDescriptorUnavailable
        }
        return (requester, binding, descriptor)
    }
}

@MainActor
enum BindingDeviceIngressRegistrationComposition {
    static func register(
        protectedBody: Data,
        consentEvidence: NotificationTermsConsentEvidence,
        buildProvenance: BindingBuildProvenance
    ) async throws -> DeviceIngressRegistrationReceipt {
        let vaultHandle = try await DeviceIngressAuthenticatedVaultHandle.current()
        guard let notificationIdentity = await vaultHandle.identityVault.identity(
            for: DeviceIngressEnvelope.identityDomain,
            makeNewIfNotFound: true
        ),
              let descriptor = DeviceIngressIdentityDescriptor.publicDescriptor(
                  for: notificationIdentity
              ) else {
            throw DeviceIngressRegistrationClientError.notificationIdentityUnavailable
        }
        let identityBoundBody = try identityBoundRegistrationBody(
            protectedBody,
            deviceIdentityUUID: descriptor.uuid,
            consentEvidence: consentEvidence
        )
        let configuration = try BindingDeviceIngressRuntimeConfiguration.current()
        let evidenceStore = try FileDeviceIngressRegistrationEvidenceStore
            .applicationSupport()
        let transport = try URLSessionDeviceIngressRegistrationTransport(
            origin: configuration.origin
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: vaultHandle,
            transport: transport,
            evidenceStore: evidenceStore,
            trust: configuration.trust,
            buildProvenance: buildProvenance
        )
        return try await client.register(
            protectedBody: identityBoundBody,
            consentEvidence: consentEvidence
        )
    }

    nonisolated static func identityBoundRegistrationBody(
        _ data: Data,
        deviceIdentityUUID: String,
        consentEvidence: NotificationTermsConsentEvidence
    ) throws -> Data {
        guard var payload = try? JSONDecoder().decode(
            [String: JSONValue].self,
            from: data
        ),
              case .string("binding.device-registration.body.v3-candidate")?
                = payload["schema"],
              consentEvidence.state == .accepted else {
            throw DeviceIngressRegistrationClientError.invalidProtectedBody
        }
        payload["participantId"] = .string(deviceIdentityUUID)
        payload["deviceId"] = .string(deviceIdentityUUID)
        payload["termsConsentState"] = .string(consentEvidence.state.rawValue)
        payload["termsAcceptanceEvidence"] = .object(
            consentEvidence.registrationObject
        )
        payload["termsVersion"] = .string(consentEvidence.termsVersion)
        payload.removeValue(forKey: "termsAccepted")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }
}
