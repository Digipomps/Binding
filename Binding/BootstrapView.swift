import SwiftUI
import CellBase
import CellApple
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif

actor BindingLocalCellRegistration {
    static let shared = BindingLocalCellRegistration()

    private var isRegistered = false
    private var registrationTask: Task<Void, Never>?

    func ensureRegistered() async {
        if isRegistered {
            return
        }
        if let registrationTask {
            await registrationTask.value
            return
        }

        let task = Task {
            await AppInitializer.initialize()
            let resolver = CellResolver.sharedInstance
            await Self.registerAll(on: resolver)
        }
        registrationTask = task
        await task.value
        isRegistered = true
        registrationTask = nil
    }

    private static func registerAll(on resolver: CellResolver) async {
        await register(
            name: "EventEmitter",
            cellScope: .template,
            identityDomain: "private",
            type: EventEmitterCell.self,
            resolver: resolver
        )
        await register(
            name: "FolderWatch",
            cellScope: .template,
            identityDomain: "private",
            type: FolderWatchCell.self,
            resolver: resolver
        )
        await register(
            name: "AgentEnrollment",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: AgentEnrollmentCell.self,
            resolver: resolver
        )
        await register(
            name: "AgentProvisioning",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: AgentProvisioningCell.self,
            resolver: resolver
        )
        await register(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantPreviewShell",
            cellScope: .scaffoldUnique,
            identityDomain: "private",
            type: ConferenceParticipantPreviewShellLocalFallbackCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceAdminPreviewShell",
            cellScope: .scaffoldUnique,
            identityDomain: "private",
            type: ConferenceAdminPreviewShellLocalFallbackCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceNearbyRadar",
            cellScope: .scaffoldUnique,
            identityDomain: "private",
            type: ConferenceNearbyRadarLocalCell.self,
            resolver: resolver
        )
    }

    private static func register<CellType: Emit & OwnerInstantiable>(
        name: String,
        cellScope: CellUsageScope,
        persistency: Persistancy? = nil,
        identityDomain: String,
        type: CellType.Type,
        resolver: CellResolver
    ) async {
        do {
            if let persistency {
                try await resolver.addCellResolve(
                    name: name,
                    cellScope: cellScope,
                    persistency: persistency,
                    identityDomain: identityDomain,
                    type: type
                )
            } else {
                try await resolver.addCellResolve(
                    name: name,
                    cellScope: cellScope,
                    identityDomain: identityDomain,
                    type: type
                )
            }
        } catch {
            let errorDescription = String(describing: error).lowercased()
            guard !errorDescription.contains("duplicatedendpointname"),
                  !errorDescription.contains("registeratalreadytakenendpoint") else {
                return
            }
            print("Binding local cell registration failed for \(name): \(error)")
        }
    }
}

struct ConferenceNearbyFollowUpTarget: Equatable {
    var remoteUUID: String
    var participantId: String
    var identityUUID: String?
    var displayName: String
    var company: String?
    var role: String?

    func discoveryTargetObject() -> Object {
        var object: Object = [
            "participantId": .string(participantId),
            "displayName": .string(displayName),
            "company": .string(company ?? ""),
            "role": .string(role ?? "")
        ]
        if let identityUUID {
            object["identityUUID"] = .string(identityUUID)
        }
        return object
    }
}

enum ConferenceNearbyFollowUpSupport {
    static func target(
        from encounter: Object,
        fallbackRemoteUUID: String,
        fallbackDisplayName: String
    ) -> ConferenceNearbyFollowUpTarget {
        let remotePerspective = object(from: encounter["remotePerspective"])
        let identityUUID = normalizedString(from: encounter["remoteIdentityUUID"])
        let participantId = prioritizedString(
            in: remotePerspective,
            keypaths: [
                ["participantId"],
                ["profile", "participantId"],
                ["participant", "participantId"],
                ["identityProfile", "state", "participantId"],
                ["publicProfile", "profile", "participantId"],
                ["publicProfile", "state", "profile", "participantId"],
                ["editorState", "participantId"]
            ]
        ) ?? synthesizedParticipantId(remoteUUID: fallbackRemoteUUID, identityUUID: identityUUID)
        let displayName = normalizedString(from: encounter["remoteDisplayName"])
            ?? prioritizedString(
                in: remotePerspective,
                keypaths: [
                    ["displayName"],
                    ["name"],
                    ["profile", "displayName"],
                    ["profile", "name"],
                    ["participant", "name"],
                    ["identityProfile", "state", "name"],
                    ["publicProfile", "profile", "displayName"],
                    ["publicProfile", "profile", "name"],
                    ["publicProfile", "state", "profile", "displayName"],
                    ["publicProfile", "state", "profile", "name"]
                ]
            )
            ?? fallbackDisplayName
        let company = prioritizedString(
            in: remotePerspective,
            keypaths: [
                ["company"],
                ["profile", "company"],
                ["participant", "company"],
                ["identityProfile", "state", "company"],
                ["publicProfile", "profile", "company"],
                ["publicProfile", "state", "profile", "company"]
            ]
        )
        let role = prioritizedString(
            in: remotePerspective,
            keypaths: [
                ["role"],
                ["profile", "role"],
                ["participant", "role"],
                ["identityProfile", "state", "role"],
                ["publicProfile", "profile", "role"],
                ["publicProfile", "state", "profile", "role"]
            ]
        )

        return ConferenceNearbyFollowUpTarget(
            remoteUUID: fallbackRemoteUUID,
            participantId: participantId,
            identityUUID: identityUUID,
            displayName: displayName,
            company: company,
            role: role
        )
    }

    static func discoveryPayload(for target: ConferenceNearbyFollowUpTarget, source: String) -> Object {
        var payload: Object = [
            "source": .string(source),
            "participantIds": .list([.string(target.participantId)]),
            "displayName": .string(target.displayName),
            "company": .string(target.company ?? ""),
            "role": .string(target.role ?? ""),
            "targets": .list([.object(target.discoveryTargetObject())])
        ]
        if let identityUUID = target.identityUUID {
            payload["identityUUIDs"] = .list([.string(identityUUID)])
        }
        return payload
    }

    static func synthesizedParticipantId(remoteUUID: String, identityUUID: String?) -> String {
        let seed = identityUUID ?? remoteUUID
        let sanitized = seed
            .lowercased()
            .map { character -> Character in
                if character.isLetter || character.isNumber {
                    return character
                }
                return "-"
            }
            .reduce(into: "") { partial, character in
                if character == "-", partial.last == "-" {
                    return
                }
                partial.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if sanitized.isEmpty {
            return "nearby-participant"
        }
        return "nearby-\(sanitized)"
    }

    private static func prioritizedString(in object: Object?, keypaths: [[String]]) -> String? {
        for keypath in keypaths {
            if let string = string(at: keypath, in: object) {
                return string
            }
        }
        return nil
    }

    private static func string(at keypath: [String], in object: Object?) -> String? {
        guard let object else { return nil }
        var current: ValueType = .object(object)
        for key in keypath {
            guard case let .object(dictionary) = current,
                  let nextValue = dictionary[key] else {
                return nil
            }
            current = nextValue
        }
        return normalizedString(from: current)
    }

    private static func normalizedString(from value: ValueType?) -> String? {
        guard case let .string(raw)? = value else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func object(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }
}

@MainActor
private final class ConferenceNearbyRadarLocalCell: GeneralCell {
    private enum CompassSector: String, CaseIterable {
        case left
        case ahead
        case right
        case behind

        var title: String {
            switch self {
            case .left: return "Left"
            case .ahead: return "Ahead"
            case .right: return "Right"
            case .behind: return "Behind"
            }
        }
    }

    private struct ContactSignal {
        var status: String
        var summary: String
        var actionLabel: String
    }

    private struct PurposeSignal {
        var count: Int
        var score: Double?
        var summary: String
        var detail: String
    }

    private let bootstrapRequester: Identity
    private var scannerEmit: Emit?
    private var scannerMeddle: Meddle?
    private var activeRequester: Identity?
    private var flowCancellable: AnyCancellable?
    private var connectionTask: Task<Void, Never>?

    private var entitiesById: [String: NearbyEntity] = [:]
    private var scannerStatus = "idle"
    private var transportMode = "multipeerconnectivity"
    private var precisionMode = "unknown"
    private var capabilityDescription = "Start the scanner to evaluate nearby transport and precision."
    private var supportsNearbyPrecision = false
    private var contactSignalsById: [String: ContactSignal] = [:]
    private var purposeSignalsById: [String: PurposeSignal] = [:]
    private var followUpTargetsById: [String: ConferenceNearbyFollowUpTarget] = [:]
    private var launchedChatRemoteUUIDs: Set<String> = []
    private var lastError: String?
    private var lastActionSummary = "Nearby radar is ready. Request contact to unlock verified purpose and interest matching."

    required init(owner: Identity) async {
        self.bootstrapRequester = owner
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceNearbyRadarLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    deinit {
        flowCancellable?.cancel()
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "start")
        agreementTemplate.addGrant("rw--", for: "stop")
        agreementTemplate.addGrant("rw--", for: "invite")
        agreementTemplate.addGrant("rw--", for: "requestContact")
        agreementTemplate.addGrant("rw--", for: "openFollowUpChat")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.connectScannerIfNeeded(requester: requester)
            return .object(self.snapshotObject())
        })

        await addInterceptForSet(requester: owner, key: "start", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "start", for: requester) else { return .string("denied") }
            return await self.forwardMutation(keypath: "start", value: .bool(true), requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "stop", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "stop", for: requester) else { return .string("denied") }
            return await self.forwardMutation(keypath: "stop", value: .bool(true), requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "invite", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "invite", for: requester) else { return .string("denied") }
            return await self.forwardMutation(keypath: "invite", value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "requestContact", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "requestContact", for: requester) else { return .string("denied") }
            return await self.forwardMutation(keypath: "requestContact", value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "openFollowUpChat", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "openFollowUpChat", for: requester) else { return .string("denied") }
            return await self.openFollowUpChat(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.forwardDispatchAction(value: value, requester: requester)
        })

        Task { [weak self] in
            guard let self else { return }
            await self.connectScannerIfNeeded(requester: owner)
            self.emitSnapshot(requester: owner)
        }
    }

    private func connectScannerIfNeeded(requester: Identity) async {
        if scannerEmit != nil, scannerMeddle != nil {
            activeRequester = requester
            return
        }
        if let connectionTask {
            await connectionTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await AppInitializer.initialize()
            guard let resolver = CellBase.defaultCellResolver else {
                self.lastError = "Cell resolver missing"
                self.emitSnapshot(requester: requester)
                return
            }

            do {
                let emit = try await resolver.cellAtEndpoint(endpoint: "cell:///EntityScanner", requester: requester)
                guard let meddle = emit as? Meddle else {
                    self.lastError = "EntityScanner does not support meddle"
                    self.emitSnapshot(requester: requester)
                    return
                }

                self.activeRequester = requester
                self.scannerEmit = emit
                self.scannerMeddle = meddle
                self.lastError = nil
                try await self.subscribeToScannerFlow(emitter: emit, requester: requester)
                await self.refreshCapabilitySnapshot(requester: requester)
                await self.refreshEncounterSnapshot(requester: requester)
                self.emitSnapshot(requester: requester)
            } catch {
                self.lastError = "Failed to connect nearby scanner: \(error)"
                self.emitSnapshot(requester: requester)
            }
        }

        connectionTask = task
        await task.value
        connectionTask = nil
    }

    private func subscribeToScannerFlow(emitter: Emit, requester: Identity) async throws {
        flowCancellable?.cancel()
        let publisher = try await emitter.flow(requester: requester)
        flowCancellable = publisher.sink(
            receiveCompletion: { [weak self] completion in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if case let .failure(error) = completion {
                        self.lastError = "Nearby scanner flow ended: \(error)"
                        let snapshotRequester = self.activeRequester ?? self.bootstrapRequester
                        self.emitSnapshot(requester: snapshotRequester)
                    }
                }
            },
            receiveValue: { [weak self] flowElement in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.consume(flowElement: flowElement)
                }
            }
        )
    }

    private func forwardMutation(keypath: String, value: ValueType, requester: Identity) async -> ValueType {
        await connectScannerIfNeeded(requester: requester)
        guard let scannerMeddle else {
            lastError = "EntityScanner unavailable"
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        do {
            let result = try await scannerMeddle.set(keypath: keypath, value: value, requester: requester)
            lastError = nil
            applyMutationResult(keypath: keypath, result: result, payload: value)
            await refreshCapabilitySnapshot(requester: requester)
            if keypath == "requestContact" {
                await refreshEncounterSnapshot(requester: requester)
            }
        } catch {
            lastError = "Nearby scanner action \(keypath) failed: \(error)"
            lastActionSummary = "Nearby action failed: \(error)"
        }

        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func forwardDispatchAction(value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(actionObject) = value,
              let actionKeypath = string(from: actionObject["keypath"]),
              actionKeypath.isEmpty == false else {
            lastError = "Nearby action payload mangler keypath."
            lastActionSummary = "Nearby action payload mangler keypath."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        let actionPayload = actionObject["payload"] ?? .bool(true)
        switch actionKeypath {
        case "start", "stop", "invite", "requestContact":
            return await forwardMutation(keypath: actionKeypath, value: actionPayload, requester: requester)
        case "openFollowUpChat":
            return await openFollowUpChat(value: actionPayload, requester: requester)
        default:
            lastError = "Nearby action \(actionKeypath) er ikke stoettet."
            lastActionSummary = "Nearby action \(actionKeypath) er ikke stoettet."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }
    }

    private func refreshCapabilitySnapshot(requester: Identity) async {
        guard let scannerMeddle else {
            return
        }
        do {
            let capabilityValue = try await scannerMeddle.get(keypath: "capabilities", requester: requester)
            if case let .object(capabilityObject) = capabilityValue {
                applyCapabilities(from: capabilityObject)
            }
        } catch {
            lastError = "Could not refresh scanner capabilities: \(error)"
        }
    }

    private func refreshEncounterSnapshot(requester: Identity) async {
        guard let scannerMeddle else {
            return
        }
        do {
            let encountersValue = try await scannerMeddle.get(keypath: "encounters", requester: requester)
            applyEncounterSummaries(from: encountersValue)
        } catch {
            lastError = "Could not refresh nearby encounter summaries: \(error)"
        }
    }

    private func openFollowUpChat(value: ValueType, requester: Identity) async -> ValueType {
        guard let remoteUUID = normalizedRemoteUUID(string(from: object(from: value)?["remoteUUID"]) ?? string(from: value)),
              let target = followUpTargetsById[remoteUUID] else {
            lastError = "Nearby follow-up is not ready yet. Complete signed contact proof first."
            lastActionSummary = "Nearby follow-up is not ready yet. Complete signed contact proof first."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }
        guard let resolver = CellBase.defaultCellResolver else {
            lastError = "Cell resolver missing"
            lastActionSummary = "Could not open discovery chat because the local resolver is missing."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        do {
            guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: requester) as? Meddle else {
                lastError = "Porthole unavailable"
                lastActionSummary = "Could not open discovery chat because Porthole is unavailable."
                emitSnapshot(requester: requester)
                return .object(snapshotObject())
            }

            let dispatchPayload: Object = [
                "keypath": .string("discovery.startChat"),
                "payload": .object(
                    ConferenceNearbyFollowUpSupport.discoveryPayload(
                        for: target,
                        source: "nearby-verified-contact"
                    )
                )
            ]
            let result = try await porthole.set(
                keypath: "conferenceParticipantShell.dispatchAction",
                value: .object(dispatchPayload),
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: result) {
                lastError = errorDescription
                lastActionSummary = errorDescription
            } else {
                lastError = nil
                launchedChatRemoteUUIDs.insert(remoteUUID)
                lastActionSummary = "Started a conference follow-up chat with \(target.displayName)."
                if var contactSignal = contactSignalsById[remoteUUID] {
                    contactSignal.summary = "Verified contact saved. Discovery chat is ready for follow-up."
                    contactSignal.actionLabel = "Open chat"
                    contactSignalsById[remoteUUID] = contactSignal
                }
            }
        } catch {
            lastError = "Nearby follow-up chat failed: \(error)"
            lastActionSummary = "Nearby follow-up chat failed: \(error)"
        }

        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func consume(flowElement: FlowElement) async {
        if case let .object(object) = flowElement.content {
            applyCapabilities(from: object)
            applyContactEvent(topic: flowElement.topic, object: object)
        }

        guard let scannerEvent = RadarEventParser.parse(flowElement) else {
            let snapshotRequester = activeRequester ?? bootstrapRequester
            if flowElement.topic == "scanner.encounter.saved" || flowElement.topic == "scanner.contact.established" {
                await refreshEncounterSnapshot(requester: snapshotRequester)
            }
            emitSnapshot(requester: snapshotRequester)
            return
        }

        switch scannerEvent {
        case let .found(update):
            upsert(update, fallbackStatus: "found")
        case var .connected(update):
            if update.remoteUUID != nil, update.connected == nil {
                update.connected = true
            }
            upsert(update, fallbackStatus: "connected")
        case let .lost(update):
            handleLost(update)
        case let .proximity(update):
            upsert(update, fallbackStatus: "nearby")
        case let .status(update):
            if let status = update.status, !status.isEmpty {
                scannerStatus = status
            }
            upsert(update, fallbackStatus: scannerStatus)
        }

        pruneStaleEntities()
        let snapshotRequester = activeRequester ?? bootstrapRequester
        if flowElement.topic == "scanner.encounter.saved" || flowElement.topic == "scanner.contact.established" {
            await refreshEncounterSnapshot(requester: snapshotRequester)
        }
        emitSnapshot(requester: snapshotRequester)
    }

    private func applyCapabilities(from object: Object) {
        if let transport = string(from: object["transportMode"]), !transport.isEmpty {
            transportMode = transport
        }
        if let precision = string(from: object["precisionMode"]), !precision.isEmpty {
            precisionMode = precision
        }
        if let description = string(from: object["description"]), !description.isEmpty {
            capabilityDescription = description
        }
        if let status = string(from: object["status"]), !status.isEmpty {
            scannerStatus = status
        }
        if let supportsNearby = bool(from: object["supportsNearbyPrecision"]) {
            supportsNearbyPrecision = supportsNearby
        }
    }

    private func upsert(_ update: RadarEntityUpdate, fallbackStatus: String) {
        guard let remoteUUID = normalizedRemoteUUID(update.remoteUUID) else {
            return
        }

        var normalizedUpdate = update
        normalizedUpdate.remoteUUID = remoteUUID
        if normalizedUpdate.status == nil || normalizedUpdate.status?.isEmpty == true {
            normalizedUpdate.status = fallbackStatus
        }

        if var entity = entitiesById[remoteUUID] {
            entity.merge(update: normalizedUpdate, defaultStatus: fallbackStatus)
            entitiesById[remoteUUID] = entity
        } else {
            entitiesById[remoteUUID] = NearbyEntity(update: normalizedUpdate, defaultStatus: fallbackStatus)
        }
    }

    private func handleLost(_ update: RadarEntityUpdate) {
        guard let remoteUUID = normalizedRemoteUUID(update.remoteUUID) else {
            return
        }
        if var entity = entitiesById[remoteUUID] {
            var lostUpdate = update
            lostUpdate.remoteUUID = remoteUUID
            if lostUpdate.status == nil {
                lostUpdate.status = "lost"
            }
            lostUpdate.connected = false
            entity.merge(update: lostUpdate, defaultStatus: "lost")
            entitiesById[remoteUUID] = entity
        }
    }

    private func pruneStaleEntities() {
        guard !entitiesById.isEmpty else {
            return
        }

        let now = Date()
        let staleCutoff = now.addingTimeInterval(-20.0)
        let lostCutoff = now.addingTimeInterval(-4.0)

        let keysToRemove = entitiesById.compactMap { key, entity -> String? in
            if entity.status == "lost", entity.lastSeenAt < lostCutoff {
                return key
            }
            if !entity.connected, entity.lastSeenAt < staleCutoff {
                return key
            }
            return nil
        }

        keysToRemove.forEach { entitiesById.removeValue(forKey: $0) }
    }

    private func applyMutationResult(keypath: String, result: ValueType?, payload: ValueType) {
        guard keypath == "requestContact",
              let resultObject = object(from: result),
              let remoteUUID = normalizedRemoteUUID(string(from: resultObject["remoteUUID"]) ?? string(from: payload)) else {
            return
        }

        switch string(from: resultObject["status"]) ?? "" {
        case "pendingConnection":
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "pendingConnection",
                summary: "Invite sent. Signed contact proof starts when the device link is ready.",
                actionLabel: "Connecting..."
            )
            lastActionSummary = "Invite sent. Signed contact proof starts when the device link is ready."
        case "sent":
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "sent",
                summary: "Signed contact request sent. Waiting for the other side to accept.",
                actionLabel: "Contact pending"
            )
            lastActionSummary = "Signed contact request sent. Waiting for the other side to accept."
        case "error":
            let message = string(from: resultObject["message"]) ?? "Nearby contact request failed."
            lastError = message
            lastActionSummary = message
        default:
            break
        }
    }

    private func applyContactEvent(topic: String, object: Object) {
        guard let remoteUUID = normalizedRemoteUUID(string(from: object["remoteUUID"])) else {
            if topic == "scanner.status",
               let status = string(from: object["status"]),
               status == "error",
               let message = string(from: object["message"]) {
                lastError = message
                lastActionSummary = message
            }
            return
        }

        switch topic {
        case "scanner.contact.pending":
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "pendingConnection",
                summary: string(from: object["message"]) ?? "Invite sent. Waiting for a direct device link.",
                actionLabel: "Connecting..."
            )
            lastActionSummary = "Invite sent. Waiting for a direct device link before signed contact proof."
        case "scanner.contact.outgoing":
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "sent",
                summary: "Signed contact request sent. Waiting for acceptance.",
                actionLabel: "Contact pending"
            )
            lastActionSummary = "Signed contact request sent."
        case "scanner.contact.established", "scanner.encounter.saved":
            let matchCount = purposeSignalsById[remoteUUID]?.count ?? int(from: object["matchCount"]) ?? 0
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "verified",
                summary: matchCount > 0
                    ? "Verified contact saved with \(matchCount) purpose/interest overlap(s)."
                    : "Verified contact saved. No overlap confirmed yet.",
                actionLabel: "Verified contact"
            )
            lastActionSummary = contactSignalsById[remoteUUID]?.summary ?? "Verified contact saved."
        default:
            break
        }
    }

    private func applyEncounterSummaries(from value: ValueType) {
        guard case let .list(encounters) = value else {
            return
        }

        var refreshedPurposeSignals: [String: PurposeSignal] = [:]
        var refreshedFollowUpTargets: [String: ConferenceNearbyFollowUpTarget] = [:]
        for encounterValue in encounters {
            guard let encounter = object(from: encounterValue),
                  let remoteUUID = normalizedRemoteUUID(string(from: encounter["remoteUUID"])) else {
                continue
            }

            let purposeSignal = makePurposeSignal(from: encounter)
            refreshedPurposeSignals[remoteUUID] = purposeSignal
            refreshedFollowUpTargets[remoteUUID] = ConferenceNearbyFollowUpSupport.target(
                from: encounter,
                fallbackRemoteUUID: remoteUUID,
                fallbackDisplayName: string(from: encounter["remoteDisplayName"])
                    ?? entitiesById[remoteUUID]?.displayName
                    ?? remoteUUID
            )
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "verified",
                summary: purposeSignal.count > 0
                    ? "Verified contact saved with \(purposeSignal.count) purpose/interest overlap(s)."
                    : "Verified contact saved. No overlap confirmed yet.",
                actionLabel: "Verified contact"
            )
        }

        purposeSignalsById = refreshedPurposeSignals
        followUpTargetsById = refreshedFollowUpTargets
        launchedChatRemoteUUIDs.formIntersection(Set(refreshedFollowUpTargets.keys))
    }

    private func makePurposeSignal(from encounter: Object) -> PurposeSignal {
        let matchCount = int(from: encounter["matchCount"]) ?? 0
        let matchObject = object(from: encounter["match"])
        let topHit = list(from: matchObject?["allHits"])?.compactMap { object(from: $0) }.first
        let topScore = double(from: topHit?["matchScore"])
        let sourcePurpose = string(from: topHit?["sourcePurposeName"])
        let targetPurpose = string(from: topHit?["targetPurposeName"])
        let interestName = string(from: topHit?["interestName"])

        if matchCount > 0 {
            let summary: String
            if let interestName, !interestName.isEmpty {
                summary = "\(matchCount) verified overlap(s) via \(interestName)"
            } else if let sourcePurpose, let targetPurpose {
                summary = "\(matchCount) verified overlap(s): \(sourcePurpose) <-> \(targetPurpose)"
            } else {
                summary = "\(matchCount) verified purpose/interest overlap(s)"
            }

            let detail: String
            if let topScore {
                detail = "Top verified match score \(String(format: "%.2f", topScore))"
            } else {
                detail = "Verified after signed contact proof."
            }

            return PurposeSignal(
                count: matchCount,
                score: topScore,
                summary: summary,
                detail: detail
            )
        }

        let remotePerspective = object(from: encounter["remotePerspective"])
        let advertisedPurpose = remotePerspective.flatMap(advertisedPurposeSummary(from:))
        return PurposeSignal(
            count: 0,
            score: nil,
            summary: advertisedPurpose ?? "No verified purpose overlap yet",
            detail: "Purpose signal becomes verified after signed contact proof."
        )
    }

    private func fallbackPurposeSummary(for remoteUUID: String, liveScore: Double?) -> String {
        if let liveScore {
            return "Live proximity fit \(String(format: "%.2f", liveScore))"
        }
        if let purposeSignal = purposeSignalsById[remoteUUID] {
            return purposeSignal.summary
        }
        return "Proximity only · request contact to verify purpose and interest fit"
    }

    private func advertisedPurposeSummary(from remotePerspective: Object) -> String? {
        guard let advertisedPurpose = object(from: remotePerspective["advertisedPurpose"]),
              let firstPurpose = advertisedPurpose.values.compactMap(string(from:)).first,
              !firstPurpose.isEmpty else {
            return nil
        }
        return "Advertised purpose: \(firstPurpose)"
    }

    private func snapshotObject() -> Object {
        pruneStaleEntities()

        let entities = sortedEntities()
        let sectors = CompassSector.allCases.map { sector in
            makeSectorCard(for: sector, entities: entities.filter { compassSector(for: $0) == sector })
        }

        let nearbyCards = entities.prefix(8).map(makeNearbyCard(for:))
        let connectedCount = entities.filter(\.connected).count
        let verifiedMatchCount = purposeSignalsById.values.filter { $0.count > 0 }.count
        let followUpCount = followUpTargetsById.count
        let summary = entities.isEmpty
            ? "Ingen nearby peers enda. Start scanner for å bygge et lokalt spatialt bilde."
            : "\(entities.count) nearby peer(s) · \(connectedCount) connected · \(verifiedMatchCount) verified purpose fit(s) · \(followUpCount) follow-up chat(s) ready."

        let precisionSummary: String
        if precisionMode.lowercased().contains("uwb") || supportsNearbyPrecision {
            precisionSummary = "UWB-precision is available on this device. MPC remains the base transport."
        } else {
            precisionSummary = "Using MPC-only proximity. Direction and distance stay less precise until UWB is available."
        }

        let localityNote = "Binding-local spatial enrichment over EntityScanner. This augments conference discovery without replacing the portable scaffold contract."

        return [
            "headline": .string("Nearby Participants"),
            "summary": .string(summary),
            "precisionSummary": .string(precisionSummary),
            "actionSummary": .string(lastActionSummary),
            "transportBadge": .string(transportMode.uppercased()),
            "precisionBadge": .string(precisionMode.uppercased()),
            "statusBadge": .string(scannerStatus),
            "localityNote": .string(localityNote),
            "description": .string(capabilityDescription),
            "sectors": .list(sectors.map(ValueType.object)),
            "nearby": .list(nearbyCards.map(ValueType.object)),
            "emptyState": .string(entities.isEmpty ? "No nearby participants visible yet." : ""),
            "lastError": .string(lastError ?? "")
        ]
    }

    private func emitSnapshot(requester: Identity) {
        var flowElement = FlowElement(
            title: "Nearby Radar Snapshot",
            content: .object(snapshotObject()),
            properties: FlowElement.Properties(type: .content, contentType: .object)
        )
        flowElement.topic = "nearbyRadar.snapshot"
        flowElement.origin = self.uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func sortedEntities() -> [NearbyEntity] {
        entitiesById.values.sorted { lhs, rhs in
            let lhsDistance = lhs.distanceMeters ?? .greatestFiniteMagnitude
            let rhsDistance = rhs.distanceMeters ?? .greatestFiniteMagnitude
            if lhs.connected != rhs.connected {
                return lhs.connected && !rhs.connected
            }
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return lhs.lastSeenAt > rhs.lastSeenAt
        }
    }

    private func makeSectorCard(for sector: CompassSector, entities: [NearbyEntity]) -> Object {
        let closest = entities
            .compactMap(\.distanceMeters)
            .min()
            .map { String(format: "%.1f m", $0) }
            ?? "No distance yet"

        let previewNames = entities
            .prefix(2)
            .map(\.displayName)
            .joined(separator: " · ")

        return [
            "title": .string(sector.title),
            "subtitle": .string("\(entities.count) peer(s)"),
            "detail": .string(entities.isEmpty ? "No active signals" : "Closest: \(closest)"),
            "note": .string(previewNames.isEmpty ? "Waiting for signals" : previewNames)
        ]
    }

    private func makeNearbyCard(for entity: NearbyEntity) -> Object {
        let sector = compassSector(for: entity)
        let distanceText = entity.distanceMeters.map { String(format: "%.1f m", $0) } ?? "Distance pending"
        let precisionText = precisionMode.lowercased().contains("uwb") || supportsNearbyPrecision
            ? "UWB-ready when available"
            : "MPC approximate"
        let detail = "\(sector.title) · \(distanceText) · \(entity.connected ? "connected" : "visible")"
        let purposeSignal = purposeSignalsById[entity.remoteUUID]
        let contactSignal = contactSignalsById[entity.remoteUUID]
        let note = contactSignal?.summary ?? "\(entity.status) · \(precisionText)"

        if followUpTargetsById[entity.remoteUUID] != nil,
           contactSignal?.status == "verified" {
            let hasLaunchedChat = launchedChatRemoteUUIDs.contains(entity.remoteUUID)
            return [
                "title": .string(entity.displayName),
                "subtitle": .string("\(sector.title) sector"),
                "detail": .string(detail),
                "purposeSummary": .string(purposeSignal?.summary ?? fallbackPurposeSummary(for: entity.remoteUUID, liveScore: entity.matchScore)),
                "purposeDetail": .string(purposeSignal?.detail ?? "Purpose fit remains approximate until signed contact is established."),
                "note": .string(hasLaunchedChat ? "Discovery chat is ready. \(note)" : note),
                "keypath": .string("dispatchAction"),
                "label": .string(hasLaunchedChat ? "Open chat" : "Start chat"),
                "payload": .object([
                    "keypath": .string("openFollowUpChat"),
                    "payload": .object(["remoteUUID": .string(entity.remoteUUID)])
                ])
            ]
        }

        return [
            "title": .string(entity.displayName),
            "subtitle": .string("\(sector.title) sector"),
            "detail": .string(detail),
            "purposeSummary": .string(purposeSignal?.summary ?? fallbackPurposeSummary(for: entity.remoteUUID, liveScore: entity.matchScore)),
            "purposeDetail": .string(purposeSignal?.detail ?? "Purpose fit remains approximate until signed contact is established."),
            "note": .string(note),
            "keypath": .string("dispatchAction"),
            "label": .string(contactSignal?.actionLabel ?? "Request contact"),
            "payload": .object([
                "keypath": .string("requestContact"),
                "payload": .string(entity.remoteUUID)
            ])
        ]
    }

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        guard let value else { return "Unknown nearby follow-up failure." }
        switch value {
        case let .string(string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            if trimmed == "denied" || trimmed.hasPrefix("error:") || trimmed.hasPrefix("failure") {
                return trimmed
            }
            return nil
        case let .object(object):
            if case let .string(status)? = object["status"],
               status == "error",
               let message = string(from: object["message"]) {
                return message
            }
            return nil
        default:
            return nil
        }
    }

    private func compassSector(for entity: NearbyEntity) -> CompassSector {
        let angle = entity.radarAngleRadians
        if angle >= -.pi / 4, angle < .pi / 4 {
            return .ahead
        }
        if angle >= .pi / 4, angle < 3 * .pi / 4 {
            return .right
        }
        if angle <= -.pi / 4, angle > -3 * .pi / 4 {
            return .left
        }
        return .behind
    }

    private func normalizedRemoteUUID(_ remoteUUID: String?) -> String? {
        guard let remoteUUID else {
            return nil
        }
        let normalizedUUID = remoteUUID.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedUUID.isEmpty ? nil : normalizedUUID
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        if case let .string(string) = value {
            return string
        }
        return nil
    }

    private func bool(from value: ValueType?) -> Bool? {
        guard let value else { return nil }
        if case let .bool(bool) = value {
            return bool
        }
        return nil
    }

    private func int(from value: ValueType?) -> Int? {
        guard let value else { return nil }
        switch value {
        case let .integer(integer):
            return integer
        case let .float(float):
            return Int(float)
        case let .number(number):
            return number
        case let .string(string):
            return Int(string)
        default:
            return nil
        }
    }

    private func double(from value: ValueType?) -> Double? {
        guard let value else { return nil }
        switch value {
        case let .float(float):
            return float
        case let .integer(integer):
            return Double(integer)
        case let .number(number):
            return Double(number)
        case let .string(string):
            return Double(string)
        default:
            return nil
        }
    }

    private func object(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else {
            return nil
        }
        return object
    }

    private func list(from value: ValueType?) -> [ValueType]? {
        guard case let .list(list)? = value else {
            return nil
        }
        return list
    }
}

struct BootstrapView<Content: View>: View {
    @State private var isReady = false
    let content: () -> Content

    var body: some View {
        Group {
            if isReady {
                content()
            } else {
                ProgressView("Starter opp…")
            }
        }
        .task {
            await BindingLocalCellRegistration.shared.ensureRegistered()
            isReady = true
        }
    }
}

private final class ConferenceParticipantPreviewShellLocalFallbackCell: GeneralCell {
    private var agendaView = "forYou"
    private var activeTrackID = "track-governance"
    private var currentFilter = "Governance og interoperabilitet"
    private var pendingRequestCount = 2
    private var confirmedMeetingCount = 3
    private var exportPrepared = false
    private var searchQuery = "governance"
    private var recentMessageTexts = [
        "Takk for praten. Skal vi fortsette etter neste sesjon?",
        "Jeg kan dele oppsummeringen fra governance-panelet etter lunsj."
    ]
    private var launchedDiscoveryChatNames: [String] = []
    private var recentActionSummary = "Participant-preview kjører lokalt i Binding fordi staging-preview svarte denied."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, _ in
            guard let self else { return .string("failure") }
            return .object(self.makeStateObject())
        })
        await addInterceptForGet(requester: owner, key: "skeletonConfiguration", getValueIntercept: { _, _ in
            .null
        })
        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, _ in
            guard let self else { return .string("failure") }
            return await self.handleDispatchAction(value)
        })
    }

    private func handleDispatchAction(_ value: ValueType) async -> ValueType {
        guard case let .object(object) = value,
              case let .string(actionKeypath)? = object["keypath"] else {
            return .string("error: invalid action payload")
        }

        let payload = object["payload"] ?? .null
        switch actionKeypath {
        case "agenda.setView":
            if case let .object(viewObject) = payload,
               case let .string(view)? = viewObject["view"] {
                agendaView = view
                recentActionSummary = "Byttet agenda-visning til \(viewLabel(view))."
            }
        case "agenda.setTrackFocus":
            if case let .object(trackObject) = payload,
               case let .string(trackID)? = trackObject["trackId"] {
                activeTrackID = trackID
                recentActionSummary = "Fokus er satt til \(trackLabel(trackID))."
            }
        case "matchmaking.refreshRecommendations":
            recentActionSummary = "Anbefalingene ble oppdatert lokalt i preview."
        case "matchmaking.setFilters":
            currentFilter = currentFilter == "Governance og interoperabilitet" ? "Identity, trust og claims" : "Governance og interoperabilitet"
            recentActionSummary = "Matchmaking-filteret ble byttet til \(currentFilter.lowercased())."
        case "matchmaking.searchPeople":
            if case let .object(searchObject) = payload,
               case let .string(query)? = searchObject["query"],
               !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchQuery = query
                recentActionSummary = "Søket ble oppdatert til '\(query)'."
            }
        case "scheduling.createMeetingRequest":
            pendingRequestCount += 1
            recentActionSummary = "La til en ny møteforespørsel i preview-køen."
        case "scheduling.exportICal":
            exportPrepared = true
            recentActionSummary = "iCal-forberedelsen er klar i lokal preview."
        case "scheduling.respondMeetingRequest":
            if pendingRequestCount > 0 {
                pendingRequestCount -= 1
                confirmedMeetingCount += 1
            }
            recentActionSummary = "Oppdaterte møteforespørsler og bekreftelser."
        case "connections.postSharedMessage":
            if case let .object(messageObject) = payload,
               case let .string(text)? = messageObject["text"],
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                recentMessageTexts.insert(text, at: 0)
                recentMessageTexts = Array(recentMessageTexts.prefix(4))
                recentActionSummary = "La til en ny oppfølgingsmelding i shared network."
            }
        case "discovery.startChat":
            let targetNames = discoveryTargetNames(from: payload)
            if let firstTarget = targetNames.first {
                launchedDiscoveryChatNames.removeAll { $0 == firstTarget }
                launchedDiscoveryChatNames.insert(firstTarget, at: 0)
                launchedDiscoveryChatNames = Array(launchedDiscoveryChatNames.prefix(4))
                recentMessageTexts.insert("Nearby follow-up med \(firstTarget) er klar i discovery chat.", at: 0)
                recentMessageTexts = Array(recentMessageTexts.prefix(4))
                recentActionSummary = "Startet oppfølgingschat med \(firstTarget) i lokal preview."
            } else {
                recentActionSummary = "Startet en discovery-chat i lokal preview."
            }
        case "discovery.startGroupChat":
            let targetNames = discoveryTargetNames(from: payload)
            if targetNames.isEmpty == false {
                let summary = targetNames.joined(separator: ", ")
                recentMessageTexts.insert("Nearby group follow-up er klar med \(summary).", at: 0)
                recentMessageTexts = Array(recentMessageTexts.prefix(4))
                recentActionSummary = "Startet gruppechat med \(summary) i lokal preview."
            } else {
                recentActionSummary = "Startet en discovery-gruppechat i lokal preview."
            }
        default:
            recentActionSummary = "Utførte \(actionKeypath) i lokal conference-preview."
        }

        return .object([
            "status": .string("ok"),
            "state": .object(makeStateObject())
        ])
    }

    private func makeStateObject() -> Object {
        let meetingSummary = "\(confirmedMeetingCount) bekreftede møter og \(pendingRequestCount) ventende forespørsler."
        let requestSummary = "\(pendingRequestCount) møteforespørsler venter på svar."
        let trackSummary = "\(trackLabel(activeTrackID)) er i fokus akkurat nå."
        let timelineSummary = timelineSummaryText(for: agendaView)
        let viewSummary = "Visning: \(viewLabel(agendaView))."
        let exportStatus = exportPrepared ? "iCal-eksporten er klar til deling." : "Ingen iCal-eksport er forberedt ennå."
        let activeChatCount = max(2, recentMessageTexts.count)
        let recentMessages = recentMessageTexts.map { text in
            ValueType.object([
                "title": .string("Shared thread"),
                "detail": .string(text),
                "note": .string("Nylig oppfølging")
            ])
        }
        let dynamicNearbyConnections = launchedDiscoveryChatNames.map { name in
            connectionCard(
                title: name,
                subtitle: "Nearby verified contact",
                detail: "Verified nearby encounter opened a discovery follow-up chat.",
                note: "Scanner enriched"
            )
        }

        return [
            "workspace": .object([
                "title": .string("Conference Participant Portal Dashboard"),
                "subtitle": .string("Agenda, møter og matchende personer i én mørk conference-flate."),
                "participantBadge": .string("Participant"),
                "programBadge": .string("Program ready"),
                "matchBadge": .string("Matches active"),
                "meetingBadge": .string("\(confirmedMeetingCount) møter bekreftet"),
                "nextStep": .string(recentActionSummary),
                "previewNotice": .string("Lokal preview brukes fordi staging-preview svarte denied. Kontrakten holdes lik, så demoen kan fortsette.")
            ]),
            "program": .object([
                "intro": .string("Agendaen er klar for governance, interoperabilitet og praktisk oppfølging."),
                "agendaSummary": .string("6 lagrede sesjoner og 2 valgte fokusspor."),
                "viewSummary": .string(viewSummary),
                "trackSummary": .string(trackSummary),
                "timelineSummary": .string(timelineSummary),
                "status": .string("Agenda-preview er lesbar og responsiv lokalt."),
                "storageSummary": .string("Valg og preferanser holdes stabile i preview-state."),
                "trackOptions": .list([
                    sessionCard(title: "Applied AI", subtitle: "4 session(s)", detail: "Practical AI systems and tooling.", note: "Available for focus"),
                    sessionCard(title: "Identity", subtitle: "4 session(s)", detail: "Trust, verification and claims.", note: "Available for focus"),
                    sessionCard(title: "Governance", subtitle: "4 session(s)", detail: "Policy, regulation and coordination.", note: "Focused now")
                ]),
                "recommendedSessions": .list([
                    sessionCard(title: "Identity Session 8", subtitle: "Identity · 09:30-10:00", detail: "Forum: identity, AI and digital independence.", note: "Matches interests"),
                    sessionCard(title: "Governance Session 15", subtitle: "Governance · 10:00-10:30", detail: "Library: governance, AI and digital independence.", note: "Visible in current view"),
                    sessionCard(title: "Infra Session 3", subtitle: "Infra · 13:00-13:30", detail: "Shared infrastructure and deployment patterns.", note: "Recommended next")
                ]),
                "savedSessions": .list([
                    timelineCard(title: "Opening keynote", subtitle: "Main stage · 08:30", detail: "Framing digital independence across sectors.", note: "Saved"),
                    timelineCard(title: "Shared relations roundtable", subtitle: "Studio 2 · 11:15", detail: "Operational follow-up between ecosystem teams.", note: "Saved")
                ]),
                "timelineSessions": .list([
                    timelineCard(title: "Governance Session 3", subtitle: "Studio 2 · 08:00", detail: "Governance, AI and digital independence.", note: "Visible in timeline"),
                    timelineCard(title: "Identity Session 2", subtitle: "Hall B · 08:30", detail: "Identity, AI and digital independence.", note: "Visible in timeline"),
                    timelineCard(title: "Governance Session 9", subtitle: "Bridge · 09:00", detail: "Cross-team governance patterns.", note: "Visible in timeline")
                ])
            ]),
            "matches": .object([
                "intro": .string("Disse personene matcher formålene og interessene dine akkurat nå."),
                "filterSummary": .string("Filter: \(currentFilter)."),
                "status": .string("Anbefalinger er oppdatert og klare for review."),
                "recommendationSummary": .string("4 høy-signal personer matcher målene dine."),
                "searchSummary": .string("Siste søk: \(searchQuery)."),
                "recommendations": .list([
                    recommendationCard(title: "Ane Solberg", subtitle: "Public sector interoperability", detail: "Sterk match på governance og gjennomføring.", note: "92% match"),
                    recommendationCard(title: "Mads Hovden", subtitle: "Policy and compliance", detail: "Jobber med claims, trust og organisering.", note: "88% match"),
                    recommendationCard(title: "Lea Heger", subtitle: "Digital service design", detail: "Kan koble programmet til konkrete produktvalg.", note: "84% match")
                ]),
                "searchResults": .list([
                    connectionCard(title: "Governance Forum", subtitle: "Nearby people", detail: "Fant deltakere som nevner \(searchQuery.lowercased()).", note: "Lokal preview"),
                    connectionCard(title: "Trust Infrastructure Lab", subtitle: "Shared interests", detail: "Samme fokus på tillit, claims og drift.", note: "Suggested follow-up")
                ])
            ]),
            "meetings": .object([
                "intro": .string("Møteplanlegging holdes i participant-shellen for lav friksjon."),
                "requestSummary": .string(requestSummary),
                "slotSummary": .string("5 overlappende slotter passer med agendaen din."),
                "meetingSummary": .string(meetingSummary),
                "chatSummary": .string("2 chats er klare for møterelevant oppfølging."),
                "exportStatus": .string(exportStatus),
                "requests": .list([
                    timelineCard(title: "Governance follow-up", subtitle: "Pending", detail: "Venter på svar fra kommunal plattformgruppe.", note: "Participant shell"),
                    timelineCard(title: "Interop sync", subtitle: "Pending", detail: "Forslått kort sync etter lunsj.", note: "Participant shell")
                ]),
                "confirmedMeetings": .list([
                    timelineCard(title: "Coordination with municipal platform team", subtitle: "10:30", detail: "Kort sync om felles styringsmodell.", note: "Confirmed"),
                    timelineCard(title: "Shared trust registry", subtitle: "14:15", detail: "Oppfølging på trust registry og claims.", note: "Confirmed")
                ])
            ]),
            "sharedConnections": .object([
                "intro": .string("Shared relations gjør det enkelt å fortsette riktige samtaler."),
                "accessSummary": .string("Shared threads er synlige for partene som deltar i relasjonen."),
                "agreementBoundary": .string("Bare policy-godkjent oppfølging deles videre."),
                "connectionSummary": .string("2 aktive relasjoner og 1 sovende forbindelse."),
                "requestSummary": .string(requestSummary),
                "meetingSummary": .string(meetingSummary),
                "chatSummary": .string("\(activeChatCount) aktive oppfølgingstråder er klare."),
                "connections": .list(([
                    connectionCard(title: "Digital Governance Forum", subtitle: "Shared contact", detail: "Felles oppfølging på offentlig samordning.", note: "Warm"),
                    connectionCard(title: "Trust Infrastructure Lab", subtitle: "Meeting collaborator", detail: "Tidligere møte koblet til ny oppfølging.", note: "Active")
                ] + dynamicNearbyConnections).map { $0 }),
                "confirmedMeetings": .list([
                    timelineCard(title: "Morning follow-up", subtitle: "11:45", detail: "Møt teamet bak delte relasjoner og drift.", note: "Shared connection")
                ]),
                "recentMessages": .list(recentMessages)
            ])
        ]
    }

    private func discoveryTargetNames(from payload: ValueType) -> [String] {
        guard case let .object(payloadObject) = payload else { return [] }
        if case let .list(targets)? = payloadObject["targets"] {
            let names = targets.compactMap { target -> String? in
                guard case let .object(targetObject) = target else { return nil }
                if case let .string(displayName)? = targetObject["displayName"],
                   displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if case let .string(participantId)? = targetObject["participantId"],
                   participantId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return participantId.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }
            if names.isEmpty == false {
                return names
            }
        }
        if case let .list(participantIds)? = payloadObject["participantIds"] {
            return participantIds.compactMap { value in
                guard case let .string(raw) = value else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        return []
    }

    private func viewLabel(_ view: String) -> String {
        switch view {
        case "timeline": return "Timeline"
        case "saved": return "Lagrede sesjoner"
        default: return "For deg"
        }
    }

    private func timelineSummaryText(for view: String) -> String {
        switch view {
        case "timeline":
            return "Timeline-visningen viser programmet kronologisk med fokus på neste trekk."
        case "saved":
            return "Lagret-visningen viser bare sesjoner du allerede har valgt."
        default:
            return "For deg-visningen prioriterer det som passer formålene dine best."
        }
    }

    private func trackLabel(_ trackID: String) -> String {
        switch trackID {
        case "track-governance": return "Governance"
        case "track-identity": return "Identity"
        default: return "Konferansesporet"
        }
    }

    private func sessionCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note)
        ])
    }

    private func recommendationCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        sessionCard(title: title, subtitle: subtitle, detail: detail, note: note)
    }

    private func timelineCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        sessionCard(title: title, subtitle: subtitle, detail: detail, note: note)
    }

    private func connectionCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        sessionCard(title: title, subtitle: subtitle, detail: detail, note: note)
    }
}

private final class ConferenceAdminPreviewShellLocalFallbackCell: GeneralCell {
    private var draftPublished = false
    private var discardedDraft = false
    private var lastEditSummary = "Redaktørutkastet er klart for gjennomgang."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, _ in
            guard let self else { return .string("failure") }
            return .object(self.makeStateObject())
        })
        await addInterceptForGet(requester: owner, key: "skeletonConfiguration", getValueIntercept: { _, _ in
            .null
        })
        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, _ in
            guard let self else { return .string("failure") }
            return await self.handleDispatchAction(value)
        })
    }

    private func handleDispatchAction(_ value: ValueType) async -> ValueType {
        guard case let .object(object) = value,
              case let .string(actionKeypath)? = object["keypath"] else {
            return .string("error: invalid action payload")
        }

        switch actionKeypath {
        case "contentPublishing.publishDraft":
            draftPublished = true
            discardedDraft = false
            lastEditSummary = "Utkastet ble publisert i lokal organizer-preview."
        case "contentPublishing.discardDraft":
            draftPublished = false
            discardedDraft = true
            lastEditSummary = "Utkastet ble forkastet i lokal organizer-preview."
        default:
            lastEditSummary = "Utførte \(actionKeypath) i lokal organizer-preview."
        }

        return .object([
            "status": .string("ok"),
            "state": .object(makeStateObject())
        ])
    }

    private func makeStateObject() -> Object {
        let contentStatus: String
        let draftWarning: String
        let nextAction: String
        let draftTracks: [ValueType]
        let draftSessions: [ValueType]

        if draftPublished {
            contentStatus = "Draft publisert og klar for offentlig shell."
            draftWarning = "Ingen ventende redaktøradvarsler."
            nextAction = "Overvåk publisert innhold og oppdater run-of-show ved behov."
            draftTracks = []
            draftSessions = []
        } else if discardedDraft {
            contentStatus = "Draft forkastet. Ny redaksjonell runde kreves."
            draftWarning = "Redaktørutkastet er fjernet fra publiseringskøen."
            nextAction = "Opprett et nytt draft før du går videre."
            draftTracks = []
            draftSessions = []
        } else {
            contentStatus = "Draft klart for review og publisering."
            draftWarning = "Utkastet må sjekkes mot run-of-show før publisering."
            nextAction = "Publiser dagens draft når speaker- og facilities-noter er godkjent."
            draftTracks = [
                timelineCard(title: "Governance", subtitle: "Draft track", detail: "Klar for publisering med oppdatert ingress.", note: "Preview"),
                timelineCard(title: "Identity", subtitle: "Draft track", detail: "Claims og trust-sporet er oppdatert.", note: "Preview")
            ]
            draftSessions = [
                timelineCard(title: "Opening keynote", subtitle: "Draft session", detail: "Speaker-bio og ingress er klare.", note: "Pending publish"),
                timelineCard(title: "Shared relations roundtable", subtitle: "Draft session", detail: "Room og moderator er oppdatert.", note: "Pending publish")
            ]
        }

        return [
            "workspace": .object([
                "title": .string("Conference Control Tower"),
                "subtitle": .string("Organizer-visning for eierskap, publisering, drift og innsikt."),
                "conferenceBadge": .string("Conference owner"),
                "opsBadge": .string("Ops ready"),
                "nextAction": .string(nextAction),
                "previewNotice": .string("Lokal organizer-preview brukes mens staging-preview er i flux. Contract og mørk UI holdes like.")
            ]),
            "access": .object([
                "headline": .string("Organizer access og ansvar"),
                "ownerScope": .string("Owner scope: conference entity og organizer VC."),
                "readScope": .string("Read scope: admin-shell, public-shell og sponsor handoff."),
                "writeScope": .string("Write scope: programdraft, alerts, ops og content publishing."),
                "deliveryScope": .string("Delivery scope: preview shells og publiserte conference views."),
                "storageScope": .string("Storage scope: organizer notes, publishing queue og metrics."),
                "notes": .string("Access-kontrakten er den samme som i CellScaffold; denne previewen er bare lokal fallback."),
                "keypathMatrix": .list([
                    timelineCard(title: "conferenceAdminShell.state.*", subtitle: "Read/write", detail: "Organizer shell kontrakt", note: "Allowed"),
                    timelineCard(title: "conferencePublicShell.state.*", subtitle: "Read + publish", detail: "Publisert view for attendees", note: "Allowed"),
                    timelineCard(title: "conferenceSponsorShell.state.*", subtitle: "Read handoff", detail: "Sponsor view og leads", note: "Scoped")
                ])
            ]),
            "content": .object([
                "intro": .string("Control Tower samler redaksjonelle drafts og publiseringsstatus i én organizerflate."),
                "editorScope": .string("Editor scope: tracks, sessions, people, facilities og articles."),
                "lifecycleSummary": .string("Draft -> review -> publish -> public shell."),
                "status": .string(contentStatus),
                "lastEditSummary": .string(lastEditSummary),
                "draftWarning": .string(draftWarning),
                "preview": .object([
                    "programSummary": .string("Program preview er konsistent med dagens run-of-show."),
                    "trackSummary": .string("2 draft tracks er klare til review."),
                    "sessionSummary": .string("2 draft sessions venter på siste godkjenning."),
                    "facilitySummary": .string("Venue- og room-data er på plass."),
                    "peopleSummary": .string("Speaker cards er klare for publisering."),
                    "articleSummary": .string("Landing-artikkel og agenda-artikkel er synkronisert.")
                ]),
                "draftTracks": .list(draftTracks),
                "draftSessions": .list(draftSessions)
            ]),
            "operations": .object([
                "intro": .string("Driftsbildet viser run-of-show og eventuelle operative avvik."),
                "runOfShow": .list([
                    titleDetailCard(title: "Doors open", detail: "07:45 · crew ready"),
                    titleDetailCard(title: "Opening keynote", detail: "08:30 · green room confirmed"),
                    titleDetailCard(title: "Networking lunch", detail: "12:00 · facilities synced")
                ]),
                "alerts": .list([
                    titleDetailCard(title: "Room B overlap", detail: "Session 2 and workshop share setup crew"),
                    titleDetailCard(title: "Badge printer", detail: "One printer reports intermittent connectivity")
                ])
            ]),
            "insights": .object([
                "dashboardSummary": .string("Dashboarden viser attendance, consent og topic-trender."),
                "consentSummary": .string("Consent coverage holder seg over demo-terskelen."),
                "aggregateBoundary": .string("Aggregater er avgrenset til policy-godkjent organizer scope."),
                "chartDirection": .string("Momentum peker oppover for governance og identity."),
                "status": .string("Insights er oppdatert for denne preview-runden."),
                "exportStatus": .string("Eksportpakke er klar til bruk når ønsket."),
                "kpis": .list([
                    titleDetailCard(title: "Registrations", detail: "412 confirmed"),
                    titleDetailCard(title: "Meetings booked", detail: "87 across participant shell"),
                    titleDetailCard(title: "Shared threads", detail: "26 active")
                ]),
                "topicTrends": .list([
                    titleDetailCard(title: "Governance", detail: "Trending up"),
                    titleDetailCard(title: "Identity", detail: "Stable high interest"),
                    titleDetailCard(title: "Trust infrastructure", detail: "Strong cross-track pull")
                ])
            ]),
            "sponsor": .object([
                "dashboardSummary": .string("Sponsor handoff er klar og følger organizer-policy."),
                "engagementSummary": .string("Lead engagement viser god overgang til sponsor-shell."),
                "handoffSummary": .string("3 varme leads er klare for videre sponsor-oppfølging."),
                "leadCandidates": .list([
                    timelineCard(title: "Municipal platform team", subtitle: "Warm lead", detail: "Governance + identity overlap.", note: "Ready for sponsor handoff"),
                    timelineCard(title: "Trust infrastructure lab", subtitle: "Warm lead", detail: "Shared interest in claims and verification.", note: "Ready for sponsor handoff")
                ])
            ])
        ]
    }

    private func timelineCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note)
        ])
    }

    private func titleDetailCard(title: String, detail: String) -> ValueType {
        .object([
            "title": .string(title),
            "detail": .string(detail)
        ])
    }
}
