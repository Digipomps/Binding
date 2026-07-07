// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

@Suite(.serialized)
struct ChatWorkbenchParityTests {
    @Test func copilotChatMoreMenuCarriesOptionalHelpWithoutOwningDefaultSurface() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-help-menu")
        let chat = await BindingPersonalChatHubCell(owner: owner)

        let state = try #require(asObject(try await chat.get(keypath: "state", requester: owner)))
        let ui = try #require(asObject(state["ui"]))
        #expect(asString(ui["activeTab"]) == "samtale")
        #expect(asString(ui["activeMoreTab"]) == "verktoy")

        let moreTabs = try #require(asList(ui["moreTabs"]))
        #expect(moreTabs.contains {
            guard let tab = asObject($0) else { return false }
            return asString(tab["id"]) == "hjelp" && asString(tab["title"]) == "Hjelp"
        })
    }

    @Test func contextualHelpStagesGUIContextInChatWithoutDomainSideEffects() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-contextual-help")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let before = counters(try await chat.get(keypath: "state", requester: owner))

        let opened = try #require(asObject(try await chat.set(
            keypath: "chatHub.help.openContextual",
            value: .object([
                "activeSurfaceName": .string("Vault / Ideas"),
                "surfaceDescription": .string("Privat ide- og prosjektflate"),
                "editorMode": .string("view"),
                "destination": .string("Vault"),
                "sourceKind": .string("local"),
                "sourceEndpoint": .string("cell:///Vault"),
                "sourceBacked": .bool(false),
                "userContextSummary": .string("Personal Co-Pilot shell, privat requester-scope."),
                "permissionSummary": .string("Ingen native tillatelser. RAG krever eget klikk.")
            ]),
            requester: owner
        ) ?? .null))

        #expect(asBool(opened["sideEffect"]) == false)
        let context = try #require(asObject(opened["context"]))
        #expect(asString(context["activeSurfaceName"]) == "Vault / Ideas")
        #expect(asString(context["ragPolicy"])?.contains("eksplisitt brukerklikk") == true)
        let sources = try #require(asList(opened["availableSources"]))
        #expect(sources.contains { asString(asObject($0)?["id"]) == "gui-context" })
        #expect(sources.contains { asString(asObject($0)?["id"]) == "granted-rag" })

        let state = try #require(asObject(try await chat.get(keypath: "chatHub.state", requester: owner)))
        let ui = try #require(asObject(state["ui"]))
        #expect(asString(ui["activeTab"]) == "samtale")
        #expect(asString(ui["activeMoreTab"]) == "hjelp")

        let help = try #require(asObject(state["help"]))
        #expect(asString(help["status"]) == "context_staged")
        #expect(asString(help["suggestedPrompt"])?.contains("Vault / Ideas") == true)

        let composer = try #require(asObject(state["composer"]))
        #expect(asString(composer["body"])?.contains("Vault / Ideas") == true)
        let docsRAG = try #require(asObject(state["docsRAG"]))
        #expect(asString(docsRAG["query"])?.contains("Vault / Ideas") == true)
        #expect(counters(.object(state)) == before)
    }

    @Test func providerCellsExposeCellScopedStateContracts() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-provider-state")
        let apple = await BindingAppleIntelligenceProviderCell(owner: owner)
        let localLLM = await BindingLocalLLMCell(owner: owner)

        let appleState = try #require(asObject(try await apple.get(keypath: "ai.state", requester: owner)))
        #expect(asString(appleState["providerID"]) == "binding.apple-intelligence")
        #expect(asString(appleState["kind"]) == "apple_intelligence")
        #expect(asString(appleState["privacyLevel"]) == "local_device")
        #expect(asBool(appleState["requiresNetwork"]) == false)
        #expect(asBool(appleState["requiresUserApproval"]) == true)
        #expect(asStringList(appleState["purposeRefs"]).contains("personal.ai.provider.apple-intelligence"))
        #expect(asStringList(appleState["interests"]).contains("on-device"))

        let localState = try #require(asObject(try await localLLM.get(keypath: "state", requester: owner)))
        #expect(asString(localState["providerID"]) == "binding.local-llm")
        #expect(asString(localState["kind"]) == "local_llm")
        #expect(asString(localState["endpoint"]) == "cell:///LocalLLM")
        #expect(asString(localState["capability"]) == "llm.generate")
        #expect(asString(localState["privacyLevel"]) == "local_device_or_localhost")
        #expect(asBool(localState["requiresNetwork"]) == false)
    }

    @Test func ownerScopedChatAndProviderCellsRejectForeignRequesterWithoutDebugBypass() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let previousVault = CellBase.defaultIdentityVault
        let identityVault = await BindingStartupIdentityVault.shared.initialize()
        CellBase.debugValidateAccessForEverything = false
        CellBase.defaultIdentityVault = identityVault
        defer {
            CellBase.debugValidateAccessForEverything = previousDebugAccess
            CellBase.defaultIdentityVault = previousVault
        }

        let owner = try #require(await identityVault.identity(
            for: "binding-chat-owner-scope-owner-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        let foreignRequester = try #require(await identityVault.identity(
            for: "binding-chat-owner-scope-foreign-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let apple = await BindingAppleIntelligenceProviderCell(owner: owner)
        let localLLM = await BindingLocalLLMCell(owner: owner)

        let ownerFingerprint = try #require(owner.signingPublicKeyFingerprint)
        #expect(chat.storedOwnerIdentity.uuid == owner.uuid)
        #expect(chat.storedOwnerIdentity.signingPublicKeyFingerprint == ownerFingerprint)
        #expect(apple.storedOwnerIdentity.uuid == owner.uuid)
        #expect(apple.storedOwnerIdentity.signingPublicKeyFingerprint == ownerFingerprint)
        #expect(localLLM.storedOwnerIdentity.uuid == owner.uuid)
        #expect(localLLM.storedOwnerIdentity.signingPublicKeyFingerprint == ownerFingerprint)

        await expectDenied {
            try await chat.get(keypath: "state", requester: foreignRequester)
        }
        await expectDenied {
            try await chat.set(
                keypath: "assistant.analyzeDraft",
                value: .object(["text": .string("lag en avstemning")]),
                requester: foreignRequester
            )
        }

        await expectDenied {
            try await apple.get(keypath: "ai.state", requester: foreignRequester)
        }
        await expectDenied {
            try await apple.set(
                keypath: "ai.classifyIntent",
                value: .object(["draft": .string("lag en oppgave")]),
                requester: foreignRequester
            )
        }

        await expectDenied {
            try await localLLM.get(keypath: "state", requester: foreignRequester)
        }
        await expectDenied {
            try await localLLM.set(
                keypath: "llm.classifyIntent",
                value: .object(["draft": .string("lag et prosjekt")]),
                requester: foreignRequester
            )
        }
    }

    @Test func analyzeContextPackExcludesNativePrivateScopesAndOnlyListsScopedProviders() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let previousVault = CellBase.defaultIdentityVault
        let identityVault = await BindingStartupIdentityVault.shared.initialize()
        CellBase.debugValidateAccessForEverything = false
        CellBase.defaultIdentityVault = identityVault
        defer {
            CellBase.debugValidateAccessForEverything = previousDebugAccess
            CellBase.defaultIdentityVault = previousVault
        }

        let owner = try #require(await identityVault.identity(
            for: "binding-chat-context-pack-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        let chat = await BindingPersonalChatHubCell(owner: owner)

        let result = try #require(asObject(try await chat.set(
            keypath: "chatHub.assistant.analyzeDraft",
            value: .object([
                "text": .string("legg til oppgave: rydd Co-Pilot Chat og finn neste trygge steg")
            ]),
            requester: owner
        ) ?? .null))
        #expect(asBool(result["sideEffect"]) == false)

        let contextPack = try #require(asObject(result["contextPack"]))
        let excludedScopes = asStringList(contextPack["excluded"])
        for scope in [
            "other_participant_drafts",
            "native_contacts",
            "calendar",
            "microphone",
            "camera",
            "vault",
            "other_threads"
        ] {
            #expect(excludedScopes.contains(scope))
        }

        let descriptors = try #require(asList(contextPack["availableDescriptors"]))
        let descriptorObjects = descriptors.compactMap(asObject)
        #expect(descriptorObjects.isEmpty == false)

        let allowedProviderIDs: Set<String> = [
            "chat.local-rules",
            "binding.apple-intelligence",
            "binding.local-llm"
        ]
        let providerIDs = descriptorObjects.compactMap { descriptor in
            asString(descriptor["providerID"]) ?? asString(descriptor["id"])
        }
        #expect(providerIDs.isEmpty == false)
        #expect(providerIDs.allSatisfy { allowedProviderIDs.contains($0) })

        let descriptorJSON = try ValueType.list(descriptors).jsonString()
        for forbidden in [
            "native_contacts",
            "calendar",
            "microphone",
            "camera",
            "vault",
            "other_threads",
            "openai.4o-mini",
            "cell:///AIGateway"
        ] {
            #expect(!descriptorJSON.contains(forbidden))
        }
    }

    @Test func contactEndpointCellAcceptsSignedRequestsAndRejectsReplay() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let (owner, requester) = await signingIdentities()
        let cell = await BindingContactEndpointCell(owner: owner)

        let descriptor = try #require(asObject(try await cell.set(
            keypath: "publishEndpoint",
            value: .object([
                "endpointId": .string("binding-peer-inbox"),
                "purposes": .list([.string("purpose://contact.introduction")]),
                "acceptedTopics": .list([.string("contact.message")]),
                "contactSetId": .string("private-binding-set"),
                "routeRefs": .list([
                    .object([
                        "kind": .string("notificationOutbox"),
                        "participantId": .string("participant-secret"),
                        "deviceId": .string("device-secret"),
                        "platform": .string("ios")
                    ])
                ])
            ]),
            requester: owner
        ) ?? .null))

        #expect(asString(descriptor["endpointId"]) == "binding-peer-inbox")
        #expect(asString(descriptor["cell"]) == "cell:///ContactEndpoint")
        #expect(asString(descriptor["routingMode"]) == "opaqueSetRouter")
        #expect(asString(descriptor["ownerContextHash"]) != nil)
        #expect(asString(descriptor["contactSetIdHash"]) != nil)
        #expect(descriptor["routeRefs"] == nil)
        #expect(descriptor["participantId"] == nil)
        #expect(descriptor["deviceId"] == nil)

        let unsigned = try #require(asObject(try await cell.set(
            keypath: "contact.request",
            value: .object([
                "schema": .string("cellprotocol.contact.request.v1"),
                "endpointId": .string("binding-peer-inbox"),
                "nonce": .string("unsigned-1"),
                "issuedAt": .float(Date().timeIntervalSince1970),
                "expiresAt": .float(Date().addingTimeInterval(300).timeIntervalSince1970),
                "requesterIdentity": .identity(requester),
                "topic": .string("contact.message"),
                "purpose": .string("purpose://contact.introduction"),
                "payload": .object(["message": .string("Kan HAVENAgentD ta neste steg?")])
            ]),
            requester: owner
        ) ?? .null))
        #expect(asString(unsigned["status"]) == "rejected")
        #expect(asString(unsigned["reason"]) == "missing_signature")

        let request = try await signedContactRequest(
            endpointId: "binding-peer-inbox",
            nonce: "signed-1",
            requester: requester
        )
        let ticket = try #require(asObject(try await cell.set(
            keypath: "contact.request",
            value: .object(request),
            requester: owner
        ) ?? .null))
        #expect(asString(ticket["endpointId"]) == "binding-peer-inbox")
        #expect(asString(ticket["requestTopic"]) == "contact.message")
        let ticketId = try #require(asString(ticket["ticketId"]))

        let replay = try #require(asObject(try await cell.set(
            keypath: "contact.request",
            value: .object(request),
            requester: owner
        ) ?? .null))
        #expect(asString(replay["code"]) == "replay_detected")

        let resolved = try #require(asObject(try await cell.set(
            keypath: "ticket.resolve",
            value: .object(["ticketId": .string(ticketId)]),
            requester: owner
        ) ?? .null))
        #expect(asString(resolved["status"]) == "resolved")
        #expect(asObject(resolved["requestPayload"]) != nil)

        let responded = try #require(asObject(try await cell.set(
            keypath: "ticket.respond",
            value: .object([
                "ticketId": .string(ticketId),
                "status": .string("accepted"),
                "result": .object(["message": .string("Accepted")])
            ]),
            requester: owner
        ) ?? .null))
        #expect(asString(responded["status"]) == "accepted")
    }

    @Test func chatEntityExtensionScanFindsContactEndpointWithoutSideEffects() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-entity-extension")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let prompt = "Kan vi sende en melding via en annen entitets celle endepunkt og vente paa HAVENAgentD?"
        let before = counters(try await chat.get(keypath: "state", requester: owner))

        let scan = try #require(asObject(try await chat.set(
            keypath: "entityExtension.scan",
            value: .object(["query": .string(prompt)]),
            requester: owner
        ) ?? .null))
        #expect(asBool(scan["sideEffect"]) == false)
        let scanMatches = asList(scan["resourceMatches"]) ?? []
        #expect(scanMatches.contains { asString(asObject($0)?["kind"]) == "contact_endpoint" })
        #expect(counters(try await chat.get(keypath: "state", requester: owner)) == before)

        let analyze = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string(prompt)]),
            requester: owner
        ) ?? .null))
        #expect(asBool(analyze["sideEffect"]) == false)
        let analyzeMatches = asList(analyze["resourceMatches"]) ?? []
        #expect(analyzeMatches.contains { asString(asObject($0)?["kind"]) == "contact_endpoint" })
        #expect(asString(asObject(analyze["providerRecommendation"])?["kind"]) == "contact_endpoint")
        #expect(counters(try await chat.get(keypath: "state", requester: owner)) == before)

        let open = try #require(asObject(try await chat.set(
            keypath: "ui.openComponentSurface",
            value: .object(["kind": .string("contact-endpoint")]),
            requester: owner
        ) ?? .null))
        #expect(asBool(open["sideEffect"]) == false)
    }

    @Test func chatEntityExtensionUsesCellScaffoldSnapshotShape() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-entity-extension-shape")
        let chat = await BindingPersonalChatHubCell(owner: owner)

        let initial = try #require(asObject(try await chat.get(keypath: "entityExtension", requester: owner)))
        #expect(asString(initial["schema"]) == "haven.personal.entity-extension.v1")
        #expect(asString(initial["privacyBoundary"]) == "no_global_identifier_no_cross_domain_merge")
        #expect(asBool(initial["sideEffectsRequireClick"]) == true)
        #expect((asInt(initial["extensionCount"]) ?? 0) > 0)
        let counts = try #require(asObject(initial["counts"]))
        #expect((asInt(counts["cell_configuration"]) ?? 0) > 0)
        #expect((asInt(counts["agent_action"]) ?? 0) > 0)
        #expect((asInt(counts["provider"]) ?? 0) > 0)

        let scan = try #require(asObject(try await chat.set(
            keypath: "entityExtension.scan",
            value: .object(["query": .string("hva har jeg tilgang til på enhetene mine og i skyen?")]),
            requester: owner
        ) ?? .null))
        #expect(asBool(scan["ok"]) == true)
        #expect(asString(scan["status"]) == "scanned")
        #expect(asBool(scan["sideEffect"]) == false)
        #expect(asObject(scan["auditEvent"]) != nil)
        #expect((asList(scan["assistantProviders"]) ?? []).contains { asString(asObject($0)?["providerID"]) == "chat.local-rules" })

        let snapshot = try #require(asObject(scan["entityExtension"]))
        let rows = try #require(asList(snapshot["extensions"]))
        #expect(rows.contains { asString(asObject($0)?["kind"]) == "cell_configuration" })
        #expect(rows.contains { asString(asObject($0)?["kind"]) == "agent_action" })
        #expect(rows.contains { asString(asObject($0)?["kind"]) == "provider" })
        let matches = try #require(asList(scan["resourceMatches"]))
        #expect(matches.contains { asString(asObject($0)?["kind"]) == "cell_configuration" })
        #expect(matches.contains { asString(asObject($0)?["kind"]) == "agent_action" })

        let state = try #require(asObject(try await chat.get(keypath: "state", requester: owner)))
        let assistant = try #require(asObject(state["assistant"]))
        #expect((asInt(assistant["resourceMatchCount"]) ?? 0) > 0)
    }

    @Test func agendaContextAnswersInjectedCalendarAndReminderItemsWithRoleClarification() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-agenda-context")
        let agenda = await PersonalAgendaContextCell(owner: owner)
        let now = "2026-05-16T09:00:00+02:00"

        let refreshed = try #require(asObject(try await agenda.set(
            keypath: "agenda.refresh",
            value: .object([
                "now": .string(now),
                "items": .list([
                    .object([
                        "id": .string("event-organizer"),
                        "kind": .string("event"),
                        "title": .string("Arrangørbrief for konferanse"),
                        "startAt": .string("2026-05-16T10:00:00+02:00"),
                        "endAt": .string("2026-05-16T10:30:00+02:00"),
                        "roleHints": .list([.string("organizer")])
                    ]),
                    .object([
                        "id": .string("reminder-sponsor"),
                        "kind": .string("reminder"),
                        "title": .string("Følg opp sponsor-leads"),
                        "dueAt": .string("2026-05-16T12:00:00+02:00"),
                        "roleHints": .list([.string("sponsor")])
                    ])
                ])
            ]),
            requester: owner
        ) ?? .null))
        #expect(asInt(refreshed["itemCount"]) == 2)

        let answer = try #require(asObject(try await agenda.set(
            keypath: "agenda.answerQuery",
            value: .object([
                "query": .string("Hva er på agendaen i dag?"),
                "now": .string(now)
            ]),
            requester: owner
        ) ?? .null))

        #expect(asString(answer["status"]) == "answered")
        #expect(asBool(answer["sideEffect"]) == false)
        #expect(asInt(answer["itemCount"]) == 2)
        #expect(asBool(answer["needsClarification"]) == true)
        #expect(asString(answer["clarifyingQuestion"])?.contains("deltaker") == true)
        #expect(asString(answer["summaryText"])?.contains("Arrangørbrief") == true)
        let roleScores = try #require(asObject(answer["roleScores"]))
        #expect(asStringList(answer["topRoles"]).contains("organizer"))
        #expect(asStringList(answer["topRoles"]).contains("sponsor"))
        #expect(roleScores["organizer"] != nil)
        #expect(roleScores["sponsor"] != nil)
        let signals = try #require(asList(answer["purposeSignals"]))
        #expect(signals.contains { asString(asObject($0)?["portablePurposeRef"]) == "purpose://review-todays-agenda" })
        #expect(signals.contains { asString(asObject($0)?["portablePurposeRef"]) == "purpose://organizer-agenda-focus" })
    }

    @Test func agendaQuestionRoutesToAgendaContextProvider() async throws {
        let prompt = "Hva er på agendaen i dag, og hva er neste møte?"
        let matches = BindingChatIntentClassifier.resourceMatches(prompt: prompt)
        #expect(matches.contains { asString($0["kind"]) == "agenda_context" })

        let recommendation = BindingChatProviderRouter.recommend(
            prompt: prompt,
            suggestion: BindingChatIntentClassifier.classify(prompt: prompt),
            resourceMatches: matches,
            providers: []
        )
        #expect(recommendation.kind == "agenda_context")
        #expect(recommendation.endpoint == "cell:///PersonalAgendaContext")
        #expect(recommendation.requiresUserApproval)
    }

    @Test func havenAgentStatusProviderReportsNextSetupStep() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BindingHavenAgentDStatus-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)

        let agentBinary = root.appendingPathComponent("haven-agentd")
        let mcpBinary = root.appendingPathComponent("haven-agentd-mcp")
        try Data("#!/bin/sh\n".utf8).write(to: agentBinary)
        try Data("#!/bin/sh\n".utf8).write(to: mcpBinary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: agentBinary.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mcpBinary.path)

        let config = root.appendingPathComponent("config.json")
        let starter = root.appendingPathComponent("starter-auth.json")
        let environment = [
            "BINDING_HAVEN_AGENTD_BINARY": agentBinary.path,
            "BINDING_HAVEN_AGENTD_MCP_BINARY": mcpBinary.path,
            "BINDING_HAVEN_AGENTD_CONFIG": config.path,
            "BINDING_HAVEN_AGENTD_STARTER_AUTH": starter.path
        ]
        let now = try #require(ISO8601DateFormatter().date(from: "2026-05-17T12:00:00Z"))

        try Data("{}".utf8).write(to: config)
        var status = BindingHavenAgentDStatusProvider.snapshot(environment: environment, now: now)
        #expect(status.status == "device_action_relay_missing")
        #expect(status.recommendedNextStep == "enable_device_action_relay")

        try Data(#"{"deviceActionRelay":{"enabled":true}}"#.utf8).write(to: config)
        try Data(#"{"expiresAt":"2026-05-04T20:58:29Z"}"#.utf8).write(to: starter)
        status = BindingHavenAgentDStatusProvider.snapshot(environment: environment, now: now)
        #expect(status.status == "starter_auth_expired")
        #expect(status.recommendedNextStep == "refresh_starter_auth_with_sprout")

        try Data(#"{"expiresAt":"2026-06-04T20:58:29Z"}"#.utf8).write(to: starter)
        status = BindingHavenAgentDStatusProvider.snapshot(environment: environment, now: now)
        #expect(status.status == "ready_for_mcp")
        #expect(status.recommendedNextStep == "configure_codex_mcp_host")
    }

    @Test func analyzeDraftSurfacesHavenAgentDDecisionForPhoneCodexPrompt() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-agent-codex")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let result = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string("Fra telefonen vil jeg sette i gang et prompt i Codex og få varsel når jobben trenger tillatelse.")]),
            requester: owner
        ) ?? .null))

        let suggestion = try #require(asObject(result["suggestion"]))
        #expect(asString(suggestion["kind"]) == "agent_codex_prompt")
        #expect(asString(suggestion["helperID"]) == "agent-setup")

        let decision = try #require(asObject(result["agentUseDecision"]))
        #expect(asBool(decision["shouldSuggest"]) == true)
        #expect(asString(decision["requiredCapability"]) == "phone_originated_codex_prompt")
        #expect(asString(decision["recommendedNextStep"]) != nil)
        #expect((asList(decision["instructions"]) ?? []).isEmpty == false)

        let recommendation = try #require(asObject(result["providerRecommendation"]))
        #expect(asString(recommendation["kind"]) == "agent_bridge")
    }

    @Test func analyzeDraftSurfacesHavenAgentDEmailDraftPurpose() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-agent-email")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let result = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string("Send e-post til ane@example.com og spør om vi kan ta en prat om HAVENAgentD.")]),
            requester: owner
        ) ?? .null))

        let suggestion = try #require(asObject(result["suggestion"]))
        #expect(asString(suggestion["kind"]) == "agent_email_draft")
        #expect(asString(suggestion["helperID"]) == "agent-review")
        #expect(asString(suggestion["purposeRef"]) == "personal.agent.email.compose-draft")
        #expect(asStringList(suggestion["interests"]).contains("contact-fallback"))

        let recommendation = try #require(asObject(result["providerRecommendation"]))
        #expect(asString(recommendation["kind"]) == "agent_bridge")
        #expect(asStringList(recommendation["purposeRefs"]).contains("personal.agent.email.compose-draft"))

        let resources = try #require(asList(result["resourceMatches"]))
        let emailResource = resources.compactMap { asObject($0) }.first {
            asString($0["sourceCellName"]) == "AgentMailDraftCell"
        }
        #expect(asString(emailResource?["sourceCellEndpoint"]) == "cell:///agent/email/outbox")
        #expect(asString(emailResource?["actionKeypath"]) == "draftIntent")
    }

    @Test func analyzeDraftDoesNotSuggestAgentForOrdinaryCodeExplanation() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-no-agent")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let result = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string("Forklar hva denne Swift-funksjonen gjør uten å kjøre noe.")]),
            requester: owner
        ) ?? .null))

        let decision = try #require(asObject(result["agentUseDecision"]))
        #expect(asBool(decision["shouldSuggest"]) == false)
        #expect(asString(decision["requiredCapability"]) == "none")
    }

    @Test func assistantStateDirectKeypathsMirrorCoPilotContract() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-assistantstate-direct")
        let chat = await BindingPersonalChatHubCell(owner: owner)

        _ = try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string("vi trenger avstemning om lunsj")]),
            requester: owner
        )

        let candidates = try #require(asList(try await chat.get(keypath: "assistantState.intentCandidates", requester: owner)))
        #expect(candidates.contains { asString(asObject($0)?["intentKind"]) == "create_poll" })
        let priority = try #require(asObject(try await chat.get(keypath: "assistantState.priorityIntent", requester: owner)))
        #expect(asString(priority["helperID"]) == "poll")
        let providers = try #require(asList(try await chat.get(keypath: "assistantState.assistantProviders", requester: owner)))
        #expect(providers.contains { asString(asObject($0)?["providerID"]) == "chat.local-rules" })
        let recommendation = try #require(asObject(try await chat.get(keypath: "assistantState.providerRecommendation", requester: owner)))
        #expect(asString(recommendation["providerID"]) == "chat.local-rules")
        #expect(asString(try await chat.get(keypath: "assistantState.whySummary", requester: owner)) != nil)
    }

    @Test func copilotRendererKeypathAliasesStayInsideChatHubScope() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-renderer-keypaths")
        let chat = await BindingPersonalChatHubCell(owner: owner)

        #expect(asString(try await chat.get(keypath: "state.voice.message", requester: owner)) == "Speech input is idle.")
        #expect(asString(try await chat.get(keypath: "chatHub.state.voice.message", requester: owner)) == "Speech input is idle.")
        #expect(asString(try await chat.get(keypath: "chatHub.state.assistant.whySummary", requester: owner)) != "denied")
        #expect(asList(try await chat.get(keypath: "chatHub.state.assistant.assistantProviders", requester: owner))?.isEmpty == false)

        let analyze = try #require(asObject(try await chat.set(
            keypath: "chatHub.assistant.analyzeDraft",
            value: .object(["text": .string("vi trenger avstemning om lunsj")]),
            requester: owner
        ) ?? .null))
        #expect(asBool(analyze["sideEffect"]) == false)
        #expect(asString(asObject(analyze["suggestion"])?["helperID"]) == "poll")
        #expect(asString(try await chat.get(
            keypath: "chatHub.state.assistant.latestSuggestion.explanation",
            requester: owner
        )) != "denied")
    }

    @Test func promptSubmitProducesPurposeContextAndPromptLogWithoutDomainSideEffects() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-prompt-submit")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let before = counters(try await chat.get(keypath: "state", requester: owner))

        _ = try await chat.set(
            keypath: "chatHub.setComposer",
            value: .string("registrer feil: Co-Pilot Chat viser denied under forslag"),
            requester: owner
        )
        let result = try #require(asObject(try await chat.set(
            keypath: "chatHub.prompt.submit",
            value: .object([:]),
            requester: owner
        ) ?? .null))

        #expect(asBool(result["sideEffect"]) == false)
        let suggestion = try #require(asObject(result["suggestion"]))
        #expect(asString(suggestion["helperID"]) == "work-item")
        let purposeContext = try #require(asObject(result["purposeContext"]))
        #expect(asString(purposeContext["schema"]) == "haven.purpose-context-pack.v0.binding-preview")
        #expect(asString(purposeContext["purposeTreeExcerpt"])?.contains("personal.chat.assist.work-item.capture") == true)
        let understanding = try #require(asObject(result["promptUnderstanding"]))
        #expect(asString(understanding["recommendedNextStep"]) == "open_helper_after_user_click")
        let plan = try #require(asObject(result["groundedActionPlan"]))
        #expect(asString(asObject(plan["target"])?["actionKeypath"]) == "chatHub.workItem.capture")

        let state = try #require(asObject(try await chat.get(keypath: "chatHub.state", requester: owner)))
        let ui = try #require(asObject(state["ui"]))
        #expect(asString(ui["activeTab"]) == "samtale")
        #expect((asList(ui["promptMessages"]) ?? []).count >= 3)
        #expect(asString(try await chat.get(keypath: "chatHub.state.assistant.purposeContext.summary", requester: owner)) != "denied")
        #expect(counters(.object(state)) == before)
    }

    @Test func perspectiveActivePurposeImprovesAmbiguousPromptRoutingWithoutSideEffects() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let previousResolver = CellBase.defaultCellResolver
        let previousVault = CellBase.defaultIdentityVault
        CellBase.debugValidateAccessForEverything = true
        CellBase.defaultCellResolver = nil
        CellBase.defaultIdentityVault = nil
        defer {
            CellBase.debugValidateAccessForEverything = previousDebugAccess
            CellBase.defaultCellResolver = previousResolver
            CellBase.defaultIdentityVault = previousVault
        }

        let plain = BindingChatIntentClassifier.classify(prompt: "legg dette inn")
        #expect(plain.status == "low_confidence")
        #expect(plain.helperID.isEmpty)

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        let resolver = try #require(CellBase.defaultCellResolver as? CellResolver)
        let owner = try #require(await CellBase.defaultIdentityVault?.identity(
            for: "binding-chat-perspective-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        let perspective = try #require(try await resolver.cellAtEndpoint(
            endpoint: "cell:///Perspective",
            requester: owner
        ) as? Meddle)
        let added = try #require(asObject(try await perspective.set(
            keypath: "addPurpose",
            value: .object([
                "purpose": .object([
                    "name": .string("personal.chat.assist.project"),
                    "description": .string("Project planning context for ambiguous Co-Pilot follow-up prompts."),
                    "types": .list([]),
                    "subTypes": .list([]),
                    "parts": .list([]),
                    "partOf": .list([]),
                    "purposes": .list([]),
                    "interests": .list([]),
                    "entities": .list([]),
                    "states": .list([])
                ]),
                "purposeWeight": .float(0.92)
            ]),
            requester: owner
        ) ?? .null))
        #expect(asString(added["status"]) == "ok")

        let chat = await BindingPersonalChatHubCell(owner: owner)
        let before = counters(try await chat.get(keypath: "state", requester: owner))
        let analyzed = try #require(asObject(try await chat.set(
            keypath: "chatHub.assistant.analyzeDraft",
            value: .object(["text": .string("legg dette inn")]),
            requester: owner
        ) ?? .null))

        #expect(asBool(analyzed["sideEffect"]) == false)
        let suggestion = try #require(asObject(analyzed["suggestion"]))
        #expect(asString(suggestion["helperID"]) == "project")
        #expect(asString(suggestion["purposeRef"]) == "personal.chat.assist.project")
        #expect(asString(suggestion["status"]) == "suggested")
        #expect((asString(suggestion["reason"]) ?? "").contains("Perspective"))

        let purposeContext = try #require(asObject(analyzed["purposeContext"]))
        #expect(asStringList(purposeContext["activePerspectivePurposeRefs"]).contains("personal.chat.assist.project"))
        #expect(asString(purposeContext["purposeTreeExcerpt"])?.contains("personal.chat.assist.project") == true)
        let contextPack = try #require(asObject(analyzed["contextPack"]))
        let perspectiveContext = try #require(asObject(contextPack["perspectiveContext"]))
        #expect(asBool(perspectiveContext["isEmpty"]) == false)
        #expect(asStringList(perspectiveContext["purposeRefs"]).contains("personal.chat.assist.project"))

        let state = try #require(asObject(try await chat.get(keypath: "chatHub.state", requester: owner)))
        #expect(counters(.object(state)) == before)
    }

    @Test func purposeInterestContextQualityMatrixImprovesAmbiguousChatPrompts() async throws {
        struct QualityCase {
            var prompt: String
            var context: BindingChatPurposeContext
            var expectedHelperID: String
            var expectedPurposeRef: String
        }

        func context(
            purposeRefs: [String],
            interests: [String],
            weights: [String: Double]
        ) -> BindingChatPurposeContext {
            BindingChatPurposeContext(
                purposeRefs: purposeRefs,
                interests: interests,
                weights: weights,
                source: "test.perspective.active-purpose"
            )
        }

        let cases: [QualityCase] = [
            QualityCase(
                prompt: "legg dette inn",
                context: context(
                    purposeRefs: ["personal.chat.assist.project"],
                    interests: ["project", "planning", "project-management"],
                    weights: ["personal.chat.assist.project": 0.92]
                ),
                expectedHelperID: "project",
                expectedPurposeRef: "personal.chat.assist.project"
            ),
            QualityCase(
                prompt: "neste steg",
                context: context(
                    purposeRefs: ["personal.chat.assist.todo"],
                    interests: ["todo", "task", "oppgave"],
                    weights: ["personal.chat.assist.todo": 0.91]
                ),
                expectedHelperID: "todo",
                expectedPurposeRef: "personal.chat.assist.todo"
            ),
            QualityCase(
                prompt: "lagre dette",
                context: context(
                    purposeRefs: ["personal.chat.assist.idea.capture"],
                    interests: ["idea", "capture", "vault"],
                    weights: ["personal.chat.assist.idea.capture": 0.9]
                ),
                expectedHelperID: "idea-capture",
                expectedPurposeRef: "personal.chat.assist.idea.capture"
            ),
            QualityCase(
                prompt: "koble dette",
                context: context(
                    purposeRefs: ["personal.knowledge.graph.index"],
                    interests: ["graph", "obsidian", "vault"],
                    weights: ["personal.knowledge.graph.index": 0.9]
                ),
                expectedHelperID: "resource-router",
                expectedPurposeRef: "personal.knowledge.graph.index"
            )
        ]

        let baseline = cases.map { BindingChatIntentClassifier.classify(prompt: $0.prompt) }
        let withPerspective = cases.map {
            BindingChatIntentClassifier.classify(
                prompt: $0.prompt,
                perspectiveContext: $0.context
            )
        }

        let baselineExactHits = zip(cases, baseline).filter { item, result in
            result.helperID == item.expectedHelperID
                && result.purposeRef == item.expectedPurposeRef
                && result.shouldSuggest
        }.count
        let perspectiveExactHits = zip(cases, withPerspective).filter { item, result in
            result.helperID == item.expectedHelperID
                && result.purposeRef == item.expectedPurposeRef
                && result.shouldSuggest
        }.count
        let baselineSuggestions = baseline.filter(\.shouldSuggest).count
        let perspectiveSuggestions = withPerspective.filter(\.shouldSuggest).count
        let averageBaselineConfidence = baseline.reduce(0.0) { $0 + $1.confidence } / Double(cases.count)
        let averagePerspectiveConfidence = withPerspective.reduce(0.0) { $0 + $1.confidence } / Double(cases.count)

        #expect(baselineExactHits == 0)
        #expect(baselineSuggestions == 0)
        #expect(perspectiveExactHits == cases.count)
        #expect(perspectiveSuggestions == cases.count)
        #expect(averagePerspectiveConfidence - averageBaselineConfidence >= 0.6)

        let ideaContext = context(
            purposeRefs: ["personal.chat.assist.idea.capture"],
            interests: ["idea", "capture", "vault"],
            weights: ["personal.chat.assist.idea.capture": 0.9]
        )
        let negative = BindingChatIntentClassifier.classify(
            prompt: "ikke lagre ide",
            perspectiveContext: ideaContext
        )
        #expect(negative.shouldSuggest == false)
        #expect(negative.negativeIntent == "idea_capture")
    }

    @Test func docsRAGHelperIsDiscoverableAndSideEffectFreeUntilExplicitAsk() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-docs-rag")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let before = counters(try await chat.get(keypath: "state", requester: owner))

        let analyze = try #require(asObject(try await chat.set(
            keypath: "chatHub.assistant.analyzeDraft",
            value: .object(["text": .string("hva sier dokumentasjonen om formålstre i Co-Pilot Chat?")]),
            requester: owner
        ) ?? .null))
        #expect(asBool(analyze["sideEffect"]) == false)
        #expect(asString(asObject(analyze["suggestion"])?["helperID"]) == "docs-rag")

        let open = try #require(asObject(try await chat.set(
            keypath: "chatHub.ui.openSuggestedHelper",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asBool(open["sideEffect"]) == false)
        #expect(asString(open["helper"]) == "docs-rag")
        let openedState = try #require(asObject(try await chat.get(keypath: "chatHub.state", requester: owner)))
        let openedUI = try #require(asObject(openedState["ui"]))
        #expect(asString(openedUI["activeTab"]) == "samtale")
        #expect(asBool(openedUI["hasActiveHelperSurface"]) == true)
        #expect((asList(openedUI["activeHelpers"]) ?? []).contains { asString(asObject($0)?["id"]) == "docs-rag" })
        #expect(counters(.object(openedState)) == before)

        let search = try #require(asObject(try await chat.set(
            keypath: "chatHub.docsRAG.search",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asBool(search["sideEffect"]) == false)
        #expect((asList(search["documentationMatches"]) ?? []).isEmpty == false)

        let ask = try #require(asObject(try await chat.set(
            keypath: "chatHub.docsRAG.askRAG",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asBool(ask["sideEffect"]) == false)
        #expect(asString(ask["status"]) != "error")
        #expect(counters(try await chat.get(keypath: "chatHub.state", requester: owner)) == before)
    }

    @Test func openHelperDirectlyFromComposerStagesSuggestionAndSurface() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-direct-open-helper")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let before = counters(try await chat.get(keypath: "state", requester: owner))

        _ = try await chat.set(
            keypath: "chatHub.setComposer",
            value: .object(["body": .string("vi trenger avstemning om lunsj")]),
            requester: owner
        )
        let open = try #require(asObject(try await chat.set(
            keypath: "chatHub.ui.openSuggestedHelper",
            value: .object([:]),
            requester: owner
        ) ?? .null))

        #expect(asBool(open["ok"]) == true)
        #expect(asBool(open["sideEffect"]) == false)
        #expect(asString(open["helper"]) == "poll")
        #expect(asString(asObject(open["suggestion"])?["helperID"]) == "poll")

        let openedState = try #require(asObject(try await chat.get(keypath: "chatHub.state", requester: owner)))
        let openedUI = try #require(asObject(openedState["ui"]))
        #expect(asBool(openedUI["hasActiveHelperSurface"]) == true)
        #expect((asList(openedUI["activeHelpers"]) ?? []).contains { asString(asObject($0)?["id"]) == "poll" })
        #expect(counters(.object(openedState)) == before)
    }

    @Test func iOSStyleComposerAnalyzeAndOpenFindsCoreHelpers() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let scenarios: [(prompt: String, helper: String, purpose: String)] = [
            ("lagre ide: iOS Co-Pilot bør finne hjelpere fra prompt", "idea-capture", "personal.chat.assist.idea.capture"),
            ("legg til oppgave: test Åpne hjelper på iPhone", "todo", "personal.chat.assist.todo"),
            ("lag prosjektplan for Binding Co-Pilot parity", "project", "personal.chat.assist.project"),
            ("vis ideer prosjektstyring og Obsidian graf i vault", "resource-router", "personal.knowledge.graph.index")
        ]

        for scenario in scenarios {
            let owner = await signedOwner("binding-chat-ios-helper-\(scenario.helper)")
            let chat = await BindingPersonalChatHubCell(owner: owner)
            let before = counters(try await chat.get(keypath: "state", requester: owner))

            _ = try await chat.set(
                keypath: "chatHub.setComposer",
                value: .string(scenario.prompt),
                requester: owner
            )
            let analyze = try #require(asObject(try await chat.set(
                keypath: "chatHub.assistant.analyzeDraft",
                value: .object([:]),
                requester: owner
            ) ?? .null))
            #expect(asBool(analyze["sideEffect"]) == false)
            #expect(asString(asObject(analyze["suggestion"])?["helperID"]) == scenario.helper)
            #expect(asString(asObject(analyze["suggestion"])?["purposeRef"]) == scenario.purpose)
            let analyzedState = try #require(asObject(try await chat.get(keypath: "chatHub.state", requester: owner)))
            let analyzedUI = try #require(asObject(analyzedState["ui"]))
            #expect(asBool(analyzedUI["hasActionableSuggestion"]) == true)
            #expect((asString(analyzedUI["primaryActionHint"]) ?? "").contains("Trykk hovedknappen"))

            let open = try #require(asObject(try await chat.set(
                keypath: "chatHub.ui.openSuggestedHelper",
                value: .object([:]),
                requester: owner
            ) ?? .null))
            #expect(asBool(open["ok"]) == true)
            #expect(asBool(open["sideEffect"]) == false)
            #expect(asString(open["helper"]) == scenario.helper)

            let openedState = try #require(asObject(try await chat.get(keypath: "chatHub.state", requester: owner)))
            let openedUI = try #require(asObject(openedState["ui"]))
            #expect(asBool(openedUI["hasActiveHelperSurface"]) == true)
            #expect(asBool(openedUI["hasActionableSuggestion"]) == false)
            #expect(asString(openedUI["activeTab"]) == "samtale")
            #expect((asList(openedUI["activeHelpers"]) ?? []).contains { asString(asObject($0)?["id"]) == scenario.helper })
            #expect(counters(.object(openedState)) == before)
        }
    }

    @Test func vaultIdeasAndObsidianGraphPromptsRouteToLocalSurfaces() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-vault-graph-routing")
        let chat = await BindingPersonalChatHubCell(owner: owner)

        let vault = try #require(asObject(try await chat.set(
            keypath: "chatHub.assistant.analyzeDraft",
            value: .object(["text": .string("vis ideer og prosjektstyring i vault")]),
            requester: owner
        ) ?? .null))
        #expect(asBool(vault["sideEffect"]) == false)
        #expect(asString(asObject(vault["suggestion"])?["helperID"]) == "resource-router")
        #expect(asString(asObject(vault["suggestion"])?["purposeRef"]) == "personal.vault.ideas.projects")
        #expect((asList(vault["resourceMatches"]) ?? []).contains {
            asString(asObject($0)?["id"]) == "configuration:vault-ideas"
        })

        let graph = try #require(asObject(try await chat.set(
            keypath: "chatHub.assistant.analyzeDraft",
            value: .object(["text": .string("åpne obsidian grafen og render knowledge graph")]),
            requester: owner
        ) ?? .null))
        #expect(asBool(graph["sideEffect"]) == false)
        #expect(asString(asObject(graph["suggestion"])?["helperID"]) == "resource-router")
        #expect(asString(asObject(graph["suggestion"])?["purposeRef"]) == "personal.knowledge.graph.index")
        #expect((asList(graph["resourceMatches"]) ?? []).contains {
            asString(asObject($0)?["id"]) == "configuration:graph-index"
        })
    }

    @Test func vaultAndGraphIndexResolveAndRenderInBindingContract() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let previousResolver = CellBase.defaultCellResolver
        let previousVault = CellBase.defaultIdentityVault
        CellBase.debugValidateAccessForEverything = true
        defer {
            CellBase.debugValidateAccessForEverything = previousDebugAccess
            CellBase.defaultCellResolver = previousResolver
            CellBase.defaultIdentityVault = previousVault
        }

        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver
        let identityVault = await BindingStartupIdentityVault.shared.initialize()
        CellBase.defaultIdentityVault = identityVault
        let ownerIdentity = await identityVault.identity(
            for: "binding-vault-graph-\(UUID().uuidString)",
            makeNewIfNotFound: true
        )
        let owner = try #require(ownerIdentity)

        let vault = try #require(try await resolver.cellAtEndpoint(
            endpoint: "cell:///Vault",
            requester: owner
        ) as? Meddle)
        let graph = try #require(try await resolver.cellAtEndpoint(
            endpoint: "cell:///GraphIndex",
            requester: owner
        ) as? Meddle)

        let note = try #require(asObject(try await vault.set(
            keypath: "vault.note.create",
            value: .object([
                "id": .string("binding-idea"),
                "title": .string("Binding idea"),
                "content": .string("Ide koblet til [[binding-project]]."),
                "tags": .list([.string("idea"), .string("project")]),
                "createdAtEpochMs": .integer(0),
                "updatedAtEpochMs": .integer(0)
            ]),
            requester: owner
        ) ?? .null))
        #expect(asString(note["status"]) == "ok")
        let vaultState = try #require(asObject(try await vault.get(keypath: "vault.state", requester: owner)))
        #expect((asInt(vaultState["note_count"]) ?? 0) >= 1)

        _ = try await graph.set(
            keypath: "graph.reindex",
            value: .object([
                "notes": .list([
                    .object(["id": .string("binding-idea"), "content": .string("Ide koblet til [[binding-project]].")]),
                    .object(["id": .string("binding-project"), "content": .string("Prosjekt koblet til [[next-step]].")]),
                    .object(["id": .string("next-step"), "content": .string("Neste steg.")])
                ])
            ]),
            requester: owner
        )
        let graphState = try #require(asObject(try await graph.get(keypath: "graph.state", requester: owner)))
        #expect(asInt(graphState["node_count"]) == 3)
        #expect(asInt(graphState["edge_count"]) == 2)

        let configuration = ConfigurationCatalogCell.personalVaultIdeasMenuConfiguration()
        #expect(configuration.cellReferences?.contains {
            $0.label == "vault" && $0.endpoint == "cell:///Vault"
        } == true)
        #expect(configuration.cellReferences?.contains {
            $0.label == "graph" && $0.endpoint == "cell:///GraphIndex"
        } == true)
        let skeletonText = try #require(encodedSkeletonString(configuration.skeleton))
        #expect(skeletonText.contains("\"kind\":\"graph\""))
        #expect(skeletonText.contains("graph.reindex"))
        #expect(skeletonText.contains("vault.vault.state.notes"))
    }

    @Test func workItemHelperOnlyCreatesModuleOnExplicitCapture() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-work-item")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let prompt = "registrer feil: Co-Pilot Chat på mac viser denied under Finn forslag, forventet vanlig norsk forslagstekst"
        let before = counters(try await chat.get(keypath: "chatHub.state", requester: owner))

        let analyze = try #require(asObject(try await chat.set(
            keypath: "chatHub.assistant.analyzeDraft",
            value: .object(["text": .string(prompt)]),
            requester: owner
        ) ?? .null))
        #expect(asBool(analyze["sideEffect"]) == false)
        #expect(asString(asObject(analyze["suggestion"])?["helperID"]) == "work-item")
        #expect(counters(try await chat.get(keypath: "chatHub.state", requester: owner)) == before)

        let draft = try #require(asObject(try await chat.get(
            keypath: "chatHub.state.workbench.workItemDraft",
            requester: owner
        )))
        #expect(asString(draft["kind"]) == "bug")
        #expect(asString(draft["summary"])?.contains("denied") == true)

        _ = try await chat.set(keypath: "chatHub.ui.openSuggestedHelper", value: .object([:]), requester: owner)
        #expect(counters(try await chat.get(keypath: "chatHub.state", requester: owner)) == before)

        _ = try await chat.set(keypath: "chatHub.workItem.capture", value: .object([:]), requester: owner)
        let afterCapture = counters(try await chat.get(keypath: "chatHub.state", requester: owner))
        #expect(afterCapture.workbenchModuleCount == before.workbenchModuleCount + 1)
    }

    @Test func chatDropReceiveStagesInviteDraftOnly() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-drop")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let before = counters(try await chat.get(keypath: "state", requester: owner))

        let drop = try #require(asObject(try await chat.set(
            keypath: "drop.receive",
            value: .object([
                "dragRole": .string("person"),
                "dropTargetRole": .string("chat-invite-slot"),
                "dropIntent": .string("add"),
                "dragPayload": .object([
                    "profileID": .string("drop-bob-profile"),
                    "userUUID": .string("drop-bob-user"),
                    "displayName": .string("Drop Bob"),
                    "headline": .string("Can be invited"),
                    "contactEndpoint": .object([
                        "endpointId": .string("contact-drop-bob"),
                        "cell": .string("cell:///ContactEndpoint"),
                        "purposes": .list([.string("personal.chat.invite.receive")]),
                        "interests": .list([.string("invite-only-chat")])
                    ])
                ])
            ]),
            requester: owner
        ) ?? .null))
        #expect(asString(drop["status"]) == "candidate_ready")
        #expect(asString(drop["sideEffect"]) == "invite_draft_only")
        let inviteDraft = try #require(asObject(drop["inviteDraft"]))
        #expect(asString(inviteDraft["profileID"]) == "drop-bob-profile")
        #expect(asString(inviteDraft["userUUID"]) == "drop-bob-user")
        #expect(asString(asObject(inviteDraft["contactEndpoint"])?["endpointID"]) == "contact-drop-bob")
        #expect(counters(try await chat.get(keypath: "state", requester: owner)) == before)

        let state = try #require(asObject(try await chat.get(keypath: "state", requester: owner)))
        #expect(asString(asObject(state["drop"])?["validationState"]) == "valid")
        #expect(asString(asObject(state["inviteDraft"])?["profileID"]) == "drop-bob-profile")
    }

    @Test func chatWorkbenchAnalyzeAndOpenHelperHaveNoDomainSideEffects() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let (owner, _) = await signingIdentities()
        let chat = await BindingPersonalChatHubCell(owner: owner)

        let before = counters(try await chat.get(keypath: "state", requester: owner))
        let analyze = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string("vi trenger avstemning om lunsj")]),
            requester: owner
        ) ?? .null))
        #expect(asBool(analyze["ok"]) == true)
        #expect(asBool(analyze["sideEffect"]) == false)
        #expect(asString(asObject(analyze["suggestion"])?["helperID"]) == "poll")
        #expect(counters(try await chat.get(keypath: "state", requester: owner)) == before)

        let open = try #require(asObject(try await chat.set(
            keypath: "ui.openSuggestedHelper",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asBool(open["sideEffect"]) == false)
        #expect(asString(open["helper"]) == "poll")
        let openedState = try #require(asObject(try await chat.get(keypath: "state", requester: owner)))
        let openedUI = try #require(asObject(openedState["ui"]))
        let openedChips = try #require(asList(openedUI["activeToolChips"]))
        #expect(openedChips.count == 1)
        let openedChip = try #require(asObject(openedChips.first))
        #expect(asString(openedChip["label"]) == "Fjern")
        #expect(asString(openedChip["keypath"]) == "chatHub.ui.dismissComponentSurface")
        let openedChipID = try #require(asString(openedChip["id"]))
        #expect(asString(asObject(openedChip["payload"])?["surfaceID"]) == openedChipID)
        #expect(counters(try await chat.get(keypath: "state", requester: owner)) == before)

        _ = try await chat.set(
            keypath: "ui.dismissComponentSurface",
            value: .object(["interacted": .object(["id": .string(openedChipID)])]),
            requester: owner
        )
        let dismissedState = try #require(asObject(try await chat.get(keypath: "state", requester: owner)))
        let dismissedUI = try #require(asObject(dismissedState["ui"]))
        #expect(asList(dismissedUI["activeToolChips"])?.isEmpty == true)

        _ = try await chat.set(keypath: "assistant.acceptSuggestion", value: .object([:]), requester: owner)
        let afterAccept = counters(try await chat.get(keypath: "state", requester: owner))
        #expect(afterAccept.pollCount == before.pollCount + 1)
    }

    @Test func negativePromptDoesNotOpenPollHelper() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-negative")
        let chat = await BindingPersonalChatHubCell(owner: owner)

        let analyze = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string("Ikke lag avstemning, jeg bare nevner at temaet kom opp.")]),
            requester: owner
        ) ?? .null))
        let suggestion = try #require(asObject(analyze["suggestion"]))
        #expect(asString(suggestion["status"]) == "low_confidence")
        #expect(asString(suggestion["kind"]) != "create_poll")
        #expect(asString(suggestion["negativeIntent"]) == "create_poll")

        let open = try #require(asObject(try await chat.set(
            keypath: "ui.openSuggestedHelper",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asBool(open["ok"]) == false)
        #expect(asBool(open["sideEffect"]) == false)
    }

    @Test func inviteOnlySendAndMeetingBridgeStayGuarded() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-safety")
        let chat = await BindingPersonalChatHubCell(owner: owner)

        let bridge = try #require(asObject(try await chat.get(keypath: "meetingBridge", requester: owner)))
        #expect(asString(bridge["v1RenderMode"]) == "placeholder")
        #expect(asBool(bridge["requiresCameraMicrophoneConsent"]) == true)
        #expect(asBool(bridge["nativePermissionsRequested"]) == false)
        #expect(asList(try await chat.get(keypath: "threads", requester: owner))?.isEmpty == true)

        _ = try await chat.set(keypath: "setComposer", value: .string("Hei"), requester: owner)
        let blockedBeforeInvite = try #require(asObject(try await chat.set(
            keypath: "sendComposedMessage",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asString(blockedBeforeInvite["status"]) == "blocked")
        #expect(asString(blockedBeforeInvite["userMessage"]) != nil)

        _ = try await chat.set(keypath: "acceptInvite", value: .object([:]), requester: owner)
        _ = try await chat.set(keypath: "blockUser", value: .string("participant-1"), requester: owner)
        let blockedAfterBlock = try #require(asObject(try await chat.set(
            keypath: "sendComposedMessage",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asString(blockedAfterBlock["status"]) == "blocked")
        #expect(asString(blockedAfterBlock["userMessage"]) != nil)
    }

    @Test func voiceTranscriptFillsComposerAndAnalyzeStaysSideEffectFree() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-voice")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let before = counters(try await chat.get(keypath: "state", requester: owner))

        let result = try #require(asObject(try await chat.set(
            keypath: "voice.acceptTranscriptAndAnalyze",
            value: .object(["transcript": .string("vi trenger avstemning om lunsj")]),
            requester: owner
        ) ?? .null))
        #expect(asString(result["status"]) == "committed_and_analyzed")
        #expect(asBool(result["sideEffect"]) == false)

        let state = try #require(asObject(try await chat.get(keypath: "state", requester: owner)))
        let currentThread = try #require(asObject(state["currentThread"]))
        let composer = try #require(asObject(currentThread["composer"]))
        #expect(asString(composer["body"]) == "vi trenger avstemning om lunsj")
        #expect(asString(asObject(state["voice"])?["lastCommittedTranscript"]) == "vi trenger avstemning om lunsj")
        #expect(counters(.object(state)) == before)

        let analysis = try #require(asObject(result["analysis"]))
        #expect(asBool(analysis["sideEffect"]) == false)
        #expect(asString(asObject(analysis["suggestion"])?["helperID"]) == "poll")
    }

    @Test func capabilityGapRequiresOptInBeforeSuggestionAndSubmit() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-capability-gap")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let prompt = "skulle ønske chatten kunne lage en Gantt-visning for prosjekter"

        let off = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string(prompt)]),
            requester: owner
        ) ?? .null))
        #expect(asString(asObject(off["suggestion"])?["status"]) == "low_confidence")

        _ = try await chat.set(keypath: "ui.setCapabilityDiscoveryEnabled", value: .bool(true), requester: owner)
        let on = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string(prompt)]),
            requester: owner
        ) ?? .null))
        #expect(asString(asObject(on["suggestion"])?["kind"]) == "capability_request")
        #expect(asString(asObject(on["suggestion"])?["helperID"]) == "capability-request")

        let before = counters(try await chat.get(keypath: "state", requester: owner))
        let open = try #require(asObject(try await chat.set(
            keypath: "ui.openSuggestedHelper",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asBool(open["sideEffect"]) == false)
        #expect(counters(try await chat.get(keypath: "state", requester: owner)) == before)

        let submitted = try #require(asObject(try await chat.set(
            keypath: "capabilityRequest.submit",
            value: .object(["destination": .string("digipomps")]),
            requester: owner
        ) ?? .null))
        #expect(asBool(submitted["sideEffect"]) == true)
        #expect(counters(try await chat.get(keypath: "state", requester: owner)).workbenchModuleCount == before.workbenchModuleCount + 1)
    }

    @Test func resourceRouterAndPortholeUIFollowCellScaffoldPromptContract() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-resource-router")
        let chat = await BindingPersonalChatHubCell(owner: owner)

        let mermaid = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string("jeg trenger mermaid diagram")]),
            requester: owner
        ) ?? .null))
        let suggestion = try #require(asObject(mermaid["suggestion"]))
        #expect(asString(suggestion["kind"]) == "resource_match")
        #expect(asString(suggestion["helperID"]) == "mermaid-diagram")
        #expect(asString(suggestion["purposeRef"]) == "personal.diagram.mermaid.render")
        let matches = try #require(asList(mermaid["resourceMatches"]))
        #expect(matches.contains {
            let match = asObject($0)
            return asString(match?["kind"]) == "cell_configuration"
                && asString(match?["title"]) == "Mermaid Renderer Playground"
                && asString(match?["sourceCellEndpoint"]) == "cell:///MermaidRenderer"
                && asStringList(match?["purposeRefs"]).contains("personal.diagram.mermaid.render")
        })
        let libraryPrompt = try #require(asObject(mermaid["portholeUI"]))
        #expect(asBool(libraryPrompt["openLibrary"]) == false)
        #expect(asString(libraryPrompt["configurationName"]) == "Mermaid Renderer Playground")
        let stateAfterAnalysis = try #require(asObject(try await chat.get(keypath: "state", requester: owner)))
        let promptMessages = asList(asObject(stateAfterAnalysis["ui"])?["promptMessages"]) ?? []
        #expect(promptMessages.contains {
            let row = asObject($0)
            return asString(row?["helperID"]) == "mermaid-diagram"
                && (asString(row?["body"]) ?? "").contains("Mermaid Renderer Playground")
        })

        let beforeOpen = counters(.object(stateAfterAnalysis))
        let opened = try #require(asObject(try await chat.set(
            keypath: "ui.openSuggestedHelper",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asBool(opened["sideEffect"]) == false)
        #expect(asString(opened["helper"]) == "mermaid-diagram")
        let openedState = try #require(asObject(opened["state"]))
        let openedUI = try #require(asObject(openedState["ui"]))
        #expect(asString(openedUI["activeTab"]) == "samtale")
        #expect(asString(openedUI["activeHelper"]) == "mermaid-diagram")
        #expect(asList(openedUI["activeHelpers"])?.contains {
            asString(asObject($0)?["id"]) == "mermaid-diagram"
        } == true)
        #expect(counters(.object(openedState)) == beforeOpen)

        let query = try #require(asObject(try await chat.set(
            keypath: "assistant.queryResource",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asString(query["status"]) == "library_open_requested")
        let openLibrary = try #require(asObject(query["portholeUI"]))
        #expect(asBool(openLibrary["openLibrary"]) == true)
        #expect(asBool(openLibrary["focusLibrary"]) == true)

        let porthole = try #require(asObject(try await chat.set(
            keypath: "assistant.analyzeDraft",
            value: .object(["text": .string("vis Porthole verktøy og åpne bibliotek")]),
            requester: owner
        ) ?? .null))
        let portholeUI = try #require(asObject(porthole["portholeUI"]))
        #expect(asBool(portholeUI["showProductChrome"]) == true)
        #expect(asBool(portholeUI["showToolbarDetails"]) == true)
        #expect(asBool(portholeUI["openLibrary"]) == true)
        #expect((asList(portholeUI["expandMenus"]) ?? []).count >= 3)
        #expect(asString(asObject(porthole["suggestion"])?["status"]) == "low_confidence")
    }

    @Test func matchedResourceChipOpensResourceRouterHelperNotInvite() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-arendalsuka-resource-chip")
        let chat = await BindingPersonalChatHubCell(owner: owner)
        let initialState = try #require(asObject(try await chat.get(keypath: "chatHub.state", requester: owner)))
        let initialUI = try #require(asObject(initialState["ui"]))
        #expect(asString(initialUI["activeHelper"]) == "")
        #expect((asList(initialUI["activeHelpers"]) ?? []).isEmpty)

        let before = counters(.object(initialState))
        let opened = try #require(asObject(try await chat.set(
            keypath: "chatHub.ui.openMatchedResourceLibrary",
            value: .object([
                "configurationName": .string("Arendalsuka Participant Program"),
                "sourceCellEndpoint": .string("cell://staging.haven.digipomps.org/ArendalsukaParticipantProgram"),
                "resourceID": .string("configuration:arendalsuka-participant-program"),
                "autoOpen": .bool(false)
            ]),
            requester: owner
        ) ?? .null))

        #expect(asBool(opened["sideEffect"]) == false)
        #expect(asString(opened["status"]) == "library_open_requested")
        let ui = try #require(asObject(opened["ui"]))
        #expect(asString(ui["activeHelper"]) == "resource-router")
        let activeHelpers = asList(ui["activeHelpers"]) ?? []
        #expect(activeHelpers.contains { asString(asObject($0)?["id"]) == "resource-router" })
        #expect(!activeHelpers.contains { asString(asObject($0)?["id"]) == "invite" })

        let openedState = try #require(asObject(opened["state"]))
        let assistant = try #require(asObject(openedState["assistant"]))
        #expect((asList(assistant["resourceMatches"]) ?? []).contains {
            asString(asObject($0)?["title"]) == "Arendalsuka Participant Program"
        })
        #expect(counters(.object(openedState)) == before)
    }

    @Test func conversationPromptLogStaysCompactForSplitWorkbench() throws {
        let configuration = ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        let skeleton = try #require(configuration.skeleton)
        let promptLog = try #require(skeletonList(
            keypath: "chatHub.state.ui.promptMessages",
            in: skeleton
        ))
        #expect(promptLog.modifiers?.styleRole == "chat-prompt-log")
        #expect((promptLog.modifiers?.height ?? 0) <= 112)
    }

    @Test func sendComposedMessageCreatesThreadReadModel() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await signedOwner("binding-chat-thread-readmodel")
        let chat = await BindingPersonalChatHubCell(owner: owner)

        #expect(asList(try await chat.get(keypath: "threads", requester: owner))?.isEmpty == true)
        _ = try await chat.set(keypath: "acceptInvite", value: .object([:]), requester: owner)
        _ = try await chat.set(
            keypath: "setComposer",
            value: .string("Hei, la oss teste trådloggen"),
            requester: owner
        )
        let sent = try #require(asObject(try await chat.set(
            keypath: "sendComposedMessage",
            value: .object([:]),
            requester: owner
        ) ?? .null))
        #expect(asString(sent["status"]) == "ok")

        let state = try #require(asObject(try await chat.get(keypath: "state", requester: owner)))
        let messages = try #require(asList(state["messages"]))
        let firstMessage = try #require(asObject(messages.first))
        #expect(asString(firstMessage["threadID"]) == "local-copilot-thread")
        #expect(asString(firstMessage["body"]) == "Hei, la oss teste trådloggen")
        let threads = try #require(asList(state["threads"]))
        #expect(threads.count == 1)
        let firstThread = try #require(asObject(threads.first))
        #expect(asString(firstThread["id"]) == "local-copilot-thread")
        #expect(asString(firstThread["lastMessagePreview"])?.contains("teste trådloggen") == true)
        #expect(asInt(firstThread["messageCount"]) == 1)
        #expect(asInt(state["threadCount"]) == 1)
        let currentThread = try #require(asObject(state["currentThread"]))
        #expect(asInt(currentThread["messageCount"]) == 1)
        #expect(asString(asObject(currentThread["composer"])?["body"]) == "")

        let selected = try #require(asObject(try await chat.set(
            keypath: "ui.setCurrentThread",
            value: .string("local-copilot-thread"),
            requester: owner
        ) ?? .null))
        #expect(asBool(selected["sideEffect"]) == false)
        #expect(asString(selected["threadID"]) == "local-copilot-thread")
    }

    @Test func providerEvaluationRunnerUsesCellScaffoldFixtureForLocalProviders() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let data = try Data(contentsOf: fixtureURL())
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"targetSurface\": \"Co-Pilot Chat\""))
        for provider in [
            BindingChatPromptProviderUnderTest.deterministicLocalRules,
            BindingChatPromptProviderUnderTest.appleIntelligence,
            BindingChatPromptProviderUnderTest.localLLM
        ] {
            let outcomes = try await BindingChatPromptEvaluationRunner.evaluate(suiteData: data, provider: provider)
            let failures = outcomes.filter { !$0.matchesExpected }
            let failedIDs = failures.map(\.caseID).joined(separator: ", ")
            #expect(failures.isEmpty, "\(provider.rawValue) failed \(failures.count) prompt-eval cases: \(failedIDs)")
        }
    }

    private func counters(_ value: ValueType?) -> (threadCount: Int, pollCount: Int, workbenchModuleCount: Int) {
        guard let state = asObject(value) else { return (0, 0, 0) }
        return (
            asInt(state["threadCount"]) ?? 0,
            asList(state["polls"])?.count ?? 0,
            asInt(asObject(state["workbench"])?["moduleCount"]) ?? 0
        )
    }

    private func fixtureURL() throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let localFixture = repoRoot
            .appendingPathComponent("Tests", isDirectory: true)
            .appendingPathComponent("fixtures", isDirectory: true)
            .appendingPathComponent("personal_chat_prompt_evaluation.json")
        if FileManager.default.fileExists(atPath: localFixture.path) {
            return localFixture
        }

        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        for _ in 0..<6 {
            let candidate = directory
                .appendingPathComponent("Tests", isDirectory: true)
                .appendingPathComponent("fixtures", isDirectory: true)
                .appendingPathComponent("personal_chat_prompt_evaluation.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }
        throw FixtureError.missing
    }

    private enum FixtureError: Error {
        case missing
    }

    private func skeletonList(keypath: String, in element: SkeletonElement) -> SkeletonList? {
        switch element {
        case .List(let list):
            return list.keypath == keypath ? list : nil
        case .VStack(let stack):
            return stack.elements.lazy.compactMap { skeletonList(keypath: keypath, in: $0) }.first
        case .HStack(let stack):
            return stack.elements.lazy.compactMap { skeletonList(keypath: keypath, in: $0) }.first
        case .ScrollView(let scroll):
            return scroll.elements.lazy.compactMap { skeletonList(keypath: keypath, in: $0) }.first
        case .Section(let section):
            if let header = section.header,
               let match = skeletonList(keypath: keypath, in: header) {
                return match
            }
            if let match = section.content.lazy.compactMap({ skeletonList(keypath: keypath, in: $0) }).first {
                return match
            }
            if let footer = section.footer {
                return skeletonList(keypath: keypath, in: footer)
            }
            return nil
        case .Reference(let reference):
            return reference.flowElementSkeleton.flatMap {
                skeletonList(keypath: keypath, in: .VStack($0))
            }
        case .Grid(let grid):
            return grid.elements.lazy.compactMap { skeletonList(keypath: keypath, in: $0) }.first
        case .ZStack(let stack):
            return stack.elements.lazy.compactMap { skeletonList(keypath: keypath, in: $0) }.first
        case .Object(let object):
            return object.elements.values.lazy.compactMap { skeletonList(keypath: keypath, in: $0) }.first
        case .Tabs(let tabs):
            return tabs.panels.lazy.compactMap { panel in
                panel.content.lazy.compactMap { skeletonList(keypath: keypath, in: $0) }.first
            }.first
        default:
            return nil
        }
    }

    private func signedContactRequest(
        endpointId: String,
        nonce: String,
        requester: Identity,
        issuedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(300),
        payload: Object = ["message": .string("Can we talk?")]
    ) async throws -> Object {
        var request: Object = [
            "schema": .string("cellprotocol.contact.request.v1"),
            "endpointId": .string(endpointId),
            "nonce": .string(nonce),
            "issuedAt": .float(issuedAt.timeIntervalSince1970),
            "expiresAt": .float(expiresAt.timeIntervalSince1970),
            "requesterIdentity": .identity(requester),
            "requesterDomain": .string("domain:binding-smoke"),
            "topic": .string("contact.message"),
            "purpose": .string("purpose://contact.introduction"),
            "requestedAction": .string("contact.request.submit"),
            "payload": .object(payload)
        ]
        let canonical = try FlowCanonicalEncoder.canonicalData(for: .object(request))
        let signature = try #require(try await requester.sign(data: canonical))
        request["signature"] = .data(signature)
        return request
    }

    private func signedOwner(_ context: String) async -> Identity {
        let vault = EphemeralIdentityVault()
        guard let owner = await vault.identity(
            for: "\(context)-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ) else {
            fatalError("Could not create signed owner identity for \(context).")
        }
        return owner
    }

    private func signingIdentities() async -> (Identity, Identity) {
        let previousVault = CellBase.defaultIdentityVault
        let vault = await BindingStartupIdentityVault.shared.initialize()
        CellBase.defaultIdentityVault = vault
        let owner = await vault.identity(for: "binding-contact-owner-\(UUID().uuidString)", makeNewIfNotFound: true)!
        let requester = await vault.identity(for: "binding-contact-requester-\(UUID().uuidString)", makeNewIfNotFound: true)!
        CellBase.defaultIdentityVault = previousVault
        return (owner, requester)
    }
}

private func encodedSkeletonString(_ skeleton: SkeletonElement?) -> String? {
    guard let skeleton,
          let data = try? JSONEncoder().encode(skeleton) else {
        return nil
    }
    return String(decoding: data, as: UTF8.self)
}

private func expectDenied(_ action: () async throws -> ValueType?) async {
    do {
        let value = try await action() ?? .null
        #expect(asString(value) == "denied")
    } catch CellAuthorizationError.denied(let decision) {
        #expect(decision.allowed == false)
        #expect(decision.requiredAction != nil)
    } catch {
        #expect(Bool(false))
    }
}

private func asObject(_ value: ValueType?) -> Object? {
    guard case let .object(object)? = value else { return nil }
    return object
}

private func asList(_ value: ValueType?) -> ValueTypeList? {
    guard case let .list(list)? = value else { return nil }
    return list
}

private func asString(_ value: ValueType?) -> String? {
    guard case let .string(text)? = value else { return nil }
    return text
}

private func asBool(_ value: ValueType?) -> Bool? {
    guard case let .bool(flag)? = value else { return nil }
    return flag
}

private func asInt(_ value: ValueType?) -> Int? {
    guard case let .integer(number)? = value else { return nil }
    return number
}

private func asStringList(_ value: ValueType?) -> [String] {
    guard case let .list(list)? = value else { return [] }
    return list.compactMap { asString($0) }
}
