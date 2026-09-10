// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  InvitationCell.swift
//  Binding
//
//  Turns "inviter Vegar" into a signed ticket, a short link, and a ready
//  message — and then stops. The cell never sends anything. It hands the app a
//  `mailto:` or `sms:` URL and the person presses send.
//
//  It does reach the network once, at prepare time, to publish the ticket to
//  the scaffold. That single call buys three things nothing else could:
//
//    * a link short enough to survive an SMS
//    * a reply channel with an actual receiver, so
//      `send_contact_request_to_issuer` stops being a promise we cannot keep
//    * a real open/joined signal instead of the issuer ticking a box by hand
//
//  Publishing is refusable. Without it the invitation still works over e-mail
//  as a self-contained link, and the surface says which mode it is in rather
//  than pretending they are the same.
//

import Foundation
import CellBase

final class BindingInvitationCell: GeneralCell {
    static let endpoint = "cell:///Invitation"
    static let sourceCellName = "BindingInvitationCell"
    static let relationsEndpoint = "cell:///Relations"
    static let contactEndpointEndpoint = "cell:///ContactEndpoint"

    private enum CodingKeys: String, CodingKey {
        case outbox
        case revoked
        case settings
        case inbox
        case lastResult
    }

    /// One issued invitation, and what happened to it.
    private struct OutboxEntry: Codable, Equatable {
        var ticket: HavenInviteTicket
        var relationID: String
        var recipientDisplayName: String
        /// Kept locally so the person can see who it went to. Never leaves the
        /// device — only the truncated audience token travels in the link.
        var recipientEndpointRaw: String
        var recipientEndpointKind: String
        var channel: String
        var link: String?
        var appLink: String?
        var shortLink: String?
        var subject: String
        var body: String
        var handoffURL: String?
        var state: HavenInviteState
        var published: Bool
        var statusKey: String?
        var preparedAt: Date
        var sentAt: Date?
        var openedAt: Date?
        var openCount: Int
        var respondedAt: Date?
        var resultingEntityRef: String?
        var contactRequestCount: Int
    }

    private struct Settings: Codable, Equatable {
        var landingBase: String = ""
        var issuerDisplayName: String = ""
        var issuerEntityRef: String?
        /// The `ContactEndpoint` id the invitee may reply to. Without one the
        /// ticket drops the reply capability instead of advertising it.
        var contactEndpointID: String?
        var defaultNote: String = ""
        var ttlDays: Int = 14
        /// Invitations sent per rolling 24 hours. A 400-row import plus no cap
        /// is how a domain earns a spam reputation in one evening.
        var dailyLimit: Int = 25
        var autoPublish: Bool = true

        static let `default` = Settings()
    }

    private struct RevocationEntry: Codable, Equatable {
        var ticketID: String
        var reason: String
        var revokedAt: Date
    }

    private struct InboxEntry: Codable, Equatable {
        var request: HavenInviteContactRequest
        var receivedAt: Date
        var deliveredToEndpoint: Bool
        var deliveryNote: String?
    }

    private let stateQueue = DispatchQueue(label: "Binding.BindingInvitationCell.State")

    private nonisolated(unsafe) var outbox: [OutboxEntry] = []
    private nonisolated(unsafe) var revoked: [RevocationEntry] = []
    private nonisolated(unsafe) var settings: Settings = .default
    private nonisolated(unsafe) var inbox: [InboxEntry] = []
    private nonisolated(unsafe) var lastResult: Object = [:]

    required init(owner: Identity) async {
        await super.init(owner: owner)
        stateQueue.sync {
            if settings.issuerDisplayName.isEmpty {
                settings.issuerDisplayName = owner.displayName
            }
            lastResult = HavenValue.ok("Klar til å lage en invitasjon.", sideEffect: false)
        }
        try? await ensureRuntimeReady()
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outbox = try container.decodeIfPresent([OutboxEntry].self, forKey: .outbox) ?? []
        revoked = try container.decodeIfPresent([RevocationEntry].self, forKey: .revoked) ?? []
        settings = try container.decodeIfPresent(Settings.self, forKey: .settings) ?? .default
        inbox = try container.decodeIfPresent([InboxEntry].self, forKey: .inbox) ?? []
        lastResult = try container.decodeIfPresent(Object.self, forKey: .lastResult) ?? [:]
        try super.init(from: decoder)
    }

    override func installCellRuntimeBindingsForAccess() async throws {
        await setup(owner: storedOwnerIdentity)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync { (outbox, revoked, settings, inbox, lastResult) }
        try container.encode(snapshot.0, forKey: .outbox)
        try container.encode(snapshot.1, forKey: .revoked)
        try container.encode(snapshot.2, forKey: .settings)
        try container.encode(snapshot.3, forKey: .inbox)
        try container.encode(snapshot.4, forKey: .lastResult)
    }

    private func setup(owner: Identity) async {
        for key in readableKeys {
            agreementTemplate.addGrant("r---", for: key)
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                return self.readValue(for: key)
            }
        }
        for key in writableKeys {
            agreementTemplate.addGrant("rw--", for: key)
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
                return await self.writeValue(for: key, value: value, requester: requester)
            }
        }
    }

    private var readableKeys: [String] {
        [
            "state",
            "invite.state",
            "invite.outbox",
            "invite.inbox",
            "invite.settings",
            "invite.revoked",
            "invite.lastResult",
            "invite.boundaryStatement",
            "providerDescriptor",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    private var writableKeys: [String] {
        [
            "invite.configure",
            "invite.prepare",
            "invite.publish",
            "invite.openPreparedMessage",
            "invite.markSent",
            "invite.refreshStatus",
            "invite.pullContactRequests",
            "invite.acceptContactRequest",
            "invite.recordJoined",
            "invite.recordDeclined",
            "invite.revoke",
            "invite.verify",
            "invite.clearOutbox"
        ]
    }

    private func readValue(for key: String) -> ValueType {
        switch key {
        case "state", "invite.state":
            return .object(stateObject())
        case "invite.outbox":
            return .list(outboxRows().map(ValueType.object))
        case "invite.inbox":
            return .list(inboxRows().map(ValueType.object))
        case "invite.settings":
            return .object(settingsObject())
        case "invite.revoked":
            return .list(stateQueue.sync { revoked }.map { entry in
                .object([
                    "ticketID": .string(entry.ticketID),
                    "reason": .string(entry.reason),
                    "revokedAtText": .string(HavenValue.readable(entry.revokedAt))
                ])
            })
        case "invite.lastResult":
            return .object(stateQueue.sync { lastResult })
        case "invite.boundaryStatement":
            return .string(HavenInviteCopy.boundaryLine)
        case "providerDescriptor":
            return .object(providerDescriptor())
        case "purposeGoal":
            return .object(purposeGoal())
        case "skeletonConfiguration":
            return .cellConfiguration(Self.menuConfiguration())
        default:
            return .null
        }
    }

    private func writeValue(for key: String, value: ValueType, requester: Identity) async -> ValueType {
        switch key {
        case "invite.configure":
            return .object(configure(value))
        case "invite.prepare":
            return .object(await prepare(value, requester: requester))
        case "invite.publish":
            return .object(await publish(value))
        case "invite.openPreparedMessage":
            return .object(await openPreparedMessage(value, requester: requester))
        case "invite.markSent":
            return .object(await transition(value, to: .sent, requester: requester))
        case "invite.refreshStatus":
            return .object(await refreshStatus(value, requester: requester))
        case "invite.pullContactRequests":
            return .object(await pullContactRequests(value, requester: requester))
        case "invite.acceptContactRequest":
            return .object(await acceptContactRequest(value, requester: requester))
        case "invite.recordJoined":
            return .object(await transition(value, to: .joined, requester: requester))
        case "invite.recordDeclined":
            return .object(await transition(value, to: .declined, requester: requester))
        case "invite.revoke":
            return .object(await revoke(value))
        case "invite.verify":
            return .object(verify(value))
        case "invite.clearOutbox":
            return .object(clearOutbox(value))
        default:
            return .object(HavenValue.error(code: "unsupported_keypath", message: "Ukjent invitasjons-handling."))
        }
    }

    // MARK: - Settings

    private func configure(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        var problems: [String] = []
        stateQueue.sync {
            if let base = HavenValue.string(payload["landingBase"]) {
                if let normalized = HavenRelationNormalizer.normalizeURL(base) {
                    settings.landingBase = normalized
                } else {
                    problems.append("«\(base)» ser ikke ut som en https-adresse, så jeg lot landingssiden stå.")
                }
            }
            if let name = HavenValue.string(payload["issuerDisplayName"]) { settings.issuerDisplayName = name }
            if payload["issuerEntityRef"] != nil { settings.issuerEntityRef = HavenValue.string(payload["issuerEntityRef"]) }
            if payload["contactEndpointID"] != nil { settings.contactEndpointID = HavenValue.string(payload["contactEndpointID"]) }
            if let note = HavenValue.string(payload["defaultNote"]) { settings.defaultNote = note }
            if let days = HavenValue.int(payload["ttlDays"]) { settings.ttlDays = min(90, max(1, days)) }
            if let limit = HavenValue.int(payload["dailyLimit"]) { settings.dailyLimit = min(200, max(1, limit)) }
            if let auto = HavenValue.bool(payload["autoPublish"]) { settings.autoPublish = auto }
        }
        let result = HavenValue.ok(
            problems.isEmpty ? "Invitasjonsoppsettet er lagret." : problems.joined(separator: " "),
            sideEffect: true,
            extra: ["settings": .object(settingsObject())]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    private func settingsObject() -> Object {
        let current = stateQueue.sync { settings }
        let hasScaffold = !current.landingBase.isEmpty
        let canReply = current.contactEndpointID?.isEmpty == false
        return [
            "landingBase": .string(current.landingBase),
            "issuerDisplayName": .string(current.issuerDisplayName),
            "issuerEntityRef": .string(current.issuerEntityRef ?? ""),
            "contactEndpointID": .string(current.contactEndpointID ?? ""),
            "defaultNote": .string(current.defaultNote),
            "ttlDays": .integer(current.ttlDays),
            "dailyLimit": .integer(current.dailyLimit),
            "autoPublish": .bool(current.autoPublish),
            "hasScaffold": .bool(hasScaffold),
            "canReceiveReplies": .bool(canReply),
            "smsAvailable": .bool(hasScaffold && current.autoPublish),
            "linkMode": .string(hasScaffold ? (current.autoPublish ? "short" : "selfContained") : "appLinkOnly"),
            "scaffoldWarning": .string(Self.scaffoldWarning(hasScaffold: hasScaffold, autoPublish: current.autoPublish, canReply: canReply))
        ]
    }

    private static func scaffoldWarning(hasScaffold: Bool, autoPublish: Bool, canReply: Bool) -> String {
        if !hasScaffold {
            return "Ingen landingsside er satt opp, så invitasjonene får bare en haven://-lenke som virker på enheter der HAVEN allerede er installert. SMS er slått av. Sett `landingBase` for lenker som virker for alle."
        }
        if !autoPublish {
            return "Invitasjonene sendes som hele billetten i lenken. Det virker i e-post, men lenken blir for lang for SMS, og du får ingen beskjed når noen åpner den."
        }
        if !canReply {
            return "Du har ingen kontaktflate satt opp, så invitasjonene lover ikke at mottakeren kan svare tilbake. Sett `contactEndpointID` for å gi dem den muligheten."
        }
        return ""
    }

    // MARK: - Prepare

    private func prepare(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let force = HavenValue.bool(payload["force"]) ?? false

        guard let relations = await relationsCell(requester: requester) else {
            return fail(HavenValue.error(
                code: "relations_unavailable",
                message: "Relasjonscellen er ikke tilgjengelig, så jeg vet ikke hvem du mener."
            ))
        }

        // The rate limit is checked before anything is minted, so a blocked
        // attempt leaves no half-made ticket behind.
        if !force, let capMessage = dailyCapMessage() {
            return fail(HavenValue.error(code: "daily_limit", message: capMessage))
        }

        guard let record = await resolveRecipient(payload: payload, value: value, relations: relations, requester: requester) else {
            // resolveRecipient already stored a clarification or an error.
            return stateQueue.sync { lastResult }
        }

        let readiness = record.inviteReadiness
        if !readiness.canInvite && !(force && record.inviteState != .blocked && !record.isInHaven) {
            return fail(HavenValue.error(
                code: "not_invitable",
                message: readiness.reason,
                extra: ["relationID": .string(record.id), "displayName": .string(record.displayName)]
            ))
        }

        let requestedChannel = HavenValue.string(payload["channel"])
        guard let endpoint = chooseEndpoint(
            for: record,
            requestedChannel: requestedChannel,
            requestedEndpoint: HavenValue.string(payload["endpoint"])
        ) else {
            return fail(HavenValue.error(
                code: "no_channel",
                message: requestedChannel.map { "\(record.displayName) har ingen \($0) jeg kan bruke." }
                    ?? "\(record.displayName) har verken e-post eller telefon."
            ))
        }
        let channel = endpoint.kind == .email ? "email" : "sms"

        // A second live invitation to the same address is noise, not eagerness.
        if !force, let duplicate = liveTicket(forAudience: endpoint.disclosureToken) {
            return fail(HavenValue.error(
                code: "already_invited",
                message: "\(record.displayName) har allerede en åpen invitasjon på \(duplicate.channel == "email" ? "e-post" : "SMS"), sendt \(duplicate.sentAt.map(HavenValue.readable) ?? "nylig"). Send `force: true` hvis du vil lage en ny.",
                extra: ["ticketID": .string(duplicate.ticket.ticketID)]
            ))
        }

        let current = stateQueue.sync { settings }

        if channel == "sms" && !(current.autoPublish && !current.landingBase.isEmpty) {
            // A self-contained ticket is well over a thousand characters. In an
            // SMS with Norwegian letters that is twenty-odd segments. Refusing
            // is kinder than sending something that arrives as garbage.
            return fail(HavenValue.error(
                code: "sms_requires_publication",
                message: "SMS krever kort lenke, og kort lenke krever at billetten registreres hos scaffoldet. Slå på `autoPublish` og sett `landingBase`, eller inviter på e-post.",
                extra: ["settings": .object(settingsObject())]
            ))
        }

        guard let descriptor = IdentityPublicKeySignatureVerifier.descriptor(for: storedOwnerIdentity) else {
            return fail(HavenValue.error(
                code: "no_signing_identity",
                message: "Identiteten din har ingen signeringsnøkkel i denne kjøringen, så jeg kan ikke signere invitasjonen."
            ))
        }

        let now = Date()
        let ticketID = "inv-\(UUID().uuidString.lowercased())"
        let humanCode = HavenInviteLink.humanCode(from: ticketID + endpoint.disclosureToken)

        // Only promise a reply channel when one exists.
        var capabilities = ["create_own_entity"]
        if current.contactEndpointID?.isEmpty == false {
            capabilities.append("send_contact_request_to_issuer")
        }

        var ticket = HavenInviteTicket(
            ticketID: ticketID,
            issuer: descriptor,
            issuerDisplayName: current.issuerDisplayName.isEmpty ? storedOwnerIdentity.displayName : current.issuerDisplayName,
            issuerContactEndpoint: current.contactEndpointID,
            issuerEntityRef: current.issuerEntityRef,
            audienceToken: endpoint.disclosureToken,
            audienceKind: endpoint.kind.rawValue,
            humanCode: humanCode,
            greetingName: record.givenName ?? record.displayName.split(whereSeparator: { $0.isWhitespace }).first.map(String.init),
            note: HavenValue.string(payload["note"]) ?? (current.defaultNote.isEmpty ? nil : current.defaultNote),
            createdAt: Int(now.timeIntervalSince1970),
            expiresAt: Int(now.addingTimeInterval(TimeInterval(current.ttlDays) * 86_400).timeIntervalSince1970),
            nonce: Self.randomBytes(12),
            capabilities: capabilities
        )

        guard let payloadData = try? ticket.canonicalPayloadData(),
              let signature = try? await storedOwnerIdentity.sign(data: payloadData),
              !signature.isEmpty else {
            return fail(HavenValue.error(
                code: "signing_failed",
                message: "Kunne ikke signere invitasjonen. Uten signatur sender jeg den ikke."
            ))
        }
        ticket.proof = HavenSignatureProof(
            byIdentityUUID: descriptor.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )

        let selfContained: String? = current.landingBase.isEmpty
            ? nil
            : (try? HavenInviteLink.universalLink(for: ticket, landingBase: current.landingBase)) ?? nil
        let appLink: String? = try? HavenInviteLink.appLink(for: ticket)
        let short = current.landingBase.isEmpty
            ? nil
            : HavenInviteLink.shortLink(for: ticket, landingBase: current.landingBase)

        var entry = OutboxEntry(
            ticket: ticket,
            relationID: record.id,
            recipientDisplayName: record.displayName,
            recipientEndpointRaw: endpoint.raw,
            recipientEndpointKind: endpoint.kind.rawValue,
            channel: channel,
            link: selfContained ?? appLink,
            appLink: appLink,
            shortLink: short,
            subject: "",
            body: "",
            handoffURL: nil,
            state: .prepared,
            published: false,
            statusKey: nil,
            preparedAt: now,
            openCount: 0,
            contactRequestCount: 0
        )

        var publicationNote: String?
        if current.autoPublish && !current.landingBase.isEmpty {
            let outcome = await Self.publishTicket(
                ticket,
                landingBase: current.landingBase,
                identity: storedOwnerIdentity,
                descriptor: descriptor
            )
            switch outcome {
            case .success(let statusKey):
                entry.published = true
                entry.statusKey = statusKey
            case .failure(let error):
                publicationNote = error.userMessage
                if channel == "sms" {
                    return fail(HavenValue.error(
                        code: "publish_failed",
                        message: "SMS krever kort lenke, og registreringen hos scaffoldet feilet: \(error.userMessage)"
                    ))
                }
            }
        }

        // Short link only when the scaffold actually has the ticket. Otherwise
        // it resolves to nothing and the invitee sees an error page.
        let preferredLink = entry.published ? (short ?? selfContained ?? appLink) : (selfContained ?? appLink)
        entry.link = preferredLink

        let message = HavenInviteCopy.compose(
            ticket: ticket,
            recipientDisplayName: record.displayName,
            recipientEndpoint: endpoint.raw,
            link: preferredLink,
            channel: channel,
            senderNote: ticket.note
        )
        entry.subject = message.subject
        entry.body = message.body
        entry.handoffURL = message.handoffURL

        stateQueue.sync {
            outbox.removeAll { $0.ticket.ticketID == ticket.ticketID }
            outbox.insert(entry, at: 0)
        }

        _ = try? await relations.set(
            keypath: "relations.setInviteState",
            value: .object([
                "id": .string(record.id),
                "state": .string(HavenInviteState.prepared.rawValue),
                "channel": .string(channel),
                "ticketID": .string(ticket.ticketID),
                "at": .string(HavenValue.iso(now))
            ]),
            requester: requester
        )

        var extra: Object = [
            "ticketID": .string(ticket.ticketID),
            "relationID": .string(record.id),
            "displayName": .string(record.displayName),
            "channel": .string(channel),
            "channelText": .string(channel == "email" ? "e-post" : "SMS"),
            "recipient": .string(endpoint.raw),
            "humanCode": .string(ticket.humanCode),
            "expiresAtText": .string(HavenValue.readable(ticket.expiryDate)),
            "link": .string(preferredLink ?? ""),
            "linkLength": .integer((preferredLink ?? "").count),
            "published": .bool(entry.published),
            "subject": .string(message.subject),
            "body": .string(message.body),
            "handoffURL": .string(message.handoffURL ?? ""),
            "boundaryStatement": .string(HavenInviteCopy.boundary(for: ticket)),
            "capabilities": .list(ticket.capabilities.map(ValueType.string)),
            "canReceiveContactRequest": .bool(ticket.canReceiveContactRequest),
            "requiresUserToPressSend": .bool(true),
            "nextAction": .string("invite.openPreparedMessage"),
            "outbox": .list(outboxRows().map(ValueType.object))
        ]
        if let publicationNote { extra["publicationWarning"] = .string(publicationNote) }

        var headline = "Invitasjon til \(record.displayName) er klar på \(channel == "email" ? "e-post" : "SMS")."
        if let publicationNote { headline += " " + publicationNote }

        let result = HavenValue.ok(headline, sideEffect: true, extra: extra)
        stateQueue.sync { lastResult = result }
        return result
    }

    /// An explicit id, or a search that is allowed to come back ambiguous.
    private func resolveRecipient(
        payload: Object,
        value: ValueType,
        relations: Meddle,
        requester: Identity
    ) async -> HavenRelationRecord? {
        if let relationID = HavenValue.string(payload["relationID"]) ?? HavenValue.string(payload["id"]) {
            guard let record = await lookup(relationID: relationID, in: relations, requester: requester) else {
                _ = fail(HavenValue.error(code: "not_found", message: "Fant ingen relasjon med id \(relationID)."))
                return nil
            }
            return record
        }
        guard let query = HavenValue.string(payload["query"]) ?? HavenValue.string(value) else {
            _ = fail(HavenValue.error(
                code: "bad_request",
                message: "Si hvem invitasjonen gjelder — enten `relationID` eller `query`."
            ))
            return nil
        }
        guard let response = try? await relations.set(
            keypath: "relations.search",
            value: .object(["query": .string(query), "limit": .integer(5), "onlyInvitable": .bool(true)]),
            requester: requester
        ), let searchResult = HavenValue.object(response) else {
            _ = fail(HavenValue.error(code: "search_failed", message: "Søket i relasjonene feilet."))
            return nil
        }
        if HavenValue.bool(searchResult["needsClarification"]) == true {
            // Ambiguity is an answer, not a failure. Hand the question back.
            var result = searchResult
            result["status"] = .string("needsClarification")
            result["sideEffect"] = .bool(false)
            stateQueue.sync { lastResult = result }
            return nil
        }
        guard let matches = HavenValue.list(searchResult["matches"]),
              let best = matches.first,
              let bestID = HavenValue.string(HavenValue.object(best)?["id"]) else {
            _ = fail(HavenValue.error(
                code: "no_match",
                message: HavenValue.string(searchResult["summaryText"]) ?? "Jeg fant ingen som passer, og vil ikke gjette."
            ))
            return nil
        }
        return await lookup(relationID: bestID, in: relations, requester: requester)
    }

    private func dailyCapMessage() -> String? {
        let current = stateQueue.sync { settings }
        let cutoff = Date().addingTimeInterval(-86_400)
        let sentToday = stateQueue.sync { outbox }.filter { entry in
            guard let sentAt = entry.sentAt else { return false }
            return sentAt > cutoff
        }.count
        guard sentToday >= current.dailyLimit else { return nil }
        return "Du har sendt \(sentToday) invitasjoner det siste døgnet, og grensen står på \(current.dailyLimit). Vent litt, eller hev grensen i oppsettet."
    }

    private func liveTicket(forAudience token: String) -> OutboxEntry? {
        let now = Date()
        return stateQueue.sync { outbox }.first { entry in
            entry.ticket.audienceToken == token
                && !entry.ticket.isExpired(at: now)
                && (entry.state == .prepared || entry.state == .sent || entry.state == .opened)
        }
    }

    // MARK: - Publication

    private static func publishTicket(
        _ ticket: HavenInviteTicket,
        landingBase: String,
        identity: Identity,
        descriptor: IdentityPublicKeyDescriptor
    ) async -> Result<String, HavenInviteTransportFailure> {
        guard !landingBase.isEmpty, let token = try? HavenInviteLink.encode(ticket) else {
            return .failure(.notConfigured)
        }
        let statusKey = HavenInvitePublication.makeStatusKey()
        var publication = HavenInvitePublication(
            ticketID: ticket.ticketID,
            humanCode: ticket.humanCode,
            ticketToken: token,
            audienceToken: ticket.audienceToken,
            issuerIdentityUUID: descriptor.uuid,
            expiresAt: ticket.expiresAt,
            publishedAt: Int(Date().timeIntervalSince1970),
            statusKey: statusKey
        )
        guard let canonical = try? publication.canonicalPayloadData(),
              let signature = try? await identity.sign(data: canonical) else {
            return .failure(.rejected("kunne ikke signere registreringen"))
        }
        publication.proof = HavenSignatureProof(
            byIdentityUUID: descriptor.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )

        switch await BindingInviteScaffoldClient.post(
            path: "/i/api/publish",
            landingBase: landingBase,
            body: publication
        ) {
        case .success:
            return .success(statusKey)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func publish(_ value: ValueType) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let ticketID = HavenValue.string(payload["ticketID"]) ?? HavenValue.string(value),
              let entry = stateQueue.sync(execute: { outbox.first { $0.ticket.ticketID == ticketID } }) else {
            return fail(HavenValue.error(code: "not_found", message: "Fant ingen invitasjon med den id-en."))
        }
        guard !entry.published else {
            return HavenValue.ok("Billetten er allerede registrert.", sideEffect: false)
        }
        let current = stateQueue.sync { settings }
        guard let descriptor = IdentityPublicKeySignatureVerifier.descriptor(for: storedOwnerIdentity) else {
            return fail(HavenValue.error(code: "no_signing_identity", message: "Mangler signeringsnøkkel."))
        }

        switch await Self.publishTicket(
            entry.ticket,
            landingBase: current.landingBase,
            identity: storedOwnerIdentity,
            descriptor: descriptor
        ) {
        case .failure(let failure):
            return fail(HavenValue.error(code: "publish_failed", message: failure.userMessage))
        case .success(let statusKey):
            let short = HavenInviteLink.shortLink(for: entry.ticket, landingBase: current.landingBase)
            stateQueue.sync {
                guard let index = outbox.firstIndex(where: { $0.ticket.ticketID == ticketID }) else { return }
                outbox[index].published = true
                outbox[index].statusKey = statusKey
                outbox[index].shortLink = short
                if let short { outbox[index].link = short }
            }
            let result = HavenValue.ok(
                "Billetten er registrert. Kort lenke: \(short ?? "")",
                sideEffect: true,
                extra: ["ticketID": .string(ticketID), "shortLink": .string(short ?? "")]
            )
            stateQueue.sync { lastResult = result }
            return result
        }
    }

    // MARK: - Handing the message to the person

    /// Opens the prepared `mailto:`/`sms:` URL. This is the last centimetre of
    /// the task: before it existed, the person was left holding a finished
    /// message they could not act on.
    ///
    /// It is a side effect, so it only ever runs from an explicit press, and
    /// it opens a composer — it does not send.
    private func openPreparedMessage(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let ticketID = HavenValue.string(payload["ticketID"]) ?? HavenValue.string(value)
        let entry = stateQueue.sync { outbox }.first { candidate in
            guard let ticketID else { return candidate.state == .prepared }
            return candidate.ticket.ticketID == ticketID
        }
        guard let entry, let handoff = entry.handoffURL, !handoff.isEmpty else {
            return fail(HavenValue.error(
                code: "nothing_prepared",
                message: "Ingen klargjort melding å åpne. Lag en invitasjon først."
            ))
        }

        let opened = await BindingExternalURLOpener.open(handoff)
        guard opened else {
            return fail(HavenValue.error(
                code: "open_failed",
                message: "Klarte ikke å åpne \(entry.channel == "email" ? "e-postprogrammet" : "meldingsappen"). Teksten ligger klar under, så du kan kopiere den.",
                extra: ["body": .string(entry.body), "subject": .string(entry.subject)]
            ))
        }

        // Opening the composer is the strongest "sent" signal this device can
        // honestly produce. It is still the person who presses send.
        return await transition(
            .object(["ticketID": .string(entry.ticket.ticketID)]),
            to: .sent,
            requester: requester
        )
    }

    // MARK: - Status from the scaffold

    private func refreshStatus(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let only = HavenValue.string(payload["ticketID"])
        let current = stateQueue.sync { settings }
        let candidates = stateQueue.sync { outbox }.filter { entry in
            guard entry.published, entry.statusKey != nil else { return false }
            if let only { return entry.ticket.ticketID == only }
            return entry.state == .sent || entry.state == .opened || entry.state == .prepared
        }
        guard !candidates.isEmpty else {
            return HavenValue.ok(
                "Ingen registrerte invitasjoner å hente status for.",
                sideEffect: false
            )
        }

        var updated = 0
        var joined: [String] = []
        for entry in candidates {
            guard let statusKey = entry.statusKey else { continue }
            guard case let .success(report) = await BindingInviteScaffoldClient.status(
                landingBase: current.landingBase,
                ticketID: entry.ticket.ticketID,
                statusKey: statusKey
            ) else { continue }

            var becameJoined = false
            stateQueue.sync {
                guard let index = outbox.firstIndex(where: { $0.ticket.ticketID == entry.ticket.ticketID }) else { return }
                let previous = outbox[index].state
                outbox[index].openCount = report.openCount
                outbox[index].contactRequestCount = report.contactRequestCount
                if let firstOpenedAt = report.firstOpenedAt {
                    outbox[index].openedAt = Date(timeIntervalSince1970: TimeInterval(firstOpenedAt))
                }
                if let respondedAt = report.respondedAt {
                    outbox[index].respondedAt = Date(timeIntervalSince1970: TimeInterval(respondedAt))
                }
                outbox[index].resultingEntityRef = report.resultingEntityRef
                let mapped = Self.mapLifecycle(report.state, fallback: previous)
                outbox[index].state = mapped
                if mapped != previous {
                    updated += 1
                    if mapped == .joined { becameJoined = true }
                }
            }
            if becameJoined {
                joined.append(entry.recipientDisplayName)
                await syncRelationState(
                    relationID: entry.relationID,
                    state: .joined,
                    ticketID: entry.ticket.ticketID,
                    entityRef: report.resultingEntityRef,
                    requester: requester
                )
            }
        }

        let message: String
        if updated == 0 {
            message = "Ingen endring siden sist."
        } else if joined.isEmpty {
            message = "\(updated) invitasjoner har fått ny status."
        } else {
            message = "\(joined.joined(separator: ", ")) er i HAVEN nå."
        }
        let result = HavenValue.ok(message, sideEffect: updated > 0, extra: [
            "updatedCount": .integer(updated),
            "outbox": .list(outboxRows().map(ValueType.object))
        ])
        stateQueue.sync { lastResult = result }
        return result
    }

    private static func mapLifecycle(_ lifecycle: HavenInviteLifecycle, fallback: HavenInviteState) -> HavenInviteState {
        switch lifecycle {
        case .published: return fallback == .prepared ? .prepared : fallback
        case .opened: return .opened
        case .accepted: return .joined
        case .declined: return .declined
        case .revoked: return .blocked
        case .expired: return fallback
        }
    }

    // MARK: - Contact requests coming back

    private func pullContactRequests(_ value: ValueType, requester: Identity) async -> Object {
        let current = stateQueue.sync { settings }
        let candidates = stateQueue.sync { outbox }.filter { $0.published && $0.statusKey != nil }
        guard !candidates.isEmpty else {
            return HavenValue.ok("Ingen registrerte invitasjoner å hente svar for.", sideEffect: false)
        }

        var received = 0
        var names: [String] = []
        for entry in candidates {
            guard let statusKey = entry.statusKey else { continue }
            guard case let .success(requests) = await BindingInviteScaffoldClient.contactRequests(
                landingBase: current.landingBase,
                ticketID: entry.ticket.ticketID,
                statusKey: statusKey
            ) else { continue }

            for request in requests {
                // The scaffold only relayed this. Verify it against the key it
                // carries and the ticket it claims to answer, here.
                do {
                    try HavenInvitePublicationVerifier.verifyContactRequest(request, forTicket: entry.ticket)
                } catch {
                    continue
                }
                let alreadyHave = stateQueue.sync {
                    inbox.contains { $0.request.requestID == request.requestID }
                }
                guard !alreadyHave else { continue }
                stateQueue.sync {
                    inbox.insert(
                        InboxEntry(request: request, receivedAt: Date(), deliveredToEndpoint: false),
                        at: 0
                    )
                }
                received += 1
                names.append(request.senderDisplayName)
            }
        }

        let result = HavenValue.ok(
            received == 0
                ? "Ingen nye svar."
                : "\(names.joined(separator: ", ")) har svart på invitasjonen. Se over og godta for å opprette kontakten.",
            sideEffect: received > 0,
            extra: [
                "receivedCount": .integer(received),
                "inbox": .list(inboxRows().map(ValueType.object))
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    /// Hands a verified reply to the `ContactEndpoint` cell, which already
    /// owns first-contact policy. One inbox, not two.
    private func acceptContactRequest(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let requestID = HavenValue.string(payload["requestID"]) ?? HavenValue.string(value),
              let entry = stateQueue.sync(execute: { inbox.first { $0.request.requestID == requestID } }) else {
            return fail(HavenValue.error(code: "not_found", message: "Fant ingen forespørsel med den id-en."))
        }
        guard !entry.deliveredToEndpoint else {
            return HavenValue.ok("Denne er allerede tatt imot.", sideEffect: false)
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let contactCell = try? await resolver.cellAtEndpoint(
                endpoint: Self.contactEndpointEndpoint,
                requester: requester
              ) as? Meddle else {
            return fail(HavenValue.error(
                code: "contact_endpoint_unavailable",
                message: "Kontaktflaten er ikke tilgjengelig i denne kjøringen."
            ))
        }

        var request = entry.request.contactEndpointPayload()
        request["requesterIdentity"] = ValueType.identity(storedOwnerIdentity.publicIdentitySnapshot())

        let response = try? await contactCell.set(
            keypath: "contact.request",
            value: .object(request),
            requester: requester
        )
        let responseObject = HavenValue.object(response) ?? [:]
        let accepted = HavenValue.string(responseObject["status"]) != "error"

        stateQueue.sync {
            guard let index = inbox.firstIndex(where: { $0.request.requestID == requestID }) else { return }
            inbox[index].deliveredToEndpoint = accepted
            inbox[index].deliveryNote = HavenValue.string(responseObject["message"])
        }

        // Whoever replied is now in HAVEN, whatever the endpoint policy said.
        if let ticketEntry = stateQueue.sync(execute: { outbox.first { $0.ticket.ticketID == entry.request.ticketID } }) {
            await syncRelationState(
                relationID: ticketEntry.relationID,
                state: .joined,
                ticketID: entry.request.ticketID,
                entityRef: entry.request.senderEntityRef,
                requester: requester
            )
            stateQueue.sync {
                if let index = outbox.firstIndex(where: { $0.ticket.ticketID == entry.request.ticketID }) {
                    outbox[index].state = .joined
                    outbox[index].resultingEntityRef = entry.request.senderEntityRef
                }
            }
        }

        let result = HavenValue.ok(
            accepted
                ? "\(entry.request.senderDisplayName) er lagt inn som kontakt."
                : "Kontaktflaten avviste forespørselen: \(HavenValue.string(responseObject["message"]) ?? "ukjent grunn").",
            sideEffect: true,
            extra: [
                "requestID": .string(requestID),
                "delivered": .bool(accepted),
                "contactEndpointResponse": .object(responseObject),
                "inbox": .list(inboxRows().map(ValueType.object))
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    // MARK: - Lifecycle

    private func transition(_ value: ValueType, to state: HavenInviteState, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let ticketID = HavenValue.string(payload["ticketID"]) ?? HavenValue.string(value) else {
            return HavenValue.error(code: "missing_ticket", message: "Mangler `ticketID`.")
        }
        var relationID: String?
        var recipient: String?
        var found = false
        let now = Date()
        stateQueue.sync {
            guard let index = outbox.firstIndex(where: { $0.ticket.ticketID == ticketID }) else { return }
            found = true
            outbox[index].state = state
            relationID = outbox[index].relationID
            recipient = outbox[index].recipientDisplayName
            switch state {
            case .sent: outbox[index].sentAt = now
            case .opened: outbox[index].openedAt = now
            case .joined, .declined:
                outbox[index].respondedAt = now
                outbox[index].resultingEntityRef = HavenValue.string(payload["entityRef"])
            default: break
            }
        }
        guard found, let relationID else {
            return HavenValue.error(code: "not_found", message: "Fant ingen invitasjon med id \(ticketID).")
        }

        await syncRelationState(
            relationID: relationID,
            state: state,
            ticketID: ticketID,
            entityRef: HavenValue.string(payload["entityRef"]),
            requester: requester
        )

        let message: String
        switch state {
        case .sent: message = "Meldingen er åpnet i \(recipient.map { "din e-post/SMS til \($0)" } ?? "meldingsappen"). Trykk send der."
        case .opened: message = "\(recipient ?? "Mottakeren") har åpnet invitasjonen."
        case .joined: message = "\(recipient ?? "Mottakeren") er i HAVEN nå."
        case .declined: message = "\(recipient ?? "Mottakeren") takket nei."
        default: message = "Status oppdatert."
        }
        let result = HavenValue.ok(message, sideEffect: true, extra: [
            "ticketID": .string(ticketID),
            "state": .string(state.rawValue),
            "outbox": .list(outboxRows().map(ValueType.object))
        ])
        stateQueue.sync { lastResult = result }
        return result
    }

    private func syncRelationState(
        relationID: String,
        state: HavenInviteState,
        ticketID: String,
        entityRef: String?,
        requester: Identity
    ) async {
        guard let relations = await relationsCell(requester: requester) else { return }
        var payload: Object = [
            "id": .string(relationID),
            "state": .string(state.rawValue),
            "ticketID": .string(ticketID),
            "at": .string(HavenValue.iso(Date()))
        ]
        if let entityRef { payload["entityRef"] = .string(entityRef) }
        _ = try? await relations.set(keypath: "relations.setInviteState", value: .object(payload), requester: requester)
    }

    private func revoke(_ value: ValueType) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let ticketID = HavenValue.string(payload["ticketID"]) ?? HavenValue.string(value) else {
            return HavenValue.error(code: "missing_ticket", message: "Mangler `ticketID`.")
        }
        let reason = HavenValue.string(payload["reason"]) ?? "Trukket tilbake av avsender."
        let entry = stateQueue.sync { outbox.first { $0.ticket.ticketID == ticketID } }
        let current = stateQueue.sync { settings }

        stateQueue.sync {
            revoked.removeAll { $0.ticketID == ticketID }
            revoked.append(RevocationEntry(ticketID: ticketID, reason: reason, revokedAt: Date()))
            if let index = outbox.firstIndex(where: { $0.ticket.ticketID == ticketID }) {
                outbox[index].state = .declined
            }
        }

        var remoteNote = "Lenken virker fortsatt for den som allerede har den — den ble aldri registrert hos noe scaffold."
        if let entry, entry.published,
           let descriptor = IdentityPublicKeySignatureVerifier.descriptor(for: storedOwnerIdentity) {
            var notice = HavenInviteRevocationNotice(
                ticketID: ticketID,
                reason: reason,
                revokedAt: Int(Date().timeIntervalSince1970),
                issuerIdentityUUID: descriptor.uuid
            )
            if let canonical = try? notice.canonicalPayloadData(),
               let signature = try? await storedOwnerIdentity.sign(data: canonical) {
                notice.proof = HavenSignatureProof(
                    byIdentityUUID: descriptor.uuid,
                    algorithm: descriptor.algorithm,
                    curveType: descriptor.curveType,
                    signature: signature
                )
                switch await BindingInviteScaffoldClient.post(
                    path: "/i/api/revoke",
                    landingBase: current.landingBase,
                    body: notice
                ) {
                case .success:
                    remoteNote = "Lenken slutter å virke med én gang."
                case .failure(let failure):
                    remoteNote = "Lokalt trukket tilbake, men scaffoldet svarte ikke: \(failure.userMessage) Prøv igjen."
                }
            }
        }

        let result = HavenValue.ok(
            "Invitasjonen er trukket tilbake. " + remoteNote,
            sideEffect: true,
            extra: ["ticketID": .string(ticketID)]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    // MARK: - Verify

    private func verify(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let ticket: HavenInviteTicket
        do {
            if let link = HavenValue.string(payload["link"]) ?? HavenValue.string(value) {
                ticket = try HavenInviteLink.decode(try HavenInviteLink.token(fromLink: link))
            } else if let embedded = payload["ticket"],
                      let decoded = HavenValue.decode(HavenInviteTicket.self, from: embedded) {
                ticket = decoded
            } else {
                return HavenValue.error(code: "bad_request", message: "Send `link` eller `ticket`.")
            }
        } catch let error as HavenInviteLink.Failure {
            return HavenValue.error(code: error.code, message: error.description)
        } catch {
            return HavenValue.error(code: "bad_link", message: "Invitasjonen kunne ikke leses.")
        }

        let verdict = HavenInviteVerifier.verify(
            ticket: ticket,
            revokedTicketIDs: Set(stateQueue.sync { revoked }.map(\.ticketID)),
            expectedAudienceToken: HavenValue.string(payload["expectedAudienceToken"])
        )
        // The one serialisation the landing page uses too.
        return HavenInviteVerifier.payload(for: verdict, ticket: ticket)
    }

    private func clearOutbox(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let onlyResolved = HavenValue.bool(payload["onlyResolved"]) ?? true
        var removed = 0
        stateQueue.sync {
            let before = outbox.count
            if onlyResolved {
                outbox.removeAll { $0.state == .joined || $0.state == .declined }
            } else {
                outbox.removeAll()
            }
            removed = before - outbox.count
        }
        return HavenValue.ok("Ryddet \(removed) invitasjoner ut av listen.", sideEffect: removed > 0)
    }

    // MARK: - Helpers

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        return Data(bytes)
    }

    private func chooseEndpoint(
        for record: HavenRelationRecord,
        requestedChannel: String?,
        requestedEndpoint: String?
    ) -> HavenRelationEndpoint? {
        if let requestedEndpoint {
            let normalized = HavenRelationNormalizer.endpoint(from: requestedEndpoint)
            if let match = record.endpoints.first(where: {
                $0.raw == requestedEndpoint || $0.normalized == normalized?.normalized
            }) {
                return match
            }
        }
        if let requestedChannel {
            let kind: HavenEndpointKind? = {
                switch requestedChannel.lowercased() {
                case "email", "epost", "e-post", "mail": return .email
                case "sms", "phone", "telefon", "mobil": return .phone
                default: return nil
                }
            }()
            if let kind { return record.reachableEndpoints.first { $0.kind == kind } }
        }
        return record.reachableEndpoints.first(where: \.confirmed) ?? record.reachableEndpoints.first
    }

    private func relationsCell(requester: Identity) async -> Meddle? {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else { return nil }
        return try? await resolver.cellAtEndpoint(endpoint: Self.relationsEndpoint, requester: requester) as? Meddle
    }

    private func lookup(relationID: String, in relations: Meddle, requester: Identity) async -> HavenRelationRecord? {
        guard let response = try? await relations.get(keypath: "relations.all", requester: requester),
              let list = HavenValue.list(response),
              let row = list.compactMap(HavenValue.object).first(where: {
                  HavenValue.string($0["id"]) == relationID
              }) else { return nil }
        return Self.record(fromPresenterRow: row)
    }

    /// Rebuilds enough of a record from a presenter row to mint an invitation.
    /// Deliberately partial: reading less means carrying less.
    private static func record(fromPresenterRow row: Object) -> HavenRelationRecord? {
        guard let id = HavenValue.string(row["id"]),
              let displayName = HavenValue.string(row["displayName"]) else { return nil }
        let endpoints: [HavenRelationEndpoint] = (HavenValue.list(row["endpoints"]) ?? []).compactMap { entry in
            guard let object = HavenValue.object(entry),
                  let raw = HavenValue.string(object["raw"]),
                  let normalized = HavenValue.string(object["normalized"]),
                  let kindText = HavenValue.string(object["kind"]),
                  let kind = HavenEndpointKind(rawValue: kindText),
                  let token = HavenValue.string(object["disclosureToken"]) else { return nil }
            return HavenRelationEndpoint(
                raw: raw,
                normalized: normalized,
                kind: kind,
                label: HavenValue.string(object["label"]),
                confirmed: HavenValue.bool(object["confirmed"]) ?? false,
                disclosureToken: token
            )
        }
        return HavenRelationRecord(
            id: id,
            displayName: displayName,
            organization: HavenValue.string(row["organization"]),
            jobTitle: HavenValue.string(row["jobTitle"]),
            endpoints: endpoints,
            entityRef: HavenValue.string(row["entityRef"]),
            inviteState: HavenInviteState(rawValue: HavenValue.string(row["inviteState"]) ?? "none") ?? .none,
            confidence: HavenValue.double(row["confidence"]) ?? 0.5
        )
    }

    private func fail(_ error: Object) -> Object {
        stateQueue.sync { lastResult = error }
        return error
    }

    // MARK: - Presentation

    private func outboxRows() -> [Object] {
        let revokedIDs = Set(stateQueue.sync { revoked }.map(\.ticketID))
        let now = Date()
        return stateQueue.sync { outbox }.map { entry in
            let expired = entry.ticket.isExpired(at: now)
            return [
                "ticketID": .string(entry.ticket.ticketID),
                "relationID": .string(entry.relationID),
                "displayName": .string(entry.recipientDisplayName),
                "recipient": .string(entry.recipientEndpointRaw),
                "channel": .string(entry.channel),
                "channelText": .string(entry.channel == "email" ? "E-post" : "SMS"),
                "state": .string(entry.state.rawValue),
                "stateText": .string(HavenRelationPresenter.stateText(entry.state)),
                "humanCode": .string(entry.ticket.humanCode),
                "link": .string(entry.link ?? ""),
                "published": .bool(entry.published),
                "openCount": .integer(entry.openCount),
                "contactRequestCount": .integer(entry.contactRequestCount),
                "preparedAtText": .string(HavenValue.readable(entry.preparedAt)),
                "sentAtText": .string(entry.sentAt.map(HavenValue.readable) ?? ""),
                "expired": .bool(expired),
                "revoked": .bool(revokedIDs.contains(entry.ticket.ticketID)),
                "canOpen": .bool(entry.handoffURL?.isEmpty == false),
                "statusLine": .string(Self.statusLine(entry: entry, expired: expired, revoked: revokedIDs.contains(entry.ticket.ticketID)))
            ]
        }
    }

    private static func statusLine(entry: OutboxEntry, expired: Bool, revoked: Bool) -> String {
        if revoked { return "Trukket tilbake" }
        switch entry.state {
        case .prepared:
            return expired ? "Klargjort, men utløpt — lag en ny" : "Klar til å sendes på \(entry.channel == "email" ? "e-post" : "SMS")"
        case .sent:
            let when = entry.sentAt.map(HavenValue.readable) ?? ""
            if expired { return "Sendt \(when), nå utløpt" }
            return entry.published ? "Sendt \(when) · venter på at hen åpner" : "Sendt \(when)"
        case .opened:
            return entry.openCount > 1 ? "Åpnet \(entry.openCount) ganger" : "Åpnet"
        case .joined: return "Ble med i HAVEN"
        case .declined: return "Takket nei"
        default: return HavenRelationPresenter.stateText(entry.state)
        }
    }

    private func inboxRows() -> [Object] {
        stateQueue.sync { inbox }.map { entry in
            [
                "requestID": .string(entry.request.requestID),
                "ticketID": .string(entry.request.ticketID),
                "displayName": .string(entry.request.senderDisplayName),
                "message": .string(entry.request.message ?? ""),
                "endpoint": .string(entry.request.senderEndpoint ?? ""),
                "receivedAtText": .string(HavenValue.readable(entry.receivedAt)),
                "delivered": .bool(entry.deliveredToEndpoint),
                "deliveryNote": .string(entry.deliveryNote ?? ""),
                "statusLine": .string(
                    entry.deliveredToEndpoint
                        ? "Lagt inn som kontakt"
                        : "\(entry.request.senderDisplayName) vil koble seg til deg"
                )
            ]
        }
    }

    private func stateObject() -> Object {
        let entries = stateQueue.sync { outbox }
        let pending = stateQueue.sync { inbox }.filter { !$0.deliveredToEndpoint }
        let sent = entries.filter { $0.state == .sent || $0.state == .opened }.count
        let joined = entries.filter { $0.state == .joined }.count
        let waiting = entries.filter { $0.state == .prepared }.count
        return [
            "schema": .string("haven.invite.state.v1"),
            "summary": .string(summary(total: entries.count, waiting: waiting, sent: sent, joined: joined, replies: pending.count)),
            "settings": .object(settingsObject()),
            "outbox": .list(outboxRows().map(ValueType.object)),
            "inbox": .list(inboxRows().map(ValueType.object)),
            "pendingReplyCount": .integer(pending.count),
            "counts": .object([
                "total": .integer(entries.count),
                "waiting": .integer(waiting),
                "sent": .integer(sent),
                "joined": .integer(joined)
            ]),
            "boundaryStatement": .string(HavenInviteCopy.boundaryLine),
            "lastResult": .object(stateQueue.sync { lastResult }),
            "privacyBoundary": .string("owner_local_ticket_mint_publication_is_opt_in_no_automatic_send"),
            "updatedAt": .string(HavenValue.iso(Date()))
        ]
    }

    private func summary(total: Int, waiting: Int, sent: Int, joined: Int, replies: Int) -> String {
        if replies > 0 {
            return replies == 1
                ? "Én har svart på en invitasjon og venter på deg."
                : "\(replies) har svart på invitasjoner og venter på deg."
        }
        guard total > 0 else { return "Ingen invitasjoner ennå." }
        var parts: [String] = []
        if waiting > 0 { parts.append("\(waiting) venter på at du trykker send") }
        if sent > 0 { parts.append("\(sent) er sendt") }
        if joined > 0 { parts.append("\(joined) har blitt med") }
        return parts.joined(separator: ", ") + "."
    }

    // MARK: - Discovery

    private func providerDescriptor() -> Object {
        [
            "id": .string("binding.invitation"),
            "providerID": .string("binding.invitation"),
            "kind": .string("invitation"),
            "title": .string("Invitasjon"),
            "summary": .string("Lag en signert invitasjonslenke til noen du kjenner, og få den ferdig skrevet på e-post eller SMS."),
            "endpoint": .string(Self.endpoint),
            "sourceCellName": .string(Self.sourceCellName),
            "actionKeypath": .string("invite.prepare"),
            "purposeRefs": .list([
                .string("personal.chat.assist.invite"),
                .string("purpose://invite-known-people")
            ]),
            "interests": .list([
                .string("invite-person"),
                .string("relations"),
                .string("onboarding"),
                .string("requires-user-approval")
            ]),
            "availability": .string("available_in_cell_scope"),
            "privacyLevel": .string("owner_local_no_automatic_send"),
            "executionScope": .string("binding_local_cell"),
            "requiresUserApproval": .bool(true),
            "requiresNetwork": .bool(true),
            "networkNote": .string("Registrerer billetten hos ditt eget scaffold ved forberedelse. Kan slås av."),
            "canInvokeFromChat": .bool(true),
            "score": .float(0.93),
            "reason": .string("«Inviter X» skal lage en signert billett og en ferdig melding, aldri sende noe selv.")
        ]
    }

    private func purposeGoal() -> Object {
        [
            "title": .string("Invitasjon"),
            "summary": .string("Gjør en relasjon om til en signert invitasjon på en kanal personen faktisk bruker, og la eieren trykke send."),
            "purposeRefs": .list([.string("personal.chat.assist.invite")]),
            "interests": .list([.string("invite-person"), .string("relations"), .string("onboarding")])
        ]
    }

    /// The invitation surface is now part of the single Relations surface —
    /// see `RelationsWorkbenchConfiguration.swift`. This stays as the
    /// cell-local fallback for anyone opening the endpoint directly.
    nonisolated static func menuConfiguration() -> CellConfiguration {
        HavenRelationsWorkbench.configuration()
    }
}
