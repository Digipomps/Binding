// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  RelationsCell.swift
//  Binding
//
//  The relations part of my own entity: the people I know, how to reach them,
//  where that knowledge came from, and whether they are in HAVEN yet.
//
//  This cell is the single source of truth for that data. Everything else —
//  the address book, an imported spreadsheet, a nearby encounter — is a
//  *source* that flows in here and keeps its provenance. Caches and backups
//  live elsewhere (see EntityResidencyCell) and are never authoritative.
//
//  Scope is `.identityUnique` and persistency `.persistant`: these are my
//  relations, in my entity, not the device's.
//

import Foundation
import CellBase

final class BindingRelationsCell: GeneralCell {
    static let endpoint = "cell:///Relations"
    static let sourceCellName = "BindingRelationsCell"

    private enum CodingKeys: String, CodingKey {
        case records
        case lastSearch
        case lastMutation
        case region
        case projectionSalt
        case projectionEpoch
        case projectionEnabled
    }

    private let stateQueue = DispatchQueue(label: "Binding.BindingRelationsCell.State")

    private nonisolated(unsafe) var records: [HavenRelationRecord] = []
    private nonisolated(unsafe) var lastSearch: Object = [:]
    private nonisolated(unsafe) var lastMutation: Object = [:]
    /// Default region for phone normalisation on this entity.
    private nonisolated(unsafe) var region: String = HavenRelationNormalizer.defaultPhoneRegion
    /// Local, secret salt for the opaque references used in the perspective.
    ///
    /// Without it the perspective would be keyed on display names — which
    /// collides two people who share one, and turns a file that gets compared
    /// against other parties into a plaintext list of everyone you know.
    private nonisolated(unsafe) var projectionSalt: String = ""
    /// Monotonic. A delayed projection must never undo a newer one.
    private nonisolated(unsafe) var projectionEpoch: Int = 0
    /// Projection is off until the owner turns it on. It is a real disclosure —
    /// names and interests leave this cell for a graph built to be matched.
    private nonisolated(unsafe) var projectionEnabled: Bool = false

    /// Entity sync bookkeeping — in memory on purpose. On a fresh process the
    /// first mutation resyncs everything, which is the honest thing to do
    /// when we cannot know what the entity already has.
    private nonisolated(unsafe) var lastEntitySync: Object = [:]
    private nonisolated(unsafe) var entitySyncedIDs: Set<String> = []
    private nonisolated(unsafe) var entitySyncTask: Task<Void, Never>?

    required init(owner: Identity) async {
        await super.init(owner: owner)
        stateQueue.sync {
            lastSearch = Self.emptySearch()
            lastMutation = HavenValue.ok("Relasjonene er klare.", sideEffect: false)
        }
        try? await ensureRuntimeReady()
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        records = try container.decodeIfPresent([HavenRelationRecord].self, forKey: .records) ?? []
        lastSearch = try container.decodeIfPresent(Object.self, forKey: .lastSearch) ?? Self.emptySearch()
        lastMutation = try container.decodeIfPresent(Object.self, forKey: .lastMutation) ?? [:]
        region = try container.decodeIfPresent(String.self, forKey: .region) ?? HavenRelationNormalizer.defaultPhoneRegion
        projectionSalt = try container.decodeIfPresent(String.self, forKey: .projectionSalt) ?? ""
        projectionEpoch = try container.decodeIfPresent(Int.self, forKey: .projectionEpoch) ?? 0
        projectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .projectionEnabled) ?? false
        try super.init(from: decoder)
    }

    override func installCellRuntimeBindingsForAccess() async throws {
        await setup(owner: storedOwnerIdentity)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync {
            (records, lastSearch, lastMutation, region, projectionSalt, projectionEpoch, projectionEnabled)
        }
        try container.encode(snapshot.0, forKey: .records)
        try container.encode(snapshot.1, forKey: .lastSearch)
        try container.encode(snapshot.2, forKey: .lastMutation)
        try container.encode(snapshot.3, forKey: .region)
        try container.encode(snapshot.4, forKey: .projectionSalt)
        try container.encode(snapshot.5, forKey: .projectionEpoch)
        try container.encode(snapshot.6, forKey: .projectionEnabled)
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

    // MARK: - Contract

    private var readableKeys: [String] {
        [
            "state",
            "relations.state",
            "relations.all",
            "relations.inviteCandidates",
            "relations.duplicates",
            "relations.batches",
            "relations.stats",
            "relations.lastSearch",
            "relations.lastMutation",
            "relations.snapshot",
            "relations.entitySync",
            "providerDescriptor",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    private var writableKeys: [String] {
        [
            "relations.upsert",
            "relations.search",
            "relations.setInviteState",
            "relations.setEntityRef",
            "relations.block",
            "relations.unblock",
            "relations.remove",
            "relations.forgetBatch",
            "relations.mergeManually",
            "relations.setRegion",
            "relations.clear",
            "relations.restoreSnapshot",
            "relations.publishPurposeSignals",
            "relations.setProjectionEnabled",
            "relations.projectToPerspective",
            "relations.reach",
            "relations.recordInteraction",
            "relations.interactions",
            "relations.syncToEntity",
            "relations.setInteractionPolicy",
            "relations.interactionPolicy"
        ]
    }

    /// Mutations that change what the entity should hold.
    private static let entityAffectingKeys: Set<String> = [
        "relations.upsert", "relations.setInviteState", "relations.setEntityRef",
        "relations.block", "relations.unblock", "relations.remove", "relations.forgetBatch",
        "relations.mergeManually", "relations.clear", "relations.restoreSnapshot"
    ]

    private func readValue(for key: String) -> ValueType {
        switch key {
        case "state", "relations.state":
            return .object(stateObject())
        case "relations.all":
            return .list(sortedRecords().map { .object(HavenRelationPresenter.row(for: $0)) })
        case "relations.inviteCandidates":
            return .list(inviteCandidates().map { .object(HavenRelationPresenter.row(for: $0)) })
        case "relations.duplicates":
            return .list(duplicatePairs().map(ValueType.object))
        case "relations.batches":
            return .list(batches().map(ValueType.object))
        case "relations.stats":
            return .object(stats())
        case "relations.lastSearch":
            return .object(stateQueue.sync { lastSearch })
        case "relations.lastMutation":
            return .object(stateQueue.sync { lastMutation })
        case "relations.snapshot":
            return .object(snapshot())
        case "relations.entitySync":
            return .object(stateQueue.sync { lastEntitySync })
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
        let result = await performWrite(for: key, value: value, requester: requester)
        if Self.entityAffectingKeys.contains(key),
           case let .object(object) = result,
           HavenValue.bool(object["sideEffect"]) != false,
           HavenValue.string(object["status"]) != "error" {
            scheduleEntitySync(requester: requester)
        }
        // An invitation changing state *is* an interaction. Log it as one, so
        // «når snakket vi sist» is answered by the same record as everything else.
        if key == "relations.setInviteState",
           case let .object(object) = result,
           HavenValue.string(object["status"]) == "ok",
           let id = HavenValue.string(object["id"]),
           let state = HavenValue.string(object["state"]).flatMap(HavenInviteState.init(rawValue:)),
           let kind = Self.interactionKind(forInviteState: state) {
            let payload = HavenValue.object(value) ?? [:]
            let channel = HavenValue.string(payload["channel"]).flatMap(Self.channelKind(forInviteChannel:))
            let outbound = state == .sent || state == .prepared
            let ticket = HavenValue.string(payload["ticketID"]) ?? ""
            let channelValue: ValueType = channel.map { ValueType.string($0.rawValue) } ?? .null
            let eventPayload: Object = [
                "id": .string(id),
                "kind": .string(kind.rawValue),
                "channel": channelValue,
                "direction": .string(outbound ? "outbound" : "inbound"),
                "eventID": .string("invite-\(state.rawValue)-" + (ticket.isEmpty ? HavenValue.iso(Date()) : ticket)),
                "sourceCell": .string(Self.sourceCellName)
            ]
            Task { [weak self] in
                guard let self else { return }
                _ = await self.recordInteraction(.object(eventPayload), requester: requester)
            }
        }
        return result
    }

    private static func interactionKind(forInviteState state: HavenInviteState) -> EntityRelationInteractionKind? {
        switch state {
        case .prepared: return .invitePrepared
        case .sent: return .inviteSent
        case .opened: return .inviteOpened
        case .joined: return .inviteJoined
        case .none, .declined, .blocked: return nil
        }
    }

    private static func channelKind(forInviteChannel channel: String) -> EntityRelationChannelKind? {
        switch channel.lowercased() {
        case "email", "mail", "mailto", "e-post": return .email
        case "sms", "phone", "tel", "telefon": return .sms
        case "nearby", "radar": return .nearby
        case "haven", "chat", "haven-chat": return .havenChat
        default: return EntityRelationChannelKind(rawValue: channel.lowercased())
        }
    }

    private func performWrite(for key: String, value: ValueType, requester: Identity) async -> ValueType {
        switch key {
        case "relations.upsert":
            return .object(upsert(value))
        case "relations.search":
            return .object(search(value))
        case "relations.setInviteState":
            return .object(setInviteState(value))
        case "relations.setEntityRef":
            return .object(setEntityRef(value))
        case "relations.block":
            return .object(setBlocked(value, blocked: true))
        case "relations.unblock":
            return .object(setBlocked(value, blocked: false))
        case "relations.remove":
            return .object(remove(value))
        case "relations.forgetBatch":
            return .object(forgetBatch(value))
        case "relations.mergeManually":
            return .object(mergeManually(value))
        case "relations.setRegion":
            return .object(setRegion(value))
        case "relations.clear":
            return .object(clearAll())
        case "relations.restoreSnapshot":
            return .object(restoreSnapshot(value))
        case "relations.publishPurposeSignals":
            return .object(await publishPurposeSignals(value, requester: requester))
        case "relations.setProjectionEnabled":
            return .object(await setProjectionEnabled(value, requester: requester))
        case "relations.projectToPerspective":
            return .object(await projectToPerspective(requester: requester))
        case "relations.reach":
            return .object(await reach(value, requester: requester))
        case "relations.recordInteraction":
            return .object(await recordInteraction(value, requester: requester))
        case "relations.interactions":
            return .object(await interactions(value, requester: requester))
        case "relations.syncToEntity":
            return .object(await syncToEntity(requester: requester, force: true))
        case "relations.setInteractionPolicy":
            return .object(await setInteractionPolicy(value, requester: requester))
        case "relations.interactionPolicy":
            let mode = await BindingRelationEntityStore.interactionPolicy(requester: requester)
            return .object(["mode": .string(mode.rawValue), "default": .string(EntityRelationRecordV1.defaultInteractionPolicy.rawValue)])
        default:
            return .object(HavenValue.error(code: "unsupported_keypath", message: "Ukjent relasjons-handling."))
        }
    }

    // MARK: - Reads

    private func sortedRecords() -> [HavenRelationRecord] {
        stateQueue.sync { records }.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func inviteCandidates() -> [HavenRelationRecord] {
        sortedRecords()
            .filter { $0.inviteReadiness.canInvite }
            .sorted { lhs, rhs in
                // Best-known first: a confirmed e-mail beats a bare phone, and a
                // richer record beats a name with one address.
                if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    /// Records that share a name but no identifier. Surfaced rather than
    /// merged, because two people really can share a name.
    private func duplicatePairs() -> [Object] {
        let all = stateQueue.sync { records }
        var seen = Set<String>()
        var pairs: [Object] = []
        for (index, left) in all.enumerated() {
            for right in all[(index + 1)...] {
                guard HavenRelationMerger.looksLikeSamePerson(left, right),
                      !HavenRelationMerger.sharesStrongIdentifier(left, right) else { continue }
                let key = [left.id, right.id].sorted().joined(separator: "|")
                guard seen.insert(key).inserted else { continue }
                pairs.append([
                    "leftID": .string(left.id),
                    "rightID": .string(right.id),
                    "displayName": .string(left.displayName),
                    "leftSummary": .string(HavenRelationPresenter.subtitle(for: left)),
                    "rightSummary": .string(HavenRelationPresenter.subtitle(for: right)),
                    "question": .string("Er dette samme person?")
                ])
            }
        }
        return pairs
    }

    private func batches() -> [Object] {
        let all = stateQueue.sync { records }
        var grouped: [String: (label: String, kind: String, count: Int, importedAt: Date)] = [:]
        for record in all {
            for source in record.sources {
                guard let batchID = source.batchID else { continue }
                if var existing = grouped[batchID] {
                    existing.count += 1
                    existing.importedAt = max(existing.importedAt, source.importedAt)
                    grouped[batchID] = existing
                } else {
                    grouped[batchID] = (source.label, source.kind.rawValue, 1, source.importedAt)
                }
            }
        }
        return grouped
            .sorted { $0.value.importedAt > $1.value.importedAt }
            .map { batchID, info in
                [
                    "batchID": .string(batchID),
                    "label": .string(info.label),
                    "kind": .string(info.kind),
                    "recordCount": .integer(info.count),
                    "importedAt": .string(HavenValue.iso(info.importedAt)),
                    "importedAtText": .string(HavenValue.readable(info.importedAt)),
                    "summary": .string("\(info.count) relasjoner fra \(info.label)")
                ]
            }
    }

    private func stats() -> Object {
        let all = stateQueue.sync { records }
        let reachable = all.filter { !$0.reachableEndpoints.isEmpty }
        let inHaven = all.filter(\.isInHaven)
        let invitable = all.filter { $0.inviteReadiness.canInvite }
        let noChannel = all.filter { $0.reachableEndpoints.isEmpty && !$0.isInHaven }
        return [
            "total": .integer(all.count),
            "reachable": .integer(reachable.count),
            "inHaven": .integer(inHaven.count),
            "invitable": .integer(invitable.count),
            "missingChannel": .integer(noChannel.count),
            "blocked": .integer(all.filter { $0.inviteState == .blocked }.count),
            "invitesSent": .integer(all.filter { $0.inviteState == .sent || $0.inviteState == .opened }.count),
            "possibleDuplicates": .integer(duplicatePairs().count),
            "summaryText": .string(summaryText(total: all.count, invitable: invitable.count, inHaven: inHaven.count, missingChannel: noChannel.count))
        ]
    }

    private func summaryText(total: Int, invitable: Int, inHaven: Int, missingChannel: Int) -> String {
        guard total > 0 else {
            return "Ingen relasjoner ennå. Hent noen fra kontaktene dine eller slipp inn en fil."
        }
        var sentence = "\(total) relasjoner. \(invitable) kan inviteres nå"
        if inHaven > 0 { sentence += ", \(inHaven) er allerede i HAVEN" }
        if missingChannel > 0 { sentence += ", \(missingChannel) mangler e-post eller telefon" }
        return sentence + "."
    }

    /// One list for the surface to show, whatever the person just did.
    ///
    /// After a search it is the matches; before any search it is the people
    /// most worth inviting. Binding two different lists to two different
    /// keypaths and hoping the UI picks the right one is how a screen ends up
    /// showing stale results next to fresh ones.
    private func shortlist() -> (rows: [Object], note: String) {
        let search = stateQueue.sync { lastSearch }
        if HavenValue.string(search["status"]) == "matched" || HavenValue.string(search["status"]) == "ambiguous",
           let matches = HavenValue.list(search["matches"]), !matches.isEmpty {
            let query = HavenValue.string(search["query"]) ?? ""
            return (
                matches.compactMap(HavenValue.object),
                matches.count == 1
                    ? "Ett treff på «\(query)»."
                    : "\(matches.count) treff på «\(query)». Tøm søkefeltet for å se forslagene igjen."
            )
        }
        let candidates = inviteCandidates()
        guard !candidates.isEmpty else {
            let total = stateQueue.sync { records }.count
            return ([], total == 0
                ? ""
                : "Ingen av de \(total) relasjonene dine har e-post eller telefon jeg kan sende til.")
        }
        let shown = Array(candidates.prefix(20))
        return (
            shown.map { HavenRelationPresenter.row(for: $0) },
            candidates.count > shown.count
                ? "Viser \(shown.count) av \(candidates.count) som kan inviteres. Søk for å finne en bestemt."
                : ""
        )
    }

    private func stateObject() -> Object {
        let statistics = stats()
        let visibleList = shortlist()
        return [
            "schema": .string("haven.relations.state.v1"),
            "summary": .string(HavenValue.string(statistics["summaryText"]) ?? ""),
            "stats": .object(statistics),
            "region": .string(stateQueue.sync { region }),
            "records": .list(sortedRecords().map { .object(HavenRelationPresenter.row(for: $0)) }),
            "inviteCandidates": .list(inviteCandidates().map { .object(HavenRelationPresenter.row(for: $0)) }),
            "shortlist": .list(visibleList.rows.map(ValueType.object)),
            "shortlistNote": .string(visibleList.note),
            "duplicates": .list(duplicatePairs().map(ValueType.object)),
            "batches": .list(batches().map(ValueType.object)),
            "lastSearch": .object(stateQueue.sync { lastSearch }),
            "lastMutation": .object(stateQueue.sync { lastMutation }),
            "entitySync": .object(stateQueue.sync { lastEntitySync }),
            "privacyBoundary": .string("owner_entity_local_no_network"),
            "updatedAt": .string(HavenValue.iso(Date()))
        ]
    }

    /// Everything needed to rebuild this cell elsewhere. Used by the residency
    /// cell when relations move to another home, and by backup.
    private func snapshot() -> Object {
        let all = stateQueue.sync { records }
        let payload = HavenValue.value(all)
        let canonical = (try? HavenValue.encoder().encode(all)) ?? Data()
        return [
            "schema": .string("haven.relations.snapshot.v1"),
            "recordCount": .integer(all.count),
            "records": payload,
            "byteSize": .integer(canonical.count),
            "contentHash": .string(HavenRelationNormalizer.sha256Hex(String(data: canonical, encoding: .utf8) ?? "")),
            "createdAt": .string(HavenValue.iso(Date()))
        ]
    }

    // MARK: - Writes

    /// Accepts either already-shaped records (`records: [...]`) or loose
    /// contact objects (`contacts: [...]`) as they come off the address book
    /// bridge, and folds them into the store with full provenance.
    private func upsert(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let now = Date()
        let currentRegion = HavenValue.string(payload["region"]) ?? stateQueue.sync { region }

        let source = Self.source(from: HavenValue.object(payload["source"]), fallbackKind: .manual, now: now)

        var incoming: [HavenRelationRecord] = []
        if let list = HavenValue.list(payload["records"]) {
            incoming = list.compactMap { HavenValue.decode(HavenRelationRecord.self, from: $0) }
        }
        if let list = HavenValue.list(payload["contacts"]) {
            incoming.append(contentsOf: list.compactMap {
                Self.record(fromLooseContact: HavenValue.object($0), source: source, region: currentRegion, now: now)
            })
        }

        guard !incoming.isEmpty else {
            let result = HavenValue.error(
                code: "no_records",
                message: "Ingen relasjoner i forespørselen. Send enten `records` eller `contacts`."
            )
            stateQueue.sync { lastMutation = result }
            return result
        }

        var added = 0
        var merged = 0
        var flaggedDuplicates = 0

        stateQueue.sync {
            var index: [String: Int] = [:]
            for (position, record) in records.enumerated() { index[record.id] = position }

            for var candidate in incoming {
                if candidate.sources.isEmpty { candidate.sources = [source] }

                // First try the deterministic id, then a strong-identifier scan,
                // because two exports can spell the same person differently and
                // still share an address.
                var target: Int?
                if let position = index[candidate.id] {
                    target = position
                } else {
                    target = records.firstIndex { HavenRelationMerger.sharesStrongIdentifier($0, candidate) }
                }

                if let position = target {
                    records[position] = HavenRelationMerger.merge(
                        existing: records[position],
                        incoming: candidate,
                        now: now
                    )
                    merged += 1
                } else {
                    // Same name, no shared identifier: keep both, flag the pair.
                    let lookalikes = records.enumerated().filter {
                        HavenRelationMerger.looksLikeSamePerson($0.element, candidate)
                    }
                    if !lookalikes.isEmpty {
                        flaggedDuplicates += lookalikes.count
                        candidate.possibleDuplicateIDs = lookalikes.map(\.element.id)
                        for (position, _) in lookalikes {
                            records[position].possibleDuplicateIDs = HavenRelationMerger
                                .dedupePreservingOrder(records[position].possibleDuplicateIDs + [candidate.id])
                        }
                    }
                    index[candidate.id] = records.count
                    records.append(candidate)
                    added += 1
                }
            }
        }

        let result = HavenValue.ok(
            mutationMessage(added: added, merged: merged, flagged: flaggedDuplicates),
            sideEffect: true,
            extra: [
                "added": .integer(added),
                "merged": .integer(merged),
                "flaggedDuplicates": .integer(flaggedDuplicates),
                "batchID": .string(source.batchID ?? ""),
                "stats": .object(stats())
            ]
        )
        stateQueue.sync { lastMutation = result }
        return result
    }

    private func mutationMessage(added: Int, merged: Int, flagged: Int) -> String {
        var parts: [String] = []
        if added > 0 { parts.append(added == 1 ? "1 ny relasjon" : "\(added) nye relasjoner") }
        if merged > 0 { parts.append(merged == 1 ? "1 slått sammen med en du hadde" : "\(merged) slått sammen med noen du hadde") }
        if parts.isEmpty { parts.append("ingenting endret") }
        var sentence = parts.joined(separator: ", ") + "."
        if flagged > 0 {
            sentence += " \(flagged) har samme navn som noen fra før — jeg slo dem ikke sammen, du får velge."
        }
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }

    /// The path a prompt such as "inviter Vegar" runs through.
    private func search(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let query = HavenValue.string(payload["query"])
            ?? HavenValue.string(payload["text"])
            ?? HavenValue.string(value)
            ?? ""
        let limit = HavenValue.int(payload["limit"]) ?? 10
        let onlyInvitable = HavenValue.bool(payload["onlyInvitable"]) ?? false
        let currentRegion = stateQueue.sync { region }

        var pool = stateQueue.sync { records }
        if onlyInvitable { pool = pool.filter { $0.inviteReadiness.canInvite } }

        let matches = HavenRelationMatcher.search(query: query, in: pool, limit: limit, region: currentRegion)

        // Ambiguity is a real outcome, not an error: two strong matches means
        // we must ask rather than pick.
        let strong = matches.filter { $0.score >= 0.55 }
        let needsClarification = strong.count > 1
            && abs((strong.first?.score ?? 0) - (strong.dropFirst().first?.score ?? 0)) < 0.15

        var result: Object = [
            "schema": .string("haven.relations.search.v1"),
            "status": .string(matches.isEmpty ? "noMatch" : (needsClarification ? "ambiguous" : "matched")),
            "query": .string(query),
            "matchCount": .integer(matches.count),
            "matches": .list(matches.map { match in
                var row = HavenRelationPresenter.row(for: match.record)
                row["score"] = .float(match.score)
                row["matchReason"] = .string(match.reason)
                return .object(row)
            }),
            "needsClarification": .bool(needsClarification),
            "askUserWhenUnclear": .bool(true),
            "sideEffect": .bool(false),
            "updatedAt": .string(HavenValue.iso(Date()))
        ]

        if matches.isEmpty {
            result["summaryText"] = .string(
                query.isEmpty
                    ? "Ingen relasjoner å vise ennå."
                    : "Jeg fant ingen som matcher «\(query)». Vil du hente flere fra kontaktene eller en fil?"
            )
            result["clarifyingQuestion"] = .string("")
        } else if needsClarification {
            let names = strong.prefix(3).map(\.record.displayName).joined(separator: ", ")
            result["summaryText"] = .string("Flere passer på «\(query)».")
            result["clarifyingQuestion"] = .string("Mente du \(names)?")
        } else if let best = matches.first {
            let readiness = best.record.inviteReadiness
            result["summaryText"] = .string(
                readiness.canInvite
                    ? "\(best.record.displayName) — \(HavenRelationPresenter.endpointSummary(for: best.record))."
                    : readiness.reason
            )
            result["clarifyingQuestion"] = .string("")
            result["bestMatchID"] = .string(best.record.id)
        }

        stateQueue.sync { lastSearch = result }
        return result
    }

    private func setInviteState(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let id = HavenValue.string(payload["id"]) ?? HavenValue.string(payload["relationID"]) else {
            return HavenValue.error(code: "missing_id", message: "Mangler `id`.")
        }
        guard let stateText = HavenValue.string(payload["state"]),
              let state = HavenInviteState(rawValue: stateText) else {
            return HavenValue.error(
                code: "bad_state",
                message: "Ukjent invitasjonsstatus. Gyldige: " + HavenInviteState.allCasesText
            )
        }
        var found = false
        stateQueue.sync {
            guard let position = records.firstIndex(where: { $0.id == id }) else { return }
            found = true
            records[position].inviteState = state
            records[position].updatedAt = Date()
            if state == .sent || state == .prepared {
                records[position].lastInviteAt = HavenValue.date(payload["at"]) ?? Date()
                records[position].lastInviteChannel = HavenValue.string(payload["channel"])
                records[position].lastInviteTicketID = HavenValue.string(payload["ticketID"])
            }
            if state == .joined, let entityRef = HavenValue.string(payload["entityRef"]) {
                records[position].entityRef = entityRef
            }
        }
        guard found else {
            return HavenValue.error(code: "not_found", message: "Fant ingen relasjon med id \(id).")
        }
        let result = HavenValue.ok(
            "Status satt til \(HavenRelationPresenter.stateText(state)).",
            sideEffect: true,
            extra: ["id": .string(id), "state": .string(state.rawValue)]
        )
        stateQueue.sync { lastMutation = result }
        return result
    }

    private func setEntityRef(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let id = HavenValue.string(payload["id"]) else {
            return HavenValue.error(code: "missing_id", message: "Mangler `id`.")
        }
        let entityRef = HavenValue.string(payload["entityRef"])
        var found = false
        stateQueue.sync {
            guard let position = records.firstIndex(where: { $0.id == id }) else { return }
            found = true
            records[position].entityRef = entityRef
            if entityRef != nil { records[position].inviteState = .joined }
            records[position].updatedAt = Date()
        }
        guard found else {
            return HavenValue.error(code: "not_found", message: "Fant ingen relasjon med id \(id).")
        }
        return HavenValue.ok("Entitetsreferansen er oppdatert.", sideEffect: true, extra: ["id": .string(id)])
    }

    private func setBlocked(_ value: ValueType, blocked: Bool) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let id = HavenValue.string(payload["id"]) ?? HavenValue.string(value) else {
            return HavenValue.error(code: "missing_id", message: "Mangler `id`.")
        }
        var found = false
        stateQueue.sync {
            guard let position = records.firstIndex(where: { $0.id == id }) else { return }
            found = true
            records[position].inviteState = blocked ? .blocked : .none
            records[position].updatedAt = Date()
        }
        guard found else {
            return HavenValue.error(code: "not_found", message: "Fant ingen relasjon med id \(id).")
        }
        return HavenValue.ok(
            blocked
                ? "Blokkert. Denne får ingen invitasjoner, heller ikke fra en senere import."
                : "Blokkeringen er fjernet.",
            sideEffect: true,
            extra: ["id": .string(id)]
        )
    }

    private func remove(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let id = HavenValue.string(payload["id"]) ?? HavenValue.string(value) else {
            return HavenValue.error(code: "missing_id", message: "Mangler `id`.")
        }
        var removed = 0
        stateQueue.sync {
            let before = records.count
            records.removeAll { $0.id == id }
            removed = before - records.count
            for position in records.indices {
                records[position].possibleDuplicateIDs.removeAll { $0 == id }
            }
        }
        return HavenValue.ok(
            removed > 0 ? "Relasjonen er slettet." : "Fant ingen relasjon med den id-en.",
            sideEffect: removed > 0,
            extra: ["removed": .integer(removed), "stats": .object(stats())]
        )
    }

    /// Undo a whole import. Records that arrived only in that batch go away;
    /// records that also came from somewhere else just lose that source.
    private func forgetBatch(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let batchID = HavenValue.string(payload["batchID"]) ?? HavenValue.string(value) else {
            return HavenValue.error(code: "missing_batch", message: "Mangler `batchID`.")
        }
        var removed = 0
        var trimmed = 0
        stateQueue.sync {
            var kept: [HavenRelationRecord] = []
            for var record in records {
                let remaining = record.sources.filter { $0.batchID != batchID }
                if remaining.isEmpty && record.sources.count > 0 {
                    // Never silently discard someone we have actually been in
                    // contact with, even if the import was their only source.
                    if record.isInHaven || record.inviteState == .sent || record.inviteState == .opened || record.inviteState == .blocked {
                        record.sources = []
                        trimmed += 1
                        kept.append(record)
                    } else {
                        removed += 1
                    }
                } else {
                    if remaining.count != record.sources.count { trimmed += 1 }
                    record.sources = remaining
                    kept.append(record)
                }
            }
            records = kept
        }
        return HavenValue.ok(
            "Importen er trukket tilbake: \(removed) slettet, \(trimmed) beholdt fordi du har hatt kontakt med dem.",
            sideEffect: true,
            extra: ["removed": .integer(removed), "trimmed": .integer(trimmed), "stats": .object(stats())]
        )
    }

    /// The user's answer to a flagged duplicate pair.
    private func mergeManually(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let keepID = HavenValue.string(payload["keepID"]),
              let mergeID = HavenValue.string(payload["mergeID"]),
              keepID != mergeID else {
            return HavenValue.error(code: "bad_request", message: "Trenger `keepID` og `mergeID`, og de må være forskjellige.")
        }
        var ok = false
        stateQueue.sync {
            guard let keepPosition = records.firstIndex(where: { $0.id == keepID }),
                  let mergePosition = records.firstIndex(where: { $0.id == mergeID }) else { return }
            let incoming = records[mergePosition]
            records[keepPosition] = HavenRelationMerger.merge(
                existing: records[keepPosition],
                incoming: incoming,
                now: Date()
            )
            records[keepPosition].possibleDuplicateIDs.removeAll { $0 == mergeID }
            records.remove(at: mergePosition)
            for position in records.indices {
                records[position].possibleDuplicateIDs.removeAll { $0 == mergeID }
            }
            ok = true
        }
        guard ok else {
            return HavenValue.error(code: "not_found", message: "Fant ikke begge relasjonene.")
        }
        return HavenValue.ok("Slått sammen.", sideEffect: true, extra: ["id": .string(keepID), "stats": .object(stats())])
    }

    private func setRegion(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let candidate = HavenValue.string(payload["region"]) ?? HavenValue.string(value),
              candidate.count == 2 else {
            return HavenValue.error(code: "bad_region", message: "Oppgi en tobokstavs landkode, for eksempel NO.")
        }
        stateQueue.sync { region = candidate.uppercased() }
        return HavenValue.ok(
            "Telefonnumre uten landkode tolkes nå som \(candidate.uppercased()).",
            sideEffect: true,
            extra: ["region": .string(candidate.uppercased())]
        )
    }

    private func clearAll() -> Object {
        var removed = 0
        stateQueue.sync {
            removed = records.count
            records = []
            lastSearch = Self.emptySearch()
        }
        return HavenValue.ok(
            "Alle \(removed) relasjoner er slettet fra entiteten din.",
            sideEffect: true,
            extra: ["removed": .integer(removed)]
        )
    }

    private func restoreSnapshot(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let list = payload["records"],
              let restored = HavenValue.decode([HavenRelationRecord].self, from: list) else {
            return HavenValue.error(code: "bad_snapshot", message: "Fant ingen gyldig `records`-liste i øyeblikksbildet.")
        }
        let mode = HavenValue.string(payload["mode"]) ?? "replace"
        stateQueue.sync {
            if mode == "merge" {
                for candidate in restored {
                    if let position = records.firstIndex(where: { $0.id == candidate.id }) {
                        records[position] = HavenRelationMerger.merge(existing: records[position], incoming: candidate)
                    } else {
                        records.append(candidate)
                    }
                }
            } else {
                records = restored
            }
        }
        return HavenValue.ok(
            "Gjenopprettet \(restored.count) relasjoner (\(mode == "merge" ? "flettet inn" : "erstattet")).",
            sideEffect: true,
            extra: ["restored": .integer(restored.count), "stats": .object(stats())]
        )
    }

    /// Publishes what the relations imply about what I am trying to do, into
    /// Perspective.
    ///
    /// This is the *purpose* half. The entity half now has a real home — see
    /// `projectToPerspective` — so passing `includeEntities` does both in one
    /// call, which is what the surface wants.
    private func publishPurposeSignals(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let includeEntities = HavenValue.bool(payload["includeEntities"])
            ?? HavenValue.bool(payload["includeEntityDrafts"])
            ?? true

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let perspective = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///Perspective",
                requester: requester
              ) as? Meddle else {
            return HavenValue.error(
                code: "perspective_unavailable",
                message: "Perspective er ikke tilgjengelig i denne kjøringen."
            )
        }

        var published = 0
        var failures: [String] = []
        for signal in purposeSignals() {
            let purposeName = HavenValue.string(signal["purposeName"]) ?? "Invite people into HAVEN"
            let purposeObject: Object = [
                "name": .string(purposeName),
                "description": .string(HavenValue.string(signal["reason"]) ?? "Publisert fra Relations."),
                "types": .list([]),
                "subTypes": .list([]),
                "parts": .list([]),
                "partOf": .list([]),
                "purposes": .list([]),
                "interests": .list([]),
                "entities": .list([]),
                "states": .list([])
            ]
            let signalPayload: Object = [
                "purpose": .object(purposeObject),
                "purposeWeight": signal["purposeWeight"] ?? .float(0.5)
            ]
            if (try? await perspective.set(keypath: "addPurpose", value: .object(signalPayload), requester: requester)) != nil {
                published += 1
            } else {
                failures.append(purposeName)
            }
        }

        var extra: Object = [
            "publishedCount": .integer(published),
            "failedPurposes": .list(failures.map(ValueType.string))
        ]
        if includeEntities, stateQueue.sync(execute: { projectionEnabled }) {
            let projection = await projectToPerspective(requester: requester)
            extra["entityProjection"] = .object(projection)
            extra["entityProjectionStatus"] = .string(HavenValue.string(projection["status"]) ?? "unknown")
        } else if includeEntities {
            extra["entityProjectionStatus"] = .string("disabled")
            extra["entityProjectionNote"] = .string(
                "Relasjonene projiseres ikke inn i perspektivet før du slår det på."
            )
        }
        return HavenValue.ok(
            failures.isEmpty
                ? "Publiserte \(published) formålssignaler til Perspective."
                : "Publiserte \(published), \(failures.count) feilet.",
            sideEffect: true,
            extra: extra
        )
    }

    private func purposeSignals() -> [Object] {
        let all = stateQueue.sync { records }
        let invitable = all.filter { $0.inviteReadiness.canInvite }
        var signals: [Object] = [
            [
                "purposeName": .string("Invite people I know into HAVEN"),
                "portablePurposeRef": .string("purpose://invite-known-people"),
                "purposeWeight": .float(invitable.isEmpty ? 0.35 : min(0.95, 0.5 + Double(invitable.count) / 40.0)),
                "interests": .list([
                    .string("relations"),
                    .string("invite-person"),
                    .string("onboarding"),
                    .string("network-growth")
                ]),
                "reason": .string(
                    invitable.isEmpty
                        ? "Ingen relasjoner er klare til å inviteres ennå."
                        : "\(invitable.count) relasjoner har en kanal jeg kan sende en invitasjon på."
                )
            ]
        ]

        // Tags that recur across many relations say something about what this
        // entity is actually working on.
        var tagCounts: [String: Int] = [:]
        for record in all {
            for tag in record.contextTags {
                tagCounts[HavenRelationNormalizer.fold(tag), default: 0] += 1
            }
        }
        for (tag, count) in tagCounts.sorted(by: { $0.value > $1.value }).prefix(3) where count >= 3 {
            signals.append([
                "purposeName": .string("Reach the \(tag) network"),
                "portablePurposeRef": .string("purpose://reach-\(tag.replacingOccurrences(of: " ", with: "-"))"),
                "purposeWeight": .float(min(0.85, 0.3 + Double(count) / 30.0)),
                "interests": .list([.string("relations"), .string(tag)]),
                "reason": .string("\(count) relasjoner er merket «\(tag)».")
            ])
        }
        return signals
    }

    // MARK: - Projection into the perspective

    /// Turning the projection on is a disclosure, so it is a decision, not a
    /// default. Turning it off removes what was projected — the perspective
    /// never keeps a copy of something the owner withdrew.
    private func setProjectionEnabled(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let enabled = HavenValue.bool(payload["enabled"]) ?? HavenValue.bool(value) ?? false
        stateQueue.sync { projectionEnabled = enabled }

        if enabled {
            return await projectToPerspective(requester: requester)
        }

        guard let perspective = await perspectiveCell(requester: requester) else {
            return HavenValue.ok(
                "Projeksjonen er slått av. Perspective var ikke tilgjengelig, så den ryddes neste gang.",
                sideEffect: true
            )
        }
        // An empty set is the legitimate way to say "I contribute nobody".
        let response = try? await perspective.set(
            keypath: "projectEntities",
            value: .object([
                "source": .string(Self.endpoint),
                "epoch": .integer(nextProjectionEpoch()),
                "entities": .list([])
            ]),
            requester: requester
        )
        let responseObject = HavenValue.object(response) ?? [:]
        let result = HavenValue.ok(
            "Projeksjonen er slått av, og relasjonene er fjernet fra perspektivet.",
            sideEffect: true,
            extra: ["perspectiveResponse": .object(responseObject)]
        )
        stateQueue.sync { lastMutation = result }
        return result
    }

    /// Writes the whole relation set into the perspective as one projection.
    ///
    /// Whole-set, not incremental: that is what makes deleting a relation
    /// reach the graph. Anything this cell contributed before and does not
    /// contribute now is removed on the other side.
    ///
    /// What goes: a salted opaque reference, the display name, the interests
    /// the tags imply, and a weight. What stays here: endpoints, endpoint
    /// hashes, notes, and which spreadsheet a person arrived in. The
    /// perspective is built to be compared against other parties; contact
    /// detail has no business in it.
    private func projectToPerspective(requester: Identity) async -> Object {
        guard stateQueue.sync(execute: { projectionEnabled }) else {
            return HavenValue.error(
                code: "projection_disabled",
                message: "Projeksjonen er av. Slå den på med relations.setProjectionEnabled hvis butleren skal kunne foreslå folk."
            )
        }
        guard let perspective = await perspectiveCell(requester: requester) else {
            return HavenValue.error(
                code: "perspective_unavailable",
                message: "Perspective er ikke tilgjengelig i denne kjøringen."
            )
        }

        let entities = projectedEntities()
        let epoch = nextProjectionEpoch()
        guard let response = try? await perspective.set(
            keypath: "projectEntities",
            value: .object([
                "source": .string(Self.endpoint),
                "epoch": .integer(epoch),
                "entities": .list(entities)
            ]),
            requester: requester
        ), let responseObject = HavenValue.object(response) else {
            return HavenValue.error(
                code: "projection_failed",
                message: "Perspective tok ikke imot projeksjonen."
            )
        }

        if HavenValue.string(responseObject["status"]) == "error" {
            return HavenValue.error(
                code: HavenValue.string(responseObject["code"]) ?? "projection_failed",
                message: HavenValue.string(responseObject["message"]) ?? "Projeksjonen feilet."
            )
        }

        let result = HavenValue.ok(
            HavenValue.string(responseObject["message"]) ?? "Perspektivet er oppdatert.",
            sideEffect: true,
            extra: [
                "projectedCount": .integer(entities.count),
                "epoch": .integer(epoch),
                "perspectiveResponse": .object(responseObject),
                "privacyBoundary": .string("names_weights_and_interests_only_no_contact_detail")
            ]
        )
        stateQueue.sync { lastMutation = result }
        return result
    }

    private func nextProjectionEpoch() -> Int {
        stateQueue.sync {
            projectionEpoch += 1
            return projectionEpoch
        }
    }

    private func perspectiveCell(requester: Identity) async -> Meddle? {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else { return nil }
        return try? await resolver.cellAtEndpoint(endpoint: "cell:///Perspective", requester: requester) as? Meddle
    }

    /// Canonical `Weight` shape: `{ weight, value }`.
    ///
    /// An earlier draft of this put the node under `"object"`, which decodes to
    /// a weight with no value — the projection would have been accepted and
    /// then silently dropped every person in it.
    private func projectedEntities() -> [ValueType] {
        let all = stateQueue.sync { records }
        let salt = projectionSaltValue()
        return all.compactMap { record -> ValueType? in
            let name = HavenRelationNormalizer.collapseWhitespace(record.displayName)
            guard !name.isEmpty else { return nil }
            return .object([
                "weight": .float(Self.relationSalience(record)),
                "value": .object([
                    "name": .string(name),
                    "nodeIdentifier": .string(Self.opaqueReference(for: record, salt: salt)),
                    "projectionSource": .string(Self.endpoint),
                    "types": .list([]),
                    "subTypes": .list([]),
                    "parts": .list([]),
                    "partOf": .list([]),
                    "purposes": .list([]),
                    "interests": .list(Self.interestWeights(for: record)),
                    "entities": .list([]),
                    "states": .list([]),
                    "agreementRefs": .list([])
                ])
            ])
        }
    }

    /// How much this relation should count when the perspective is matched.
    ///
    /// Deliberately *not* `confidence`: that measures whether we merged two
    /// rows correctly, and using it here would rank a clean CSV import above
    /// someone the owner actually knows. Salience is about the relationship —
    /// are they in HAVEN, have we been in contact, do we know what they care
    /// about.
    static func relationSalience(_ record: HavenRelationRecord) -> Double {
        var weight = 0.25
        if record.isInHaven { weight += 0.35 }
        switch record.inviteState {
        case .sent, .opened: weight += 0.15
        case .joined: weight += 0.2
        case .blocked: return 0.0
        default: break
        }
        if !record.contextTags.isEmpty { weight += 0.1 }
        if record.organization?.isEmpty == false { weight += 0.05 }
        if record.endpoints.contains(where: \.confirmed) { weight += 0.1 }
        return min(1.0, weight)
    }

    /// Marks a tag the importer inferred rather than read. A working group the
    /// person chose is evidence; a guess from their job title is a hypothesis,
    /// and the graph should not weigh them the same.
    static let inferredTagPrefix = "antatt:"

    /// Tags become interests, which is the whole reason to project at all.
    /// An entity with no interests matches nothing, so a projection of bare
    /// names would make the graph bigger without making it smarter.
    ///
    /// Declared interests come first and heavier, inferred ones after and
    /// lighter. Order matters because the list is capped: without sorting, an
    /// arbitrary insertion order decided which interests survived the cut.
    static func interestWeights(for record: HavenRelationRecord) -> [ValueType] {
        let declared = record.contextTags.filter { !$0.hasPrefix(inferredTagPrefix) }
        let inferred = record.contextTags.filter { $0.hasPrefix(inferredTagPrefix) }
        let ordered = declared.map { (name: $0, weight: 0.75) }
            + inferred.map { (name: String($0.dropFirst(inferredTagPrefix.count)), weight: 0.35) }

        return ordered.prefix(12).map { entry in
            .object([
                "weight": .float(entry.weight),
                "value": .object([
                    "name": .string(entry.name),
                    "types": .list([]),
                    "subTypes": .list([]),
                    "parts": .list([]),
                    "partOf": .list([]),
                    "purposes": .list([]),
                    "interests": .list([]),
                    "entities": .list([]),
                    "states": .list([])
                ])
            ])
        }
    }

    /// Stable for this entity, meaningless anywhere else. Two people called
    /// the same thing get different references; the same person keeps theirs
    /// across restarts.
    static func opaqueReference(for record: HavenRelationRecord, salt: String) -> String {
        "e-" + HavenRelationNormalizer.sha256Hex("haven.relation.projection.v1|\(salt)|\(record.id)").prefix(24)
    }

    private func projectionSaltValue() -> String {
        stateQueue.sync {
            if projectionSalt.isEmpty {
                var bytes = [UInt8](repeating: 0, count: 32)
                for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
                projectionSalt = Data(bytes).base64EncodedString()
            }
            return projectionSalt
        }
    }

    // MARK: - The entity: where a relation lives

    /// Coalesces bursts of mutations into one authority commit.
    private func scheduleEntitySync(requester: Identity) {
        entitySyncTask?.cancel()
        entitySyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            _ = await self.syncToEntity(requester: requester, force: false)
        }
    }

    /// Writes every record the entity does not have in this form, and forgets
    /// the ones that are gone. One commit for the records, one for the
    /// removals, both idempotent on content.
    private func syncToEntity(requester: Identity, force: Bool) async -> Object {
        let (current, salt, alreadySynced) = stateQueue.sync { (records, projectionSalt, entitySyncedIDs) }
        let existing: [String: EntityRelationRecord]
        do {
            existing = try await BindingRelationEntityStore.loadRecords(requester: requester)
        } catch {
            let result = HavenValue.error(code: "entity_unavailable", message: "Entiteten er ikke tilgjengelig: \(error.localizedDescription)")
            stateQueue.sync { lastEntitySync = result }
            return result
        }

        var toWrite: [EntityRelationRecord] = []
        for record in current {
            let previous = existing[record.id]
            let mapped = HavenRelationEntityMapper.entityRecord(
                from: record,
                existing: previous,
                perspectiveRef: salt.isEmpty ? nil : Self.opaqueReference(for: record, salt: salt)
            )
            if force || previous == nil || Self.entityRecordDiffers(previous, mapped) {
                toWrite.append(mapped)
            }
        }
        let currentIDs = Set(current.map(\.id))
        let toForget = existing.keys.filter { !currentIDs.contains($0) && (alreadySynced.contains($0) || force) }

        var written = 0
        var forgotten = 0
        do {
            if !toWrite.isEmpty {
                let result = try await BindingRelationEntityStore.persist(records: toWrite, requester: requester, sourceUUID: uuid)
                written = result.idempotentReplay ? 0 : toWrite.count
            }
            if !toForget.isEmpty {
                try await BindingRelationEntityStore.remove(relationIDs: toForget, requester: requester, sourceUUID: uuid)
                forgotten = toForget.count
            }
        } catch {
            let result = HavenValue.error(code: "entity_write_failed", message: "Kunne ikke skrive relasjonene til entiteten: \(error.localizedDescription)")
            stateQueue.sync { lastEntitySync = result }
            return result
        }

        let result = HavenValue.ok(
            written == 0 && forgotten == 0
                ? "Entiteten hadde alt fra før."
                : "\(written) relasjoner skrevet til entiteten" + (forgotten > 0 ? ", \(forgotten) glemt." : "."),
            sideEffect: written > 0 || forgotten > 0,
            extra: [
                "written": .integer(written),
                "forgotten": .integer(forgotten),
                "inEntity": .integer(existing.count - toForget.count + toWrite.filter { existing[$0.relationID] == nil }.count),
                "syncedAt": .string(HavenValue.iso(Date()))
            ]
        )
        stateQueue.sync {
            lastEntitySync = result
            entitySyncedIDs = currentIDs
        }
        return result
    }

    /// Everything but the bookkeeping the mapper bumps on every call.
    private static func entityRecordDiffers(_ lhs: EntityRelationRecord?, _ rhs: EntityRelationRecord) -> Bool {
        guard var lhs else { return true }
        var rhs = rhs
        lhs.updatedAt = rhs.updatedAt
        lhs.revision = rhs.revision
        return lhs != rhs
    }

    /// «Hvordan når jeg Vegar?» — search, then plan from the entity record,
    /// or from the device record mapped on the fly when the entity has none
    /// yet. Ambiguity is returned as a question, never resolved by guessing.
    private func reach(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let explicitID = HavenValue.string(payload["id"]) ?? HavenValue.string(payload["relationID"])

        let record: HavenRelationRecord?
        if let explicitID {
            record = stateQueue.sync { records.first { $0.id == explicitID } }
            guard record != nil else {
                return HavenValue.error(code: "not_found", message: "Fant ingen relasjon med id \(explicitID).")
            }
        } else {
            let found = search(value)
            let status = HavenValue.string(found["status"]) ?? "noMatch"
            guard status == "matched", let bestID = HavenValue.string(found["bestMatchID"]) else {
                var result = found
                result["schema"] = .string("haven.relations.reach.v1")
                result["reach"] = .null
                return result
            }
            record = stateQueue.sync { records.first { $0.id == bestID } }
        }
        guard let record else {
            return HavenValue.error(code: "not_found", message: "Relasjonen forsvant under oppslaget.")
        }

        let salt = stateQueue.sync { projectionSalt }
        let entityRecord = (try? await BindingRelationEntityStore.loadRecord(relationID: record.id, requester: requester))
            ?? HavenRelationEntityMapper.entityRecord(
                from: record,
                existing: nil,
                perspectiveRef: salt.isEmpty ? nil : Self.opaqueReference(for: record, salt: salt)
            )
        let plan = EntityRelationReachPlanner.plan(for: entityRecord)
        let readiness = record.inviteReadiness

        var row = HavenRelationPresenter.row(for: record)
        row["roles"] = HavenValue.value(record.roles)
        let lastContact: ValueType = plan.lastContact.map { ValueType.string(HavenValue.iso($0)) } ?? .null
        let lastContactKind: ValueType = plan.lastContactKind.map { ValueType.string($0) } ?? .null
        return [
            "schema": .string("haven.relations.reach.v1"),
            "status": .string(plan.canReach ? "reachable" : "unreachable"),
            "relation": .object(row),
            "reach": HavenValue.value(plan),
            "summaryText": .string(plan.recommended?.reason ?? plan.blockers.joined(separator: " ")),
            "inviteReadiness": .object([
                "canInvite": .bool(readiness.canInvite),
                "reason": .string(readiness.reason)
            ]),
            "lastContact": lastContact,
            "lastContactKind": lastContactKind,
            "sideEffect": .bool(false),
            "updatedAt": .string(HavenValue.iso(Date()))
        ]
    }

    /// Something happened with a relation. Goes to the chronicle and moves
    /// the relation's summary, under the owner's interaction policy.
    private func recordInteraction(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let id = HavenValue.string(payload["id"]) ?? HavenValue.string(payload["relationID"]) else {
            return HavenValue.error(code: "missing_id", message: "Mangler `id`.")
        }
        guard let kindText = HavenValue.string(payload["kind"]),
              let kind = EntityRelationInteractionKind(rawValue: kindText) else {
            return HavenValue.error(
                code: "bad_kind",
                message: "Ukjent hendelsestype. Gyldige: " + EntityRelationInteractionKind.allCases.map(\.rawValue).joined(separator: ", ")
            )
        }
        let matched: HavenRelationRecord? = stateQueue.sync { records.first { $0.id == id } }
        guard let record = matched else {
            return HavenValue.error(code: "not_found", message: "Fant ingen relasjon med id \(id).")
        }
        let channel = HavenValue.string(payload["channel"]).flatMap(EntityRelationChannelKind.init(rawValue:))
        let direction = HavenValue.string(payload["direction"]).flatMap(EntityRelationDirection.init(rawValue:))
        let summary = HavenValue.string(payload["summary"])
        let event = EntityRelationInteractionEvent(
            id: BindingPersonalChatChronicle.safeIdentifier(HavenValue.string(payload["eventID"])),
            relationID: id,
            kind: kind,
            at: HavenValue.date(payload["at"]) ?? Date(),
            channel: channel,
            direction: direction,
            contentMode: summary == nil ? .metadata : .full,
            summary: summary,
            evidenceID: HavenValue.string(payload["evidenceID"]),
            sourceCell: HavenValue.string(payload["sourceCell"]) ?? Self.sourceCellName
        )
        let salt = stateQueue.sync { projectionSalt }
        let fallback = HavenRelationEntityMapper.entityRecord(
            from: record, existing: nil,
            perspectiveRef: salt.isEmpty ? nil : Self.opaqueReference(for: record, salt: salt)
        )
        do {
            let outcome = try await BindingRelationEntityStore.recordInteraction(
                event, fallbackRecord: fallback, requester: requester, sourceUUID: uuid
            )
            let chronicleRef: ValueType = outcome.chronicleRef.map { ValueType.string($0) } ?? .null
            let interactions: ValueType = outcome.record.map { HavenValue.value($0.interactions) } ?? .null
            let trust: ValueType = outcome.record.map { ValueType.string($0.standing.trust.rawValue) } ?? .null
            var extra: Object = [
                "status": .string(outcome.status),
                "id": .string(id),
                "eventID": .string(event.id)
            ]
            extra["chronicleRef"] = chronicleRef
            extra["interactions"] = interactions
            extra["trust"] = trust
            let result = HavenValue.ok(outcome.message, sideEffect: outcome.status == "recorded", extra: extra)
            stateQueue.sync { lastMutation = result }
            return result
        } catch {
            return HavenValue.error(code: "interaction_failed", message: error.localizedDescription)
        }
    }

    /// The events behind a relation's summary, newest first.
    private func interactions(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let id = HavenValue.string(payload["id"]) ?? HavenValue.string(payload["relationID"]) else {
            return HavenValue.error(code: "missing_id", message: "Mangler `id`.")
        }
        let limit = HavenValue.int(payload["limit"]) ?? 20
        guard let anchor = try? await BindingPersonalChatChronicle.entityAnchor(requester: requester),
              let meddle = anchor as? Meddle else {
            return HavenValue.error(code: "entity_unavailable", message: "Entiteten er ikke tilgjengelig.")
        }
        let chronicle = (try? await meddle.get(keypath: "chronicle", requester: requester)) ?? .null
        let entries: [ValueType]
        switch chronicle {
        case let .list(list): entries = list
        case let .object(object): entries = Array(object.values)
        default: entries = []
        }
        let prefix = EntityRelationRecordV1.chronicleID(relationID: id, eventID: "")
        let events = entries
            .compactMap { EntityRelationCodec.decode(EntityRelationInteractionEvent.self, from: $0) }
            .filter { $0.relationID == id }
            .sorted { $0.at > $1.at }
            .prefix(limit)
        return [
            "schema": .string("haven.relations.interactions.v1"),
            "id": .string(id),
            "count": .integer(events.count),
            "events": .list(events.map { HavenValue.value($0) }),
            "chronicleIDPrefix": .string(prefix),
            "sideEffect": .bool(false)
        ]
    }

    private func setInteractionPolicy(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let modeText = HavenValue.string(payload["mode"]) ?? HavenValue.string(value),
              let mode = EntityRelationInteractionPolicyMode(rawValue: modeText) else {
            return HavenValue.error(code: "bad_mode", message: "Gyldige valg: off, metadata, full.")
        }
        let accepted = HavenValue.bool(payload["fullContentWarningAccepted"]) ?? false
        if mode == .full, !accepted {
            return HavenValue.error(
                code: "consent_required",
                message: "`full` lagrer sammendrag av det som ble sagt. Send `fullContentWarningAccepted: true` for å bekrefte."
            )
        }
        do {
            try await BindingRelationEntityStore.setInteractionPolicy(mode, fullContentAccepted: accepted, requester: requester, sourceUUID: uuid)
            return HavenValue.ok(
                mode == .off ? "Interaksjoner logges ikke lenger." :
                mode == .full ? "Interaksjoner logges med sammendrag." :
                "Interaksjoner logges som metadata — at, når og hvordan.",
                sideEffect: true,
                extra: ["mode": .string(mode.rawValue)]
            )
        } catch {
            return HavenValue.error(code: "policy_failed", message: error.localizedDescription)
        }
    }

    // MARK: - Conversion helpers

    private static func source(from object: Object?, fallbackKind: HavenRelationSourceKind, now: Date) -> HavenRelationSource {
        let kind = HavenValue.string(object?["kind"])
            .flatMap(HavenRelationSourceKind.init(rawValue:)) ?? fallbackKind
        return HavenRelationSource(
            kind: kind,
            label: HavenValue.string(object?["label"]) ?? defaultLabel(for: kind),
            batchID: HavenValue.string(object?["batchID"]) ?? "batch-\(UUID().uuidString.prefix(8))",
            locator: HavenValue.string(object?["locator"]),
            importedAt: HavenValue.date(object?["importedAt"]) ?? now
        )
    }

    private static func defaultLabel(for kind: HavenRelationSourceKind) -> String {
        switch kind {
        case .addressBookPicker: return "Kontakter (valgt)"
        case .addressBookScan: return "Kontakter"
        case .fileImport: return "Filimport"
        case .manual: return "Lagt inn manuelt"
        case .nearby: return "I nærheten"
        case .inboundInvite: return "Invitasjon"
        }
    }

    /// Accepts the loose shape the address book bridge and chat produce:
    /// `{ displayName, givenName, familyName, organization, jobTitle,
    ///    emails: [..], phones: [..], urls: [..], tags: [..], notes }`.
    private static func record(
        fromLooseContact object: Object?,
        source: HavenRelationSource,
        region: String,
        now: Date
    ) -> HavenRelationRecord? {
        guard let object else { return nil }

        var endpoints: [HavenRelationEndpoint] = []
        func collect(_ key: String, kind: HavenEndpointKind) {
            for entry in HavenValue.list(object[key]) ?? [] {
                if let text = HavenValue.string(entry) {
                    if let endpoint = HavenRelationNormalizer.endpoint(from: text, preferredKind: kind, region: region) {
                        endpoints.append(endpoint)
                    }
                } else if let nested = HavenValue.object(entry),
                          let text = HavenValue.string(nested["value"]) ?? HavenValue.string(nested["raw"]) {
                    let endpoint = HavenRelationNormalizer.endpoint(
                        from: text,
                        preferredKind: kind,
                        label: HavenValue.string(nested["label"]),
                        region: region
                    )
                    if let endpoint { endpoints.append(endpoint) }
                }
            }
        }
        collect("emails", kind: .email)
        collect("phones", kind: .phone)
        collect("urls", kind: .url)
        collect("handles", kind: .handle)
        if let single = HavenValue.string(object["email"]),
           let endpoint = HavenRelationNormalizer.endpoint(from: single, preferredKind: .email, region: region) {
            endpoints.append(endpoint)
        }
        if let single = HavenValue.string(object["phone"]),
           let endpoint = HavenRelationNormalizer.endpoint(from: single, preferredKind: .phone, region: region) {
            endpoints.append(endpoint)
        }
        endpoints = HavenContactColumnInference.dedupeEndpoints(endpoints)

        let givenName = HavenValue.string(object["givenName"])
        let familyName = HavenValue.string(object["familyName"])
        let organization = HavenValue.string(object["organization"]) ?? HavenValue.string(object["company"])
        let displayName = HavenRelationNormalizer.displayName(
            given: givenName,
            family: familyName,
            full: HavenValue.string(object["displayName"]) ?? HavenValue.string(object["name"]),
            organization: organization,
            fallbackEndpoint: endpoints.first
        )
        guard givenName != nil || familyName != nil || !endpoints.isEmpty
                || HavenValue.string(object["displayName"]) != nil
                || HavenValue.string(object["name"]) != nil else { return nil }

        var confidence = 0.35
        if givenName != nil || familyName != nil { confidence += 0.25 }
        if endpoints.contains(where: { $0.kind == .email }) { confidence += 0.25 }
        if endpoints.contains(where: { $0.kind == .phone }) { confidence += 0.15 }

        return HavenRelationRecord(
            id: HavenRelationNormalizer.recordID(
                endpoints: endpoints,
                displayName: displayName,
                organization: organization
            ),
            displayName: displayName,
            givenName: givenName,
            familyName: familyName,
            organization: organization,
            jobTitle: HavenValue.string(object["jobTitle"]) ?? HavenValue.string(object["title"]),
            endpoints: endpoints,
            contextTags: HavenRelationMerger.dedupePreservingOrder(
                HavenValue.stringList(object["tags"]) + HavenValue.stringList(object["groups"])
            ),
            notes: HavenValue.string(object["notes"]),
            sources: [
                HavenRelationSource(
                    kind: source.kind,
                    label: source.label,
                    batchID: source.batchID,
                    locator: HavenValue.string(object["sourceIdentifier"]),
                    importedAt: source.importedAt
                )
            ],
            entityRef: HavenValue.string(object["entityRef"]),
            confidence: min(1.0, confidence),
            createdAt: now,
            updatedAt: now
        )
    }

    private static func emptySearch() -> Object {
        [
            "schema": .string("haven.relations.search.v1"),
            "status": .string("idle"),
            "query": .string(""),
            "matchCount": .integer(0),
            "matches": .list([]),
            "needsClarification": .bool(false),
            "clarifyingQuestion": .string(""),
            "summaryText": .string("Ingen søk kjørt ennå."),
            "sideEffect": .bool(false)
        ]
    }

    // MARK: - Discovery

    private func providerDescriptor() -> Object {
        [
            "id": .string("binding.relations"),
            "providerID": .string("binding.relations"),
            "kind": .string("relations_store"),
            "title": .string("Relasjoner"),
            "summary": .string("Menneskene jeg kjenner, hvordan jeg når dem, og hvem som ennå ikke er i HAVEN."),
            "endpoint": .string(Self.endpoint),
            "sourceCellName": .string(Self.sourceCellName),
            "actionKeypath": .string("relations.search"),
            "purposeRefs": .list([
                .string("personal.relations.lookup"),
                .string("personal.chat.assist.invite"),
                .string("purpose://invite-known-people")
            ]),
            "interests": .list([
                .string("relations"),
                .string("contacts"),
                .string("invite-person"),
                .string("contact-endpoint"),
                .string("network-growth")
            ]),
            "availability": .string("available_in_cell_scope"),
            "privacyLevel": .string("owner_entity_local"),
            "executionScope": .string("binding_local_cell"),
            "requiresUserApproval": .bool(false),
            "requiresNetwork": .bool(false),
            "canInvokeFromChat": .bool(true),
            "score": .float(0.94),
            "reason": .string("Spørsmål om hvem jeg kjenner og hvem som kan inviteres skal treffe relasjonslageret først.")
        ]
    }

    private func purposeGoal() -> Object {
        [
            "title": .string("Relasjoner"),
            "summary": .string("Finn riktig person blant relasjonene mine, si ærlig om jeg kan nå dem, og spør når flere passer."),
            "purposeRefs": .list([
                .string("personal.relations.lookup"),
                .string("personal.chat.assist.invite")
            ]),
            "interests": .list([
                .string("relations"),
                .string("contacts"),
                .string("invite-person")
            ])
        ]
    }

    // MARK: - Surface

    /// The relations surface is the whole task now — sources, review, people
    /// and invitations in one place. See `RelationsWorkbenchConfiguration.swift`.
    nonisolated static func menuConfiguration() -> CellConfiguration {
        HavenRelationsWorkbench.configuration()
    }
}

private extension HavenInviteState {
    static var allCasesText: String {
        [HavenInviteState.none, .prepared, .sent, .opened, .joined, .declined, .blocked]
            .map(\.rawValue)
            .joined(separator: ", ")
    }
}
