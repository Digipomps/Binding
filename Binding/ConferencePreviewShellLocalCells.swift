import Foundation
import CellBase

private enum ConferenceAdminPreviewCodingKeys: String, CodingKey {
    case discardedDraft
    case draftPublished
    case draftSubtitle
    case draftTitle
    case lastEditSummary
}

private func conferenceFixtureTimelineCard(title: String, subtitle: String, detail: String, note: String) -> ValueType {
    .object([
        "title": .string(title),
        "subtitle": .string(subtitle),
        "detail": .string(detail),
        "note": .string(note)
    ])
}

private func conferenceFixtureTitleDetailRow(title: String, detail: String) -> ValueType {
    .object([
        "title": .string(title),
        "detail": .string(detail)
    ])
}

private func conferenceFixtureTitleSubtitleDetailRow(title: String, subtitle: String, detail: String) -> ValueType {
    .object([
        "title": .string(title),
        "subtitle": .string(subtitle),
        "detail": .string(detail)
    ])
}

final class ConferenceParticipantPreviewShellLocalFallbackCell: GeneralCell {
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
    private var recentActionSummary = "Participant preview is running locally in HAVEN because the staging preview was denied."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        storeKey = owner.uuid
        try? await ensureRuntimeReady()
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

    override func installCellRuntimeBindingsForAccess() async throws {
        let owner = storedOwnerIdentity
        storeKey = owner.uuid
        await restoreStoredStateIfAvailable()
        await configure(owner: owner)
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
            "selectionBadge": .string(sessionBadge(for: note)),
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note)
        ])
    }

    private func sessionBadge(for note: String) -> String {
        let normalized = note.lowercased()
        if normalized.contains("focused") {
            return "AKTIVT FOKUS"
        }
        if normalized.contains("available") {
            return "SPOR"
        }
        if normalized.contains("matches") {
            return "MATCH"
        }
        if normalized.contains("recommended") {
            return "ANBEFALT"
        }
        if normalized.contains("saved") {
            return "LAGRET"
        }
        if normalized.contains("timeline") || normalized.contains("visible") {
            return "VISES NÅ"
        }
        return "AGENDA"
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
        .object([
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

final class ConferenceAdminPreviewShellLocalFallbackCell: GeneralCell {
    private var draftPublished = false
    private var discardedDraft = false
    private var lastEditSummary = "Redaktørutkastet er klart for gjennomgang."
    private var draftTitle = "AI & Digital Independence 2026"
    private var draftSubtitle = "Sovereign AI, identity, governance, and infrastructure."
    private var requestedSurface = "conferencePublicShell"
    private var requestedWindowHours = "24"
    private var discoveryRefreshCount = 0
    private var selectedAudienceSegment = "Public-facing organizers"
    private var pollingResultsRevealed = false
    private var simulationStatus = "Paused"
    private var simulationNextStep = "Start simuleringen når du vil teste organizer-flyten mot publisering og innsikt."
    private var simulatedNowLabel = "4 Jun 2026 · 08:30"
    private var sponsorRefreshCount = 0
    private var sponsorCapturedLeadCount = 0
    private var sponsorLeadCandidates = [
        "Municipal platform team",
        "Trust infrastructure lab"
    ]
    private var pendingAccessRequests: [AdminTimelineEntry] = [
        AdminTimelineEntry(
            title: "Public shell read access",
            subtitle: "Pending request",
            detail: "Needs preview-read access for Conference Public Shell for 24 hours.",
            note: "Awaiting organizer approval"
        )
    ]
    private var activeGrants: [AdminTimelineEntry] = [
        AdminTimelineEntry(
            title: "Sponsor dashboard handoff",
            subtitle: "Active grant",
            detail: "Read-only sponsor dashboard access is active for the partnership team.",
            note: "Expires in 18 hours"
        )
    ]
    private var accessRequestHistory: [AdminTimelineEntry] = [
        AdminTimelineEntry(
            title: "Agenda moderation access",
            subtitle: "History",
            detail: "Previous agenda moderation request was approved and later closed.",
            note: "Completed yesterday"
        )
    ]
    private var sessionThreadMessages: [AdminTranscriptMessage] = [
        AdminTranscriptMessage(
            title: "Ane Solberg",
            subtitle: "Participant follow-up thread",
            detail: "Del gjerne de oppdaterte programnotatene etter keynote. Det vil hjelpe oss å koordinere møtepunktene raskt.",
            note: "Latest shared participant message",
            senderInitials: "AS"
        ),
        AdminTranscriptMessage(
            title: "Organizer",
            subtitle: "Control Tower note",
            detail: "Speaker and facilities are confirmed. Publishing draft stays on hold until final room sync is green.",
            note: "Visible in shared organizer thread",
            senderInitials: "CT"
        )
    ]

    private struct AdminTimelineEntry {
        let title: String
        let subtitle: String
        let detail: String
        let note: String

        var value: ValueType {
            .object([
                "title": .string(title),
                "subtitle": .string(subtitle),
                "detail": .string(detail),
                "note": .string(note)
            ])
        }
    }

    private struct AdminTranscriptMessage {
        let title: String
        let subtitle: String
        let detail: String
        let note: String
        let senderInitials: String

        var value: ValueType {
            .object([
                "title": .string(title),
                "subtitle": .string(subtitle),
                "detail": .string(detail),
                "note": .string(note),
                "senderInitials": .string(senderInitials)
            ])
        }
    }

    required init(owner: Identity) async {
        await super.init(owner: owner)
        try? await ensureRuntimeReady()
    }

    nonisolated required init(from decoder: Decoder) throws {
        let stateContainer = try? decoder.container(keyedBy: ConferenceAdminPreviewCodingKeys.self)
        let decodedDiscardedDraft = try? stateContainer?.decodeIfPresent(Bool.self, forKey: .discardedDraft)
        let decodedDraftPublished = try? stateContainer?.decodeIfPresent(Bool.self, forKey: .draftPublished)
        let decodedDraftSubtitle = try? stateContainer?.decodeIfPresent(String.self, forKey: .draftSubtitle)
        let decodedDraftTitle = try? stateContainer?.decodeIfPresent(String.self, forKey: .draftTitle)
        let decodedLastEditSummary = try? stateContainer?.decodeIfPresent(String.self, forKey: .lastEditSummary)
        try super.init(from: decoder)
        if let decodedDiscardedDraft {
            discardedDraft = decodedDiscardedDraft
        }
        if let decodedDraftPublished {
            draftPublished = decodedDraftPublished
        }
        if let decodedDraftSubtitle, decodedDraftSubtitle.isEmpty == false {
            draftSubtitle = decodedDraftSubtitle
        }
        if let decodedDraftTitle, decodedDraftTitle.isEmpty == false {
            draftTitle = decodedDraftTitle
        }
        if let decodedLastEditSummary, decodedLastEditSummary.isEmpty == false {
            lastEditSummary = decodedLastEditSummary
        }
    }

    override func installCellRuntimeBindingsForAccess() async throws {
        await configure(owner: storedOwnerIdentity)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: ConferenceAdminPreviewCodingKeys.self)
        try container.encode(discardedDraft, forKey: .discardedDraft)
        try container.encode(draftPublished, forKey: .draftPublished)
        try container.encode(draftSubtitle, forKey: .draftSubtitle)
        try container.encode(draftTitle, forKey: .draftTitle)
        try container.encode(lastEditSummary, forKey: .lastEditSummary)
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")
        agreementTemplate.addGrant("rw--", for: "contentPublishing.setDraftTitle")
        agreementTemplate.addGrant("rw--", for: "contentPublishing.setDraftSubtitle")
        agreementTemplate.addGrant("rw--", for: "accessRequests.setRequestedSurface")
        agreementTemplate.addGrant("rw--", for: "accessRequests.setRequestedWindowHours")

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
        await addInterceptForSet(requester: owner, key: "contentPublishing.setDraftTitle", setValueIntercept: { [weak self] _, value, _ in
            guard let self else { return .string("failure") }
            self.draftTitle = self.stringValue(from: value, fallback: self.draftTitle)
            self.lastEditSummary = "Landing title updated in local organizer-preview."
            self.discardedDraft = false
            return .object([
                "status": .string("ok"),
                "state": .object(self.makeStateObject())
            ])
        })
        await addInterceptForSet(requester: owner, key: "contentPublishing.setDraftSubtitle", setValueIntercept: { [weak self] _, value, _ in
            guard let self else { return .string("failure") }
            self.draftSubtitle = self.stringValue(from: value, fallback: self.draftSubtitle)
            self.lastEditSummary = "Landing subtitle updated in local organizer-preview."
            self.discardedDraft = false
            return .object([
                "status": .string("ok"),
                "state": .object(self.makeStateObject())
            ])
        })
        await addInterceptForSet(requester: owner, key: "accessRequests.setRequestedSurface", setValueIntercept: { [weak self] _, value, _ in
            guard let self else { return .string("failure") }
            self.requestedSurface = self.stringValue(from: value, fallback: self.requestedSurface)
            return .object([
                "status": .string("ok"),
                "state": .object(self.makeStateObject())
            ])
        })
        await addInterceptForSet(requester: owner, key: "accessRequests.setRequestedWindowHours", setValueIntercept: { [weak self] _, value, _ in
            guard let self else { return .string("failure") }
            self.requestedWindowHours = self.stringValue(from: value, fallback: self.requestedWindowHours)
            return .object([
                "status": .string("ok"),
                "state": .object(self.makeStateObject())
            ])
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
        case "audienceDiscovery.refreshDiscovery":
            discoveryRefreshCount += 1
            selectedAudienceSegment = discoveryRefreshCount.isMultiple(of: 2)
                ? "Public-facing organizers"
                : "Policy and governance cluster"
            lastEditSummary = "Audience discovery refreshed in local organizer-preview."
        case "accessRequests.createRequest":
            let request = AdminTimelineEntry(
                title: requestedSurface,
                subtitle: "Pending request",
                detail: "Needs organizer-approved access window of \(requestedWindowHours) hour(s).",
                note: "Created from local organizer preview"
            )
            pendingAccessRequests.insert(request, at: 0)
            lastEditSummary = "Created a local access request for \(requestedSurface)."
        case "accessRequests.approveSelectedRequest":
            if let approved = pendingAccessRequests.first {
                pendingAccessRequests.removeFirst()
                activeGrants.insert(
                    AdminTimelineEntry(
                        title: approved.title,
                        subtitle: "Active grant",
                        detail: approved.detail,
                        note: "Approved in local organizer preview"
                    ),
                    at: 0
                )
                accessRequestHistory.insert(
                    AdminTimelineEntry(
                        title: approved.title,
                        subtitle: "History",
                        detail: "Approved organizer request for \(requestedWindowHours) hour(s).",
                        note: "Most recent access decision"
                    ),
                    at: 0
                )
                lastEditSummary = "Approved the selected local access request."
            }
        case "accessRequests.denySelectedRequest":
            if let denied = pendingAccessRequests.first {
                pendingAccessRequests.removeFirst()
                accessRequestHistory.insert(
                    AdminTimelineEntry(
                        title: denied.title,
                        subtitle: "History",
                        detail: "Denied organizer request for \(denied.title).",
                        note: "Most recent access decision"
                    ),
                    at: 0
                )
                lastEditSummary = "Denied the selected local access request."
            }
        case "accessRequests.expireSelectedGrant":
            if let expired = activeGrants.first {
                activeGrants.removeFirst()
                accessRequestHistory.insert(
                    AdminTimelineEntry(
                        title: expired.title,
                        subtitle: "History",
                        detail: "Expired organizer grant for \(expired.title).",
                        note: "Grant moved to history"
                    ),
                    at: 0
                )
                lastEditSummary = "Expired the selected local grant."
            }
        case "sessionThread.postMessage":
            let payload = object["payload"] ?? .null
            let organizerText: String
            if case let .object(payloadObject) = payload,
               case let .string(text)? = payloadObject["text"],
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                organizerText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                organizerText = "Organizer note from HAVEN control tower"
            }
            sessionThreadMessages.insert(
                AdminTranscriptMessage(
                    title: "Organizer",
                    subtitle: "Control Tower note",
                    detail: organizerText,
                    note: "Posted from local organizer preview",
                    senderInitials: "CT"
                ),
                at: 0
            )
            sessionThreadMessages.insert(
                AdminTranscriptMessage(
                    title: "Participant thread",
                    subtitle: "Shared relation update",
                    detail: "Participant-side thread acknowledged the note and kept follow-up visible in the shared relation state.",
                    note: "Simulated reply",
                    senderInitials: "PR"
                ),
                at: 1
            )
            sessionThreadMessages = Array(sessionThreadMessages.prefix(8))
            lastEditSummary = "Posted a local organizer note into the shared thread preview."
        case "sessionPolling.toggleRevealResults":
            pollingResultsRevealed.toggle()
            lastEditSummary = pollingResultsRevealed
                ? "Polling results are visible in local organizer-preview."
                : "Polling results are hidden in local organizer-preview."
        case "simulation.start":
            simulationStatus = "Running"
            simulationNextStep = "Simulation is running. Watch audience, access, and sponsor sections react in sync."
            simulatedNowLabel = "4 Jun 2026 · 09:10"
            lastEditSummary = "Started the local conference simulation."
        case "simulation.pause":
            simulationStatus = "Paused"
            simulationNextStep = "Simulation paused. Review organizer state before resuming."
            lastEditSummary = "Paused the local conference simulation."
        case "simulation.resume":
            simulationStatus = "Running"
            simulationNextStep = "Simulation resumed. Organizer metrics continue to move."
            simulatedNowLabel = "4 Jun 2026 · 09:40"
            lastEditSummary = "Resumed the local conference simulation."
        case "simulation.reset":
            simulationStatus = "Paused"
            simulationNextStep = "Simulation reset to the clean conference baseline."
            simulatedNowLabel = "4 Jun 2026 · 08:30"
            lastEditSummary = "Reset the local conference simulation."
        case "sponsorExhibitor.refreshDashboard":
            sponsorRefreshCount += 1
            lastEditSummary = "Sponsor dashboard refreshed in local organizer-preview."
        case "sponsorExhibitor.captureLeadOptIn":
            sponsorCapturedLeadCount += 1
            let capturedLeadName = sponsorLeadCandidates.first ?? "Conference prospect"
            sponsorLeadCandidates.removeAll(where: { $0 == capturedLeadName })
            accessRequestHistory = Array(accessRequestHistory.prefix(6))
            lastEditSummary = "Captured a local sponsor lead opt-in for \(capturedLeadName)."
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
        let publishedAtLabel: String
        let lastEditedAtLabel: String
        let lastEditedBy: String

        if draftPublished {
            contentStatus = "Draft publisert og klar for offentlig shell."
            draftWarning = "Ingen ventende redaktøradvarsler."
            nextAction = "Overvåk publisert innhold og oppdater run-of-show ved behov."
            draftTracks = []
            draftSessions = []
            publishedAtLabel = "Published at: 4 Jun 2026 · 08:30"
            lastEditedAtLabel = "Last edited: 4 Jun 2026 · 08:20"
            lastEditedBy = "Edited by: Organizer publishing desk"
        } else if discardedDraft {
            contentStatus = "Draft forkastet. Ny redaksjonell runde kreves."
            draftWarning = "Redaktørutkastet er fjernet fra publiseringskøen."
            nextAction = "Opprett et nytt draft før du går videre."
            draftTracks = []
            draftSessions = []
            publishedAtLabel = "Published at: not published"
            lastEditedAtLabel = "Last edited: 4 Jun 2026 · 08:22"
            lastEditedBy = "Edited by: Organizer publishing desk"
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
            publishedAtLabel = "Published at: waiting for publish"
            lastEditedAtLabel = "Last edited: 4 Jun 2026 · 08:18"
            lastEditedBy = "Edited by: Organizer publishing desk"
        }

        let accessCoverageSummary = "\(pendingAccessRequests.count) pending request(s), \(activeGrants.count) active grant(s)."
        let accessSelectionSummary = pendingAccessRequests.first?.title ?? "No request selected."
        let sponsorDashboardCards: [ValueType] = [
            titleDetailCard(title: "Warm leads", detail: "\(sponsorLeadCandidates.count + sponsorCapturedLeadCount) total"),
            titleDetailCard(title: "Captured opt-ins", detail: "\(sponsorCapturedLeadCount) captured"),
            titleDetailCard(title: "Refresh count", detail: "\(sponsorRefreshCount) refresh(es)")
        ]
        let sponsorRows: [ValueType] = [
            timelineCard(title: "Lead capture status", subtitle: "Sponsor dashboard", detail: "\(sponsorCapturedLeadCount) lead(s) captured with explicit opt-in.", note: "Organizer-approved"),
            timelineCard(title: "Handoff readiness", subtitle: "Sponsor dashboard", detail: "\(max(sponsorLeadCandidates.count, 1)) lead candidate(s) remain in queue.", note: "Ready for follow-up")
        ]
        let sponsorInterestHeatmap: [ValueType] = [
            titleDetailCard(title: "Governance", detail: "High overlap with sponsor interests"),
            titleDetailCard(title: "Identity", detail: "Strong continuing interest"),
            titleDetailCard(title: "Trust infrastructure", detail: "Cross-track pull remains strong")
        ]
        let sponsorCapturedLeads: [ValueType] = sponsorCapturedLeadCount == 0
            ? [timelineCard(title: "No captured leads yet", subtitle: "Sponsor inbox", detail: "Use capture lead to simulate an explicit sponsor handoff.", note: "Waiting for opt-in")]
            : (0..<sponsorCapturedLeadCount).map { index in
                timelineCard(
                    title: "Captured lead \(index + 1)",
                    subtitle: "Sponsor inbox",
                    detail: "Explicit opt-in recorded and ready for sponsor follow-up.",
                    note: "Captured in local organizer preview"
                )
            }
        let sponsorHandoffs: [ValueType] = [
            timelineCard(title: "Partnership team", subtitle: "Handoff", detail: "Warm governance leads are staged for sponsor follow-up.", note: "Local preview"),
            timelineCard(title: "Trust infrastructure sponsor", subtitle: "Handoff", detail: "Identity and verification leads are organized for outreach.", note: "Local preview")
        ]
        let threadMessageValues = sessionThreadMessages.map(\.value)
        let pollingResults: [ValueType] = pollingResultsRevealed
            ? [
                timelineCard(title: "Support transparent defaults", subtitle: "58%", detail: "Most attendees prefer transparent organizer defaults.", note: "Results revealed"),
                timelineCard(title: "Require explicit consent reminder", subtitle: "42%", detail: "Attendees want stronger consent reminders before sharing.", note: "Results revealed")
            ]
            : [
                timelineCard(title: "Results hidden", subtitle: "Organizer policy", detail: "Reveal is off until the session host decides to publish the outcome.", note: "Toggle reveal to inspect")
            ]
        let systemTimestampLabel = "Updated: \(Self.localizedTimestampLabel())"

        return [
            "workspace": .object([
                "title": .string("Conference Control Tower"),
                "subtitle": .string("Organizer-visning for eierskap, publisering, drift og innsikt."),
                "conferenceBadge": .string("Conference owner"),
                "opsBadge": .string("Ops ready"),
                "nextAction": .string(nextAction),
                "previewNotice": .string("Lokal organizer-preview brukes mens staging-preview er i flux. Contract og mørk UI holdes like.")
            ]),
            "followUpStory": .object([
                "headline": .string("Organizer sees the same follow-up reality participants act in."),
                "intro": .string("This section keeps participant follow-up, shared relations, and sponsor visibility aligned in one organizer story."),
                "sharedRelationSummary": .string("\(sessionThreadMessages.count) shared thread message(s) visible across organizer and participant shells."),
                "followUpSummary": .string("3 participant follow-up tracks remain active after keynote and nearby introductions."),
                "agreementSummary": .string("Agreement boundaries keep participant-only notes separate from organizer summaries and sponsor handoffs."),
                "sponsorSummary": .string("\(sponsorLeadCandidates.count) sponsor-ready lead candidate(s) remain in queue."),
                "boundaryNote": .string("Organizer summaries stay aggregate unless a relation explicitly allows deeper follow-up."),
                "nextAction": .string("Review shared relation evidence before approving any sponsor or publishing handoff."),
                "pulseCards": .list([
                    timelineCard(title: "Shared threads", subtitle: "Organizer + participant", detail: "\(sessionThreadMessages.count) messages keep the shared follow-up visible in both shells.", note: "In sync"),
                    timelineCard(title: "Meeting requests", subtitle: "Participant follow-up", detail: "\(pendingAccessRequests.count) pending organizer request(s) still affect next steps.", note: "Needs review"),
                    timelineCard(title: "Sponsor handoff", subtitle: "Lead readiness", detail: "\(sponsorLeadCandidates.count) lead candidate(s) are visible for sponsor follow-up when approved.", note: "Scoped")
                ]),
                "evidenceRows": .list([
                    timelineCard(title: "Participant portal", subtitle: "Shared relation evidence", detail: "Agenda, people, and meetings remain visible through the same relation-aware contract.", note: "Verified"),
                    timelineCard(title: "Organizer shell", subtitle: "Control Tower", detail: "Organizer actions reference the same shared relation state instead of a separate demo-only model.", note: "Contract aligned")
                ])
            ]),
            "insightStory": .object([
                "headline": .string("Organizer insights stay useful without breaking participant expectations."),
                "intro": .string("The insight story turns shared relation activity into aggregate organizer signals with clear privacy boundaries."),
                "organizerValueSummary": .string("Organizer can see attendance pressure, follow-up velocity, and interest clusters without exposing unnecessary personal detail."),
                "participantValueContract": .string("Participant value is preserved because organizer insight is derived from already-legitimate relation activity and aggregate telemetry."),
                "boundaryNote": .string("No organizer-only analytics should mutate participant state or reveal hidden profile fields."),
                "nextAction": .string("Use insights to adjust staffing, publishing, and sponsor routing before opening more flows."),
                "kpiCards": .list([
                    titleDetailCard(title: "Registrations", detail: "412 confirmed"),
                    titleDetailCard(title: "Meetings booked", detail: "87 across participant shell"),
                    titleDetailCard(title: "Shared follow-ups", detail: "\(sessionThreadMessages.count) active message(s)")
                ]),
                "topicTrendCards": .list([
                    titleDetailCard(title: "Governance", detail: "Trending up in public and organizer signals"),
                    titleDetailCard(title: "Identity", detail: "Stable high organizer and participant interest"),
                    titleDetailCard(title: "Trust infrastructure", detail: "Strong cross-track demand")
                ]),
                "evidenceRows": .list([
                    timelineCard(title: "Topic trend basis", subtitle: "Aggregate boundary", detail: "Trend cards are derived from consented aggregate conference activity.", note: "Policy safe"),
                    timelineCard(title: "Operational value", subtitle: "Organizer decisions", detail: "Publishing, staffing, and sponsor follow-up use the same evidence base.", note: "Actionable")
                ])
            ]),
            "access": .object([
                "headline": .string("Organizer access og ansvar"),
                "ownerScope": .string("Owner scope: conference entity og organizer VC."),
                "readScope": .string("Read scope: admin-shell, public-shell og sponsor handoff."),
                "writeScope": .string("Write scope: programdraft, alerts, ops og content publishing."),
                "deliveryScope": .string("Delivery scope: preview shells og publiserte conference views."),
                "storageScope": .string("Storage scope: organizer notes, publishing queue og metrics."),
                "notes": .string("Access-kontrakten er den samme som i CellScaffold; denne previewen er bare lokal fallback."),
                "agreementSummary": .string("Agreements stay surface-specific so public shell, admin shell, and sponsor handoff do not silently merge scopes."),
                "coverageSummary": .string(accessCoverageSummary),
                "selectionSummary": .string(accessSelectionSummary),
                "recommendedConfigurationSummary": .string("Recommended next surface: \(requestedSurface) for \(requestedWindowHours) hour(s)."),
                "surfaceSummary": .string("Public shell is publish-oriented, sponsor shell is handoff-oriented, and organizer shell stays operational."),
                "nextAction": .string("Approve or deny the next request before expanding surface coverage."),
                "surfaceMatrix": .list([
                    timelineCard(title: "Conference public shell", subtitle: "Published surface", detail: "Readable as a published organizer asset.", note: "Scoped"),
                    timelineCard(title: "Conference sponsor shell", subtitle: "Lead follow-up", detail: "Readable after explicit sponsor handoff.", note: "Scoped"),
                    timelineCard(title: "Conference admin shell", subtitle: "Organizer control", detail: "Full organizer read/write contract.", note: "Owner")
                ]),
                "liveAgreementRows": .list(activeGrants.map(\.value)),
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
                "publishedAtLabel": .string(publishedAtLabel),
                "lastEditedAtLabel": .string(lastEditedAtLabel),
                "lastEditedBy": .string(lastEditedBy),
                "lastEditSummary": .string(lastEditSummary),
                "draftWarning": .string(draftWarning),
                "draft": .object([
                    "title": .string(draftTitle),
                    "subtitle": .string(draftSubtitle)
                ]),
                "preview": .object([
                    "programSummary": .string("Program preview er konsistent med dagens run-of-show."),
                    "trackSummary": .string("2 draft tracks er klare til review."),
                    "sessionSummary": .string("2 draft sessions venter på siste godkjenning."),
                    "facilitySummary": .string("Venue- og room-data er på plass."),
                    "peopleSummary": .string("Speaker cards er klare for publisering."),
                    "articleSummary": .string("Landing-artikkel og agenda-artikkel er synkronisert.")
                ]),
                "draftTracks": .list(draftTracks),
                "draftSessions": .list(draftSessions),
                "draftFacilities": .list([
                    timelineCard(title: "Oslo Harbor Forum", subtitle: "Facility draft", detail: "Wayfinding and room descriptions are ready.", note: "Pending publish"),
                    timelineCard(title: "Studio 2", subtitle: "Facility draft", detail: "Moderator table and AV notes are synced.", note: "Pending publish")
                ]),
                "draftPeople": .list([
                    timelineCard(title: "Ane Solberg", subtitle: "Speaker profile", detail: "Bio and role summary are updated for publishing.", note: "Pending publish"),
                    timelineCard(title: "Mads Hovden", subtitle: "Speaker profile", detail: "Panel participation is confirmed.", note: "Pending publish")
                ]),
                "draftArticles": .list([
                    timelineCard(title: "Landing article", subtitle: "Draft article", detail: "Front page framing is aligned with the current program.", note: "Pending publish"),
                    timelineCard(title: "Agenda article", subtitle: "Draft article", detail: "Highlights and track summaries are synchronized.", note: "Pending publish")
                ])
            ]),
            "audienceDiscovery": .object([
                "headline": .string("Audience Discovery"),
                "intro": .string("Audience discovery helps organizers understand which segments are ready for public or sponsor-facing follow-up."),
                "status": .string("Audience discovery is stable in local organizer preview."),
                "scenarioSummary": .string("Current segment focus: \(selectedAudienceSegment)."),
                "alignmentSummary": .string("Segment alignment is strongest between governance, identity, and trust infrastructure."),
                "permissionSummary": .string("Discovery stays within organizer-approved aggregate boundaries unless a deeper access request is approved."),
                "selectedSegmentSummary": .string("Selected segment: \(selectedAudienceSegment)."),
                "nextAction": .string("Refresh discovery before changing sponsor routing or public landing emphasis."),
                "refreshSummary": .string("Discovery refreshed \(discoveryRefreshCount) time(s) in this local preview."),
                "segments": .list([
                    titleDetailCard(title: "Public-facing organizers", detail: "Strong fit for public landing and control tower views"),
                    titleDetailCard(title: "Policy and governance cluster", detail: "Best fit for organizer and sponsor follow-up"),
                    titleDetailCard(title: "Trust infrastructure builders", detail: "Cross-track audience with sponsor relevance")
                ]),
                "queryReadyEntities": .list([
                    titleDetailCard(title: "Conference public shell", detail: "Readable now for published metadata review"),
                    titleDetailCard(title: "Conference admin shell", detail: "Readable now for organizer insight and publishing")
                ]),
                "accessNeededEntities": .list([
                    titleDetailCard(title: "Conference sponsor shell", detail: "Requires explicit sponsor handoff or grant"),
                    titleDetailCard(title: "Public profile enrichment", detail: "Requires deeper access beyond basic public metadata")
                ]),
                "recommendedQuerySurfaces": .list([
                    titleDetailCard(title: "Control Tower", detail: "Best for organizer insight and publishing decisions"),
                    titleDetailCard(title: "Conference public surface", detail: "Best for validating published promise and timing")
                ])
            ]),
            "accessRequests": .object([
                "headline": .string("Access Requests"),
                "intro": .string("Manage surface-scoped requests and grants without silently expanding conference access."),
                "status": .string("Request queue is operational in local organizer preview."),
                "policySummary": .string("Every request stays bound to a named surface, duration window, and organizer-approved reason."),
                "requestSummary": .string("\(pendingAccessRequests.count) pending request(s) ready for review."),
                "coverageSummary": .string("\(activeGrants.count) active grant(s) currently extend organizer-approved access."),
                "selectionSummary": .string(accessSelectionSummary),
                "grantBoundary": .string("Grant boundary stays surface-specific and time-bounded."),
                "recommendedConfigurationSummary": .string("Recommended next request: \(requestedSurface) for \(requestedWindowHours) hour(s)."),
                "nextAction": .string("Approve, deny, or expire the next request before moving on."),
                "editor": .object([
                    "requestedSurface": .string(requestedSurface),
                    "requestedWindowHours": .string(requestedWindowHours)
                ]),
                "pendingRequests": .list(pendingAccessRequests.map(\.value)),
                "activeGrants": .list(activeGrants.map(\.value)),
                "history": .list(accessRequestHistory.map(\.value))
            ]),
            "sessionThread": .object([
                "headline": .string("Session Threads"),
                "intro": .string("Session threads let organizers see the shared discussion state without leaving the control tower."),
                "sessionSummary": .string("2 active session thread(s) are visible for organizer follow-up."),
                "participationSummary": .string("Participants and organizers are sharing the same thread contract."),
                "discoverySummary": .string("Discovery-driven follow-up is visible when a participant starts a thread."),
                "privacySummary": .string("Only relation-safe thread summaries and messages are visible here."),
                "lastActionSummary": .string(lastEditSummary),
                "sessions": .list([
                    timelineCard(title: "Opening keynote", subtitle: "Shared thread", detail: "Organizer notes and participant follow-up share the same thread contract.", note: "Live"),
                    timelineCard(title: "Shared relations roundtable", subtitle: "Shared thread", detail: "Participant questions and organizer guidance remain aligned.", note: "Live")
                ]),
                "messages": .list(threadMessageValues),
                "topicClusters": .list([
                    titleDetailCard(title: "Governance", detail: "Most discussed in organizer and participant follow-up"),
                    titleDetailCard(title: "Identity", detail: "Stable session-thread interest"),
                    titleDetailCard(title: "Trust infrastructure", detail: "Shows strong cross-thread pull")
                ])
            ]),
            "sessionPolling": .object([
                "headline": .string("Session Polling"),
                "intro": .string("Polling lets organizers test session sentiment while keeping reveal control explicit."),
                "sessionSummary": .string("Polling is attached to the opening keynote in this local preview."),
                "privacySummary": .string("Poll participation is aggregate until results are explicitly revealed."),
                "questionSummary": .string("Current question: What should organizers prioritize after keynote?"),
                "voteSummary": .string("83 vote(s) registered in the local simulation."),
                "revealSummary": .string(pollingResultsRevealed ? "Results are revealed to the organizer." : "Results are still hidden."),
                "lastActionSummary": .string(lastEditSummary),
                "nextAction": .string("Toggle reveal to inspect aggregate outcomes."),
                "sessions": .list([
                    timelineCard(title: "Opening keynote", subtitle: "Polling session", detail: "Primary polling surface for organizer preview.", note: "Active")
                ]),
                "options": .list([
                    timelineCard(title: "Transparent defaults", subtitle: "Option A", detail: "Emphasize transparent organizer defaults.", note: "Most selected"),
                    timelineCard(title: "Consent reminders", subtitle: "Option B", detail: "Emphasize consent reminders before sharing.", note: "Close second")
                ]),
                "results": .list(pollingResults)
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
            "simulation": .object([
                "headline": .string("Simulation Studio"),
                "intro": .string("Simulation Studio drives a reproducible organizer scenario without leaving the same shell contract."),
                "status": .string("Simulation status: \(simulationStatus)."),
                "nextStep": .string(simulationNextStep),
                "scenario": .object([
                    "scenarioSummary": .string("Organizer preview scenario: keynote day with active publishing, access, and sponsor follow-up."),
                    "typeSummary": .string("Scenario type: conference operations rehearsal."),
                    "scaleSummary": .string("Scale: medium conference with public, participant, and sponsor surfaces."),
                    "sizeSummary": .string("Population size: 400+ attendees, 80+ meetings, active shared relations."),
                    "compositionSummary": .string("Composition: organizers, speakers, participants, sponsors, and facilities.")
                ]),
                "clock": .object([
                    "headline": .string("Simulation clock"),
                    "statusSummary": .string("Clock status follows the \(simulationStatus.lowercased()) simulation state."),
                    "simulatedNowLabel": .string(simulatedNowLabel)
                ]),
                "population": .object([
                    "headline": .string("Population"),
                    "summary": .string("Population stays consistent across organizer, participant, and public shells in this scenario.")
                ]),
                "playback": .object([
                    "headline": .string("Playback"),
                    "recordingSummary": .string("Playback is lightweight and deterministic so organizer actions can be replayed safely.")
                ])
            ]),
            "insights": .object([
                "intro": .string("Organizer insight dashboard keeps aggregate conference signals readable inside the same shell."),
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
            "system": .object([
                "headline": .string("System Load & Storage"),
                "intro": .string("System status summarizes resolver, storage, and host health for the local organizer preview."),
                "status": .string("System status is stable for this local organizer shell."),
                "accessSummary": .string("Startup vault and local organizer cells are available without bridge timeout."),
                "resolverSummary": .string("CellResolver is serving local conference preview cells and porthole bindings."),
                "storageSummary": .string("Local organizer preview stores state in the same portable keypath model as the rest of HAVEN."),
                "hostSummary": .string("Host: HAVEN local runtime on My Mac."),
                "loadSummary": .string("Load is moderate with organizer, public, AI, and identity-link shells available."),
                "memorySummary": .string("Memory pressure is normal for this smoke configuration."),
                "ioSummary": .string("I/O is stable; no bridge reconnect loop is active."),
                "topProcessSummary": .string("HAVEN remains the top local conference process."),
                "persistedCellSummary": .string("Persisted cells are available for organizer preview and porthole state."),
                "timestampSummary": .string(systemTimestampLabel),
                "resolverHighlights": .list([
                    titleDetailCard(title: "ConferenceAdminPreviewShell", detail: "Resolved locally"),
                    titleDetailCard(title: "ConferenceParticipantPreviewShell", detail: "Resolved locally"),
                    titleDetailCard(title: "ConferenceAIGatewayPreview", detail: "Expected from scaffold bridge")
                ]),
                "topProcesses": .list([
                    timelineCard(title: "HAVEN", subtitle: "Organizer runtime", detail: "Primary local process serving the conference demo.", note: "Healthy"),
                    timelineCard(title: "Porthole", subtitle: "Shared shell host", detail: "Absorbs conference configurations and bindings.", note: "Healthy")
                ]),
                "persistedCells": .list([
                    timelineCard(title: "ConferenceAdminPreviewShell", subtitle: "Persisted organizer state", detail: "Organizer preview keeps local mutable state available.", note: "Local"),
                    timelineCard(title: "Porthole", subtitle: "Persisted shell state", detail: "Porthole keeps the active conference configuration visible.", note: "Local")
                ])
            ]),
            "sponsor": .object([
                "intro": .string("Sponsor / Exhibitor keeps sponsor-safe aggregates and handoff signals separate from organizer-only detail."),
                "status": .string("Sponsor dashboard is available in local organizer preview."),
                "aggregateBoundary": .string("Sponsor cards and rows stay within organizer-approved aggregate and handoff boundaries."),
                "dashboardSummary": .string("Sponsor handoff er klar og følger organizer-policy."),
                "engagementSummary": .string("Lead engagement viser god overgang til sponsor-shell."),
                "candidateSummary": .string("\(sponsorLeadCandidates.count) warm lead candidate(s) remain before capture."),
                "capturedSummary": .string("\(sponsorCapturedLeadCount) explicit sponsor opt-in lead(s) captured."),
                "handoffSummary": .string("3 varme leads er klare for videre sponsor-oppfølging."),
                "dashboardCards": .list(sponsorDashboardCards),
                "dashboardRows": .list(sponsorRows),
                "interestHeatmap": .list(sponsorInterestHeatmap),
                "leadCandidates": .list([
                    timelineCard(title: sponsorLeadCandidates.first ?? "Municipal platform team", subtitle: "Warm lead", detail: "Governance + identity overlap.", note: "Ready for sponsor handoff"),
                    timelineCard(title: sponsorLeadCandidates.dropFirst().first ?? "Trust infrastructure lab", subtitle: "Warm lead", detail: "Shared interest in claims and verification.", note: "Ready for sponsor handoff")
                ]),
                "capturedLeads": .list(sponsorCapturedLeads),
                "handoffs": .list(sponsorHandoffs)
            ])
        ]
    }

    private func stringValue(from value: ValueType, fallback: String) -> String {
        switch value {
        case .string(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        case .integer(let value):
            return String(value)
        case .number(let value):
            return String(value)
        case .float(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        default:
            return fallback
        }
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

    private static func localizedTimestampLabel(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "d MMM yyyy · HH:mm"
        return formatter.string(from: date)
    }
}

final class ConferencePublicShellFixtureCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "feed")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state") { _, _ in
            .object(Self.stateObject)
        }
        await addInterceptForGet(requester: owner, key: "skeletonConfiguration") { _, _ in
            .null
        }
        await addInterceptForSet(requester: owner, key: "dispatchAction") { _, _, _ in
            .object([
                "status": .string("ok"),
                "state": .object(Self.stateObject)
            ])
        }
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private static let stateObject: Object = [
        "workspace": .object([
            "title": .string("AI & Digital Independence"),
            "subtitle": .string("Conference public surface for the live program, people, articles and facilities."),
            "dateBadge": .string("30. mars"),
            "venueBadge": .string("Oslo"),
            "ctaTitle": .string("Join the public program"),
            "ctaDetail": .string("Tracks, sessions and facilities are now published for everyone.")
        ]),
        "access": .object([
            "headline": .string("Public conference publication scope"),
            "ownerScope": .string("Owner: conference public publisher"),
            "readScope": .string("Read: public audience"),
            "writeScope": .string("Write: public publishing pipeline"),
            "deliveryScope": .string("Delivery: published surfaces only"),
            "storageScope": .string("Storage: scaffold publication state"),
            "notes": .string("This local fixture mirrors the public-shell contract for demo and verification."),
            "keypathMatrix": .list([
                conferenceFixtureTimelineCard(title: "workspace.*", subtitle: "Public landing", detail: "Title, badges and CTA", note: "Readable"),
                conferenceFixtureTimelineCard(title: "tracks/sessions", subtitle: "Published program", detail: "Tracks and sessions visible to attendees", note: "Readable")
            ])
        ]),
        "tracksIntro": .string("Tracks currently highlighted for the public audience."),
        "tracks": .list([
            conferenceFixtureTitleDetailRow(title: "Trusted AI", detail: "Governance, controls and public interest deployment."),
            conferenceFixtureTitleDetailRow(title: "Digital Independence", detail: "Infrastructure, procurement and resilient service design.")
        ]),
        "sessionsIntro": .string("Featured sessions from the published conference program."),
        "sessions": .list([
            conferenceFixtureTitleSubtitleDetailRow(title: "Opening keynote", subtitle: "Main stage", detail: "Why trustworthy AI needs better institutional memory."),
            conferenceFixtureTitleSubtitleDetailRow(title: "Implementation roundtable", subtitle: "Room B", detail: "How public-sector teams move from pilots to dependable delivery.")
        ]),
        "peopleIntro": .string("People currently highlighted on the public surface."),
        "people": .list([
            conferenceFixtureTitleSubtitleDetailRow(title: "Ane Solberg", subtitle: "Public sector interoperability", detail: "Speaking on procurement, coordination and follow-up."),
            conferenceFixtureTitleSubtitleDetailRow(title: "Mads Hovden", subtitle: "Policy and compliance", detail: "Moderating the governance track discussion.")
        ]),
        "articlesIntro": .string("Editorial highlights and conference explainers."),
        "articles": .list([
            conferenceFixtureTitleSubtitleDetailRow(title: "Why this conference now", subtitle: "Editorial", detail: "Explains the public framing for AI and digital independence."),
            conferenceFixtureTitleSubtitleDetailRow(title: "How to navigate the day", subtitle: "Guide", detail: "Program guide for attendees and visitors.")
        ]),
        "facilitiesIntro": .string("Facilities and practical venue information."),
        "facilities": .list([
            conferenceFixtureTitleSubtitleDetailRow(title: "Main stage", subtitle: "Ground floor", detail: "Keynotes and plenary sessions."),
            conferenceFixtureTitleSubtitleDetailRow(title: "Quiet work area", subtitle: "Second floor", detail: "Space for follow-up and focused conversation.")
        ])
    ]
}

final class ConferenceSponsorShellFixtureCell: GeneralCell {
    private var exportCount = 1
    private var retentionSweepCount = 0
    private var statusSummary = "Inbox is synchronized."
    private var exportSummary = "Last export pack prepared 10 minutes ago."
    private var reviewSummary = "2 review items in the retention queue."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state") { [weak self] _, _ in
            guard let self else { return .null }
            return .object(self.stateObject())
        }
        await addInterceptForGet(requester: owner, key: "skeletonConfiguration") { _, _ in
            .null
        }
        await addInterceptForSet(requester: owner, key: "dispatchAction") { [weak self] _, value, _ in
            guard let self else { return .string("failure") }
            return await self.handleDispatchAction(value)
        }
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func handleDispatchAction(_ value: ValueType) async -> ValueType {
        guard case let .object(object) = value,
              case let .string(actionKeypath)? = object["keypath"] else {
            return .string("error: invalid action payload")
        }

        switch actionKeypath {
        case "sponsorInbox.refreshState":
            statusSummary = "Inbox refreshed locally for the conference demo."
        case "sponsorInbox.exportPack":
            exportCount += 1
            exportSummary = "Prepared export pack #\(exportCount) in the local sponsor fixture."
        case "sponsorInbox.runRetentionSweep":
            retentionSweepCount += 1
            reviewSummary = "Retention sweep #\(retentionSweepCount) completed locally. Remaining queue is small."
        default:
            statusSummary = "Handled \(actionKeypath) in the local sponsor fixture."
        }

        return .object([
            "status": .string("ok"),
            "state": .object(stateObject())
        ])
    }

    private func stateObject() -> Object {
        [
            "workspace": .object([
                "title": .string("Conference Sponsor Follow-up"),
                "subtitle": .string("Sponsor-owned inbox, compliance and retention overview."),
                "conferenceBadge": .string("Conference"),
                "sponsorBadge": .string("Sponsor"),
                "pipelineBadge": .string("Pipeline active"),
                "retentionBadge": .string("Retention ready"),
                "creditBadge": .string("Credits healthy"),
                "nextStep": .string("Refresh the inbox, prepare export, and clear the retention review queue."),
                "previewNotice": .string("Local fixture mirrors the sponsor-shell contract for deterministic demo use.")
            ]),
            "access": .object([
                "headline": .string("Sponsor follow-up access scope"),
                "ownerScope": .string("Owner: sponsor workspace"),
                "readScope": .string("Read: sponsor lead inbox"),
                "writeScope": .string("Write: sponsor follow-up operations"),
                "deliveryScope": .string("Delivery: sponsor exports and unlock handoff"),
                "storageScope": .string("Storage: consented sponsor data only"),
                "notes": .string("Retention and export steps stay inside sponsor-owned state."),
                "keypathMatrix": .list([
                    conferenceFixtureTimelineCard(title: "followUp.*", subtitle: "Lead inbox", detail: "Pickup and qualified leads", note: "Readable"),
                    conferenceFixtureTimelineCard(title: "retention.*", subtitle: "Retention controls", detail: "Unlocks, reclaim and review queue", note: "Readable")
                ])
            ]),
            "followUp": .object([
                "intro": .string("Lead inbox for sponsor-owned pickup and qualification."),
                "pickupSummary": .string("2 pickup leads waiting."),
                "qualificationSummary": .string("1 qualified lead ready for export."),
                "status": .string(statusSummary),
                "pickupLeads": .list([
                    conferenceFixtureTimelineCard(title: "Ingrid Nilsen", subtitle: "Municipal AI lead", detail: "Asked for a short follow-up after the keynote.", note: "Pickup"),
                    conferenceFixtureTimelineCard(title: "Jon Hauge", subtitle: "Digital procurement", detail: "Interested in sponsor roundtable materials.", note: "Pickup")
                ]),
                "qualifiedLeads": .list([
                    conferenceFixtureTimelineCard(title: "Lea Heger", subtitle: "Service design", detail: "Qualified after consent review and sponsor handoff.", note: "Qualified")
                ])
            ]),
            "compliance": .object([
                "intro": .string("Consent, agreement and chronicle review for sponsor follow-up."),
                "consentSummary": .string("All exported leads have explicit consent receipts."),
                "agreementSummary": .string("Agreement template is current."),
                "chronicleSummary": .string("Chronicle entries ready for sponsor audit."),
                "status": .string("Compliance checks are green."),
                "consentReceipts": .list([
                    conferenceFixtureTimelineCard(title: "Receipt #104", subtitle: "Lea Heger", detail: "Consent captured for sponsor follow-up export.", note: "Valid")
                ])
            ]),
            "retention": .object([
                "creditSummary": .string("Credits remain within sponsor allocation."),
                "unlockSummary": .string("1 unlock action is pending approval."),
                "reclaimSummary": .string("No reclaims needed right now."),
                "reviewSummary": .string(reviewSummary),
                "policySummary": .string("Retention policy is aligned with sponsor agreement."),
                "slaSummary": .string("Next retention review due tomorrow."),
                "exportStatus": .string(exportSummary),
                "reviewQueue": .list([
                    conferenceFixtureTimelineCard(title: "Review Lea Heger", subtitle: "Retention queue", detail: "Check unlock scope before export.", note: "Pending"),
                    conferenceFixtureTimelineCard(title: "Review Ingrid Nilsen", subtitle: "Retention queue", detail: "Confirm follow-up objective and SLA.", note: "Pending")
                ]),
                "unlockedLeads": .list([
                    conferenceFixtureTimelineCard(title: "Mads Hovden", subtitle: "Unlocked lead", detail: "Ready for sponsor-owned next step.", note: "Unlocked")
                ])
            ])
        ]
    }
}
