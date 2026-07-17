// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase
import CryptoKit
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif

enum BindingPersonalChatHistoryMode: String, Codable, CaseIterable {
    case off
    case metadata
    case full
}

struct BindingPersonalChatHistoryPolicy: Codable, Equatable {
    static let schema = "binding.personal-chat-history-policy.v1"

    var mode: BindingPersonalChatHistoryMode
    var updatedAtEpochMilliseconds: Int
    var fullContentWarningAccepted: Bool

    static let defaultOff = BindingPersonalChatHistoryPolicy(
        mode: .off,
        updatedAtEpochMilliseconds: 0,
        fullContentWarningAccepted: false
    )

    var automaticCaptureEnabled: Bool {
        mode != .off
    }

    var summary: String {
        switch mode {
        case .off:
            return "Samtaler lagres ikke i Entity Chronicle. Lokal promptlogg kan tømmes separat."
        case .metadata:
            return "Nye, eksplisitt sendte prompts lagres som private metadata i Entity Chronicle uten prompt- eller svartekst."
        case .full:
            return "Nye, eksplisitt sendte prompts lagres med prompt- og svartekst i privat Entity Chronicle."
        }
    }

    var objectValue: Object {
        [
            "schema": .string(Self.schema),
            "mode": .string(mode.rawValue),
            "automaticCaptureEnabled": .bool(automaticCaptureEnabled),
            "fullContentWarningAccepted": .bool(fullContentWarningAccepted),
            "updatedAtEpochMilliseconds": .integer(updatedAtEpochMilliseconds),
            "ownerControlled": .bool(true),
            "existingEntriesRemainUntilSeparateErase": .bool(true),
            "automaticDeletionImplemented": .bool(false),
            "summary": .string(summary)
        ]
    }

    init(
        mode: BindingPersonalChatHistoryMode,
        updatedAtEpochMilliseconds: Int,
        fullContentWarningAccepted: Bool
    ) {
        self.mode = mode
        self.updatedAtEpochMilliseconds = updatedAtEpochMilliseconds
        self.fullContentWarningAccepted = fullContentWarningAccepted
    }

    init?(object: Object) {
        guard case let .string(rawMode)? = object["mode"],
              let mode = BindingPersonalChatHistoryMode(rawValue: rawMode) else {
            return nil
        }
        let updatedAt: Int
        if case let .integer(value)? = object["updatedAtEpochMilliseconds"] {
            updatedAt = value
        } else {
            updatedAt = 0
        }
        let warningAccepted: Bool
        if case let .bool(value)? = object["fullContentWarningAccepted"] {
            warningAccepted = value
        } else {
            warningAccepted = false
        }
        guard mode != .full || warningAccepted else {
            return nil
        }
        self.init(
            mode: mode,
            updatedAtEpochMilliseconds: updatedAt,
            fullContentWarningAccepted: warningAccepted
        )
    }
}

struct BindingPersonalChatChronicleAcknowledgement: Equatable {
    var status: String
    var recordID: String?
    var persistedPaths: [String]
    var message: String
    var idempotentReplay: Bool = false
    var commitReceipt: EntityAuthorityCommitReceipt? = nil

    var objectValue: Object {
        var object: Object = [
            "status": .string(status),
            "recordID": recordID.map(ValueType.string) ?? .null,
            "persistedPaths": .list(persistedPaths.map(ValueType.string)),
            "message": .string(message),
            "idempotentReplay": .bool(idempotentReplay),
            "authorityCommitReceiptVerified": .bool(commitReceipt != nil),
            "durableCommitReceipt": .bool(
                commitReceipt?.distributedCommit == true
                    && commitReceipt?.quorumSatisfied == true
            ),
            "acknowledgementKind": .string(
                commitReceipt == nil
                    ? "no_entity_authority_commit_receipt"
                    : "entity_authority_commit_receipt"
            )
        ]
        if let commitReceipt,
           let receiptValue = try? commitReceipt.valueType() {
            object["commitReceipt"] = receiptValue
        }
        return object
    }
}

enum BindingPersonalChatChronicleError: Error, LocalizedError {
    case noResolver
    case noEntityAnchor
    case connectionDenied
    case timedOut(String)
    case persistenceFailed(String)
    case authorityReceiptInvalid(String)
    case staleAuthorityState
    case idempotencyConflict(String)

    var errorDescription: String? {
        switch self {
        case .noResolver:
            return "CellResolver er ikke tilgjengelig."
        case .noEntityAnchor:
            return "EntityAnchor er ikke tilgjengelig for eieren."
        case .connectionDenied:
            return "EntityAnchor avviste den eierautoriserte persistensforbindelsen."
        case let .timedOut(correlationID):
            return "EntityAnchor svarte ikke innen fristen for \(correlationID)."
        case let .persistenceFailed(message):
            return "EntityAnchor kunne ikke lagre historikken: \(message)"
        case let .authorityReceiptInvalid(message):
            return "EntityAnchor svarte uten en gyldig authority-kvittering: \(message)"
        case .staleAuthorityState:
            return "EntityAnchor endret revisjon mens historikken ble lagret."
        case let .idempotencyConflict(recordID):
            return "Chronicle har allerede posten \(recordID) med annet innhold. Skrivingen ble stoppet for å bevare historikken."
        }
    }
}

enum BindingPersonalChatChronicle {
    static let policyKeypath = "person.copilot.chatHistoryPolicy"
    static let chronicleRecordSchema = "binding.personal-chat-chronicle-turn.v1"
    static let policyEnvelopeSchema = "binding.personal-chat-history-policy.updated.v1"
    static let turnEnvelopeSchema = "binding.personal-chat-history-turn.persisted.v1"

    static func policy(
        from payload: Object,
        now: Date = Date()
    ) -> BindingPersonalChatHistoryPolicy? {
        let rawMode: String
        if case let .string(value)? = payload["mode"] {
            rawMode = value
        } else if case let .bool(enabled)? = payload["enabled"] {
            rawMode = enabled ? BindingPersonalChatHistoryMode.metadata.rawValue : BindingPersonalChatHistoryMode.off.rawValue
        } else {
            return nil
        }
        guard let mode = BindingPersonalChatHistoryMode(rawValue: rawMode) else {
            return nil
        }
        let confirmation: Bool
        if case let .bool(value)? = payload["confirm"] {
            confirmation = value
        } else {
            confirmation = false
        }
        guard mode == .off || confirmation else {
            return nil
        }
        let fullWarningAccepted: Bool
        if case let .bool(value)? = payload["fullContentWarningAccepted"] {
            fullWarningAccepted = value
        } else {
            fullWarningAccepted = false
        }
        guard mode != .full || fullWarningAccepted else {
            return nil
        }
        return BindingPersonalChatHistoryPolicy(
            mode: mode,
            updatedAtEpochMilliseconds: Int(now.timeIntervalSince1970 * 1_000),
            fullContentWarningAccepted: mode == .full && fullWarningAccepted
        )
    }

    static func loadPolicy(requester: Identity) async throws -> BindingPersonalChatHistoryPolicy? {
        let entityAnchor = try await entityAnchor(requester: requester)
        guard let meddle = entityAnchor as? Meddle else {
            throw BindingPersonalChatChronicleError.noEntityAnchor
        }
        let value = try await meddle.get(keypath: policyKeypath, requester: requester)
        guard case let .object(object) = value else {
            return nil
        }
        return BindingPersonalChatHistoryPolicy(object: object)
    }

    static func persistPolicy(
        _ policy: BindingPersonalChatHistoryPolicy,
        requester: Identity,
        sourceUUID: String
    ) async throws -> BindingPersonalChatChronicleAcknowledgement {
        let envelope = EntityBatchPersistEnvelope(
            schema: policyEnvelopeSchema,
            mutations: [
                EntityBatchPersistMutation(
                    keypath: policyKeypath,
                    value: .object(policy.objectValue)
                )
            ],
            metadata: [
                "sourceCell": .string("BindingPersonalChatHubCell"),
                "purposeRef": .string("purpose://preference.owner-controlled"),
                "ownerControlled": .bool(true),
                "storagePermission": .string("rw-s")
            ]
        )
        let result = try await persist(
            envelope: envelope,
            mutationID: "personal-chat-history-policy-\(policy.updatedAtEpochMilliseconds)",
            purposeRef: "purpose://preference.owner-controlled",
            requester: requester,
            sourceUUID: sourceUUID,
            title: "personal_chat_history_policy_updated",
            topic: "personal-chat-history-policy"
        )
        return BindingPersonalChatChronicleAcknowledgement(
            status: "authority_committed",
            recordID: nil,
            persistedPaths: result.persistedPaths,
            message: policy.summary,
            idempotentReplay: result.idempotentReplay,
            commitReceipt: result.receipt
        )
    }

    static func persistTurn(
        turnID requestedTurnID: String?,
        threadID: String,
        prompt: String,
        assistantText: String,
        purposeRef: String,
        helperID: String,
        policy: BindingPersonalChatHistoryPolicy,
        requester: Identity,
        sourceUUID: String
    ) async throws -> BindingPersonalChatChronicleAcknowledgement {
        guard policy.automaticCaptureEnabled else {
            return BindingPersonalChatChronicleAcknowledgement(
                status: "off",
                recordID: nil,
                persistedPaths: [],
                message: policy.summary
            )
        }

        let turnID = safeIdentifier(requestedTurnID)
        let recordID = "personal-chat-turn-\(turnID)"
        let recordPath = "chronicle[id=\(recordID)]"
        var record: Object = [
            "id": .string(recordID),
            "schema": .string(chronicleRecordSchema),
            "kind": .string("personal_chat_turn"),
            "sourceCell": .string("BindingPersonalChatHubCell"),
            "sourceCellEndpoint": .string("cell:///PersonalChatHub"),
            "threadID": .string(threadID),
            "turnID": .string(turnID),
            "recordedAtSource": .string("entity_authority_commit_receipt"),
            "purposeRef": .string(purposeRef.isEmpty ? "purpose://prompt.unknown" : purposeRef),
            "helperID": helperID.isEmpty ? .null : .string(helperID),
            "contentMode": .string(policy.mode.rawValue),
            "ownerControlled": .bool(true),
            "sensitivity": .string("private"),
            "storagePermission": .string("rw-s"),
            "automaticDeletionImplemented": .bool(false)
        ]
        if policy.mode == .full {
            record["prompt"] = .string(prompt)
            record["assistantText"] = .string(assistantText)
        } else {
            record["promptStored"] = .bool(false)
            record["assistantTextStored"] = .bool(false)
        }

        let contentFingerprint = turnContentFingerprint(
            turnID: turnID,
            threadID: threadID,
            purposeRef: purposeRef,
            helperID: helperID,
            policy: policy,
            prompt: prompt,
            assistantText: assistantText
        )
        record["contentFingerprint"] = .string(contentFingerprint)

        let envelope = EntityBatchPersistEnvelope(
            schema: turnEnvelopeSchema,
            mutations: [
                EntityBatchPersistMutation(keypath: recordPath, value: .object(record))
            ],
            metadata: [
                "mutationID": .string(recordID),
                "turnID": .string(turnID),
                "threadID": .string(threadID),
                "sourceCell": .string("BindingPersonalChatHubCell"),
                "purposeRef": .string(purposeRef.isEmpty ? "purpose://prompt.unknown" : purposeRef),
                "ownerControlled": .bool(true)
            ]
        )
        let result = try await persist(
            envelope: envelope,
            mutationID: recordID,
            purposeRef: purposeRef.isEmpty ? "purpose://prompt.unknown" : purposeRef,
            requester: requester,
            sourceUUID: sourceUUID,
            title: "personal_chat_turn_chronicle_persist",
            topic: "personal-chat-chronicle"
        )
        return BindingPersonalChatChronicleAcknowledgement(
            status: result.idempotentReplay ? "already_persisted" : "authority_committed",
            recordID: recordID,
            persistedPaths: result.persistedPaths,
            message: result.idempotentReplay
                ? "Samtaleturnen var allerede authority-committed med samme innhold; ingen ny Entity-mutasjon ble gjort."
                : policy.mode == .full
                    ? "Samtaleturnen ble authority-committed med tekst i din private Entity Chronicle."
                    : "Samtaleturnen ble authority-committed som metadata i din private Entity Chronicle.",
            idempotentReplay: result.idempotentReplay,
            commitReceipt: result.receipt
        )
    }

    private static func turnContentFingerprint(
        turnID: String,
        threadID: String,
        purposeRef: String,
        helperID: String,
        policy: BindingPersonalChatHistoryPolicy,
        prompt: String,
        assistantText: String
    ) -> String {
        var fields = [
            chronicleRecordSchema,
            turnID,
            threadID,
            purposeRef.isEmpty ? "purpose://prompt.unknown" : purposeRef,
            helperID,
            policy.mode.rawValue
        ]
        if policy.mode == .full {
            fields.append(prompt)
            fields.append(assistantText)
        }
        let canonical = fields.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func safeIdentifier(_ candidate: String?) -> String {
        let trimmed = candidate?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(96) ?? Substring()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let normalized = String(trimmed.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(String(scalar)) : "-"
        })
        let collapsed = normalized
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? UUID().uuidString.lowercased() : collapsed
    }

    private static func entityAnchor(requester: Identity) async throws -> Emit {
        guard let resolver = CellBase.defaultCellResolver else {
            throw BindingPersonalChatChronicleError.noResolver
        }
        do {
            return try await resolver.cellAtEndpoint(
                endpoint: "cell:///EntityAnchor",
                requester: requester
            )
        } catch {
            throw BindingPersonalChatChronicleError.noEntityAnchor
        }
    }

    private static func persist(
        envelope: EntityBatchPersistEnvelope,
        mutationID: String,
        purposeRef: String,
        requester: Identity,
        sourceUUID: String,
        title: String,
        topic: String
    ) async throws -> BindingEntityAuthorityPersistResult {
        let entityAnchor = try await entityAnchor(requester: requester)
        guard let absorber = entityAnchor as? Absorb,
              let meddle = entityAnchor as? Meddle else {
            throw BindingPersonalChatChronicleError.noEntityAnchor
        }

        for attempt in 0..<3 {
            let stateValue = try await meddle.get(keypath: "entityAuthority", requester: requester)
            let state: EntityAuthorityCommitState
            do {
                state = try EntityAuthorityCommitState(value: stateValue)
            } catch {
                throw BindingPersonalChatChronicleError.persistenceFailed(
                    "Entity authority-state kunne ikke dekodes: \(error.localizedDescription)"
                )
            }

            var signedEnvelope = envelope
            signedEnvelope.commitRequest = try await EntityAuthorityCommitRequest.signed(
                envelope: envelope,
                mutationID: mutationID,
                partitionID: state.partitionID,
                epoch: state.epoch,
                expectedRevision: state.revision,
                expectedPreviousHash: state.headHash,
                requester: requester,
                purposeRef: purposeRef,
                faultPolicyID: state.faultPolicyID,
                requiredReplicaAcks: 0
            )

            do {
                let result = try await sendAuthorityEnvelope(
                    signedEnvelope,
                    mutationID: mutationID,
                    requester: requester,
                    sourceUUID: sourceUUID,
                    title: title,
                    topic: topic,
                    entityAnchor: entityAnchor,
                    absorber: absorber
                )
                guard result.receipt.verifies(with: requester),
                      result.receipt.mutationID == mutationID,
                      result.receipt.payloadHash == (try envelope.authorityPayloadHash()) else {
                    throw BindingPersonalChatChronicleError.authorityReceiptInvalid(mutationID)
                }
                return result
            } catch BindingPersonalChatChronicleError.staleAuthorityState where attempt < 2 {
                continue
            }
        }
        throw BindingPersonalChatChronicleError.staleAuthorityState
    }

    private static func sendAuthorityEnvelope(
        _ envelope: EntityBatchPersistEnvelope,
        mutationID: String,
        requester: Identity,
        sourceUUID: String,
        title: String,
        topic: String,
        entityAnchor: Emit,
        absorber: Absorb
    ) async throws -> BindingEntityAuthorityPersistResult {
        let acknowledgementPublisher = try await entityAnchor.flow(requester: requester)
        let pusher = FlowElementPusherCell(owner: requester)
        let correlationID = "binding-personal-chat-entity-write-\(UUID().uuidString)"
        let label = "push-\(correlationID)"
        let connectState = try await absorber.attach(emitter: pusher, label: label, requester: requester)
        guard connectState == .connected else {
            throw BindingPersonalChatChronicleError.connectionDenied
        }
        defer { absorber.detach(label: label, requester: requester) }
        try await absorber.absorbFlow(label: label, requester: requester)
        return try await awaitAcknowledgement(
            correlationID: correlationID,
            mutationID: mutationID,
            publisher: acknowledgementPublisher
        ) {
            var flowElement = FlowElement(
                title: title,
                content: .object([
                    "correlationId": .string(correlationID),
                    "operation": .string(EntityBatchPersistEnvelope.operation),
                    "envelope": .object(envelope.objectValue())
                ]),
                properties: FlowElement.Properties(type: .event, contentType: .object)
            )
            flowElement.topic = topic
            flowElement.origin = sourceUUID
            pusher.pushFlowElement(flowElement, requester: requester)
            pusher.pushCompletion(error: nil, requester: requester)
        }
    }

    private static func awaitAcknowledgement(
        correlationID: String,
        mutationID: String,
        publisher: AnyPublisher<FlowElement, Error>,
        send: @escaping () -> Void
    ) async throws -> BindingEntityAuthorityPersistResult {
        let lock = NSLock()
        var didResume = false
        var acknowledgementCancellable: AnyCancellable?

        defer {
            acknowledgementCancellable?.cancel()
        }

        return try await withCheckedThrowingContinuation { continuation in
            func resumeOnce(_ result: Result<BindingEntityAuthorityPersistResult, Error>) {
                lock.lock()
                guard didResume == false else {
                    lock.unlock()
                    return
                }
                didResume = true
                lock.unlock()
                continuation.resume(with: result)
            }

            acknowledgementCancellable = publisher.sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        resumeOnce(.failure(error))
                    }
                },
                receiveValue: { flowElement in
                    guard let result = acknowledgementResult(
                        flowElement,
                        correlationID: correlationID,
                        mutationID: mutationID
                    ) else {
                        return
                    }
                    resumeOnce(result)
                }
            )

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
                resumeOnce(.failure(BindingPersonalChatChronicleError.timedOut(correlationID)))
            }
            send()
        }
    }

    private static func acknowledgementResult(
        _ flowElement: FlowElement,
        correlationID: String,
        mutationID: String
    ) -> Result<BindingEntityAuthorityPersistResult, Error>? {
        guard case let .object(payload) = flowElement.content,
              case let .string(receivedCorrelationID)? = payload["correlationId"],
              receivedCorrelationID == correlationID else {
            return nil
        }

        if case let .string(status)? = payload["status"], status == "authority_committed" {
            let paths: [String]
            if case let .list(values)? = payload["persistedPaths"] {
                paths = values.compactMap { value in
                    guard case let .string(path) = value else { return nil }
                    return path
                }
            } else {
                paths = []
            }
            guard let receiptValue = payload["commitReceipt"],
                  let receipt = try? EntityAuthorityCommitReceipt(value: receiptValue) else {
                return .failure(
                    BindingPersonalChatChronicleError.authorityReceiptInvalid("mangler eller kan ikke dekodes")
                )
            }
            let idempotentReplay: Bool
            if case let .bool(value)? = payload["idempotentReplay"] {
                idempotentReplay = value
            } else {
                idempotentReplay = false
            }
            return .success(BindingEntityAuthorityPersistResult(
                persistedPaths: paths,
                receipt: receipt,
                idempotentReplay: idempotentReplay
            ))
        }

        if case let .string(status)? = payload["status"],
           status == "failed" || status == "conflict" {
            let message: String
            if case let .string(value)? = payload["error"] {
                message = value
            } else {
                message = "ukjent persistensfeil"
            }
            let errorCode: String?
            if case let .string(value)? = payload["errorCode"] {
                errorCode = value
            } else {
                errorCode = nil
            }
            switch errorCode {
            case "stale_epoch", "stale_revision", "stale_head_hash":
                return .failure(BindingPersonalChatChronicleError.staleAuthorityState)
            case "mutation_id_conflict":
                return .failure(BindingPersonalChatChronicleError.idempotencyConflict(mutationID))
            default:
                return .failure(BindingPersonalChatChronicleError.persistenceFailed(message))
            }
        }

        return nil
    }
}

private struct BindingEntityAuthorityPersistResult {
    var persistedPaths: [String]
    var receipt: EntityAuthorityCommitReceipt
    var idempotentReplay: Bool
}
