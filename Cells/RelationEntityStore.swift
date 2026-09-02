// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  RelationEntityStore.swift
//  Binding
//
//  The relation records in `BindingRelationsCell` are the working copy on this
//  device. The entity — `relations.records.<id>` below the EntityAnchor, with
//  interaction events in the chronicle — is where a relation *lives*, so it is
//  there when the owner picks up another surface. This file is the bridge:
//  the mapping from the device record to the entity record, and the
//  owner-signed authority writes that put it there.
//

import Foundation
import CryptoKit
import CellBase

// MARK: - Mapping

nonisolated enum HavenRelationEntityMapper {

    /// Builds the entity record for a device record, carrying forward what
    /// only the entity knows: evidence, the interaction summary, standing
    /// that outranks the device (verified), channels the device never saw
    /// (a correspondence peer), and the revision counter.
    static func entityRecord(
        from record: HavenRelationRecord,
        existing: EntityRelationRecord?,
        perspectiveRef: String?,
        now: Date = Date()
    ) -> EntityRelationRecord {
        let declared = record.contextTags.filter { !$0.hasPrefix(BindingRelationsCell.inferredTagPrefix) }
        let inferred = record.contextTags
            .filter { $0.hasPrefix(BindingRelationsCell.inferredTagPrefix) }
            .map { String($0.dropFirst(BindingRelationsCell.inferredTagPrefix.count)) }

        var channels: [EntityRelationChannel] = record.endpoints.compactMap { endpoint in
            guard let kind = channelKind(for: endpoint.kind) else { return nil }
            let previous = existing?.channels.first { $0.ref == endpoint.disclosureToken }
            return EntityRelationChannel(
                kind: kind,
                ref: endpoint.disclosureToken,
                label: endpoint.label,
                confirmed: endpoint.confirmed || (previous?.confirmed ?? false),
                preferred: previous?.preferred ?? false,
                lastUsedAt: previous?.lastUsedAt
            )
        }
        if let entityRef = record.entityRef, !entityRef.isEmpty {
            let previous = existing?.channels.first { $0.kind == .havenChat }
            channels.append(EntityRelationChannel(
                kind: .havenChat,
                ref: entityRef,
                confirmed: true,
                preferred: previous?.preferred ?? false,
                lastUsedAt: previous?.lastUsedAt
            ))
        }
        // Channels only the entity knows about survive a resync.
        for channel in existing?.channels ?? [] where !channels.contains(where: { $0.ref == channel.ref }) {
            if channel.kind == .havenCorrespondence || channel.kind == .nearby || channel.kind == .conference {
                channels.append(channel)
            }
        }

        var standing = existing?.standing ?? EntityRelationStanding()
        standing.inviteState = record.inviteState.rawValue
        standing.lastInviteAt = record.lastInviteAt ?? standing.lastInviteAt
        standing.lastInviteTicketID = record.lastInviteTicketID ?? standing.lastInviteTicketID
        standing.trust = trust(for: record, previous: existing?.standing.trust)
        if standing.trust == .joined || standing.trust == .verified {
            standing.joinedAt = standing.joinedAt ?? record.updatedAt
        }

        let subject = EntityRelationSubject(
            displayName: record.displayName,
            givenName: record.givenName,
            familyName: record.familyName,
            organization: record.organization,
            jobTitle: record.jobTitle,
            entityRef: record.entityRef,
            perspectiveRef: perspectiveRef ?? existing?.subject.perspectiveRef,
            validatedContactRef: existing?.subject.validatedContactRef
        )

        return EntityRelationRecord(
            relationID: record.id,
            subject: subject,
            origin: existing?.origin ?? origin(for: record),
            roles: record.roles.map { EntityRelationRole(context: $0.context, role: $0.role, group: $0.group) },
            interests: EntityRelationInterests(declared: declared, inferred: inferred),
            purposeRefs: record.purposeRefs,
            channels: channels,
            standing: standing,
            evidence: existing?.evidence ?? [],
            interactions: existing?.interactions ?? EntityRelationInteractionSummary(),
            tags: record.contextTags,
            notes: record.notes,
            createdAt: existing?.createdAt ?? record.createdAt,
            updatedAt: now,
            revision: (existing?.revision ?? 0) + 1
        )
    }

    /// The earliest source is where the tie came from; later ones are
    /// confirmations. The context is the first role's context, which is the
    /// list the person arrived on.
    static func origin(for record: HavenRelationRecord) -> EntityRelationOrigin {
        let first = record.sources.min { $0.importedAt < $1.importedAt }
        return EntityRelationOrigin(
            kind: originKind(for: first?.kind ?? .manual),
            at: first?.importedAt ?? record.createdAt,
            sourceLabel: first?.label ?? "manuelt",
            batchID: first?.batchID,
            locator: first?.locator,
            context: record.roles.first?.context
        )
    }

    static func originKind(for kind: HavenRelationSourceKind) -> EntityRelationOriginKind {
        switch kind {
        case .addressBookPicker, .addressBookScan: return .addressBook
        case .fileImport: return .fileImport
        case .manual: return .manual
        case .nearby: return .nearby
        case .inboundInvite: return .inviteReceived
        }
    }

    static func channelKind(for kind: HavenEndpointKind) -> EntityRelationChannelKind? {
        switch kind {
        case .email: return .email
        case .phone: return .sms
        case .url: return .web
        case .handle, .postal, .other: return nil
        }
    }

    /// Device state decides invited/joined/blocked. `verified` is evidence the
    /// entity holds and the device cannot take away — except by blocking.
    static func trust(for record: HavenRelationRecord, previous: EntityRelationTrust?) -> EntityRelationTrust {
        switch record.inviteState {
        case .blocked: return .blocked
        case .joined: return previous == .verified ? .verified : .joined
        case .prepared, .sent, .opened: return previous == .verified ? .verified : .invited
        case .none, .declined:
            if record.entityRef?.isEmpty == false { return previous == .verified ? .verified : .joined }
            return previous == .verified ? .verified : .none
        }
    }
}

// MARK: - Store

struct BindingRelationInteractionOutcome: Equatable {
    var status: String
    var chronicleRef: String?
    var record: EntityRelationRecord?
    var message: String
}

enum BindingRelationEntityStoreError: Error, LocalizedError {
    case noEntityAnchor
    case unknownRelation(String)
    case policyOff

    var errorDescription: String? {
        switch self {
        case .noEntityAnchor: return "Entitetsankeret er ikke tilgjengelig."
        case .unknownRelation(let id): return "Entiteten har ingen relasjon med id \(id)."
        case .policyOff: return "Interaksjonslogging er slått av."
        }
    }
}

/// Owner-signed reads and writes of relation records and interaction events.
/// Every write goes through the entity authority journal, so a retry with the
/// same mutation id is a no-op and a surface can verify the receipt.
nonisolated enum BindingRelationEntityStore {
    static let sourceCell = "BindingRelationsCell"
    static let purposeRef = "purpose://contact.communication"

    // MARK: Policy

    static func interactionPolicy(requester: Identity) async -> EntityRelationInteractionPolicyMode {
        guard let anchor = try? await BindingPersonalChatChronicle.entityAnchor(requester: requester),
              let meddle = anchor as? Meddle,
              let value = try? await meddle.get(keypath: EntityRelationRecordV1.interactionPolicyKeypath, requester: requester),
              case let .object(object) = value,
              case let .string(raw)? = object["mode"],
              let mode = EntityRelationInteractionPolicyMode(rawValue: raw) else {
            return EntityRelationRecordV1.defaultInteractionPolicy
        }
        return mode
    }

    static func setInteractionPolicy(
        _ mode: EntityRelationInteractionPolicyMode,
        fullContentAccepted: Bool,
        requester: Identity,
        sourceUUID: String
    ) async throws {
        let now = Date()
        let envelope = EntityBatchPersistEnvelope(
            schema: "haven.relation-interaction-policy.v1",
            mutations: [
                EntityBatchPersistMutation(
                    keypath: EntityRelationRecordV1.interactionPolicyKeypath,
                    value: .object([
                        "mode": .string(mode.rawValue),
                        "updatedAt": .string(HavenValue.iso(now)),
                        "fullContentWarningAccepted": .bool(mode == .full && fullContentAccepted)
                    ])
                )
            ],
            metadata: [
                "sourceCell": .string(sourceCell),
                "purposeRef": .string("purpose://preference.owner-controlled"),
                "ownerControlled": .bool(true)
            ]
        )
        _ = try await BindingPersonalChatChronicle.persist(
            envelope: envelope,
            mutationID: "relation-interaction-policy-\(Int(now.timeIntervalSince1970 * 1_000))-\(mode.rawValue)",
            purposeRef: "purpose://preference.owner-controlled",
            requester: requester,
            sourceUUID: sourceUUID,
            title: "relation_interaction_policy_updated",
            topic: "relation-interaction-policy"
        )
    }

    // MARK: Records

    static func loadRecords(requester: Identity) async throws -> [String: EntityRelationRecord] {
        guard let anchor = try? await BindingPersonalChatChronicle.entityAnchor(requester: requester),
              let meddle = anchor as? Meddle else {
            throw BindingRelationEntityStoreError.noEntityAnchor
        }
        guard let value = try? await meddle.get(keypath: EntityRelationRecordV1.protectedRoot, requester: requester),
              case let .object(object) = value else {
            return [:]
        }
        var records: [String: EntityRelationRecord] = [:]
        for (id, entry) in object {
            if let record = EntityRelationCodec.decode(EntityRelationRecord.self, from: entry) {
                records[id] = record
            }
        }
        return records
    }

    static func loadRecord(relationID: String, requester: Identity) async throws -> EntityRelationRecord? {
        guard let anchor = try? await BindingPersonalChatChronicle.entityAnchor(requester: requester),
              let meddle = anchor as? Meddle else {
            throw BindingRelationEntityStoreError.noEntityAnchor
        }
        let keypath = EntityRelationRecordV1.keypath(relationID: relationID)
        guard let value = try? await meddle.get(keypath: keypath, requester: requester) else { return nil }
        return EntityRelationCodec.decode(EntityRelationRecord.self, from: value)
    }

    /// Writes the records as one authority commit. The mutation id is a hash
    /// of what is being written, so an identical resync replays for free.
    @discardableResult
    static func persist(
        records: [EntityRelationRecord],
        requester: Identity,
        sourceUUID: String
    ) async throws -> BindingEntityAuthorityPersistResult {
        var mutations: [EntityBatchPersistMutation] = []
        for record in records.sorted(by: { $0.relationID < $1.relationID }) {
            try EntityRelationRecordV1.validate(record)
            mutations.append(EntityBatchPersistMutation(
                keypath: EntityRelationRecordV1.keypath(relationID: record.relationID),
                value: EntityRelationCodec.value(record)
            ))
        }
        let envelope = EntityBatchPersistEnvelope(
            schema: EntityRelationRecordV1.envelopeSchema,
            mutations: mutations,
            metadata: [
                "sourceCell": .string(sourceCell),
                "purposeRef": .string(purposeRef),
                "ownerControlled": .bool(true),
                "recordCount": .integer(records.count)
            ]
        )
        let fingerprint = records
            .sorted { $0.relationID < $1.relationID }
            .map { "\($0.relationID):\($0.revision)" }
            .joined(separator: "|")
        return try await BindingPersonalChatChronicle.persist(
            envelope: envelope,
            mutationID: "relation-sync-" + sha256Hex(fingerprint).prefix(24),
            purposeRef: purposeRef,
            requester: requester,
            sourceUUID: sourceUUID,
            title: "relation_records_sync",
            topic: "relation-records"
        )
    }

    static func remove(relationIDs: [String], requester: Identity, sourceUUID: String) async throws {
        guard !relationIDs.isEmpty else { return }
        let envelope = EntityBatchPersistEnvelope(
            schema: EntityRelationRecordV1.envelopeSchema,
            mutations: relationIDs.map {
                EntityBatchPersistMutation(keypath: EntityRelationRecordV1.keypath(relationID: $0), value: .null)
            },
            metadata: [
                "sourceCell": .string(sourceCell),
                "purposeRef": .string(purposeRef),
                "ownerControlled": .bool(true),
                "dataAction": .string("forget")
            ]
        )
        _ = try await BindingPersonalChatChronicle.persist(
            envelope: envelope,
            mutationID: "relation-forget-" + sha256Hex(relationIDs.sorted().joined(separator: "|")).prefix(24),
            purposeRef: purposeRef,
            requester: requester,
            sourceUUID: sourceUUID,
            title: "relation_records_forget",
            topic: "relation-records"
        )
    }

    // MARK: Interactions

    /// Records that something happened between me and a relation: the event
    /// goes into the chronicle and the relation's summary moves, in one
    /// commit. Under `off` nothing is written and the caller is told so.
    static func recordInteraction(
        _ event: EntityRelationInteractionEvent,
        fallbackRecord: EntityRelationRecord?,
        requester: Identity,
        sourceUUID: String
    ) async throws -> BindingRelationInteractionOutcome {
        let policy = await interactionPolicy(requester: requester)
        guard policy != .off else {
            return BindingRelationInteractionOutcome(
                status: "off", chronicleRef: nil, record: nil,
                message: "Interaksjonslogging er av. Ingenting ble skrevet."
            )
        }
        var event = event
        if policy == .metadata, event.contentMode == .full {
            // The policy outranks the caller. Rebuild so the summary is gone.
            event = EntityRelationInteractionEvent(
                id: event.id, relationID: event.relationID, kind: event.kind, at: event.at,
                channel: event.channel, direction: event.direction, contentMode: .metadata,
                evidenceID: event.evidenceID, purposeRef: event.purposeRef, sourceCell: event.sourceCell
            )
        }
        try EntityRelationRecordV1.validate(event)

        guard let current = try await loadRecord(relationID: event.relationID, requester: requester) ?? fallbackRecord else {
            throw BindingRelationEntityStoreError.unknownRelation(event.relationID)
        }
        let chronicleKeypath = EntityRelationRecordV1.chronicleKeypath(relationID: event.relationID, eventID: event.id)
        let updated = current.applying(event, chronicleRef: chronicleKeypath)
        try EntityRelationRecordV1.validate(updated)

        let envelope = EntityBatchPersistEnvelope(
            schema: EntityRelationRecordV1.envelopeSchema,
            mutations: [
                EntityBatchPersistMutation(keypath: chronicleKeypath, value: EntityRelationCodec.value(event)),
                EntityBatchPersistMutation(
                    keypath: EntityRelationRecordV1.keypath(relationID: updated.relationID),
                    value: EntityRelationCodec.value(updated)
                )
            ],
            metadata: [
                "sourceCell": .string(event.sourceCell),
                "purposeRef": .string(event.purposeRef),
                "ownerControlled": .bool(true),
                "contentMode": .string(event.contentMode.rawValue),
                "relationID": .string(event.relationID),
                "eventID": .string(event.id)
            ]
        )
        let result = try await BindingPersonalChatChronicle.persist(
            envelope: envelope,
            mutationID: EntityRelationRecordV1.chronicleID(relationID: event.relationID, eventID: event.id),
            purposeRef: event.purposeRef,
            requester: requester,
            sourceUUID: sourceUUID,
            title: "relation_interaction_recorded",
            topic: "relation-interactions"
        )
        return BindingRelationInteractionOutcome(
            status: result.idempotentReplay ? "already_recorded" : "recorded",
            chronicleRef: chronicleKeypath,
            record: updated,
            message: result.idempotentReplay
                ? "Hendelsen var allerede loggført; ingenting nytt ble skrevet."
                : policy == .full
                    ? "Hendelsen ble loggført med sammendrag i din private Chronicle."
                    : "Hendelsen ble loggført som metadata — at, når og hvordan, ikke hva."
        )
    }

    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
