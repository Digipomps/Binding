import Foundation
import CellBase
import CellApple
#if canImport(AppKit)
import AppKit
#endif

nonisolated struct BindingRuntimeSurfaceLaunchRequest: Equatable {
    static let schema = "haven.surface-launch.v1"
    let surfaceID: String
}

nonisolated enum BindingRuntimeSurfaceLaunchParseResult: Equatable {
    case notLaunchRoute
    case accepted(BindingRuntimeSurfaceLaunchRequest)
    case rejected(String)
}

nonisolated enum BindingRuntimeSurfaceLaunchPayloadResult: Equatable {
    case notLaunchPayload
    case accepted(BindingRuntimeSurfaceLaunchRequest)
    case rejected(String)
}

nonisolated enum BindingRuntimeSurfaceLaunchSupport {
    static let registrySchema = "haven.scaffold.surface-launch-registry.v1"
    static let registryCellName = "ScaffoldLaunchRegistry"
    static let publishedRoutesKeypath = "publishedRoutes"
    static let adapterCellName = "BindingRuntimeSurfaceLaunchAdapter"
    static let adapterEndpoint = "cell:///BindingRuntimeSurfaceLaunchAdapter"
    static let adapterKeypath = "open"
    private static let targetSceneIDKey = "bindingTargetSceneID"

    static let buttonResolutionTransform = SkeletonButtonResolutionTransform { template, resolved in
        guard template.keypath == adapterKeypath,
              template.url == adapterEndpoint,
              classifyPayload(template.payload) != .notLaunchPayload else {
            return resolved
        }
        var preserved = template
        preserved.label = resolved.label
        return preserved
    }

    static func parse(_ url: URL) -> BindingRuntimeSurfaceLaunchParseResult {
        guard url.absoluteString.utf8.count <= 2_048 else {
            return .rejected("url_too_large")
        }
        guard url.scheme?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "haven" else {
            return .notLaunchRoute
        }
        let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pathComponents = url.path
            .split(separator: "/")
            .map { String($0).lowercased() }
        let isCanonicalHostRoute = host == "open" && pathComponents.isEmpty
        let isCanonicalPathRoute = host == nil && pathComponents == ["open"]
        guard isCanonicalHostRoute || isCanonicalPathRoute else {
            return .notLaunchRoute
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .rejected("invalid_url")
        }

        let allowedKeys = Set(["schema", "surfaceid", "intent"])
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard allowedKeys.contains(key), values[key] == nil,
                  let rawValue = item.value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  rawValue.isEmpty == false else {
                return .rejected("invalid_or_duplicate_parameter")
            }
            values[key] = rawValue
        }

        guard values["schema"] == BindingRuntimeSurfaceLaunchRequest.schema else {
            return .rejected("unsupported_schema")
        }
        guard values["intent"] == "view" else {
            return .rejected("unsupported_intent")
        }
        guard let surfaceID = normalizedSurfaceID(values["surfaceid"]) else {
            return .rejected("invalid_surface_id")
        }
        return .accepted(BindingRuntimeSurfaceLaunchRequest(surfaceID: surfaceID))
    }

    static func classifyPayload(_ payload: ValueType?) -> BindingRuntimeSurfaceLaunchPayloadResult {
        guard case let .object(root)? = payload,
              root["surfaceLaunch"] != nil else {
            return .notLaunchPayload
        }
        var allowedRootKeys = Set(["surfaceLaunch"])
        if root[targetSceneIDKey] != nil {
            allowedRootKeys.insert(targetSceneIDKey)
        }
        guard Set(root.keys) == allowedRootKeys,
              case let .object(launch)? = root["surfaceLaunch"],
              Set(launch.keys) == ["schema", "surfaceID", "intent"],
              string(launch["schema"]) == BindingRuntimeSurfaceLaunchRequest.schema,
              string(launch["intent"]) == "view",
              let surfaceID = normalizedSurfaceID(string(launch["surfaceID"])) else {
            return .rejected("invalid_surface_launch_payload")
        }
        if root[targetSceneIDKey] != nil,
           targetSceneID(from: payload) == nil {
            return .rejected("invalid_surface_launch_payload")
        }
        return .accepted(BindingRuntimeSurfaceLaunchRequest(surfaceID: surfaceID))
    }

    static func adaptSkeletonButton(
        _ button: SkeletonButton,
        targetSceneID: UUID? = nil
    ) -> SkeletonButton {
        guard button.keypath.trimmingCharacters(in: .whitespacesAndNewlines) == "addConfiguration",
              classifyPayload(button.payload) != .notLaunchPayload else {
            return button
        }
        var adapted = button
        adapted.keypath = adapterKeypath
        adapted.url = adapterEndpoint
        if let targetSceneID,
           case var .object(root)? = adapted.payload {
            root[targetSceneIDKey] = .string(targetSceneID.uuidString)
            adapted.payload = .object(root)
        }
        return adapted
    }

    static func targetSceneID(from payload: ValueType?) -> UUID? {
        guard case let .object(root)? = payload,
              let value = string(root[targetSceneIDKey]) else {
            return nil
        }
        return UUID(uuidString: value)
    }

    static func orderedCatalogEndpoints(_ endpoints: [String]) -> [String] {
        RemoteCatalogSupport.orderedCatalogCandidateEndpoints(
            from: endpoints,
            preference: .preferRemote
        )
    }

    static func configuredRemoteCatalogEndpoints(
        environment: [String: String],
        defaultEndpoint: String
    ) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n")
        var endpoints = (environment["BINDING_REMOTE_CATALOG_ENDPOINTS"] ?? "")
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        let includeDefault = !["0", "false", "no", "off"].contains(
            (environment["BINDING_INCLUDE_DEFAULT_REMOTE_CATALOG"] ?? "true")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        )
        let configuredDefault = environment["BINDING_DEFAULT_REMOTE_CATALOG_ENDPOINT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if includeDefault {
            let endpoint = configuredDefault.flatMap { $0.isEmpty ? nil : $0 } ?? defaultEndpoint
            endpoints.append(endpoint)
        }

        var seen: Set<String> = []
        return endpoints.filter { endpoint in
            seen.insert(endpoint.lowercased()).inserted
        }
    }

    static func resolveLaunchPayload(
        surfaceID: String,
        routesValue: ValueType,
        registryEndpoint: String
    ) -> ValueType? {
        guard let surfaceID = normalizedSurfaceID(surfaceID),
              case let .list(routes) = routesValue else {
            return nil
        }
        for value in routes {
            guard case let .object(route) = value,
                  string(route["schema"]) == registrySchema,
                  normalizedSurfaceID(string(route["surfaceID"])) == surfaceID,
                  bool(route["enabled"]) == true,
                  bool(route["published"]) == true,
                  case let .object(lookup)? = route["configurationLookup"],
                  lookupHasStableIdentity(lookup) else {
                continue
            }
            var normalizedLookup = lookup
            if let endpoint = string(lookup["sourceCellEndpoint"]) ?? string(lookup["endpoint"]) {
                normalizedLookup["sourceCellEndpoint"] = .string(
                    CellConfigurationEndpointRetargeting.rewriteLocalCellEndpoint(
                        endpoint,
                        toScaffoldEndpoint: registryEndpoint
                    )
                )
                normalizedLookup["endpoint"] = nil
            }
            return .object(["configurationLookup": .object(normalizedLookup)])
        }
        return nil
    }

    static func registryEndpoint(forCatalogEndpoint catalogEndpoint: String) -> String? {
        let trimmed = catalogEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["cell", "ws", "wss"].contains(scheme) else {
            return nil
        }
        if scheme == "cell", components.host == nil {
            return "cell:///\(registryCellName)"
        }
        guard let host = components.host, host.isEmpty == false else { return nil }
        components.scheme = "cell"
        components.host = host
        components.path = "/\(registryCellName)"
        components.query = nil
        components.fragment = nil
        return components.string
    }

    struct CatalogDiscoveryCandidate {
        let catalogEndpoint: String
        let registryEndpoint: String
        let lookupPayload: ValueType
    }

    struct CatalogDiscoveryResult {
        let candidates: [CatalogDiscoveryCandidate]
        let failedSourceCount: Int
    }

    @MainActor
    static func discoverCatalogCandidates(
        surfaceID: String,
        catalogEndpoints: [String],
        isActive: () -> Bool = { true },
        readRoutes: (_ catalogEndpoint: String, _ registryEndpoint: String) async throws -> ValueType
    ) async -> CatalogDiscoveryResult {
        var candidates: [CatalogDiscoveryCandidate] = []
        var failedSourceCount = 0

        for catalogEndpoint in catalogEndpoints {
            guard isActive() else { break }
            guard let registryEndpoint = registryEndpoint(forCatalogEndpoint: catalogEndpoint) else {
                failedSourceCount += 1
                continue
            }

            let routesValue: ValueType
            do {
                routesValue = try await readRoutes(catalogEndpoint, registryEndpoint)
            } catch {
                failedSourceCount += 1
                continue
            }
            guard isActive() else { break }
            guard let lookupPayload = resolveLaunchPayload(
                surfaceID: surfaceID,
                routesValue: routesValue,
                registryEndpoint: registryEndpoint
            ) else {
                continue
            }

            candidates.append(CatalogDiscoveryCandidate(
                catalogEndpoint: catalogEndpoint,
                registryEndpoint: registryEndpoint,
                lookupPayload: lookupPayload
            ))
        }

        return CatalogDiscoveryResult(
            candidates: candidates,
            failedSourceCount: failedSourceCount
        )
    }

    private static func normalizedSurfaceID(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.count >= 1, normalized.count <= 128,
              let first = normalized.unicodeScalars.first,
              CharacterSet.alphanumerics.contains(first),
              normalized.unicodeScalars.allSatisfy({
                  CharacterSet.alphanumerics.contains($0) || ".-_".unicodeScalars.contains($0)
              }) else {
            return nil
        }
        return normalized
    }

    private static func lookupHasStableIdentity(_ lookup: Object) -> Bool {
        normalizedToken(string(lookup["uuid"])) != nil
            || normalizedToken(string(lookup["name"])) != nil
    }

    private static func normalizedToken(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func string(_ value: ValueType?) -> String? {
        guard case let .string(string)? = value else { return nil }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bool(_ value: ValueType?) -> Bool? {
        guard case let .bool(value)? = value else { return nil }
        return value
    }
}

nonisolated struct BindingRuntimeSurfaceLaunchBridgeEvent {
    let request: BindingRuntimeSurfaceLaunchRequest?
    let rejectionReason: String?
    let requester: Identity
    let targetWindowNumber: Int?
    let targetSceneID: UUID?
}

nonisolated enum BindingRuntimeSurfaceLaunchBridge {
    static let notificationName = Notification.Name("BindingRuntimeSurfaceLaunchBridge.received")
    private static let eventKey = "event"

    static func post(
        _ event: BindingRuntimeSurfaceLaunchBridgeEvent,
        notificationCenter: NotificationCenter = .default
    ) {
        notificationCenter.post(
            name: notificationName,
            object: nil,
            userInfo: [eventKey: event]
        )
    }

    static func event(from notification: Notification) -> BindingRuntimeSurfaceLaunchBridgeEvent? {
        notification.userInfo?[eventKey] as? BindingRuntimeSurfaceLaunchBridgeEvent
    }

    @MainActor
    static func currentTargetWindowNumber() -> Int? {
#if canImport(AppKit)
        NSApp.keyWindow?.windowNumber
            ?? NSApp.mainWindow?.windowNumber
            ?? NSApp.orderedWindows.first(where: \.isVisible)?.windowNumber
#else
        nil
#endif
    }
}

final class BindingRuntimeSurfaceLaunchAdapterCell: BindingRuntimeBindingCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        await installRuntimeBindings(owner: owner)
        await markRuntimeBindingsInstalled()
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func installRuntimeBindings(owner: Identity) async {
        ensureAgreementGrant("rw--", for: BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        await registerSet(
            key: BindingRuntimeSurfaceLaunchSupport.adapterKeypath,
            owner: owner,
            input: .object([:]),
            returns: .object([:])
        ) { [weak self] requester, payload in
            guard let self,
                  await self.validateAccess(
                    "rw--",
                    at: BindingRuntimeSurfaceLaunchSupport.adapterKeypath,
                    for: requester
                  ) else {
                return nil
            }

            switch BindingRuntimeSurfaceLaunchSupport.classifyPayload(payload) {
            case .accepted(let request):
                let targetSceneID = BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: payload)
                await MainActor.run {
                    BindingRuntimeSurfaceLaunchBridge.post(
                        BindingRuntimeSurfaceLaunchBridgeEvent(
                            request: request,
                            rejectionReason: nil,
                            requester: requester,
                            targetWindowNumber: BindingRuntimeSurfaceLaunchBridge.currentTargetWindowNumber(),
                            targetSceneID: targetSceneID
                        )
                    )
                }
                return .object(["status": .string("accepted")])
            case .rejected(let reason):
                let targetSceneID = BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: payload)
                await MainActor.run {
                    BindingRuntimeSurfaceLaunchBridge.post(
                        BindingRuntimeSurfaceLaunchBridgeEvent(
                            request: nil,
                            rejectionReason: reason,
                            requester: requester,
                            targetWindowNumber: BindingRuntimeSurfaceLaunchBridge.currentTargetWindowNumber(),
                            targetSceneID: targetSceneID
                        )
                    )
                }
                return nil
            case .notLaunchPayload:
                let targetSceneID = BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: payload)
                await MainActor.run {
                    BindingRuntimeSurfaceLaunchBridge.post(
                        BindingRuntimeSurfaceLaunchBridgeEvent(
                            request: nil,
                            rejectionReason: "missing_surface_launch_payload",
                            requester: requester,
                            targetWindowNumber: BindingRuntimeSurfaceLaunchBridge.currentTargetWindowNumber(),
                            targetSceneID: targetSceneID
                        )
                    )
                }
                return nil
            }
        }
    }
}

nonisolated enum PortableSurfaceContractSupport {
    enum RecoveryDecision {
        case live(CellConfiguration)
        case rejectCache
        case allowCache
    }

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

    static func firstConfiguration(
        in values: [String: ValueType],
        orderedKeypaths: [String]
    ) -> CellConfiguration? {
        for keypath in orderedKeypaths {
            guard let value = values[keypath],
                  let configuration = extractConfiguration(from: value) else {
                continue
            }
            return configuration
        }
        return nil
    }

    static func recoveryDecision(
        values: [String: ValueType],
        orderedKeypaths: [String],
        authorizationDenied: Bool
    ) -> RecoveryDecision {
        if let configuration = firstConfiguration(
            in: values,
            orderedKeypaths: orderedKeypaths
        ) {
            return .live(configuration)
        }
        return authorizationDenied ? .rejectCache : .allowCache
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
    nonisolated static let envelopeSchema = "haven.binding.portable-surface-cache.v2"
    nonisolated static let maximumRetainedEntries = 64
    nonisolated static let maximumSnapshotsPerEntry = 16

    private struct Entry: Codable {
        var endpoint: String
        var endpointIdentity: String
        var configuration: CellConfiguration?
        var snapshots: [String: ValueType]
        var configurationUpdatedAtEpochMs: Double?
        var snapshotUpdatedAtEpochMs: [String: Double]
        var lastUpdatedAtEpochMs: Double
    }

    private struct Envelope: Codable {
        var schema: String
        var entries: [String: Entry]
    }

    private var entries: [String: Entry] = [:]
    private var didLoad = false
    private let fileURLOverride: URL?
    private let legacyFileURLOverride: URL?

    /// Production deliberately remains memory-only until CellProtocol exposes
    /// a verified Storage-authority receipt that can be bound to requester,
    /// endpoint, Contract and expiry. An explicit file URL is a test-only
    /// persistence seam for round-trip coverage.
    init(fileURL: URL? = nil, legacyFileURL: URL? = nil) {
        self.fileURLOverride = fileURL
        self.legacyFileURLOverride = legacyFileURL
    }

    func storeConfiguration(_ configuration: CellConfiguration, endpoint: String, requester: Identity) {
        guard let identity = cacheIdentity(for: endpoint, requester: requester),
              let endpointIdentity = endpointIdentity(for: endpoint) else { return }
        loadIfNeeded()

        let timestamp = Date().timeIntervalSince1970 * 1000
        var entry = entries[identity] ?? Entry(
            endpoint: endpoint,
            endpointIdentity: endpointIdentity,
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
        prune()
        persist()
    }

    func storeSnapshot(_ value: ValueType, endpoint: String, keypath: String, requester: Identity) {
        guard let identity = cacheIdentity(for: endpoint, requester: requester),
              let endpointIdentity = endpointIdentity(for: endpoint) else { return }
        let normalizedKeypath = normalizedSnapshotKeypath(keypath)
        guard !normalizedKeypath.isEmpty else { return }
        loadIfNeeded()

        let timestamp = Date().timeIntervalSince1970 * 1000
        var entry = entries[identity] ?? Entry(
            endpoint: endpoint,
            endpointIdentity: endpointIdentity,
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
        prune()
        persist()
    }

    func configuration(for endpoint: String, requester: Identity) -> CellConfiguration? {
        guard let entry = entry(for: endpoint, requester: requester) else { return nil }
        return entry.configuration
    }

    func snapshot(for endpoint: String, keypath: String, requester: Identity) -> ValueType? {
        guard let entry = entry(for: endpoint, requester: requester) else { return nil }
        return entry.snapshots[normalizedSnapshotKeypath(keypath)]
    }

    func metadata(for endpoint: String, requester: Identity) -> PortableSurfaceCacheMetadata? {
        guard let entry = entry(for: endpoint, requester: requester) else { return nil }
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

    func remove(endpoint: String, requester: Identity) {
        guard let identity = cacheIdentity(for: endpoint, requester: requester) else { return }
        loadIfNeeded()
        entries.removeValue(forKey: identity)
        persist()
    }

    private func entry(for endpoint: String, requester: Identity) -> Entry? {
        guard let identity = cacheIdentity(for: endpoint, requester: requester) else { return nil }
        loadIfNeeded()
        return entries[identity]
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true

        guard let url = fileURLOverride else {
            purgeLegacyUnscopedCache()
            return
        }
        guard
              let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schema == Self.envelopeSchema else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        entries = envelope.entries
        prune()
    }

    private func persist() {
        guard let url = fileURLOverride else { return }
        let directoryURL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let envelope = Envelope(schema: Self.envelopeSchema, entries: entries)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func purgeLegacyUnscopedCache() {
        let url = legacyFileURLOverride ?? defaultLegacyCacheFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func defaultLegacyCacheFileURL() -> URL {
        let fileManager = FileManager.default
        let baseURL =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent("Binding/portable-surface-cache.json")
    }

    private func endpointIdentity(for endpoint: String) -> String? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    private func cacheIdentity(for endpoint: String, requester: Identity) -> String? {
        guard let endpointIdentity = endpointIdentity(for: endpoint),
              let fingerprint = requester.signingPublicKeyFingerprint?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !fingerprint.isEmpty else {
            return nil
        }
        return "\(endpointIdentity)|\(requester.uuid.lowercased())|\(fingerprint)"
    }

    private func normalizedSnapshotKeypath(_ keypath: String) -> String {
        keypath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prune() {
        for (identity, var entry) in entries {
            if entry.snapshots.count > Self.maximumSnapshotsPerEntry {
                let retainedKeypaths = Set(
                    entry.snapshots.keys
                        .sorted { lhs, rhs in
                            let lhsUpdated = entry.snapshotUpdatedAtEpochMs[lhs] ?? 0
                            let rhsUpdated = entry.snapshotUpdatedAtEpochMs[rhs] ?? 0
                            if lhsUpdated == rhsUpdated {
                                return lhs.localizedStandardCompare(rhs) == .orderedDescending
                            }
                            return lhsUpdated > rhsUpdated
                        }
                        .prefix(Self.maximumSnapshotsPerEntry)
                )
                entry.snapshots = entry.snapshots.filter { retainedKeypaths.contains($0.key) }
                entry.snapshotUpdatedAtEpochMs = entry.snapshotUpdatedAtEpochMs.filter { retainedKeypaths.contains($0.key) }
                entries[identity] = entry
            }
        }

        if entries.count > Self.maximumRetainedEntries {
            let retainedIdentities = Set(
                entries
                    .sorted { lhs, rhs in
                        if lhs.value.lastUpdatedAtEpochMs == rhs.value.lastUpdatedAtEpochMs {
                            return lhs.key.localizedStandardCompare(rhs.key) == .orderedDescending
                        }
                        return lhs.value.lastUpdatedAtEpochMs > rhs.value.lastUpdatedAtEpochMs
                    }
                    .prefix(Self.maximumRetainedEntries)
                    .map(\.key)
            )
            entries = entries.filter { retainedIdentities.contains($0.key) }
        }
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
