import Foundation
import CellBase

nonisolated struct ConferenceParticipantPreviewFallbackState {
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
    var recentActionSummary = "Participant preview is running locally in HAVEN because the staging preview was denied."
}

nonisolated struct ConferenceParticipantPreviewFallbackMessage: Equatable {
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

nonisolated struct ConferenceDemoPersona {
    var name: String
    var roleSummary: String
    var publicProfileDetail: String
    var fitContext: String
    var conversationStyle: String
    var suggestedOpening: String
    var simulatedAgentSummary: String
}

nonisolated struct ConferenceDemoPersonaSeed {
    var name: String?
    var roleSummary: String?
    var publicProfileDetail: String?
    var fitContext: String?
    var conversationStyle: String?
    var suggestedOpening: String?
    var simulatedAgentSummary: String?
    var starterReply: String?
}

nonisolated struct ConferenceDemoPersonaProvider {
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

nonisolated let conferenceDemoPersonaProvider = ConferenceDemoPersonaProvider()

nonisolated func conferenceFallbackDemoPersona(named rawName: String?) -> ConferenceDemoPersona {
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

nonisolated func conferenceDemoPersona(named rawName: String?, source sourceObject: Object? = nil) -> ConferenceDemoPersona {
    conferenceDemoPersonaProvider.persona(named: rawName, source: sourceObject)
}

nonisolated func conferenceDemoPersonaSeedObject(named rawName: String?) -> Object {
    conferenceDemoPersonaProvider.seedObject(named: rawName)
}

nonisolated func conferenceDemoReply(
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

nonisolated func conferenceDemoStarterMessage(for persona: ConferenceDemoPersona) -> String {
    persona.suggestedOpening
}

nonisolated func conferenceDemoStarterReply(for persona: ConferenceDemoPersona, source sourceObject: Object? = nil) -> String {
    conferenceDemoPersonaProvider.starterReply(named: persona.name, source: sourceObject)
}

actor ConferenceParticipantPreviewFallbackStateStore {
    static let shared = ConferenceParticipantPreviewFallbackStateStore()
    private static let maximumRetainedOwners = 12
    private static let memoryPressureRetainedOwners = 4

    private var statesByOwnerUUID: [String: ConferenceParticipantPreviewFallbackState] = [:]
    private var ownerRecency: [String] = []

    func load(for ownerUUID: String) -> ConferenceParticipantPreviewFallbackState? {
        guard let state = statesByOwnerUUID[ownerUUID] else {
            return nil
        }
        touch(ownerUUID)
        return state
    }

    func save(_ state: ConferenceParticipantPreviewFallbackState, for ownerUUID: String) {
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

nonisolated func conferenceRunRestoreSetupSynchronously(_ operation: @escaping @Sendable () async -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        await operation()
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 5)
}

func conferenceRestoredOwner(
    for cell: GeneralCell,
    decodedOwner: Identity?,
    fallbackOwnerUUID: String? = nil,
    fallbackDisplayName: String = "Conference Restore"
) async -> Identity {
    if let decodedOwner {
        return decodedOwner
    }

    let restoreRequester = Identity(UUID().uuidString, displayName: "Conference Restore", identityVault: nil)
    if let restoredOwner = try? await cell.getOwner(requester: restoreRequester) {
        return restoredOwner
    }

    if let fallbackOwnerUUID {
        if let vault = CellBase.defaultIdentityVault {
            return Identity(fallbackOwnerUUID, displayName: fallbackDisplayName, identityVault: vault)
        }

        return Identity(fallbackOwnerUUID, displayName: fallbackDisplayName, identityVault: nil)
    }

    return restoreRequester
}
