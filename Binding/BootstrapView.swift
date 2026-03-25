import SwiftUI
import CellBase
import CellApple

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
        let recentMessages = recentMessageTexts.map { text in
            ValueType.object([
                "title": .string("Shared thread"),
                "detail": .string(text),
                "note": .string("Nylig oppfølging")
            ])
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
                "chatSummary": .string("\(recentMessageTexts.count) aktive oppfølgingstråder er klare."),
                "connections": .list([
                    connectionCard(title: "Digital Governance Forum", subtitle: "Shared contact", detail: "Felles oppfølging på offentlig samordning.", note: "Warm"),
                    connectionCard(title: "Trust Infrastructure Lab", subtitle: "Meeting collaborator", detail: "Tidligere møte koblet til ny oppfølging.", note: "Active")
                ]),
                "confirmedMeetings": .list([
                    timelineCard(title: "Morning follow-up", subtitle: "11:45", detail: "Møt teamet bak delte relasjoner og drift.", note: "Shared connection")
                ]),
                "recentMessages": .list(recentMessages)
            ])
        ]
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
