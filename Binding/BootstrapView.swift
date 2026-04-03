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
    private static let warmupEndpointTimeoutNanoseconds: UInt64 = 1_200_000_000
    private static let warmupStateTimeoutNanoseconds: UInt64 = 1_200_000_000
    private static let safeConferenceWarmupEndpoints: [String] = [
        "cell:///ConferenceParticipantPreviewShell",
        "cell:///ConferenceParticipantAgendaSnapshot",
        "cell:///ConferenceParticipantDiscoverySnapshot",
        "cell:///ConferenceParticipantMatchmakingSnapshot",
        "cell:///ConferenceNearbyRadar",
        "cell:///ConferenceParticipantChatSnapshot",
        "cell:///ConferenceAdminPreviewShell",
        "cell:///ConferenceAIAssistantGatewayProxy",
    ]

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

    func warmConferenceRuntime(requester: Identity? = nil) async {
        await ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            return
        }

        let effectiveRequester: Identity?
        if let requester {
            effectiveRequester = requester
        } else {
            effectiveRequester = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true)
        }

        guard let effectiveRequester else {
            return
        }

        for endpoint in Self.safeConferenceWarmupEndpoints {
            guard let meddle = try? await Self.resolveWarmupMeddle(
                endpoint: endpoint,
                resolver: resolver,
                requester: effectiveRequester
            ) else {
                continue
            }

            _ = try? await Self.readStateForWarmup(
                from: meddle,
                requester: effectiveRequester
            )
        }
    }

    private static func resolveWarmupMeddle(
        endpoint: String,
        resolver: CellResolver,
        requester: Identity
    ) async throws -> Meddle {
        try await withThrowingTaskGroup(of: Meddle.self) { group in
            group.addTask {
                guard let meddle = try await resolver.cellAtEndpoint(
                    endpoint: endpoint,
                    requester: requester
                ) as? Meddle else {
                    throw WarmupEndpointResolutionError(endpoint: endpoint)
                }
                return meddle
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.warmupEndpointTimeoutNanoseconds)
                throw WarmupEndpointTimeoutError(endpoint: endpoint)
            }

            guard let firstResult = try await group.next() else {
                throw WarmupEndpointTimeoutError(endpoint: endpoint)
            }
            group.cancelAll()
            return firstResult
        }
    }

    private static func readStateForWarmup(
        from meddle: Meddle,
        requester: Identity
    ) async throws -> ValueType {
        try await withThrowingTaskGroup(of: ValueType.self) { group in
            group.addTask {
                try await meddle.get(keypath: "state", requester: requester)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.warmupStateTimeoutNanoseconds)
                throw WarmupStateTimeoutError()
            }

            guard let firstResult = try await group.next() else {
                throw WarmupStateTimeoutError()
            }
            group.cancelAll()
            return firstResult
        }
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
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantPreviewShellLocalFallbackCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceAdminPreviewShell",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceAdminPreviewShellLocalFallbackCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceNearbyRadar",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceNearbyRadarLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantAgendaSnapshot",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantAgendaSnapshotLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantDiscoverySnapshot",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantDiscoverySnapshotLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantMatchmakingSnapshot",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantMatchmakingSnapshotLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantChatSnapshot",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantChatSnapshotLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceIdentityLinkIntake",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceIdentityLinkIntakeCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceAIAssistantGatewayProxy",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceAIAssistantGatewayProxyCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceDemoLauncher",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceDemoLauncherLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "Lobby",
            cellScope: .scaffoldUnique,
            identityDomain: "private",
            type: GeneralCell.self,
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

private struct WarmupStateTimeoutError: LocalizedError {
    var errorDescription: String? {
        "Conference runtime warmup timed out while reading state."
    }
}

private struct WarmupEndpointTimeoutError: LocalizedError {
    let endpoint: String

    var errorDescription: String? {
        "Conference runtime warmup timed out while resolving \(endpoint)."
    }
}

private struct WarmupEndpointResolutionError: LocalizedError {
    let endpoint: String

    var errorDescription: String? {
        "Conference runtime warmup could not resolve meddle at \(endpoint)."
    }
}

private enum ConferenceSnapshotRetrySupport {
    private static let retryableFragments: [String] = [
        "ikke tilgjengelig",
        "kunne ikke",
        "notfound",
        "denied",
        "timeout",
        "finishedwithoutvalue",
        "siste stabile snapshot",
        "siste lokale snapshot",
        "beholdt siste stabile snapshot"
    ]

    static func shouldRetryImmediately(
        cachedState: Object,
        statusKeys: [String]
    ) -> Bool {
        statusKeys.contains { key in
            containsRetryableFailure(cachedState[key])
        }
    }

    private static func containsRetryableFailure(_ value: ValueType?) -> Bool {
        guard case let .string(text)? = value else {
            return false
        }

        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            return false
        }

        return retryableFragments.contains(where: normalized.contains)
    }
}

private final class ConferenceAIAssistantGatewayProxyCell: GeneralCell {
    private static let localGatewayEndpoint = "cell:///AIGateway"
    private static let stagingGatewayEndpoint = "cell://staging.haven.digipomps.org/AIGateway"
    private var pendingAPIKeyEntry = ""

    private static let readableKeys = [
        "state",
        "contracts",
        "purposeGoal",
        "configuration",
        "skeletonConfiguration"
    ]
    private static let writableKeys = [
        "applyDraftProfile",
        "setDraftPrompt",
        "setDraftSystemPrompt",
        "setDraftProviderID",
        "setDraftModel",
        "setDraftBaseURL",
        "setDraftAPIKeyAlias",
        "setDraftTemperatureText",
        "setDraftMaxTokensText",
        "setDraftDeterministicMode",
        "setDraftRequiresAPIKey",
        "setDraftAPIKeyEntry",
        "commitDraftAPIKeyEntry",
        "setDraftAPIKey",
        "clearDraftAPIKey",
        "persistDraftAPIKey",
        "invokeDraft",
        "ai.invoke",
        "invokeAI"
    ]

    required init(owner: Identity) async {
        await super.init(owner: owner)
        Self.readableKeys.forEach { agreementTemplate.addGrant("r---", for: $0) }
        Self.writableKeys.forEach { agreementTemplate.addGrant("rw--", for: $0) }

        for key in Self.readableKeys {
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                return await self.forwardGet(keypath: key, requester: requester)
            }
        }

        for key in Self.writableKeys {
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
                return await self.forwardSet(keypath: key, value: value, requester: requester)
            }
        }
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func resolveGateway(requester: Identity) async throws -> Meddle {
        await BindingRuntimeBootstrap.ensureBaseline()
        await BindingLocalCellRegistration.shared.ensureRegistered()
        guard let resolver = CellBase.defaultCellResolver else {
            throw CellBaseError.noResolver
        }

        for endpoint in [Self.localGatewayEndpoint, Self.stagingGatewayEndpoint] {
            if let gateway = try? await resolver.cellAtEndpoint(
                endpoint: endpoint,
                requester: requester
            ) as? Meddle {
                return gateway
            }
        }

        throw CellBaseError.noTargetCell
    }

    private func forwardGet(keypath: String, requester: Identity) async -> ValueType {
        do {
            let gateway = try await resolveGateway(requester: requester)
            let value = try await gateway.get(keypath: keypath, requester: requester)
            if keypath == "state" {
                return augmentGatewayState(value)
            }
            return value
        } catch {
            return .string("Conference AI gateway proxy get failed: \(error)")
        }
    }

    private func forwardSet(keypath: String, value: ValueType, requester: Identity) async -> ValueType {
        do {
            let gateway = try await resolveGateway(requester: requester)

            switch keypath {
            case "setDraftAPIKeyEntry":
                pendingAPIKeyEntry = conferenceMutationString(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let state = try await gateway.get(keypath: "state", requester: requester)
                return augmentGatewayState(state)
            case "commitDraftAPIKeyEntry":
                let response = try await gateway.set(
                    keypath: "setDraftAPIKey",
                    value: .string(pendingAPIKeyEntry),
                    requester: requester
                )
                let stateValue: ValueType
                if let response {
                    stateValue = response
                } else {
                    stateValue = try await gateway.get(keypath: "state", requester: requester)
                }
                return augmentGatewayState(stateValue)
            case "persistDraftAPIKey", "invokeDraft":
                if pendingAPIKeyEntry.isEmpty == false {
                    _ = try await gateway.set(
                        keypath: "setDraftAPIKey",
                        value: .string(pendingAPIKeyEntry),
                        requester: requester
                    )
                }
            case "clearDraftAPIKey":
                pendingAPIKeyEntry = ""
            case "setDraftAPIKey":
                pendingAPIKeyEntry = conferenceMutationString(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            default:
                break
            }

            if let response = try await gateway.set(keypath: keypath, value: value, requester: requester) {
                return augmentGatewayState(response)
            }
            return augmentGatewayState(try await gateway.get(keypath: "state", requester: requester))
        } catch {
            return .string("Conference AI gateway proxy set failed: \(error)")
        }
    }

    private func augmentGatewayState(_ value: ValueType) -> ValueType {
        guard case let .object(initialRootObject) = value else {
            return value
        }

        var rootObject: Object = initialRootObject
        guard case let .object(existingSetup)? = rootObject["setup"] else {
            return value
        }

        var setupObject: Object = existingSetup
        let pendingEntryPresent = pendingAPIKeyEntry.isEmpty == false
        setupObject["pendingEntryPresent"] = .bool(pendingEntryPresent)
        setupObject["pendingEntryStatus"] = .string(
            pendingEntryPresent
                ? "A local session key is buffered in this field. Invoke and Save API key will load it automatically."
                : ""
        )
        rootObject["setup"] = .object(setupObject)
        return .object(rootObject)
    }
}

private func conferenceMutationString(from value: ValueType?) -> String? {
    guard let value else { return nil }
    switch value {
    case let .string(string):
        return string
    case let .integer(integer):
        return String(integer)
    case let .number(number):
        return String(number)
    case let .float(float):
        return String(float)
    case let .bool(bool):
        return bool ? "true" : "false"
    default:
        return nil
    }
}

private func conferenceMutationErrorDescription(from value: ValueType?) -> String? {
    guard let value else { return "Ukjent conference-feil." }
    switch value {
    case let .string(string):
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let normalized = trimmed.lowercased()
        if normalized == "denied"
            || normalized == "notfound"
            || normalized == "not found"
            || normalized == "timeout"
            || normalized == "finishedwithoutvalue"
            || normalized.hasPrefix("error:")
            || normalized.hasPrefix("failure")
            || normalized.contains("notfound")
            || normalized.contains("finishedwithoutvalue") {
            return trimmed
        }
        return nil
    case let .object(object):
        if let status = conferenceMutationString(from: object["status"])?.lowercased(),
           ["error", "denied", "notfound", "timeout", "finishedwithoutvalue"].contains(status),
           let message = conferenceMutationString(from: object["message"]) {
            return message
        }
        if let error = conferenceMutationString(from: object["error"])?.trimmingCharacters(in: .whitespacesAndNewlines),
           error.isEmpty == false {
            return error
        }
        return nil
    default:
        return nil
    }
}

private func conferenceSharedConnectionNames(from sharedConnections: Object?) -> [String] {
    guard case let .list(values)? = sharedConnections?["connections"] else {
        return []
    }

    return values.compactMap { value in
        guard case let .object(object) = value else { return nil }
        let raw = conferenceMutationString(from: object["title"])
            ?? conferenceMutationString(from: object["displayName"])
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func conferenceObject(from value: ValueType?) -> Object? {
    guard case let .object(object)? = value else {
        return nil
    }
    return object
}

private func conferenceActionKeypath(from value: ValueType?) -> String? {
    guard case let .object(object)? = value,
          case let .string(keypath)? = object["keypath"] else {
        return nil
    }
    return keypath
}

private func conferenceActionPayload(from value: ValueType?) -> ValueType? {
    guard case let .object(object)? = value else {
        return nil
    }
    return object["payload"]
}

private struct ConferenceParticipantPreviewFallbackState {
    var agendaView = "forYou"
    var activeTrackID = "all"
    var currentFilter = "All recommended people"
    var pendingRequestCount = 0
    var confirmedMeetingCount = 0
    var exportPrepared = false
    var searchQuery = "people"
    var recentMessages: [ConferenceParticipantPreviewFallbackMessage] = []
    var launchedDiscoveryChatNames: [String] = []
    var focusedRecommendationName: String?
    var followUpMarkedNames = Set<String>()
    var recentActionSummary = "Participant preview is running locally in Binding because the staging preview was denied."
}

private struct ConferenceParticipantPreviewFallbackMessage: Equatable {
    var title: String
    var subtitle: String
    var detail: String
    var note: String

    var value: ValueType {
        .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note)
        ])
    }
}

private struct ConferenceDemoPersona {
    var name: String
    var roleSummary: String
    var publicProfileDetail: String
    var fitContext: String
    var conversationStyle: String
    var suggestedOpening: String
    var simulatedAgentSummary: String
}

private struct ConferenceDemoPersonaSeed {
    var name: String?
    var roleSummary: String?
    var publicProfileDetail: String?
    var fitContext: String?
    var conversationStyle: String?
    var suggestedOpening: String?
    var simulatedAgentSummary: String?
    var starterReply: String?
}

private struct ConferenceDemoPersonaProvider {
    func persona(named rawName: String?, source sourceObject: Object? = nil) -> ConferenceDemoPersona {
        let fallback = fallbackPersona(named: rawName)
        guard let seed = seed(from: sourceObject) else {
            return fallback
        }

        return ConferenceDemoPersona(
            name: nonEmpty(seed.name) ?? fallback.name,
            roleSummary: nonEmpty(seed.roleSummary) ?? fallback.roleSummary,
            publicProfileDetail: nonEmpty(seed.publicProfileDetail) ?? fallback.publicProfileDetail,
            fitContext: nonEmpty(seed.fitContext) ?? fallback.fitContext,
            conversationStyle: nonEmpty(seed.conversationStyle) ?? fallback.conversationStyle,
            suggestedOpening: nonEmpty(seed.suggestedOpening) ?? fallback.suggestedOpening,
            simulatedAgentSummary: nonEmpty(seed.simulatedAgentSummary) ?? fallback.simulatedAgentSummary
        )
    }

    func starterReply(named rawName: String?, source sourceObject: Object? = nil) -> String {
        if let starterReply = nonEmpty(seed(from: sourceObject)?.starterReply) {
            return starterReply
        }
        let persona = persona(named: rawName, source: sourceObject)
        return "Ja, gjerne. \(persona.publicProfileDetail) Hvis du vil, kan vi ta et kort neste steg etter sesjonen."
    }

    func seedObject(named rawName: String?) -> Object {
        let persona = fallbackPersona(named: rawName)
        return [
            "name": .string(persona.name),
            "roleSummary": .string(persona.roleSummary),
            "publicProfileDetail": .string(persona.publicProfileDetail),
            "fitContext": .string(persona.fitContext),
            "conversationStyle": .string(persona.conversationStyle),
            "suggestedOpening": .string(persona.suggestedOpening),
            "simulatedAgentSummary": .string(persona.simulatedAgentSummary),
            "starterReply": .string("Ja, gjerne. \(persona.publicProfileDetail) Hvis du vil, kan vi ta et kort neste steg etter sesjonen.")
        ]
    }

    private func seed(from sourceObject: Object?) -> ConferenceDemoPersonaSeed? {
        let nested = object(from: sourceObject?["demoPersona"])
        let raw = nested ?? sourceObject

        let seed = ConferenceDemoPersonaSeed(
            name: nonEmpty(string(from: raw?["name"])),
            roleSummary: nonEmpty(string(from: raw?["roleSummary"])),
            publicProfileDetail: nonEmpty(string(from: raw?["publicProfileDetail"])),
            fitContext: nonEmpty(string(from: raw?["fitContext"])),
            conversationStyle: nonEmpty(string(from: raw?["conversationStyle"])),
            suggestedOpening: nonEmpty(string(from: raw?["suggestedOpening"])),
            simulatedAgentSummary: nonEmpty(string(from: raw?["simulatedAgentSummary"])),
            starterReply: nonEmpty(string(from: raw?["starterReply"]))
        )

        let hasSeedValues =
            seed.name != nil ||
            seed.roleSummary != nil ||
            seed.publicProfileDetail != nil ||
            seed.fitContext != nil ||
            seed.conversationStyle != nil ||
            seed.suggestedOpening != nil ||
            seed.simulatedAgentSummary != nil ||
            seed.starterReply != nil

        return hasSeedValues ? seed : nil
    }

    private func fallbackPersona(named rawName: String?) -> ConferenceDemoPersona {
        conferenceFallbackDemoPersona(named: rawName)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(string):
            return string
        case let .integer(integer):
            return String(integer)
        case let .number(number):
            return String(number)
        case let .float(float):
            return String(float)
        case let .bool(bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private func object(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }
}

private let conferenceDemoPersonaProvider = ConferenceDemoPersonaProvider()

private func conferenceFallbackDemoPersona(named rawName: String?) -> ConferenceDemoPersona {
    let name = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    switch name {
    case "Ane Solberg":
        return ConferenceDemoPersona(
            name: "Ane Solberg",
            roleSummary: "Public sector interoperability",
            publicProfileDetail: "Jobber med offentlig samhandling, interoperabilitet og styring på tvers av virksomheter.",
            fitContext: "Sterk på governance, leveranse og offentlig koordinering.",
            conversationStyle: "Kort, konkret og opptatt av hva som faktisk kan følges opp etter sesjonen.",
            suggestedOpening: "Hei Ane. Jeg vil gjerne snakke mer om governance-sporet og hvordan du jobber med interoperabilitet i praksis.",
            simulatedAgentSummary: "Demo-svarene holder seg til en bounded persona som representerer offentlig samhandling og governance."
        )
    case "Mads Hovden":
        return ConferenceDemoPersona(
            name: "Mads Hovden",
            roleSummary: "Policy and compliance",
            publicProfileDetail: "Jobber med policy, etterlevelse og hvordan claims og tillit kan forankres organisatorisk.",
            fitContext: "Sterk på policy, claims og operativ compliance.",
            conversationStyle: "Svarene er strukturerte og dreier raskt inn mot ansvar, policy og beslutningsløp.",
            suggestedOpening: "Hei Mads. Jeg vil gjerne høre hvordan du kobler policy og claims til konkrete driftsvalg.",
            simulatedAgentSummary: "Demo-svarene holder seg til en bounded persona som representerer policy, claims og compliance."
        )
    case "Lea Heger":
        return ConferenceDemoPersona(
            name: "Lea Heger",
            roleSummary: "Digital service design",
            publicProfileDetail: "Kobler konferansens temaer til tjenestedesign, produktvalg og tydelige brukerforløp.",
            fitContext: "Sterk på oversettelsen fra strategi til faktisk tjenesteopplevelse.",
            conversationStyle: "Svarene er brukerorienterte og prøver å gjøre neste steg konkret og forståelig.",
            suggestedOpening: "Hei Lea. Jeg vil gjerne høre hvordan du ville oversatt governance-sporet til konkrete tjenestevalg.",
            simulatedAgentSummary: "Demo-svarene holder seg til en bounded persona som representerer tjenestedesign og produktnær oppfølging."
        )
    case "Nora Berg":
        return ConferenceDemoPersona(
            name: "Nora Berg",
            roleSummary: "Trust infrastructure",
            publicProfileDetail: "Jobber med tillit, relasjoner og hvordan identitet og oppfølging kan flyte mellom team.",
            fitContext: "Sterk på tillit, samarbeid og relasjonell oppfølging.",
            conversationStyle: "Svarene er varme og samarbeidsorienterte, men prøver raskt å lande neste steg.",
            suggestedOpening: "Hei Nora. Jeg tror vi har overlapp på trust og oppfølging. Har du tid til en kort prat etter neste sesjon?",
            simulatedAgentSummary: "Demo-svarene holder seg til en bounded persona som representerer tillit, relasjoner og oppfølging."
        )
    default:
        let fallbackName = name.isEmpty ? "Konferansekontakt" : name
        return ConferenceDemoPersona(
            name: fallbackName,
            roleSummary: "Conference follow-up",
            publicProfileDetail: "Representerer en generell konferansedeltager med offentlig profil og tydelig oppfølgingskontekst.",
            fitContext: "Relevant for videre conference-oppfølging.",
            conversationStyle: "Svarene er korte og forsøker å lande et konkret neste steg.",
            suggestedOpening: "Hei. Jeg tror vi har relevant overlapp og vil gjerne ta en kort oppfølgingsprat etter neste sesjon.",
            simulatedAgentSummary: "Demo-svarene holder seg til en bounded konferansepersona, ikke fri generativ improvisasjon."
        )
    }
}

private func conferenceDemoPersona(named rawName: String?, source sourceObject: Object? = nil) -> ConferenceDemoPersona {
    conferenceDemoPersonaProvider.persona(named: rawName, source: sourceObject)
}

private func conferenceDemoPersonaSeedObject(named rawName: String?) -> Object {
    conferenceDemoPersonaProvider.seedObject(named: rawName)
}

private func conferenceDemoReply(
    to message: String,
    persona: ConferenceDemoPersona,
    priorTurns: Int
) -> String {
    let lowered = message.lowercased()
    if lowered.contains("governance") {
        return priorTurns > 0
            ? "Ja, governance er fortsatt mest relevant for meg. Hvis du vil, kan vi gjøre det konkret og se på neste steg rett etter sesjonen."
            : "Ja, gjerne. Governance er også mitt hovedspor. Jeg kan ta 10 minutter etter neste sesjon."
    }
    if lowered.contains("interoperabilitet") || lowered.contains("interop") {
        return "\(persona.name) her: det er også der jeg bruker mest tid nå. Jeg tror vi kan få en god prat hvis vi gjør det konkret rundt samhandling og ansvar."
    }
    if lowered.contains("sesjon") || lowered.contains("session") {
        return "Det passer bra. Jeg blir igjen etter neste sesjon, så vi kan ta praten da."
    }
    if lowered.contains("møte") || lowered.contains("meeting") {
        return "Ja, la oss gjøre det konkret. Jeg har et lite vindu etter lunsj om det passer."
    }
    return "Takk. Dette ser relevant ut for meg også, så vi kan gjerne følge opp videre. \(persona.conversationStyle)"
}

private func conferenceDemoStarterMessage(for persona: ConferenceDemoPersona) -> String {
    persona.suggestedOpening
}

private func conferenceDemoStarterReply(for persona: ConferenceDemoPersona, source sourceObject: Object? = nil) -> String {
    conferenceDemoPersonaProvider.starterReply(named: persona.name, source: sourceObject)
}

actor ConferenceParticipantPreviewFallbackStateStore {
    static let shared = ConferenceParticipantPreviewFallbackStateStore()
    private static let maximumRetainedOwners = 12
    private static let memoryPressureRetainedOwners = 4

    private var statesByOwnerUUID: [String: ConferenceParticipantPreviewFallbackState] = [:]
    private var ownerRecency: [String] = []

    fileprivate func load(for ownerUUID: String) -> ConferenceParticipantPreviewFallbackState? {
        guard let state = statesByOwnerUUID[ownerUUID] else {
            return nil
        }
        touch(ownerUUID)
        return state
    }

    fileprivate func save(_ state: ConferenceParticipantPreviewFallbackState, for ownerUUID: String) {
        statesByOwnerUUID[ownerUUID] = state
        touch(ownerUUID)
        trimIfNeeded(limit: Self.maximumRetainedOwners)
    }

    func reset(for ownerUUID: String) {
        statesByOwnerUUID.removeValue(forKey: ownerUUID)
        ownerRecency.removeAll { $0 == ownerUUID }
    }

    func handleMemoryPressure() {
        trimIfNeeded(limit: Self.memoryPressureRetainedOwners)
    }

    private func touch(_ ownerUUID: String) {
        ownerRecency.removeAll { $0 == ownerUUID }
        ownerRecency.append(ownerUUID)
    }

    private func trimIfNeeded(limit: Int) {
        guard ownerRecency.count > limit else { return }
        let staleOwners = ownerRecency.prefix(ownerRecency.count - limit)
        for ownerUUID in staleOwners {
            statesByOwnerUUID.removeValue(forKey: ownerUUID)
        }
        ownerRecency = Array(ownerRecency.suffix(limit))
    }
}

actor ConferenceParticipantSelectionStore {
    static let shared = ConferenceParticipantSelectionStore()
    private static let maximumRetainedOwners = 12
    private static let memoryPressureRetainedOwners = 4

    private var selectedParticipantByOwnerUUID: [String: String] = [:]
    private var ownerRecency: [String] = []

    func load(for ownerUUID: String) -> String? {
        guard let selection = selectedParticipantByOwnerUUID[ownerUUID] else {
            return nil
        }
        touch(ownerUUID)
        return selection
    }

    func save(_ displayName: String?, for ownerUUID: String) {
        guard let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            selectedParticipantByOwnerUUID.removeValue(forKey: ownerUUID)
            ownerRecency.removeAll { $0 == ownerUUID }
            return
        }
        selectedParticipantByOwnerUUID[ownerUUID] = trimmed
        touch(ownerUUID)
        trimIfNeeded(limit: Self.maximumRetainedOwners)
    }

    func handleMemoryPressure() {
        trimIfNeeded(limit: Self.memoryPressureRetainedOwners)
    }

    private func touch(_ ownerUUID: String) {
        ownerRecency.removeAll { $0 == ownerUUID }
        ownerRecency.append(ownerUUID)
    }

    private func trimIfNeeded(limit: Int) {
        guard ownerRecency.count > limit else { return }
        let staleOwners = ownerRecency.prefix(ownerRecency.count - limit)
        for ownerUUID in staleOwners {
            selectedParticipantByOwnerUUID.removeValue(forKey: ownerUUID)
        }
        ownerRecency = Array(ownerRecency.suffix(limit))
    }
}

struct ConferenceNearbyFollowUpTarget: Equatable {
    var remoteUUID: String
    var participantId: String
    var identityUUID: String?
    var displayName: String
    var company: String?
    var role: String?

    func discoveryTargetObject(includeIdentityUUID: Bool = false) -> Object {
        var object: Object = [
            "participantId": .string(participantId),
            "displayName": .string(displayName),
            "company": .string(company ?? ""),
            "role": .string(role ?? "")
        ]
        if includeIdentityUUID, let identityUUID {
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
            "targets": .list([.object(target.discoveryTargetObject(includeIdentityUUID: true))])
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
        case uncertain

        var title: String {
            switch self {
            case .left: return "Venstre"
            case .ahead: return "Foran"
            case .right: return "Høyre"
            case .behind: return "Bak"
            case .uncertain: return "Retning usikker"
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

    private struct RelevanceSignal {
        var badge: String
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
    private var scannerLifecycleStatus = "idle"
    private var requestedScannerStatus: String?
    private var transportMode = "multipeerconnectivity"
    private var precisionMode = "unknown"
    private var capabilityDescription = "Start the scanner to evaluate nearby transport and precision."
    private var supportsNearbyPrecision = false
    private var contactSignalsById: [String: ContactSignal] = [:]
    private var purposeSignalsById: [String: PurposeSignal] = [:]
    private var followUpTargetsById: [String: ConferenceNearbyFollowUpTarget] = [:]
    private var selectedRemoteUUID: String?
    private var followUpMarkedRemoteUUIDs: Set<String> = []
    private var launchedChatRemoteUUIDs: Set<String> = []
    private var testInjectedRemoteUUIDs: Set<String> = []
    private var lastError: String?
    private var lastActionSummary = "Nearby-radaren er klar. Be om kontakt for å verifisere formål og interesser."

    private var scannerAccessRequester: Identity {
        bootstrapRequester
    }

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
        agreementTemplate.addGrant("rw--", for: "openExpandedRadarWorkbench")
        agreementTemplate.addGrant("rw--", for: "openSelectedParticipantWorkbench")
        agreementTemplate.addGrant("rw--", for: "openParticipantPortalWorkbench")
        agreementTemplate.addGrant("rw--", for: "selectEntity")
        agreementTemplate.addGrant("rw--", for: "toggleFollowUp")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")
#if DEBUG
        agreementTemplate.addGrant("rw--", for: "testInjectNearbyCandidate")
        agreementTemplate.addGrant("rw--", for: "testInjectVerifiedContact")
#endif

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

        await addInterceptForSet(requester: owner, key: "openExpandedRadarWorkbench", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "openExpandedRadarWorkbench", for: requester) else { return .string("denied") }
            return await self.openExpandedRadarWorkbench(requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "openSelectedParticipantWorkbench", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "openSelectedParticipantWorkbench", for: requester) else { return .string("denied") }
            return await self.openSelectedParticipantWorkbench(requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "openParticipantPortalWorkbench", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "openParticipantPortalWorkbench", for: requester) else { return .string("denied") }
            return await self.openParticipantPortalWorkbench(requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "selectEntity", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "selectEntity", for: requester) else { return .string("denied") }
            return await self.selectEntity(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "toggleFollowUp", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "toggleFollowUp", for: requester) else { return .string("denied") }
            return await self.toggleFollowUp(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.forwardDispatchAction(value: value, requester: requester)
        })

#if DEBUG
        await addInterceptForSet(requester: owner, key: "testInjectNearbyCandidate", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "testInjectNearbyCandidate", for: requester) else { return .string("denied") }
            return await self.injectNearbyCandidate(value: value, requester: requester, verifiedByDefault: false)
        })

        await addInterceptForSet(requester: owner, key: "testInjectVerifiedContact", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "testInjectVerifiedContact", for: requester) else { return .string("denied") }
            return await self.injectNearbyCandidate(value: value, requester: requester, verifiedByDefault: true)
        })
#endif

        Task { [weak self] in
            guard let self else { return }
            await self.connectScannerIfNeeded(requester: owner)
            self.emitSnapshot(requester: owner)
        }
    }

    private func connectScannerIfNeeded(requester: Identity) async {
        let scannerRequester = scannerAccessRequester
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
                let emit = try await resolver.cellAtEndpoint(endpoint: "cell:///EntityScanner", requester: scannerRequester)
                guard let meddle = emit as? Meddle else {
                    self.lastError = "EntityScanner does not support meddle"
                    self.emitSnapshot(requester: requester)
                    return
                }

                self.activeRequester = requester
                self.scannerEmit = emit
                self.scannerMeddle = meddle
                self.lastError = nil
                try await self.subscribeToScannerFlow(emitter: emit, requester: scannerRequester)
                await self.refreshCapabilitySnapshot(requester: scannerRequester)
                await self.refreshEncounterSnapshot(requester: scannerRequester)
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
        if keypath == "requestContact",
           let remoteUUID = normalizedRemoteUUID(string(from: value)),
           testInjectedRemoteUUIDs.contains(remoteUUID) {
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "sent",
                summary: "Signert kontaktforespørsel sendt. Venter på godkjenning.",
                actionLabel: "Kontakt venter"
            )
            lastError = nil
            lastActionSummary = "Signert kontaktforespørsel sendt. Venter på godkjenning."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        await connectScannerIfNeeded(requester: requester)
        guard let scannerMeddle else {
            lastError = "EntityScanner unavailable"
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }
        let scannerRequester = scannerAccessRequester

        do {
            if keypath == "start" {
                scannerStatus = "started"
                scannerLifecycleStatus = "started"
                requestedScannerStatus = "started"
                lastActionSummary = "Starter scanner og lytter etter nearby-signaler."
            } else if keypath == "stop" {
                scannerStatus = "stopped"
                scannerLifecycleStatus = "stopped"
                requestedScannerStatus = "stopped"
                lastActionSummary = "Stopper scanner og rydder live nearby-signaler."
            }
            let result = try await scannerMeddle.set(keypath: keypath, value: value, requester: scannerRequester)
            lastError = nil
            applyMutationResult(keypath: keypath, result: result, payload: value)
            await refreshCapabilitySnapshot(requester: scannerRequester)
            if keypath == "requestContact" {
                await refreshEncounterSnapshot(requester: scannerRequester)
            } else if keypath == "start" {
                scannerStatus = "started"
                scannerLifecycleStatus = "started"
                requestedScannerStatus = "started"
                lastActionSummary = "Scanner kjører. Venter på nearby-deltagere."
            } else if keypath == "stop" {
                scannerStatus = "stopped"
                scannerLifecycleStatus = "stopped"
                requestedScannerStatus = "stopped"
                lastActionSummary = "Scanner er stoppet."
            }
        } catch {
            lastError = "Nearby scanner action \(keypath) failed: \(error)"
            switch keypath {
            case "start":
                scannerStatus = "started"
                scannerLifecycleStatus = "started"
                requestedScannerStatus = "started"
                lastActionSummary = "Scanner-start ble bedt om lokalt. Live nearby-tjeneste er ikke klar ennå: \(error)"
            case "stop":
                scannerStatus = "stopped"
                scannerLifecycleStatus = "stopped"
                requestedScannerStatus = "stopped"
                lastActionSummary = "Scanner-stopp ble bedt om lokalt. Live nearby-tjeneste er ikke klar ennå: \(error)"
            default:
                requestedScannerStatus = nil
                lastActionSummary = "Nearby-handlingen feilet: \(error)"
            }
        }

        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func forwardDispatchAction(value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(actionObject) = value,
              let actionKeypath = string(from: actionObject["keypath"]),
              actionKeypath.isEmpty == false else {
            lastError = "Nearby-handlingen mangler keypath."
            lastActionSummary = "Nearby-handlingen mangler keypath."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        let actionPayload = actionObject["payload"] ?? .bool(true)
        switch actionKeypath {
        case "start", "stop", "invite", "requestContact":
            return await forwardMutation(keypath: actionKeypath, value: actionPayload, requester: requester)
        case "openFollowUpChat":
            return await openFollowUpChat(value: actionPayload, requester: requester)
        case "selectEntity":
            return await selectEntity(value: actionPayload, requester: requester)
        case "toggleFollowUp":
            return await toggleFollowUp(value: actionPayload, requester: requester)
        case "openExpandedRadarWorkbench":
            return await openExpandedRadarWorkbench(requester: requester)
        case "openSelectedParticipantWorkbench":
            return await openSelectedParticipantWorkbench(requester: requester)
        case "openParticipantPortalWorkbench":
            return await openParticipantPortalWorkbench(requester: requester)
        default:
            lastError = "Nearby-handlingen \(actionKeypath) er ikke støttet."
            lastActionSummary = "Nearby-handlingen \(actionKeypath) er ikke støttet."
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
            lastError = "Nearby-oppfølging er ikke klar ennå. Fullfør signert kontakt først."
            lastActionSummary = "Nearby-oppfølging er ikke klar ennå. Fullfør signert kontakt først."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }
        guard let resolver = CellBase.defaultCellResolver else {
            lastError = "Cell resolver missing"
            lastActionSummary = "Could not open discovery chat because the local resolver is missing."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }
        selectedRemoteUUID = remoteUUID

        let dispatchPayload: Object = [
            "keypath": .string("discovery.startChat"),
            "payload": .object(
                ConferenceNearbyFollowUpSupport.discoveryPayload(
                    for: target,
                    source: "nearby-verified-contact"
                )
            )
        ]

        if await dispatchLocalParticipantFallback(
            payload: dispatchPayload,
            requester: requester,
            resolver: resolver,
            targetName: target.displayName
        ) {
            lastError = nil
            launchedChatRemoteUUIDs.insert(remoteUUID)
            lastActionSummary = "Startet conference-chat med \(target.displayName)."
            if var contactSignal = contactSignalsById[remoteUUID] {
                contactSignal.summary = "Verifisert kontakt lagret. Chatten er klar for oppfølging."
                contactSignal.actionLabel = "Åpne chat"
                contactSignalsById[remoteUUID] = contactSignal
            }
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

            let preDispatchState = await participantFollowUpState(via: porthole, requester: requester)
            let result = try await porthole.set(
                keypath: "conferenceParticipantShell.dispatchAction",
                value: .object(dispatchPayload),
                requester: requester
            )
            let postDispatchState = await participantFollowUpState(via: porthole, requester: requester)

            let localFallbackSucceededOnError: Bool
            if mutationErrorDescription(from: result) != nil {
                localFallbackSucceededOnError = await dispatchLocalParticipantFallback(
                    payload: dispatchPayload,
                    requester: requester,
                    resolver: resolver,
                    targetName: target.displayName
                )
            } else {
                localFallbackSucceededOnError = false
            }

            let localFallbackSucceededAfterNoop = await dispatchLocalParticipantFallback(
                payload: dispatchPayload,
                requester: requester,
                resolver: resolver,
                expectedBeforeState: postDispatchState,
                targetName: target.displayName
            )

            if let errorDescription = mutationErrorDescription(from: result),
               localFallbackSucceededOnError == false {
                lastError = errorDescription
                lastActionSummary = errorDescription
            } else if participantFollowUpStateDidAdvance(
                from: preDispatchState,
                to: postDispatchState,
                targetName: target.displayName
            ) || localFallbackSucceededAfterNoop {
                lastError = nil
                launchedChatRemoteUUIDs.insert(remoteUUID)
                lastActionSummary = "Startet conference-chat med \(target.displayName)."
                if var contactSignal = contactSignalsById[remoteUUID] {
                    contactSignal.summary = "Verifisert kontakt lagret. Chatten er klar for oppfølging."
                    contactSignal.actionLabel = "Åpne chat"
                    contactSignalsById[remoteUUID] = contactSignal
                }
            } else {
                lastError = "Nearby follow-up did not update participant preview state."
                lastActionSummary = "Nearby follow-up did not update participant preview state."
            }
        } catch {
            if await dispatchLocalParticipantFallback(
                payload: [
                    "keypath": .string("discovery.startChat"),
                    "payload": .object(
                        ConferenceNearbyFollowUpSupport.discoveryPayload(
                            for: target,
                            source: "nearby-verified-contact"
                        )
                    )
                ],
                requester: requester,
                resolver: resolver,
                targetName: target.displayName
            ) {
                lastError = nil
                launchedChatRemoteUUIDs.insert(remoteUUID)
                lastActionSummary = "Startet conference-chat med \(target.displayName)."
                if var contactSignal = contactSignalsById[remoteUUID] {
                    contactSignal.summary = "Verifisert kontakt lagret. Chatten er klar for oppfølging."
                    contactSignal.actionLabel = "Åpne chat"
                    contactSignalsById[remoteUUID] = contactSignal
                }
            } else {
                lastError = "Nearby-chatten kunne ikke startes: \(error)"
                lastActionSummary = "Nearby-chatten kunne ikke startes: \(error)"
            }
        }

        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func selectEntity(value: ValueType, requester: Identity) async -> ValueType {
        let requestedRemoteUUID = normalizedRemoteUUID(string(from: object(from: value)?["remoteUUID"]) ?? string(from: value))
            ?? selectedRemoteUUID

        guard let requestedRemoteUUID,
              let entity = entitiesById[requestedRemoteUUID] else {
            lastError = "Could not focus nearby participant because the selection was missing."
            lastActionSummary = "Could not focus nearby participant because the selection was missing."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        selectedRemoteUUID = requestedRemoteUUID
        lastError = nil
        lastActionSummary = "Focused nearby view on \(entity.displayName)."
        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func toggleFollowUp(value: ValueType, requester: Identity) async -> ValueType {
        let requestedRemoteUUID = normalizedRemoteUUID(string(from: object(from: value)?["remoteUUID"]) ?? string(from: value))
            ?? selectedRemoteUUID

        guard let requestedRemoteUUID,
              let entity = entitiesById[requestedRemoteUUID] else {
            lastError = "Could not update follow-up mark because no nearby participant was selected."
            lastActionSummary = "Could not update follow-up mark because no nearby participant was selected."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        selectedRemoteUUID = requestedRemoteUUID
        if followUpMarkedRemoteUUIDs.contains(requestedRemoteUUID) {
            followUpMarkedRemoteUUIDs.remove(requestedRemoteUUID)
            lastActionSummary = "Removed \(entity.displayName) from follow-up."
        } else {
            followUpMarkedRemoteUUIDs.insert(requestedRemoteUUID)
            lastActionSummary = "Marked \(entity.displayName) for follow-up."
        }
        lastError = nil
        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func openExpandedRadarWorkbench(requester: Identity) async -> ValueType {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration(
            participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        return await loadWorkbenchConfiguration(
            configuration,
            requester: requester,
            successSummary: "Åpnet radarflaten i egen arbeidsflate."
        )
    }

    private func openSelectedParticipantWorkbench(requester: Identity) async -> ValueType {
        guard let selectedRemoteUUID,
              let entity = entitiesById[selectedRemoteUUID] else {
            lastError = "Velg en nearby deltager før du åpner profilflaten."
            lastActionSummary = "Velg en nearby deltager før du åpner profilflaten."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration(
            participantEndpoint: "cell:///ConferenceParticipantPreviewShell",
            displayName: "\(entity.displayName) · Profilflate",
            summary: "Valgt nearby-deltager med oppfølging, chat og spatial kontekst i én arbeidsflate."
        )
        return await loadWorkbenchConfiguration(
            configuration,
            requester: requester,
            successSummary: "Åpnet profilflaten for \(entity.displayName)."
        )
    }

    private func openParticipantPortalWorkbench(requester: Identity) async -> ValueType {
        lastError = nil
        lastActionSummary = "Går tilbake til deltagerportalen…"
        emitSnapshot(requester: requester)
        await MainActor.run {
            BindingConferenceNavigationBridge.postPop(
                fallbackConfiguration: ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                    endpoint: "cell:///ConferenceParticipantPreviewShell"
                )
            )
        }
        lastActionSummary = "Tilbake i deltagerportalen."
        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func loadWorkbenchConfiguration(
        _ configuration: CellConfiguration,
        requester: Identity,
        successSummary: String
    ) async -> ValueType {
        lastError = nil
        lastActionSummary = "Åpner arbeidsflaten…"
        emitSnapshot(requester: requester)
        scheduleWorkbenchLoad(configuration, requester: requester, successSummary: successSummary)
        return .object(snapshotObject())
    }

    private func scheduleWorkbenchLoad(
        _ configuration: CellConfiguration,
        requester: Identity,
        successSummary: String
    ) {
        Task { @MainActor [weak self] in
            BindingPortholeLoadBridge.post(configuration: configuration)
            self?.lastError = nil
            self?.lastActionSummary = successSummary
            self?.emitSnapshot(requester: requester)
        }
    }

    private func participantFollowUpState(via porthole: Meddle, requester: Identity) async -> (nextStep: String?, chatSummary: String?, firstRecentMessage: String?) {
        let stateValue = try? await porthole.get(
            keypath: "conferenceParticipantShell.state",
            requester: requester
        )
        return participantFollowUpState(from: stateValue)
    }

    private func participantFollowUpStateDidAdvance(
        from before: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?),
        to after: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?),
        targetName: String
    ) -> Bool {
        let normalizedTarget = targetName.lowercased()
        if after.nextStep?.lowercased().contains(normalizedTarget) == true {
            return true
        }
        if after.firstRecentMessage?.lowercased().contains(normalizedTarget) == true {
            return true
        }
        return before != after
    }

    private func dispatchLocalParticipantFallback(
        payload: Object,
        requester: Identity,
        resolver: any CellResolverProtocol,
        expectedBeforeState: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?)? = nil,
        targetName: String? = nil
    ) async -> Bool {
        guard let localPreview = try? await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: requester
        ) as? Meddle else {
            return false
        }

        let beforeState: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?)
        if let expectedBeforeState {
            beforeState = expectedBeforeState
        } else {
            beforeState = await participantPreviewFallbackState(from: localPreview, requester: requester)
        }

        let result = try? await localPreview.set(
            keypath: "dispatchAction",
            value: .object(payload),
            requester: requester
        )
        if let errorDescription = mutationErrorDescription(from: result) {
            lastError = errorDescription
            return false
        }

        let afterState: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?)
        if let mutationState = participantFollowUpState(fromMutationResult: result) {
            afterState = mutationState
        } else {
            afterState = await participantPreviewFallbackState(from: localPreview, requester: requester)
        }
        return participantFollowUpStateDidAdvance(
            from: beforeState,
            to: afterState,
            targetName: targetName ?? ""
        )
    }

    private func participantPreviewFallbackState(
        from participantPreview: Meddle,
        requester: Identity
    ) async -> (nextStep: String?, chatSummary: String?, firstRecentMessage: String?) {
        let stateValue = try? await participantPreview.get(keypath: "state", requester: requester)
        return participantFollowUpState(from: stateValue)
    }

    private func participantFollowUpState(from stateValue: ValueType?) -> (nextStep: String?, chatSummary: String?, firstRecentMessage: String?) {
        guard case let .object(stateObject)? = stateValue else {
            return (nil, nil, nil)
        }
        let workspace = object(from: stateObject["workspace"])
        let sharedConnections = object(from: stateObject["sharedConnections"])
        let firstRecentMessage: String?
        if case let .list(messages)? = sharedConnections?["recentMessages"],
           case let .object(firstMessage)? = messages.first {
            firstRecentMessage = string(from: firstMessage["detail"])
        } else {
            firstRecentMessage = nil
        }

        return (
            nextStep: string(from: workspace?["nextStep"]),
            chatSummary: string(from: sharedConnections?["chatSummary"]),
            firstRecentMessage: firstRecentMessage
        )
    }

    private func participantFollowUpState(fromMutationResult value: ValueType?) -> (nextStep: String?, chatSummary: String?, firstRecentMessage: String?)? {
        guard case let .object(resultObject)? = value,
              case let .object(stateObject)? = resultObject["state"] else {
            return nil
        }
        return participantFollowUpState(from: .object(stateObject))
    }

#if DEBUG
    private func injectNearbyCandidate(
        value: ValueType,
        requester: Identity,
        verifiedByDefault: Bool
    ) async -> ValueType {
        let input = object(from: value)
        let verified = bool(from: input?["verified"]) ?? verifiedByDefault
        let remoteUUID = normalizedRemoteUUID(string(from: input?["remoteUUID"])) ?? "nearby-test-contact"
        let displayName = string(from: input?["displayName"]) ?? "Nora Berg"
        let identityUUID = normalizedRemoteUUID(string(from: input?["identityUUID"]))
        let participantId = string(from: input?["participantId"])
            ?? ConferenceNearbyFollowUpSupport.synthesizedParticipantId(
                remoteUUID: remoteUUID,
                identityUUID: identityUUID
            )
        let company = string(from: input?["company"]) ?? "Polar Systems"
        let role = string(from: input?["role"]) ?? "speaker"
        let matchCount = int(from: input?["matchCount"]) ?? 2
        let matchScore = double(from: input?["matchScore"]) ?? 0.92
        let distanceMeters = double(from: input?["distanceMeters"]) ?? 1.6
        let hasDirection = bool(from: input?["hasDirection"]) ?? true
        let direction = hasDirection ? RadarDirection3D(
            x: double(from: input?["directionX"]) ?? 0.0,
            y: double(from: input?["directionY"]) ?? 0.0,
            z: double(from: input?["directionZ"]) ?? 1.0
        ) : nil

        let update = RadarEntityUpdate(
            remoteUUID: remoteUUID,
            displayName: displayName,
            status: "nearby",
            connected: true,
            distanceMeters: distanceMeters,
            direction: direction,
            matchScore: matchScore
        )
        entitiesById[remoteUUID] = NearbyEntity(update: update, defaultStatus: "nearby")
        selectedRemoteUUID = remoteUUID
        testInjectedRemoteUUIDs.insert(remoteUUID)
        if verified {
            purposeSignalsById[remoteUUID] = PurposeSignal(
                count: matchCount,
                score: matchScore,
                summary: "\(matchCount) verified overlap(s) via governance",
                detail: "Top verified match score \(String(format: "%.2f", matchScore))"
            )
            followUpTargetsById[remoteUUID] = ConferenceNearbyFollowUpTarget(
                remoteUUID: remoteUUID,
                participantId: participantId,
                identityUUID: identityUUID,
                displayName: displayName,
                company: company,
                role: role
            )
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "verified",
                summary: "Verified contact saved with \(matchCount) purpose/interest overlap(s).",
                actionLabel: "Verified contact"
            )
            lastActionSummary = "Injected verified nearby contact for \(displayName)."
        } else {
            purposeSignalsById.removeValue(forKey: remoteUUID)
            followUpTargetsById.removeValue(forKey: remoteUUID)
            contactSignalsById.removeValue(forKey: remoteUUID)
            launchedChatRemoteUUIDs.remove(remoteUUID)
            lastActionSummary = "Injected nearby candidate for \(displayName)."
        }
        scannerStatus = "started"
        scannerLifecycleStatus = "started"
        requestedScannerStatus = "started"
        lastError = nil
        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }
#endif

    private func consume(flowElement: FlowElement) async {
        if case let .object(object) = flowElement.content {
            applyCapabilities(from: object)
            applyContactEvent(topic: flowElement.topic, object: object)
        }

        guard let scannerEvent = RadarEventParser.parse(flowElement) else {
            let snapshotRequester = activeRequester ?? bootstrapRequester
            if flowElement.topic == "scanner.encounter.saved" || flowElement.topic == "scanner.contact.established" {
                await refreshEncounterSnapshot(requester: scannerAccessRequester)
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
                if status == "started" || status == "stopped" {
                    scannerLifecycleStatus = status
                }
                if requestedScannerStatus == status,
                   (status == "started" || status == "stopped") {
                    requestedScannerStatus = nil
                }
            }
            upsert(update, fallbackStatus: scannerStatus)
        }

        pruneStaleEntities()
        let snapshotRequester = activeRequester ?? bootstrapRequester
        if flowElement.topic == "scanner.encounter.saved" || flowElement.topic == "scanner.contact.established" {
            await refreshEncounterSnapshot(requester: scannerAccessRequester)
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
            if status == "started" || status == "stopped" || status == "idle" || status == "scannerNotStarted" {
                scannerLifecycleStatus = lifecycleBadgeStatus(from: status)
            }
        }
        if let supportsNearby = bool(from: object["supportsNearbyPrecision"]) {
            supportsNearbyPrecision = supportsNearby
        }
    }

    private func lifecycleBadgeStatus(from rawStatus: String) -> String {
        switch rawStatus {
        case "started":
            return "started"
        case "stopped":
            return "stopped"
        case "scannerNotStarted", "idle":
            return "idle"
        default:
            return scannerLifecycleStatus
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
        let remainingRemoteUUIDs = Set(entitiesById.keys)
        followUpMarkedRemoteUUIDs.formIntersection(remainingRemoteUUIDs)
        if let selectedRemoteUUID, remainingRemoteUUIDs.contains(selectedRemoteUUID) == false {
            self.selectedRemoteUUID = nil
        }
    }

    private func applyMutationResult(keypath: String, result: ValueType?, payload: ValueType) {
        guard keypath == "requestContact",
              let resultObject = object(from: result),
              let remoteUUID = normalizedRemoteUUID(string(from: resultObject["remoteUUID"]) ?? string(from: payload)) else {
            return
        }

        switch string(from: resultObject["status"]) ?? "" {
        case "pendingConnection":
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "pendingConnection",
                summary: "Invitasjon sendt. Signert kontakt starter når enhetslenken er klar.",
                actionLabel: "Kobler til..."
            )
            lastActionSummary = "Invitasjon sendt. Signert kontakt starter når enhetslenken er klar."
        case "sent":
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "sent",
                summary: "Signert kontaktforespørsel sendt. Venter på at den andre siden godkjenner.",
                actionLabel: "Kontakt venter"
            )
            lastActionSummary = "Signert kontaktforespørsel sendt. Venter på at den andre siden godkjenner."
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
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "pendingConnection",
                summary: string(from: object["message"]) ?? "Invitasjon sendt. Venter på direkte enhetslenke.",
                actionLabel: "Kobler til..."
            )
            lastActionSummary = "Invitasjon sendt. Venter på direkte enhetslenke før signert kontakt."
        case "scanner.contact.outgoing":
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "sent",
                summary: "Signert kontaktforespørsel sendt. Venter på godkjenning.",
                actionLabel: "Kontakt venter"
            )
            lastActionSummary = "Signert kontaktforespørsel sendt."
        case "scanner.contact.established", "scanner.encounter.saved":
            selectedRemoteUUID = remoteUUID
            let matchCount = purposeSignalsById[remoteUUID]?.count ?? int(from: object["matchCount"]) ?? 0
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "verified",
                summary: matchCount > 0
                    ? "Verifisert kontakt lagret med \(matchCount) formål-/interesseoverlapp."
                    : "Verifisert kontakt lagret. Ingen overlapp bekreftet ennå.",
                actionLabel: "Verifisert kontakt"
            )
            lastActionSummary = contactSignalsById[remoteUUID]?.summary ?? "Verifisert kontakt lagret."
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
        let effectiveScannerStatus = requestedScannerStatus ?? scannerLifecycleStatus

        let entities = sortedEntities()
        let focusedRemoteUUID = ensureSelectedRemoteUUID(in: entities)
        let sectors = CompassSector.allCases.map { sector in
            makeSectorCard(for: sector, entities: entities.filter { compassSector(for: $0) == sector })
        }

        let nearbyCards = entities.prefix(8).map(makeNearbyCard(for:))
        let connectedCount = entities.filter(\.connected).count
        let verifiedMatchCount = purposeSignalsById.values.filter { $0.count > 0 }.count
        let followUpCount = followUpTargetsById.count
        let directionalCount = entities.filter { hasDirectionalPosition($0) }.count
        let uncertainCount = entities.count - directionalCount
        let summary = entities.isEmpty
            ? "Ingen nearby peers enda. Start scanner for å bygge et lokalt spatialt bilde."
            : "\(entities.count) nearby peer(s) · \(connectedCount) connected · \(verifiedMatchCount) verified purpose fit(s) · \(followUpCount) follow-up chat(s) ready."
        let statusSummary = scannerStatusSummary(
            effectiveScannerStatus: effectiveScannerStatus,
            visibleEntityCount: entities.count
        )

        let precisionSummary: String
        if precisionMode.lowercased().contains("uwb") || supportsNearbyPrecision {
            precisionSummary = "UWB-precision is available on this device. MPC remains the base transport."
        } else {
            precisionSummary = "Using MPC-only proximity. Direction and distance stay less precise until UWB is available."
        }

        let localityNote = "Binding-local spatial enrichment over EntityScanner. This augments conference discovery without replacing the portable scaffold contract."
        let spatialTruthSummary: String
        if entities.isEmpty {
            spatialTruthSummary = "Når nearby-signaler dukker opp, viser vi presis retning bare når sensoren faktisk gir retning."
        } else if directionalCount > 0, uncertainCount > 0 {
            spatialTruthSummary = "Presis retning vises for \(directionalCount) deltager(e). \(uncertainCount) treff mangler retning og samles under retning usikker."
        } else if directionalCount > 0 {
            spatialTruthSummary = "Alle synlige treff har en faktisk retningsmåling akkurat nå."
        } else {
            spatialTruthSummary = "Ingen treff har presis retning akkurat nå. Nearby-signaler vises derfor som retning usikker."
        }
        let selectionSummary: String
        if let focusedRemoteUUID,
           let focusedEntity = entitiesById[focusedRemoteUUID] {
            selectionSummary = "Fokuserer på \(focusedEntity.displayName) i denne siden."
        } else {
            selectionSummary = "Trykk Vis i siden på en nearby-deltager for å fokusere på personen her."
        }
        let nextStepSummary = nextStepSummary(
            focusedRemoteUUID: focusedRemoteUUID,
            effectiveScannerStatus: effectiveScannerStatus
        )
        let matchSummary = focusedRemoteUUID.flatMap { remoteUUID in
            entitiesById[remoteUUID].map { entity in
                relevanceSignal(for: remoteUUID, entity: entity).summary
            }
        } ?? strongestRelevanceSummary(in: entities)
        let navigationSummary = focusedRemoteUUID == nil
            ? "Første klikk skjer i denne siden. Full radar og profilflate åpnes bare når du ber om en egen arbeidsflate."
            : "Du ser nå valgt deltager i denne siden. Åpne profilflate og full radar når du vil fordype deg i egne arbeidsflater."
        let selectedEntity = focusedRemoteUUID.flatMap { selectedEntityObject(for: $0) }
            ?? [
                "selectionBadge": .string("VALGT DELTAGER"),
                "title": .string("Ingen deltager valgt ennå"),
                "subtitle": .string("Velg en nearby deltager fra listen under."),
                "detail": .string("Når en deltager er valgt, viser vi avstand, retning og neste steg her."),
                "relevanceBadge": .string("AVVENTER VALG"),
                "relevanceSummary": .string("Velg en deltager for å se hvor sterk matchen ser ut akkurat nå."),
                "purposeSummary": .string("Ingen valgt deltager ennå"),
                "purposeDetail": .string("Verifisert purpose/interest-match vises først etter signert kontakt."),
                "followUpSummary": .string("Ingen oppfølging startet ennå."),
                "chatSummary": .string("Chat blir tilgjengelig når en valgt deltager er verifisert."),
                "note": .string("Bruk kortene under til å fokusere på en deltager.")
            ]
        let selectedEntityActions = focusedRemoteUUID.map { selectedEntityActionCards(for: $0) } ?? []
        let radarLayout = makeRadarLayout(
            entities: entities,
            focusedRemoteUUID: focusedRemoteUUID,
            effectiveScannerStatus: effectiveScannerStatus
        )

        return [
            "headline": .string("Nearby Participants"),
            "summary": .string(summary),
            "statusSummary": .string(statusSummary),
            "precisionSummary": .string(precisionSummary),
            "actionSummary": .string(lastActionSummary),
            "selectionSummary": .string(selectionSummary),
            "nextStepSummary": .string(nextStepSummary),
            "matchSummary": .string(matchSummary),
            "navigationSummary": .string(navigationSummary),
            "spatialTruthSummary": .string(spatialTruthSummary),
            "transportBadge": .string(transportMode.uppercased()),
            "precisionBadge": .string(precisionMode.uppercased()),
            "statusBadge": .string(effectiveScannerStatus),
            "localityNote": .string(localityNote),
            "description": .string(capabilityDescription),
            "radarLayout": .object(radarLayout),
            "selectedEntity": .object(selectedEntity),
            "selectedEntityActions": .list(selectedEntityActions.map(ValueType.object)),
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
            let lhsSelected = lhs.remoteUUID == selectedRemoteUUID
            let rhsSelected = rhs.remoteUUID == selectedRemoteUUID
            if lhsSelected != rhsSelected {
                return lhsSelected
            }
            let lhsMarked = followUpMarkedRemoteUUIDs.contains(lhs.remoteUUID)
            let rhsMarked = followUpMarkedRemoteUUIDs.contains(rhs.remoteUUID)
            if lhsMarked != rhsMarked {
                return lhsMarked
            }
            if lhs.connected != rhs.connected {
                return lhs.connected && !rhs.connected
            }
            let lhsVerified = followUpTargetsById[lhs.remoteUUID] != nil
            let rhsVerified = followUpTargetsById[rhs.remoteUUID] != nil
            if lhsVerified != rhsVerified {
                return lhsVerified
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
            "detail": .string(sector == .uncertain
                ? (entities.isEmpty ? "Ingen usikre nearby-signaler" : "MPC-only eller ventende retning · nærmest \(closest)")
                : (entities.isEmpty ? "No active signals" : "Closest: \(closest)")),
            "note": .string(previewNames.isEmpty
                ? (sector == .uncertain ? "Waiting for approximate signals" : "Waiting for directional signals")
                : previewNames)
        ]
    }

    private func makeRadarLayout(
        entities: [NearbyEntity],
        focusedRemoteUUID: String?,
        effectiveScannerStatus: String
    ) -> Object {
        let groupedEntities = Dictionary(grouping: entities, by: compassSector)
        return [
            "ahead": .object(makeRadarSectorNode(for: .ahead, entities: groupedEntities[.ahead] ?? [])),
            "left": .object(makeRadarSectorNode(for: .left, entities: groupedEntities[.left] ?? [])),
            "center": .object(makeRadarCenterNode(
                focusedRemoteUUID: focusedRemoteUUID,
                entities: entities,
                effectiveScannerStatus: effectiveScannerStatus
            )),
            "right": .object(makeRadarSectorNode(for: .right, entities: groupedEntities[.right] ?? [])),
            "behind": .object(makeRadarSectorNode(for: .behind, entities: groupedEntities[.behind] ?? [])),
            "uncertain": .object(makeRadarSectorNode(for: .uncertain, entities: groupedEntities[.uncertain] ?? []))
        ]
    }

    private func makeRadarSectorNode(for sector: CompassSector, entities: [NearbyEntity]) -> Object {
        var card = makeSectorCard(for: sector, entities: entities)
        if let strongestEntity = entities.first {
            let relevance = relevanceSignal(for: strongestEntity.remoteUUID, entity: strongestEntity)
            card["relevanceBadge"] = .string(relevance.badge)
            card["summary"] = .string(relevance.summary)
            card["note"] = .string(relevance.detail)
        } else {
            card["relevanceBadge"] = .string(sector == .uncertain ? "NÆRHET FØRST" : "AVVENTER TREFF")
            card["summary"] = .string(sector == .uncertain
                ? "Treff her vil først bli vist som usikker nearby-nærhet."
                : "Når treff dukker opp her, viser vi også hvor sterke matchene ser ut.")
        }
        card["badge"] = .string(sector == .uncertain ? "USIKKER NÆRHET" : "ROMLIG SEKTOR")
        if entities.isEmpty {
            card["note"] = .string(sector == .uncertain
                ? "Ingen usikre nearby-signaler akkurat nå."
                : "Ingen treff i denne retningen akkurat nå.")
        }
        return card
    }

    private func makeRadarCenterNode(
        focusedRemoteUUID: String?,
        entities: [NearbyEntity],
        effectiveScannerStatus: String
    ) -> Object {
        guard let focusedRemoteUUID,
              let focusedEntity = entitiesById[focusedRemoteUUID] else {
            let startGuidance = effectiveScannerStatus == "started"
                ? "Scanner kjører. Velg en nearby deltager når et treff dukker opp."
                : "Start scanner for å bygge et lokalt spatialt bilde."
            return [
                "badge": .string("FOKUS"),
                "title": .string("Velg en nearby deltager"),
                "subtitle": .string("\(entities.count) treff synlige i nærheten"),
                "detail": .string(startGuidance),
                "note": .string("Når en deltager er valgt, viser vi neste handling og chat-oppfølging her.")
            ]
        }

        let purposeSignal = purposeSignalsById[focusedRemoteUUID]
        let hasVerifiedContact = contactSignalsById[focusedRemoteUUID]?.status == "verified"
        let hasFollowUpChat = launchedChatRemoteUUIDs.contains(focusedRemoteUUID)
        let nextStep: String
        if hasVerifiedContact, hasFollowUpChat {
            nextStep = "Chatten er klar. Neste steg er å åpne den eller markere deltakeren for videre oppfølging."
        } else if hasVerifiedContact {
            nextStep = "Kontakten er verifisert. Neste steg er å starte chat eller markere deltakeren for oppfølging."
        } else {
            nextStep = "Neste steg er å be om kontakt for å verifisere purpose- og interesse-matchen."
        }

        return [
            "badge": .string("FOKUS"),
            "title": .string(focusedEntity.displayName),
            "subtitle": .string(directionSubtitle(for: focusedEntity, directionIsPrecise: hasDirectionalPosition(focusedEntity))),
            "detail": .string(purposeSignal?.summary ?? fallbackPurposeSummary(for: focusedRemoteUUID, liveScore: focusedEntity.matchScore)),
            "relevanceBadge": .string(relevanceSignal(for: focusedRemoteUUID, entity: focusedEntity).badge),
            "summary": .string(relevanceSignal(for: focusedRemoteUUID, entity: focusedEntity).summary),
            "note": .string(nextStep)
        ]
    }

    private func makeNearbyCard(for entity: NearbyEntity) -> Object {
        let directionIsPrecise = hasDirectionalPosition(entity)
        let purposeSignal = purposeSignalsById[entity.remoteUUID]
        let contactSignal = contactSignalsById[entity.remoteUUID]
        let followUpMarked = followUpMarkedRemoteUUIDs.contains(entity.remoteUUID)
        let selected = entity.remoteUUID == selectedRemoteUUID
        let relevance = relevanceSignal(for: entity.remoteUUID, entity: entity)
        let noteParts = [
            selected ? "Valgt i fokus." : nil,
            followUpMarked ? "Markert for oppfølging." : nil,
            contactSignal?.summary ?? positionTrustSummary(for: entity, directionIsPrecise: directionIsPrecise)
        ].compactMap { $0 }

        return [
            "title": .string(entity.displayName),
            "subtitle": .string(directionSubtitle(for: entity, directionIsPrecise: directionIsPrecise)),
            "detail": .string(positionDetail(for: entity, directionIsPrecise: directionIsPrecise)),
            "relevanceBadge": .string(relevance.badge),
            "relevanceSummary": .string(relevance.summary),
            "purposeSummary": .string(purposeSignal?.summary ?? fallbackPurposeSummary(for: entity.remoteUUID, liveScore: entity.matchScore)),
            "purposeDetail": .string(purposeSignal?.detail ?? "Purpose fit remains approximate until signed contact is established."),
            "note": .string(noteParts.joined(separator: " ")),
            "keypath": .string("nearbyRadar.dispatchAction"),
            "label": .string(selected ? "Valgt i siden" : "Vis i siden"),
            "payload": .object([
                "keypath": .string("selectEntity"),
                "payload": .object(["remoteUUID": .string(entity.remoteUUID)])
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
        guard let direction = entity.direction else {
            return .uncertain
        }
        let angle = direction.azimuthRadians
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

    private func hasDirectionalPosition(_ entity: NearbyEntity) -> Bool {
        entity.direction != nil
    }

    private func ensureSelectedRemoteUUID(in entities: [NearbyEntity]) -> String? {
        let validRemoteUUIDs = Set(entities.map(\.remoteUUID))
        if let selectedRemoteUUID, validRemoteUUIDs.contains(selectedRemoteUUID) {
            return selectedRemoteUUID
        }

        let preferredRemoteUUID = entities.sorted { lhs, rhs in
            let lhsMarked = followUpMarkedRemoteUUIDs.contains(lhs.remoteUUID)
            let rhsMarked = followUpMarkedRemoteUUIDs.contains(rhs.remoteUUID)
            if lhsMarked != rhsMarked {
                return lhsMarked
            }
            let lhsVerified = followUpTargetsById[lhs.remoteUUID] != nil
            let rhsVerified = followUpTargetsById[rhs.remoteUUID] != nil
            if lhsVerified != rhsVerified {
                return lhsVerified
            }
            let lhsDirectional = hasDirectionalPosition(lhs)
            let rhsDirectional = hasDirectionalPosition(rhs)
            if lhsDirectional != rhsDirectional {
                return lhsDirectional
            }
            let lhsDistance = lhs.distanceMeters ?? .greatestFiniteMagnitude
            let rhsDistance = rhs.distanceMeters ?? .greatestFiniteMagnitude
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return lhs.lastSeenAt > rhs.lastSeenAt
        }.first?.remoteUUID

        selectedRemoteUUID = preferredRemoteUUID
        return preferredRemoteUUID
    }

    private func selectedEntityObject(for remoteUUID: String) -> Object? {
        guard let entity = entitiesById[remoteUUID] else {
            return nil
        }
        let purposeSignal = purposeSignalsById[remoteUUID]
        let contactSignal = contactSignalsById[remoteUUID]
        let target = followUpTargetsById[remoteUUID]
        let markedForFollowUp = followUpMarkedRemoteUUIDs.contains(remoteUUID)
        let hasVerifiedContact = contactSignal?.status == "verified"
        let hasLaunchedChat = launchedChatRemoteUUIDs.contains(remoteUUID)
        let relevance = relevanceSignal(for: remoteUUID, entity: entity)
        let selectionBadge = markedForFollowUp ? "VALGT · MARKERT FOR OPPFØLGING" : "VALGT DELTAGER"
        let subtitleParts = [target?.company, target?.role].compactMap { value -> String? in
            guard let value, value.isEmpty == false else { return nil }
            return value
        }
        let noteParts = [
            contactSignal?.summary,
            markedForFollowUp ? "Denne deltakeren er markert for oppfølging." : nil
        ].compactMap { $0 }

        return [
            "selectionBadge": .string(selectionBadge),
            "title": .string(entity.displayName),
            "subtitle": .string(subtitleParts.isEmpty ? directionSubtitle(for: entity, directionIsPrecise: hasDirectionalPosition(entity)) : subtitleParts.joined(separator: " · ")),
            "detail": .string(positionDetail(for: entity, directionIsPrecise: hasDirectionalPosition(entity))),
            "relevanceBadge": .string(relevance.badge),
            "relevanceSummary": .string(relevance.summary),
            "purposeSummary": .string(purposeSignal?.summary ?? fallbackPurposeSummary(for: remoteUUID, liveScore: entity.matchScore)),
            "purposeDetail": .string(purposeSignal?.detail ?? "Verifisert purpose/interest-fit kommer først etter signert kontakt."),
            "followUpSummary": .string(followUpSummary(
                remoteUUID: remoteUUID,
                displayName: entity.displayName,
                hasVerifiedContact: hasVerifiedContact,
                hasLaunchedChat: hasLaunchedChat,
                markedForFollowUp: markedForFollowUp
            )),
            "chatSummary": .string(chatSummary(
                remoteUUID: remoteUUID,
                displayName: entity.displayName,
                hasVerifiedContact: hasVerifiedContact,
                hasLaunchedChat: hasLaunchedChat
            )),
            "note": .string(noteParts.isEmpty ? positionTrustSummary(for: entity, directionIsPrecise: hasDirectionalPosition(entity)) : noteParts.joined(separator: " "))
        ]
    }

    private func selectedEntityActionCards(for remoteUUID: String) -> [Object] {
        guard let entity = entitiesById[remoteUUID] else {
            return []
        }

        let profileAction: Object = [
            "title": .string("Profilflate"),
            "subtitle": .string("Åpne valgt deltager i egen flate"),
            "detail": .string("Vis valgt deltager som en hybrid av offentlig profil, lokal spatial kontekst og neste oppfølgingssteg."),
            "note": .string("Bruk dette når du vil fordype deg uten å miste conference-konteksten."),
            "keypath": .string("dispatchAction"),
            "label": .string("Åpne profilflate"),
            "payload": .object([
                "keypath": .string("openSelectedParticipantWorkbench"),
                "payload": .bool(true)
            ])
        ]

        let primaryAction: Object
        if followUpTargetsById[remoteUUID] != nil,
           contactSignalsById[remoteUUID]?.status == "verified" {
            let hasLaunchedChat = launchedChatRemoteUUIDs.contains(remoteUUID)
            primaryAction = [
                "title": .string("Chat"),
                "subtitle": .string(hasLaunchedChat ? "Fortsett oppfølging" : "Start oppfølging"),
                "detail": .string(hasLaunchedChat
                    ? "Discovery-chatten er klar. Åpne chatflaten for å fortsette samtalen med \(entity.displayName)."
                    : "Opprett en conference-chat med \(entity.displayName) fra denne nearby-matchen."),
                "note": .string("Dette er tilgjengelig fordi kontakten allerede er verifisert."),
                "keypath": .string(hasLaunchedChat ? "chatSnapshot.dispatchAction" : "nearbyRadar.dispatchAction"),
                "label": .string(hasLaunchedChat ? "Åpne chatflate" : "Start chat"),
                "payload": hasLaunchedChat
                    ? .object([
                        "keypath": .string("openChatWorkbench"),
                        "payload": .object([
                            "displayName": .string(entity.displayName)
                        ])
                    ])
                    : .object([
                        "keypath": .string("openFollowUpChat"),
                        "payload": .object(["remoteUUID": .string(remoteUUID)])
                    ])
            ]
        } else {
            primaryAction = [
                "title": .string("Kontakt"),
                "subtitle": .string("Be om signert kontakt"),
                "detail": .string("Etabler kontakt først. Når den er verifisert, kan du starte chat med høyere presisjon i match-signalet."),
                "note": .string(contactSignalsById[remoteUUID]?.summary ?? "Kontaktbeviset er første steg før verifisert purpose/interest-match."),
                "keypath": .string("nearbyRadar.dispatchAction"),
                "label": .string(contactSignalsById[remoteUUID]?.actionLabel ?? "Be om kontakt"),
                "payload": .object([
                    "keypath": .string("requestContact"),
                    "payload": .string(remoteUUID)
                ])
            ]
        }

        let markedForFollowUp = followUpMarkedRemoteUUIDs.contains(remoteUUID)
        let followUpAction: Object = [
            "title": .string("Oppfølging"),
            "subtitle": .string(markedForFollowUp ? "Fjern markering" : "Marker for oppfølging"),
            "detail": .string(markedForFollowUp
                ? "\(entity.displayName) er allerede markert for senere oppfølging."
                : "Legg denne deltakeren i oppfølgingsbunken uten å starte chat med en gang."),
            "note": .string(markedForFollowUp
                ? "Bruk dette hvis du vil rydde fokuslisten igjen."
                : "Passer når du vil komme tilbake etter sesjonen eller senere i dagen."),
            "keypath": .string("nearbyRadar.dispatchAction"),
            "label": .string(markedForFollowUp ? "Fjern markering" : "Marker for oppfølging"),
            "payload": .object([
                "keypath": .string("toggleFollowUp"),
                "payload": .object(["remoteUUID": .string(remoteUUID)])
            ])
        ]

        return [profileAction, primaryAction, followUpAction]
    }

    private func scannerStatusSummary(
        effectiveScannerStatus: String,
        visibleEntityCount: Int
    ) -> String {
        switch effectiveScannerStatus {
        case "started":
            return visibleEntityCount == 0
                ? "Scanner kjører. Når første nearby-treff dukker opp, vises det her."
                : "Scanner kjører og oppdaterer nearby-treffene løpende."
        case "stopped":
            return "Scanner er stoppet. Start den når du vil lete etter nearby-deltagere."
        case "starting":
            return "Scanner starter nå. Nearby-signaler vil dukke opp her så snart første treff kommer inn."
        case "stopping":
            return "Scanner stopper nå og rydder live nearby-signaler."
        default:
            return visibleEntityCount == 0
                ? "Nearby-radaren er klar, men har ingen live treff ennå."
                : "Nearby-radaren er klar med siste kjente nearby-treff."
        }
    }

    private func nextStepSummary(
        focusedRemoteUUID: String?,
        effectiveScannerStatus: String
    ) -> String {
        guard let focusedRemoteUUID,
              let entity = entitiesById[focusedRemoteUUID] else {
            return effectiveScannerStatus == "started"
                ? "Trykk Vis i siden på en nearby-deltager for å fokusere på personen her."
                : "Start scanner og velg deretter en nearby-deltager med Vis i siden."
        }

        let hasVerifiedContact = contactSignalsById[focusedRemoteUUID]?.status == "verified"
        let hasFollowUpChat = launchedChatRemoteUUIDs.contains(focusedRemoteUUID)
        if hasVerifiedContact, hasFollowUpChat {
            return "Chatten med \(entity.displayName) er klar. Neste steg er å åpne chatten eller markere deltakeren for oppfølging."
        }
        if hasVerifiedContact {
            return "Kontakten med \(entity.displayName) er verifisert. Neste steg er å starte chat eller markere deltakeren for oppfølging."
        }
        return "Neste steg er å be om kontakt med \(entity.displayName) for å verifisere formål og interesser."
    }

    private func strongestRelevanceSummary(in entities: [NearbyEntity]) -> String {
        guard let strongest = entities.first else {
            return "Ingen match vurdert ennå. Start scanner for å hente nearby-signaler."
        }
        return relevanceSignal(for: strongest.remoteUUID, entity: strongest).summary
    }

    private func relevanceSignal(for remoteUUID: String, entity: NearbyEntity) -> RelevanceSignal {
        let purposeSignal = purposeSignalsById[remoteUUID]
        let score = purposeSignal?.score ?? entity.matchScore
        let hasVerifiedContact = contactSignalsById[remoteUUID]?.status == "verified"

        guard let score else {
            return RelevanceSignal(
                badge: "NÆRHET FØRST",
                summary: "Nearby-signal oppdaget, men matchen må verifiseres videre.",
                detail: "Be om kontakt for å gå fra nearby-nærhet til en mer presis vurdering."
            )
        }

        if hasVerifiedContact, score >= 0.8 {
            return RelevanceSignal(
                badge: "GRØNN MATCH",
                summary: "Sterk verifisert match. Denne personen er klar for oppfølging nå.",
                detail: "Formål og interesser overlapper tydelig etter signert kontakt."
            )
        }
        if hasVerifiedContact, score >= 0.55 {
            return RelevanceSignal(
                badge: "GUL MATCH",
                summary: "God verifisert match. Det er verdt å følge opp videre.",
                detail: "Kontakten er verifisert, men relevansen er mer moderat enn toppmatchene."
            )
        }
        if hasVerifiedContact {
            return RelevanceSignal(
                badge: "RØD MATCH",
                summary: "Svakt verifisert treff. Vurder om denne personen bør følges opp videre.",
                detail: "Kontakten er verifisert, men formål og interesser overlapper svakt."
            )
        }
        if score >= 0.65 {
            return RelevanceSignal(
                badge: "LOVENDE MATCH",
                summary: "Lovende nearby-match. Det neste naturlige steget er å be om kontakt.",
                detail: "Scanneren ser høy relevans, men den er ikke verifisert ennå."
            )
        }
        if score >= 0.35 {
            return RelevanceSignal(
                badge: "GUL MATCH",
                summary: "Moderat nearby-match. Bruk dette som en kandidat, ikke som en bekreftet prioritet.",
                detail: "Det kan være verdt å be om kontakt hvis samtalen virker relevant."
            )
        }
        return RelevanceSignal(
            badge: "RØD MATCH",
            summary: "Lav nearby-relevans akkurat nå. Se gjerne videre før du følger opp.",
            detail: "Dette treffet er nærme, men scorer lavt på nåværende matchsignal."
        )
    }

    private func followUpSummary(
        remoteUUID: String,
        displayName: String,
        hasVerifiedContact: Bool,
        hasLaunchedChat: Bool,
        markedForFollowUp: Bool
    ) -> String {
        if hasLaunchedChat, markedForFollowUp {
            return "\(displayName) er både markert for oppfølging og har en chat klar."
        }
        if hasLaunchedChat {
            return "Chatten med \(displayName) er klar til videre oppfølging."
        }
        if markedForFollowUp {
            return "\(displayName) er markert for oppfølging senere."
        }
        if hasVerifiedContact {
            return "Kontakten er verifisert. Nå kan du starte chat eller markere for oppfølging."
        }
        if contactSignalsById[remoteUUID]?.status == "sent" || contactSignalsById[remoteUUID]?.status == "pendingConnection" {
            return "Kontaktforespørselen er sendt. Vent på verifisering før du starter chat."
        }
        return "Ingen oppfølging startet ennå. Be om kontakt eller marker deltakeren for senere."
    }

    private func chatSummary(
        remoteUUID: String,
        displayName: String,
        hasVerifiedContact: Bool,
        hasLaunchedChat: Bool
    ) -> String {
        if hasLaunchedChat {
            return "Åpne chatten for å fortsette samtalen med \(displayName)."
        }
        if hasVerifiedContact {
            return "Chat er ikke startet ennå. Neste steg er å trykke Start chat."
        }
        if contactSignalsById[remoteUUID]?.status == "sent" || contactSignalsById[remoteUUID]?.status == "pendingConnection" {
            return "Chat blir tilgjengelig når kontakten er verifisert."
        }
        return "Chat er låst til verifisert kontakt i denne nearby-flyten."
    }

    private func directionSubtitle(for entity: NearbyEntity, directionIsPrecise: Bool) -> String {
        if directionIsPrecise {
            return "\(compassSector(for: entity).title) · presis retning"
        }
        return "Retning usikker · nearby via MPC"
    }

    private func positionDetail(for entity: NearbyEntity, directionIsPrecise: Bool) -> String {
        let distanceText = entity.distanceMeters.map { String(format: "%.1f m", $0) } ?? "Avstand avventer"
        let visibilityText = entity.connected ? "tilkoblet" : "synlig"
        if directionIsPrecise {
            return "\(compassSector(for: entity).title) · \(distanceText) · \(visibilityText)"
        }
        return "Retning usikker · \(distanceText) · \(visibilityText)"
    }

    private func positionTrustSummary(for entity: NearbyEntity, directionIsPrecise: Bool) -> String {
        if directionIsPrecise {
            return "Retning og avstand er basert på levende nearby-signaler."
        }
        if entity.matchScore != nil {
            return "Dette treffet er synlig nearby, men retningen er foreløpig usikker."
        }
        return "Nearby-signal oppdaget. Retning og presis match må bekreftes videre."
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
    private var storeKey = ""
    private var agendaView = "forYou"
    private var activeTrackID = "all"
    private var currentFilter = "All recommended people"
    private var pendingRequestCount = 0
    private var confirmedMeetingCount = 0
    private var exportPrepared = false
    private var searchQuery = "people"
    private var recentMessages: [ConferenceParticipantPreviewFallbackMessage] = []
    private var launchedDiscoveryChatNames: [String] = []
    private var focusedRecommendationName: String?
    private var followUpMarkedNames = Set<String>()
    private var recentActionSummary = "Participant preview is running locally in Binding because the staging preview was denied."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        storeKey = owner.uuid
        await restoreStoredStateIfAvailable()
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func restoreStoredStateIfAvailable() async {
        guard !storeKey.isEmpty,
              let storedState = await ConferenceParticipantPreviewFallbackStateStore.shared.load(for: storeKey) else {
            return
        }

        agendaView = storedState.agendaView
        activeTrackID = storedState.activeTrackID
        currentFilter = storedState.currentFilter
        pendingRequestCount = storedState.pendingRequestCount
        confirmedMeetingCount = storedState.confirmedMeetingCount
        exportPrepared = storedState.exportPrepared
        searchQuery = storedState.searchQuery
        recentMessages = storedState.recentMessages
        launchedDiscoveryChatNames = storedState.launchedDiscoveryChatNames
        focusedRecommendationName = storedState.focusedRecommendationName
        followUpMarkedNames = storedState.followUpMarkedNames
        recentActionSummary = storedState.recentActionSummary
    }

    private func persistCurrentState() async {
        guard !storeKey.isEmpty else {
            return
        }

        await ConferenceParticipantPreviewFallbackStateStore.shared.save(
            ConferenceParticipantPreviewFallbackState(
                agendaView: agendaView,
                activeTrackID: activeTrackID,
                currentFilter: currentFilter,
                pendingRequestCount: pendingRequestCount,
                confirmedMeetingCount: confirmedMeetingCount,
                exportPrepared: exportPrepared,
                searchQuery: searchQuery,
                recentMessages: recentMessages,
                launchedDiscoveryChatNames: launchedDiscoveryChatNames,
                focusedRecommendationName: focusedRecommendationName,
                followUpMarkedNames: followUpMarkedNames,
                recentActionSummary: recentActionSummary
            ),
            for: storeKey
        )
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
                recentActionSummary = "Switched agenda view to \(viewLabel(view))."
            }
        case "agenda.setTrackFocus":
            if case let .object(trackObject) = payload,
               case let .string(trackID)? = trackObject["trackId"] {
                activeTrackID = trackID
                recentActionSummary = "Track focus set to \(trackLabel(trackID))."
            }
        case "matchmaking.refreshRecommendations":
            recentActionSummary = "Recommendations refreshed locally in preview."
        case "matchmaking.setFilters":
            currentFilter = currentFilter == "All recommended people" ? "Identity and trust" : "All recommended people"
            recentActionSummary = "Matchmaking filter switched to \(currentFilter.lowercased())."
        case "matchmaking.searchPeople":
            if case let .object(searchObject) = payload,
               case let .string(query)? = searchObject["query"],
               !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchQuery = query
                recentActionSummary = "Search updated to '\(query)'."
            }
        case "matchmaking.focusPerson":
            if case let .object(personObject) = payload,
               case let .string(displayName)? = personObject["displayName"],
               displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                focusedRecommendationName = trimmed
                recentActionSummary = "Opened profile focus for \(trimmed) in local preview."
            }
        case "matchmaking.toggleFollowUp":
            if case let .object(personObject) = payload,
               case let .string(displayName)? = personObject["displayName"],
               displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                if followUpMarkedNames.contains(trimmed) {
                    followUpMarkedNames.remove(trimmed)
                    recentActionSummary = "Removed \(trimmed) from follow-up in local preview."
                } else {
                    followUpMarkedNames.insert(trimmed)
                    recentActionSummary = "Marked \(trimmed) for follow-up in local preview."
                }
            }
        case "discovery.refresh":
            recentActionSummary = "Discovery refreshed locally in preview."
        case "scheduling.createMeetingRequest":
            pendingRequestCount += 1
            recentActionSummary = "Added a new meeting request to the local preview queue."
        case "scheduling.exportICal":
            exportPrepared = true
            recentActionSummary = "iCal export is prepared in local preview."
        case "scheduling.respondMeetingRequest":
            if pendingRequestCount > 0 {
                pendingRequestCount -= 1
                confirmedMeetingCount += 1
            }
            recentActionSummary = "Updated meeting requests and confirmations."
        case "connections.postSharedMessage":
            if case let .object(messageObject) = payload,
               case let .string(text)? = messageObject["text"],
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let focusedThreadName = launchedDiscoveryChatNames.first ?? focusedRecommendationName ?? "Konferansekontakt"
                let persona = conferenceDemoPersona(named: focusedThreadName)
                let priorTurns = recentMessages.filter { $0.title == persona.name }.count
                prependRecentMessages([
                    ConferenceParticipantPreviewFallbackMessage(
                        title: persona.name,
                        subtitle: "Simulert deltager · \(persona.roleSummary)",
                        detail: conferenceDemoReply(to: text, persona: persona, priorTurns: priorTurns),
                        note: "Siste melding i delt tråd · \(persona.conversationStyle)"
                    ),
                    ConferenceParticipantPreviewFallbackMessage(
                        title: "Deg",
                        subtitle: "Sendt fra chatflaten",
                        detail: text,
                        note: "Siste melding i delt tråd"
                    )
                ])
                recentActionSummary = "La en oppfølgingsmelding i tråden med \(focusedThreadName). Simulert demosvar kom inn."
            }
        case "discovery.startChat":
            let targetNames = discoveryTargetNames(from: payload)
            if let firstTarget = targetNames.first {
                let persona = conferenceDemoPersona(named: firstTarget)
                launchedDiscoveryChatNames.removeAll { $0 == firstTarget }
                launchedDiscoveryChatNames.insert(firstTarget, at: 0)
                launchedDiscoveryChatNames = Array(launchedDiscoveryChatNames.prefix(4))
                prependRecentMessages([
                    ConferenceParticipantPreviewFallbackMessage(
                        title: persona.name,
                        subtitle: "Simulert deltager · \(persona.roleSummary)",
                        detail: conferenceDemoStarterReply(for: persona),
                        note: "Delt tråd er klar · \(persona.simulatedAgentSummary)"
                    ),
                    ConferenceParticipantPreviewFallbackMessage(
                        title: "Deg",
                        subtitle: "Startet fra deltagerportalen",
                        detail: conferenceDemoStarterMessage(for: persona),
                        note: "Chat startet i deltagerportalen"
                    )
                ])
                recentActionSummary = "Started follow-up chat with \(firstTarget) in local preview."
            } else {
                recentActionSummary = "Started a discovery chat in local preview."
            }
        case "discovery.startGroupChat":
            let targetNames = discoveryTargetNames(from: payload)
            if targetNames.isEmpty == false {
                let summary = targetNames.joined(separator: ", ")
                prependRecentMessages([
                    ConferenceParticipantPreviewFallbackMessage(
                        title: "Gruppechat",
                        subtitle: "Oppfølging klar",
                        detail: "Nearby group follow-up is ready with \(summary).",
                        note: "Siste melding i delt tråd"
                    ),
                    ConferenceParticipantPreviewFallbackMessage(
                        title: "Deg",
                        subtitle: "Neste steg",
                        detail: "Start med en kort introduksjon og avklar hva gruppen vil følge opp sammen.",
                        note: "Forslag til åpning"
                    )
                ])
                recentActionSummary = "Started a group chat with \(summary) in local preview."
            } else {
                recentActionSummary = "Started a discovery group chat in local preview."
            }
        default:
            recentActionSummary = "Utførte \(actionKeypath) i lokal conference-preview."
        }

        await persistCurrentState()

        return .object([
            "status": .string("ok"),
            "state": .object(makeStateObject())
        ])
    }

    private func prependRecentMessages(_ messages: [ConferenceParticipantPreviewFallbackMessage]) {
        for message in messages.reversed() {
            recentMessages.removeAll(where: { $0 == message })
            recentMessages.insert(message, at: 0)
        }
        recentMessages = Array(recentMessages.prefix(6))
    }

    private func makeStateObject() -> Object {
        let meetingSummary = "\(confirmedMeetingCount) shared meeting(s) visible."
        let requestSummary = "\(pendingRequestCount) shared request(s) visible."
        let trackSummary = activeTrackID == "all" ? "Track focus: all tracks visible." : "Track focus: \(trackLabel(activeTrackID))."
        let timelineSummary = timelineSummaryText(for: agendaView)
        let viewSummary = "Current view: \(viewLabel(agendaView))."
        let recommendedSummary = agendaView == "forYou"
            ? "Anbefalte sesjoner vises nå."
            : "6 anbefalte sesjoner er klare når du går tilbake til For deg."
        let savedSummary = agendaView == "saved"
            ? "Lagrede sesjoner vises nå."
            : "2 lagrede sesjoner er klare når du åpner Lagret."
        let persistenceStatus = "Agenda-valg lagres lokalt i deltagerportalen."
        let exportStatus = exportPrepared ? "iCal export is ready to share." : "No iCal export prepared yet."
        let activeChatCount = recentMessages.count
        let primaryChatName = launchedDiscoveryChatNames.first ?? "Conference follow-up"
        let focusedRecommendationSummary = focusedRecommendationName.map {
            "Focused recommendation: \($0). Open chat or mark follow-up when you are ready."
        } ?? "3 recommended people with explainability."
        let followUpSummary = followUpMarkedNames.isEmpty
            ? "No people marked for follow-up yet."
            : "\(followUpMarkedNames.count) person(s) marked for follow-up."
        let matchStatus = focusedRecommendationName.map {
            "Focused on \($0). The next natural step is to start chat or mark follow-up."
        } ?? "Recommendations are derived from onboarding interests, purpose signals, and optional track focus."
        let recentMessagesValue = recentMessages.map(\.value)
        let dynamicNearbyConnections = launchedDiscoveryChatNames.map { name in
            ValueType.object([
                "title": .string(name),
                "subtitle": .string("Nearby verified contact"),
                "detail": .string("Verified nearby encounter opened a discovery follow-up chat with \(activeChatCount) message(s) ready."),
                "note": .string("Scanner enriched · Chat klar"),
                "demoPersona": .object(conferenceDemoPersonaSeedObject(named: name))
            ])
        }
        let sharedIntro = activeChatCount > 0
            ? "Delt tråd med \(primaryChatName) er klar. Vis samtalen her og send neste oppfølging når det passer."
            : "Shared relation state is empty until a live thread or meeting is created."
        let sharedAccessSummary = activeChatCount > 0
            ? "Shared follow-up with \(primaryChatName) is available in local preview."
            : "No shared meeting/chat projection loaded."
        let agreementBoundary = activeChatCount > 0
            ? "Local preview agreement boundary for participant follow-up."
            : "No agreement boundary loaded."

        return [
            "workspace": .object([
                "title": .string("Conference Participant Portal"),
                "subtitle": .string("Profile, recommended people, and meetings in one low-friction flow."),
                "conferenceBadge": .string("AI & Digital Independence 2026"),
                "privacyBadge": .string("Private by default"),
                "participantBadge": .string("Conference Participant · Attendee · Independent attendee"),
                "programBadge": .string("2 saved sessions · 6 recommended sessions"),
                "matchBadge": .string("3 recommended people ready for review"),
                "meetingBadge": .string("\(pendingRequestCount) pending requests · \(confirmedMeetingCount) confirmed meetings · \(launchedDiscoveryChatNames.count) shared thread(s)"),
                "nextStep": .string(recentActionSummary),
                "previewNotice": .string("This shell is participant-only. Organizer insights and sponsor views live in separate conference shells.")
            ]),
            "program": .object([
                "intro": .string("Participant agenda stays local while the shell projects the most relevant conference sessions."),
                "agendaSummary": .string("2 saved session(s) · 6 recommended session(s)."),
                "viewSummary": .string(viewSummary),
                "trackSummary": .string(trackSummary),
                "timelineSummary": .string(timelineSummary),
                "status": .string("Agenda selections are ready for review."),
                "storageSummary": .string("Agenda selections stay local to the participant shell."),
                "persistenceStatus": .string(persistenceStatus),
                "recommendedSummary": .string(recommendedSummary),
                "savedSummary": .string(savedSummary),
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
                "intro": .string("These people match your current goals and conference interests."),
                "filterSummary": .string("Filter: \(currentFilter)."),
                "status": .string(matchStatus),
                "recommendationSummary": .string(focusedRecommendationSummary),
                "searchSummary": .string("Search broadening: \(searchQuery). \(followUpSummary)"),
                "recommendations": .list([
                    recommendationCard(title: "Ane Solberg", subtitle: "Public sector interoperability", detail: "Strong match on governance and delivery.", note: "92% match"),
                    recommendationCard(title: "Mads Hovden", subtitle: "Policy and compliance", detail: "Works with claims, trust, and organization.", note: "88% match"),
                    recommendationCard(title: "Lea Heger", subtitle: "Digital service design", detail: "Can connect the program to concrete product choices.", note: "84% match")
                ]),
                "searchResults": .list([
                    followUpConnectionCard(title: "Governance Forum", subtitle: "Nearby people", detail: "Found people mentioning \(searchQuery.lowercased()).", note: "Local preview"),
                    followUpConnectionCard(title: "Trust Infrastructure Lab", subtitle: "Shared interests", detail: "Shared focus on trust, claims, and operations.", note: "Suggested follow-up")
                ])
            ]),
            "discovery": .object([
                "intro": .string("Conference discovery combines portable participant discovery with local nearby enrichment."),
                "status": .string("Discovery is ready for follow-up."),
                "alignmentSummary": .string("Nearby and conference signals are aligned around \(currentFilter.lowercased())."),
                "proofSummary": .string("Verified follow-up can unlock richer purpose and interest matching."),
                "sourceSummary": .string("Portable conference candidates are merged with local nearby signals when available."),
                "publicProfileSummary": .string("Only minimal profile data is shown until you explicitly request more."),
                "chatSummary": .string("\(launchedDiscoveryChatNames.count) discovery chat(s) ready."),
                "nextAction": .string("Refresh discovery, review promising people, and start a follow-up chat when it feels right."),
                "refreshSummary": .string("Search focus is currently tuned for \(searchQuery.lowercased())."),
                "candidates": .list([
                    discoveryCandidateCard(title: "Ane Solberg", subtitle: "Public sector interoperability", detail: "Strong alignment on governance, delivery, and shared trust patterns.", note: "Recommended"),
                    discoveryCandidateCard(title: "Mads Hovden", subtitle: "Policy and compliance", detail: "Good match for claims, compliance, and organizer follow-up.", note: "Nearby-capable"),
                    discoveryCandidateCard(title: "Lea Heger", subtitle: "Digital service design", detail: "Connects participant needs to service and product design decisions.", note: "Suggested follow-up")
                ]),
                "proofCandidates": .list([
                    discoveryCandidateCard(title: "Shared Relations Forum", subtitle: "Proof-backed discovery", detail: "Participants who can expose stronger matching once contact is verified.", note: "Proof ready"),
                    discoveryCandidateCard(title: "Trust Infrastructure Lab", subtitle: "Policy and operations", detail: "Good candidate set for deeper follow-up if you want more precision.", note: "Consent gated")
                ]),
                "groupSuggestions": .list([
                    groupSuggestionCard(title: "Identity and Governance Circle", subtitle: "3 people", detail: "A small group with overlapping agenda and meeting goals.", note: "Suggested group chat"),
                    groupSuggestionCard(title: "Applied AI Follow-up", subtitle: "2 people", detail: "Focused on practical AI systems, trust, and delivery.", note: "Suggested nearby cluster")
                ])
            ]),
            "meetings": .object([
                "intro": .string("Keep availability local while requests, confirmed meetings, and follow-up chat live in shared relation records."),
                "requestSummary": .string(requestSummary),
                "slotSummary": .string("3 available slot(s) across Harbor Lounge, Hall B, Studio 2, Cafe, Garden, Library, AI Lab, Forum, Bridge."),
                "meetingSummary": .string(meetingSummary),
                "chatSummary": .string("\(activeChatCount) shared message(s) visible."),
                "exportStatus": .string(exportStatus),
                "requests": .list([]),
                "confirmedMeetings": .list([])
            ]),
            "sharedConnections": .object([
                "intro": .string(sharedIntro),
                "accessSummary": .string(sharedAccessSummary),
                "agreementBoundary": .string(agreementBoundary),
                "connectionSummary": .string("\(launchedDiscoveryChatNames.count) shared relation(s) visible."),
                "requestSummary": .string(requestSummary),
                "meetingSummary": .string(meetingSummary),
                "chatSummary": .string("\(activeChatCount) shared message(s) visible."),
                "connections": .list(dynamicNearbyConnections.map { $0 }),
                "confirmedMeetings": .list([]),
                "recentMessages": .list(recentMessagesValue)
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
            return "8 session(s) visible in timeline view."
        case "saved":
            return "2 saved session(s) visible in saved view."
        default:
            return "8 session(s) visible in for you view."
        }
    }

    private func trackLabel(_ trackID: String) -> String {
        switch trackID {
        case "all": return "all tracks visible"
        case "track-governance": return "Governance"
        case "track-identity": return "Identity"
        default: return "conference track"
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
        let isFocused = focusedRecommendationName == title
        let chatReady = launchedDiscoveryChatNames.contains(title)
        let actionLabel = isFocused ? (chatReady ? "Åpne chat" : "Start chat") : "Åpne profil"
        let actionPayload: ValueType = isFocused
            ? discoveryChatPayload(for: title, subtitle: subtitle)
            : .object([
                "displayName": .string(title),
                "subtitle": .string(subtitle)
            ])

        let actionKeypath = isFocused ? "discovery.startChat" : "matchmaking.focusPerson"
        let updatedNote: String
        if isFocused {
            updatedNote = chatReady ? "\(note) · Chat klar." : "\(note) · Profil fokusert."
        } else {
            updatedNote = "\(note) · Åpne profil for neste steg."
        }

        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(updatedNote),
            "demoPersona": .object(conferenceDemoPersonaSeedObject(named: title)),
            "keypath": .string("conferenceParticipantShell.dispatchAction"),
            "label": .string(actionLabel),
            "payload": .object([
                "keypath": .string(actionKeypath),
                "payload": actionPayload
            ])
        ])
    }

    private func timelineCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        sessionCard(title: title, subtitle: subtitle, detail: detail, note: note)
    }

    private func connectionCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        sessionCard(title: title, subtitle: subtitle, detail: detail, note: note)
    }

    private func discoveryCandidateCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        let chatReady = launchedDiscoveryChatNames.contains(title)
        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(chatReady ? "\(note) · Chat klar." : "\(note) · Start chat når du er klar."),
            "demoPersona": .object(conferenceDemoPersonaSeedObject(named: title)),
            "keypath": .string("conferenceParticipantShell.dispatchAction"),
            "label": .string(chatReady ? "Åpne chat" : "Start chat"),
            "payload": .object([
                "keypath": .string("discovery.startChat"),
                "payload": discoveryChatPayload(for: title, subtitle: subtitle)
            ])
        ])
    }

    private func followUpConnectionCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        let marked = followUpMarkedNames.contains(title)
        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(marked ? "\(note) · Markert for oppfølging." : "\(note) · Kan markeres for oppfølging."),
            "keypath": .string("conferenceParticipantShell.dispatchAction"),
            "label": .string(marked ? "Fjern markering" : "Marker for oppfølging"),
            "payload": .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
            ])
        ])
    }

    private func groupSuggestionCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string("\(note) · Start group chat when the group is ready."),
            "keypath": .string("conferenceParticipantShell.dispatchAction"),
            "label": .string("Start group chat"),
            "payload": .object([
                "keypath": .string("discovery.startGroupChat"),
                "payload": .object([
                    "source": .string("participant-portal-group-suggestion"),
                    "targets": .list([
                        .object([
                            "displayName": .string(title),
                            "headline": .string(subtitle)
                        ])
                    ])
                ])
            ])
        ])
    }

    private func discoveryChatPayload(for title: String, subtitle: String) -> ValueType {
        .object([
            "source": .string("participant-portal-recommendation"),
            "targets": .list([
                .object([
                    "displayName": .string(title),
                    "headline": .string(subtitle)
                ])
            ])
        ])
    }
}

@MainActor
private final class ConferenceParticipantAgendaSnapshotLocalCell: GeneralCell {
    private var cachedAgendaState: Object = ConferenceParticipantAgendaSnapshotLocalCell.defaultAgendaState()
    private var lastRefreshAt: Date?
    private var refreshTask: Task<Void, Never>?
    private var activeView = "forYou"
    private var activeTrackID = "all"
    private var recentActionSummary = "Velg hvordan agendaen skal vises. Endringen skjer i denne siden med en gang."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceParticipantAgendaSnapshotLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "refresh")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: false, forwardAction: nil, requester: requester)
            return .object(self.cachedAgendaState)
        })

        await addInterceptForSet(requester: owner, key: "refresh", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "refresh", for: requester) else { return .string("denied") }
            let refreshAction: ValueType = .object([
                "keypath": .string("agenda.setView"),
                "payload": .object([
                    "view": .string(self.activeView)
                ])
            ])
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: refreshAction, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedAgendaState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.handleDispatchAction(value, requester: requester)
        })

        Task { [weak self] in
            guard let self else { return }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: owner)
        }
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              let actionKeypath = string(from: object["keypath"]),
              actionKeypath.isEmpty == false else {
            cachedAgendaState = Self.agendaStateWithStatus(
                basedOn: cachedAgendaState,
                status: "Agenda-handlingen mangler keypath.",
                actionSummary: "Kunne ikke oppdatere agendaen fordi handlingspayloaden var ugyldig."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedAgendaState)
            ])
        }

        let payload = object["payload"] ?? .null

        switch actionKeypath {
        case "agenda.setView":
            if case let .object(viewObject) = payload,
               let view = string(from: viewObject["view"]),
               view.isEmpty == false {
                activeView = normalizedView(view)
                recentActionSummary = actionSummaryForView(activeView)
            }
        case "agenda.setTrackFocus":
            if case let .object(trackObject) = payload,
               let trackID = string(from: trackObject["trackId"]),
               trackID.isEmpty == false {
                activeTrackID = normalizedTrackID(trackID)
                recentActionSummary = actionSummaryForTrack(activeTrackID)
            }
        default:
            recentActionSummary = "Utførte \(actionKeypath) i agenda-snapshotet."
        }

        cachedAgendaState = mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true)
        let forwardedAction: ValueType = .object([
            "keypath": .string(actionKeypath),
            "payload": payload
        ])
        await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedAgendaState)
        ])
    }

    private func refreshSnapshotIfNeeded(
        force: Bool,
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        let shouldRetryImmediately = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
            cachedState: cachedAgendaState,
            statusKeys: ["storageSummary", "persistenceStatus"]
        )

        if !force,
           !shouldRetryImmediately,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 1 {
            return
        }

        if let refreshTask {
            await refreshTask.value
            let shouldRetryAfterInflight = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
                cachedState: cachedAgendaState,
                statusKeys: ["storageSummary", "persistenceStatus"]
            )
            if !force && !shouldRetryAfterInflight {
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(
                forwardAction: forwardAction,
                requester: requester
            )
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    @MainActor
    private func performRefresh(
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        await AppInitializer.initialize()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let porthole = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///Porthole",
                requester: requester
              ) as? Meddle else {
            cachedAgendaState = Self.agendaStateWithSyncWarning(
                basedOn: mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true),
                storageSummary: "Agenda-valg vises lokalt mens Porthole kobler seg til igjen.",
                persistenceStatus: "Kunne ikke synkronisere agendaen akkurat nå. Valget ditt vises fortsatt i denne siden."
            )
            lastRefreshAt = Date()
            return
        }

        if let forwardAction {
            let mutationResult = try? await porthole.set(
                keypath: "conferenceParticipantShell.dispatchAction",
                value: forwardAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedAgendaState = Self.agendaStateWithSyncWarning(
                    basedOn: mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true),
                    storageSummary: "Agenda-valget ditt vises lokalt mens vi prøver å synkronisere mot deltagerportalen.",
                    persistenceStatus: "Kunne ikke synkronisere agendahandlingen akkurat nå: \(errorDescription)"
                )
            }
        }

        do {
            let programValue = try await porthole.get(
                keypath: "conferenceParticipantShell.state.program",
                requester: requester
            )
            guard case let .object(programObject) = programValue else {
                cachedAgendaState = Self.agendaStateWithSyncWarning(
                    basedOn: mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true),
                    storageSummary: "Agendaen bruker siste stabile data mens deltagerportalen blir lesbar igjen.",
                    persistenceStatus: "Kunne ikke lese oppdatert agenda akkurat nå. Valget ditt vises fortsatt lokalt."
                )
                lastRefreshAt = Date()
                return
            }

            cachedAgendaState = mergedAgendaState(from: programObject)
            lastRefreshAt = Date()
        } catch {
            cachedAgendaState = Self.agendaStateWithSyncWarning(
                basedOn: mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true),
                storageSummary: "Agendaen viser siste stabile valg mens oppdateringen kobler seg til igjen.",
                persistenceStatus: "Kunne ikke hente oppdatert agenda akkurat nå: \(error)"
            )
            lastRefreshAt = Date()
        }
    }

    private func mergedAgendaState(from object: Object, preserveCurrentSelection: Bool = false) -> Object {
        var merged = Self.defaultAgendaState()
        for (key, value) in object {
            merged[key] = value
        }

        if !preserveCurrentSelection {
            synchronizeSelections(from: merged)
        }

        let rawTrackOptions = listObjects(from: merged["trackOptions"])
        let rawRecommended = listObjects(from: merged["recommendedSessions"])
        let rawSaved = listObjects(from: merged["savedSessions"])
        let rawTimeline = listObjects(from: merged["timelineSessions"])

        let trackOptions = rawTrackOptions.map { trackOptionCard(from: $0) }
        let recommendedSessions = rawRecommended.map { sessionCard(from: $0, category: .recommended) }
        let savedSessions = rawSaved.map { sessionCard(from: $0, category: .saved) }
        let timelineSessions = rawTimeline.map { sessionCard(from: $0, category: .timeline) }

        let activeViewLabel = viewLabel(activeView)
        let activeTrackLabel = trackLabel(activeTrackID)
        let activeViewCount = visibleSessionCount(
            recommendedCount: recommendedSessions.count,
            savedCount: savedSessions.count,
            timelineCount: timelineSessions.count
        )

        merged["intro"] = .string("Velg hvordan agendaen skal vises. Oppsummeringene under forklarer alltid hvilken visning og hvilket fokus som er aktivt akkurat nå.")
        merged["agendaSummary"] = .string("\(savedSessions.count) lagrede sesjoner · \(recommendedSessions.count) anbefalte sesjoner.")
        merged["viewSummary"] = .string("Aktiv visning: \(activeViewLabel).")
        merged["trackSummary"] = .string(activeTrackID == "all" ? "Aktivt spor: alle spor er synlige." : "Aktivt spor: \(activeTrackLabel).")
        merged["timelineSummary"] = .string(timelineSummaryText(for: activeView, visibleCount: activeViewCount))
        merged["status"] = .string(statusSummary(for: activeView, trackID: activeTrackID))
        merged["storageSummary"] = .string("Agenda-valg holdes stabile i deltagerportalen og speiles tilbake i denne siden.")
        merged["persistenceStatus"] = .string("Valgene dine blir husket lokalt, så siden ikke hopper når du bytter visning.")
        merged["recommendedSummary"] = .string("\(recommendedSessions.count) anbefalte sesjoner er klare når du bruker For deg.")
        merged["savedSummary"] = .string("\(savedSessions.count) lagrede sesjoner er klare når du åpner Lagret.")
        merged["statusSummary"] = .string(statusSummary(for: activeView, trackID: activeTrackID))
        merged["selectionSummary"] = .string("Viser \(activeViewLabel.lowercased()) med \(trackSelectionLabel(activeTrackID)).")
        merged["navigationSummary"] = .string("Knappene over bytter visning i denne siden med en gang. Handlingskortene under forklarer hva hver visning gjør.")
        merged["nextStepSummary"] = .string(nextStepSummary(for: activeView, trackID: activeTrackID))
        merged["actionSummary"] = .string(recentActionSummary)
        merged["modeChoices"] = .list(modeChoiceCards())
        merged["trackChoices"] = .list(trackChoiceCards())
        merged["trackOptions"] = .list(trackOptions)
        merged["recommendedSessions"] = .list(recommendedSessions)
        merged["savedSessions"] = .list(savedSessions)
        merged["timelineSessions"] = .list(timelineSessions)
        merged["focusedActions"] = .list(focusedActionCards())

        return merged
    }

    private func synchronizeSelections(from object: Object) {
        if let viewSummary = string(from: object["viewSummary"]) {
            activeView = inferredView(from: viewSummary)
        }
        if let trackSummary = string(from: object["trackSummary"]) {
            activeTrackID = inferredTrackID(from: trackSummary)
        }
    }

    private func modeChoiceCards() -> [ValueType] {
        [
            selectionChipCard(
                badge: activeView == "forYou" ? "AKTIV NÅ" : "MODUS",
                title: "For deg",
                subtitle: activeView == "forYou" ? "Anbefalingene dine vises nå" : "Anbefalte sesjoner først",
                detail: "Bruk denne når du vil tilbake til de mest relevante sesjonene for deg.",
                note: activeView == "forYou"
                    ? "For deg er aktiv i denne siden."
                    : "Bytter tilbake til anbefalt deltageragenda.",
                label: activeView == "forYou" ? "Viser nå" : "Vis for deg",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("forYou")])
            ),
            selectionChipCard(
                badge: activeView == "timeline" ? "AKTIV NÅ" : "MODUS",
                title: "Timeline",
                subtitle: activeView == "timeline" ? "Hele programmet vises nå" : "Hele programmet i rekkefølge",
                detail: "Bruk denne når du vil orientere deg i hele programflyten.",
                note: activeView == "timeline"
                    ? "Timeline er aktiv i denne siden."
                    : "Bytter til full tidslinje uten å forlate siden.",
                label: activeView == "timeline" ? "Viser nå" : "Vis timeline",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("timeline")])
            ),
            selectionChipCard(
                badge: activeView == "saved" ? "AKTIV NÅ" : "MODUS",
                title: "Lagret",
                subtitle: activeView == "saved" ? "Lagrede sesjoner vises nå" : "Bare det du har lagret",
                detail: "Bruk denne når du vil se bare det du allerede har valgt å ta vare på.",
                note: activeView == "saved"
                    ? "Lagret er aktiv i denne siden."
                    : "Bytter til kun lagrede sesjoner.",
                label: activeView == "saved" ? "Viser nå" : "Vis lagret",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("saved")])
            )
        ]
    }

    private func trackChoiceCards() -> [ValueType] {
        [
            selectionChipCard(
                badge: activeTrackID == "all" ? "FOKUS NÅ" : "SPOR",
                title: "Alle spor",
                subtitle: activeTrackID == "all" ? "Hele bredden er synlig" : "Slå av innsnevret fokus",
                detail: "Bruk denne når du vil se hele konferansebredden igjen.",
                note: activeTrackID == "all"
                    ? "Alle spor er synlige nå."
                    : "Går tilbake til full oversikt uten spor-fokus.",
                label: activeTrackID == "all" ? "Viser nå" : "Vis alle spor",
                actionKeypath: "agenda.setTrackFocus",
                payload: .object(["trackId": .string("all")])
            ),
            selectionChipCard(
                badge: activeTrackID == "track-governance" ? "FOKUS NÅ" : "SPOR",
                title: "Governance",
                subtitle: activeTrackID == "track-governance" ? "Governance er valgt nå" : "Snevr inn til governance",
                detail: "Bruk denne når du vil se governance-sporet tydeligere i agendaen.",
                note: activeTrackID == "track-governance"
                    ? "Governance er aktivt fokus i denne siden."
                    : "Setter governance i fokus uten å åpne en ny flate.",
                label: activeTrackID == "track-governance" ? "Viser nå" : "Fokuser governance",
                actionKeypath: "agenda.setTrackFocus",
                payload: .object(["trackId": .string("track-governance")])
            )
        ]
    }

    private func selectionChipCard(
        badge: String,
        title: String,
        subtitle: String,
        detail: String,
        note: String,
        label: String,
        actionKeypath: String,
        payload: ValueType
    ) -> ValueType {
        .object([
            "selectionBadge": .string(badge),
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "keypath": .string("agendaSnapshot.dispatchAction"),
            "label": .string(label),
            "payload": .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        ])
    }

    private func focusedActionCards() -> [ValueType] {
        [
            agendaActionCard(
                title: "For deg",
                subtitle: activeView == "forYou" ? "Vises nå" : "Anbefalte sesjoner først",
                detail: "Bruk denne når du vil se de mest relevante sesjonene for deg akkurat nå.",
                note: activeView == "forYou"
                    ? "For deg er aktiv. Herfra er neste steg å velge en sesjon eller fokusere et spor."
                    : "Bytter tilbake til den anbefalte deltageragendaen.",
                label: activeView == "forYou" ? "Viser nå" : "Vis for deg",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("forYou")])
            ),
            agendaActionCard(
                title: "Timeline",
                subtitle: activeView == "timeline" ? "Vises nå" : "Hele programmet i rekkefølge",
                detail: "Bruk denne når du vil se hele programflyten og orientere deg i konferansen.",
                note: activeView == "timeline"
                    ? "Timeline er aktiv. Nå ser du hele programmet i rekkefølge."
                    : "Bytter til den fulle tidslinjen for konferansen.",
                label: activeView == "timeline" ? "Viser nå" : "Vis timeline",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("timeline")])
            ),
            agendaActionCard(
                title: "Lagret",
                subtitle: activeView == "saved" ? "Vises nå" : "Bare sesjonene du har lagret",
                detail: "Bruk denne når du vil se bare det du allerede har valgt å ta vare på.",
                note: activeView == "saved"
                    ? "Lagret er aktiv. Nå ser du bare det du allerede har valgt."
                    : "Bytter til kun lagrede sesjoner.",
                label: activeView == "saved" ? "Viser nå" : "Vis lagret",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("saved")])
            ),
            agendaActionCard(
                title: activeTrackID == "track-governance" ? "Alle spor" : "Governance",
                subtitle: activeTrackID == "track-governance" ? "Slå av spor-fokus" : "Sett governance i fokus",
                detail: activeTrackID == "track-governance"
                    ? "Bruk denne når du vil gå tilbake til alle spor igjen."
                    : "Bruk denne når du vil se hva som er mest relevant innen governance.",
                note: activeTrackID == "track-governance"
                    ? "Governance er allerede fokusert. Neste steg er ofte å åpne timeline eller gå tilbake til alle spor."
                    : "Setter governance i fokus uten å forlate siden.",
                label: activeTrackID == "track-governance" ? "Vis alle spor" : "Fokuser governance",
                actionKeypath: "agenda.setTrackFocus",
                payload: .object(["trackId": .string(activeTrackID == "track-governance" ? "all" : "track-governance")])
            )
        ]
    }

    private func agendaActionCard(
        title: String,
        subtitle: String,
        detail: String,
        note: String,
        label: String,
        actionKeypath: String,
        payload: ValueType
    ) -> ValueType {
        .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "keypath": .string("agendaSnapshot.dispatchAction"),
            "label": .string(label),
            "payload": .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        ])
    }

    private func trackOptionCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let trackID = trackID(forTitle: title)
        let note: String
        if trackID == activeTrackID {
            note = "Aktivt fokus nå."
        } else if activeTrackID == "all" {
            note = "Tilgjengelig for fokus."
        } else {
            note = "Tilgjengelig, men ikke i aktivt fokus nå."
        }

        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note)
        ])
    }

    private enum SessionCategory {
        case recommended
        case saved
        case timeline
    }

    private func sessionCard(from raw: Object, category: SessionCategory) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let note = sessionNote(baseNote: cardNote(from: raw), category: category)

        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note)
        ])
    }

    private func sessionNote(baseNote: String, category: SessionCategory) -> String {
        switch category {
        case .recommended:
            return activeView == "forYou" ? "\(baseNote) · Vises nå i For deg." : "\(baseNote) · Klar når du går til For deg."
        case .saved:
            return activeView == "saved" ? "\(baseNote) · Vises nå i Lagret." : "\(baseNote) · Klar når du åpner Lagret."
        case .timeline:
            return activeView == "timeline" ? "\(baseNote) · Vises nå i Timeline." : "\(baseNote) · Klar når du åpner Timeline."
        }
    }

    private func visibleSessionCount(recommendedCount: Int, savedCount: Int, timelineCount: Int) -> Int {
        switch activeView {
        case "timeline":
            return timelineCount
        case "saved":
            return savedCount
        default:
            return recommendedCount
        }
    }

    private func statusSummary(for view: String, trackID: String) -> String {
        switch (view, trackID) {
        case ("timeline", "track-governance"):
            return "Viser timeline med governance i fokus."
        case ("timeline", _):
            return "Viser timeline med alle spor tilgjengelige."
        case ("saved", "track-governance"):
            return "Viser lagrede sesjoner med governance i fokus."
        case ("saved", _):
            return "Viser bare lagrede sesjoner akkurat nå."
        case (_, "track-governance"):
            return "Viser anbefalte sesjoner med governance i fokus."
        default:
            return "Viser anbefalte sesjoner med alle spor tilgjengelige."
        }
    }

    private func nextStepSummary(for view: String, trackID: String) -> String {
        switch (view, trackID) {
        case ("timeline", "track-governance"):
            return "Neste steg er å velge en governance-sesjon eller slå av spor-fokus for å se hele bredden igjen."
        case ("timeline", _):
            return "Neste steg er å velge en sesjon fra timeline eller fokusere et spor for å snevre inn oversikten."
        case ("saved", _):
            return "Neste steg er å bekrefte hva du faktisk vil delta på, eller gå tilbake til For deg for nye forslag."
        case (_, "track-governance"):
            return "Neste steg er å se hvilke governance-sesjoner som nå er mest relevante, eller åpne timeline for mer kontekst."
        default:
            return "Neste steg er å velge en anbefalt sesjon, åpne timeline, eller fokusere governance hvis du vil snevre inn."
        }
    }

    private func timelineSummaryText(for view: String, visibleCount: Int) -> String {
        switch view {
        case "timeline":
            return "\(visibleCount) sesjoner vises i timeline akkurat nå."
        case "saved":
            return "\(visibleCount) lagrede sesjoner vises akkurat nå."
        default:
            return "\(visibleCount) anbefalte sesjoner vises akkurat nå."
        }
    }

    private func trackSelectionLabel(_ trackID: String) -> String {
        trackID == "all" ? "alle spor synlige" : "\(trackLabel(trackID)) i fokus"
    }

    private func actionSummaryForView(_ view: String) -> String {
        switch view {
        case "timeline":
            return "Viser timeline i denne siden."
        case "saved":
            return "Viser lagrede sesjoner i denne siden."
        default:
            return "Viser anbefalte sesjoner for deg i denne siden."
        }
    }

    private func actionSummaryForTrack(_ trackID: String) -> String {
        trackID == "all"
            ? "Viser alle spor igjen."
            : "Governance er nå i fokus i denne siden."
    }

    private func viewLabel(_ view: String) -> String {
        switch normalizedView(view) {
        case "timeline": return "Timeline"
        case "saved": return "Lagret"
        default: return "For deg"
        }
    }

    private func trackLabel(_ trackID: String) -> String {
        switch normalizedTrackID(trackID) {
        case "track-governance":
            return "Governance"
        case "track-identity":
            return "Identity"
        default:
            return "alle spor"
        }
    }

    private func normalizedView(_ view: String) -> String {
        let normalized = view.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "timeline":
            return "timeline"
        case "saved":
            return "saved"
        default:
            return "forYou"
        }
    }

    private func normalizedTrackID(_ trackID: String) -> String {
        let normalized = trackID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "track-governance", "governance":
            return "track-governance"
        case "track-identity", "identity":
            return "track-identity"
        default:
            return "all"
        }
    }

    private func inferredView(from summary: String) -> String {
        let normalized = summary.lowercased()
        if normalized.contains("timeline") {
            return "timeline"
        }
        if normalized.contains("lagret") || normalized.contains("saved") {
            return "saved"
        }
        return "forYou"
    }

    private func inferredTrackID(from summary: String) -> String {
        let normalized = summary.lowercased()
        if normalized.contains("governance") {
            return "track-governance"
        }
        if normalized.contains("identity") {
            return "track-identity"
        }
        return "all"
    }

    private func trackID(forTitle title: String) -> String {
        let normalized = title.lowercased()
        if normalized.contains("governance") {
            return "track-governance"
        }
        if normalized.contains("identity") {
            return "track-identity"
        }
        return "all"
    }

    private func cardTitle(from object: Object) -> String {
        string(from: object["title"]) ?? "Ukjent kort"
    }

    private func cardSubtitle(from object: Object) -> String {
        string(from: object["subtitle"]) ?? "Ingen undertittel"
    }

    private func cardDetail(from object: Object) -> String {
        string(from: object["detail"]) ?? "Ingen detalj tilgjengelig."
    }

    private func cardNote(from object: Object) -> String {
        string(from: object["note"]) ?? "Ingen ekstra agenda-kontekst tilgjengelig ennå."
    }

    private func listObjects(from value: ValueType?) -> [Object] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap {
            guard case let .object(object) = $0 else { return nil }
            return object
        }
    }

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        guard let value else { return "Ukjent agenda-feil." }
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

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(string):
            return string
        case let .integer(integer):
            return String(integer)
        case let .number(number):
            return String(number)
        case let .float(float):
            return String(float)
        case let .bool(bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private static func agendaStateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["status"] = .string(status)
        updated["statusSummary"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        updated["nextStepSummary"] = .string(actionSummary)
        return updated
    }

    private static func agendaStateWithSyncWarning(
        basedOn base: Object,
        storageSummary: String,
        persistenceStatus: String
    ) -> Object {
        var updated = base
        updated["storageSummary"] = .string(storageSummary)
        updated["persistenceStatus"] = .string(persistenceStatus)
        return updated
    }

    private static func defaultAgendaState() -> Object {
        [
            "intro": .string("Velg hvordan agendaen skal vises. Oppsummeringene under forklarer alltid hvilken visning og hvilket fokus som er aktivt akkurat nå."),
            "agendaSummary": .string("2 lagrede sesjoner · 6 anbefalte sesjoner."),
            "viewSummary": .string("Aktiv visning: For deg."),
            "trackSummary": .string("Aktivt spor: alle spor er synlige."),
            "timelineSummary": .string("3 anbefalte sesjoner vises akkurat nå."),
            "status": .string("Viser anbefalte sesjoner med alle spor tilgjengelige."),
            "storageSummary": .string("Agenda-valg holdes stabile i deltagerportalen og speiles tilbake i denne siden."),
            "persistenceStatus": .string("Valgene dine blir husket lokalt, så siden ikke hopper når du bytter visning."),
            "recommendedSummary": .string("3 anbefalte sesjoner er klare når du bruker For deg."),
            "savedSummary": .string("2 lagrede sesjoner er klare når du åpner Lagret."),
            "statusSummary": .string("Viser anbefalte sesjoner med alle spor tilgjengelige."),
            "selectionSummary": .string("Viser for deg med alle spor synlige."),
            "navigationSummary": .string("Knappene over bytter visning i denne siden med en gang. Handlingskortene under forklarer hva hver visning gjør."),
            "nextStepSummary": .string("Neste steg er å velge en anbefalt sesjon, åpne timeline, eller fokusere governance hvis du vil snevre inn."),
            "actionSummary": .string("Velg hvordan agendaen skal vises. Endringen skjer i denne siden med en gang."),
            "trackOptions": .list([
                .object([
                    "title": .string("Applied AI"),
                    "subtitle": .string("4 sesjoner"),
                    "detail": .string("Praktiske AI-systemer og verktøy."),
                    "note": .string("Tilgjengelig for fokus.")
                ]),
                .object([
                    "title": .string("Identity"),
                    "subtitle": .string("4 sesjoner"),
                    "detail": .string("Tillit, verifikasjon og claims."),
                    "note": .string("Tilgjengelig for fokus.")
                ]),
                .object([
                    "title": .string("Governance"),
                    "subtitle": .string("4 sesjoner"),
                    "detail": .string("Policy, regulering og koordinering."),
                    "note": .string("Tilgjengelig for fokus.")
                ])
            ]),
            "recommendedSessions": .list([
                .object([
                    "title": .string("Identity Session 8"),
                    "subtitle": .string("Identity · 09:30-10:00"),
                    "detail": .string("Forum: identity, AI and digital independence."),
                    "note": .string("Matches interests")
                ]),
                .object([
                    "title": .string("Governance Session 15"),
                    "subtitle": .string("Governance · 10:00-10:30"),
                    "detail": .string("Library: governance, AI and digital independence."),
                    "note": .string("Visible in current view")
                ]),
                .object([
                    "title": .string("Infra Session 3"),
                    "subtitle": .string("Infra · 13:00-13:30"),
                    "detail": .string("Shared infrastructure and deployment patterns."),
                    "note": .string("Recommended next")
                ])
            ]),
            "savedSessions": .list([
                .object([
                    "title": .string("Opening keynote"),
                    "subtitle": .string("Main stage · 08:30"),
                    "detail": .string("Framing digital independence across sectors."),
                    "note": .string("Saved")
                ]),
                .object([
                    "title": .string("Shared relations roundtable"),
                    "subtitle": .string("Studio 2 · 11:15"),
                    "detail": .string("Operational follow-up between ecosystem teams."),
                    "note": .string("Saved")
                ])
            ]),
            "timelineSessions": .list([
                .object([
                    "title": .string("Governance Session 3"),
                    "subtitle": .string("Studio 2 · 08:00"),
                    "detail": .string("Governance, AI and digital independence."),
                    "note": .string("Visible in timeline")
                ]),
                .object([
                    "title": .string("Identity Session 2"),
                    "subtitle": .string("Hall B · 08:30"),
                    "detail": .string("Identity, AI and digital independence."),
                    "note": .string("Visible in timeline")
                ]),
                .object([
                    "title": .string("Governance Session 9"),
                    "subtitle": .string("Bridge · 09:00"),
                    "detail": .string("Cross-team governance patterns."),
                    "note": .string("Visible in timeline")
                ])
            ]),
            "focusedActions": .list([])
        ]
    }
}

@MainActor
private final class ConferenceParticipantDiscoverySnapshotLocalCell: GeneralCell {
    private var cachedDiscoveryState: Object = ConferenceParticipantDiscoverySnapshotLocalCell.defaultDiscoveryState()
    private var lastRefreshAt: Date?
    private var refreshTask: Task<Void, Never>?
    private var storeKey = ""
    private var focusedDiscoveryName: String?
    private var followUpMarkedNames: Set<String> = []
    private var launchedDiscoveryChatNames: [String] = []
    private var recentActionSummary = "Trykk Vis i siden for å fokusere på en person i discovery."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceParticipantDiscoverySnapshotLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        storeKey = owner.uuid
        await restoreSelectedParticipantIfAvailable()
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "refresh")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: false, forwardAction: nil, requester: requester)
            return .object(self.cachedDiscoveryState)
        })

        await addInterceptForSet(requester: owner, key: "refresh", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "refresh", for: requester) else { return .string("denied") }
            let refreshPayload: ValueType = .object([
                "keypath": .string("discovery.refresh"),
                "payload": .bool(true)
            ])
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: refreshPayload, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedDiscoveryState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.handleDispatchAction(value, requester: requester)
        })

        Task { [weak self] in
            guard let self else { return }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: owner)
        }
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              let actionKeypath = string(from: object["keypath"]),
              actionKeypath.isEmpty == false else {
            cachedDiscoveryState = Self.discoveryStateWithStatus(
                basedOn: cachedDiscoveryState,
                status: "Discovery-handlingen mangler keypath.",
                actionSummary: "Kunne ikke oppdatere discovery fordi action-payloaden var ugyldig."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedDiscoveryState)
            ])
        }

        let payload = object["payload"] ?? .null
        var forwardedAction: ValueType?

        switch actionKeypath {
        case "refresh", "discovery.refresh":
            recentActionSummary = "Oppdaterte discovery-snapshotet."
            forwardedAction = .object([
                "keypath": .string("discovery.refresh"),
                "payload": .bool(true)
            ])
        case "discovery.focusPerson":
            if case let .object(personObject) = payload,
               let displayName = string(from: personObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedDiscoveryName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Viser \(displayName) i discovery-delen."
            }
        case "matchmaking.toggleFollowUp":
            if case let .object(personObject) = payload,
               let displayName = string(from: personObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedDiscoveryName = displayName
                await rememberSelectedParticipant(displayName)
                if followUpMarkedNames.contains(displayName) {
                    followUpMarkedNames.remove(displayName)
                    recentActionSummary = "Fjernet \(displayName) fra oppfølging."
                } else {
                    followUpMarkedNames.insert(displayName)
                    recentActionSummary = "Markerte \(displayName) for oppfølging."
                }
                forwardedAction = .object([
                    "keypath": .string(actionKeypath),
                    "payload": payload
                ])
            }
        case "discovery.startChat":
            let targetNames = discoveryTargetNames(from: payload)
            if let firstTarget = targetNames.first {
                focusedDiscoveryName = firstTarget
                await rememberSelectedParticipant(firstTarget)
                recentActionSummary = "Starter chat med \(firstTarget) fra discovery…"
            } else {
                recentActionSummary = "Starter chat fra discovery…"
            }
            forwardedAction = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        case "scheduling.createMeetingRequest":
            if let focusedDiscoveryName {
                recentActionSummary = "La til møteforespørsel for \(focusedDiscoveryName)."
            } else {
                recentActionSummary = "La til en ny møteforespørsel fra discovery."
            }
            forwardedAction = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        case "discovery.startGroupChat":
            recentActionSummary = "Startet gruppesamtale fra discovery."
            forwardedAction = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        default:
            recentActionSummary = "Utførte \(actionKeypath) i discovery-snapshotet."
            forwardedAction = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        }

        cachedDiscoveryState = mergedDiscoveryState(from: cachedDiscoveryState)
        await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedDiscoveryState)
        ])
    }

    private func refreshSnapshotIfNeeded(
        force: Bool,
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        let shouldRetryImmediately = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
            cachedState: cachedDiscoveryState,
            statusKeys: ["status", "actionSummary", "sourceSummary"]
        )

        if !force,
           !shouldRetryImmediately,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 1 {
            return
        }

        if let refreshTask {
            await refreshTask.value
            let shouldRetryAfterInflight = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
                cachedState: cachedDiscoveryState,
                statusKeys: ["status", "actionSummary", "sourceSummary"]
            )
            if !force && !shouldRetryAfterInflight {
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(
                forwardAction: forwardAction,
                requester: requester
            )
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    @MainActor
    private func performRefresh(
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        await AppInitializer.initialize()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            cachedDiscoveryState = Self.discoveryStateWithStatus(
                basedOn: cachedDiscoveryState,
                status: "Discovery bruker siste lokale snapshot fordi resolver mangler.",
                actionSummary: "Kunne ikke oppdatere discovery akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        guard let previewShell = try? await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: requester
        ) as? Meddle else {
            cachedDiscoveryState = Self.discoveryStateWithStatus(
                basedOn: cachedDiscoveryState,
                status: "Discovery bruker siste lokale snapshot fordi ingen preview-shell er tilgjengelig.",
                actionSummary: "Kunne ikke oppdatere discovery akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        if let forwardAction {
            let mutationResult = try? await previewShell.set(
                keypath: "dispatchAction",
                value: forwardAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedDiscoveryState = Self.discoveryStateWithStatus(
                    basedOn: cachedDiscoveryState,
                    status: "Discovery beholdt siste stabile snapshot fordi preview-handlingen feilet.",
                    actionSummary: errorDescription
                )
            }
        }

        do {
            let stateValue = try await previewShell.get(
                keypath: "state",
                requester: requester
            )
            guard case let .object(stateObject) = stateValue,
                  case let .object(discoveryObject)? = stateObject["discovery"] else {
                cachedDiscoveryState = Self.discoveryStateWithStatus(
                    basedOn: cachedDiscoveryState,
                    status: "Discovery returnerte ikke et lesbart preview-snapshot.",
                    actionSummary: "Bruker siste stabile data."
                )
                lastRefreshAt = Date()
                return
            }

            let sharedConnections = conferenceObject(from: stateObject["sharedConnections"])
            synchronizeLaunchedChats(
                from: sharedConnections,
                forwardedAction: forwardAction
            )

            var mergedDiscovery = mergedDiscoveryState(from: discoveryObject)
            mergedDiscovery["sourceSummary"] = .string("Discovery bruker lokal preview i Binding for å holde deltagerportalen stabil mens øvrige data kobler seg til.")
            cachedDiscoveryState = mergedDiscovery
            lastRefreshAt = Date()
        } catch {
            cachedDiscoveryState = Self.discoveryStateWithStatus(
                basedOn: cachedDiscoveryState,
                status: "Discovery bruker siste stabile snapshot.",
                actionSummary: "Kunne ikke hente oppdatert discovery akkurat nå: \(error)"
            )
            lastRefreshAt = Date()
        }
    }

    private func synchronizeLaunchedChats(
        from sharedConnections: Object?,
        forwardedAction: ValueType?
    ) {
        let sharedNames = conferenceSharedConnectionNames(from: sharedConnections)
        launchedDiscoveryChatNames = sharedNames

        guard conferenceActionKeypath(from: forwardedAction) == "discovery.startChat" else {
            return
        }

        let targetNames = discoveryTargetNames(from: conferenceActionPayload(from: forwardedAction) ?? .null)
        guard let firstTarget = targetNames.first else {
            return
        }

        if sharedNames.contains(firstTarget) {
            recentActionSummary = "Chatten med \(firstTarget) er klar."
        } else {
            recentActionSummary = "Chatten med \(firstTarget) ble ikke klar ennå. Prøv Start chat igjen."
        }
    }

    private func mergedDiscoveryState(from object: Object) -> Object {
        var merged = Self.defaultDiscoveryState()
        for (key, value) in object {
            merged[key] = value
        }

        let candidateRows = listObjects(from: merged["candidates"])
        let proofCandidateRows = listObjects(from: merged["proofCandidates"])
        let groupRows = listObjects(from: merged["groupSuggestions"])
        let derivedCandidates = candidateRows.map { discoveryCandidateCard(from: $0) }
        let derivedProofCandidates = proofCandidateRows.map { discoveryCandidateCard(from: $0) }
        let derivedGroupSuggestions = groupRows.map { groupSuggestionCard(from: $0) }
        let focusedCard = focusedDiscoveryCard(
            candidates: candidateRows,
            proofCandidates: proofCandidateRows
        )

        merged["candidates"] = .list(derivedCandidates)
        merged["proofCandidates"] = .list(derivedProofCandidates)
        merged["groupSuggestions"] = .list(derivedGroupSuggestions)
        merged["statusSummary"] = .string(statusSummary(for: candidateRows, proofCandidates: proofCandidateRows))
        merged["selectionSummary"] = .string(selectionSummary(for: focusedCard))
        merged["navigationSummary"] = .string(navigationSummary(for: focusedCard))
        merged["nextStepSummary"] = .string(nextStepSummary(for: focusedCard))
        merged["actionSummary"] = .string(recentActionSummary)
        merged["focusedProfile"] = .object(focusedProfileObject(from: focusedCard, publicProfileSummary: string(from: merged["publicProfileSummary"])))
        merged["focusedActions"] = .list(focusedActionCards(for: focusedCard))

        if string(from: merged["status"])?.isEmpty != false {
            merged["status"] = .string("Discovery er klar for oppfølging.")
        }
        if string(from: merged["refreshSummary"])?.isEmpty != false {
            merged["refreshSummary"] = .string("Discovery-snapshotet er oppdatert lokalt.")
        }

        return merged
    }

    private func discoveryCandidateCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let baseNote = cardNote(from: raw)
        let isFocused = focusedDiscoveryName == title
        let chatReady = launchedDiscoveryChatNames.contains(title)
        let label = isFocused ? (chatReady ? "Åpne chatflate" : "Start chat") : "Vis i siden"
        let actionKeypath = isFocused
            ? (chatReady ? "openChatWorkbench" : "discovery.startChat")
            : "discovery.focusPerson"
        let note: String
        if isFocused {
            note = chatReady ? "\(baseNote) · Chat klar i egen flate." : "\(baseNote) · Vises i discovery nå."
        } else {
            note = "\(baseNote) · Trykk Vis i siden for å fokusere."
        }

        let payload: ValueType = isFocused
            ? (chatReady
                ? .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
                : discoveryChatPayload(for: title, subtitle: subtitle))
            : .object([
                "displayName": .string(title),
                "subtitle": .string(subtitle)
            ])

        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "demoPersona": raw["demoPersona"] ?? .object(conferenceDemoPersonaSeedObject(named: title)),
            "keypath": .string(isFocused && chatReady ? "chatSnapshot.dispatchAction" : "discoverySnapshot.dispatchAction"),
            "label": .string(label),
            "payload": .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        ])
    }

    private func groupSuggestionCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let note = "\(cardNote(from: raw)) · Åpner gruppesamtale når gruppen er klar."
        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "keypath": .string("discoverySnapshot.dispatchAction"),
            "label": .string("Start gruppesamtale"),
            "payload": .object([
                "keypath": .string("discovery.startGroupChat"),
                "payload": .object([
                    "source": .string("binding-discovery-snapshot"),
                    "targets": .list([
                        .object([
                            "displayName": .string(title),
                            "headline": .string(subtitle)
                        ])
                    ])
                ])
            ])
        ])
    }

    private func statusSummary(for candidates: [Object], proofCandidates: [Object]) -> String {
        if candidates.isEmpty && proofCandidates.isEmpty {
            return "Ingen discovery-kandidater er klare ennå."
        }
        return "\(candidates.count) åpne kandidater og \(proofCandidates.count) proof-klare kandidater er klare for gjennomgang."
    }

    private func selectionSummary(for focusedCard: Object?) -> String {
        guard let focusedCard else {
            return "Trykk Vis i siden på en discovery-kandidat for å fokusere på personen her."
        }
        return "Viser \(cardTitle(from: focusedCard)) i discovery-delen."
    }

    private func navigationSummary(for focusedCard: Object?) -> String {
        if focusedCard == nil {
            return "Første klikk skjer i denne siden. Du trenger ikke åpne en egen arbeidsflate for å se hvem discovery-kortet gjelder."
        }
        return "Du ser nå valgt discovery-deltaker i denne siden. Herfra kan du starte chat, markere oppfølging eller be om møte."
    }

    private func nextStepSummary(for focusedCard: Object?) -> String {
        guard let focusedCard else {
            return "Velg en discovery-kandidat med Vis i siden før du tar neste steg."
        }
        let title = cardTitle(from: focusedCard)
        if launchedDiscoveryChatNames.contains(title) {
            return "Chatten med \(title) er klar. Neste steg er å åpne chatten eller be om møte."
        }
        if followUpMarkedNames.contains(title) {
            return "\(title) er markert for oppfølging. Neste steg er å starte chat eller be om møte."
        }
        return "Neste steg for \(title) er å starte chat, markere oppfølging eller be om møte."
    }

    private func focusedProfileObject(from focusedCard: Object?, publicProfileSummary: String?) -> Object {
        let publicSummary = publicProfileSummary ?? "Bare minimal offentlig profil vises til du ber om mer."
        guard let focusedCard else {
            return [
                "selectionBadge": .string("VALGT I DISCOVERY"),
                "title": .string("Ingen deltaker valgt ennå"),
                "subtitle": .string("Entity Discovery"),
                "detail": .string("Trykk Vis i siden på en discovery-kandidat for å se personens offentlige og lokale oppsummering her."),
                "note": .string(publicSummary),
                "publicProfileSummary": .string(publicSummary),
                "profileDetail": .string("Vi viser offentlig profil, lokal begrunnelse og neste steg når en kandidat er valgt."),
                "fitSummary": .string("Ingen discovery-kandidat er valgt ennå."),
                "nextStep": .string("Velg en kandidat først, og bruk deretter chat, oppfølging eller møte."),
                "conversationStyle": .string("Når en kandidat er valgt, viser vi hvordan demo-personaen typisk svarer i chat."),
                "openingPrompt": .string("Velg en kandidat først for å se et godt forslag til åpningsmelding."),
                "simulationSummary": .string("Demo-svarene er bounded og følger valgt deltagerprofil.")
            ]
        }

        let persona = conferenceDemoPersona(named: cardTitle(from: focusedCard), source: focusedCard)
        return [
            "selectionBadge": .string("VALGT I DISCOVERY"),
            "title": .string(cardTitle(from: focusedCard)),
            "subtitle": .string(cardSubtitle(from: focusedCard)),
            "detail": .string(cardDetail(from: focusedCard)),
            "note": .string("\(cardNote(from: focusedCard)) · \(publicSummary)"),
            "publicProfileSummary": .string(publicSummary),
            "profileDetail": .string("Offentlig profil: \(cardSubtitle(from: focusedCard)). \(cardDetail(from: focusedCard)) \(persona.publicProfileDetail)"),
            "fitSummary": .string(cardNote(from: focusedCard)),
            "nextStep": .string("Bruk Start chat, Marker for oppfølging eller Be om møte med \(cardTitle(from: focusedCard))."),
            "conversationStyle": .string(persona.conversationStyle),
            "openingPrompt": .string(persona.suggestedOpening),
            "simulationSummary": .string(persona.simulatedAgentSummary)
        ]
    }

    private func focusedActionCards(for focusedCard: Object?) -> [ValueType] {
        guard let focusedCard else { return [] }
        let title = cardTitle(from: focusedCard)
        let subtitle = cardSubtitle(from: focusedCard)
        let chatReady = launchedDiscoveryChatNames.contains(title)
        let followUpMarked = followUpMarkedNames.contains(title)

        let chatAction: ValueType = .object([
            "title": .string("Chat"),
            "subtitle": .string(chatReady ? "Fortsett discovery-chatten" : "Start discovery-chat"),
            "detail": .string(chatReady ? "Åpne chatflaten med \(title) og fortsett oppfølgingen." : "Start en discovery-chat med \(title) fra denne siden."),
            "note": .string("Dette er det tydeligste neste steget når discovery-kandidaten virker lovende."),
            "keypath": .string(chatReady ? "chatSnapshot.dispatchAction" : "discoverySnapshot.dispatchAction"),
            "label": .string(chatReady ? "Åpne chatflate" : "Start chat"),
            "payload": .object([
                "keypath": .string(chatReady ? "openChatWorkbench" : "discovery.startChat"),
                "payload": chatReady
                    ? .object([
                        "displayName": .string(title),
                        "subtitle": .string(subtitle)
                    ])
                    : discoveryChatPayload(for: title, subtitle: subtitle)
            ])
        ])

        let followUpAction: ValueType = .object([
            "title": .string("Oppfølging"),
            "subtitle": .string(followUpMarked ? "Allerede markert" : "Marker neste steg"),
            "detail": .string(followUpMarked ? "\(title) er markert for oppfølging." : "Marker \(title) for oppfølging så discovery-sporet blir lett å komme tilbake til."),
            "note": .string("Bruk dette når du vil holde fast i kandidaten uten å starte chat med en gang."),
            "keypath": .string("discoverySnapshot.dispatchAction"),
            "label": .string(followUpMarked ? "Fjern markering" : "Marker for oppfølging"),
            "payload": .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
            ])
        ])

        let meetingAction: ValueType = .object([
            "title": .string("Møte"),
            "subtitle": .string("Foreslå et konkret neste steg"),
            "detail": .string("Be om møte med \(title) hvis du vil gå fra discovery til konkret plan."),
            "note": .string("Bra når du allerede vet at kandidaten er relevant og vil sette opp et faktisk møtetidspunkt."),
            "keypath": .string("discoverySnapshot.dispatchAction"),
            "label": .string("Be om møte"),
            "payload": .object([
                "keypath": .string("scheduling.createMeetingRequest"),
                "payload": .object([
                    "source": .string("binding-discovery-snapshot"),
                    "displayName": .string(title)
                ])
            ])
        ])

        return [chatAction, followUpAction, meetingAction]
    }

    private func focusedDiscoveryCard(candidates: [Object], proofCandidates: [Object]) -> Object? {
        guard let focusedDiscoveryName else { return nil }
        if let candidate = candidates.first(where: { cardTitle(from: $0) == focusedDiscoveryName }) {
            return candidate
        }
        if let proofCandidate = proofCandidates.first(where: { cardTitle(from: $0) == focusedDiscoveryName }) {
            return proofCandidate
        }
        return nil
    }

    private func listObjects(from value: ValueType?) -> [Object] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap {
            guard case let .object(object) = $0 else { return nil }
            return object
        }
    }

    private func restoreSelectedParticipantIfAvailable() async {
        guard focusedDiscoveryName == nil,
              !storeKey.isEmpty,
              let storedSelection = await ConferenceParticipantSelectionStore.shared.load(for: storeKey) else {
            return
        }
        focusedDiscoveryName = storedSelection
    }

    private func rememberSelectedParticipant(_ displayName: String?) async {
        guard !storeKey.isEmpty else { return }
        await ConferenceParticipantSelectionStore.shared.save(displayName, for: storeKey)
    }

    private func cardTitle(from object: Object) -> String {
        string(from: object["title"]) ??
        string(from: object["displayName"]) ??
        "Ukjent deltaker"
    }

    private func cardSubtitle(from object: Object) -> String {
        string(from: object["subtitle"]) ??
        string(from: object["headline"]) ??
        "Discovery-kandidat"
    }

    private func cardDetail(from object: Object) -> String {
        string(from: object["detail"]) ??
        "Ingen detalj tilgjengelig."
    }

    private func cardNote(from object: Object) -> String {
        string(from: object["note"]) ??
        "Ingen ekstra discovery-kontekst tilgjengelig ennå."
    }

    private func discoveryChatPayload(for title: String, subtitle: String) -> ValueType {
        .object([
            "source": .string("binding-discovery-snapshot"),
            "targets": .list([
                .object([
                    "displayName": .string(title),
                    "headline": .string(subtitle)
                ])
            ])
        ])
    }

    private func discoveryTargetNames(from payload: ValueType) -> [String] {
        guard case let .object(payloadObject) = payload else { return [] }
        if case let .list(targets)? = payloadObject["targets"] {
            let names = targets.compactMap { target -> String? in
                guard case let .object(targetObject) = target else { return nil }
                if let displayName = string(from: targetObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                   displayName.isEmpty == false {
                    return displayName
                }
                if let participantId = string(from: targetObject["participantId"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                   participantId.isEmpty == false {
                    return participantId
                }
                return nil
            }
            if names.isEmpty == false {
                return names
            }
        }
        if case let .list(participantIds)? = payloadObject["participantIds"] {
            return participantIds.compactMap { value in
                guard let raw = string(from: value) else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        return []
    }

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        conferenceMutationErrorDescription(from: value)
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(string):
            return string
        case let .integer(integer):
            return String(integer)
        case let .number(number):
            return String(number)
        case let .float(float):
            return String(float)
        case let .bool(bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private static func discoveryStateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["status"] = .string(status)
        updated["statusSummary"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        updated["refreshSummary"] = .string(actionSummary)
        return updated
    }

    private static func defaultDiscoveryState() -> Object {
        [
            "intro": .string("Conference discovery combines portable participant discovery with local nearby enrichment."),
            "status": .string("Discovery-snapshotet varmer opp lokalt."),
            "alignmentSummary": .string("Portable og lokale discovery-signaler holdes samlet i ett stabilt snapshot."),
            "proofSummary": .string("Verifisert kontakt kan åpne for rikere purpose- og interest-matching."),
            "sourceSummary": .string("Vi bruker et lokalt cached snapshot så discovery-delen holder seg stabil mens live-data oppdateres."),
            "publicProfileSummary": .string("Bare minimal offentlig profil vises til du eksplisitt ber om mer."),
            "chatSummary": .string("0 discovery-chat(er) klare."),
            "nextAction": .string("Oppdater discovery, vurder lovende personer, og start en oppfølgingschat når det føles riktig."),
            "refreshSummary": .string("Forbereder første discovery-snapshot."),
            "statusSummary": .string("Discovery-snapshotet bruker en lokal startflate mens livedata kobler seg til."),
            "selectionSummary": .string("Trykk Vis i siden på en discovery-kandidat for å fokusere på personen her."),
            "navigationSummary": .string("Første klikk skjer i denne siden."),
            "nextStepSummary": .string("Velg en discovery-kandidat før du tar neste steg."),
            "actionSummary": .string("Trykk Vis i siden for å fokusere på en person i discovery."),
            "candidates": .list([
                .object([
                    "title": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability"),
                    "detail": .string("Strong alignment on governance, delivery, and shared trust patterns."),
                    "note": .string("Recommended")
                ]),
                .object([
                    "title": .string("Mads Hovden"),
                    "subtitle": .string("Policy and compliance"),
                    "detail": .string("Good match for claims, compliance, and organizer follow-up."),
                    "note": .string("Nearby-capable")
                ]),
                .object([
                    "title": .string("Lea Heger"),
                    "subtitle": .string("Digital service design"),
                    "detail": .string("Connects participant needs to service and product design decisions."),
                    "note": .string("Suggested follow-up")
                ])
            ]),
            "proofCandidates": .list([
                .object([
                    "title": .string("Shared Relations Forum"),
                    "subtitle": .string("Proof-backed discovery"),
                    "detail": .string("Participants who can expose stronger matching once contact is verified."),
                    "note": .string("Proof ready")
                ]),
                .object([
                    "title": .string("Trust Infrastructure Lab"),
                    "subtitle": .string("Policy and operations"),
                    "detail": .string("Good candidate set for deeper follow-up if you want more precision."),
                    "note": .string("Consent gated")
                ])
            ]),
            "groupSuggestions": .list([
                .object([
                    "title": .string("Identity and Governance Circle"),
                    "subtitle": .string("3 people"),
                    "detail": .string("A small group with overlapping agenda and meeting goals."),
                    "note": .string("Suggested group chat")
                ]),
                .object([
                    "title": .string("Applied AI Follow-up"),
                    "subtitle": .string("2 people"),
                    "detail": .string("Focused on practical AI systems, trust, and delivery."),
                    "note": .string("Suggested nearby cluster")
                ])
            ]),
            "focusedProfile": .object([
                "selectionBadge": .string("VALGT I DISCOVERY"),
                "title": .string("Ingen deltaker valgt ennå"),
                "subtitle": .string("Entity Discovery"),
                "detail": .string("Trykk Vis i siden på en discovery-kandidat for å se personens offentlige og lokale oppsummering her."),
                "note": .string("Bare minimal offentlig profil vises til du eksplisitt ber om mer.")
            ]),
            "focusedActions": .list([])
        ]
    }
}

@MainActor
private final class ConferenceParticipantMatchmakingSnapshotLocalCell: GeneralCell {
    private var cachedMatchmakingState: Object = ConferenceParticipantMatchmakingSnapshotLocalCell.defaultMatchmakingState()
    private var lastRefreshAt: Date?
    private var refreshTask: Task<Void, Never>?
    private var storeKey = ""
    private var focusedRecommendationName: String?
    private var followUpMarkedNames: Set<String> = []
    private var launchedChatNames: [String] = []
    private var recentActionSummary = "Velg Vis i siden for å fokusere på en anbefalt deltaker her."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceParticipantMatchmakingSnapshotLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        storeKey = owner.uuid
        await restoreSelectedParticipantIfAvailable()
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "refresh")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: false, forwardAction: nil, requester: requester)
            return .object(self.cachedMatchmakingState)
        })

        await addInterceptForSet(requester: owner, key: "refresh", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "refresh", for: requester) else { return .string("denied") }
            let payload: Object = [
                "keypath": .string("matchmaking.refreshRecommendations"),
                "payload": .bool(true)
            ]
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: .object(payload), requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedMatchmakingState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.handleDispatchAction(value, requester: requester)
        })

        Task { [weak self] in
            guard let self else { return }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: owner)
        }
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              let actionKeypath = string(from: object["keypath"]),
              actionKeypath.isEmpty == false else {
            cachedMatchmakingState = Self.matchmakingStateWithStatus(
                basedOn: cachedMatchmakingState,
                status: "Anbefalingshandlingen mangler keypath.",
                actionSummary: "Kunne ikke utføre handlingen fordi payloaden var ugyldig."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedMatchmakingState)
            ])
        }

        let payload = object["payload"] ?? .null
        let recommendationRows = listObjects(from: cachedMatchmakingState["recommendations"])
        let searchRows = listObjects(from: cachedMatchmakingState["searchResults"])
        var forwardedAction: ValueType? = .object([
            "keypath": .string(actionKeypath),
            "payload": payload
        ])

        switch actionKeypath {
        case "matchmaking.focusRecommendationAtIndex":
            let index = recommendationIndex(from: payload)
            if let index,
               recommendationRows.indices.contains(index) {
                let focusedCard = recommendationRows[index]
                let displayName = cardTitle(from: focusedCard)
                let subtitle = cardSubtitle(from: focusedCard)
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Viser \(displayName) i denne siden."
                forwardedAction = .object([
                    "keypath": .string("matchmaking.focusPerson"),
                    "payload": .object([
                        "displayName": .string(displayName),
                        "subtitle": .string(subtitle)
                    ])
                ])
            } else {
                recentActionSummary = "Kunne ikke finne anbefalingen du prøvde å fokusere."
                forwardedAction = nil
            }
        case "matchmaking.focusPerson":
            if case let .object(personObject) = payload,
               let displayName = string(from: personObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Viser \(displayName) i denne siden."
            }
        case "discovery.startChatWithFocusedPerson":
            if let focusedCard = focusedRecommendationCard(
                recommendations: recommendationRows,
                searchResults: searchRows
            ) {
                let displayName = cardTitle(from: focusedCard)
                let subtitle = cardSubtitle(from: focusedCard)
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Starter chat med \(displayName)…"
                forwardedAction = .object([
                    "keypath": .string("discovery.startChat"),
                    "payload": discoveryChatPayload(for: displayName, subtitle: subtitle)
                ])
            } else {
                recentActionSummary = "Velg Vis i siden på en anbefaling før du starter chat."
                forwardedAction = nil
            }
        case "matchmaking.toggleFollowUpForFocusedPerson":
            if let focusedCard = focusedRecommendationCard(
                recommendations: recommendationRows,
                searchResults: searchRows
            ) {
                let displayName = cardTitle(from: focusedCard)
                let subtitle = cardSubtitle(from: focusedCard)
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                if followUpMarkedNames.contains(displayName) {
                    followUpMarkedNames.remove(displayName)
                    recentActionSummary = "Fjernet \(displayName) fra oppfølging."
                } else {
                    followUpMarkedNames.insert(displayName)
                    recentActionSummary = "Markerte \(displayName) for oppfølging."
                }
                forwardedAction = .object([
                    "keypath": .string("matchmaking.toggleFollowUp"),
                    "payload": .object([
                        "displayName": .string(displayName),
                        "subtitle": .string(subtitle)
                    ])
                ])
            } else {
                recentActionSummary = "Velg Vis i siden på en anbefaling før du markerer oppfølging."
                forwardedAction = nil
            }
        case "scheduling.createMeetingRequestForFocusedPerson":
            if let focusedCard = focusedRecommendationCard(
                recommendations: recommendationRows,
                searchResults: searchRows
            ) {
                let displayName = cardTitle(from: focusedCard)
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "La til møteforespørsel for \(displayName)."
                forwardedAction = .object([
                    "keypath": .string("scheduling.createMeetingRequest"),
                    "payload": .object([
                        "source": .string("binding-matchmaking-focused-person"),
                        "displayName": .string(displayName)
                    ])
                ])
            } else {
                recentActionSummary = "Velg Vis i siden på en anbefaling før du ber om møte."
                forwardedAction = nil
            }
        case "matchmaking.toggleFollowUp":
            if case let .object(personObject) = payload,
               let displayName = string(from: personObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                if followUpMarkedNames.contains(displayName) {
                    followUpMarkedNames.remove(displayName)
                    recentActionSummary = "Fjernet \(displayName) fra oppfølging."
                } else {
                    followUpMarkedNames.insert(displayName)
                    recentActionSummary = "Markerte \(displayName) for oppfølging."
                }
            }
        case "discovery.startChat":
            let targetNames = discoveryTargetNames(from: payload)
            if let firstTarget = targetNames.first {
                focusedRecommendationName = firstTarget
                await rememberSelectedParticipant(firstTarget)
                recentActionSummary = "Starter chat med \(firstTarget)…"
            } else {
                recentActionSummary = "Starter chat fra anbefalingsflaten…"
            }
        case "scheduling.createMeetingRequest":
            if let focusedRecommendationName {
                recentActionSummary = "La til møteforespørsel for \(focusedRecommendationName)."
            } else {
                recentActionSummary = "La til en ny møteforespørsel."
            }
        case "matchmaking.setFilters":
            recentActionSummary = "Oppdaterte anbefalingsfilteret."
        case "matchmaking.searchPeople":
            recentActionSummary = "Viser governance-relevante personer i anbefalingene."
        case "matchmaking.refreshRecommendations":
            recentActionSummary = "Oppdaterte anbefalingene."
        default:
            recentActionSummary = "Utførte \(actionKeypath) i anbefalingssnapshotet."
        }

        cachedMatchmakingState = mergedMatchmakingState(from: cachedMatchmakingState)
        await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedMatchmakingState)
        ])
    }

    private func refreshSnapshotIfNeeded(
        force: Bool,
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        let shouldRetryImmediately = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
            cachedState: cachedMatchmakingState,
            statusKeys: ["status", "actionSummary", "searchSummary"]
        )

        if !force,
           !shouldRetryImmediately,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 1 {
            return
        }

        if let refreshTask {
            await refreshTask.value
            let shouldRetryAfterInflight = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
                cachedState: cachedMatchmakingState,
                statusKeys: ["status", "actionSummary", "searchSummary"]
            )
            if !force && forwardAction == nil && !shouldRetryAfterInflight {
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(
                forwardAction: forwardAction,
                requester: requester
            )
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    @MainActor
    private func performRefresh(
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        await AppInitializer.initialize()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            cachedMatchmakingState = Self.matchmakingStateWithStatus(
                basedOn: cachedMatchmakingState,
                status: "Anbefalingene bruker siste lokale snapshot fordi resolver mangler.",
                actionSummary: "Kunne ikke oppdatere anbefalingene akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        guard let previewShell = try? await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: requester
        ) as? Meddle else {
            cachedMatchmakingState = Self.matchmakingStateWithStatus(
                basedOn: cachedMatchmakingState,
                status: "Anbefalingene bruker siste lokale snapshot fordi ingen preview-shell er tilgjengelig.",
                actionSummary: "Kunne ikke oppdatere anbefalingene akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        if let forwardAction {
            let mutationResult = try? await previewShell.set(
                keypath: "dispatchAction",
                value: forwardAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedMatchmakingState = Self.matchmakingStateWithStatus(
                    basedOn: cachedMatchmakingState,
                    status: "Anbefalingene beholdt siste stabile snapshot fordi handlingen feilet.",
                    actionSummary: errorDescription
                )
            }
        }

        do {
            let stateValue = try await previewShell.get(
                keypath: "state",
                requester: requester
            )
            guard case let .object(stateObject) = stateValue,
                  case let .object(matchesObject)? = stateObject["matches"] else {
                cachedMatchmakingState = Self.matchmakingStateWithStatus(
                    basedOn: cachedMatchmakingState,
                    status: "Anbefalingene returnerte ikke et lesbart snapshot.",
                    actionSummary: "Bruker siste stabile data."
                )
                lastRefreshAt = Date()
                return
            }

            let sharedConnections = conferenceObject(from: stateObject["sharedConnections"])
            synchronizeLaunchedChats(
                from: sharedConnections,
                forwardedAction: forwardAction
            )

            cachedMatchmakingState = mergedMatchmakingState(from: matchesObject)
            lastRefreshAt = Date()
        } catch {
            cachedMatchmakingState = Self.matchmakingStateWithStatus(
                basedOn: cachedMatchmakingState,
                status: "Anbefalingene bruker siste stabile snapshot.",
                actionSummary: "Kunne ikke hente oppdatert anbefalingsdata akkurat nå: \(error)"
            )
            lastRefreshAt = Date()
        }
    }

    private func synchronizeLaunchedChats(
        from sharedConnections: Object?,
        forwardedAction: ValueType?
    ) {
        let sharedNames = conferenceSharedConnectionNames(from: sharedConnections)
        launchedChatNames = sharedNames

        guard conferenceActionKeypath(from: forwardedAction) == "discovery.startChat" else {
            return
        }

        let targetNames = discoveryTargetNames(from: conferenceActionPayload(from: forwardedAction) ?? .null)
        guard let firstTarget = targetNames.first else {
            return
        }

        if sharedNames.contains(firstTarget) {
            recentActionSummary = "Chatten med \(firstTarget) er klar."
        } else {
            if launchedChatNames.contains(firstTarget) == false {
                launchedChatNames.insert(firstTarget, at: 0)
                launchedChatNames = Array(Set(launchedChatNames)).sorted {
                    if $0 == firstTarget { return true }
                    if $1 == firstTarget { return false }
                    return $0 < $1
                }
            }
            recentActionSummary = "Chatten med \(firstTarget) klargjøres. Du kan åpne chatflaten nå."
        }
    }

    private func mergedMatchmakingState(from object: Object) -> Object {
        var merged = Self.defaultMatchmakingState()
        for (key, value) in object {
            merged[key] = value
        }

        let recommendationRows = listObjects(from: merged["recommendations"])
        let searchRows = listObjects(from: merged["searchResults"])
        let derivedRecommendations = recommendationRows.map { recommendationCard(from: $0) }
        let derivedSearchResults = searchRows.map { followUpConnectionCard(from: $0) }
        let focusedCard = focusedRecommendationCard(
            recommendations: recommendationRows,
            searchResults: searchRows
        )

        merged["recommendations"] = .list(derivedRecommendations)
        merged["searchResults"] = .list(derivedSearchResults)
        merged["statusSummary"] = .string(statusSummary(for: recommendationRows))
        merged["selectionSummary"] = .string(selectionSummary(for: focusedCard))
        merged["navigationSummary"] = .string(navigationSummary(for: focusedCard))
        merged["nextStepSummary"] = .string(nextStepSummary(for: focusedCard))
        merged["actionSummary"] = .string(recentActionSummary)
        merged["focusedProfile"] = .object(focusedProfileObject(from: focusedCard))
        merged["focusedActions"] = .list(focusedActionCards(for: focusedCard))
        return merged
    }

    private func recommendationCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let baseNote = cardNote(from: raw)
        let isFocused = focusedRecommendationName == title
        let note: String
        if isFocused {
            note = "\(baseNote) · Vises i siden nå."
        } else {
            note = "\(baseNote) · Trykk Vis i siden for å fokusere."
        }

        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "demoPersona": raw["demoPersona"] ?? .object(conferenceDemoPersonaSeedObject(named: title)),
            "keypath": .string("matchmakingSnapshot.dispatchAction"),
            "label": .string(isFocused ? "Valgt i siden" : "Vis i siden"),
            "payload": .object([
                "keypath": .string("matchmaking.focusPerson"),
                "payload": .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
            ])
        ])
    }

    private func followUpConnectionCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let baseNote = cardNote(from: raw)
        let marked = followUpMarkedNames.contains(title)
        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(marked ? "\(baseNote) · Markert for oppfølging." : "\(baseNote) · Kan markeres for oppfølging."),
            "demoPersona": raw["demoPersona"] ?? .object(conferenceDemoPersonaSeedObject(named: title)),
            "keypath": .string("matchmakingSnapshot.dispatchAction"),
            "label": .string(marked ? "Fjern markering" : "Marker for oppfølging"),
            "payload": .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
            ])
        ])
    }

    private func statusSummary(for recommendationRows: [Object]) -> String {
        if recommendationRows.isEmpty {
            return "Ingen anbefalte deltakere er klare ennå."
        }
        return "\(recommendationRows.count) anbefalte deltakere er klare for gjennomgang."
    }

    private func selectionSummary(for focusedCard: Object?) -> String {
        guard let focusedCard else {
            return "Trykk Vis i siden på en anbefaling for å fokusere på personen her."
        }
        return "Viser \(cardTitle(from: focusedCard)) i denne siden."
    }

    private func navigationSummary(for focusedCard: Object?) -> String {
        if focusedCard == nil {
            return "Første klikk skjer i denne siden. Du trenger ikke åpne en ny arbeidsflate for å se hvem anbefalingen gjelder."
        }
        return "Du ser nå valgt deltaker i denne siden. Herfra kan du starte chat, markere oppfølging eller be om møte."
    }

    private func nextStepSummary(for focusedCard: Object?) -> String {
        guard let focusedCard else {
            return "Velg en anbefalt deltaker med Vis i siden før du tar neste steg."
        }
        let title = cardTitle(from: focusedCard)
        if launchedChatNames.contains(title) {
            return "Chatten med \(title) er klar. Neste steg er å åpne chatflaten eller be om møte."
        }
        if followUpMarkedNames.contains(title) {
            return "\(title) er markert for oppfølging. Neste steg er å starte chat eller be om møte."
        }
        return "Neste steg for \(title) er å starte chat, markere oppfølging eller be om møte."
    }

    private func focusedProfileObject(from focusedCard: Object?) -> Object {
        guard let focusedCard else {
            return [
                "selectionBadge": .string("VALGT DELTAKER"),
                "title": .string("Ingen deltaker valgt ennå"),
                "subtitle": .string("Anbefalinger"),
                "detail": .string("Trykk Vis i siden på en anbefaling for å se personens offentlige og lokale oppsummering her."),
                "note": .string("Dette er standardvisningen før du velger en anbefalt deltaker."),
                "publicProfileSummary": .string("Velg en anbefaling for å se en tydelig offentlig profil og lokal oppsummering her."),
                "profileDetail": .string("Vi viser fagområde, begrunnelse og anbefalt neste steg når en deltaker er valgt."),
                "fitSummary": .string("Ingen anbefalt deltaker er valgt ennå."),
                "nextStep": .string("Velg en anbefaling først, og bruk deretter chat, oppfølging eller møte."),
                "conversationStyle": .string("Når en deltaker er valgt, viser vi hvordan demo-personaen typisk svarer i chat."),
                "openingPrompt": .string("Velg en anbefaling først for å se et konkret forslag til åpningsmelding."),
                "simulationSummary": .string("Demo-svarene er bounded og følger valgt deltagerprofil.")
            ]
        }

        let persona = conferenceDemoPersona(named: cardTitle(from: focusedCard), source: focusedCard)
        let title = cardTitle(from: focusedCard)
        let chatReady = launchedChatNames.contains(title)
        let followUpMarked = followUpMarkedNames.contains(title)
        let note: String
        if chatReady {
            note = "\(cardNote(from: focusedCard)) · Chatten er klar i chat og oppfølging."
        } else if followUpMarked {
            note = "\(cardNote(from: focusedCard)) · Markert for oppfølging."
        } else {
            note = cardNote(from: focusedCard)
        }
        let nextStep: String
        if chatReady {
            nextStep = "Åpne chatflaten eller be om møte med \(title)."
        } else if followUpMarked {
            nextStep = "Fortsett med chat eller be om møte med \(title)."
        } else {
            nextStep = "Bruk Klargjør chat, Marker for oppfølging eller Be om møte med \(title)."
        }
        return [
            "selectionBadge": .string("VALGT DELTAKER"),
            "title": .string(title),
            "subtitle": .string(cardSubtitle(from: focusedCard)),
            "detail": .string(cardDetail(from: focusedCard)),
            "note": .string(note),
            "publicProfileSummary": .string("Offentlig profil: \(cardSubtitle(from: focusedCard))."),
            "profileDetail": .string("\(cardDetail(from: focusedCard)) \(persona.publicProfileDetail)"),
            "fitSummary": .string("\(cardNote(from: focusedCard)) · \(persona.fitContext)"),
            "nextStep": .string(nextStep),
            "conversationStyle": .string(persona.conversationStyle),
            "openingPrompt": .string(persona.suggestedOpening),
            "simulationSummary": .string(persona.simulatedAgentSummary)
        ]
    }

    private func focusedActionCards(for focusedCard: Object?) -> [ValueType] {
        guard let focusedCard else { return [] }
        let title = cardTitle(from: focusedCard)
        let subtitle = cardSubtitle(from: focusedCard)
        let chatReady = launchedChatNames.contains(title)
        let followUpMarked = followUpMarkedNames.contains(title)

        let chatAction: ValueType = .object([
            "title": .string("Chat"),
            "subtitle": .string(chatReady ? "Fortsett samtalen" : "Start samtalen"),
            "detail": .string(chatReady ? "Åpne chatflaten med \(title) og fortsett oppfølgingen." : "Start en conference-chat med \(title) fra denne siden."),
            "note": .string("Dette er den tydeligste neste handlingen når du vil ta kontakt."),
            "keypath": .string(chatReady ? "chatSnapshot.dispatchAction" : "matchmakingSnapshot.dispatchAction"),
            "label": .string(chatReady ? "Åpne chatflate" : "Start chat"),
            "payload": .object([
                "keypath": .string(chatReady ? "openChatWorkbench" : "discovery.startChat"),
                "payload": chatReady
                    ? .object([
                        "displayName": .string(title),
                        "subtitle": .string(subtitle)
                    ])
                    : discoveryChatPayload(for: title, subtitle: subtitle)
            ])
        ])

        let followUpAction: ValueType = .object([
            "title": .string("Oppfølging"),
            "subtitle": .string(followUpMarked ? "Allerede markert" : "Marker neste steg"),
            "detail": .string(followUpMarked ? "\(title) er markert for oppfølging." : "Marker \(title) for oppfølging så den er lett å finne igjen."),
            "note": .string("Bruk dette når du vil huske personen uten å starte chat med en gang."),
            "keypath": .string("matchmakingSnapshot.dispatchAction"),
            "label": .string(followUpMarked ? "Fjern markering" : "Marker for oppfølging"),
            "payload": .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
            ])
        ])

        let meetingAction: ValueType = .object([
            "title": .string("Møte"),
            "subtitle": .string("Foreslå et konkret neste steg"),
            "detail": .string("Be om møte med \(title) hvis du vil gå fra anbefaling til konkret plan."),
            "note": .string("Bra når du allerede vet at personen er relevant og vil sette opp et faktisk møtetidspunkt."),
            "keypath": .string("matchmakingSnapshot.dispatchAction"),
            "label": .string("Be om møte"),
            "payload": .object([
                "keypath": .string("scheduling.createMeetingRequest"),
                "payload": .object([
                    "source": .string("binding-matchmaking-snapshot"),
                    "displayName": .string(title)
                ])
            ])
        ])

        return [chatAction, followUpAction, meetingAction]
    }

    private func focusedRecommendationCard(
        recommendations: [Object],
        searchResults: [Object]
    ) -> Object? {
        guard let focusedRecommendationName else { return nil }
        if let recommendation = recommendations.first(where: { cardTitle(from: $0) == focusedRecommendationName }) {
            return recommendation
        }
        if let searchResult = searchResults.first(where: { cardTitle(from: $0) == focusedRecommendationName }) {
            return searchResult
        }
        return nil
    }

    private func restoreSelectedParticipantIfAvailable() async {
        guard focusedRecommendationName == nil,
              !storeKey.isEmpty,
              let storedSelection = await ConferenceParticipantSelectionStore.shared.load(for: storeKey) else {
            return
        }
        focusedRecommendationName = storedSelection
    }

    private func rememberSelectedParticipant(_ displayName: String?) async {
        guard !storeKey.isEmpty else { return }
        await ConferenceParticipantSelectionStore.shared.save(displayName, for: storeKey)
    }

    private func listObjects(from value: ValueType?) -> [Object] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap {
            guard case let .object(object) = $0 else { return nil }
            return object
        }
    }

    private func cardTitle(from object: Object) -> String {
        string(from: object["title"]) ??
        string(from: object["displayName"]) ??
        "Ukjent deltaker"
    }

    private func cardSubtitle(from object: Object) -> String {
        string(from: object["subtitle"]) ??
        string(from: object["headline"]) ??
        "Anbefalt deltaker"
    }

    private func cardDetail(from object: Object) -> String {
        string(from: object["detail"]) ??
        "Ingen detalj tilgjengelig."
    }

    private func cardNote(from object: Object) -> String {
        string(from: object["note"]) ??
        "Ingen ekstra kontekst tilgjengelig ennå."
    }

    private func discoveryChatPayload(for title: String, subtitle: String) -> ValueType {
        .object([
            "source": .string("binding-participant-portal-recommendation"),
            "targets": .list([
                .object([
                    "displayName": .string(title),
                    "headline": .string(subtitle)
                ])
            ])
        ])
    }

    private func discoveryTargetNames(from payload: ValueType) -> [String] {
        guard case let .object(payloadObject) = payload else { return [] }
        if case let .list(targets)? = payloadObject["targets"] {
            let names = targets.compactMap { target -> String? in
                guard case let .object(targetObject) = target else { return nil }
                if let displayName = string(from: targetObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                   displayName.isEmpty == false {
                    return displayName
                }
                if let participantId = string(from: targetObject["participantId"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                   participantId.isEmpty == false {
                    return participantId
                }
                return nil
            }
            if names.isEmpty == false {
                return names
            }
        }
        if case let .list(participantIds)? = payloadObject["participantIds"] {
            return participantIds.compactMap { value in
                guard let raw = string(from: value) else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        return []
    }

    private func recommendationIndex(from payload: ValueType) -> Int? {
        if let direct = int(from: payload) {
            return direct
        }
        guard case let .object(payloadObject) = payload else {
            return nil
        }
        return int(from: payloadObject["index"])
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(string):
            return string
        case let .integer(integer):
            return String(integer)
        case let .number(number):
            return String(number)
        case let .float(float):
            return String(float)
        case let .bool(bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
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

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        conferenceMutationErrorDescription(from: value)
    }

    private static func matchmakingStateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["statusSummary"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        return updated
    }

    private static func defaultMatchmakingState() -> Object {
        [
            "intro": .string("Disse anbefalingene samler deltakerens formål, interesser og conference-kontekst i én stabil lokal snapshot-flate."),
            "filterSummary": .string("Filter: alle anbefalte deltakere."),
            "status": .string("Anbefalingene er klare for gjennomgang."),
            "recommendationSummary": .string("3 anbefalte deltakere klare for gjennomgang."),
            "searchSummary": .string("Søkeutvidelsen er klar når du vil spisse treffene. Ingen personer er markert for oppfølging ennå."),
            "statusSummary": .string("Anbefalingssnapshotet bruker en lokal startflate mens livedata kobler seg til."),
            "selectionSummary": .string("Trykk Vis i siden på en anbefaling for å fokusere på personen her."),
            "navigationSummary": .string("Første klikk skjer i denne siden."),
            "nextStepSummary": .string("Velg en anbefalt deltaker før du tar neste steg."),
            "actionSummary": .string("Velg Vis i siden for å fokusere på en anbefalt deltaker her."),
            "recommendations": .list([
                .object([
                    "title": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability"),
                    "detail": .string("Strong match on governance and delivery."),
                    "note": .string("92% match")
                ]),
                .object([
                    "title": .string("Mads Hovden"),
                    "subtitle": .string("Policy and compliance"),
                    "detail": .string("Works with claims, trust, and organization."),
                    "note": .string("88% match")
                ]),
                .object([
                    "title": .string("Lea Heger"),
                    "subtitle": .string("Digital service design"),
                    "detail": .string("Can connect the program to concrete product choices."),
                    "note": .string("84% match")
                ])
            ]),
            "searchResults": .list([
                .object([
                    "title": .string("Governance Forum"),
                    "subtitle": .string("Nearby people"),
                    "detail": .string("Found people mentioning governance."),
                    "note": .string("Local preview")
                ]),
                .object([
                    "title": .string("Trust Infrastructure Lab"),
                    "subtitle": .string("Shared interests"),
                    "detail": .string("Shared focus on trust, claims, and operations."),
                    "note": .string("Suggested follow-up")
                ])
            ]),
            "focusedProfile": .object([
                "selectionBadge": .string("VALGT DELTAKER"),
                "title": .string("Ingen deltaker valgt ennå"),
                "subtitle": .string("Anbefalinger"),
                "detail": .string("Trykk Vis i siden på en anbefaling for å se personens offentlige og lokale oppsummering her."),
                "note": .string("Dette er standardvisningen før du velger en anbefalt deltaker.")
            ]),
            "focusedActions": .list([])
        ]
    }
}

@MainActor
private final class ConferenceParticipantChatSnapshotLocalCell: GeneralCell {
    private var cachedChatState: Object = ConferenceParticipantChatSnapshotLocalCell.defaultChatState()
    private var lastRefreshAt: Date?
    private var refreshTask: Task<Void, Never>?
    private var storeKey = ""
    private var focusedChatName: String?
    private var draftMessage = ""
    private var draftSeedName: String?
    private var recentActionSummary = "Start chat fra deltagerportalen for å gjøre en delt tråd klar her."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceParticipantChatSnapshotLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        storeKey = owner.uuid
        await restoreSelectedParticipantIfAvailable()
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "refresh")
        agreementTemplate.addGrant("rw--", for: "setDraftMessage")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: false, forwardAction: nil, requester: requester)
            return .object(self.cachedChatState)
        })

        await addInterceptForSet(requester: owner, key: "refresh", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "refresh", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedChatState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "setDraftMessage", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "setDraftMessage", for: requester) else { return .string("denied") }
            self.draftMessage = self.draftText(from: value) ?? ""
            self.recentActionSummary = self.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Meldingsutkastet er tomt igjen."
                : "Meldingsutkastet er oppdatert i chatflaten."
            self.cachedChatState = self.mergedChatState(from: self.cachedChatState)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedChatState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.handleDispatchAction(value, requester: requester)
        })

        Task { [weak self] in
            guard let self else { return }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: owner)
        }
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              let actionKeypath = string(from: object["keypath"]),
              actionKeypath.isEmpty == false else {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: cachedChatState,
                status: "Chat-handlingen mangler keypath.",
                actionSummary: "Kunne ikke utføre handlingen fordi payloaden var ugyldig."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedChatState)
            ])
        }

        let payload = object["payload"] ?? .null

        switch actionKeypath {
        case "chat.focusThread":
            if case let .object(threadObject) = payload,
               let displayName = string(from: threadObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedChatName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Viser den delte tråden med \(displayName)."
                cachedChatState = mergedChatState(from: cachedChatState)
            }
            return .object([
                "status": .string("ok"),
                "state": .object(cachedChatState)
            ])

        case "chat.sendDraftMessage":
            return await sendDraftMessage(requester: requester)

        case "openChatWorkbenchForSelectedParticipant":
            if let storedSelection = await selectedParticipantFromStore() {
                focusedChatName = storedSelection
                await rememberSelectedParticipant(storedSelection)
            }
            let selectedName = focusedChatName ?? "valgt deltaker"
            recentActionSummary = "Åpner chatflaten for \(selectedName)…"
            let selectedThreadReady = await ensureSharedThreadReady(requester: requester)
            if !selectedThreadReady {
                let currentState = mergedChatState(from: cachedChatState)
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: currentState,
                    status: string(from: currentState["statusSummary"]) ?? "Ingen delt tråd er klar ennå.",
                    actionSummary: recentActionSummary
                )
                return .object([
                    "status": .string("error"),
                    "state": .object(cachedChatState)
                ])
            }
            return await openChatWorkbench(requester: requester)

        case "openChatWorkbench":
            if case let .object(threadObject) = payload,
               let displayName = string(from: threadObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedChatName = displayName
                await rememberSelectedParticipant(displayName)
            }
            let threadReady = await ensureSharedThreadReady(requester: requester)
            if !threadReady {
                let currentState = mergedChatState(from: cachedChatState)
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: currentState,
                    status: string(from: currentState["statusSummary"]) ?? "Ingen delt tråd er klar ennå.",
                    actionSummary: recentActionSummary
                )
                return .object([
                    "status": .string("error"),
                    "state": .object(cachedChatState)
                ])
            }
            return await openChatWorkbench(requester: requester)

        case "openParticipantPortalWorkbench":
            return await openParticipantPortalWorkbench(requester: requester)

        case "connections.postSharedMessage", "scheduling.createMeetingRequest":
            let forwardedAction: ValueType = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
            if actionKeypath == "connections.postSharedMessage" {
                recentActionSummary = "Sendte en oppfølgingsmelding i delt tråd."
            } else {
                recentActionSummary = "La til en møteforespørsel fra chatflaten."
            }
            await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(cachedChatState)
            ])

        default:
            recentActionSummary = "Utførte \(actionKeypath) i chat-snapshotet."
            let forwardedAction: ValueType = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
            await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(cachedChatState)
            ])
        }
    }

    private func refreshSnapshotIfNeeded(
        force: Bool,
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        let shouldRetryImmediately = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
            cachedState: cachedChatState,
            statusKeys: ["statusSummary", "actionSummary", "threadSummary", "recentMessagesSummary"]
        )

        if !force,
           !shouldRetryImmediately,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 1 {
            return
        }

        if let refreshTask {
            await refreshTask.value
            let shouldRetryAfterInflight = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
                cachedState: cachedChatState,
                statusKeys: ["statusSummary", "actionSummary", "threadSummary", "recentMessagesSummary"]
            )
            if !force && forwardAction == nil && !shouldRetryAfterInflight {
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(forwardAction: forwardAction, requester: requester)
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    @MainActor
    private func performRefresh(
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        await AppInitializer.initialize()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let previewShell = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///ConferenceParticipantPreviewShell",
                requester: requester
              ) as? Meddle else {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: cachedChatState,
                status: "Chatflaten bruker siste lokale snapshot fordi deltager-preview ikke er tilgjengelig.",
                actionSummary: "Kunne ikke oppdatere chat akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        if let forwardAction {
            let mutationResult = try? await previewShell.set(
                keypath: "dispatchAction",
                value: forwardAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: cachedChatState,
                    status: "Chatflaten beholdt siste stabile snapshot fordi handlingen feilet.",
                    actionSummary: errorDescription
                )
                lastRefreshAt = Date()
                return
            }
        }

        do {
            let stateValue = try await previewShell.get(keypath: "state", requester: requester)
            guard case let .object(stateObject) = stateValue else {
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: cachedChatState,
                    status: "Chatflaten returnerte ikke et lesbart preview-snapshot.",
                    actionSummary: "Bruker siste stabile data."
                )
                lastRefreshAt = Date()
                return
            }

            let workspace = object(from: stateObject["workspace"])
            let sharedConnections = object(from: stateObject["sharedConnections"])
            cachedChatState = mergedChatState(
                workspace: workspace,
                sharedConnections: sharedConnections
            )
            lastRefreshAt = Date()
        } catch {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: cachedChatState,
                status: "Chatflaten bruker siste stabile snapshot.",
                actionSummary: "Kunne ikke hente oppdatert chat akkurat nå: \(error)"
            )
            lastRefreshAt = Date()
        }
    }

    private func mergedChatState(
        workspace: Object?,
        sharedConnections: Object?
    ) -> Object {
        var merged = Self.defaultChatState()

        if let intro = string(from: sharedConnections?["intro"]) {
            merged["intro"] = .string(intro)
        }
        if let chatSummary = string(from: sharedConnections?["chatSummary"]) {
            merged["chatSummary"] = .string(chatSummary)
            merged["recentMessagesSummary"] = .string(chatSummary)
        }
        if let connectionSummary = string(from: sharedConnections?["connectionSummary"]) {
            merged["threadSummary"] = .string(connectionSummary)
            merged["statusSummary"] = .string(connectionSummary)
        }

        let connectionRows = listObjects(from: sharedConnections?["connections"])
        let recentMessageRows = listObjects(from: sharedConnections?["recentMessages"])
        let transcriptRows = Array(recentMessageRows.reversed())
        let effectiveFocusedName = ensureFocusedChatName(in: connectionRows)
        let focusedPersona = resolvedPersona(focusedName: effectiveFocusedName, connectionRows: connectionRows)
        seedDraftIfNeeded(persona: focusedPersona)

        merged["selectionSummary"] = .string(selectionSummary(
            focusedName: effectiveFocusedName,
            connectionCount: connectionRows.count
        ))
        merged["nextStepSummary"] = .string(nextStepSummary(
            focusedName: effectiveFocusedName,
            workspaceNextStep: string(from: workspace?["nextStep"]),
            connectionCount: connectionRows.count
        ))
        merged["actionSummary"] = .string(recentActionSummary)
        merged["recentMessagesSummary"] = .string(transcriptSummary(
            focusedName: effectiveFocusedName,
            messageCount: transcriptRows.count
        ))
        merged["chatSummary"] = .string(transcriptSummary(
            focusedName: effectiveFocusedName,
            messageCount: transcriptRows.count
        ))
        merged["personaSummary"] = .string(personaSummary(persona: focusedPersona))
        merged["personaDetail"] = .string(personaDetail(persona: focusedPersona))
        merged["simulationSummary"] = .string(simulationSummary(persona: focusedPersona))
        merged["focusedThread"] = .object(focusedThreadObject(
            persona: focusedPersona,
            connectionRows: connectionRows,
            messageRows: recentMessageRows
        ))
        merged["draftMessage"] = .string(draftMessage)
        merged["draftSummary"] = .string(draftSummary(focusedName: effectiveFocusedName, connectionCount: connectionRows.count))
        merged["draftHint"] = .string(draftHint(persona: focusedPersona))
        merged["focusedActions"] = .list(focusedActionCards(persona: focusedPersona).map(ValueType.object))
        merged["connections"] = .list(connectionRows.map { connectionCard(from: $0, focusedName: effectiveFocusedName) })
        merged["recentMessages"] = .list(transcriptRows.map(messageCard))

        return merged
    }

    private func ensureFocusedChatName(in connectionRows: [Object]) -> String? {
        if let focusedChatName,
           connectionRows.contains(where: { cardTitle(from: $0) == focusedChatName }) {
            return focusedChatName
        }
        let firstName = connectionRows.first.map { cardTitle(from: $0) }
        focusedChatName = firstName
        return firstName
    }

    private func resolvedPersona(focusedName: String?, connectionRows: [Object]) -> ConferenceDemoPersona? {
        guard let focusedName else { return nil }
        let sourceObject = connectionRows.first(where: { cardTitle(from: $0) == focusedName })
        return conferenceDemoPersona(named: focusedName, source: sourceObject)
    }

    private func selectionSummary(focusedName: String?, connectionCount: Int) -> String {
        if let focusedName {
            return "Viser den delte tråden med \(focusedName)."
        }
        if connectionCount == 0 {
            return "Ingen delt tråd er klar ennå. Start chat i deltagerportalen først."
        }
        return "Velg en delt tråd for å fokusere samtalen her."
    }

    private func nextStepSummary(
        focusedName: String?,
        workspaceNextStep: String?,
        connectionCount: Int
    ) -> String {
        if let focusedName {
            return "Neste steg for \(focusedName) er å sende en kort oppfølging eller gå tilbake til deltagerportalen."
        }
        if connectionCount == 0 {
            return workspaceNextStep ?? "Start en chat fra recommendations, discovery eller nearby for å gjøre chatflaten aktiv."
        }
        return "Velg en delt tråd og fortsett oppfølgingen derfra."
    }

    private func personaSummary(persona: ConferenceDemoPersona?) -> String {
        guard let persona else {
            return "Ingen demo-deltager er valgt ennå."
        }
        return "\(persona.name) · \(persona.roleSummary)"
    }

    private func personaDetail(persona: ConferenceDemoPersona?) -> String {
        guard let persona else {
            return "Når en tråd er valgt, viser vi offentlig profil og samtalestil for demo-deltageren her."
        }
        return persona.publicProfileDetail
    }

    private func simulationSummary(persona: ConferenceDemoPersona?) -> String {
        guard let persona else {
            return "Svarene i demoen er bounded og følger valgt deltagerprofil."
        }
        return persona.simulatedAgentSummary
    }

    private func transcriptSummary(focusedName: String?, messageCount: Int) -> String {
        if let focusedName {
            if messageCount == 0 {
                return "Ingen meldinger synlige ennå i tråden med \(focusedName)."
            }
            if messageCount == 1 {
                return "1 melding synlig i tråden med \(focusedName), eldste først."
            }
            return "\(messageCount) meldinger synlige i tråden med \(focusedName), eldste først."
        }
        if messageCount == 0 {
            return "Ingen delte meldinger synlige ennå."
        }
        if messageCount == 1 {
            return "1 delt melding synlig, eldste først."
        }
        return "\(messageCount) delte meldinger synlige, eldste først."
    }

    private func draftSummary(focusedName: String?, connectionCount: Int) -> String {
        if let focusedName {
            return "Skriv en kort oppfølging til \(focusedName) og send den direkte fra denne flaten."
        }
        if connectionCount == 0 {
            return "Start en chat i deltagerportalen først, så kan du skrive en egen melding her."
        }
        return "Velg en tråd, og skriv deretter en konkret oppfølging i compose-feltet."
    }

    private func draftHint(persona: ConferenceDemoPersona?) -> String {
        if let persona {
            return "Hold meldingen kort og konkret. \(persona.conversationStyle) Svarene i demoen følger denne personaen."
        }
        return "Når en tråd er valgt, kan du skrive en egen melding eller bruke forslagsteksten som utgangspunkt."
    }

    private func focusedThreadObject(
        persona: ConferenceDemoPersona?,
        connectionRows: [Object],
        messageRows: [Object]
    ) -> Object {
        guard let persona,
              let focusedName = Optional(persona.name),
              let connection = connectionRows.first(where: { cardTitle(from: $0) == focusedName }) else {
            return [
                "selectionBadge": .string("VALGT TRÅD"),
                "title": .string("Ingen delt tråd valgt ennå"),
                "subtitle": .string("Conference chat"),
                "detail": .string("Start chat fra deltagerportalen eller velg en delt tråd fra listen under."),
                "note": .string("Når en tråd er valgt, viser vi siste oppsummering og neste steg her."),
                "nextMessage": .string("Velg en delt tråd for å se forslag til neste melding."),
                "nextMessageHint": .string("Når tråden er klar, kan du skrive en egen melding eller sende forslagsteksten herfra.")
            ]
        }

        let latestMessage = messageRows.first.flatMap { string(from: $0["detail"]) }
        let note = latestMessage.map { "Siste melding: \($0)" }
            ?? "Ingen melding sendt ennå. Send en kort oppfølging for å gjøre chatten tydelig i demoen."
        let suggestedNextMessage = persona.suggestedOpening

        return [
            "selectionBadge": .string("VALGT TRÅD"),
            "title": .string(cardTitle(from: connection)),
            "subtitle": .string(cardSubtitle(from: connection)),
            "detail": .string(cardDetail(from: connection)),
            "note": .string(note),
            "nextMessage": .string(suggestedNextMessage),
            "nextMessageHint": .string("Bruk compose-feltet under for å skrive en egen melding, eller send forslagsteksten med ett trykk. Demo-svaret holder seg til \(persona.roleSummary.lowercased()).")
        ]
    }

    private func focusedActionCards(persona: ConferenceDemoPersona?) -> [Object] {
        guard let persona else {
            return []
        }
        let focusedName = persona.name

        let sendAction: Object = [
            "title": .string("Send forslag"),
            "subtitle": .string("Bruk standardsvaret"),
            "detail": .string("Send en ferdig oppfølgingsmelding til \(focusedName) hvis du vil demonstrere flyten raskt."),
            "note": .string("Bruk compose-feltet over hvis du vil skrive en egen melding."),
            "keypath": .string("chatSnapshot.dispatchAction"),
            "label": .string("Send forslag"),
            "payload": .object([
                "keypath": .string("connections.postSharedMessage"),
                "payload": .object([
                    "text": .string(persona.suggestedOpening),
                    "contentType": .string("text/plain")
                ])
            ])
        ]

        let meetingAction: Object = [
            "title": .string("Be om møte"),
            "subtitle": .string("Foreslå neste steg"),
            "detail": .string("Be om møte med \(focusedName) når chatten ser relevant ut."),
            "note": .string("Dette binder chat og scheduling sammen i samme conference-flyt."),
            "keypath": .string("chatSnapshot.dispatchAction"),
            "label": .string("Be om møte"),
            "payload": .object([
                "keypath": .string("scheduling.createMeetingRequest"),
                "payload": .object([
                    "source": .string("binding-chat-snapshot"),
                    "displayName": .string(focusedName)
                ])
            ])
        ]

        return [sendAction, meetingAction]
    }

    private func connectionCard(from raw: Object, focusedName: String?) -> ValueType {
        let title = cardTitle(from: raw)
        let isFocused = focusedName == title
        let note = cardNote(from: raw)
        let updatedNote = isFocused ? "\(note) · Vises i chatflaten nå." : "\(note) · Velg tråden for å fokusere den her."
        return .object([
            "title": .string(title),
            "subtitle": .string(cardSubtitle(from: raw)),
            "detail": .string(cardDetail(from: raw)),
            "note": .string(updatedNote),
            "keypath": .string("chatSnapshot.dispatchAction"),
            "label": .string(isFocused ? "Valgt tråd" : "Vis tråd"),
            "payload": .object([
                "keypath": .string("chat.focusThread"),
                "payload": .object([
                    "displayName": .string(title)
                ])
            ])
        ])
    }

    private func messageCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        return .object([
            "title": .string(title),
            "subtitle": .string(cardSubtitle(from: raw)),
            "detail": .string(cardDetail(from: raw)),
            "note": .string(cardNote(from: raw)),
            "senderInitials": .string(senderInitials(for: title))
        ])
    }

    private func senderInitials(for title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "?" }
        if trimmed == "Deg" {
            return "DU"
        }

        let components = trimmed
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap { $0.first }

        let initials = String(components).uppercased()
        return initials.isEmpty ? String(trimmed.prefix(1)).uppercased() : initials
    }

    private func draftText(from value: ValueType) -> String? {
        if let text = string(from: value) {
            return text
        }
        if case let .object(object) = value,
           let text = string(from: object["text"]) {
            return text
        }
        return nil
    }

    private func sendDraftMessage(requester: Identity) async -> ValueType {
        let outgoingText = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard outgoingText.isEmpty == false else {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Skriv en melding før du sender.",
                actionSummary: "Meldingsutkastet var tomt."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedChatState)
            ])
        }

        let focusedName = focusedChatName ?? "delt tråd"
        let forwardedAction: ValueType = .object([
            "keypath": .string("connections.postSharedMessage"),
            "payload": .object([
                "text": .string(outgoingText),
                "contentType": .string("text/plain")
            ])
        ])

        recentActionSummary = "Sender meldingen til \(focusedName)…"
        await AppInitializer.initialize()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let previewShell = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///ConferenceParticipantPreviewShell",
                requester: requester
              ) as? Meddle else {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Chatflaten bruker siste lokale snapshot fordi deltager-preview ikke er tilgjengelig.",
                actionSummary: "Kunne ikke sende meldingen akkurat nå."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedChatState)
            ])
        }

        do {
            let mutationResult = try await previewShell.set(
                keypath: "dispatchAction",
                value: forwardedAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: mergedChatState(from: cachedChatState),
                    status: "Chatflaten beholdt meldingsutkastet fordi sendingen feilet.",
                    actionSummary: errorDescription
                )
                return .object([
                    "status": .string("error"),
                    "state": .object(cachedChatState)
                ])
            }

            draftMessage = ""
            draftSeedName = focusedName
            recentActionSummary = "Sendte meldingen til \(focusedName). Demo-personaen svarte i samme tråd."

            let stateValue = try await previewShell.get(keypath: "state", requester: requester)
            guard case let .object(stateObject) = stateValue else {
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: mergedChatState(from: cachedChatState),
                    status: "Meldingen ble sendt, men chatflaten fikk ikke lest nytt snapshot.",
                    actionSummary: "Bruker siste stabile data."
                )
                return .object([
                    "status": .string("ok"),
                    "state": .object(cachedChatState)
                ])
            }

            let workspace = object(from: stateObject["workspace"])
            let sharedConnections = object(from: stateObject["sharedConnections"])
            cachedChatState = mergedChatState(
                workspace: workspace,
                sharedConnections: sharedConnections
            )
            lastRefreshAt = Date()
            return .object([
                "status": .string("ok"),
                "state": .object(cachedChatState)
            ])
        } catch {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Chatflaten beholdt meldingsutkastet fordi sendingen feilet.",
                actionSummary: "Kunne ikke sende meldingen akkurat nå: \(error)"
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedChatState)
            ])
        }
    }

    private func ensureSharedThreadReady(requester: Identity) async -> Bool {
        await AppInitializer.initialize()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let previewShell = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///ConferenceParticipantPreviewShell",
                requester: requester
              ) as? Meddle else {
            recentActionSummary = "Kunne ikke åpne chatflaten fordi deltager-preview ikke er tilgjengelig."
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Chatflaten bruker siste lokale snapshot fordi deltager-preview ikke er tilgjengelig.",
                actionSummary: recentActionSummary
            )
            return false
        }

        let currentState = try? await previewShell.get(keypath: "state", requester: requester)
        if let currentObject = object(from: currentState),
           let workspace = object(from: currentObject["workspace"]),
           let sharedConnections = object(from: currentObject["sharedConnections"]) {
            cachedChatState = mergedChatState(workspace: workspace, sharedConnections: sharedConnections)
            let sharedNames = conferenceSharedConnectionNames(from: sharedConnections)
            if let focusedChatName, sharedNames.contains(focusedChatName) {
                recentActionSummary = "Chatten med \(focusedChatName) er klar."
                cachedChatState = mergedChatState(from: cachedChatState)
                return true
            }
            if let firstSharedName = sharedNames.first {
                focusedChatName = firstSharedName
                await rememberSelectedParticipant(firstSharedName)
                recentActionSummary = "Viser den delte tråden med \(firstSharedName)."
                cachedChatState = mergedChatState(from: cachedChatState)
                return true
            }
        }

        guard let bootstrapTarget = focusedChatName?.trimmingCharacters(in: .whitespacesAndNewlines),
              bootstrapTarget.isEmpty == false else {
            recentActionSummary = "Velg en deltager i portalen eller trykk Start chat før du åpner chatflaten."
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Ingen delt tråd er klar ennå.",
                actionSummary: recentActionSummary
            )
            return false
        }

        let persona = conferenceDemoPersona(named: bootstrapTarget)
        let bootstrapAction: ValueType = .object([
            "keypath": .string("discovery.startChat"),
            "payload": .object([
                "source": .string("binding-chat-workbench"),
                "targets": .list([
                    .object([
                        "displayName": .string(bootstrapTarget),
                        "headline": .string(persona.roleSummary)
                    ])
                ])
            ])
        ])

        recentActionSummary = "Gjør chatten med \(bootstrapTarget) klar…"
        let mutationResult = try? await previewShell.set(
            keypath: "dispatchAction",
            value: bootstrapAction,
            requester: requester
        )
        if let errorDescription = mutationErrorDescription(from: mutationResult) {
            recentActionSummary = errorDescription
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Chatflaten beholdt siste stabile snapshot fordi chatten ikke ble klar.",
                actionSummary: recentActionSummary
            )
            return false
        }

        let refreshedState = try? await previewShell.get(keypath: "state", requester: requester)
        guard let refreshedObject = object(from: refreshedState),
              let refreshedWorkspace = object(from: refreshedObject["workspace"]),
              let refreshedConnections = object(from: refreshedObject["sharedConnections"]) else {
            recentActionSummary = "Chatten med \(bootstrapTarget) ble ikke klar ennå. Prøv Start chat i portalen igjen."
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Ingen delt tråd er klar ennå.",
                actionSummary: recentActionSummary
            )
            return false
        }

        cachedChatState = mergedChatState(workspace: refreshedWorkspace, sharedConnections: refreshedConnections)
        let refreshedNames = conferenceSharedConnectionNames(from: refreshedConnections)
        if refreshedNames.contains(bootstrapTarget) {
            focusedChatName = bootstrapTarget
            await rememberSelectedParticipant(bootstrapTarget)
            recentActionSummary = "Chatten med \(bootstrapTarget) er klar."
            cachedChatState = mergedChatState(from: cachedChatState)
            return true
        }

        if let firstSharedName = refreshedNames.first {
            focusedChatName = firstSharedName
            await rememberSelectedParticipant(firstSharedName)
        }
        recentActionSummary = "Chatten med \(bootstrapTarget) ble ikke klar ennå. Prøv Start chat i portalen igjen."
        cachedChatState = Self.chatStateWithStatus(
            basedOn: mergedChatState(from: cachedChatState),
            status: "Ingen delt tråd er klar ennå.",
            actionSummary: recentActionSummary
        )
        return false
    }

    private func openChatWorkbench(requester: Identity) async -> ValueType {
        let displayName = focusedChatName.map { "Conference Chat · \($0)" } ?? "Conference Chat · Oppfølging"
        let configuration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration(
            participantEndpoint: "cell:///ConferenceParticipantPreviewShell",
            displayName: displayName,
            summary: "Delt conference-chat med oppfølging, meldinger og neste steg i egen arbeidsflate."
        )
        return await loadWorkbenchConfiguration(
            configuration,
            requester: requester,
            successSummary: "Åpnet chatflaten i egen arbeidsflate."
        )
    }

    private func openParticipantPortalWorkbench(requester: Identity) async -> ValueType {
        recentActionSummary = "Går tilbake til deltagerportalen…"
        cachedChatState = mergedChatState(from: cachedChatState)
        await MainActor.run {
            BindingConferenceNavigationBridge.postPop(
                fallbackConfiguration: ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                    endpoint: "cell:///ConferenceParticipantPreviewShell"
                )
            )
        }
        recentActionSummary = "Tilbake i deltagerportalen."
        cachedChatState = Self.chatStateWithStatus(
            basedOn: cachedChatState,
            status: "Chatflaten lukket. Deltagerportalen er aktiv igjen.",
            actionSummary: recentActionSummary
        )
        return .object([
            "status": .string("ok"),
            "state": .object(cachedChatState)
        ])
    }

    private func loadWorkbenchConfiguration(
        _ configuration: CellConfiguration,
        requester: Identity,
        successSummary: String
    ) async -> ValueType {
        recentActionSummary = "Åpner chatflaten…"
        cachedChatState = mergedChatState(from: cachedChatState)
        scheduleWorkbenchLoad(configuration, requester: requester, successSummary: successSummary)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedChatState)
        ])
    }

    private func scheduleWorkbenchLoad(
        _ configuration: CellConfiguration,
        requester: Identity,
        successSummary: String
    ) {
        Task { @MainActor [weak self] in
            BindingPortholeLoadBridge.post(configuration: configuration)
            self?.recentActionSummary = successSummary
            if let self {
                self.cachedChatState = Self.chatStateWithStatus(
                    basedOn: self.cachedChatState,
                    status: "Chatflaten åpnes i egen arbeidsflate.",
                    actionSummary: successSummary
                )
            }
        }
    }

    private func mergedChatState(from object: Object) -> Object {
        var merged = object
        merged["actionSummary"] = .string(recentActionSummary)
        let focusedName = self.object(from: merged["focusedThread"]).flatMap { string(from: $0["title"]) }
        let normalizedFocusedName = (focusedName == "Ingen delt tråd valgt ennå") ? nil : focusedName
        let focusedPersona = normalizedFocusedName.map { conferenceDemoPersona(named: $0) }
        seedDraftIfNeeded(persona: focusedPersona)
        let connectionCount = listObjects(from: merged["connections"]).count
        merged["draftMessage"] = .string(draftMessage)
        merged["draftSummary"] = .string(draftSummary(focusedName: normalizedFocusedName, connectionCount: connectionCount))
        merged["draftHint"] = .string(draftHint(persona: focusedPersona))
        return merged
    }

    private func listObjects(from value: ValueType?) -> [Object] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap {
            guard case let .object(object) = $0 else { return nil }
            return object
        }
    }

    private func cardTitle(from object: Object) -> String {
        string(from: object["title"]) ??
        string(from: object["displayName"]) ??
        "Delt tråd"
    }

    private func cardSubtitle(from object: Object) -> String {
        string(from: object["subtitle"]) ?? "Conference chat"
    }

    private func cardDetail(from object: Object) -> String {
        string(from: object["detail"]) ?? "Ingen detalj tilgjengelig ennå."
    }

    private func cardNote(from object: Object) -> String {
        string(from: object["note"]) ?? "Ingen ekstra chat-kontekst tilgjengelig ennå."
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(string):
            return string
        case let .integer(integer):
            return String(integer)
        case let .number(number):
            return String(number)
        case let .float(float):
            return String(float)
        case let .bool(bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private func object(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        conferenceMutationErrorDescription(from: value)
    }

    private func restoreSelectedParticipantIfAvailable() async {
        guard focusedChatName == nil,
              let storedSelection = await selectedParticipantFromStore() else {
            return
        }
        focusedChatName = storedSelection
    }

    private func selectedParticipantFromStore() async -> String? {
        guard !storeKey.isEmpty,
              let storedSelection = await ConferenceParticipantSelectionStore.shared.load(for: storeKey) else {
            return nil
        }
        let trimmed = storedSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func rememberSelectedParticipant(_ displayName: String?) async {
        guard !storeKey.isEmpty else { return }
        await ConferenceParticipantSelectionStore.shared.save(displayName, for: storeKey)
    }

    private func seedDraftIfNeeded(persona: ConferenceDemoPersona?) {
        guard let persona else {
            if draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draftSeedName = nil
            }
            return
        }
        guard draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard draftSeedName != persona.name else {
            return
        }
        draftMessage = persona.suggestedOpening
        draftSeedName = persona.name
    }

    private static func chatStateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["statusSummary"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        return updated
    }

    private static func defaultChatState() -> Object {
        [
            "intro": .string("Denne flaten viser når en conference-chat faktisk er klar, og gjør det tydelig hvordan du fortsetter oppfølgingen."),
            "statusSummary": .string("Ingen delt tråd er klar ennå."),
            "selectionSummary": .string("Start chat fra deltagerportalen for å gjøre en delt tråd klar her."),
            "nextStepSummary": .string("Når en delt tråd finnes, kan du sende oppfølging eller gå tilbake til portalen."),
            "actionSummary": .string("Start chat fra deltagerportalen for å gjøre en delt tråd klar her."),
            "threadSummary": .string("0 delte tråder synlige."),
            "recentMessagesSummary": .string("0 delte meldinger synlige."),
            "chatSummary": .string("0 delte meldinger synlige."),
            "personaSummary": .string("Ingen demo-deltager er valgt ennå."),
            "personaDetail": .string("Når en tråd er valgt, viser vi offentlig profil og samtalestil for demo-deltageren her."),
            "simulationSummary": .string("Svarene i demoen er bounded og følger valgt deltagerprofil."),
            "draftMessage": .string(""),
            "draftSummary": .string("Start en chat i deltagerportalen først, så kan du skrive en egen melding her."),
            "draftHint": .string("Når en tråd er valgt, kan du skrive en egen melding eller bruke forslagsteksten som utgangspunkt."),
            "focusedThread": .object([
                "selectionBadge": .string("VALGT TRÅD"),
                "title": .string("Ingen delt tråd valgt ennå"),
                "subtitle": .string("Conference chat"),
                "detail": .string("Start chat fra deltagerportalen eller velg en delt tråd når en blir synlig."),
                "note": .string("Når en tråd er valgt, viser vi siste oppsummering og neste steg her."),
                "nextMessage": .string("Velg en delt tråd for å se forslag til neste melding."),
                "nextMessageHint": .string("Når tråden er klar, kan du skrive en egen melding eller sende forslagsteksten herfra.")
            ]),
            "focusedActions": .list([]),
            "connections": .list([]),
            "recentMessages": .list([])
        ]
    }
}

struct ConferenceIdentityLinkParsedChallenge {
    var sourceSummary: String
    var statusSummary: String
    var challengeSummary: String
    var audienceSummary: String
    var originSummary: String
    var entitySummary: String
    var deviceSummary: String
    var domainSummary: String
    var contextSummary: String
    var scopeSummary: String
    var expirySummary: String
    var proofSummary: String
    var rawPreview: String
}

enum ConferenceIdentityLinkSupport {
    private static let emptySummary = "Ingen challenge lastet ennå."

    nonisolated static func parse(url: URL) -> ConferenceIdentityLinkParsedChallenge? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let matchesIdentityLinkRoute =
            (scheme == "haven" && (host == "identity-link" || normalizedPath == "identity-link" || (host == "binding" && normalizedPath == "add-device")))
            || (scheme == "https" || scheme == "http") && (normalizedPath.contains("identity-link") || normalizedPath.contains("add-device"))

        guard matchesIdentityLinkRoute else {
            return nil
        }

        let queryMap = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        if let payload = queryMap["payload"] ?? queryMap["request"],
           let parsed = parse(raw: payload, sourceSummary: "Deep link fra \(host ?? "ukjent vert")") {
            return parsed
        }

        return buildChallenge(
            sourceSummary: "Deep link fra \(host ?? "lokal app-lenke")",
            requestID: queryMap["requestId"] ?? queryMap["request_id"],
            purpose: queryMap["purpose"] ?? "link_identity",
            audience: queryMap["audience"],
            origin: queryMap["origin"] ?? url.absoluteString,
            entityAnchorReference: queryMap["entityAnchorReference"] ?? queryMap["entity"],
            deviceLabel: queryMap["deviceLabel"] ?? queryMap["device"],
            identityLabel: queryMap["displayName"] ?? queryMap["identity"],
            requestedDomains: splitCSV(queryMap["domains"]),
            requestedIdentityContexts: splitCSV(queryMap["contexts"]),
            requestedScopes: splitCSV(queryMap["scopes"]),
            expiresAt: queryMap["expiresAt"] ?? queryMap["expires_at"],
            challenge: queryMap["challenge"] ?? queryMap["nonce"],
            proofAlgorithm: queryMap["algorithm"],
            rawPreview: url.absoluteString
        )
    }

    nonisolated static func parse(raw: String, sourceSummary: String = "Innlimt challenge-data") -> ConferenceIdentityLinkParsedChallenge? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let parsedURL = parse(url: url) {
            return parsedURL
        }

        if let decodedPayload = decodePotentialBase64URL(trimmed),
           let decodedText = String(data: decodedPayload, encoding: .utf8),
           let parsedDecoded = parseJSONObjectString(decodedText, sourceSummary: sourceSummary) {
            return parsedDecoded
        }

        return parseJSONObjectString(trimmed, sourceSummary: sourceSummary)
    }

    private nonisolated static func parseJSONObjectString(_ value: String, sourceSummary: String) -> ConferenceIdentityLinkParsedChallenge? {
        guard let data = value.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return buildChallenge(
            sourceSummary: sourceSummary,
            requestID: string(in: json, path: ["requestId"]),
            purpose: string(in: json, path: ["purpose"]) ?? "link_identity",
            audience: string(in: json, path: ["audience"]),
            origin: string(in: json, path: ["origin"]),
            entityAnchorReference: string(in: json, path: ["entityAnchorReference"]),
            deviceLabel: string(in: json, path: ["device", "label"]),
            identityLabel: string(in: json, path: ["newIdentity", "displayName"]),
            requestedDomains: strings(in: json, path: ["requestedDomains"]),
            requestedIdentityContexts: strings(in: json, path: ["requestedIdentityContexts"]),
            requestedScopes: strings(in: json, path: ["requestedScopes"]),
            expiresAt: string(in: json, path: ["expiresAt"]),
            challenge: string(in: json, path: ["nonce"]),
            proofAlgorithm: string(in: json, path: ["proof", "algorithm"]),
            rawPreview: value
        )
    }

    private nonisolated static func buildChallenge(
        sourceSummary: String,
        requestID: String?,
        purpose: String,
        audience: String?,
        origin: String?,
        entityAnchorReference: String?,
        deviceLabel: String?,
        identityLabel: String?,
        requestedDomains: [String],
        requestedIdentityContexts: [String],
        requestedScopes: [String],
        expiresAt: String?,
        challenge: String?,
        proofAlgorithm: String?,
        rawPreview: String
    ) -> ConferenceIdentityLinkParsedChallenge {
        let effectiveAudience = audience?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveOrigin = origin?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveRequestID = requestID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveChallenge = challenge?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveDeviceLabel = deviceLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveIdentityLabel = identityLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveEntity = entityAnchorReference?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveExpiresAt = expiresAt?.trimmingCharacters(in: .whitespacesAndNewlines)

        let challengeSummary: String
        if let effectiveRequestID, !effectiveRequestID.isEmpty {
            challengeSummary = "Request \(effectiveRequestID)"
        } else if let effectiveChallenge, !effectiveChallenge.isEmpty {
            challengeSummary = "Challenge \(effectiveChallenge)"
        } else {
            challengeSummary = emptySummary
        }

        let compactPreview = rawPreview
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ConferenceIdentityLinkParsedChallenge(
            sourceSummary: sourceSummary,
            statusSummary: "Incoming identity-link challenge klar for review. Binding viser challenge-data og lokal key-possession før scaffold/web fullfører approval.",
            challengeSummary: challengeSummary,
            audienceSummary: effectiveAudience.map { "Audience: \($0)" } ?? "Audience mangler i challenge-data.",
            originSummary: effectiveOrigin.map { "Origin: \($0)" } ?? "Origin mangler i challenge-data.",
            entitySummary: effectiveEntity.map { "Entity anchor: \($0)" } ?? "Entity anchor ikke oppgitt i challenge-data.",
            deviceSummary: {
                let identityPart = effectiveIdentityLabel.map { "Ny Binding-identitet: \($0)" } ?? "Ny Binding-identitet ikke navngitt ennå."
                let devicePart = effectiveDeviceLabel.map { "Device: \($0)" } ?? "Device label mangler."
                return "\(identityPart) · \(devicePart)"
            }(),
            domainSummary: requestedDomains.isEmpty ? "Ingen requested domains oppgitt." : "Requested domains: \(requestedDomains.joined(separator: ", "))",
            contextSummary: requestedIdentityContexts.isEmpty ? "Ingen requested identity contexts oppgitt." : "Requested contexts: \(requestedIdentityContexts.joined(separator: ", "))",
            scopeSummary: requestedScopes.isEmpty ? "Ingen requested scopes oppgitt." : "Requested scopes: \(requestedScopes.joined(separator: ", "))",
            expirySummary: effectiveExpiresAt.map { "Expires: \($0)" } ?? "Expiry mangler i challenge-data.",
            proofSummary: "Purpose: \(purpose) · Proof alg: \(proofAlgorithm ?? "ikke oppgitt")",
            rawPreview: compactPreview.isEmpty ? emptySummary : compactPreview
        )
    }

    private nonisolated static func splitCSV(_ value: String?) -> [String] {
        guard let value else { return [] }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private nonisolated static func decodePotentialBase64URL(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var normalized = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while normalized.count % 4 != 0 {
            normalized.append("=")
        }
        return Data(base64Encoded: normalized)
    }

    private nonisolated static func string(in object: [String: Any], path: [String]) -> String? {
        var current: Any = object
        for component in path {
            guard let dictionary = current as? [String: Any],
                  let next = dictionary[component] else {
                return nil
            }
            current = next
        }
        return current as? String
    }

    private nonisolated static func strings(in object: [String: Any], path: [String]) -> [String] {
        var current: Any = object
        for component in path {
            guard let dictionary = current as? [String: Any],
                  let next = dictionary[component] else {
                return []
            }
            current = next
        }
        guard let values = current as? [Any] else { return [] }
        return values.compactMap { $0 as? String }
    }
}

actor ConferenceIdentityLinkInboxStore {
    static let shared = ConferenceIdentityLinkInboxStore()

    private var draftInput = ""
    private var incomingChallenge: ConferenceIdentityLinkParsedChallenge?
    private var localIdentitySummary = "Ingen lokal Binding-identitet er bekreftet i denne flaten ennå."
    private var confirmationStatus = "Lokal brukerbekreftelse mangler."
    private var actionSummary = "Åpne en haven://identity-link-lenke eller lim inn challenge-data for å starte review."
    private var lastIntakeSource = "Ingen challenge mottatt ennå."
    private var limitationSummary = "Binding gjør ekte challenge-intake og lokal key-review her. Endelig approval/fullføring i cross-vault identity-link-protokollen er fortsatt ikke koblet helt ferdig i denne flaten."
    private var nextStepSummary = "Når challenge-data er synlig, bekrefter du lokal nøkkelbesittelse og går deretter tilbake til Scaffold/web for approval eller completion."

    func ingest(url: URL) -> Bool {
        guard let parsed = ConferenceIdentityLinkSupport.parse(url: url) else {
            return false
        }
        incomingChallenge = parsed
        lastIntakeSource = parsed.sourceSummary
        actionSummary = "Lastet challenge-data fra deep link. Kontroller audience, scopes og lokal identitet før du går videre."
        nextStepSummary = "Bekreft lokal nøkkelbesittelse i Binding, og fullfør deretter approval i Scaffold/web."
        return true
    }

    func setDraftInput(_ input: String) {
        draftInput = input
    }

    func importDraft() -> Bool {
        guard let parsed = ConferenceIdentityLinkSupport.parse(raw: draftInput) else {
            actionSummary = "Klarte ikke å tolke innlimt challenge-data."
            return false
        }
        incomingChallenge = parsed
        lastIntakeSource = parsed.sourceSummary
        actionSummary = "Tolket challenge-data fra innlimt payload. Kontroller audience, scopes og origin før du går videre."
        nextStepSummary = "Bekreft lokal nøkkelbesittelse i Binding, og fullfør deretter approval i Scaffold/web."
        return true
    }

    func clear() {
        draftInput = ""
        incomingChallenge = nil
        localIdentitySummary = "Ingen lokal Binding-identitet er bekreftet i denne flaten ennå."
        confirmationStatus = "Lokal brukerbekreftelse mangler."
        actionSummary = "Åpne en haven://identity-link-lenke eller lim inn challenge-data for å starte review."
        lastIntakeSource = "Ingen challenge mottatt ennå."
        nextStepSummary = "Når challenge-data er synlig, bekrefter du lokal nøkkelbesittelse og går deretter tilbake til Scaffold/web for approval eller completion."
    }

    func confirmLocalReview(with identity: Identity?) {
        guard incomingChallenge != nil else {
            confirmationStatus = "Last en identity-link challenge før du bekrefter lokal review."
            actionSummary = "Ingen challenge er lastet ennå."
            return
        }
        guard let identity else {
            confirmationStatus = "Binding fant ingen lokal private-identitet å bekrefte."
            actionSummary = "Lokal key-possession kunne ikke bekreftes."
            return
        }

        let label = identity.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let identityLabel = label.isEmpty ? identity.uuid : label
        localIdentitySummary = "Binding verifiserte lokal nøkkelbesittelse for \(identityLabel) i private-domenet. Denne identiteten kan signere videre i den vanlige cross-vault-flyten."
        confirmationStatus = "Lokal brukerbekreftelse registrert. Binding er klar for neste proof-/approval-steg når Scaffold/web tilbyr det."
        actionSummary = "Lokal Binding-identitet er klar. Fullfør approval eller completeEnrollment på Scaffold-siden."
        nextStepSummary = "Gå tilbake til Scaffold Setup & Identity Link i web, godkjenn requesten der, og fullfør deretter den ordinære protocol completion uten demo-only bypass."
    }

    func stateObject() -> Object {
        let challenge = incomingChallenge
        return [
            "workspace": .object([
                "title": .string("Conference Scaffold Setup & Identity Link"),
                "subtitle": .string("Mobil intake for scaffold setup og cross-vault identity-link challenges. Denne flaten viser hva som faktisk er på vei inn til Binding, og hva som fortsatt må fullføres i den delte protokollen."),
                "notice": .string("Ingen skjult global identitet. Ingen demo-bypass. Binding viser incoming challenge-data, requested scopes og lokal key-possession eksplisitt.")
            ]),
            "incoming": .object([
                "statusSummary": .string(challenge?.statusSummary ?? "Ingen identity-link challenge synlig ennå."),
                "sourceSummary": .string(lastIntakeSource),
                "challengeSummary": .string(challenge?.challengeSummary ?? "Ingen request eller challenge lastet ennå."),
                "audienceSummary": .string(challenge?.audienceSummary ?? "Audience mangler til en challenge er lastet."),
                "originSummary": .string(challenge?.originSummary ?? "Origin mangler til en challenge er lastet."),
                "entitySummary": .string(challenge?.entitySummary ?? "Entity anchor blir vist når requesten er lastet."),
                "deviceSummary": .string(challenge?.deviceSummary ?? "Ny Binding-identitet og device label vises når requesten er lest."),
                "domainSummary": .string(challenge?.domainSummary ?? "Requested domains vises når challenge-data er lastet."),
                "contextSummary": .string(challenge?.contextSummary ?? "Requested contexts vises når challenge-data er lastet."),
                "scopeSummary": .string(challenge?.scopeSummary ?? "Requested scopes vises når challenge-data er lastet."),
                "expirySummary": .string(challenge?.expirySummary ?? "Expiry vises når challenge-data er lastet."),
                "proofSummary": .string(challenge?.proofSummary ?? "Proof metadata vises når challenge-data er lastet."),
                "rawPreview": .string(challenge?.rawPreview ?? "Ingen raw preview tilgjengelig ennå.")
            ]),
            "review": .object([
                "localIdentitySummary": .string(localIdentitySummary),
                "confirmationStatus": .string(confirmationStatus),
                "actionSummary": .string(actionSummary),
                "limitationSummary": .string(limitationSummary),
                "nextStepSummary": .string(nextStepSummary)
            ]),
            "draftInput": .string(draftInput)
        ]
    }
}

private final class ConferenceIdentityLinkIntakeCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceIdentityLinkIntakeCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "setDraftInput")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { _, _ in
            .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
        })

        await addInterceptForSet(requester: owner, key: "setDraftInput", setValueIntercept: { _, value, _ in
            await ConferenceIdentityLinkInboxStore.shared.setDraftInput(Self.string(from: value))
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { _, value, requester in
            await self.handleDispatchAction(value, requester: requester)
        })
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              case let .string(actionKeypath)? = object["keypath"] else {
            return .object([
                "status": .string("error"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        }

        switch actionKeypath {
        case "identityLink.importDraft":
            let imported = await ConferenceIdentityLinkInboxStore.shared.importDraft()
            return .object([
                "status": .string(imported ? "ok" : "error"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        case "identityLink.clear":
            await ConferenceIdentityLinkInboxStore.shared.clear()
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        case "identityLink.confirmLocalReview":
            await AppInitializer.initialize()
            let localIdentity = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) ?? requester
            await ConferenceIdentityLinkInboxStore.shared.confirmLocalReview(with: localIdentity)
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        case "identityLink.openLauncher":
            await MainActor.run {
                BindingConferenceNavigationBridge.postPop(
                    fallbackConfiguration: ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
                )
            }
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        default:
            return .object([
                "status": .string("error"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        }
    }

    private static func string(from value: ValueType) -> String {
        switch value {
        case let .string(string):
            return string
        default:
            return ""
        }
    }
}

private final class ConferenceDemoLauncherLocalCell: GeneralCell {
    private static let stagingHost = "staging.haven.digipomps.org"

    private var cachedState: Object = ConferenceDemoLauncherLocalCell.defaultState()

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceDemoLauncherLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, _ in
            guard let self else { return .string("failure") }
            return .object(self.cachedState)
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, _ in
            guard let self else { return .string("failure") }
            return await self.handleDispatchAction(value)
        })
    }

    private func handleDispatchAction(_ value: ValueType) async -> ValueType {
        guard case let .object(object) = value,
              case let .string(actionKeypath)? = object["keypath"] else {
            cachedState = Self.stateWithStatus(
                basedOn: cachedState,
                status: "Launcheren kunne ikke lese handlingen.",
                actionSummary: "Payloaden manglet action-keypath."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedState)
            ])
        }

        guard let configuration = configuration(for: actionKeypath) else {
            cachedState = Self.stateWithStatus(
                basedOn: cachedState,
                status: "Launcheren støtter ikke denne handlingen ennå.",
                actionSummary: "Ukjent launcher-handling: \(actionKeypath)"
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedState)
            ])
        }

        let successSummary = successSummary(for: actionKeypath, configurationName: configuration.name)
        cachedState = Self.stateWithStatus(
            basedOn: cachedState,
            status: "Åpner \(configuration.name)…",
            actionSummary: successSummary
        )
        scheduleWorkbenchLoad(configuration, successSummary: successSummary)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedState)
        ])
    }

    private func scheduleWorkbenchLoad(
        _ configuration: CellConfiguration,
        successSummary: String
    ) {
        Task { @MainActor [weak self] in
            BindingPortholeLoadBridge.post(configuration: configuration)
            guard let self else { return }
            self.cachedState = Self.stateWithStatus(
                basedOn: self.cachedState,
                status: "Launcheren åpnet \(configuration.name).",
                actionSummary: successSummary
            )
        }
    }

    private func configuration(for actionKeypath: String) -> CellConfiguration? {
        switch actionKeypath {
        case "launcher.openPublicSurface":
            return ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
                endpoint: "cell://\(Self.stagingHost)/ConferencePublicShell"
            )
        case "launcher.openIdentityLink":
            return ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()
        case "launcher.openParticipantCockpit":
            return ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                endpoint: "cell:///ConferenceParticipantPreviewShell"
            )
        case "launcher.openParticipantChat":
            return ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            )
        case "launcher.openControlTower":
            return ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
                endpoint: "cell:///ConferenceAdminPreviewShell"
            )
        case "launcher.openAIAssistant":
            return ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
                conferenceEndpoint: "cell://\(Self.stagingHost)/ConferenceParticipantPreviewShell",
                aiEndpoint: "cell://\(Self.stagingHost)/AIGateway"
            )
        default:
            return nil
        }
    }

    private func successSummary(for actionKeypath: String, configurationName: String) -> String {
        switch actionKeypath {
        case "launcher.openPublicSurface":
            return "Åpner den publiserte conference-flaten først."
        case "launcher.openIdentityLink":
            return "Åpner scaffold setup og identity-link review i Binding."
        case "launcher.openParticipantCockpit":
            return "Åpner deltagerportalen i samme demo-løp."
        case "launcher.openParticipantChat":
            return "Åpner den eksplisitte chatflaten for participant-flyten."
        case "launcher.openControlTower":
            return "Bytter til organizer-perspektivet i control tower."
        case "launcher.openAIAssistant":
            return "Åpner conference-copiloten side om side med participant preview-state."
        default:
            return "Åpner \(configurationName)."
        }
    }

    private static func stateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["statusSummary"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        return updated
    }

    private static func defaultState() -> Object {
        [
            "intro": .string("Dette er Binding sin parity-launcher for conference-demoen. Den holder seg til eksisterende conference-konfigurasjoner og bruker samme Porthole-session hele veien."),
            "statusSummary": .string("Launcheren er klar. Start med den publiserte public surface før du går videre til participant eller organizer."),
            "actionSummary": .string("Velg en act under for å åpne neste conference-flate."),
            "nextStepSummary": .string("Act 0 åpner public surface. Act 0.5 åpner scaffold setup og identity-link review. Derfra går du videre til participant cockpit, chat og control tower."),
            "readinessSummary": .string("Public opener, scaffold setup / identity link review, participant cockpit, explicit chat, control tower og AI assistant er tilgjengelige som egne konfigurasjoner i Binding."),
            "stretchSummary": .string("Nearby-radar forblir en tydelig merket Binding-only stretch, og er ikke del av den staging-first demo-historien."),
            "publicActSummary": .string("Vis publisert landing, spor og program som faktisk kommer fra CellScaffold på staging."),
            "identityLinkActSummary": .string("Åpne scaffold setup og review incoming identity-link challenge-data i Binding uten å omgå den delte cross-vault-protokollen."),
            "participantActSummary": .string("Fortsett i participant-portalen og åpne chatflaten eksplisitt når samtalen er startet."),
            "organizerActSummary": .string("Bytt deretter til control tower eller AI assistant for organizer-/briefing-perspektivet.")
        ]
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
