// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

@Suite(.serialized)
struct PersonalChatChronicleTests {
    @Test func historyPolicyIsOffByDefaultAndRequiresExplicitEscalation() throws {
        #expect(BindingPersonalChatHistoryPolicy.defaultOff.mode == .off)
        #expect(BindingPersonalChatHistoryPolicy.defaultOff.automaticCaptureEnabled == false)

        #expect(BindingPersonalChatChronicle.policy(from: [
            "mode": .string("metadata")
        ]) == nil)
        #expect(BindingPersonalChatChronicle.policy(from: [
            "mode": .string("full"),
            "confirm": .bool(true)
        ]) == nil)

        let metadata = try #require(BindingPersonalChatChronicle.policy(
            from: [
                "mode": .string("metadata"),
                "confirm": .bool(true)
            ],
            now: Date(timeIntervalSince1970: 42)
        ))
        #expect(metadata.mode == .metadata)
        #expect(metadata.updatedAtEpochMilliseconds == 42_000)
        #expect(metadata.fullContentWarningAccepted == false)

        let full = try #require(BindingPersonalChatChronicle.policy(
            from: [
                "mode": .string("full"),
                "confirm": .bool(true),
                "fullContentWarningAccepted": .bool(true)
            ],
            now: Date(timeIntervalSince1970: 43)
        ))
        #expect(full.mode == .full)
        #expect(full.fullContentWarningAccepted)

        let off = try #require(BindingPersonalChatChronicle.policy(from: [
            "mode": .string("off")
        ]))
        #expect(off.mode == .off)
    }

    @Test func chronicleIdentifiersCannotInjectKeypathSegments() {
        let identifier = BindingPersonalChatChronicle.safeIdentifier("  turn[id=other].payload  ")
        #expect(identifier == "turn-id-other-.payload")
        #expect(identifier.contains("[") == false)
        #expect(identifier.contains("]") == false)
        #expect(identifier.count <= 96)
    }

    @Test func personalChatRegistrationIsPersistentAfterInfrastructureBaseline() async throws {
        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        let resolver = CellResolver.sharedInstance
        let vault = try #require(CellBase.defaultIdentityVault)
        let requester = try #require(await vault.identity(
            for: "binding-personal-chat-registry-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        let snapshot = await resolver.resolverRegistrySnapshot(requester: requester)
        let resolve = try #require(snapshot.resolves.first { $0.name == "PersonalChatHub" })

        #expect(resolve.cellScope == .identityUnique)
        #expect(resolve.persistancy == .persistant)
        #expect(resolve.identityDomain == "private")
    }

    @Test func ownerControlsEntityChronicleCaptureAndRepeatedTurnIsIdempotent() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let previousResolver = CellBase.defaultCellResolver
        let previousVault = CellBase.defaultIdentityVault
        CellBase.debugValidateAccessForEverything = false
        defer {
            CellBase.debugValidateAccessForEverything = previousDebugAccess
            CellBase.defaultCellResolver = previousResolver
            CellBase.defaultIdentityVault = previousVault
        }

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        let resolver = CellResolver.sharedInstance
        let vault = try #require(CellBase.defaultIdentityVault)
        let owner = try #require(await vault.identity(
            for: "binding-personal-chat-chronicle-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        let chat = await BindingPersonalChatHubCell(owner: owner)

        let initialHistory = try #require(valueObject(try await chat.get(
            keypath: "chatHub.history",
            requester: owner
        )))
        #expect(valueString(initialHistory["mode"]) == "off")
        #expect(valueBool(initialHistory["automaticCaptureEnabled"]) == false)

        let analysis = try #require(valueObject(try await chat.set(
            keypath: "chatHub.assistant.analyzeDraft",
            value: .object(["text": .string("registrer en privat idé")]),
            requester: owner
        )))
        #expect(valueBool(analysis["sideEffect"]) == false)
        #expect(analysis["history"] == nil)

        let rejectedFull = try #require(valueObject(try await chat.set(
            keypath: "chatHub.history.configure",
            value: .object([
                "mode": .string("full"),
                "confirm": .bool(true)
            ]),
            requester: owner
        )))
        #expect(valueString(rejectedFull["status"]) == "confirmation_required")
        #expect(valueBool(rejectedFull["mutatesEntity"]) == false)

        let metadataConfiguration = try #require(valueObject(try await chat.set(
            keypath: "chatHub.history.configure",
            value: .object([
                "mode": .string("metadata"),
                "confirm": .bool(true)
            ]),
            requester: owner
        )))
        #expect(valueString(metadataConfiguration["status"]) == "persisted")
        let policyAcknowledgement = try #require(valueObject(metadataConfiguration["acknowledgement"]))
        #expect(valueBool(policyAcknowledgement["durableCommitReceipt"]) == false)
        #expect(valueBool(policyAcknowledgement["authorityCommitReceiptVerified"]) == true)
        #expect(valueString(policyAcknowledgement["acknowledgementKind"]) == "entity_authority_commit_receipt")
        let policyReceipt = try #require(valueObject(policyAcknowledgement["commitReceipt"]))
        #expect(valueString(policyReceipt["status"]) == "authority_committed")
        #expect(valueString(policyReceipt["replicationState"]) == "local_authority_only")
        #expect(valueBool(policyReceipt["quorumSatisfied"]) == false)
        #expect(valueBool(policyReceipt["distributedCommit"]) == false)

        let turnID = "metadata-replay-\(UUID().uuidString.lowercased())"
        var replayStatuses: [String] = []
        var replayMutations: [Bool] = []
        for _ in 0..<2 {
            let submitted = try #require(valueObject(try await chat.set(
                keypath: "chatHub.prompt.submit",
                value: .object([
                    "prompt": .string("hemmelig prompttekst som ikke skal lagres"),
                    "turnID": .string(turnID)
                ]),
                requester: owner
            )))
            replayStatuses.append(valueString(valueObject(submitted["history"])?["status"]) ?? "")
            replayMutations.append(valueBool(submitted["mutatesEntity"]) ?? false)
        }
        #expect(replayStatuses == ["authority_committed", "already_persisted"])
        #expect(replayMutations == [true, false])

        let entityAnchor = try #require(try await resolver.cellAtEndpoint(
            endpoint: "cell:///EntityAnchor",
            requester: owner
        ) as? Meddle)
        let metadataRecordID = "personal-chat-turn-\(turnID)"
        let chronicle = try #require(valueList(try await entityAnchor.get(
            keypath: "chronicle",
            requester: owner
        )))
        let matchingRecords = chronicle.compactMap(valueObject).filter {
            valueString($0["id"]) == metadataRecordID
        }
        #expect(matchingRecords.count == 1)
        let metadataRecord = try #require(matchingRecords.first)
        #expect(valueString(metadataRecord["contentMode"]) == "metadata")
        #expect(valueString(metadataRecord["recordedAtSource"]) == "entity_authority_commit_receipt")
        #expect(valueBool(metadataRecord["promptStored"]) == false)
        #expect(valueString(metadataRecord["contentFingerprint"])?.count == 64)
        #expect(metadataRecord["prompt"] == nil)
        #expect(metadataRecord["assistantText"] == nil)

        let fullConfiguration = try #require(valueObject(try await chat.set(
            keypath: "chatHub.history.configure",
            value: .object([
                "mode": .string("full"),
                "confirm": .bool(true),
                "fullContentWarningAccepted": .bool(true)
            ]),
            requester: owner
        )))
        #expect(valueString(fullConfiguration["status"]) == "persisted")

        let fullTurnID = "full-\(UUID().uuidString.lowercased())"
        _ = try await chat.set(
            keypath: "chatHub.prompt.submit",
            value: .object([
                "prompt": .string("fulltekst valgt av eieren"),
                "turnID": .string(fullTurnID)
            ]),
            requester: owner
        )
        let updatedChronicle = try #require(valueList(try await entityAnchor.get(
            keypath: "chronicle",
            requester: owner
        )))
        let fullRecord = try #require(updatedChronicle.compactMap(valueObject).first {
            valueString($0["id"]) == "personal-chat-turn-\(fullTurnID)"
        })
        #expect(valueString(fullRecord["contentMode"]) == "full")
        #expect(valueString(fullRecord["prompt"]) == "fulltekst valgt av eieren")

        let conflictingReplay = try #require(valueObject(try await chat.set(
            keypath: "chatHub.prompt.submit",
            value: .object([
                "prompt": .string("annet innhold med samme turn-id"),
                "turnID": .string(fullTurnID)
            ]),
            requester: owner
        )))
        #expect(valueString(valueObject(conflictingReplay["history"])?["status"]) == "failed")
        #expect(valueBool(conflictingReplay["mutatesEntity"]) == false)
        let chronicleAfterConflict = try #require(valueList(try await entityAnchor.get(
            keypath: "chronicle",
            requester: owner
        )))
        let preservedFullRecord = try #require(chronicleAfterConflict.compactMap(valueObject).first {
            valueString($0["id"]) == "personal-chat-turn-\(fullTurnID)"
        })
        #expect(valueString(preservedFullRecord["prompt"]) == "fulltekst valgt av eieren")

        let encoded = try JSONEncoder().encode(chat)
        let decoded = try JSONDecoder().decode(BindingPersonalChatHubCell.self, from: encoded)
        let reloadedHistory = try #require(valueObject(try await decoded.get(
            keypath: "chatHub.history",
            requester: owner
        )))
        #expect(valueString(reloadedHistory["mode"]) == "full")

        let disabled = try #require(valueObject(try await chat.set(
            keypath: "chatHub.history.configure",
            value: .object(["mode": .string("off")]),
            requester: owner
        )))
        #expect(valueString(disabled["status"]) == "persisted")
        let localClear = try #require(valueObject(try await chat.set(
            keypath: "chatHub.history.clearLocal",
            value: .object([:]),
            requester: owner
        )))
        #expect(valueString(localClear["status"]) == "local_history_cleared")
        #expect(valueBool(localClear["mutatesEntity"]) == false)
    }

    @Test func personalCopilotSkeletonExposesOwnerControlledChronicleModes() throws {
        let configuration = ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        let json = String(data: try JSONEncoder().encode(configuration), encoding: .utf8) ?? ""

        #expect(json.contains("chatHub.state.history.summary"))
        #expect(json.contains("chatHub.history.configure"))
        #expect(json.contains("Chronicle av"))
        #expect(json.contains("Lagre metadata"))
        #expect(json.contains("Lagre fulltekst"))
        #expect(json.contains("fullContentWarningAccepted"))
        #expect(json.contains("chatHub.history.clearLocal"))
    }
}

private func valueObject(_ value: ValueType?) -> Object? {
    guard case let .object(object)? = value else { return nil }
    return object
}

private func valueList(_ value: ValueType?) -> ValueTypeList? {
    guard case let .list(list)? = value else { return nil }
    return list
}

private func valueString(_ value: ValueType?) -> String? {
    guard case let .string(string)? = value else { return nil }
    return string
}

private func valueBool(_ value: ValueType?) -> Bool? {
    guard case let .bool(bool)? = value else { return nil }
    return bool
}
