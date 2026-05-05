import Foundation
import CellBase

nonisolated enum PortableSurfaceContractSupport {
    static func decodeCellConfiguration(from value: ValueType?) -> CellConfiguration? {
        guard let value else { return nil }
        switch value {
        case .cellConfiguration(let configuration):
            return configuration
        case .object(let object):
            guard let data = try? JSONEncoder().encode(object) else { return nil }
            return try? JSONDecoder().decode(CellConfiguration.self, from: data)
        default:
            return nil
        }
    }

    static func extractConfiguration(from value: ValueType) -> CellConfiguration? {
        if let direct = decodeCellConfiguration(from: value) {
            return direct
        }
        guard case let .object(object) = value else { return nil }
        if let configuration = decodeCellConfiguration(from: object["configuration"]) {
            return configuration
        }
        if let configuration = decodeCellConfiguration(from: object["goal"]) {
            return configuration
        }
        if let configuration = decodeCellConfiguration(from: object["skeletonConfiguration"]) {
            return configuration
        }
        return nil
    }
}

nonisolated struct PortableSurfaceCacheMetadata: Codable, Equatable {
    var endpoint: String
    var endpointIdentity: String
    var hasConfiguration: Bool
    var cachedKeypaths: [String]
    var configurationUpdatedAtEpochMs: Double?
    var snapshotUpdatedAtEpochMs: [String: Double]
    var lastUpdatedAtEpochMs: Double
}

actor PortableSurfaceCacheStore {
    static let shared = PortableSurfaceCacheStore()

    private struct Entry: Codable {
        var endpoint: String
        var endpointIdentity: String
        var configuration: CellConfiguration?
        var snapshots: [String: ValueType]
        var configurationUpdatedAtEpochMs: Double?
        var snapshotUpdatedAtEpochMs: [String: Double]
        var lastUpdatedAtEpochMs: Double
    }

    private var entries: [String: Entry] = [:]
    private var didLoad = false

    func storeConfiguration(_ configuration: CellConfiguration, endpoint: String) {
        guard let identity = cacheIdentity(for: endpoint) else { return }
        loadIfNeeded()

        let timestamp = Date().timeIntervalSince1970 * 1000
        var entry = entries[identity] ?? Entry(
            endpoint: endpoint,
            endpointIdentity: identity,
            configuration: nil,
            snapshots: [:],
            configurationUpdatedAtEpochMs: nil,
            snapshotUpdatedAtEpochMs: [:],
            lastUpdatedAtEpochMs: timestamp
        )
        entry.endpoint = endpoint
        entry.configuration = configuration
        entry.configurationUpdatedAtEpochMs = timestamp
        entry.lastUpdatedAtEpochMs = timestamp
        entries[identity] = entry
        persist()
    }

    func storeSnapshot(_ value: ValueType, endpoint: String, keypath: String) {
        guard let identity = cacheIdentity(for: endpoint) else { return }
        let normalizedKeypath = normalizedSnapshotKeypath(keypath)
        guard !normalizedKeypath.isEmpty else { return }
        loadIfNeeded()

        let timestamp = Date().timeIntervalSince1970 * 1000
        var entry = entries[identity] ?? Entry(
            endpoint: endpoint,
            endpointIdentity: identity,
            configuration: nil,
            snapshots: [:],
            configurationUpdatedAtEpochMs: nil,
            snapshotUpdatedAtEpochMs: [:],
            lastUpdatedAtEpochMs: timestamp
        )
        entry.endpoint = endpoint
        entry.snapshots[normalizedKeypath] = value
        entry.snapshotUpdatedAtEpochMs[normalizedKeypath] = timestamp
        entry.lastUpdatedAtEpochMs = timestamp
        entries[identity] = entry
        persist()
    }

    func configuration(for endpoint: String) -> CellConfiguration? {
        guard let entry = entry(for: endpoint) else { return nil }
        return entry.configuration
    }

    func snapshot(for endpoint: String, keypath: String) -> ValueType? {
        guard let entry = entry(for: endpoint) else { return nil }
        return entry.snapshots[normalizedSnapshotKeypath(keypath)]
    }

    func metadata(for endpoint: String) -> PortableSurfaceCacheMetadata? {
        guard let entry = entry(for: endpoint) else { return nil }
        return PortableSurfaceCacheMetadata(
            endpoint: entry.endpoint,
            endpointIdentity: entry.endpointIdentity,
            hasConfiguration: entry.configuration != nil,
            cachedKeypaths: entry.snapshots.keys.sorted(),
            configurationUpdatedAtEpochMs: entry.configurationUpdatedAtEpochMs,
            snapshotUpdatedAtEpochMs: entry.snapshotUpdatedAtEpochMs,
            lastUpdatedAtEpochMs: entry.lastUpdatedAtEpochMs
        )
    }

    func clearAll() {
        loadIfNeeded()
        entries = [:]
        persist()
    }

    private func entry(for endpoint: String) -> Entry? {
        guard let identity = cacheIdentity(for: endpoint) else { return nil }
        loadIfNeeded()
        return entries[identity]
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true

        guard let url = cacheFileURL(),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func persist() {
        guard let url = cacheFileURL() else { return }
        let directoryURL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func cacheFileURL() -> URL? {
        let fileManager = FileManager.default
        let baseURL =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        return baseURL?.appendingPathComponent("Binding/portable-surface-cache.json")
    }

    private func cacheIdentity(for endpoint: String) -> String? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    private func normalizedSnapshotKeypath(_ keypath: String) -> String {
        keypath.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated enum BindingAdmissionChallengeSupport {
    static func decodePayload(from value: ValueType?) -> AdmissionChallengePayload? {
        guard let value else { return nil }
        if case let .object(object) = value {
            return decodePayload(from: object)
        }
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(AdmissionChallengePayload.self, from: data)
    }

    static func decodePayload(from object: Object) -> AdmissionChallengePayload? {
        if let data = try? JSONEncoder().encode(object),
           let payload = try? JSONDecoder().decode(AdmissionChallengePayload.self, from: data) {
            return payload
        }
        return lossyDecodePayload(from: object)
    }

    static func decodePayload(from jsonString: String) -> AdmissionChallengePayload? {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8) else {
            return nil
        }
        if let payload = try? JSONDecoder().decode(AdmissionChallengePayload.self, from: data) {
            return payload
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let object = Object(
            uniqueKeysWithValues: json.map { key, rawValue in
                (key, bridgeJSONValue(rawValue))
            }
        )
        return decodePayload(from: object)
    }

    static func encodeObject<T: Encodable>(_ value: T) -> Object? {
        guard let data = try? JSONEncoder().encode(value),
              let object = try? JSONDecoder().decode(Object.self, from: data) else {
            return nil
        }
        return object
    }

    private static func lossyDecodePayload(from object: Object) -> AdmissionChallengePayload? {
        guard let state = stringValue(from: object["state"]).flatMap(AdmissionChallengePayloadState.init(rawValue:)),
              let connectState = stringValue(from: object["connectState"]).flatMap(ConnectState.init(rawValue:)) else {
            return nil
        }

        let contextObject = objectValue(from: object["context"])
        let identity =
            decode(Identity.self, from: contextObject?["identity"])
            ?? decode(Identity.self, from: objectValue(from: object["agreement"])?["owner"])
            ?? Identity()

        let agreement: Agreement = {
            if let decoded = decode(Agreement.self, from: object["agreement"]) {
                return decoded
            }
            let fallback = Agreement(owner: identity)
            if let agreementObject = objectValue(from: object["agreement"]) {
                if let name = stringValue(from: agreementObject["name"]),
                   !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    fallback.name = name
                }
                if let uuid = stringValue(from: agreementObject["uuid"]),
                   !uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    fallback.uuid = uuid
                }
            }
            return fallback
        }()

        let context = decode(ConnectContext.self, from: object["context"])
            ?? ConnectContext(source: nil, target: nil, identity: identity)

        let issues = listValue(from: object["issues"])?.compactMap(lossyDecodeIssue(from:)) ?? []
        let issueCount = intValue(from: object["issueCount"]) ?? issues.count
        let session =
            decode(AdmissionSession.self, from: object["session"])
            ?? lossyDecodeSession(from: object["session"])
        let sessionId = stringValue(from: object["sessionId"]) ?? session?.id
        let reasonCode = stringValue(from: object["reasonCode"]) ?? issues.first?.reasonCode
        let userMessage = stringValue(from: object["userMessage"]) ?? issues.first?.userMessage
        let requiredAction = stringValue(from: object["requiredAction"]) ?? issues.first?.requiredAction
        let canAutoResolve = boolValue(from: object["canAutoResolve"]) ?? issues.first?.canAutoResolve
        let helperCellConfiguration =
            decode(CellConfiguration.self, from: object["helperCellConfiguration"])
            ?? issues.first?.helperCellConfiguration
        let developerHint = stringValue(from: object["developerHint"]) ?? issues.first?.developerHint

        return AdmissionChallengePayload(
            state: state,
            connectState: connectState,
            agreement: agreement,
            context: context,
            issues: issues,
            issueCount: issueCount,
            sessionId: sessionId,
            session: session,
            reasonCode: reasonCode,
            userMessage: userMessage,
            requiredAction: requiredAction,
            canAutoResolve: canAutoResolve,
            helperCellConfiguration: helperCellConfiguration,
            developerHint: developerHint
        )
    }

    private static func lossyDecodeIssue(from value: ValueType) -> AdmissionChallengeIssueRecord? {
        if let decoded = decode(AdmissionChallengeIssueRecord.self, from: value) {
            return decoded
        }
        guard let object = objectValue(from: value),
              let conditionName = stringValue(from: object["conditionName"]),
              let conditionType = stringValue(from: object["conditionType"]),
              let state = stringValue(from: object["state"]).flatMap(ConditionState.init(rawValue:)),
              let reasonCode = stringValue(from: object["reasonCode"]),
              let userMessage = stringValue(from: object["userMessage"]),
              let requiredAction = stringValue(from: object["requiredAction"]) else {
            return nil
        }

        return AdmissionChallengeIssueRecord(
            conditionName: conditionName,
            conditionType: conditionType,
            state: state,
            reasonCode: reasonCode,
            userMessage: userMessage,
            requiredAction: requiredAction,
            canAutoResolve: boolValue(from: object["canAutoResolve"]) ?? false,
            helperCellConfiguration: decode(CellConfiguration.self, from: object["helperCellConfiguration"]),
            developerHint: stringValue(from: object["developerHint"])
        )
    }

    private static func lossyDecodeSession(from value: ValueType?) -> AdmissionSession? {
        guard let object = objectValue(from: value),
              let label = stringValue(from: object["label"]),
              let requesterUUID = stringValue(from: object["requesterUUID"]),
              let targetCellUUID = stringValue(from: object["targetCellUUID"]),
              let agreementUUID = stringValue(from: object["agreementUUID"]),
              let agreementName = stringValue(from: object["agreementName"]),
              let connectState = stringValue(from: object["connectState"]).flatMap(ConnectState.init(rawValue:)) else {
            return nil
        }

        let createdAt = intValue(from: object["createdAt"]) ?? Int(Date().timeIntervalSince1970)
        let updatedAt = intValue(from: object["updatedAt"])

        return AdmissionSession(
            id: stringValue(from: object["id"]) ?? UUID().uuidString,
            label: label,
            requesterUUID: requesterUUID,
            targetCellUUID: targetCellUUID,
            agreementUUID: agreementUUID,
            agreementName: agreementName,
            connectState: connectState,
            primaryReasonCode: stringValue(from: object["primaryReasonCode"]),
            requiredAction: stringValue(from: object["requiredAction"]),
            issueCount: intValue(from: object["issueCount"]) ?? 0,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func decode<T: Decodable>(_ type: T.Type, from value: ValueType?) -> T? {
        guard let value else { return nil }
        let data: Data?
        switch value {
        case .object(let object):
            data = try? JSONEncoder().encode(object)
        case .cellConfiguration(let configuration):
            data = try? JSONEncoder().encode(configuration)
        default:
            data = try? JSONEncoder().encode(value)
        }
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func objectValue(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    private static func listValue(from value: ValueType?) -> ValueTypeList? {
        guard case let .list(list)? = value else { return nil }
        return list
    }

    private static func stringValue(from value: ValueType?) -> String? {
        guard case let .string(string)? = value else { return nil }
        return string
    }

    private static func intValue(from value: ValueType?) -> Int? {
        switch value {
        case .integer(let intValue)?:
            return intValue
        case .number(let intValue)?:
            return intValue
        default:
            return nil
        }
    }

    private static func boolValue(from value: ValueType?) -> Bool? {
        guard case let .bool(boolValue)? = value else { return nil }
        return boolValue
    }

    private static func bridgeJSONValue(_ rawValue: Any) -> ValueType {
        switch rawValue {
        case let string as String:
            return .string(string)
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .integer(int)
        case let double as Double:
            return .float(double)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }
            return .float(number.doubleValue)
        case let dictionary as [String: Any]:
            return .object(
                Object(uniqueKeysWithValues: dictionary.map { key, nested in
                    (key, bridgeJSONValue(nested))
                })
            )
        case let array as [Any]:
            return .list(array.map(bridgeJSONValue))
        case _ as NSNull:
            return .null
        default:
            return .string(String(describing: rawValue))
        }
    }
}

nonisolated struct BindingAdmissionChallengeSnapshot {
    let state: AdmissionChallengePayloadState
    let connectState: ConnectState
    let sessionId: String?
    let session: AdmissionSession?
    let issueCount: Int
    let reasonCode: String?
    let userMessage: String?
    let requiredAction: String?
    let canAutoResolve: Bool
    let developerHint: String?
    let helperCellConfiguration: CellConfiguration?

    init(payload: AdmissionChallengePayload) {
        state = payload.state
        connectState = payload.connectState
        sessionId = payload.sessionId ?? payload.session?.id
        session = payload.session
        issueCount = payload.issueCount
        reasonCode = payload.reasonCode ?? payload.primaryIssue?.reasonCode
        userMessage = payload.userMessage ?? payload.primaryIssue?.userMessage
        requiredAction = payload.requiredAction ?? payload.primaryIssue?.requiredAction
        canAutoResolve = payload.canAutoResolve ?? payload.primaryIssue?.canAutoResolve ?? false
        developerHint = payload.developerHint ?? payload.primaryIssue?.developerHint
        helperCellConfiguration = payload.helperCellConfiguration ?? payload.primaryIssue?.helperCellConfiguration
    }

    func retryRequest() -> AdmissionRetryRequest? {
        guard let sessionId,
              !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return AdmissionRetryRequest(
            sessionId: sessionId,
            requesterUUID: session?.requesterUUID,
            note: "binding.sameEntityLink.review"
        )
    }

    func asObject() -> Object {
        var object: Object = [
            "statusSummary": .string(statusSummary),
            "state": .string(state.rawValue),
            "connectState": .string(connectState.rawValue),
            "issueCount": .integer(issueCount),
            "issueSummary": .string(issueSummary),
            "requiredActionSummary": .string(requiredActionSummary),
            "userMessage": .string(userMessage ?? "Ingen typed userMessage i challenge payload."),
            "autoResolveSummary": .string(
                canAutoResolve
                    ? "Challenge kan auto-retries nar tilstanden endrer seg."
                    : "Challenge krever eksplisitt review eller remediation."
            ),
            "helperSummary": .string(
                helperCellConfiguration == nil
                    ? "Ingen helper-konfigurasjon fulgte med challenge payload."
                    : "Challenge payload inneholder helper-konfigurasjon for guided remediation."
            ),
            "retrySummary": .string(
                retryRequest() == nil
                    ? "Ingen admission retry-request tilgjengelig."
                    : "Admission retry-request er klar fra delt session-id."
            ),
            "sessionSummary": .string(sessionSummary)
        ]

        if let reasonCode,
           !reasonCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            object["reasonCode"] = .string(reasonCode)
        }
        if let requiredAction,
           !requiredAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            object["requiredAction"] = .string(requiredAction)
        }
        if let developerHint,
           !developerHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            object["developerHint"] = .string(developerHint)
        }
        if let helperCellConfiguration {
            object["helperCellConfiguration"] = .cellConfiguration(helperCellConfiguration)
        }
        if let session {
            object["session"] = .object(session.asObject())
        }
        if let retryRequest = retryRequest(),
           let retryObject = BindingAdmissionChallengeSupport.encodeObject(retryRequest) {
            object["retryRequest"] = .object(retryObject)
        }

        return object
    }

    private var statusSummary: String {
        switch state {
        case .unmet:
            return "Typed admission challenge er lest fra delt contract og venter pa review."
        case .denied:
            return "Typed admission challenge viser at tilgang ble avslatt av target-cellen."
        }
    }

    private var sessionSummary: String {
        if let sessionId,
           !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Session: \(sessionId)"
        }
        return "Ingen admission-session eksponert i challenge payload."
    }

    private var issueSummary: String {
        if issueCount == 1 {
            return "1 challenge-issue registrert."
        }
        return "\(issueCount) challenge-issues registrert."
    }

    private var requiredActionSummary: String {
        if let requiredAction,
           !requiredAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Required action: \(requiredAction)"
        }
        return "Ingen requiredAction oppgitt i challenge payload."
    }
}
