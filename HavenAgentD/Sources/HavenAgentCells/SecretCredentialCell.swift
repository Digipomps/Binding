import Foundation
@preconcurrency import CellBase
import CellApple

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public struct SecretCredentialEncryptionMetadata: Codable, Equatable, Sendable {
    public var scheme: String
    public var keyDerivation: String
    public var saltBase64: String
    public var authenticatedData: String

    public init(
        scheme: String = "ChaChaPoly",
        keyDerivation: String = "HKDF-SHA256; unlock-key must be high entropy and is never stored",
        saltBase64: String,
        authenticatedData: String
    ) {
        self.scheme = scheme
        self.keyDerivation = keyDerivation
        self.saltBase64 = saltBase64
        self.authenticatedData = authenticatedData
    }
}

public struct SecretCredentialMetadataRecord: Codable, Equatable, Sendable {
    public var credentialID: String
    public var providerID: String
    public var credentialLabel: String
    public var secretRef: String
    public var ownerIdentityUUID: String
    public var ownerDisplayName: String
    public var ownerDid: String?
    public var ownerIdentityDomain: String
    public var allowedPurposeRefs: [String]
    public var allowedScaffolds: [String]
    public var allowedDataClasses: [String]
    public var blockedDataClasses: [String]
    public var maxMonthlySpendNOK: Double?
    public var requiresUserApproval: Bool
    public var dpaStatus: String
    public var sourceURLs: [String]
    public var tags: [String]
    public var encryption: SecretCredentialEncryptionMetadata
    public var createdAt: String
    public var updatedAt: String
    public var revokedAt: String?
    public var lastRotatedAt: String?
    public var lastAuthorizedAt: String?
    public var authorizationCount: Int

    public init(
        credentialID: String,
        providerID: String,
        credentialLabel: String,
        secretRef: String,
        ownerIdentityUUID: String,
        ownerDisplayName: String,
        ownerDid: String?,
        ownerIdentityDomain: String,
        allowedPurposeRefs: [String],
        allowedScaffolds: [String],
        allowedDataClasses: [String],
        blockedDataClasses: [String],
        maxMonthlySpendNOK: Double?,
        requiresUserApproval: Bool,
        dpaStatus: String,
        sourceURLs: [String],
        tags: [String],
        encryption: SecretCredentialEncryptionMetadata,
        createdAt: String,
        updatedAt: String,
        revokedAt: String? = nil,
        lastRotatedAt: String? = nil,
        lastAuthorizedAt: String? = nil,
        authorizationCount: Int = 0
    ) {
        self.credentialID = credentialID
        self.providerID = providerID
        self.credentialLabel = credentialLabel
        self.secretRef = secretRef
        self.ownerIdentityUUID = ownerIdentityUUID
        self.ownerDisplayName = ownerDisplayName
        self.ownerDid = ownerDid
        self.ownerIdentityDomain = ownerIdentityDomain
        self.allowedPurposeRefs = allowedPurposeRefs
        self.allowedScaffolds = allowedScaffolds
        self.allowedDataClasses = allowedDataClasses
        self.blockedDataClasses = blockedDataClasses
        self.maxMonthlySpendNOK = maxMonthlySpendNOK
        self.requiresUserApproval = requiresUserApproval
        self.dpaStatus = dpaStatus
        self.sourceURLs = sourceURLs
        self.tags = tags
        self.encryption = encryption
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revokedAt = revokedAt
        self.lastRotatedAt = lastRotatedAt
        self.lastAuthorizedAt = lastAuthorizedAt
        self.authorizationCount = authorizationCount
    }

    public func redactedObject() -> Object {
        [
            "credentialID": .string(credentialID),
            "providerID": .string(providerID),
            "credentialLabel": .string(credentialLabel),
            "secretRef": .string(secretRef),
            "ownerIdentityUUID": .string(ownerIdentityUUID),
            "ownerDisplayName": .string(ownerDisplayName),
            "ownerDid": ownerDid.map(ValueType.string) ?? .null,
            "ownerIdentityDomain": .string(ownerIdentityDomain),
            "allowedPurposeRefs": .list(allowedPurposeRefs.map(ValueType.string)),
            "allowedScaffolds": .list(allowedScaffolds.map(ValueType.string)),
            "allowedDataClasses": .list(allowedDataClasses.map(ValueType.string)),
            "blockedDataClasses": .list(blockedDataClasses.map(ValueType.string)),
            "maxMonthlySpendNOK": maxMonthlySpendNOK.map(ValueType.float) ?? .null,
            "requiresUserApproval": .bool(requiresUserApproval),
            "dpaStatus": .string(dpaStatus),
            "sourceURLs": .list(sourceURLs.map(ValueType.string)),
            "tags": .list(tags.map(ValueType.string)),
            "encryption": .object([
                "scheme": .string(encryption.scheme),
                "keyDerivation": .string(encryption.keyDerivation),
                "saltStoredWithMetadata": .bool(!encryption.saltBase64.isEmpty),
                "authenticatedData": .string(encryption.authenticatedData)
            ]),
            "createdAt": .string(createdAt),
            "updatedAt": .string(updatedAt),
            "revokedAt": revokedAt.map(ValueType.string) ?? .null,
            "lastRotatedAt": lastRotatedAt.map(ValueType.string) ?? .null,
            "lastAuthorizedAt": lastAuthorizedAt.map(ValueType.string) ?? .null,
            "authorizationCount": .integer(authorizationCount),
            "rawSecretAvailableInCellState": .bool(false)
        ]
    }
}

public protocol SecretCredentialMetadataStoring: Sendable {
    func loadCredentials() async throws -> [SecretCredentialMetadataRecord]
    func saveCredentials(_ records: [SecretCredentialMetadataRecord]) async throws
}

public actor FileSecretCredentialMetadataStore: SecretCredentialMetadataStoring {
    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    public func loadCredentials() async throws -> [SecretCredentialMetadataRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([SecretCredentialMetadataRecord].self, from: data)
    }

    public func saveCredentials(_ records: [SecretCredentialMetadataRecord]) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let data = try encoder.encode(records.sorted { $0.credentialID < $1.credentialID })
        try data.write(to: fileURL, options: [.atomic])
    }
}

public actor InMemorySecretCredentialMetadataStore: SecretCredentialMetadataStoring {
    private var records: [SecretCredentialMetadataRecord]

    public init(records: [SecretCredentialMetadataRecord] = []) {
        self.records = records
    }

    public func loadCredentials() async throws -> [SecretCredentialMetadataRecord] {
        records
    }

    public func saveCredentials(_ records: [SecretCredentialMetadataRecord]) async throws {
        self.records = records.sorted { $0.credentialID < $1.credentialID }
    }
}

public actor SecretCredentialRuntimeVault {
    public static let shared = SecretCredentialRuntimeVault()

    public struct Authorization: Equatable, Sendable {
        public var authorizationID: String
        public var credentialID: String
        public var providerID: String
        public var purposeRef: String
        public var expiresAt: Date
    }

    private struct Entry {
        var authorization: Authorization
        var secret: Data
    }

    private var entries: [String: Entry] = [:]

    public init() {}

    public func store(
        secret: Data,
        credentialID: String,
        providerID: String,
        purposeRef: String,
        ttlSeconds: Int
    ) -> Authorization {
        pruneExpired(now: Date())
        let authorizationID = "cred_auth_\(UUID().uuidString.lowercased())"
        let authorization = Authorization(
            authorizationID: authorizationID,
            credentialID: credentialID,
            providerID: providerID,
            purposeRef: purposeRef,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(30, min(ttlSeconds, 900))))
        )
        entries[authorizationID] = Entry(authorization: authorization, secret: secret)
        return authorization
    }

    public func secretData(for authorizationID: String) -> Data? {
        let now = Date()
        pruneExpired(now: now)
        guard let entry = entries[authorizationID], entry.authorization.expiresAt > now else {
            entries[authorizationID] = nil
            return nil
        }
        return entry.secret
    }

    public func revoke(_ authorizationID: String) {
        entries[authorizationID] = nil
    }

    public func removeAuthorizations(for credentialID: String) {
        entries = entries.filter { $0.value.authorization.credentialID != credentialID }
    }

    public func clear() {
        entries.removeAll()
    }

    private func pruneExpired(now: Date) {
        entries = entries.filter { $0.value.authorization.expiresAt > now }
    }
}

private struct SecretCredentialSealedEnvelope: Codable {
    var version: Int
    var scheme: String
    var combinedBase64: String
}

public final class SecretCredentialCell: GeneralCell {
    private enum CodingKeys: String, CodingKey {
        case version
    }

    nonisolated(unsafe) public static var metadataStoreFactory: @Sendable () -> any SecretCredentialMetadataStoring = {
        FileSecretCredentialMetadataStore(
            fileURL: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/HAVENAgent/State/secret-credentials.json")
        )
    }

    nonisolated(unsafe) public static var secureStoreFactory: @Sendable () -> any SecureCredentialStore = {
        AppleKeychainSecureCredentialStore(service: "no.haven.agentd.secret-credentials")
    }

    nonisolated(unsafe) public static var runtimeVaultFactory: @Sendable () -> SecretCredentialRuntimeVault = {
        .shared
    }

    private let metadataStore: any SecretCredentialMetadataStoring
    private let secureStore: any SecureCredentialStore
    private let runtimeVault: SecretCredentialRuntimeVault

    public required init(owner: Identity) async {
        self.metadataStore = Self.metadataStoreFactory()
        self.secureStore = Self.secureStoreFactory()
        self.runtimeVault = Self.runtimeVaultFactory()
        await super.init(owner: owner)
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    public required init(from decoder: Decoder) throws {
        self.metadataStore = Self.metadataStoreFactory()
        self.secureStore = Self.secureStoreFactory()
        self.runtimeVault = Self.runtimeVaultFactory()
        _ = try? decoder.container(keyedBy: CodingKeys.self)
        try super.init(from: decoder)
        let cell = UncheckedSendableReference(value: self)
        Task {
            let requester = Identity()
            let decodedOwner = (try? await cell.value.getOwner(requester: requester)) ?? requester
            await cell.value.setupPermissions(owner: decodedOwner)
            await cell.value.setupKeys(owner: decodedOwner)
        }
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("1", forKey: .version)
    }

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "credentials")
        agreementTemplate.addGrant("r---", for: "contracts")
        agreementTemplate.addGrant("rw--", for: "credential.register")
        agreementTemplate.addGrant("rw--", for: "credential.authorizeUse")
        agreementTemplate.addGrant("rw--", for: "credential.rotate")
        agreementTemplate.addGrant("rw--", for: "credential.revoke")
        agreementTemplate.addGrant("r---", for: "flow")
    }

    private func setupKeys(owner: Identity) async {
        await setupExploreContracts(owner: owner)

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "state", requester: requester) else { return .string("denied") }
            return await self.stateValue()
        })

        await addInterceptForGet(requester: owner, key: "credentials", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "credentials", requester: requester) else { return .string("denied") }
            return await self.credentialsValue()
        })

        await addInterceptForGet(requester: owner, key: "contracts", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "contracts", requester: requester) else { return .string("denied") }
            return self.contractsValue()
        })

        await addInterceptForSet(requester: owner, key: "credential.register", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("rw--", at: "credential.register", requester: requester) else { return .string("denied") }
            return await self.registerCredential(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "credential.authorizeUse", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("rw--", at: "credential.authorizeUse", requester: requester) else { return .string("denied") }
            return await self.authorizeUse(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "credential.rotate", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("rw--", at: "credential.rotate", requester: requester) else { return .string("denied") }
            return await self.rotateCredential(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "credential.revoke", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("rw--", at: "credential.revoke", requester: requester) else { return .string("denied") }
            return await self.revokeCredential(value: value, requester: requester)
        })
    }

    private func setupExploreContracts(owner: Identity) async {
        let recordSchema = ExploreContract.objectSchema(
            properties: [
                "credentialID": ExploreContract.schema(type: "string"),
                "providerID": ExploreContract.schema(type: "string"),
                "credentialLabel": ExploreContract.schema(type: "string"),
                "secretRef": ExploreContract.schema(type: "string"),
                "allowedPurposeRefs": ExploreContract.listSchema(item: ExploreContract.schema(type: "string")),
                "allowedScaffolds": ExploreContract.listSchema(item: ExploreContract.schema(type: "string")),
                "allowedDataClasses": ExploreContract.listSchema(item: ExploreContract.schema(type: "string")),
                "blockedDataClasses": ExploreContract.listSchema(item: ExploreContract.schema(type: "string")),
                "rawSecretAvailableInCellState": ExploreContract.schema(type: "bool")
            ],
            requiredKeys: ["credentialID", "providerID", "credentialLabel", "secretRef"]
        )
        let statusSchema = ExploreContract.objectSchema(
            properties: [
                "status": ExploreContract.schema(type: "string"),
                "credentialID": ExploreContract.schema(type: "string"),
                "providerID": ExploreContract.schema(type: "string"),
                "message": ExploreContract.schema(type: "string")
            ],
            requiredKeys: ["status"]
        )
        let registrationInput = ExploreContract.objectSchema(
            properties: [
                "credentialID": ExploreContract.schema(type: "string"),
                "providerID": ExploreContract.schema(type: "string"),
                "credentialLabel": ExploreContract.schema(type: "string"),
                "secret": ExploreContract.schema(type: "string", description: "Raw API key; accepted only on set and never returned."),
                "unlockKey": ExploreContract.schema(type: "string", description: "High-entropy key used to derive the ChaChaPoly key; never stored."),
                "allowedPurposeRefs": ExploreContract.listSchema(item: ExploreContract.schema(type: "string")),
                "allowedScaffolds": ExploreContract.listSchema(item: ExploreContract.schema(type: "string")),
                "allowedDataClasses": ExploreContract.listSchema(item: ExploreContract.schema(type: "string")),
                "blockedDataClasses": ExploreContract.listSchema(item: ExploreContract.schema(type: "string")),
                "maxMonthlySpendNOK": ExploreContract.schema(type: "float"),
                "requiresUserApproval": ExploreContract.schema(type: "bool"),
                "dpaStatus": ExploreContract.schema(type: "string"),
                "sourceURLs": ExploreContract.listSchema(item: ExploreContract.schema(type: "string"))
            ],
            requiredKeys: ["providerID", "credentialLabel", "secret", "unlockKey"]
        )
        await registerExploreContract(
            requester: owner,
            key: "state",
            method: .get,
            returns: ExploreContract.objectSchema(),
            permissions: ["r---"],
            description: .string("Returns SecretCredentialCell status and storage policy without raw secrets.")
        )
        await registerExploreContract(
            requester: owner,
            key: "credentials",
            method: .get,
            returns: ExploreContract.listSchema(item: recordSchema),
            permissions: ["r---"],
            description: .string("Lists redacted entity-scoped credential metadata.")
        )
        await registerExploreContract(
            requester: owner,
            key: "contracts",
            method: .get,
            returns: ExploreContract.objectSchema(),
            permissions: ["r---"],
            description: .string("Describes credential registration and authorization keypaths.")
        )
        await registerExploreContract(
            requester: owner,
            key: "credential.register",
            method: .set,
            input: registrationInput,
            returns: statusSchema,
            permissions: ["rw--"],
            flowEffects: [ExploreContract.flowEffect(trigger: .set, topic: "agent.credentials", contentType: "object")],
            description: .string("Stores a provider credential as redacted metadata plus an encrypted vault blob.")
        )
        await registerExploreContract(
            requester: owner,
            key: "credential.authorizeUse",
            method: .set,
            input: ExploreContract.objectSchema(
                properties: [
                    "credentialID": ExploreContract.schema(type: "string"),
                    "unlockKey": ExploreContract.schema(type: "string"),
                    "purposeRef": ExploreContract.schema(type: "string"),
                    "requestingScaffold": ExploreContract.schema(type: "string"),
                    "dataClass": ExploreContract.schema(type: "string"),
                    "ttlSeconds": ExploreContract.schema(type: "integer"),
                    "operatorApproved": ExploreContract.schema(type: "bool")
                ],
                requiredKeys: ["credentialID", "unlockKey", "purposeRef"]
            ),
            returns: ExploreContract.objectSchema(
                properties: [
                    "status": ExploreContract.schema(type: "string"),
                    "authorizedUseID": ExploreContract.schema(type: "string"),
                    "expiresAt": ExploreContract.schema(type: "string"),
                    "credentialID": ExploreContract.schema(type: "string"),
                    "providerID": ExploreContract.schema(type: "string")
                ],
                requiredKeys: ["status"]
            ),
            permissions: ["rw--"],
            flowEffects: [ExploreContract.flowEffect(trigger: .set, topic: "agent.credentials", contentType: "object")],
            description: .string("Validates policy and unlock-key, then creates a short-lived in-process authorization without returning the raw secret.")
        )
        await registerExploreContract(
            requester: owner,
            key: "credential.rotate",
            method: .set,
            input: registrationInput,
            returns: statusSchema,
            permissions: ["rw--"],
            flowEffects: [ExploreContract.flowEffect(trigger: .set, topic: "agent.credentials", contentType: "object")],
            description: .string("Replaces the encrypted secret blob for an existing credential.")
        )
        await registerExploreContract(
            requester: owner,
            key: "credential.revoke",
            method: .set,
            input: ExploreContract.objectSchema(
                properties: ["credentialID": ExploreContract.schema(type: "string")],
                requiredKeys: ["credentialID"]
            ),
            returns: statusSchema,
            permissions: ["rw--"],
            flowEffects: [ExploreContract.flowEffect(trigger: .set, topic: "agent.credentials", contentType: "object")],
            description: .string("Revokes metadata, deletes the vault blob, and clears short-lived runtime authorizations.")
        )
    }

    private func hasAccess(_ grant: String, at keypath: String, requester: Identity) async -> Bool {
        if await validateAccess(grant, at: keypath, for: requester) { return true }
        return await LocalControlCellAccess.isPairedOperator(requester)
    }

    private func stateValue() async -> ValueType {
        let records = (try? await metadataStore.loadCredentials()) ?? []
        let active = records.filter { $0.revokedAt == nil }
        return .object([
            "status": .string("ready"),
            "endpoint": .string("cell:///agent/credentials"),
            "credentialCount": .integer(records.count),
            "activeCredentialCount": .integer(active.count),
            "providers": .list(Array(Set(active.map(\.providerID))).sorted().map(ValueType.string)),
            "storage": .object([
                "metadata": .string("SecretCredentialCell metadata store"),
                "secret": .string("SecureCredentialStore/Keychain encrypted blob"),
                "rawSecretInCellState": .bool(false),
                "rawSecretInFlow": .bool(false),
                "unlockKeyStored": .bool(false)
            ]),
            "encryption": .object([
                "scheme": .string("ChaChaPoly"),
                "keyDerivation": .string("HKDF-SHA256 from caller-supplied high-entropy unlock key"),
                "additionalAtRestProtection": .string("Apple Keychain via SecureCredentialStore")
            ]),
            "capabilities": .list([
                .string("credential.register"),
                .string("credential.authorizeUse"),
                .string("credential.rotate"),
                .string("credential.revoke")
            ])
        ])
    }

    private func credentialsValue() async -> ValueType {
        do {
            let records = try await metadataStore.loadCredentials()
            return .list(records.map { .object($0.redactedObject()) })
        } catch {
            return errorValue(status: "metadataUnavailable", message: error.localizedDescription)
        }
    }

    private func contractsValue() -> ValueType {
        .object([
            "state": .string("GET redacted vault status."),
            "credentials": .string("GET redacted credential metadata."),
            "credential.register": .string("SET provider metadata, raw secret, and unlockKey. Stores only encrypted secret blob."),
            "credential.authorizeUse": .string("SET credentialID, unlockKey, purposeRef. Returns short-lived authorizedUseID, never raw secret."),
            "credential.rotate": .string("SET credentialID, new raw secret, unlockKey, and metadata updates."),
            "credential.revoke": .string("SET credentialID to revoke metadata and delete secret blob.")
        ])
    }

    private func registerCredential(value: ValueType, requester: Identity) async -> ValueType {
        do {
            let providerID = try requiredString("providerID", in: value)
            let label = try requiredString("credentialLabel", in: value)
            let secret = try requiredString("secret", in: value)
            let unlockKey = try requiredString("unlockKey", in: value)
            try validateUnlockKey(unlockKey)

            var records = try await metadataStore.loadCredentials()
            let credentialID = Self.canonicalCredentialID(stringValue(valueAt("credentialID", in: value)) ?? "\(providerID)-\(label)")
            guard !records.contains(where: { $0.credentialID == credentialID && $0.revokedAt == nil }) else {
                return errorValue(status: "alreadyExists", message: "Credential '\(credentialID)' already exists. Use credential.rotate to replace it.")
            }

            let now = Self.iso8601String(Date())
            let secretRef = Self.secretRef(for: credentialID)
            let salt = try SecureRandom.data(count: 32)
            let ownerDid = try? requester.did()
            let aad = Self.authenticatedData(ownerIdentityUUID: requester.uuid, credentialID: credentialID)
            let encrypted = try Self.seal(secret: Data(secret.utf8), unlockKey: unlockKey, salt: salt, authenticatedData: aad)
            try await secureStore.store(secret: encrypted, handleID: secretRef)

            let record = SecretCredentialMetadataRecord(
                credentialID: credentialID,
                providerID: providerID,
                credentialLabel: label,
                secretRef: secretRef,
                ownerIdentityUUID: requester.uuid,
                ownerDisplayName: requester.displayName,
                ownerDid: ownerDid,
                ownerIdentityDomain: normalizedString(stringValue(valueAt("ownerIdentityDomain", in: value))) ?? "entity.local",
                allowedPurposeRefs: stringList(valueAt("allowedPurposeRefs", in: value)),
                allowedScaffolds: stringList(valueAt("allowedScaffolds", in: value)),
                allowedDataClasses: stringList(valueAt("allowedDataClasses", in: value)),
                blockedDataClasses: stringList(valueAt("blockedDataClasses", in: value)),
                maxMonthlySpendNOK: doubleValue(valueAt("maxMonthlySpendNOK", in: value)),
                requiresUserApproval: boolValue(valueAt("requiresUserApproval", in: value)) ?? true,
                dpaStatus: normalizedString(stringValue(valueAt("dpaStatus", in: value))) ?? "needs-review",
                sourceURLs: stringList(valueAt("sourceURLs", in: value)),
                tags: stringList(valueAt("tags", in: value)),
                encryption: SecretCredentialEncryptionMetadata(saltBase64: salt.base64EncodedString(), authenticatedData: aad),
                createdAt: now,
                updatedAt: now
            )
            records.removeAll { $0.credentialID == credentialID }
            records.append(record)
            try await metadataStore.saveCredentials(records)
            await emitCredentialEvent(status: "registered", credential: record, purposeRef: nil, requester: requester)
            return .object([
                "status": .string("registered"),
                "credentialID": .string(record.credentialID),
                "providerID": .string(record.providerID),
                "secretRef": .string(record.secretRef),
                "rawSecretReturned": .bool(false)
            ])
        } catch {
            return errorValue(status: "invalidRequest", message: error.localizedDescription)
        }
    }

    private func authorizeUse(value: ValueType, requester: Identity) async -> ValueType {
        do {
            let credentialID = try requiredString("credentialID", in: value)
            let unlockKey = try requiredString("unlockKey", in: value)
            let purposeRef = try requiredString("purposeRef", in: value)
            let requestingScaffold = normalizedString(stringValue(valueAt("requestingScaffold", in: value)))
            let dataClass = normalizedString(stringValue(valueAt("dataClass", in: value))) ?? "unknown"
            let ttlSeconds = intValue(valueAt("ttlSeconds", in: value)) ?? 300

            var records = try await metadataStore.loadCredentials()
            guard let index = records.firstIndex(where: { $0.credentialID == credentialID }) else {
                return errorValue(status: "notFound", message: "No credential metadata found for '\(credentialID)'.")
            }
            var record = records[index]
            guard record.revokedAt == nil else {
                return errorValue(status: "revoked", message: "Credential '\(credentialID)' is revoked.")
            }
            guard record.allowedPurposeRefs.isEmpty || record.allowedPurposeRefs.contains(purposeRef) else {
                return errorValue(status: "purposeDenied", message: "Purpose is not allowed for this credential.")
            }
            if let requestingScaffold, !record.allowedScaffolds.isEmpty, !record.allowedScaffolds.contains(requestingScaffold) {
                return errorValue(status: "scaffoldDenied", message: "Scaffold is not allowed for this credential.")
            }
            if record.blockedDataClasses.contains(dataClass) {
                return errorValue(status: "dataClassDenied", message: "Data class is blocked for this credential.")
            }
            if !record.allowedDataClasses.isEmpty, !record.allowedDataClasses.contains(dataClass) {
                return errorValue(status: "dataClassDenied", message: "Data class is not allowed for this credential.")
            }
            if record.requiresUserApproval, boolValue(valueAt("operatorApproved", in: value)) != true {
                return errorValue(status: "approvalRequired", message: "Credential requires explicit operator approval for this use.")
            }
            guard let encrypted = try await secureStore.loadSecret(handleID: record.secretRef) else {
                return errorValue(status: "secretMissing", message: "Encrypted secret blob is missing from secure store.")
            }
            let plaintext: Data
            do {
                plaintext = try Self.open(encrypted: encrypted, unlockKey: unlockKey, record: record)
            } catch {
                return errorValue(status: "invalidUnlockKey", message: "Credential could not be opened with the supplied unlock key.")
            }
            let authorization = await runtimeVault.store(
                secret: plaintext,
                credentialID: record.credentialID,
                providerID: record.providerID,
                purposeRef: purposeRef,
                ttlSeconds: ttlSeconds
            )
            record.lastAuthorizedAt = Self.iso8601String(Date())
            record.updatedAt = record.lastAuthorizedAt ?? record.updatedAt
            record.authorizationCount += 1
            records[index] = record
            try await metadataStore.saveCredentials(records)
            await emitCredentialEvent(status: "authorized", credential: record, purposeRef: purposeRef, requester: requester)
            return .object([
                "status": .string("authorized"),
                "authorizedUseID": .string(authorization.authorizationID),
                "credentialID": .string(record.credentialID),
                "providerID": .string(record.providerID),
                "purposeRef": .string(purposeRef),
                "expiresAt": .string(Self.iso8601String(authorization.expiresAt)),
                "rawSecretReturned": .bool(false)
            ])
        } catch {
            return errorValue(status: "invalidRequest", message: error.localizedDescription)
        }
    }

    private func rotateCredential(value: ValueType, requester: Identity) async -> ValueType {
        do {
            let credentialID = try requiredString("credentialID", in: value)
            let newSecret = try requiredString("secret", in: value)
            let unlockKey = try requiredString("unlockKey", in: value)
            try validateUnlockKey(unlockKey)
            var records = try await metadataStore.loadCredentials()
            guard let index = records.firstIndex(where: { $0.credentialID == credentialID }) else {
                return errorValue(status: "notFound", message: "No credential metadata found for '\(credentialID)'.")
            }
            var record = records[index]
            guard record.revokedAt == nil else {
                return errorValue(status: "revoked", message: "Credential '\(credentialID)' is revoked.")
            }
            let salt = try SecureRandom.data(count: 32)
            let aad = Self.authenticatedData(ownerIdentityUUID: record.ownerIdentityUUID, credentialID: credentialID)
            let encrypted = try Self.seal(secret: Data(newSecret.utf8), unlockKey: unlockKey, salt: salt, authenticatedData: aad)
            try await secureStore.store(secret: encrypted, handleID: record.secretRef)
            let now = Self.iso8601String(Date())
            record.lastRotatedAt = now
            record.updatedAt = now
            record.encryption = SecretCredentialEncryptionMetadata(saltBase64: salt.base64EncodedString(), authenticatedData: aad)
            if let label = normalizedString(stringValue(valueAt("credentialLabel", in: value))) { record.credentialLabel = label }
            records[index] = record
            try await metadataStore.saveCredentials(records)
            await runtimeVault.removeAuthorizations(for: credentialID)
            await emitCredentialEvent(status: "rotated", credential: record, purposeRef: nil, requester: requester)
            return .object([
                "status": .string("rotated"),
                "credentialID": .string(record.credentialID),
                "providerID": .string(record.providerID),
                "rawSecretReturned": .bool(false)
            ])
        } catch {
            return errorValue(status: "invalidRequest", message: error.localizedDescription)
        }
    }

    private func revokeCredential(value: ValueType, requester: Identity) async -> ValueType {
        do {
            let credentialID = try requiredString("credentialID", in: value)
            var records = try await metadataStore.loadCredentials()
            guard let index = records.firstIndex(where: { $0.credentialID == credentialID }) else {
                return errorValue(status: "notFound", message: "No credential metadata found for '\(credentialID)'.")
            }
            var record = records[index]
            let now = Self.iso8601String(Date())
            record.revokedAt = record.revokedAt ?? now
            record.updatedAt = now
            records[index] = record
            try await secureStore.deleteSecret(handleID: record.secretRef)
            try await metadataStore.saveCredentials(records)
            await runtimeVault.removeAuthorizations(for: credentialID)
            await emitCredentialEvent(status: "revoked", credential: record, purposeRef: nil, requester: requester)
            return .object([
                "status": .string("revoked"),
                "credentialID": .string(record.credentialID),
                "providerID": .string(record.providerID),
                "rawSecretReturned": .bool(false)
            ])
        } catch {
            return errorValue(status: "invalidRequest", message: error.localizedDescription)
        }
    }

    private func emitCredentialEvent(
        status: String,
        credential: SecretCredentialMetadataRecord,
        purposeRef: String?,
        requester: Identity
    ) async {
        var payload: Object = [
            "status": .string(status),
            "credentialID": .string(credential.credentialID),
            "providerID": .string(credential.providerID),
            "purposeRef": purposeRef.map(ValueType.string) ?? .null,
            "rawSecretIncluded": .bool(false),
            "recordedAt": .string(Self.iso8601String(Date()))
        ]
        payload["secretRef"] = .string(credential.secretRef)
        var flowElement = FlowElement(
            title: "agent.credentials.\(status)",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "agent.credentials"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func errorValue(status: String, message: String) -> ValueType {
        .object([
            "status": .string(status),
            "message": .string(message),
            "rawSecretReturned": .bool(false)
        ])
    }

    private func requiredString(_ key: String, in value: ValueType) throws -> String {
        guard let raw = normalizedString(stringValue(valueAt(key, in: value))) else {
            throw SecretCredentialCellError.missingRequiredField(key)
        }
        return raw
    }

    private func validateUnlockKey(_ unlockKey: String) throws {
        guard unlockKey.utf8.count >= 24 else {
            throw SecretCredentialCellError.weakUnlockKey
        }
    }

    private static func seal(
        secret: Data,
        unlockKey: String,
        salt: Data,
        authenticatedData: String
    ) throws -> Data {
        let key = derivedKey(unlockKey: unlockKey, salt: salt, authenticatedData: authenticatedData)
        let sealed = try ChaChaPoly.seal(secret, using: key, authenticating: Data(authenticatedData.utf8))
        let envelope = SecretCredentialSealedEnvelope(
            version: 1,
            scheme: "ChaChaPoly.HKDF-SHA256",
            combinedBase64: sealed.combined.base64EncodedString()
        )
        return try JSONEncoder().encode(envelope)
    }

    private static func open(
        encrypted: Data,
        unlockKey: String,
        record: SecretCredentialMetadataRecord
    ) throws -> Data {
        let envelope = try JSONDecoder().decode(SecretCredentialSealedEnvelope.self, from: encrypted)
        let salt = try Data(base64EncodedRequired: record.encryption.saltBase64)
        let combined = try Data(base64EncodedRequired: envelope.combinedBase64)
        let key = derivedKey(unlockKey: unlockKey, salt: salt, authenticatedData: record.encryption.authenticatedData)
        let box = try ChaChaPoly.SealedBox(combined: combined)
        return try ChaChaPoly.open(box, using: key, authenticating: Data(record.encryption.authenticatedData.utf8))
    }

    private static func derivedKey(unlockKey: String, salt: Data, authenticatedData: String) -> SymmetricKey {
        let material = SymmetricKey(data: Data(unlockKey.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: material,
            salt: salt,
            info: Data(authenticatedData.utf8),
            outputByteCount: 32
        )
    }

    private static func authenticatedData(ownerIdentityUUID: String, credentialID: String) -> String {
        "haven.agentd.secretcredential.v1|owner=\(ownerIdentityUUID)|credential=\(credentialID)"
    }

    private static func secretRef(for credentialID: String) -> String {
        "haven.agentd.secretcredential.v1.\(credentialID)"
    }

    private static func canonicalCredentialID(_ value: String) -> String {
        let lowered = value.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" || scalar == "." {
                return Character(scalar)
            }
            return "-"
        }
        let normalized = String(scalars).split(separator: "-").joined(separator: "-")
        return normalized.isEmpty ? "credential-\(UUID().uuidString.lowercased())" : normalized
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

public enum SecretCredentialCellError: Error, LocalizedError, Sendable {
    case missingRequiredField(String)
    case weakUnlockKey
    case invalidBase64

    public var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required credential field '\(field)'."
        case .weakUnlockKey:
            return "unlockKey must be at least 24 UTF-8 bytes; use a generated high-entropy key."
        case .invalidBase64:
            return "Stored encrypted credential payload is not valid base64."
        }
    }
}

private func valueAt(_ key: String, in value: ValueType) -> ValueType? {
    guard case let .object(object) = value else { return nil }
    return object[key]
}

private func stringValue(_ value: ValueType?) -> String? {
    guard let value else { return nil }
    if case let .string(raw) = value { return raw }
    return nil
}

private func normalizedString(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func stringList(_ value: ValueType?) -> [String] {
    guard let value else { return [] }
    switch value {
    case .list(let list):
        return list.compactMap { normalizedString(stringValue($0)) }
    case .string(let string):
        return normalizedString(string).map { [$0] } ?? []
    default:
        return []
    }
}

private func boolValue(_ value: ValueType?) -> Bool? {
    guard let value else { return nil }
    if case let .bool(raw) = value { return raw }
    if case let .string(raw) = value { return Bool(raw) }
    return nil
}

private func intValue(_ value: ValueType?) -> Int? {
    guard let value else { return nil }
    switch value {
    case .integer(let raw), .number(let raw):
        return raw
    case .float(let raw):
        return Int(raw)
    case .string(let raw):
        return Int(raw)
    default:
        return nil
    }
}

private func doubleValue(_ value: ValueType?) -> Double? {
    guard let value else { return nil }
    switch value {
    case .float(let raw):
        return raw
    case .integer(let raw), .number(let raw):
        return Double(raw)
    case .string(let raw):
        return Double(raw)
    default:
        return nil
    }
}

private extension Data {
    init(base64EncodedRequired string: String) throws {
        guard let data = Data(base64Encoded: string) else {
            throw SecretCredentialCellError.invalidBase64
        }
        self = data
    }
}
