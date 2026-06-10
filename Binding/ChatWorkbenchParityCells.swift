// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase
#if canImport(FoundationModels)
import FoundationModels
#endif

struct BindingChatIntentClassification: Codable, Equatable {
    var intentKind: String
    var purposeRef: String
    var interests: [String]
    var helperID: String
    var confidence: Double
    var requiresUserApproval: Bool
    var reason: String
    var negativeIntent: String
    var status: String

    nonisolated var shouldSuggest: Bool {
        status != "low_confidence" && confidence >= 0.68 && negativeIntent.isEmpty
    }

    nonisolated func objectValue() -> Object {
        [
            "kind": .string(intentKind),
            "intentKind": .string(intentKind),
            "purposeRef": .string(purposeRef),
            "interests": .list(interests.map(ValueType.string)),
            "helperID": .string(helperID),
            "confidence": .float(confidence),
            "requiresUserApproval": .bool(requiresUserApproval),
            "reason": .string(reason),
            "negativeIntent": negativeIntent.isEmpty ? .null : .string(negativeIntent),
            "status": .string(status),
            "explanation": .string(explanation)
        ]
    }

    nonisolated var explanation: String {
        guard shouldSuggest else {
            if !negativeIntent.isEmpty {
                return "Jeg fant et mulig onnske om \(negativeIntent), men brukeren ba eksplisitt om at det ikke skal gjores."
            }
            return "Ingen trygg hjelper ble valgt. Meldingen kan bli staende som vanlig chat."
        }

        switch helperID {
        case "invite":
            return "Jeg kan apne invite-hjelperen slik at du kan velge person og sende invitasjon selv."
        case "poll":
            return "Jeg kan apne poll-hjelperen uten aa opprette avstemning for du bekrefter."
        case "idea-capture":
            return "Jeg kan apne ide-hjelperen som et privat utkast."
        case "todo":
            return "Jeg kan apne oppgave-hjelperen som et utkast."
        case "project":
            return "Jeg kan apne prosjekt-hjelperen for aa strukturere ideen."
        case "reminder":
            return "Jeg kan apne paaminnelse-hjelperen. Ingen systempaaminnelse lages for du bekrefter."
        case "meeting":
            return "Jeg kan apne mote-hjelperen. Kalender, kamera og mikrofon brukes ikke uten egen capability og samtykke."
        case "agent-review":
            return "Jeg kan apne agent-review. Dette blir bare et signeringsutkast, ikke direkte script-kjoring."
        case "agent-setup":
            return "Jeg kan vise enkleste HAVENAgentD-oppsett for dette formaalet. Ingen agentjobb startes uten eksplisitt handling."
        case "capability-request":
            return "Jeg kan apne behovsflaten som et lokalt utkast. Ingenting sendes videre for du bekrefter."
        case "resource-router":
            return "Jeg fant en synlig flate som passer. Apne hjelperen for aa filtrere Library uten aa laste eller kjore noe automatisk."
        default:
            return reason
        }
    }
}

struct BindingChatProviderDescriptor: Codable, Equatable {
    var id: String
    var kind: String
    var title: String
    var summary: String
    var endpoint: String?
    var sourceCellName: String?
    var actionKeypath: String?
    var purposeRefs: [String]
    var interests: [String]
    var availability: String
    var privacyLevel: String
    var executionScope: String
    var requiresUserApproval: Bool
    var requiresNetwork: Bool
    var canInvokeFromChat: Bool
    var score: Double
    var reason: String

    nonisolated func objectValue() -> Object {
        [
            "id": .string(id),
            "providerID": .string(id),
            "kind": .string(kind),
            "title": .string(title),
            "summary": .string(summary),
            "endpoint": endpoint.map(ValueType.string) ?? .null,
            "sourceCellName": sourceCellName.map(ValueType.string) ?? .null,
            "actionKeypath": actionKeypath.map(ValueType.string) ?? .null,
            "purposeRefs": .list(purposeRefs.map(ValueType.string)),
            "interests": .list(interests.map(ValueType.string)),
            "availability": .string(availability),
            "privacyLevel": .string(privacyLevel),
            "executionScope": .string(executionScope),
            "requiresUserApproval": .bool(requiresUserApproval),
            "requiresNetwork": .bool(requiresNetwork),
            "canInvokeFromChat": .bool(canInvokeFromChat),
            "score": .float(score),
            "reason": .string(reason)
        ]
    }
}

struct BindingHavenAgentDStatusSnapshot: Codable, Equatable {
    var status: String
    var agentBinaryPath: String
    var mcpBinaryPath: String
    var configPath: String
    var starterAuthPath: String
    var agentBinaryExists: Bool
    var mcpBinaryExists: Bool
    var configExists: Bool
    var deviceActionRelayConfigured: Bool
    var starterAuthExists: Bool
    var starterAuthValid: Bool
    var starterAuthExpiresAt: String?
    var recommendedNextStep: String
    var instructions: [String]

    nonisolated var isReadyForPhoneCodexQueue: Bool {
        status == "ready_for_mcp"
    }

    nonisolated func objectValue() -> Object {
        [
            "status": .string(status),
            "agentBinaryPath": .string(agentBinaryPath),
            "mcpBinaryPath": .string(mcpBinaryPath),
            "configPath": .string(configPath),
            "starterAuthPath": .string(starterAuthPath),
            "agentBinaryExists": .bool(agentBinaryExists),
            "mcpBinaryExists": .bool(mcpBinaryExists),
            "configExists": .bool(configExists),
            "deviceActionRelayConfigured": .bool(deviceActionRelayConfigured),
            "starterAuthExists": .bool(starterAuthExists),
            "starterAuthValid": .bool(starterAuthValid),
            "starterAuthExpiresAt": starterAuthExpiresAt.map(ValueType.string) ?? .null,
            "recommendedNextStep": .string(recommendedNextStep),
            "instructions": .list(instructions.map(ValueType.string))
        ]
    }
}

enum BindingHavenAgentDStatusProvider {
    nonisolated static func snapshot(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: Date = Date()
    ) -> BindingHavenAgentDStatusSnapshot {
        let home = environment["HOME"] ?? fileManager.homeDirectoryForCurrentUser.path
        let repoRoot = environment["BINDING_REPO_ROOT"]
            ?? "/Users/kjetil/Build/Digipomps/HAVEN/Binding"
        let agentBinaryPath = normalizedPath(
            environment["BINDING_HAVEN_AGENTD_BINARY"]
                ?? "\(repoRoot)/HavenAgentD/.build/debug/haven-agentd"
        )
        let mcpBinaryPath = normalizedPath(
            environment["BINDING_HAVEN_AGENTD_MCP_BINARY"]
                ?? "\(repoRoot)/HavenAgentD/.build/debug/haven-agentd-mcp"
        )
        let configPath = normalizedPath(
            environment["BINDING_HAVEN_AGENTD_CONFIG"]
                ?? environment["HAVEN_AGENT_CONFIG"]
                ?? "\(home)/Library/Application Support/HAVENAgent/config.json"
        )
        let starterAuthPath = normalizedPath(
            environment["BINDING_HAVEN_AGENTD_STARTER_AUTH"]
                ?? "\(URL(fileURLWithPath: configPath).deletingLastPathComponent().path)/starter-auth.json"
        )

        let agentBinaryExists = isExecutableFile(at: agentBinaryPath, fileManager: fileManager)
        let mcpBinaryExists = isExecutableFile(at: mcpBinaryPath, fileManager: fileManager)
        let configExists = fileManager.fileExists(atPath: configPath)
        let configObject = jsonObject(at: configPath)
        let deviceActionRelayConfigured = relayEnabled(in: configObject)
        let starterAuthExists = fileManager.fileExists(atPath: starterAuthPath)
        let starterObject = jsonObject(at: starterAuthPath)
        let starterAuthExpiresAt = stringValue(starterObject?["expiresAt"])
            ?? stringValue((starterObject?["claims"] as? [String: Any])?["expiresAt"])
        let starterAuthValid = starterAuthExists && starterStillValid(expiresAt: starterAuthExpiresAt, now: now)

        let status: String
        let nextStep: String
        let instructions: [String]

        if !agentBinaryExists || !mcpBinaryExists {
            status = "missing_binaries"
            nextStep = "build_haven_agentd_binaries"
            instructions = [
                "Bygg haven-agentd og haven-agentd-mcp fra Binding/HavenAgentD.",
                "Deretter valider aktiv agent-config før chatten foreslår telefon/Codex-flyt."
            ]
        } else if !configExists {
            status = "missing_config"
            nextStep = "open_agent_setup_workbench"
            instructions = [
                "Åpne Agent Setup Workbench i Binding.",
                "Lag eller velg aktiv config på \(configPath)."
            ]
        } else if !deviceActionRelayConfigured {
            status = "device_action_relay_missing"
            nextStep = "enable_device_action_relay"
            instructions = [
                "Legg inn deviceActionRelay.enabled=true i aktiv HAVENAgentD config.",
                "Kjør validate-config og bootstrap-probe før telefonflyten testes."
            ]
        } else if !starterAuthValid {
            status = starterAuthExists ? "starter_auth_expired" : "starter_auth_missing"
            nextStep = "refresh_starter_auth_with_sprout"
            instructions = [
                "Refresh starter-auth fra den parede Binding/agent-operator-flyten.",
                "Hvis bootstrap-probe peker på sprout, bruk sprout til å hente fersk admission/evidence."
            ]
        } else {
            status = "ready_for_mcp"
            nextStep = "configure_codex_mcp_host"
            instructions = [
                "Konfigurer Codex/Claude med haven-agentd-mcp over stdio.",
                "Bruk agent.codex.next_prompt for å konsumere telefon-initierte Codex-prompter."
            ]
        }

        return BindingHavenAgentDStatusSnapshot(
            status: status,
            agentBinaryPath: agentBinaryPath,
            mcpBinaryPath: mcpBinaryPath,
            configPath: configPath,
            starterAuthPath: starterAuthPath,
            agentBinaryExists: agentBinaryExists,
            mcpBinaryExists: mcpBinaryExists,
            configExists: configExists,
            deviceActionRelayConfigured: deviceActionRelayConfigured,
            starterAuthExists: starterAuthExists,
            starterAuthValid: starterAuthValid,
            starterAuthExpiresAt: starterAuthExpiresAt,
            recommendedNextStep: nextStep,
            instructions: instructions
        )
    }

    nonisolated private static func normalizedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    nonisolated private static func isExecutableFile(at path: String, fileManager: FileManager) -> Bool {
        fileManager.fileExists(atPath: path) && fileManager.isExecutableFile(atPath: path)
    }

    nonisolated private static func jsonObject(at path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    nonisolated private static func relayEnabled(in object: [String: Any]?) -> Bool {
        guard let relay = object?["deviceActionRelay"] as? [String: Any] else {
            return false
        }
        if let enabled = relay["enabled"] as? Bool {
            return enabled
        }
        if let enabled = relay["enabled"] as? NSNumber {
            return enabled.boolValue
        }
        return false
    }

    nonisolated private static func starterStillValid(expiresAt: String?, now: Date) -> Bool {
        guard let expiresAt,
              let expiry = ISO8601DateFormatter().date(from: expiresAt) else {
            return false
        }
        return expiry > now
    }

    nonisolated private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }
}

struct BindingAgentUseDecision: Codable, Equatable {
    var shouldSuggest: Bool
    var reason: String
    var confidence: Double
    var requiredCapability: String
    var agentStatus: String
    var recommendedNextStep: String
    var instructions: [String]

    nonisolated func objectValue() -> Object {
        [
            "shouldSuggest": .bool(shouldSuggest),
            "reason": .string(reason),
            "confidence": .float(confidence),
            "requiredCapability": .string(requiredCapability),
            "agentStatus": .string(agentStatus),
            "recommendedNextStep": .string(recommendedNextStep),
            "instructions": .list(instructions.map(ValueType.string))
        ]
    }

    nonisolated static func decide(
        prompt: String,
        suggestion: BindingChatIntentClassification,
        perspectiveSummary: Object,
        agentStatus: BindingHavenAgentDStatusSnapshot
    ) -> BindingAgentUseDecision {
        let normalized = BindingChatValue.normalized(prompt)
        let context = normalized + " " + flattenedPerspectiveText(perspectiveSummary)
        let wantsPhoneCodex = containsAny(context, ["codex", "kodeassistent", "kode assistent", "coding assistant"])
            && containsAny(context, ["telefon", "phone", "varsle", "notifikasjon", "notification", "sett i gang", "start prompt", "start jobb"])
        let wantsOperatorApproval = containsAny(context, ["godkjenning", "tillatelse", "approval", "spør meg", "spor meg", "ask me"])
            && containsAny(context, ["telefon", "phone", "kode", "codex", "agent"])
        let wantsLocalAgent = suggestion.helperID == "agent-review"
            || suggestion.helperID == "agent-setup"
            || containsAny(context, ["havenagentd", "haven agent", "local agent", "lokal agent", "sprout", "porthole"])

        let capability: String
        let confidence: Double
        let reason: String

        if wantsPhoneCodex {
            capability = "phone_originated_codex_prompt"
            confidence = agentStatus.isReadyForPhoneCodexQueue ? 0.9 : 0.86
            reason = "Formålet passer med telefon-initiert Codex-prompt via HAVENAgentD MCP-kø."
        } else if wantsOperatorApproval {
            capability = "phone_operator_approval"
            confidence = agentStatus.isReadyForPhoneCodexQueue ? 0.86 : 0.82
            reason = "Formålet krever telefonvarsling og eksplisitt operator-svar før kodeassistenten fortsetter."
        } else if wantsLocalAgent {
            capability = "local_agent_review"
            confidence = max(0.72, suggestion.confidence)
            reason = "Formålet passer bedre med HAVENAgentD enn vanlig chat fordi det krever lokal agentstatus eller review-boundary."
        } else {
            return BindingAgentUseDecision(
                shouldSuggest: false,
                reason: "Ingen agent-spesifikk capability ble nødvendig for utkastet.",
                confidence: 0.2,
                requiredCapability: "none",
                agentStatus: agentStatus.status,
                recommendedNextStep: "continue_in_chat",
                instructions: []
            )
        }

        return BindingAgentUseDecision(
            shouldSuggest: true,
            reason: reason,
            confidence: confidence,
            requiredCapability: capability,
            agentStatus: agentStatus.status,
            recommendedNextStep: agentStatus.recommendedNextStep,
            instructions: agentStatus.instructions
        )
    }

    nonisolated private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    nonisolated private static func flattenedPerspectiveText(_ object: Object) -> String {
        object.values.flatMap(flattenedStrings(from:)).joined(separator: " ")
    }

    nonisolated private static func flattenedStrings(from value: ValueType) -> [String] {
        switch value {
        case let .string(text):
            return [BindingChatValue.normalized(text)]
        case let .list(values):
            return values.flatMap(flattenedStrings(from:))
        case let .object(object):
            return object.values.flatMap(flattenedStrings(from:))
        default:
            return []
        }
    }
}

enum BindingChatValue {
    nonisolated static func string(_ value: ValueType?) -> String? {
        guard case let .string(text)? = value else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated static func bool(_ value: ValueType?) -> Bool? {
        guard case let .bool(flag)? = value else { return nil }
        return flag
    }

    nonisolated static func object(_ value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    nonisolated static func list(_ value: ValueType?) -> ValueTypeList? {
        guard case let .list(list)? = value else { return nil }
        return list
    }

    nonisolated static func stringList(_ value: ValueType?) -> [String] {
        guard case let .list(list)? = value else { return [] }
        return list.compactMap { string($0) }
    }

    nonisolated static func double(_ value: ValueType?) -> Double? {
        switch value {
        case let .float(value)?: return value
        case let .number(value)?: return Double(value)
        case let .integer(value)?: return Double(value)
        default: return nil
        }
    }

    nonisolated static func nested(_ dottedKey: String, in object: Object) -> ValueType? {
        nested(Array(dottedKey.split(separator: ".").map(String.init)), in: object)
    }

    nonisolated static func nested(_ path: [String], in object: Object) -> ValueType? {
        guard let first = path.first else { return .object(object) }
        guard let value = object[first] else { return nil }
        guard path.count > 1 else { return value }
        guard case let .object(child) = value else { return nil }
        return nested(Array(path.dropFirst()), in: child)
    }

    nonisolated static func set(_ value: ValueType, for dottedKey: String, in object: inout Object) {
        set(value, for: Array(dottedKey.split(separator: ".").map(String.init)), in: &object)
    }

    nonisolated static func set(_ value: ValueType, for path: [String], in object: inout Object) {
        guard let first = path.first else { return }
        guard path.count > 1 else {
            object[first] = value
            return
        }

        var child: Object
        if case let .object(existing)? = object[first] {
            child = existing
        } else {
            child = [:]
        }
        set(value, for: Array(path.dropFirst()), in: &child)
        object[first] = .object(child)
    }

    nonisolated static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}

enum BindingChatIntentClassifier {
    nonisolated static func classify(
        prompt: String,
        capabilityDiscoveryEnabled: Bool = false
    ) -> BindingChatIntentClassification {
        let normalized = BindingChatValue.normalized(prompt)
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return lowConfidence(reason: "Tomt utkast.")
        }

        if isNegated(normalized, keywords: ["avstemning", "poll", "stemme"]) {
            return negative("create_poll", reason: "Brukeren avviste eksplisitt poll.")
        }
        if isNegated(normalized, keywords: ["inviter", "invite"]) || normalized.contains("inviterte") {
            return negative("invite_person", reason: "Dette er ikke et nytt invite-onske.")
        }
        if isNegated(normalized, keywords: ["ide", "idea"]) || normalized.contains("ideen fra") {
            return negative("idea_capture", reason: "Dette er bare referanse til en tidligere ide.")
        }
        if isNegated(normalized, keywords: ["finder", "agent", "script", "lukk"]) {
            return negative("agent_action", reason: "Brukeren vil ikke utfore agenthandlingen.")
        }
        if isNegated(normalized, keywords: ["codex", "start codex", "kodeassistent", "kode assistent", "prompt"]) {
            return negative("agent_codex_prompt", reason: "Brukeren vil ikke starte Codex-prompt.")
        }

        if containsAny(normalized, ["hva sier"]) && containsAny(normalized, ["rag", "dokument", "kilde"]) {
            return lowConfidence(reason: "Dette ser ut som et RAG-sporsmal, ikke en helper-sideeffekt.")
        }
        if containsAny(normalized, ["apple"]) && containsAny(normalized, ["lokal", "privat", "private", "on-device", "assistant"]) {
            return lowConfidence(reason: "Dette er et provider-valg, ikke en helper-handling.")
        }
        if looksLikeCapabilityGap(normalized) {
            guard capabilityDiscoveryEnabled else {
                return lowConfidence(reason: "Dette ser ut som et mulig behov, men behovsradar er av i denne chatten.")
            }
            return positive(
                kind: "capability_request",
                purposeRef: "personal.chat.assist.capability-request",
                interests: ["capability-gap", "feature-request", "user-controlled-submission", "requires-user-approval"],
                helperID: "capability-request",
                confidence: 0.76,
                reason: "Meldingen beskriver et manglende formaal som kan meldes videre bare etter eksplisitt brukerklikk."
            )
        }
        if looksLikePhoneOriginatedCodexPrompt(normalized) {
            return positive(
                kind: "agent_codex_prompt",
                purposeRef: "personal.agent.codex.start-prompt",
                interests: ["agentd", "codex", "phone-originated-prompt", "mcp", "requires-user-approval"],
                helperID: "agent-setup",
                confidence: 0.86,
                reason: "Meldingen ber om telefon-initiert Codex-jobb; chatten skal foreslaa HAVENAgentD-oppsett eller MCP-konsumering."
            )
        }
        if looksLikePhoneOperatorApproval(normalized) {
            return positive(
                kind: "agent_operator_approval",
                purposeRef: "personal.agent.operator-approval.phone",
                interests: ["agentd", "operator-approval", "phone-notification", "requires-user-approval"],
                helperID: "agent-setup",
                confidence: 0.82,
                reason: "Meldingen ber om telefonvarsling eller tillatelse for en kodeassistent-jobb."
            )
        }
        if containsAny(normalized, ["inviter", "invite"]) {
            let ambiguous = containsAny(normalized, ["kollega"]) && !containsAny(normalized, ["nærmeste", "naermeste", "narmeste", "anna"])
            return BindingChatIntentClassification(
                intentKind: "invite_person",
                purposeRef: "personal.chat.assist.invite",
                interests: ["invite-person", "chat", "requires-user-approval"],
                helperID: "invite",
                confidence: ambiguous ? 0.78 : 0.9,
                requiresUserApproval: true,
                reason: ambiguous ? "Meldingen ber om invite, men personvalg er tvetydig." : "Meldingen ber om aa invitere en person.",
                negativeIntent: "",
                status: ambiguous ? "needs_candidate_selection" : "suggested"
            )
        }
        if containsAny(normalized, ["avstemning", "poll", "stemme over"]) {
            return positive(
                kind: "create_poll",
                purposeRef: "personal.chat.assist.poll",
                interests: ["poll", "group-decision", "requires-user-approval"],
                helperID: "poll",
                confidence: 0.9,
                reason: "Meldingen ber om aa lage et valg for gruppen."
            )
        }
        if containsAny(normalized, ["jeg har en ide", "jeg har en idea", "ide jeg ma", "ide jeg maa"]) {
            return positive(
                kind: "idea_capture",
                purposeRef: "personal.chat.assist.idea.capture",
                interests: ["idea", "capture", "private"],
                helperID: "idea-capture",
                confidence: 0.86,
                reason: "Meldingen inneholder et nytt ideutkast."
            )
        }
        if normalized.hasPrefix("oppgave:") || containsAny(normalized, ["todo:", "ma gjore", "maa gjore"]) {
            return positive(
                kind: "todo",
                purposeRef: "personal.chat.assist.todo",
                interests: ["todo", "task", "private"],
                helperID: "todo",
                confidence: 0.86,
                reason: "Meldingen beskriver en oppgave."
            )
        }
        if containsAny(normalized, ["lag prosjekt", "opprett prosjekt", "prosjekt for"]) {
            return positive(
                kind: "project",
                purposeRef: "personal.chat.assist.project",
                interests: ["project", "planning"],
                helperID: "project",
                confidence: 0.84,
                reason: "Meldingen ber om aa strukturere et prosjekt."
            )
        }
        if containsAny(normalized, ["minn meg", "paaminn", "paminn", "remind me"]) {
            return positive(
                kind: "reminder",
                purposeRef: "personal.chat.assist.reminder",
                interests: ["reminder", "time", "requires-user-approval"],
                helperID: "reminder",
                confidence: 0.88,
                reason: "Meldingen ber om en paaminnelse."
            )
        }
        if containsAny(normalized, ["sett opp mote", "sett opp møte", "mote med", "videochat", "video chat"]) {
            return positive(
                kind: containsAny(normalized, ["videochat", "video chat"]) ? "meeting_video" : "schedule_meeting",
                purposeRef: containsAny(normalized, ["videochat", "video chat"]) ? "personal.chat.assist.meeting.video" : "personal.chat.assist.meeting.schedule",
                interests: ["meeting", "calendar-intent", "requires-user-approval"],
                helperID: "meeting",
                confidence: 0.84,
                reason: "Meldingen ber om aa forberede et mote."
            )
        }
        if containsAny(normalized, ["lukk alle finder", "lukke alle finder", "finder vinduer", "script", "agent"]) {
            return positive(
                kind: "agent_action",
                purposeRef: "personal.agent.local.gui.finder.close-windows",
                interests: ["agent-review", "signed-intent", "local-review"],
                helperID: "agent-review",
                confidence: 0.82,
                reason: "Meldingen matcher en lokal agenthandling som bare kan bli et review/signering-utkast."
            )
        }
        if let resource = bestCellConfigurationResourceMatch(prompt: prompt) {
            return resourceMatchClassification(resource)
        }

        return lowConfidence(reason: "Ingen trygg chat-helper traff med hoy nok sikkerhet.")
    }

    nonisolated static func resourceMatches(
        prompt: String,
        grantRAG: Bool = true,
        grantContactEndpoint: Bool = true
    ) -> [Object] {
        let normalized = BindingChatValue.normalized(prompt)
        var matches: [Object] = []
        if looksLikeMusicPublishing(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:music-publishing-console",
                title: "Music Publishing Console",
                summary: "Musikkpublisering for streaming, nedlasting, metadata og leveranser.",
                sourceCellEndpoint: "cell:///MusicPublishingConsole",
                sourceCellName: "MusicPublishingConsoleCell",
                purposeRef: "personal.music.publish",
                interests: ["music", "publishing", "streaming", "download", "distribution", "resource-router"],
                score: 0.86
            ))
        }
        if looksLikeMermaidRenderer(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:mermaid-renderer-playground",
                title: "Mermaid Renderer Playground",
                summary: "Mermaid diagram-rendering med webview/native backend og SVG/PNG presets.",
                sourceCellEndpoint: "cell:///MermaidRenderer",
                sourceCellName: "MermaidRendererCell",
                purposeRef: "personal.diagram.mermaid.render",
                interests: ["mermaid", "diagram", "flowchart", "rendering", "svg", "png", "resource-router"],
                score: 0.9
            ))
        }
        if looksLikeEntityStudio(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:entity-studio",
                title: "Entity Studio",
                summary: "Utforsk private entities, relasjoner, proofs og avtalebaserte representasjoner.",
                sourceCellEndpoint: "cell:///EntityStudio",
                sourceCellName: "EntityStudioCell",
                purposeRef: "personal.entity.relations.manage",
                interests: ["entity", "entities", "relations", "private", "proofs", "resource-router"],
                score: 0.84
            ))
        }
        if looksLikeAdminLifecycle(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:admin-cell-dashboard",
                title: "Admin Cell Dashboard",
                summary: "Read-only admin lifecycle dashboard for orphaned cells and cleanup review.",
                sourceCellEndpoint: "cell:///AdminOverview",
                sourceCellName: "AdminOverviewCell",
                purposeRef: "admin.cell-lifecycle.cleanup-review",
                interests: ["admin", "cell-lifecycle", "orphaned", "cleanup", "staging", "resource-router"],
                score: 0.83
            ))
        }
        if looksLikeConferenceAgenda(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:conference-participant-portal-dashboard",
                title: "Conference Participant Portal Dashboard",
                summary: "Participant dashboard for conference agenda, people, chats, meetings and profile.",
                sourceCellEndpoint: "cell:///ConferenceParticipantPreviewShell",
                sourceCellName: "ConferenceParticipantPreviewShellCell",
                purposeRef: "conference.agenda.view",
                interests: ["conference", "agenda", "participant", "sessions", "event-day", "resource-router"],
                score: 0.88
            ))
        }
        if grantContactEndpoint,
           looksLikeContactEndpoint(normalized),
           isNegated(normalized, keywords: ["send", "melding", "foresporsel", "forespørsel", "kontakt", "endpoint", "endepunkt"]) == false {
            matches.append([
                "kind": .string("contact_endpoint"),
                "title": .string("Kontakt-endepunkt"),
                "summary": .string("Signerbar foresporsel til en annen entitets ContactEndpoint-cell."),
                "endpoint": .string("cell:///ContactEndpoint"),
                "purposeRef": .string("personal.chat.assist.entity-contact-request"),
                "purposeRefs": .list([
                    .string("personal.chat.assist.entity-contact-request"),
                    .string("personal.chat.assist.resource-router")
                ]),
                "interests": .list([
                    .string("contact-endpoint"),
                    .string("entity-extension"),
                    .string("message-request"),
                    .string("requires-user-approval")
                ]),
                "actionKeypath": .string("contact.request"),
                "requiresGrant": .bool(true),
                "requiresSignedIntent": .bool(true),
                "sideEffectUntilExplicitRequest": .bool(false)
            ])
        }
        if containsAny(normalized, ["tilgang", "enhet", "enheter", "sky", "capability", "kapabilitet", "tjeneste", "tjenester", "kva har jeg", "hva har jeg"]) {
            matches.append(contentsOf: [
                [
                    "kind": .string("cell_configuration"),
                    "title": .string("Co-Pilot Chat"),
                    "summary": .string("Requester-visible Co-Pilot Chat CellConfiguration i Binding."),
                    "sourceCellEndpoint": .string("cell:///PersonalChatHub"),
                    "purposeRef": .string("personal.chat.assist.resource-router"),
                    "purposeRefs": .list([.string("personal.chat.assist.resource-router")]),
                    "actionKeypath": .string("assistant.analyzeDraft"),
                    "requiresGrant": .bool(true),
                    "requiresUserApproval": .bool(true)
                ],
                [
                    "kind": .string("agent_action"),
                    "title": .string("HAVENAgentD review"),
                    "summary": .string("Autocomplete-safe lokal agent bridge; chat kan bare opprette signert review-intent."),
                    "sourceCellEndpoint": .string("cell:///agent/intents/inbox"),
                    "purposeRef": .string("personal.agent.binding.wake"),
                    "purposeRefs": .list([
                        .string("personal.agent.binding.wake"),
                        .string("personal.agent.local.gui.finder.close-windows")
                    ]),
                    "actionKeypath": .string("agent.review.create"),
                    "requiresSignedIntent": .bool(true),
                    "requiresLocalReview": .bool(true)
                ]
            ])
        }
        if looksLikeAgendaQuery(normalized) {
            matches.append([
                "kind": .string("agenda_context"),
                "title": .string("Agenda Context"),
                "summary": .string("Owner-local Calendar and Reminders context for dagens agenda og neste gjøremål."),
                "sourceCellEndpoint": .string("cell:///PersonalAgendaContext"),
                "sourceCellName": .string("PersonalAgendaContextCell"),
                "purposeRef": .string("personal.chat.assist.agenda-query"),
                "purposeRefs": .list([
                    .string("personal.chat.assist.agenda-query"),
                    .string("personal.agenda.context.today")
                ]),
                "interests": .list([
                    .string("agenda"),
                    .string("calendar"),
                    .string("reminders"),
                    .string("daily-planning"),
                    .string("agenda-aspects"),
                    .string("requires-user-approval")
                ]),
                "actionKeypath": .string("agenda.answerQuery"),
                "requiresGrant": .bool(true),
                "requiresUserApproval": .bool(true),
                "sideEffectUntilExplicitRequest": .bool(false)
            ])
        }
        if containsAny(normalized, ["finder", "script", "agent"]) {
            matches.append([
                "kind": .string("agent_action"),
                "title": .string("Agent review"),
                "purposeRef": .string("personal.agent.local.gui.finder.close-windows"),
                "purposeRefs": .list([.string("personal.agent.local.gui.finder.close-windows")]),
                "actionKeypath": .string("assistant.acceptSuggestion"),
                "requiresSignedIntent": .bool(true)
            ])
        }
        if grantRAG, containsAny(normalized, ["rag", "dokument", "kilde", "anskaffelser"]) {
            matches.append([
                "kind": .string("rag_case"),
                "title": .string("Tilgjengelig RAG-case"),
                "caseID": .string("innovasjon"),
                "purposeRef": .string("personal.chat.assist.rag-query"),
                "purposeRefs": .list([.string("personal.chat.assist.rag-query")]),
                "actionKeypath": .string("assistant.queryResource"),
                "requiresGrant": .bool(true)
            ])
        }
        return matches
    }

    nonisolated static func bestCellConfigurationResourceMatch(prompt: String) -> Object? {
        resourceMatches(prompt: prompt).first {
            BindingChatValue.string($0["kind"]) == "cell_configuration"
        }
    }

    nonisolated static func portholeUIRequest(for text: String) -> Object? {
        let normalized = BindingChatValue.normalized(text)
        let wantsConfigurationJSON = containsAny(normalized, ["json", "radata", "rådata"])
            && containsAny(normalized, ["cellconfiguration", "cell configuration", "konfigurasjon", "configuration"])
        let asksForPorthole = containsAny(normalized, [
            "porthole", "meny", "menu", "kant", "verktoy", "verktøy", "verktøylinje",
            "verktoylinje", "toolbar", "tool bar", "bibliotek", "library", "katalog"
        ]) || wantsConfigurationJSON
        let asksToShow = containsAny(normalized, [
            "vis", "apne", "åpne", "hent", "frem", "fram", "show", "open", "reveal",
            "skru pa", "skru på", "aktiver"
        ])
        let asksToHide = containsAny(normalized, [
            "skjul", "lukk", "ta bort", "hide", "close", "collapse", "skru av"
        ])
        let asksToToggle = containsAny(normalized, [
            "toggle", "skru av og på", "skru av/på", "av og på", "bytt"
        ])
        guard asksForPorthole && (asksToShow || asksToHide || asksToToggle || wantsConfigurationJSON) else {
            return nil
        }

        let wantsLibrary = containsAny(normalized, ["bibliotek", "library", "katalog"])
        let wantsMenus = containsAny(normalized, ["meny", "menu", "kant", "verktoy", "verktøy"])
        let wantsToolbar = containsAny(normalized, ["toolbar", "tool bar", "verktøylinje", "verktoylinje", "verktoy", "verktøy"])
        let notice: String
        if wantsConfigurationJSON {
            notice = "Åpner JSON for innlastet CellConfiguration."
        } else if asksToHide && wantsMenus {
            notice = "Kantmenyene er skjult."
        } else if asksToToggle && wantsToolbar {
            notice = "Verktøylinjen er togglet."
        } else if wantsLibrary {
            notice = "Porthole-verktøy og bibliotek er åpnet."
        } else {
            notice = "Porthole-verktøyene er oppdatert."
        }
        return [
            "showProductChrome": .bool(asksToHide == false),
            "hideProductChrome": .bool(asksToHide && wantsToolbar && wantsMenus == false && wantsLibrary == false && wantsConfigurationJSON == false),
            "showToolbarDetails": .bool((asksToHide == false && (wantsToolbar || wantsLibrary || wantsMenus || wantsConfigurationJSON)) || wantsConfigurationJSON),
            "hideToolbarDetails": .bool(asksToHide && wantsToolbar),
            "toggleToolbarDetails": .bool(asksToToggle && wantsToolbar),
            "showEdgeMenus": .bool(asksToShow && wantsMenus),
            "hideEdgeMenus": .bool(asksToHide && wantsMenus),
            "toggleEdgeMenus": .bool(asksToToggle && wantsMenus && wantsToolbar == false),
            "openLibrary": .bool(asksToShow && wantsLibrary),
            "closeLibrary": .bool(asksToHide && wantsLibrary),
            "collapseMenus": .bool(asksToHide && wantsMenus),
            "showConfigurationJSON": .bool(wantsConfigurationJSON),
            "expandMenus": (asksToShow && wantsMenus)
                ? .list(["upperLeftMenu", "upperMidMenu", "upperRightMenu"].map(ValueType.string))
                : .list([]),
            "notice": .string(notice)
        ]
    }

    nonisolated static func libraryUIRequest(for resource: Object, autoOpen: Bool) -> Object {
        let title = BindingChatValue.string(resource["title"]) ?? "valgt flate"
        let query = BindingChatValue.string(resource["configurationName"]) ?? title
        var request: Object = [
            "showProductChrome": .bool(autoOpen),
            "showToolbarDetails": .bool(autoOpen),
            "openLibrary": .bool(autoOpen),
            "libraryQuery": .string(query),
            "configurationName": .string(query),
            "sourceCellEndpoint": BindingChatValue.string(resource["sourceCellEndpoint"]).map(ValueType.string) ?? .null,
            "resourceID": BindingChatValue.string(resource["id"]).map(ValueType.string) ?? .string(query),
            "autoOpen": .bool(autoOpen),
            "notice": .string(autoOpen
                ? "Library er åpnet og filtrert til \(title). Velg flaten for å laste den."
                : "Jeg fant \(title). Åpne hjelperen for å filtrere Library til denne flaten.")
        ]
        if autoOpen {
            request["focusLibrary"] = .bool(true)
        }
        return request
    }

    nonisolated private static func resourceMatchClassification(_ resource: Object) -> BindingChatIntentClassification {
        let title = BindingChatValue.string(resource["title"]) ?? "synlig flate"
        let purposeRef = BindingChatValue.stringList(resource["purposeRefs"]).first
            ?? BindingChatValue.string(resource["purposeRef"])
            ?? "personal.chat.assist.resource-router"
        return BindingChatIntentClassification(
            intentKind: "resource_match",
            purposeRef: purposeRef,
            interests: Array(Set(BindingChatValue.stringList(resource["interests"]) + [
                "resource-router",
                "visible-cellconfiguration",
                "requires-user-approval"
            ])).sorted(),
            helperID: "resource-router",
            confidence: BindingChatValue.double(resource["score"]) ?? 0.78,
            requiresUserApproval: true,
            reason: "Fant en synlig CellConfiguration som matcher formaalet: \(title).",
            negativeIntent: "",
            status: "suggested"
        )
    }

    nonisolated private static func positive(
        kind: String,
        purposeRef: String,
        interests: [String],
        helperID: String,
        confidence: Double,
        reason: String
    ) -> BindingChatIntentClassification {
        BindingChatIntentClassification(
            intentKind: kind,
            purposeRef: purposeRef,
            interests: interests,
            helperID: helperID,
            confidence: confidence,
            requiresUserApproval: true,
            reason: reason,
            negativeIntent: "",
            status: "suggested"
        )
    }

    nonisolated private static func lowConfidence(reason: String) -> BindingChatIntentClassification {
        BindingChatIntentClassification(
            intentKind: "none",
            purposeRef: "personal.chat.assist.resource-router",
            interests: [],
            helperID: "",
            confidence: 0.2,
            requiresUserApproval: true,
            reason: reason,
            negativeIntent: "",
            status: "low_confidence"
        )
    }

    nonisolated private static func negative(_ intent: String, reason: String) -> BindingChatIntentClassification {
        BindingChatIntentClassification(
            intentKind: "none",
            purposeRef: "personal.chat.assist.resource-router",
            interests: [],
            helperID: "",
            confidence: 0.1,
            requiresUserApproval: true,
            reason: reason,
            negativeIntent: intent,
            status: "low_confidence"
        )
    }

    nonisolated private static func isNegated(_ text: String, keywords: [String]) -> Bool {
        let negators = ["ikke", "not", "do not", "don't", "dont", "aldri"]
        return keywords.contains { keyword in
            negators.contains { negator in
                text.contains("\(negator) \(keyword)") || text.contains("\(negator) lag \(keyword)") || text.contains("\(negator) lukk")
            }
        }
    }

    nonisolated private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    nonisolated private static func looksLikeCapabilityGap(_ text: String) -> Bool {
        containsAny(text, ["skulle onske", "skulle ønske", "savner", "mangler", "feature request", "meld behov"])
            || (containsAny(text, ["kunne lage", "kunne vise", "kunne hjelpe"]) && containsAny(text, ["chatten", "copiloten", "co-piloten", "assistenten"]))
    }

    nonisolated private static func looksLikePhoneOriginatedCodexPrompt(_ text: String) -> Bool {
        containsAny(text, ["codex", "kodeassistent", "kode assistent", "coding assistant"])
            && containsAny(text, ["telefon", "phone", "notifikasjon", "notification", "varsle", "sett i gang", "starte", "start prompt", "prompt i codex"])
    }

    nonisolated private static func looksLikePhoneOperatorApproval(_ text: String) -> Bool {
        containsAny(text, ["godkjenning", "tillatelse", "approval", "spør meg", "spor meg", "ask me", "varsle meg"])
            && containsAny(text, ["telefon", "phone", "kode", "codex", "agent"])
    }

    nonisolated private static func looksLikeContactEndpoint(_ text: String) -> Bool {
        containsAny(text, [
            "contact.request",
            "contactendpoint",
            "contact endpoint",
            "kontakt-endepunkt",
            "kontakt endepunkt",
            "endpoint-cell",
            "endpoint cell",
            "endepunkt-cell",
            "endepunkt cell",
            "celle endepunkt",
            "celle endpoint",
            "annen entitet",
            "andre entiteter",
            "entitets celle",
            "entitetens celle",
            "send foresporsel",
            "send forespørsel",
            "send melding via",
            "melding via"
        ])
    }

    nonisolated private static func looksLikeAgendaQuery(_ text: String) -> Bool {
        containsAny(text, ["agenda", "kalender", "calendar", "hva skjer", "kva skjer", "hva er pa", "hva er på", "neste gjoremal", "neste gjøremål", "neste mote", "neste møte"])
            || (containsAny(text, ["i dag", "today", "neste", "next"]) && containsAny(text, ["mote", "møte", "reminder", "paaminnelse", "påminnelse", "oppgave", "todo"]))
    }

    nonisolated private static func looksLikeMusicPublishing(_ text: String) -> Bool {
        containsAny(text, ["musikk", "music", "artist", "album", "streaming", "nedlasting", "download"])
            && containsAny(text, ["legg ut", "legge ut", "publiser", "publishing", "release", "streaming", "nedlasting", "download"])
    }

    nonisolated private static func looksLikeMermaidRenderer(_ text: String) -> Bool {
        containsAny(text, ["mermaid"])
            || (containsAny(text, ["diagram", "flowchart", "flytskjema"]) && containsAny(text, ["render", "tegn", "lag", "trenger", "svg", "png"]))
    }

    nonisolated private static func looksLikeEntityStudio(_ text: String) -> Bool {
        containsAny(text, ["entity", "entities", "entitet", "entiteter"])
            && containsAny(text, ["relasjon", "relasjoner", "relations", "private", "mine", "proof", "proofs"])
    }

    nonisolated private static func looksLikeAdminLifecycle(_ text: String) -> Bool {
        containsAny(text, ["orphaned", "foreldrelos", "foreldreløs", "cleanup", "rydde", "livssyklus"])
            && containsAny(text, ["cell", "celler", "staging", "admin"])
    }

    nonisolated private static func looksLikeConferenceAgenda(_ text: String) -> Bool {
        containsAny(text, ["konferanse", "conference"])
            && containsAny(text, ["agenda", "program", "sesjon", "session", "i dag", "today"])
    }

    nonisolated private static func cellConfigurationResource(
        id: String,
        title: String,
        summary: String,
        sourceCellEndpoint: String,
        sourceCellName: String,
        purposeRef: String,
        interests: [String],
        score: Double
    ) -> Object {
        [
            "kind": .string("cell_configuration"),
            "id": .string(id),
            "title": .string(title),
            "summary": .string(summary),
            "purposeRef": .string(purposeRef),
            "purposeRefs": .list([purposeRef, "personal.chat.assist.resource-router"].map(ValueType.string)),
            "interests": .list(Array(Set(interests + [
                "resource-router",
                "visible-cellconfiguration",
                "requires-user-approval"
            ])).sorted().map(ValueType.string)),
            "score": .float(score),
            "availability": .string("visible_configuration"),
            "reason": .string("Matched local CellScaffold chat resource routing fixture."),
            "sourceCellEndpoint": .string(sourceCellEndpoint),
            "sourceCellName": .string(sourceCellName),
            "configurationName": .string(title),
            "actionKeypath": .null,
            "readKeypaths": .list(["configuration", "discovery"].map(ValueType.string)),
            "writeKeypaths": .list([]),
            "requiresGrant": .bool(true),
            "requiresUserApproval": .bool(true),
            "requiresSignedRemoteIntent": .bool(false),
            "requiresLocalReview": .bool(false)
        ]
    }
}

enum BindingChatProviderRouter {
    nonisolated static func localRulesProvider() -> BindingChatProviderDescriptor {
        BindingChatProviderDescriptor(
            id: "chat.local-rules",
            kind: "local_rules",
            title: "Lokale chat-regler",
            summary: "Deterministisk intentmotor for trygge V1-chathelpers.",
            endpoint: "cell:///PersonalChatHub",
            sourceCellName: "BindingPersonalChatHubCell",
            actionKeypath: "assistant.analyzeDraft",
            purposeRefs: [
                "personal.chat.assist.invite",
                "personal.chat.assist.poll",
                "personal.chat.assist.meeting.video",
                "personal.chat.assist.meeting.schedule",
                "personal.chat.assist.project",
                "personal.chat.assist.todo",
                "personal.chat.assist.reminder",
                "personal.chat.assist.capability-request",
                "personal.chat.assist.entity-contact-request",
                "personal.chat.assist.resource-router"
            ],
            interests: ["chat-assistant", "invite-person", "poll", "todo-intent", "project-intent", "reminder-intent", "capability-gap", "contact-endpoint", "local", "no-network", "deterministic"],
            availability: "available_in_chat_cell",
            privacyLevel: "local_chat_state",
            executionScope: "chat_cell",
            requiresUserApproval: true,
            requiresNetwork: false,
            canInvokeFromChat: true,
            score: 0.88,
            reason: "Dekker sikre V1-intenter uten aa bruke modell."
        )
    }

    nonisolated static func descriptor(from state: ValueType, defaultKind: String) -> BindingChatProviderDescriptor? {
        guard let object = BindingChatValue.object(state) else { return nil }
        let providerID = BindingChatValue.string(object["providerID"])
            ?? BindingChatValue.string(object["id"])
            ?? (defaultKind == "apple_intelligence" ? "binding.apple-intelligence" : "binding.local-llm")
        let status = BindingChatValue.string(object["status"]) ?? BindingChatValue.string(object["backendStatus"]) ?? "unknown"
        let kind = BindingChatValue.string(object["kind"]) ?? defaultKind
        return BindingChatProviderDescriptor(
            id: providerID,
            kind: kind,
            title: BindingChatValue.string(object["title"]) ?? (kind == "apple_intelligence" ? "Apple Intelligence" : "Local LLM"),
            summary: BindingChatValue.string(object["summary"]) ?? BindingChatValue.string(object["reason"]) ?? "Cell-scoped provider.",
            endpoint: BindingChatValue.string(object["endpoint"]) ?? (kind == "apple_intelligence" ? "cell:///AppleIntelligence" : "cell:///LocalLLM"),
            sourceCellName: BindingChatValue.string(object["sourceCellName"]) ?? (kind == "apple_intelligence" ? "BindingAppleIntelligenceProviderCell" : "BindingLocalLLMCell"),
            actionKeypath: BindingChatValue.string(object["capability"]) ?? BindingChatValue.string(object["actionKeypath"]) ?? (kind == "apple_intelligence" ? "ai.classifyIntent" : "llm.generate"),
            purposeRefs: BindingChatValue.stringList(object["purposeRefs"]),
            interests: BindingChatValue.stringList(object["interests"]),
            availability: status == "ready" || status == "idle" ? "available_in_cell_scope" : status,
            privacyLevel: BindingChatValue.string(object["privacyLevel"]) ?? (kind == "apple_intelligence" ? "local_device" : "local_device_or_localhost"),
            executionScope: BindingChatValue.string(object["executionScope"]) ?? (kind == "apple_intelligence" ? "binding_chat_scope" : "local_runtime"),
            requiresUserApproval: BindingChatValue.bool(object["requiresUserApproval"]) ?? true,
            requiresNetwork: BindingChatValue.bool(object["requiresNetwork"]) ?? false,
            canInvokeFromChat: BindingChatValue.bool(object["canInvokeFromChat"]) ?? false,
            score: status == "ready" || status == "idle" ? (kind == "apple_intelligence" ? 0.74 : 0.68) : 0.34,
            reason: BindingChatValue.string(object["reason"]) ?? "Provider-state ble funnet i requesterens cell-scope."
        )
    }

    nonisolated static func registeredProvider(from object: Object) -> BindingChatProviderDescriptor? {
        guard let id = BindingChatValue.string(object["id"]) ?? BindingChatValue.string(object["providerID"]) else {
            return nil
        }
        return BindingChatProviderDescriptor(
            id: id,
            kind: BindingChatValue.string(object["kind"]) ?? "custom",
            title: BindingChatValue.string(object["title"]) ?? BindingChatValue.string(object["name"]) ?? id,
            summary: BindingChatValue.string(object["summary"]) ?? BindingChatValue.string(object["description"]) ?? id,
            endpoint: BindingChatValue.string(object["endpoint"]),
            sourceCellName: BindingChatValue.string(object["sourceCellName"]),
            actionKeypath: BindingChatValue.string(object["actionKeypath"]),
            purposeRefs: BindingChatValue.stringList(object["purposeRefs"]),
            interests: BindingChatValue.stringList(object["interests"]),
            availability: BindingChatValue.string(object["availability"]) ?? "declared_in_chat_scope",
            privacyLevel: BindingChatValue.string(object["privacyLevel"]) ?? "owner_scoped",
            executionScope: BindingChatValue.string(object["executionScope"]) ?? "cell_scope",
            requiresUserApproval: BindingChatValue.bool(object["requiresUserApproval"]) ?? true,
            requiresNetwork: BindingChatValue.bool(object["requiresNetwork"]) ?? false,
            canInvokeFromChat: BindingChatValue.bool(object["canInvokeFromChat"]) ?? false,
            score: BindingChatValue.double(object["score"]) ?? 0.5,
            reason: BindingChatValue.string(object["reason"]) ?? "Provideren er deklarert inne i chat-scope."
        )
    }

    nonisolated static func recommend(
        prompt: String,
        suggestion: BindingChatIntentClassification,
        resourceMatches: [Object],
        providers: [BindingChatProviderDescriptor],
        agentStatus: BindingHavenAgentDStatusSnapshot? = nil
    ) -> BindingChatProviderDescriptor {
        let normalized = BindingChatValue.normalized(prompt)
        if resourceMatches.contains(where: { BindingChatValue.string($0["kind"]) == "rag_case" }) {
            return ragProvider()
        }
        if resourceMatches.contains(where: { BindingChatValue.string($0["kind"]) == "agenda_context" }) {
            return agendaProvider()
        }
        if resourceMatches.contains(where: { BindingChatValue.string($0["kind"]) == "contact_endpoint" }) {
            return contactEndpointProvider()
        }
        if suggestion.shouldSuggest,
           ["invite", "poll", "idea-capture", "todo", "project", "reminder", "meeting", "capability-request", "resource-router"].contains(suggestion.helperID) {
            return localRulesProvider()
        }
        if suggestion.helperID == "agent-review"
            || suggestion.helperID == "agent-setup"
            || resourceMatches.contains(where: { BindingChatValue.string($0["kind"]) == "agent_action" }) {
            return agentProvider(status: agentStatus)
        }
        if normalized.contains("apple") || normalized.contains("privat") || normalized.contains("on-device") {
            if let apple = providers.first(where: { $0.kind == "apple_intelligence" && isAvailable($0) }) {
                return apple
            }
        }
        if normalized.contains("llm") || normalized.contains("modell") || normalized.contains("offline") || normalized.contains("localhost") {
            if let localLLM = providers.first(where: { $0.kind == "local_llm" && isAvailable($0) }) {
                return localLLM
            }
        }
        if let apple = providers.first(where: { $0.kind == "apple_intelligence" && isAvailable($0) }) {
            return apple
        }
        if let localLLM = providers.first(where: { $0.kind == "local_llm" && isAvailable($0) }) {
            return localLLM
        }
        return localRulesProvider()
    }

    nonisolated private static func isAvailable(_ provider: BindingChatProviderDescriptor) -> Bool {
        provider.availability == "available_in_cell_scope"
            || provider.availability == "available_in_chat_scope"
            || provider.availability == "ready"
            || provider.availability == "idle"
    }

    nonisolated private static func ragProvider() -> BindingChatProviderDescriptor {
        BindingChatProviderDescriptor(
            id: "chat.rag-gateway",
            kind: "rag_gateway",
            title: "Dedikert RAG",
            summary: "Sporsmal mot RAG-cases som requesteren har grant til.",
            endpoint: "cell:///RAGGateway",
            sourceCellName: "RAGGatewayCell",
            actionKeypath: "assistant.queryResource",
            purposeRefs: ["personal.ai.provider.rag-gateway", "personal.chat.assist.rag-query"],
            interests: ["rag", "citations", "knowledge", "documentation"],
            availability: "available_for_matched_case",
            privacyLevel: "authorized_case_scope",
            executionScope: "owner_scoped_rag",
            requiresUserApproval: true,
            requiresNetwork: true,
            canInvokeFromChat: true,
            score: 0.9,
            reason: "Utkastet traff en tilgjengelig RAG-case."
        )
    }

    nonisolated private static func agentProvider(
        status: BindingHavenAgentDStatusSnapshot? = nil
    ) -> BindingChatProviderDescriptor {
        let availability = status?.status ?? "status_unknown"
        let nextStep = status?.recommendedNextStep ?? "open_agent_setup_workbench"
        let instructions = status?.instructions.joined(separator: " ") ?? ""
        return BindingChatProviderDescriptor(
            id: "chat.agent-bridge",
            kind: "agent_bridge",
            title: "HAVENAgentD",
            summary: status?.isReadyForPhoneCodexQueue == true
                ? "Lokal agent er klar for MCP-basert operator/Codex-kø."
                : "Lokal agent trenger oppsett før telefon/Codex-flyt kan brukes.",
            endpoint: status?.isReadyForPhoneCodexQueue == true ? "haven-agent://codex/prompt-requests" : "cell:///agent/intents/inbox",
            sourceCellName: status?.isReadyForPhoneCodexQueue == true ? "HavenAgentDMCP" : "RemoteIntentInboxCell",
            actionKeypath: status?.isReadyForPhoneCodexQueue == true ? "agent.codex.next_prompt" : nil,
            purposeRefs: ["personal.ai.provider.agent-bridge", "personal.chat.assist.local-agent-action"],
            interests: ["agentd", "signed-intent", "local-review", "automation", "mcp", "phone-approval"],
            availability: availability,
            privacyLevel: "local_review_required",
            executionScope: "local_agent",
            requiresUserApproval: true,
            requiresNetwork: false,
            canInvokeFromChat: status?.isReadyForPhoneCodexQueue == true,
            score: status?.isReadyForPhoneCodexQueue == true ? 0.86 : 0.72,
            reason: instructions.isEmpty
                ? "Agenthandlinger maa gjennom review/signering, aldri direkte chat-kjoring. Neste steg: \(nextStep)."
                : "Neste HAVENAgentD-steg: \(nextStep). \(instructions)"
        )
    }

    nonisolated private static func agendaProvider() -> BindingChatProviderDescriptor {
        BindingChatProviderDescriptor(
            id: "binding.personal-agenda-context",
            kind: "agenda_context",
            title: "Agenda Context",
            summary: "Owner-local Calendar and Reminders context for dagens agenda og neste gjøremål.",
            endpoint: "cell:///PersonalAgendaContext",
            sourceCellName: "PersonalAgendaContextCell",
            actionKeypath: "agenda.answerQuery",
            purposeRefs: ["personal.agenda.context.today", "personal.chat.assist.agenda-query"],
            interests: ["agenda", "calendar", "reminders", "daily-planning", "agenda-aspects"],
            availability: "available_in_cell_scope",
            privacyLevel: "owner_local_eventkit_cache",
            executionScope: "binding_local_cell",
            requiresUserApproval: true,
            requiresNetwork: false,
            canInvokeFromChat: true,
            score: 0.92,
            reason: "Agenda-spørsmål skal rutes til lokal agenda-context før generiske chathelpers."
        )
    }

    nonisolated private static func contactEndpointProvider() -> BindingChatProviderDescriptor {
        BindingChatProviderDescriptor(
            id: "chat.contact-endpoint",
            kind: "contact_endpoint",
            title: "Kontakt-endepunkt",
            summary: "Owner-scoped ContactEndpoint-cell for signerte foresporsler mellom entiteter.",
            endpoint: "cell:///ContactEndpoint",
            sourceCellName: "BindingContactEndpointCell",
            actionKeypath: "contact.request",
            purposeRefs: [
                "personal.chat.assist.entity-contact-request",
                "personal.chat.assist.resource-router"
            ],
            interests: [
                "contact-endpoint",
                "entity-extension",
                "message-request",
                "signed-intent",
                "requires-user-approval"
            ],
            availability: "available_in_cell_scope",
            privacyLevel: "owner_scoped_endpoint",
            executionScope: "cell_scope",
            requiresUserApproval: true,
            requiresNetwork: false,
            canInvokeFromChat: false,
            score: 0.86,
            reason: "Chat kan foreslaa endpoint-ruten, men contact.request maa signeres og sendes eksplisitt."
        )
    }
}

final class BindingAppleIntelligenceProviderCell: GeneralCell {
    private enum CodingKeys: String, CodingKey {
        case lastClassification
    }

    nonisolated(unsafe) private var lastClassification: Object = [:]

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await setup(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastClassification = (try? container.decode(Object.self, forKey: .lastClassification)) ?? [:]
        try super.init(from: decoder)
        Task { [weak self] in
            guard let self else { return }
            await self.setup(owner: self.storedOwnerIdentity)
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lastClassification, forKey: .lastClassification)
    }

    private func setup(owner: Identity) async {
        for key in ["ai.state", "ai.lastClassification"] {
            agreementTemplate.addGrant("r---", for: key)
        }
        for key in ["ai.classifyIntent", "ai.sendPrompt"] {
            agreementTemplate.addGrant("rw--", for: key)
        }

        await registerGet(key: "ai.state", owner: owner, returns: .object([:])) { [weak self] requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "ai.state", for: requester) else { return .string("denied") }
            return self.stateValue()
        }
        await registerGet(key: "ai.lastClassification", owner: owner, returns: .object([:])) { [weak self] requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "ai.lastClassification", for: requester) else { return .string("denied") }
            return .object(self.lastClassification)
        }
        await registerSet(key: "ai.classifyIntent", owner: owner, input: .object([:]), returns: .object([:])) { [weak self] requester, value in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "ai.classifyIntent", for: requester) else { return .string("denied") }
            return await self.classify(value)
        }
        await registerSet(key: "ai.sendPrompt", owner: owner, input: .object([:]), returns: .object([:])) { [weak self] requester, value in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "ai.sendPrompt", for: requester) else { return .string("denied") }
            return await self.classify(value)
        }
    }

    private func stateValue() -> ValueType {
        let availability = Self.foundationModelAvailability()
        return .object([
            "status": .string(availability.status),
            "providerID": .string("binding.apple-intelligence"),
            "kind": .string("apple_intelligence"),
            "title": .string("Apple Intelligence"),
            "summary": .string("On-device Apple Foundation Models provider scoped to the current Binding requester and chat context."),
            "endpoint": .string("cell:///AppleIntelligence"),
            "sourceCellName": .string("BindingAppleIntelligenceProviderCell"),
            "capability": .string("ai.classifyIntent"),
            "executionScope": .string("binding_chat_scope"),
            "privacyLevel": .string("local_device"),
            "requiresNetwork": .bool(false),
            "requiresUserApproval": .bool(true),
            "canInvokeFromChat": .bool(false),
            "supportsStructuredIntent": .bool(availability.structured),
            "purposeRefs": .list([
                .string("personal.ai.provider.apple-intelligence"),
                .string("personal.chat.assist.resource-router")
            ]),
            "interests": .list([
                .string("apple-intelligence"),
                .string("local"),
                .string("private"),
                .string("on-device"),
                .string("assistant")
            ]),
            "reason": .string(availability.reason),
            "lastClassification": .object(lastClassification)
        ])
    }

    private func classify(_ value: ValueType) async -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        let draft = BindingChatValue.string(payload["draft"])
            ?? BindingChatValue.string(payload["prompt"])
            ?? BindingChatValue.string(payload["text"])
            ?? (value.stringValueIfPossible ?? "")
        let capabilityDiscoveryEnabled = BindingChatValue.bool(payload["capabilityDiscoveryEnabled"]) ?? false
        let fallback = BindingChatIntentClassifier.classify(
            prompt: draft,
            capabilityDiscoveryEnabled: capabilityDiscoveryEnabled
        )
        let useFixtureFallback = BindingChatValue.string(payload["evaluationMode"]) == "fixture"
        let classification = await Self.foundationModelClassification(
            draft: draft,
            contextPack: contextPackForClassification(from: payload),
            fallback: fallback,
            allowFoundationModels: !useFixtureFallback
        )
        var object = classification.objectValue()
        object["providerID"] = .string("binding.apple-intelligence")
        object["providerKind"] = .string("apple_intelligence")
        object["usedContext"] = .object(contextPackForClassification(from: payload))
        lastClassification = object
        return .object(object)
    }

    private func contextPackForClassification(from payload: Object) -> Object {
        [
            "includes": .list([
                .string("active_chat_draft"),
                .string("perspective_summary"),
                .string("granted_cell_tool_descriptors")
            ]),
            "draft": payload["draft"] ?? payload["prompt"] ?? payload["text"] ?? .string(""),
            "capabilityDiscoveryEnabled": payload["capabilityDiscoveryEnabled"] ?? .bool(false),
            "perspectiveSummary": payload["perspectiveSummary"] ?? .object([:]),
            "availableDescriptors": payload["availableDescriptors"] ?? .list([]),
            "excludes": .list([
                .string("other_participant_drafts"),
                .string("native_contacts"),
                .string("calendar"),
                .string("microphone"),
                .string("camera"),
                .string("vault"),
                .string("other_threads")
            ])
        ]
    }

    private static func foundationModelAvailability() -> (status: String, reason: String, structured: Bool) {
#if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return ("ready", "Apple Foundation Models is available on this device.", true)
            case .unavailable(let reason):
                return ("unavailable", "Apple Foundation Models unavailable: \(reason)", true)
            }
        }
        return ("unavailable", "Apple Foundation Models requires macOS 26 or iOS 26 in this build.", false)
#else
        return ("unavailable", "FoundationModels framework is not present in this SDK.", false)
#endif
    }

    private static func foundationModelClassification(
        draft: String,
        contextPack: Object,
        fallback: BindingChatIntentClassification,
        allowFoundationModels: Bool
    ) async -> BindingChatIntentClassification {
        guard allowFoundationModels else { return fallback }
#if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *),
           SystemLanguageModel.default.isAvailable {
            do {
                let session = LanguageModelSession(instructions: """
                Classify one private chat draft into a HAVEN PersonalChatHub helper intent.
                Only use the provided draft, perspective summary and granted descriptors.
                Never infer access to contacts, calendar, camera, microphone, vault or other threads.
                If the user says not to do an action, set negativeIntent and use low_confidence.
                """)
                let contextJSON = (try? ValueType.object(contextPack).jsonString()) ?? "{}"
                let response = try await session.respond(
                    generating: BindingAppleStructuredIntent.self,
                    includeSchemaInPrompt: true,
                    options: GenerationOptions(sampling: .greedy)
                ) {
                    """
                    Draft:
                    \(draft)

                    Context pack:
                    \(contextJSON)
                    """
                }
                return response.content.classification(fallback: fallback)
            } catch {
                return fallback
            }
        }
#endif
        return fallback
    }
}

final class BindingLocalLLMCell: GeneralCell {
    private enum CodingKeys: String, CodingKey {
        case lastClassification
        case backendStatus
    }

    nonisolated(unsafe) private var lastClassification: Object = [:]
    nonisolated(unsafe) private var backendStatus = "not_checked"

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await setup(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastClassification = (try? container.decode(Object.self, forKey: .lastClassification)) ?? [:]
        backendStatus = (try? container.decode(String.self, forKey: .backendStatus)) ?? "not_checked"
        try super.init(from: decoder)
        Task { [weak self] in
            guard let self else { return }
            await self.setup(owner: self.storedOwnerIdentity)
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lastClassification, forKey: .lastClassification)
        try container.encode(backendStatus, forKey: .backendStatus)
    }

    private func setup(owner: Identity) async {
        for key in ["state", "llm.lastClassification"] {
            agreementTemplate.addGrant("r---", for: key)
        }
        for key in ["llm.generate", "llm.classifyIntent", "llm.health"] {
            agreementTemplate.addGrant("rw--", for: key)
        }

        await registerGet(key: "state", owner: owner, returns: .object([:])) { [weak self] requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            return self.stateValue()
        }
        await registerGet(key: "llm.lastClassification", owner: owner, returns: .object([:])) { [weak self] requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "llm.lastClassification", for: requester) else { return .string("denied") }
            return .object(self.lastClassification)
        }
        await registerSet(key: "llm.generate", owner: owner, input: .object([:]), returns: .object([:])) { [weak self] requester, value in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "llm.generate", for: requester) else { return .string("denied") }
            return await self.classify(value)
        }
        await registerSet(key: "llm.classifyIntent", owner: owner, input: .object([:]), returns: .object([:])) { [weak self] requester, value in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "llm.classifyIntent", for: requester) else { return .string("denied") }
            return await self.classify(value)
        }
        await registerSet(key: "llm.health", owner: owner, input: .object([:]), returns: .object([:])) { [weak self] requester, _ in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "llm.health", for: requester) else { return .string("denied") }
            self.backendStatus = Self.configuredEndpoint().isEmpty ? "not_configured" : "configured"
            return self.stateValue()
        }
    }

    private func stateValue() -> ValueType {
        let endpoint = Self.configuredEndpoint()
        let model = Self.configuredModel()
        let status = endpoint.isEmpty ? "unavailable" : "ready"
        return .object([
            "status": .string(status),
            "providerID": .string("binding.local-llm"),
            "kind": .string("local_llm"),
            "title": .string("Local LLM"),
            "summary": .string("Small local LLM provider scoped to the current Binding requester and chat context."),
            "backendStatus": .string(endpoint.isEmpty ? "not_configured" : backendStatus),
            "model": .string(model),
            "selectedModel": .string(model),
            "endpoint": .string("cell:///LocalLLM"),
            "backend": .object([
                "endpoint": .string(endpoint.isEmpty ? "not configured" : endpoint),
                "model": .string(model),
                "runtime": .string(Self.configuredRuntime())
            ]),
            "capability": .string("llm.generate"),
            "privacyLevel": .string("local_device_or_localhost"),
            "executionScope": .string("local_runtime"),
            "requiresNetwork": .bool(false),
            "requiresUserApproval": .bool(true),
            "canInvokeFromChat": .bool(false),
            "purposeRefs": .list([
                .string("personal.ai.provider.local-llm"),
                .string("personal.chat.assist.resource-router")
            ]),
            "interests": .list([
                .string("local-llm"),
                .string("local"),
                .string("private"),
                .string("offline"),
                .string("localhost"),
                .string("assistant")
            ]),
            "lastClassification": .object(lastClassification)
        ])
    }

    private func classify(_ value: ValueType) async -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        let draft = BindingChatValue.string(payload["draft"])
            ?? BindingChatValue.string(payload["prompt"])
            ?? BindingChatValue.string(payload["text"])
            ?? (value.stringValueIfPossible ?? "")
        let classification = BindingChatIntentClassifier.classify(
            prompt: draft,
            capabilityDiscoveryEnabled: BindingChatValue.bool(payload["capabilityDiscoveryEnabled"]) ?? false
        )
        var object = classification.objectValue()
        object["providerID"] = .string("binding.local-llm")
        object["providerKind"] = .string("local_llm")
        object["usedContext"] = .object([
            "includes": .list([
                .string("active_chat_draft"),
                .string("perspective_summary"),
                .string("granted_cell_tool_descriptors")
            ]),
            "capabilityDiscoveryEnabled": payload["capabilityDiscoveryEnabled"] ?? .bool(false),
            "excludes": .list([
                .string("native_contacts"),
                .string("calendar"),
                .string("microphone"),
                .string("camera"),
                .string("vault"),
                .string("other_threads")
            ])
        ])
        lastClassification = object
        return .object(object)
    }

    private static func configuredEndpoint() -> String {
        ProcessInfo.processInfo.environment["BINDING_LOCAL_LLM_ENDPOINT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? ""
    }

    private static func configuredModel() -> String {
        ProcessInfo.processInfo.environment["BINDING_LOCAL_LLM_MODEL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? "not-installed"
    }

    private static func configuredRuntime() -> String {
        ProcessInfo.processInfo.environment["BINDING_LOCAL_LLM_RUNTIME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? "llama.cpp-compatible"
    }
}

private enum BindingContactEndpointContracts {
    static let cellName = "ContactEndpoint"
    static let endpoint = "cell:///ContactEndpoint"
    static let requestSchema = "cellprotocol.contact.request.v1"
    static let descriptorSchema = "cellprotocol.contactEndpoint.descriptor.v1"
    static let ticketSchema = "cellprotocol.contact.ticket.v1"
    static let defaultTicketTTLSeconds = 15 * 60
    static let defaultEndpointTTLSeconds = 7 * 24 * 60 * 60
    static let defaultMaxClockSkewSeconds = 5 * 60

    nonisolated static func string(_ value: ValueType?) -> String? {
        BindingChatValue.string(value)
    }

    nonisolated static func bool(_ value: ValueType?) -> Bool? {
        BindingChatValue.bool(value)
    }

    nonisolated static func list(_ value: ValueType?) -> [ValueType] {
        BindingChatValue.list(value) ?? []
    }

    nonisolated static func object(_ value: ValueType?) -> Object? {
        BindingChatValue.object(value)
    }

    nonisolated static func stringList(_ value: ValueType?) -> [String] {
        BindingChatValue.stringList(value)
    }

    nonisolated static func integer(_ value: ValueType?, default defaultValue: Int) -> Int {
        guard let value else { return defaultValue }
        switch value {
        case let .integer(number):
            return number
        case let .number(number):
            return number
        case let .float(number):
            return Int(number)
        default:
            return defaultValue
        }
    }

    nonisolated static func date(_ value: ValueType?) -> Date? {
        guard let value else { return nil }
        switch value {
        case let .float(timestamp):
            return Date(timeIntervalSince1970: timestamp)
        case let .integer(timestamp):
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        case let .number(timestamp):
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        case let .string(text):
            return ISO8601DateFormatter().date(from: text)
        default:
            return nil
        }
    }

    nonisolated static func hashRef(_ text: String) -> String {
        "sha256:\(FlowHasher.sha256Hex(Data(text.utf8)))"
    }

    nonisolated static func signatureData(from object: Object) -> Data? {
        if case let .data(data)? = object["signature"] {
            return data
        }
        if let encoded = string(object["signatureBase64"]) {
            return Data(base64Encoded: encoded)
        }
        return nil
    }

    nonisolated static func removingSignature(from object: Object) -> Object {
        var payload = object
        payload.removeValue(forKey: "signature")
        payload.removeValue(forKey: "signatureBase64")
        return payload
    }
}

private struct BindingContactEndpointPolicy: Codable, Equatable {
    var requireSignature: Bool
    var requireExpiry: Bool
    var allowedTopics: [String]
    var allowedPurposes: [String]
    var allowedActions: [String]
    var allowedDomains: [String]
    var blockedRequesterHashes: [String]
    var blockedDomains: [String]
    var allowPayloadBody: Bool
    var maxClockSkewSeconds: Int
    var maxPayloadCharacterCount: Int

    static let `default` = BindingContactEndpointPolicy(
        requireSignature: true,
        requireExpiry: true,
        allowedTopics: ["contact.request", "contact.message", "contact.consent"],
        allowedPurposes: ["purpose://contact.introduction", "purpose://contact.followup"],
        allowedActions: ["contact.request.submit"],
        allowedDomains: [],
        blockedRequesterHashes: [],
        blockedDomains: [],
        allowPayloadBody: true,
        maxClockSkewSeconds: BindingContactEndpointContracts.defaultMaxClockSkewSeconds,
        maxPayloadCharacterCount: 4096
    )

    init(
        requireSignature: Bool,
        requireExpiry: Bool,
        allowedTopics: [String],
        allowedPurposes: [String],
        allowedActions: [String],
        allowedDomains: [String],
        blockedRequesterHashes: [String],
        blockedDomains: [String],
        allowPayloadBody: Bool,
        maxClockSkewSeconds: Int,
        maxPayloadCharacterCount: Int
    ) {
        self.requireSignature = requireSignature
        self.requireExpiry = requireExpiry
        self.allowedTopics = allowedTopics
        self.allowedPurposes = allowedPurposes
        self.allowedActions = allowedActions
        self.allowedDomains = allowedDomains
        self.blockedRequesterHashes = blockedRequesterHashes
        self.blockedDomains = blockedDomains
        self.allowPayloadBody = allowPayloadBody
        self.maxClockSkewSeconds = max(0, maxClockSkewSeconds)
        self.maxPayloadCharacterCount = max(256, maxPayloadCharacterCount)
    }

    init(object: Object?) {
        guard let object else {
            self = .default
            return
        }
        let defaults = Self.default
        self.init(
            requireSignature: BindingContactEndpointContracts.bool(object["requireSignature"]) ?? defaults.requireSignature,
            requireExpiry: BindingContactEndpointContracts.bool(object["requireExpiry"]) ?? defaults.requireExpiry,
            allowedTopics: BindingContactEndpointContracts.stringList(object["allowedTopics"]).nilIfEmpty ?? defaults.allowedTopics,
            allowedPurposes: BindingContactEndpointContracts.stringList(object["allowedPurposes"]).nilIfEmpty ?? defaults.allowedPurposes,
            allowedActions: BindingContactEndpointContracts.stringList(object["allowedActions"]).nilIfEmpty ?? defaults.allowedActions,
            allowedDomains: BindingContactEndpointContracts.stringList(object["allowedDomains"]),
            blockedRequesterHashes: BindingContactEndpointContracts.stringList(object["blockedRequesterHashes"]),
            blockedDomains: BindingContactEndpointContracts.stringList(object["blockedDomains"]),
            allowPayloadBody: BindingContactEndpointContracts.bool(object["allowPayloadBody"]) ?? defaults.allowPayloadBody,
            maxClockSkewSeconds: BindingContactEndpointContracts.integer(object["maxClockSkewSeconds"], default: defaults.maxClockSkewSeconds),
            maxPayloadCharacterCount: BindingContactEndpointContracts.integer(object["maxPayloadCharacterCount"], default: defaults.maxPayloadCharacterCount)
        )
    }

    func publicObject() -> Object {
        [
            "requireSignature": .bool(requireSignature),
            "requireExpiry": .bool(requireExpiry),
            "allowedTopics": .list(allowedTopics.map(ValueType.string)),
            "allowedPurposes": .list(allowedPurposes.map(ValueType.string)),
            "allowedActions": .list(allowedActions.map(ValueType.string)),
            "allowedDomains": .list(allowedDomains.map(ValueType.string)),
            "allowPayloadBody": .bool(allowPayloadBody),
            "maxClockSkewSeconds": .integer(maxClockSkewSeconds),
            "maxPayloadCharacterCount": .integer(maxPayloadCharacterCount)
        ]
    }
}

private struct BindingContactEndpointRecord: Codable, Equatable {
    var endpointId: String
    var cell: String
    var status: String
    var purposes: [String]
    var acceptedTopics: [String]
    var routingMode: String
    var ownerContextHash: String
    var contactSetIdHash: String?
    var policy: BindingContactEndpointPolicy
    var routeRefs: [Object]
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date?
    var ticketTTLSeconds: Int

    var isActive: Bool {
        status == "active" && (expiresAt.map { $0 >= Date() } ?? true)
    }

    func publicObject() -> Object {
        var object: Object = [
            "schema": .string(BindingContactEndpointContracts.descriptorSchema),
            "cell": .string(cell),
            "endpointId": .string(endpointId),
            "status": .string(status),
            "purposes": .list(purposes.map(ValueType.string)),
            "acceptedTopics": .list(acceptedTopics.map(ValueType.string)),
            "routingMode": .string(routingMode),
            "ownerContextHash": .string(ownerContextHash),
            "policy": .object(policy.publicObject()),
            "actionKeypath": .string("contact.request"),
            "requiresSignedIntent": .bool(policy.requireSignature),
            "requiresUserApproval": .bool(true),
            "createdAt": .float(createdAt.timeIntervalSince1970),
            "updatedAt": .float(updatedAt.timeIntervalSince1970),
            "ticketTTLSeconds": .integer(ticketTTLSeconds)
        ]
        object["contactSetIdHash"] = contactSetIdHash.map(ValueType.string) ?? .null
        object["expiresAt"] = expiresAt.map { .float($0.timeIntervalSince1970) } ?? .null
        return object
    }

    func privateObject() -> Object {
        var object = publicObject()
        object["routeRefs"] = .list(routeRefs.map(ValueType.object))
        object["routeCount"] = .integer(routeRefs.count)
        return object
    }
}

private struct BindingContactTicketRecord: Codable, Equatable {
    var ticketId: String
    var endpointId: String
    var status: String
    var requestTopic: String
    var purpose: String?
    var requesterIdentityHash: String
    var requesterDomain: String?
    var requestPayload: Object
    var result: ValueType?
    var createdAt: Date
    var expiresAt: Date
    var resolvedAt: Date?
    var respondedAt: Date?

    func publicObject(includePayload: Bool) -> Object {
        var object: Object = [
            "schema": .string(BindingContactEndpointContracts.ticketSchema),
            "ticketId": .string(ticketId),
            "endpointId": .string(endpointId),
            "status": .string(status),
            "requestTopic": .string(requestTopic),
            "requesterIdentityHash": .string(requesterIdentityHash),
            "createdAt": .float(createdAt.timeIntervalSince1970),
            "expiresAt": .float(expiresAt.timeIntervalSince1970),
            "requiresUserApproval": .bool(true),
            "sideEffect": .bool(true)
        ]
        object["purpose"] = purpose.map(ValueType.string) ?? .null
        object["requesterDomain"] = requesterDomain.map(ValueType.string) ?? .null
        object["resolvedAt"] = resolvedAt.map { .float($0.timeIntervalSince1970) } ?? .null
        object["respondedAt"] = respondedAt.map { .float($0.timeIntervalSince1970) } ?? .null
        object["result"] = result ?? .null
        if includePayload {
            object["requestPayload"] = .object(requestPayload)
        }
        return object
    }
}

final class BindingContactEndpointCell: GeneralCell {
    private enum CodingKeys: String, CodingKey {
        case endpointsByID
        case ticketsByID
        case seenNonces
    }

    private let stateQueue = DispatchQueue(label: "BindingContactEndpointCell.State")
    nonisolated(unsafe) private var endpointsByID: [String: BindingContactEndpointRecord]
    nonisolated(unsafe) private var ticketsByID: [String: BindingContactTicketRecord]
    nonisolated(unsafe) private var seenNonces: [String: Date]

    required init(owner: Identity) async {
        endpointsByID = [:]
        ticketsByID = [:]
        seenNonces = [:]
        await super.init(owner: owner)
        await setup(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        endpointsByID = (try? container.decode([String: BindingContactEndpointRecord].self, forKey: .endpointsByID)) ?? [:]
        ticketsByID = (try? container.decode([String: BindingContactTicketRecord].self, forKey: .ticketsByID)) ?? [:]
        seenNonces = (try? container.decode([String: Date].self, forKey: .seenNonces)) ?? [:]
        try super.init(from: decoder)
        Task { [weak self] in
            guard let self else { return }
            await self.setup(owner: self.storedOwnerIdentity)
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stateQueue.sync { endpointsByID }, forKey: .endpointsByID)
        try container.encode(stateQueue.sync { ticketsByID }, forKey: .ticketsByID)
        try container.encode(stateQueue.sync { seenNonces }, forKey: .seenNonces)
    }

    private func setup(owner: Identity) async {
        for key in ["state", "privateState", "descriptor", "feed"] {
            agreementTemplate.addGrant("r---", for: key)
            await registerGet(key: key, owner: owner, returns: .object([:])) { [weak self] requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                switch key {
                case "privateState":
                    return self.stateValue(includePrivate: true)
                case "descriptor":
                    return self.defaultDescriptor()
                default:
                    return self.stateValue(includePrivate: false)
                }
            }
        }

        for key in ["publishEndpoint", "retireEndpoint", "contact.request", "ticket.resolve", "ticket.respond", "expire"] {
            agreementTemplate.addGrant("rw--", for: key)
            await registerSet(key: key, owner: owner, input: .object([:]), returns: .object([:])) { [weak self] requester, value in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
                return await self.handleSet(key: key, value: value, requester: requester)
            }
        }
    }

    private func handleSet(key: String, value: ValueType, requester: Identity) async -> ValueType {
        switch key {
        case "publishEndpoint":
            guard let object = BindingContactEndpointContracts.object(value) else {
                return .object(error("expected_object", "publishEndpoint expects an object payload."))
            }
            return .object(publishEndpoint(object, requester: requester).publicObject())
        case "retireEndpoint":
            let endpointId = BindingContactEndpointContracts.string(BindingContactEndpointContracts.object(value)?["endpointId"])
                ?? BindingContactEndpointContracts.string(value)
                ?? ""
            guard let record = updateEndpointStatus(endpointId: endpointId, status: "retired") else {
                return .object(error("not_found", "Endpoint not found."))
            }
            return .object(record.publicObject())
        case "contact.request":
            guard let object = BindingContactEndpointContracts.object(value) else {
                return .object(error("expected_object", "contact.request expects an object payload."))
            }
            return .object(await handleContactRequest(object, requester: requester))
        case "ticket.resolve":
            let ticketId = BindingContactEndpointContracts.string(BindingContactEndpointContracts.object(value)?["ticketId"])
                ?? BindingContactEndpointContracts.string(value)
                ?? ""
            return .object(resolveTicket(ticketId: ticketId))
        case "ticket.respond":
            guard let object = BindingContactEndpointContracts.object(value),
                  let ticketId = BindingContactEndpointContracts.string(object["ticketId"]) else {
                return .object(error("missing_ticket_id", "ticket.respond expects ticketId."))
            }
            return .object(respondTicket(ticketId: ticketId, payload: object))
        case "expire":
            return .object(expireStaleRecords())
        default:
            return .object(error("unsupported_keypath", "Unsupported ContactEndpoint action."))
        }
    }

    private func stateValue(includePrivate: Bool) -> ValueType {
        let snapshot = stateQueue.sync {
            (
                endpoints: endpointsByID.values.sorted { $0.updatedAt > $1.updatedAt },
                tickets: ticketsByID.values.sorted { $0.createdAt > $1.createdAt },
                nonceCount: seenNonces.count
            )
        }
        return .object([
            "cell": .string(BindingContactEndpointContracts.endpoint),
            "status": .string("ready"),
            "endpointCount": .integer(snapshot.endpoints.count),
            "activeEndpointCount": .integer(snapshot.endpoints.filter(\.isActive).count),
            "ticketCount": .integer(snapshot.tickets.count),
            "pendingTicketCount": .integer(snapshot.tickets.filter { ["pending", "resolved"].contains($0.status) }.count),
            "seenNonceCount": .integer(snapshot.nonceCount),
            "endpoints": .list(snapshot.endpoints.map { .object(includePrivate ? $0.privateObject() : $0.publicObject()) }),
            "tickets": .list(snapshot.tickets.map { .object($0.publicObject(includePayload: includePrivate)) }),
            "supports": .list([
                .string("publishEndpoint"),
                .string("contact.request"),
                .string("ticket.resolve"),
                .string("ticket.respond")
            ])
        ])
    }

    private func defaultDescriptor() -> ValueType {
        .object([
            "cell": .string(BindingContactEndpointContracts.endpoint),
            "cellName": .string(BindingContactEndpointContracts.cellName),
            "schema": .string(BindingContactEndpointContracts.descriptorSchema),
            "title": .string("Kontakt-endepunkt"),
            "summary": .string("Owner-scoped endpoint for explicit signed contact requests."),
            "actionKeypath": .string("contact.request"),
            "purposeRefs": .list([
                .string("personal.chat.assist.entity-contact-request"),
                .string("personal.chat.assist.resource-router")
            ]),
            "interests": .list([
                .string("contact-endpoint"),
                .string("entity-extension"),
                .string("signed-intent"),
                .string("requires-user-approval")
            ]),
            "requiresUserApproval": .bool(true),
            "requiresSignedIntent": .bool(true),
            "requiresNetwork": .bool(false)
        ])
    }

    private func publishEndpoint(_ object: Object, requester: Identity) -> BindingContactEndpointRecord {
        let now = Date()
        let endpointId = BindingContactEndpointContracts.string(object["endpointId"]) ?? "contact-\(UUID().uuidString.lowercased())"
        let contactSetId = BindingContactEndpointContracts.string(object["contactSetId"])
        let endpointTTLSeconds = BindingContactEndpointContracts.integer(
            object["endpointTTLSeconds"] ?? object["ttlSeconds"],
            default: BindingContactEndpointContracts.defaultEndpointTTLSeconds
        )
        let expiresAt = BindingContactEndpointContracts.date(object["expiresAt"])
            ?? now.addingTimeInterval(TimeInterval(endpointTTLSeconds))
        let purposes = BindingContactEndpointContracts.stringList(object["purposes"]).nilIfEmpty
            ?? BindingContactEndpointPolicy.default.allowedPurposes
        let acceptedTopics = BindingContactEndpointContracts.stringList(object["acceptedTopics"]).nilIfEmpty
            ?? BindingContactEndpointPolicy.default.allowedTopics
        let routeRefs = BindingContactEndpointContracts.list(object["routeRefs"]).compactMap(BindingContactEndpointContracts.object)
        let routingMode = BindingContactEndpointContracts.string(object["routingMode"]) ?? (contactSetId == nil ? "direct" : "opaqueSetRouter")
        let ticketTTLSeconds = BindingContactEndpointContracts.integer(
            object["ticketTTLSeconds"],
            default: BindingContactEndpointContracts.defaultTicketTTLSeconds
        )
        let record = BindingContactEndpointRecord(
            endpointId: endpointId,
            cell: BindingContactEndpointContracts.string(object["cell"]) ?? BindingContactEndpointContracts.endpoint,
            status: "active",
            purposes: purposes,
            acceptedTopics: acceptedTopics,
            routingMode: routingMode,
            ownerContextHash: BindingContactEndpointContracts.hashRef("binding-contact-endpoint::\(requester.uuid)::\(endpointId)"),
            contactSetIdHash: contactSetId.map { BindingContactEndpointContracts.hashRef("binding-contact-set::\(endpointId)::\($0)::\(now.timeIntervalSince1970)") },
            policy: BindingContactEndpointPolicy(object: BindingContactEndpointContracts.object(object["policy"])),
            routeRefs: routeRefs,
            createdAt: now,
            updatedAt: now,
            expiresAt: expiresAt,
            ticketTTLSeconds: max(60, ticketTTLSeconds)
        )
        stateQueue.sync {
            endpointsByID[endpointId] = record
        }
        return record
    }

    private func handleContactRequest(_ object: Object, requester: Identity) async -> Object {
        let now = Date()
        guard BindingContactEndpointContracts.string(object["schema"]) ?? BindingContactEndpointContracts.requestSchema == BindingContactEndpointContracts.requestSchema else {
            return error("unsupported_schema", "Unsupported contact request schema.")
        }
        guard let endpointId = BindingContactEndpointContracts.string(object["endpointId"]) else {
            return error("missing_endpoint_id", "Contact request is missing endpointId.")
        }
        guard let endpoint = endpointSnapshot(endpointId: endpointId) else {
            return error("not_found", "Endpoint not found.")
        }
        guard endpoint.status == "active" else {
            return error("endpoint_not_active", "Endpoint is \(endpoint.status).")
        }
        if let expiresAt = endpoint.expiresAt, expiresAt < now {
            _ = updateEndpointStatus(endpointId: endpointId, status: "expired")
            return error("endpoint_expired", "Endpoint has expired.")
        }
        guard let nonce = BindingContactEndpointContracts.string(object["nonce"]) else {
            return error("missing_nonce", "Contact request is missing nonce.")
        }
        guard let topic = BindingContactEndpointContracts.string(object["topic"]) else {
            return error("missing_topic", "Contact request is missing topic.")
        }
        let purpose = BindingContactEndpointContracts.string(object["purpose"])
        let requestedAction = BindingContactEndpointContracts.string(object["requestedAction"]) ?? "contact.request.submit"
        guard endpoint.acceptedTopics.contains(topic) || endpoint.policy.allowedTopics.contains(topic) else {
            return error("topic_not_allowed", "Topic is not allowed for this endpoint.")
        }
        guard endpoint.policy.allowedActions.isEmpty || endpoint.policy.allowedActions.contains(requestedAction) else {
            return error("action_not_allowed", "Requested action is not allowed for this endpoint.")
        }
        if let purpose, endpoint.policy.allowedPurposes.isEmpty == false, endpoint.policy.allowedPurposes.contains(purpose) == false {
            return error("purpose_not_allowed", "Purpose is not allowed for this endpoint.")
        }
        let requesterDomain = BindingContactEndpointContracts.string(object["requesterDomain"])
        if endpoint.policy.allowedDomains.isEmpty == false {
            guard let requesterDomain, endpoint.policy.allowedDomains.contains(requesterDomain) else {
                return error("domain_not_allowed", "Requester domain is not allowed for this endpoint.")
            }
        }
        if let requesterDomain, endpoint.policy.blockedDomains.contains(requesterDomain) {
            return error("requester_blocked", "Requester domain is blocked for this endpoint context.")
        }
        guard validateRequestExpiry(object, policy: endpoint.policy, now: now) else {
            return error("request_expired_or_invalid", "Request expiresAt/issuedAt is missing, invalid, expired, or outside allowed skew.")
        }
        let payloadCharacterCount = ((try? (object["payload"] ?? .null).jsonString()) ?? "").count
        guard payloadCharacterCount <= endpoint.policy.maxPayloadCharacterCount else {
            return error("payload_too_large", "Request payload exceeds endpoint policy.")
        }
        guard endpoint.policy.allowPayloadBody || BindingContactEndpointContracts.object(object["payload"])?.keys.allSatisfy({ $0.hasPrefix("agreement") || $0.hasPrefix("intro") }) == true else {
            return error("payload_not_allowed", "Endpoint policy only allows agreement/introduction metadata for first contact.")
        }
        let verification = await verifyRequestSignature(object, policy: endpoint.policy)
        guard BindingContactEndpointContracts.bool(verification["verified"]) == true else {
            return [
                "status": .string("rejected"),
                "reason": .string(BindingContactEndpointContracts.string(verification["status"]) ?? "signature_invalid"),
                "verification": .object(verification)
            ]
        }

        let requesterIdentityHash = requesterHash(from: object, fallbackRequester: requester)
        guard endpoint.policy.blockedRequesterHashes.contains(requesterIdentityHash) == false else {
            return error("requester_blocked", "Requester is blocked for this endpoint context.")
        }
        let nonceKey = "\(requesterIdentityHash)::\(topic)::\(nonce)"
        guard markNonceIfNew(nonceKey, now: now) else {
            return error("replay_detected", "Contact request nonce has already been seen.")
        }

        let ttlSeconds = min(endpoint.ticketTTLSeconds, secondsUntil(endpoint.expiresAt, from: now) ?? endpoint.ticketTTLSeconds)
        let ticket = BindingContactTicketRecord(
            ticketId: "ticket-\(UUID().uuidString.lowercased())",
            endpointId: endpointId,
            status: "pending",
            requestTopic: topic,
            purpose: purpose,
            requesterIdentityHash: requesterIdentityHash,
            requesterDomain: requesterDomain,
            requestPayload: sanitizedRequestPayload(object),
            result: nil,
            createdAt: now,
            expiresAt: now.addingTimeInterval(TimeInterval(max(60, ttlSeconds))),
            resolvedAt: nil,
            respondedAt: nil
        )
        stateQueue.sync {
            ticketsByID[ticket.ticketId] = ticket
        }
        return ticket.publicObject(includePayload: false)
    }

    private func resolveTicket(ticketId: String) -> Object {
        let now = Date()
        let ticket: BindingContactTicketRecord? = stateQueue.sync {
            guard var record = ticketsByID[ticketId], now <= record.expiresAt else {
                return nil
            }
            record.status = "resolved"
            record.resolvedAt = now
            ticketsByID[ticketId] = record
            return record
        }
        guard let ticket else {
            return error("ticket_not_found_or_expired", "Ticket is missing or expired.")
        }
        return ticket.publicObject(includePayload: true)
    }

    private func respondTicket(ticketId: String, payload: Object) -> Object {
        let now = Date()
        let requestedStatus = BindingContactEndpointContracts.string(payload["status"]) ?? "accepted"
        let allowed = ["accepted", "declined", "blocked", "failed"]
        let ticket: BindingContactTicketRecord? = stateQueue.sync {
            guard var record = ticketsByID[ticketId], now <= record.expiresAt else {
                return nil
            }
            record.status = allowed.contains(requestedStatus) ? requestedStatus : "accepted"
            record.respondedAt = now
            record.result = payload["result"] ?? .object([:])
            ticketsByID[ticketId] = record
            return record
        }
        guard let ticket else {
            return error("ticket_not_found_or_expired", "Ticket is missing or expired.")
        }
        return ticket.publicObject(includePayload: false)
    }

    private func validateRequestExpiry(_ object: Object, policy: BindingContactEndpointPolicy, now: Date) -> Bool {
        guard let issuedAt = BindingContactEndpointContracts.date(object["issuedAt"]) else {
            return policy.requireExpiry == false
        }
        if issuedAt.timeIntervalSince(now) > TimeInterval(policy.maxClockSkewSeconds) {
            return false
        }
        guard let expiresAt = BindingContactEndpointContracts.date(object["expiresAt"]) else {
            return policy.requireExpiry == false
        }
        return expiresAt >= now
    }

    private func verifyRequestSignature(_ object: Object, policy: BindingContactEndpointPolicy) async -> Object {
        guard policy.requireSignature else {
            return ["verified": .bool(true), "status": .string("signature_not_required")]
        }
        guard case let .identity(identity)? = object["requesterIdentity"] else {
            return ["verified": .bool(false), "status": .string("missing_requester_identity")]
        }
        guard let signatureData = BindingContactEndpointContracts.signatureData(from: object) else {
            return [
                "verified": .bool(false),
                "status": .string("missing_signature"),
                "signerIdentityUUID": .string(identity.uuid)
            ]
        }
        do {
            let data = try FlowCanonicalEncoder.canonicalData(for: .object(BindingContactEndpointContracts.removingSignature(from: object)))
            let verified = await identity.verify(signature: signatureData, for: data)
            return [
                "verified": .bool(verified),
                "status": .string(verified ? "verified" : "invalid_signature"),
                "signerIdentityUUID": .string(identity.uuid),
                "signerDisplayName": .string(identity.displayName)
            ]
        } catch {
            return [
                "verified": .bool(false),
                "status": .string("verification_error"),
                "message": .string("\(error)")
            ]
        }
    }

    private func sanitizedRequestPayload(_ object: Object) -> Object {
        var payload = BindingContactEndpointContracts.removingSignature(from: object)
        if case let .identity(identity)? = payload["requesterIdentity"] {
            payload["requesterIdentity"] = .string(BindingContactEndpointContracts.hashRef(identity.uuid))
            payload["requesterDisplayName"] = .string(identity.displayName)
        }
        return payload
    }

    private func requesterHash(from object: Object, fallbackRequester: Identity) -> String {
        if case let .identity(identity)? = object["requesterIdentity"] {
            return BindingContactEndpointContracts.hashRef(identity.uuid)
        }
        return BindingContactEndpointContracts.hashRef(fallbackRequester.uuid)
    }

    private func endpointSnapshot(endpointId: String) -> BindingContactEndpointRecord? {
        stateQueue.sync { endpointsByID[endpointId] }
    }

    private func updateEndpointStatus(endpointId: String, status: String) -> BindingContactEndpointRecord? {
        stateQueue.sync {
            guard var record = endpointsByID[endpointId] else { return nil }
            record.status = status
            record.updatedAt = Date()
            endpointsByID[endpointId] = record
            return record
        }
    }

    private func markNonceIfNew(_ key: String, now: Date) -> Bool {
        stateQueue.sync {
            guard seenNonces[key] == nil else { return false }
            seenNonces[key] = now
            return true
        }
    }

    private func expireStaleRecords(now: Date = Date()) -> Object {
        stateQueue.sync {
            var expiredEndpoints = 0
            var expiredTickets = 0
            for (endpointId, var endpoint) in endpointsByID where endpoint.status == "active" {
                if let expiresAt = endpoint.expiresAt, expiresAt < now {
                    endpoint.status = "expired"
                    endpoint.updatedAt = now
                    endpointsByID[endpointId] = endpoint
                    expiredEndpoints += 1
                }
            }
            for (ticketId, var ticket) in ticketsByID where ["accepted", "declined", "blocked", "failed"].contains(ticket.status) == false {
                if ticket.expiresAt < now {
                    ticket.status = "expired"
                    ticketsByID[ticketId] = ticket
                    expiredTickets += 1
                }
            }
            seenNonces = seenNonces.filter { now.timeIntervalSince($0.value) <= 7 * 24 * 60 * 60 }
            return [
                "expiredEndpoints": .integer(expiredEndpoints),
                "expiredTickets": .integer(expiredTickets),
                "seenNonceCount": .integer(seenNonces.count),
                "timestamp": .float(now.timeIntervalSince1970),
                "sideEffect": .bool(true)
            ]
        }
    }

    private func secondsUntil(_ date: Date?, from now: Date) -> Int? {
        guard let date else { return nil }
        return max(0, Int(date.timeIntervalSince(now)))
    }

    private func error(_ code: String, _ message: String) -> Object {
        [
            "status": .string("error"),
            "code": .string(code),
            "message": .string(message),
            "sideEffect": .bool(false)
        ]
    }
}

final class BindingPersonalChatHubCell: GeneralCell {
    private enum CodingKeys: String, CodingKey {
        case cachedState
        case registeredProviders
    }

    nonisolated(unsafe) private var cachedState: Object = BindingPersonalChatHubCell.initialState()
    nonisolated(unsafe) private var registeredProviders: [BindingChatProviderDescriptor] = []
    nonisolated(unsafe) private var voiceTranscriber = BindingVoiceInputTranscriber()

    required init(owner: Identity) async {
        await super.init(owner: owner)
        cachedState = Self.initialState()
        await setup(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cachedState = (try? container.decode(Object.self, forKey: .cachedState)) ?? Self.initialState()
        registeredProviders = (try? container.decode([BindingChatProviderDescriptor].self, forKey: .registeredProviders)) ?? []
        try super.init(from: decoder)
        Task { [weak self] in
            guard let self else { return }
            await self.setup(owner: self.storedOwnerIdentity)
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cachedState, forKey: .cachedState)
        try container.encode(registeredProviders, forKey: .registeredProviders)
    }

    private func setup(owner: Identity) async {
        for key in readableKeys {
            agreementTemplate.addGrant("r---", for: key)
            await registerGet(key: key, owner: owner, returns: .object([:])) { [weak self] requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                return self.readValue(for: key)
            }
        }

        for key in writableKeys {
            agreementTemplate.addGrant("rw--", for: key)
            await registerSet(key: key, owner: owner, input: .object([:]), returns: .object([:])) { [weak self] requester, value in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
                return await self.handleSet(key: key, value: value, requester: requester)
            }
        }
    }

    private var readableKeys: [String] {
        let canonicalKeys = [
            "state",
            "assistantState",
            "assistantState.intentCandidates",
            "assistantState.priorityIntent",
            "assistantState.assistantProviders",
            "assistantState.providerRecommendation",
            "assistantState.whySummary",
            "assistantSuggestions",
            "assistantPolicy",
            "assistantProviders",
            "providerRecommendation",
            "threads",
            "messages",
            "blockedUsers",
            "moderationStatus",
            "meetingBridge",
            "ui",
            "polls",
            "pollDraft",
            "workbenchState",
            "workbenchModules",
            "capabilityRequestDraft",
            "capabilityRequests",
            "entityExtension",
            "voiceState",
            "purposeWeights",
            "purposeGoal",
            "skeletonConfiguration"
        ] + Self.stateProjectionReadableKeys
        return canonicalKeys + canonicalKeys.map { "chatHub.\($0)" }
    }

    private var writableKeys: [String] {
        let canonicalKeys = [
            "setComposer",
            "sendComposedMessage",
            "clearComposer",
            "assistant.analyzeDraft",
            "assistant.acceptSuggestion",
            "assistant.dismissSuggestion",
            "assistant.queryResource",
            "assistant.provider.register",
            "assistant.provider.recommend",
            "assistant.setCandidateQuery",
            "assistant.selectCandidate",
            "entityExtension.scan",
            "voice.requestPermission",
            "voice.startListening",
            "voice.stopListening",
            "voice.acceptTranscript",
            "voice.acceptTranscriptAndAnalyze",
            "voice.clearTranscript",
            "drop.receive",
            "ui.openSuggestedHelper",
            "ui.openComponentSurface",
            "ui.minimizeComponentSurface",
            "ui.restoreComponentSurface",
            "ui.dismissComponentSurface",
            "ui.pinComponentSurface",
            "ui.setActiveTab",
            "ui.setActiveHelper",
            "ui.setActiveMoreTab",
            "ui.setLearningEnabled",
            "ui.setCapabilityDiscoveryEnabled",
            "ui.setShowAdvanced",
            "invite",
            "acceptInvite",
            "declineInvite",
            "inviteDraft.title",
            "inviteDraft.profileID",
            "inviteDraft.userUUID",
            "poll.setQuestion",
            "poll.setOptions",
            "poll.create",
            "poll.vote",
            "poll.close",
            "meeting.title",
            "meeting.targetProfileID",
            "meeting.proposedTimesText",
            "meeting.setBridgeMetadata",
            "meeting.schedule",
            "idea.title",
            "idea.content",
            "idea.capture",
            "todo.title",
            "todo.note",
            "todo.dueAtText",
            "todo.assigneeUUID",
            "todo.create",
            "project.title",
            "project.description",
            "project.membersText",
            "project.create",
            "reminder.title",
            "reminder.scheduledAtText",
            "reminder.scope",
            "reminder.create",
            "agent.review.actionID",
            "agent.review.reason",
            "agent.review.argumentsText",
            "agent.review.signatureBase64",
            "agent.review.create",
            "agent.review.execute",
            "agent.reviewIntent",
            "capabilityRequest.title",
            "capabilityRequest.summary",
            "capabilityRequest.destination",
            "capabilityRequest.category",
            "capabilityRequest.submit",
            "reportMessage",
            "blockUser",
            "unblockUser"
        ]
        return canonicalKeys + canonicalKeys.map { "chatHub.\($0)" }
    }

    private static let stateProjectionReadableKeys: [String] = [
        "state.assistant.assistantProviders",
        "state.assistant.candidateQuery",
        "state.assistant.latestSuggestion.candidates",
        "state.assistant.latestSuggestion.explanation",
        "state.assistant.latestSuggestion.selectedCandidateProfileID",
        "state.assistant.providerRecommendation.executionScope",
        "state.assistant.providerRecommendation.kind",
        "state.assistant.providerRecommendation.reason",
        "state.assistant.providerRecommendation.title",
        "state.assistant.whySummary",
        "state.capabilityRequests",
        "state.currentThread.composer.body",
        "state.inviteDraft.title",
        "state.invites",
        "state.messages",
        "state.pollDraft.optionsText",
        "state.pollDraft.question",
        "state.polls",
        "state.ui.activeMoreTab",
        "state.ui.activeTab",
        "state.ui.activeToolChips",
        "state.ui.componentSurfaces",
        "state.ui.moreTabs",
        "state.ui.tabs",
        "state.voice.finalTranscript",
        "state.voice.message",
        "state.workbench.agentReviewDraft.actionID",
        "state.workbench.agentReviewDraft.reason",
        "state.workbench.capabilityRequestDraft.summary",
        "state.workbench.capabilityRequestDraft.title",
        "state.workbench.ideaDraft.content",
        "state.workbench.ideaDraft.title",
        "state.workbench.meetingDraft.proposedTimesText",
        "state.workbench.meetingDraft.title",
        "state.workbench.modules",
        "state.workbench.projectDraft.description",
        "state.workbench.projectDraft.title",
        "state.workbench.reminderDraft.scheduledAtText",
        "state.workbench.reminderDraft.title",
        "state.workbench.todoDraft.dueAtText",
        "state.workbench.todoDraft.note",
        "state.workbench.todoDraft.title"
    ]

    private static func canonicalChatHubKey(_ key: String) -> String {
        if key.hasPrefix("chatHub.") {
            return String(key.dropFirst("chatHub.".count))
        }
        return key
    }

    private func readValue(for key: String) -> ValueType {
        let key = Self.canonicalChatHubKey(key)
        switch key {
        case "state":
            return .object(cachedState)
        case let key where key.hasPrefix("state."):
            let suffix = String(key.dropFirst("state.".count))
            return BindingChatValue.nested(suffix, in: cachedState) ?? .null
        case "assistantState":
            return BindingChatValue.nested("assistant", in: cachedState) ?? .object([:])
        case let key where key.hasPrefix("assistantState."):
            let suffix = String(key.dropFirst("assistantState.".count))
            return BindingChatValue.nested("assistant.\(suffix)", in: cachedState) ?? .null
        case "assistantSuggestions":
            return BindingChatValue.nested("assistant.suggestions", in: cachedState) ?? .list([])
        case "assistantPolicy":
            return BindingChatValue.nested("assistant.policy", in: cachedState) ?? .object([:])
        case "assistantProviders":
            return BindingChatValue.nested("assistant.assistantProviders", in: cachedState) ?? .list([])
        case "providerRecommendation":
            return BindingChatValue.nested("assistant.providerRecommendation", in: cachedState) ?? .null
        case "workbenchState":
            return BindingChatValue.nested("workbench", in: cachedState) ?? .object([:])
        case "workbenchModules":
            return BindingChatValue.nested("workbench.modules", in: cachedState) ?? .list([])
        case "capabilityRequestDraft":
            return BindingChatValue.nested("workbench.capabilityRequestDraft", in: cachedState) ?? .object([:])
        case "capabilityRequests":
            return BindingChatValue.nested("capabilityRequests", in: cachedState) ?? .list([])
        case "entityExtension":
            return BindingChatValue.nested("entityExtension", in: cachedState) ?? .object(entityExtensionState(matches: []))
        case "voiceState":
            return BindingChatValue.nested("voice", in: cachedState) ?? .object(Self.initialVoiceState())
        default:
            return BindingChatValue.nested(key, in: cachedState) ?? .null
        }
    }

    private func handleSet(key: String, value: ValueType, requester: Identity) async -> ValueType {
        let key = Self.canonicalChatHubKey(key)
        switch key {
        case "setComposer":
            return setComposer(value)
        case "clearComposer":
            BindingChatValue.set(.string(""), for: "currentThread.composer.body", in: &cachedState)
            return response(status: "ok", message: "Composer cleared.")
        case "sendComposedMessage":
            return sendComposedMessage()
        case "assistant.analyzeDraft":
            return await analyzeDraft(value: value, requester: requester)
        case "assistant.dismissSuggestion":
            return dismissSuggestion()
        case "ui.openSuggestedHelper":
            return openSuggestedHelper()
        case "ui.openComponentSurface":
            return openComponentSurface(value)
        case "ui.minimizeComponentSurface":
            return markSurface(value, state: "minimized")
        case "ui.restoreComponentSurface":
            return markSurface(value, state: "open")
        case "ui.dismissComponentSurface":
            return markSurface(value, state: "dismissed")
        case "ui.pinComponentSurface":
            return pinSurface(value)
        case "ui.setActiveTab":
            BindingChatValue.set(.string(text(from: value)), for: "ui.activeTab", in: &cachedState)
            return response(status: "ok", message: "Tab updated.")
        case "ui.setActiveHelper":
            let helper = BindingChatValue.string(BindingChatValue.object(value)?["activeHelper"]) ?? text(from: value)
            BindingChatValue.set(.string(helper), for: "ui.activeHelper", in: &cachedState)
            BindingChatValue.set(.string("mer"), for: "ui.activeTab", in: &cachedState)
            return response(status: "ok", message: "Helper updated.")
        case "ui.setActiveMoreTab":
            let tab = BindingChatValue.string(BindingChatValue.object(value)?["activeMoreTab"]) ?? text(from: value)
            BindingChatValue.set(.string(tab), for: "ui.activeMoreTab", in: &cachedState)
            BindingChatValue.set(.string("mer"), for: "ui.activeTab", in: &cachedState)
            return response(status: "ok", message: "More tab updated.")
        case "ui.setLearningEnabled":
            BindingChatValue.set(value, for: "privacy.learningEnabled", in: &cachedState)
            BindingChatValue.set(.string((BindingChatValue.bool(value) ?? false) ? "enabled" : "paused"), for: "ui.learningStatus", in: &cachedState)
            return response(status: "ok", message: "Privacy preference updated.")
        case "ui.setCapabilityDiscoveryEnabled":
            BindingChatValue.set(value, for: "ui.capabilityDiscoveryEnabled", in: &cachedState)
            BindingChatValue.set(.string((BindingChatValue.bool(value) ?? false) ? "enabled" : "off"), for: "ui.capabilityDiscoveryStatus", in: &cachedState)
            return response(status: "ok", message: "Capability discovery preference updated.")
        case "ui.setShowAdvanced":
            BindingChatValue.set(value, for: "ui.showAdvanced", in: &cachedState)
            return response(status: "ok", message: "Advanced visibility updated.")
        case "assistant.acceptSuggestion":
            return acceptSuggestion()
        case "assistant.queryResource":
            return await queryResource(value, requester: requester)
        case "assistant.provider.register":
            return registerProvider(value)
        case "assistant.provider.recommend":
            return recommendProvider(value)
        case "assistant.setCandidateQuery":
            BindingChatValue.set(.string(text(from: value)), for: "assistant.candidateQuery", in: &cachedState)
            return response(status: "ok", message: "Candidate query updated.")
        case "assistant.selectCandidate":
            BindingChatValue.set(.string(text(from: value)), for: "assistant.latestSuggestion.selectedCandidateProfileID", in: &cachedState)
            return response(status: "ok", message: "Candidate selected.")
        case "entityExtension.scan":
            return await scanEntityExtension(value, requester: requester)
        case "voice.requestPermission":
            return await requestVoicePermission()
        case "voice.startListening":
            return await startVoiceListening(value)
        case "voice.stopListening":
            return stopVoiceListening()
        case "voice.acceptTranscript":
            return await acceptVoiceTranscript(value, requester: requester, analyze: false)
        case "voice.acceptTranscriptAndAnalyze":
            return await acceptVoiceTranscript(value, requester: requester, analyze: true)
        case "voice.clearTranscript":
            return clearVoiceTranscript()
        case "drop.receive":
            return receiveDrop(value, requester: requester)
        case "inviteDraft.title":
            BindingChatValue.set(.string(text(from: value)), for: "inviteDraft.title", in: &cachedState)
            return response(status: "ok", message: "Invite title updated.")
        case "inviteDraft.profileID":
            BindingChatValue.set(.string(text(from: value)), for: "inviteDraft.profileID", in: &cachedState)
            return response(status: "ok", message: "Invite profile updated.")
        case "inviteDraft.userUUID":
            BindingChatValue.set(.string(text(from: value)), for: "inviteDraft.userUUID", in: &cachedState)
            return response(status: "ok", message: "Invite user updated.")
        case "invite":
            return createInvite()
        case "acceptInvite":
            BindingChatValue.set(.string("accepted"), for: "inviteStatus", in: &cachedState)
            return response(status: "ok", message: "Invite accepted.")
        case "declineInvite":
            BindingChatValue.set(.string("declined"), for: "inviteStatus", in: &cachedState)
            return response(status: "ok", message: "Invite declined.")
        case "poll.setQuestion":
            BindingChatValue.set(.string(text(from: value)), for: "pollDraft.question", in: &cachedState)
            return response(status: "ok", message: "Poll question updated.")
        case "poll.setOptions":
            BindingChatValue.set(.string(text(from: value)), for: "pollDraft.optionsText", in: &cachedState)
            return response(status: "ok", message: "Poll options updated.")
        case "poll.create":
            return createPoll()
        case "poll.vote":
            return response(status: "ok", message: "Vote recorded locally.")
        case "poll.close":
            return response(status: "ok", message: "Poll closed locally.")
        case "meeting.title":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.meetingDraft.title", in: &cachedState)
            return response(status: "ok", message: "Meeting title updated.")
        case "meeting.targetProfileID":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.meetingDraft.targetProfileID", in: &cachedState)
            return response(status: "ok", message: "Meeting target updated.")
        case "meeting.proposedTimesText":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.meetingDraft.proposedTimesText", in: &cachedState)
            return response(status: "ok", message: "Meeting times updated.")
        case "meeting.setBridgeMetadata":
            return setMeetingBridgeMetadata(value)
        case "idea.title":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.ideaDraft.title", in: &cachedState)
            return response(status: "ok", message: "Idea title updated.")
        case "idea.content":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.ideaDraft.content", in: &cachedState)
            return response(status: "ok", message: "Idea content updated.")
        case "todo.title":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.todoDraft.title", in: &cachedState)
            return response(status: "ok", message: "Todo title updated.")
        case "todo.note":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.todoDraft.note", in: &cachedState)
            return response(status: "ok", message: "Todo note updated.")
        case "todo.dueAtText":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.todoDraft.dueAtText", in: &cachedState)
            return response(status: "ok", message: "Todo due date updated.")
        case "todo.assigneeUUID":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.todoDraft.assigneeUUID", in: &cachedState)
            return response(status: "ok", message: "Todo assignee updated.")
        case "project.title":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.projectDraft.title", in: &cachedState)
            return response(status: "ok", message: "Project title updated.")
        case "project.description":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.projectDraft.description", in: &cachedState)
            return response(status: "ok", message: "Project description updated.")
        case "project.membersText":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.projectDraft.membersText", in: &cachedState)
            return response(status: "ok", message: "Project members updated.")
        case "reminder.title":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.reminderDraft.title", in: &cachedState)
            return response(status: "ok", message: "Reminder title updated.")
        case "reminder.scheduledAtText":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.reminderDraft.scheduledAtText", in: &cachedState)
            return response(status: "ok", message: "Reminder time updated.")
        case "reminder.scope":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.reminderDraft.scope", in: &cachedState)
            return response(status: "ok", message: "Reminder scope updated.")
        case "agent.review.actionID":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.agentReviewDraft.actionID", in: &cachedState)
            return response(status: "ok", message: "Agent action updated.")
        case "agent.review.reason":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.agentReviewDraft.reason", in: &cachedState)
            return response(status: "ok", message: "Agent reason updated.")
        case "agent.review.argumentsText":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.agentReviewDraft.argumentsText", in: &cachedState)
            return response(status: "ok", message: "Agent arguments updated.")
        case "agent.review.signatureBase64":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.agentReviewDraft.signatureBase64", in: &cachedState)
            return response(status: "ok", message: "Agent signature updated.")
        case "capabilityRequest.title":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.capabilityRequestDraft.title", in: &cachedState)
            return response(status: "ok", message: "Capability request title updated.")
        case "capabilityRequest.summary":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.capabilityRequestDraft.summary", in: &cachedState)
            return response(status: "ok", message: "Capability request summary updated.")
        case "capabilityRequest.destination":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.capabilityRequestDraft.destination", in: &cachedState)
            return response(status: "ok", message: "Capability request destination updated.")
        case "capabilityRequest.category":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.capabilityRequestDraft.category", in: &cachedState)
            return response(status: "ok", message: "Capability request category updated.")
        case "capabilityRequest.submit":
            return submitCapabilityRequest(value)
        case "meeting.schedule", "idea.capture", "todo.create", "project.create", "reminder.create", "agent.review.create", "agent.review.execute", "agent.reviewIntent":
            return createWorkbenchModule(kind: key)
        case "reportMessage":
            BindingChatValue.set(.string("Latest message reported for review."), for: "moderationStatus", in: &cachedState)
            return response(status: "ok", message: "Report recorded.")
        case "blockUser":
            let payload = BindingChatValue.object(value)
            let blockedID = BindingChatValue.string(payload?["profileID"])
                ?? BindingChatValue.string(payload?["userUUID"])
                ?? BindingChatValue.string(payload?["id"])
                ?? text(from: value).nilIfEmpty
                ?? "blocked-user"
            BindingChatValue.set(.list([.string(blockedID)]), for: "blockedUsers", in: &cachedState)
            return response(status: "ok", message: "Participant blocked.")
        case "unblockUser":
            BindingChatValue.set(.list([]), for: "blockedUsers", in: &cachedState)
            return response(status: "ok", message: "Participant unblocked.")
        default:
            return response(status: "error", message: "Unsupported chat action.")
        }
    }

    private func analyzeDraft(value: ValueType, requester: Identity) async -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        let draft = BindingChatValue.string(payload["text"])
            ?? BindingChatValue.string(payload["draft"])
            ?? BindingChatValue.string(payload["prompt"])
            ?? BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState))
            ?? ""
        let capabilityDiscoveryEnabled = BindingChatValue.bool(BindingChatValue.nested("ui.capabilityDiscoveryEnabled", in: cachedState)) ?? false
        let suggestion = BindingChatIntentClassifier.classify(
            prompt: draft,
            capabilityDiscoveryEnabled: capabilityDiscoveryEnabled
        )
        let perspective = await perspectiveSummary(requester: requester)
        let providers = await scopedProviders(requester: requester)
        let resourceMatches = BindingChatIntentClassifier.resourceMatches(prompt: draft)
        let agentStatus = BindingHavenAgentDStatusProvider.snapshot()
        let recommendation = BindingChatProviderRouter.recommend(
            prompt: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches,
            providers: providers,
            agentStatus: agentStatus
        )
        let agentUseDecision = BindingAgentUseDecision.decide(
            prompt: draft,
            suggestion: suggestion,
            perspectiveSummary: perspective,
            agentStatus: agentStatus
        )
        let contextPack: Object = [
            "draft": .string(draft),
            "capabilityDiscoveryEnabled": .bool(capabilityDiscoveryEnabled),
            "perspectiveSummary": .object(perspective),
            "agentStatus": .object(agentStatus.objectValue()),
            "agentUseDecision": .object(agentUseDecision.objectValue()),
            "availableDescriptors": .list(providers.map { .object($0.objectValue()) }),
            "excluded": .list([
                .string("other_participant_drafts"),
                .string("native_contacts"),
                .string("calendar"),
                .string("microphone"),
                .string("camera"),
                .string("vault"),
                .string("other_threads")
            ])
        ]
        let candidates = candidateRows(for: suggestion)
        var suggestionObject = suggestion.objectValue()
        suggestionObject["candidates"] = .list(candidates)
        suggestionObject["selectedCandidateProfileID"] = candidates.first.flatMap { BindingChatValue.string(BindingChatValue.object($0)?["id"]) }.map(ValueType.string) ?? .null

        let providerObjects = providers.map { ValueType.object($0.objectValue()) }
        let resourceObjects = resourceMatches.map(ValueType.object)
        let recommendationObject = recommendation.objectValue()
        let agentStatusObject = agentStatus.objectValue()
        let agentUseDecisionObject = agentUseDecision.objectValue()
        let portholeUI = BindingChatIntentClassifier.portholeUIRequest(for: draft)
            ?? (suggestion.helperID == "resource-router"
                ? resourceMatches.first(where: { BindingChatValue.string($0["kind"]) == "cell_configuration" }).map {
                    BindingChatIntentClassifier.libraryUIRequest(for: $0, autoOpen: false)
                }
                : nil)
        var assistantUpdates: Object = [
            "status": .string(suggestion.shouldSuggest ? "suggested" : "low_confidence"),
            "mode": .string("suggestion_first"),
            "intentEngine": .string("deterministic_with_optional_cell_scoped_provider"),
            "latestSuggestion": .object(suggestionObject),
            "suggestions": .list(suggestion.shouldSuggest ? [.object(suggestionObject)] : []),
            "whySummary": .string(suggestion.reason),
            "assistantProviders": .list(providerObjects),
            "providerRecommendation": .object(recommendationObject),
            "providerCount": .integer(providers.count),
            "resourceMatches": .list(resourceObjects),
            "resourceMatchCount": .integer(resourceMatches.count),
            "agentStatus": .object(agentStatusObject),
            "agentUseDecision": .object(agentUseDecisionObject),
            "priorityIntent": .object(suggestionObject),
            "lastContextPack": .object(contextPack),
            "intentCandidates": .list(suggestion.shouldSuggest ? [.object(suggestionObject)] : []),
            "requiresUserApproval": .bool(true)
        ]
        if let portholeUI {
            assistantUpdates["portholeUI"] = .object(portholeUI)
        }
        for (key, update) in assistantUpdates {
            BindingChatValue.set(update, for: "assistant.\(key)", in: &cachedState)
        }
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)

        var response: Object = [
            "ok": .bool(true),
            "status": .string(suggestion.shouldSuggest ? "suggested" : "low_confidence"),
            "suggestion": .object(suggestionObject),
            "priorityIntent": .object(suggestionObject),
            "providerRecommendation": .object(recommendationObject),
            "resourceMatches": .list(resourceObjects),
            "assistantProviders": .list(providerObjects),
            "agentStatus": .object(agentStatusObject),
            "agentUseDecision": .object(agentUseDecisionObject),
            "intentCandidates": .list(suggestion.shouldSuggest ? [.object(suggestionObject)] : []),
            "contextPack": .object(contextPack),
            "sideEffect": .bool(false)
        ]
        if let portholeUI {
            response["portholeUI"] = .object(portholeUI)
        }
        return .object(response)
    }

    private func scopedProviders(requester: Identity) async -> [BindingChatProviderDescriptor] {
        var providers = [BindingChatProviderRouter.localRulesProvider()]
        providers.append(contentsOf: registeredProviders)
        if let appleState = await providerState(endpoint: "cell:///AppleIntelligence", keypath: "ai.state", requester: requester),
           let apple = BindingChatProviderRouter.descriptor(from: appleState, defaultKind: "apple_intelligence") {
            providers.append(apple)
        }
        if let localState = await providerState(endpoint: "cell:///LocalLLM", keypath: "state", requester: requester),
           let localLLM = BindingChatProviderRouter.descriptor(from: localState, defaultKind: "local_llm") {
            providers.append(localLLM)
        }
        return deduplicatedProviders(providers)
    }

    private func providerState(endpoint: String, keypath: String, requester: Identity) async -> ValueType? {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let meddle = try? await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester) as? Meddle
        else {
            return nil
        }
        return try? await meddle.get(keypath: keypath, requester: requester)
    }

    private func perspectiveSummary(requester: Identity) async -> Object {
        var summary: Object = [
            "source": .string("PerspectiveCell"),
            "queries": .list([
                .string("perspective.query.activePurposes"),
                .string("perspective.query.interestsFromActivePurposes"),
                .string("perspective.query.match")
            ])
        ]
        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let perspective = try? await resolver.cellAtEndpoint(endpoint: "cell:///Perspective", requester: requester) as? Meddle
        else {
            summary["status"] = .string("unavailable")
            return summary
        }

        let active = try? await perspective.set(
            keypath: "perspective.query.activePurposes",
            value: .object(["referenceMode": .string("both")]),
            requester: requester
        )
        let interests = try? await perspective.set(
            keypath: "perspective.query.interestsFromActivePurposes",
            value: .object(["referenceMode": .string("both")]),
            requester: requester
        )
        summary["status"] = .string("queried")
        summary["activePurposes"] = active ?? .null
        summary["interests"] = interests ?? .null
        return summary
    }

    private func registerProvider(_ value: ValueType) -> ValueType {
        let values: [ValueType]
        if let object = BindingChatValue.object(value), let list = BindingChatValue.list(object["providers"]) {
            values = list
        } else if let list = BindingChatValue.list(value) {
            values = list
        } else {
            values = [value]
        }

        let parsed = values.compactMap { BindingChatValue.object($0).flatMap(BindingChatProviderRouter.registeredProvider(from:)) }
        registeredProviders = deduplicatedProviders(registeredProviders + parsed)
        BindingChatValue.set(.list(registeredProviders.map { .object($0.objectValue()) }), for: "assistant.assistantProviders", in: &cachedState)
        return .object([
            "ok": .bool(true),
            "registeredCount": .integer(registeredProviders.count),
            "providers": .list(registeredProviders.map { .object($0.objectValue()) })
        ])
    }

    private func recommendProvider(_ value: ValueType) -> ValueType {
        let prompt = BindingChatValue.string(BindingChatValue.object(value)?["text"])
            ?? BindingChatValue.string(BindingChatValue.object(value)?["prompt"])
            ?? BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState))
            ?? ""
        let suggestion = BindingChatIntentClassifier.classify(
            prompt: prompt,
            capabilityDiscoveryEnabled: BindingChatValue.bool(BindingChatValue.nested("ui.capabilityDiscoveryEnabled", in: cachedState)) ?? false
        )
        let resourceMatches = BindingChatIntentClassifier.resourceMatches(prompt: prompt)
        let providers = deduplicatedProviders([BindingChatProviderRouter.localRulesProvider()] + registeredProviders)
        let recommendation = BindingChatProviderRouter.recommend(
            prompt: prompt,
            suggestion: suggestion,
            resourceMatches: resourceMatches,
            providers: providers
        )
        BindingChatValue.set(.object(recommendation.objectValue()), for: "assistant.providerRecommendation", in: &cachedState)
        return .object([
            "ok": .bool(true),
            "providerRecommendation": .object(recommendation.objectValue()),
            "sideEffect": .bool(false)
        ])
    }

    private func scanEntityExtension(_ value: ValueType, requester: Identity) async -> ValueType {
        let query = BindingChatValue.string(BindingChatValue.object(value)?["query"])
            ?? BindingChatValue.string(BindingChatValue.object(value)?["text"])
            ?? BindingChatValue.string(value)
            ?? BindingChatValue.string(BindingChatValue.nested("assistant.candidateQuery", in: cachedState))
            ?? BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState))
            ?? ""
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return .object([
                "ok": .bool(false),
                "status": .string("error"),
                "code": .string("query_required"),
                "message": .string("entityExtension.scan requires a query or an active chat context"),
                "sideEffect": .bool(false)
            ])
        }
        let matches = BindingChatIntentClassifier.resourceMatches(prompt: trimmedQuery)
        let providers = await scopedProviders(requester: requester)
        let suggestion = BindingChatIntentClassifier.classify(
            prompt: trimmedQuery,
            capabilityDiscoveryEnabled: BindingChatValue.bool(BindingChatValue.nested("ui.capabilityDiscoveryEnabled", in: cachedState)) ?? false
        )
        let recommendation = BindingChatProviderRouter.recommend(
            prompt: trimmedQuery,
            suggestion: suggestion,
            resourceMatches: matches,
            providers: providers
        )
        let state = entityExtensionState(matches: matches, query: trimmedQuery, providers: providers)
        BindingChatValue.set(.list(matches.map(ValueType.object)), for: "assistant.resourceMatches", in: &cachedState)
        BindingChatValue.set(.integer(matches.count), for: "assistant.resourceMatchCount", in: &cachedState)
        BindingChatValue.set(.list(providers.map { .object($0.objectValue()) }), for: "assistant.assistantProviders", in: &cachedState)
        BindingChatValue.set(.object(recommendation.objectValue()), for: "assistant.providerRecommendation", in: &cachedState)
        BindingChatValue.set(.integer(providers.count), for: "assistant.providerCount", in: &cachedState)
        BindingChatValue.set(.object(state), for: "entityExtension", in: &cachedState)
        BindingChatValue.set(.string(trimmedQuery), for: "assistant.candidateQuery", in: &cachedState)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)
        return .object([
            "ok": .bool(true),
            "status": .string("scanned"),
            "query": .string(trimmedQuery),
            "entityExtension": .object(state),
            "resourceMatches": .list(matches.map(ValueType.object)),
            "assistantProviders": .list(providers.map { .object($0.objectValue()) }),
            "providerRecommendation": .object(recommendation.objectValue()),
            "auditEvent": .object(auditEvent(type: "chat.entity-extension.scanned", subjectID: requester.uuid, summary: "Requester scanned owner-scoped Binding capabilities visible to this chat.")),
            "sideEffect": .bool(false)
        ])
    }

    private func requestVoicePermission() async -> ValueType {
        let permissions = await voiceTranscriber.requestPermissions()
        var updates = permissions.objectValue()
        updates["status"] = .string(permissions.canTranscribe ? "ready" : "permission_denied")
        updates["isListening"] = .bool(false)
        updates["message"] = .string(permissions.reason)
        let state = mergeVoiceState(updates)
        return .object([
            "ok": .bool(permissions.canTranscribe),
            "status": .string(permissions.canTranscribe ? "ready" : "permission_denied"),
            "voice": .object(state),
            "nativePermissionRequest": .bool(true),
            "sideEffect": .bool(false)
        ])
    }

    private func startVoiceListening(_ value: ValueType) async -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        let locale = BindingChatValue.string(payload["locale"])
            ?? BindingChatValue.string(BindingChatValue.nested("voice.locale", in: cachedState))
            ?? Locale.current.identifier

        if let injectedTranscript = BindingChatValue.string(payload["transcript"]) ?? BindingChatValue.string(payload["mockTranscript"]) {
            let update = BindingVoiceInputUpdate(
                status: "transcribed",
                partialTranscript: injectedTranscript,
                finalTranscript: injectedTranscript,
                isFinal: true,
                isListening: false,
                localeIdentifier: locale,
                errorCode: "",
                message: "Injected voice transcript is ready."
            )
            let state = applyVoiceUpdate(update)
            return .object([
                "ok": .bool(true),
                "status": .string("transcribed"),
                "voice": .object(state),
                "sideEffect": .bool(false)
            ])
        }

        let update = await voiceTranscriber.start(localeIdentifier: locale) { [weak self] update in
            _ = self?.applyVoiceUpdate(update)
        }
        let state = applyVoiceUpdate(update)
        return .object([
            "ok": .bool(update.errorCode.isEmpty),
            "status": .string(update.status),
            "voice": .object(state),
            "nativePermissionRequest": .bool(update.status == "permission_denied"),
            "microphoneCaptureStarted": .bool(update.isListening),
            "sideEffect": .bool(false)
        ])
    }

    private func stopVoiceListening() -> ValueType {
        voiceTranscriber.stop()
        let partial = BindingChatValue.string(BindingChatValue.nested("voice.partialTranscript", in: cachedState)) ?? ""
        let final = BindingChatValue.string(BindingChatValue.nested("voice.finalTranscript", in: cachedState)) ?? ""
        let transcript = final.nilIfEmpty ?? partial
        let state = mergeVoiceState([
            "status": .string("stopped"),
            "isListening": .bool(false),
            "finalTranscript": .string(transcript),
            "message": .string(transcript.isEmpty ? "Speech input stopped." : "Speech transcript is ready.")
        ])
        return .object([
            "ok": .bool(true),
            "status": .string("stopped"),
            "voice": .object(state),
            "sideEffect": .bool(false)
        ])
    }

    private func acceptVoiceTranscript(
        _ value: ValueType,
        requester: Identity,
        analyze: Bool
    ) async -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        let transcript = BindingChatValue.string(payload["transcript"])
            ?? BindingChatValue.string(payload["text"])
            ?? BindingChatValue.string(BindingChatValue.nested("voice.finalTranscript", in: cachedState))
            ?? BindingChatValue.string(BindingChatValue.nested("voice.partialTranscript", in: cachedState))
            ?? ""
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let state = mergeVoiceState([
                "status": .string("empty_transcript"),
                "message": .string("No speech transcript is available yet.")
            ])
            return .object([
                "ok": .bool(false),
                "status": .string("empty_transcript"),
                "voice": .object(state),
                "sideEffect": .bool(false)
            ])
        }

        let mode = BindingChatValue.string(payload["mode"])
            ?? BindingChatValue.string(payload["commitMode"])
            ?? "replace"
        let existing = BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState)) ?? ""
        let body: String
        if mode == "append", !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body = "\(existing.trimmingCharacters(in: .whitespacesAndNewlines)) \(trimmed)"
        } else {
            body = trimmed
        }

        BindingChatValue.set(.string(body), for: "currentThread.composer.body", in: &cachedState)
        let state = mergeVoiceState([
            "status": .string(analyze ? "committed_and_analyzed" : "committed"),
            "isListening": .bool(false),
            "finalTranscript": .string(trimmed),
            "lastCommittedTranscript": .string(trimmed),
            "commitMode": .string(mode),
            "message": .string(analyze ? "Speech transcript moved to composer and analyzed." : "Speech transcript moved to composer.")
        ])

        if analyze {
            let analysis = await analyzeDraft(
                value: .object([
                    "text": .string(body),
                    "source": .string("voice.acceptTranscriptAndAnalyze")
                ]),
                requester: requester
            )
            return .object([
                "ok": .bool(true),
                "status": .string("committed_and_analyzed"),
                "composerBody": .string(body),
                "voice": .object(state),
                "analysis": analysis,
                "sideEffect": .bool(false)
            ])
        }

        return .object([
            "ok": .bool(true),
            "status": .string("committed"),
            "composerBody": .string(body),
            "voice": .object(state),
            "sideEffect": .bool(false)
        ])
    }

    private func clearVoiceTranscript() -> ValueType {
        let state = mergeVoiceState([
            "status": .string("idle"),
            "partialTranscript": .string(""),
            "finalTranscript": .string(""),
            "lastCommittedTranscript": .string(""),
            "isFinal": .bool(false),
            "isListening": .bool(false),
            "lastError": .null,
            "message": .string("Speech transcript cleared.")
        ])
        return .object([
            "ok": .bool(true),
            "status": .string("cleared"),
            "voice": .object(state),
            "sideEffect": .bool(false)
        ])
    }

    private func applyVoiceUpdate(_ update: BindingVoiceInputUpdate) -> Object {
        mergeVoiceState(update.objectValue())
    }

    private func mergeVoiceState(_ updates: Object) -> Object {
        var state = BindingChatValue.object(BindingChatValue.nested("voice", in: cachedState)) ?? Self.initialVoiceState()
        for (key, value) in updates {
            state[key] = value
        }
        state["updatedAt"] = .float(Date().timeIntervalSince1970)
        BindingChatValue.set(.object(state), for: "voice", in: &cachedState)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)
        return state
    }

    private func entityExtensionState(
        matches: [Object],
        query: String? = nil,
        providers: [BindingChatProviderDescriptor]? = nil
    ) -> Object {
        let providerRows = (providers ?? currentProviderDescriptors()).map { Self.providerExtensionRow($0) }
        let rows = Self.deduplicatedExtensionRows(Self.baseEntityExtensionRows() + providerRows)
        let counts = Self.extensionKindCounts(rows)
        let providerObjects = (providers ?? currentProviderDescriptors()).map { ValueType.object($0.objectValue()) }
        return [
            "schema": .string("haven.personal.entity-extension.v1"),
            "status": .string("ready"),
            "query": .string(query ?? "tilgang enheter tjenester sky lokal agent ai rag capability entity extension"),
            "surface": .string("Co-Pilot Chat"),
            "summary": .string(Self.entityExtensionSummary(counts: counts)),
            "extensionCount": .integer(rows.count),
            "counts": .object(counts),
            "extensions": .list(rows.map(ValueType.object)),
            "capabilities": .list(rows.map(ValueType.object)),
            "resourceMatches": .list(matches.map(ValueType.object)),
            "assistantProviders": .list(providerObjects),
            "providerRecommendation": providerObjects.first ?? .null,
            "queries": .list([
                .string("natural_language_to_purpose_interest"),
                .string("direct_purpose_hit_before_interest_hit"),
                .string("lexical_fallback_after_grants")
            ]),
            "sideEffectsRequireClick": .bool(true),
            "scope": .string("owner_visible_cellprotocol_scope"),
            "privacyBoundary": .string("no_global_identifier_no_cross_domain_merge"),
            "retentionDefault": .string("ephemeral_chat_scan; source cells keep their own TTL and persistence"),
            "loadBalancingHint": .string("resolve through sourceCellEndpoint/actionKeypath; do not centralize execution in chat"),
            "discoverability": .string("visible only after user opens this chat or explicitly shares/registers an endpoint"),
            "sideEffect": .bool(false)
        ]
    }

    private func receiveDrop(_ value: ValueType, requester: Identity) -> ValueType {
        let object = BindingChatValue.object(value) ?? [:]
        let dragRole = BindingChatValue.string(object["dragRole"]) ?? ""
        let dropTargetRole = BindingChatValue.string(object["dropTargetRole"]) ?? ""
        let dragPayload = BindingChatValue.object(object["dragPayload"])
            ?? BindingChatValue.object(object["publicSafeDragPayload"])
            ?? object

        guard dragRole == "person", dropTargetRole == "chat-invite-slot" else {
            let drop = chatDropObject(validationState: "invalid", deniedReason: "Dette kan ikke legges til i chatten.")
            BindingChatValue.set(.object(drop), for: "drop", in: &cachedState)
            return .object([
                "ok": .bool(false),
                "status": .string("invalid"),
                "drop": .object(drop),
                "sideEffect": .bool(false)
            ])
        }

        let profileID = BindingChatValue.string(dragPayload["profileID"])
            ?? BindingChatValue.string(dragPayload["id"])
            ?? ""
        guard !profileID.isEmpty else {
            let drop = chatDropObject(validationState: "invalid", deniedReason: "Fant ikke en publisert profil som kan inviteres.")
            BindingChatValue.set(.object(drop), for: "drop", in: &cachedState)
            return .object([
                "ok": .bool(false),
                "status": .string("invalid"),
                "drop": .object(drop),
                "sideEffect": .bool(false)
            ])
        }

        let userUUID = BindingChatValue.string(dragPayload["userUUID"])
            ?? BindingChatValue.string(dragPayload["ownerUUID"])
            ?? profileID
        let blocked = Set((BindingChatValue.list(BindingChatValue.nested("blockedUsers", in: cachedState)) ?? []).compactMap { BindingChatValue.string($0) })
        guard !blocked.contains(profileID), !blocked.contains(userUUID) else {
            let drop = chatDropObject(validationState: "denied", deniedReason: "Denne personen kan ikke legges til i chat akkurat naa.")
            BindingChatValue.set(.object(drop), for: "drop", in: &cachedState)
            return .object([
                "ok": .bool(false),
                "status": .string("denied"),
                "profileID": .string(profileID),
                "drop": .object(drop),
                "sideEffect": .bool(false)
            ])
        }

        let displayName = BindingChatValue.string(dragPayload["displayName"]) ?? "profil"
        var inviteDraft = BindingChatValue.object(BindingChatValue.nested("inviteDraft", in: cachedState)) ?? [:]
        inviteDraft["profileID"] = .string(profileID)
        inviteDraft["userUUID"] = .string(userUUID)
        if BindingChatValue.string(inviteDraft["title"])?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            inviteDraft["title"] = .string("Chat med \(displayName)")
        }
        if let contactEndpoint = normalizedContactEndpoint(from: dragPayload) {
            inviteDraft["contactEndpoint"] = .object(contactEndpoint)
        } else {
            inviteDraft["contactEndpoint"] = .null
        }

        let drop = chatDropObject(validationState: "valid", deniedReason: "")
        BindingChatValue.set(.object(inviteDraft), for: "inviteDraft", in: &cachedState)
        BindingChatValue.set(.string(profileID), for: "assistant.latestSuggestion.selectedCandidateProfileID", in: &cachedState)
        BindingChatValue.set(.object(drop), for: "drop", in: &cachedState)
        BindingChatValue.set(.string("mer"), for: "ui.activeTab", in: &cachedState)
        BindingChatValue.set(.string("verktoy"), for: "ui.activeMoreTab", in: &cachedState)
        BindingChatValue.set(.string("invite"), for: "ui.activeHelper", in: &cachedState)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)

        return .object([
            "ok": .bool(true),
            "status": .string("candidate_ready"),
            "sideEffect": .string("invite_draft_only"),
            "profileID": .string(profileID),
            "inviteDraft": .object(inviteDraft),
            "drop": .object(drop),
            "auditEvent": .object(auditEvent(type: "chat.drop.invite-draft", subjectID: profileID, summary: "A dropped public profile was converted into an invite draft. No invitation was sent."))
        ])
    }

    private func currentProviderDescriptors() -> [BindingChatProviderDescriptor] {
        let current = BindingChatValue.list(BindingChatValue.nested("assistant.assistantProviders", in: cachedState)) ?? []
        let parsed = current.compactMap { BindingChatValue.object($0).flatMap(BindingChatProviderRouter.registeredProvider(from:)) }
        return deduplicatedProviders(parsed + [BindingChatProviderRouter.localRulesProvider()])
    }

    private func normalizedContactEndpoint(from dragPayload: Object) -> Object? {
        let embedded = BindingChatValue.object(dragPayload["contactEndpoint"])
            ?? BindingChatValue.object(dragPayload["contactEndpointDescriptor"])
        let endpointID = BindingChatValue.string(embedded?["endpointID"])
            ?? BindingChatValue.string(embedded?["endpointId"])
            ?? BindingChatValue.string(dragPayload["contactEndpointID"])
            ?? BindingChatValue.string(dragPayload["contactEndpointId"])
        guard let endpointID, !endpointID.isEmpty else { return nil }
        return [
            "endpointID": .string(endpointID),
            "cell": BindingChatValue.string(embedded?["cell"])
                .map(ValueType.string)
                ?? BindingChatValue.string(dragPayload["contactEndpointCell"]).map(ValueType.string)
                ?? .string("cell:///ContactEndpoint"),
            "purposes": embedded?["purposes"]
                ?? dragPayload["contactEndpointPurposes"]
                ?? .list([.string("personal.chat.invite.receive")]),
            "interests": embedded?["interests"]
                ?? dragPayload["contactEndpointInterests"]
                ?? .list([.string("invite-only-chat")])
        ]
    }

    private func chatDropObject(validationState: String, deniedReason: String) -> Object {
        [
            "validationState": .string(validationState),
            "deniedReason": .string(deniedReason)
        ]
    }

    private func auditEvent(type: String, subjectID: String, summary: String) -> Object {
        [
            "type": .string(type),
            "surface": .string("Co-Pilot Chat"),
            "subjectID": .string(subjectID),
            "summary": .string(summary),
            "createdAt": .float(Date().timeIntervalSince1970)
        ]
    }

    nonisolated private static func initialEntityExtensionState() -> Object {
        let provider = BindingChatProviderRouter.localRulesProvider()
        let rows = deduplicatedExtensionRows(baseEntityExtensionRows() + [providerExtensionRow(provider)])
        let counts = extensionKindCounts(rows)
        return [
            "schema": .string("haven.personal.entity-extension.v1"),
            "status": .string("ready"),
            "query": .string("tilgang enheter tjenester sky lokal agent ai rag capability entity extension"),
            "surface": .string("Co-Pilot Chat"),
            "summary": .string(entityExtensionSummary(counts: counts)),
            "extensionCount": .integer(rows.count),
            "counts": .object(counts),
            "extensions": .list(rows.map(ValueType.object)),
            "capabilities": .list(rows.map(ValueType.object)),
            "resourceMatches": .list([]),
            "assistantProviders": .list([.object(provider.objectValue())]),
            "providerRecommendation": .object(provider.objectValue()),
            "sideEffectsRequireClick": .bool(true),
            "scope": .string("owner_visible_cellprotocol_scope"),
            "privacyBoundary": .string("no_global_identifier_no_cross_domain_merge"),
            "retentionDefault": .string("ephemeral_chat_scan; source cells keep their own TTL and persistence"),
            "loadBalancingHint": .string("resolve through sourceCellEndpoint/actionKeypath; do not centralize execution in chat"),
            "discoverability": .string("visible only after user opens this chat or explicitly shares/registers an endpoint"),
            "sideEffect": .bool(false)
        ]
    }

    nonisolated private static func initialVoiceState() -> Object {
        let permissions = BindingVoiceInputTranscriber.permissionSnapshot()
        var state: Object = [
            "schema": .string("haven.personal.chat.voice-input.v1"),
            "status": .string("idle"),
            "engine": .string(BindingVoiceInputTranscriber.engineName),
            "runtimeAvailable": .bool(BindingVoiceInputTranscriber.isRuntimeAvailable),
            "locale": .string(Locale.current.identifier),
            "partialTranscript": .string(""),
            "finalTranscript": .string(""),
            "lastCommittedTranscript": .string(""),
            "isListening": .bool(false),
            "isFinal": .bool(false),
            "autoSend": .bool(false),
            "requiresExplicitUserAction": .bool(true),
            "privacyLevel": .string("binding_local_microphone_to_on_device_speech"),
            "allowedCommitTargets": .list([
                .string("currentThread.composer.body"),
                .string("assistant.analyzeDraft")
            ]),
            "message": .string("Speech input is idle."),
            "lastError": .null,
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
        for (key, value) in permissions.objectValue() {
            state[key] = value
        }
        return state
    }

    nonisolated private static func baseEntityExtensionRows() -> [Object] {
        [
            [
                "id": .string("configuration:binding-copilot-chat"),
                "kind": .string("cell_configuration"),
                "title": .string("Co-Pilot Chat"),
                "summary": .string("Binding sin requester-visible chat workbench for PersonalChatHub."),
                "sourceCellEndpoint": .string("cell:///PersonalChatHub"),
                "sourceCellName": .string("BindingPersonalChatHubCell"),
                "configurationName": .string("Co-Pilot Chat"),
                "executionScope": .string("cell_scope"),
                "grantStatus": .string("visible_in_requester_scope"),
                "availability": .string("visible_configuration"),
                "purposeRefs": .list([
                    .string("personal.chat.assist.invite"),
                    .string("personal.chat.assist.poll"),
                    .string("personal.chat.assist.resource-router")
                ]),
                "interests": .list([
                    .string("chat-assistant"),
                    .string("purpose-interest-weighted"),
                    .string("requires-user-approval")
                ]),
                "readKeypaths": .list([
                    .string("assistantState"),
                    .string("entityExtension"),
                    .string("workbenchState")
                ]),
                "writeKeypaths": .list([
                    .string("assistant.analyzeDraft"),
                    .string("ui.openSuggestedHelper"),
                    .string("entityExtension.scan")
                ]),
                "requiresUserApproval": .bool(true),
                "requiresSignedRemoteIntent": .bool(false),
                "requiresLocalReview": .bool(false)
            ],
            [
                "id": .string("configuration:binding-contact-endpoint"),
                "kind": .string("cell_configuration"),
                "title": .string("ContactEndpoint"),
                "summary": .string("Owner-scoped endpoint-cell for signerte foresporsler mellom entiteter."),
                "sourceCellEndpoint": .string("cell:///ContactEndpoint"),
                "sourceCellName": .string("BindingContactEndpointCell"),
                "configurationName": .string("Contact Endpoint"),
                "executionScope": .string("cell_scope"),
                "grantStatus": .string("visible_in_requester_scope"),
                "availability": .string("visible_configuration"),
                "purposeRefs": .list([
                    .string("personal.chat.assist.entity-contact-request"),
                    .string("personal.chat.assist.resource-router")
                ]),
                "interests": .list([
                    .string("contact-endpoint"),
                    .string("entity-extension"),
                    .string("signed-intent")
                ]),
                "readKeypaths": .list([.string("state")]),
                "writeKeypaths": .list([.string("contact.request")]),
                "requiresUserApproval": .bool(true),
                "requiresSignedRemoteIntent": .bool(true),
                "requiresLocalReview": .bool(false)
            ],
            [
                "id": .string("configuration:binding-agenda-context"),
                "kind": .string("cell_configuration"),
                "title": .string("Agenda Context"),
                "summary": .string("Owner-local Calendar/Reminders context for dagens agenda og neste gjøremål."),
                "sourceCellEndpoint": .string("cell:///PersonalAgendaContext"),
                "sourceCellName": .string("PersonalAgendaContextCell"),
                "configurationName": .string("Agenda Context"),
                "executionScope": .string("binding_local_cell"),
                "grantStatus": .string("visible_in_requester_scope"),
                "availability": .string("visible_configuration"),
                "purposeRefs": .list([
                    .string("personal.agenda.context.today"),
                    .string("personal.chat.assist.agenda-query")
                ]),
                "interests": .list([
                    .string("agenda"),
                    .string("calendar"),
                    .string("reminders"),
                    .string("daily-planning"),
                    .string("agenda-aspects")
                ]),
                "readKeypaths": .list([
                    .string("agenda.today"),
                    .string("agenda.next"),
                    .string("agenda.summary"),
                    .string("agenda.permissionStatus")
                ]),
                "writeKeypaths": .list([
                    .string("agenda.answerQuery"),
                    .string("agenda.refresh"),
                    .string("agenda.publishPerspectiveSignals")
                ]),
                "requiresUserApproval": .bool(true),
                "requiresSignedRemoteIntent": .bool(false),
                "requiresLocalReview": .bool(false)
            ],
            [
                "id": .string("contact-endpoint:binding-contact-endpoint"),
                "kind": .string("contact_endpoint"),
                "title": .string("Kontakt-endepunkt"),
                "summary": .string("Signert foresporsel til en annen entitets endpoint-cell."),
                "sourceCellEndpoint": .string("cell:///ContactEndpoint"),
                "sourceCellName": .string("BindingContactEndpointCell"),
                "endpoint": .string("cell:///ContactEndpoint"),
                "actionKeypath": .string("contact.request"),
                "purposeRefs": .list([
                    .string("personal.chat.assist.entity-contact-request"),
                    .string("personal.chat.assist.resource-router")
                ]),
                "interests": .list([
                    .string("contact-endpoint"),
                    .string("entity-extension"),
                    .string("signed-intent"),
                    .string("requires-user-approval")
                ]),
                "grantStatus": .string("available_in_cell_scope"),
                "availability": .string("available_in_cell_scope"),
                "requiresGrant": .bool(true),
                "requiresSignedIntent": .bool(true),
                "requiresUserApproval": .bool(true),
                "sideEffectUntilExplicitRequest": .bool(false)
            ],
            [
                "id": .string("agent-action:personal.agent.binding.wake"),
                "kind": .string("agent_action"),
                "title": .string("HAVENAgentD review"),
                "summary": .string("Autocomplete-safe lokal agent bridge; chat oppretter bare signert review-intent."),
                "sourceCellEndpoint": .string("cell:///agent/intents/inbox"),
                "sourceCellName": .string("RemoteIntentInboxCell"),
                "configurationName": .string("HAVENAgentD local bridge"),
                "executionScope": .string("local_agent"),
                "grantStatus": .string("requires_signed_agent_bridge"),
                "availability": .string("requires_signed_agent_bridge"),
                "purposeRefs": .list([
                    .string("personal.agent.binding.wake"),
                    .string("personal.agent.local.gui.finder.close-windows")
                ]),
                "interests": .list([
                    .string("agentd"),
                    .string("signed-intent"),
                    .string("local-review")
                ]),
                "readKeypaths": .list([.string("agent-actions/v1/search")]),
                "writeKeypaths": .list([
                    .string("agent.review.create"),
                    .string("agent.review.execute")
                ]),
                "requiresUserApproval": .bool(true),
                "requiresSignedRemoteIntent": .bool(true),
                "requiresLocalReview": .bool(true)
            ]
        ]
    }

    nonisolated private static func providerExtensionRow(_ provider: BindingChatProviderDescriptor) -> Object {
        [
            "id": .string("provider:\(provider.id)"),
            "kind": .string("provider"),
            "providerKind": .string(provider.kind),
            "title": .string(provider.title),
            "summary": .string(provider.summary),
            "sourceCellEndpoint": provider.endpoint.map(ValueType.string) ?? .null,
            "sourceCellName": .string(provider.sourceCellName ?? "ChatScopedAIProvider"),
            "configurationName": .string("Co-Pilot Chat AI Provider"),
            "executionScope": .string(provider.executionScope),
            "grantStatus": .string(provider.availability),
            "availability": .string(provider.availability),
            "privacyLevel": .string(provider.privacyLevel),
            "purposeRefs": .list(provider.purposeRefs.map(ValueType.string)),
            "interests": .list(provider.interests.map(ValueType.string)),
            "readKeypaths": .list([
                .string("assistantProviders"),
                .string("providerRecommendation")
            ]),
            "writeKeypaths": .list([
                .string(provider.actionKeypath ?? "assistant.provider.recommend")
            ]),
            "requiresUserApproval": .bool(true),
            "requiresSignedRemoteIntent": .bool(false),
            "requiresLocalReview": .bool(false),
            "canInvokeFromChat": .bool(provider.canInvokeFromChat)
        ]
    }

    nonisolated private static func deduplicatedExtensionRows(_ rows: [Object]) -> [Object] {
        var seen = Set<String>()
        return rows.filter { row in
            let id = BindingChatValue.string(row["id"]) ?? UUID().uuidString
            return seen.insert(id).inserted
        }.sorted { lhs, rhs in
            let leftKind = BindingChatValue.string(lhs["kind"]) ?? ""
            let rightKind = BindingChatValue.string(rhs["kind"]) ?? ""
            if leftKind == rightKind {
                return (BindingChatValue.string(lhs["title"]) ?? "") < (BindingChatValue.string(rhs["title"]) ?? "")
            }
            return leftKind < rightKind
        }
    }

    nonisolated private static func extensionKindCounts(_ rows: [Object]) -> Object {
        var counts: [String: Int] = [:]
        for row in rows {
            let kind = BindingChatValue.string(row["kind"]) ?? "unknown"
            counts[kind, default: 0] += 1
        }
        return counts.reduce(into: Object()) { result, item in
            result[item.key] = .integer(item.value)
        }
    }

    nonisolated private static func entityExtensionSummary(counts: Object) -> String {
        let cellConfigurations = Int(BindingChatValue.double(counts["cell_configuration"]) ?? 0)
        let agentActions = Int(BindingChatValue.double(counts["agent_action"]) ?? 0)
        let providers = Int(BindingChatValue.double(counts["provider"]) ?? 0)
        return "\(cellConfigurations) synlige CellConfigurations, \(agentActions) agent-actions og \(providers) chat-scopede provider(e). Ingen global identitet eller global provider brukes."
    }

    private func openSuggestedHelper() -> ValueType {
        guard let suggestion = BindingChatValue.object(BindingChatValue.nested("assistant.latestSuggestion", in: cachedState)),
              let helper = BindingChatValue.string(suggestion["helperID"]),
              !helper.isEmpty,
              BindingChatValue.string(suggestion["status"]) != "low_confidence"
        else {
            return .object([
                "ok": .bool(false),
                "status": .string("no_suggestion"),
                "sideEffect": .bool(false)
            ])
        }

        let surface = helperSurface(kind: helper, source: "suggestion")
        appendSurface(surface)
        return .object([
            "ok": .bool(true),
            "helper": .string(helper),
            "surface": .object(surface),
            "sideEffect": .bool(false)
        ])
    }

    private func openComponentSurface(_ value: ValueType) -> ValueType {
        let object = BindingChatValue.object(value) ?? [:]
        let kind = BindingChatValue.string(object["kind"]) ?? BindingChatValue.string(object["helperID"]) ?? "custom"
        let surface = helperSurface(kind: kind, source: "direct")
        appendSurface(surface)
        return .object([
            "ok": .bool(true),
            "helper": .string(kind),
            "surface": .object(surface),
            "sideEffect": .bool(false)
        ])
    }

    private func appendSurface(_ surface: Object) {
        var surfaces = BindingChatValue.list(BindingChatValue.nested("ui.componentSurfaces", in: cachedState)) ?? []
        surfaces.removeAll { BindingChatValue.string(BindingChatValue.object($0)?["id"]) == BindingChatValue.string(surface["id"]) }
        surfaces.append(.object(surface))
        BindingChatValue.set(.list(surfaces), for: "ui.componentSurfaces", in: &cachedState)
        BindingChatValue.set(.string("aktivt"), for: "ui.activeTab", in: &cachedState)
        if let kind = BindingChatValue.string(surface["kind"]) {
            BindingChatValue.set(.string(kind), for: "ui.activeHelper", in: &cachedState)
        }
        if let id = BindingChatValue.string(surface["id"]) {
            BindingChatValue.set(.string(id), for: "ui.activeComponentSurfaceID", in: &cachedState)
        }
        BindingChatValue.set(.object([
            "hint": .string("appear"),
            "sourceRole": .string("suggestion-card")
        ]), for: "ui.lastMotionEvent", in: &cachedState)
        refreshActiveToolChips(from: surfaces)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)
    }

    private func markSurface(_ value: ValueType, state: String) -> ValueType {
        let requestedID = selectedSurfaceID(from: value)
        let fallbackID = BindingChatValue.string(BindingChatValue.nested("ui.activeComponentSurfaceID", in: cachedState)) ?? ""
        let id = requestedID.isEmpty ? fallbackID : requestedID
        var surfaces = BindingChatValue.list(BindingChatValue.nested("ui.componentSurfaces", in: cachedState)) ?? []
        surfaces = surfaces.map { item in
            guard var surface = BindingChatValue.object(item) else { return item }
            if id.isEmpty == false && BindingChatValue.string(surface["id"]) == id {
                surface["state"] = .string(state)
                surface["motionHint"] = .string(state == "minimized" ? "minimize" : state == "open" ? "restore" : "collapse")
            }
            return .object(surface)
        }
        BindingChatValue.set(.list(surfaces), for: "ui.componentSurfaces", in: &cachedState)
        BindingChatValue.set(.list(surfaces.filter {
            BindingChatValue.string(BindingChatValue.object($0)?["state"]) == "minimized"
        }), for: "ui.minimizedComponentSurfaces", in: &cachedState)
        BindingChatValue.set(.object([
            "hint": .string(state == "minimized" ? "minimize" : state == "open" ? "restore" : "collapse"),
            "sourceRole": .string("component-surface")
        ]), for: "ui.lastMotionEvent", in: &cachedState)
        refreshActiveToolChips(from: surfaces)
        if state == "dismissed" {
            let visibleSurfaceID = surfaces.compactMap { item -> String? in
                guard let surface = BindingChatValue.object(item),
                      BindingChatValue.string(surface["state"]) != "dismissed" else { return nil }
                return BindingChatValue.string(surface["id"])
            }.first ?? ""
            BindingChatValue.set(.string(visibleSurfaceID), for: "ui.activeComponentSurfaceID", in: &cachedState)
        }
        return .object(["ok": .bool(true), "sideEffect": .bool(false), "surfaceState": .string(state)])
    }

    private func selectedSurfaceID(from value: ValueType) -> String {
        if let direct = BindingChatValue.string(value), direct.isEmpty == false {
            return direct
        }
        guard let object = BindingChatValue.object(value) else { return "" }
        return selectedSurfaceID(in: object)
    }

    private func selectedSurfaceID(in object: Object) -> String {
        for key in ["surfaceID", "id", "value", "selected", "interacted", "selectedValue"] {
            if let value = BindingChatValue.string(object[key]), value.isEmpty == false {
                return value
            }
            if let nested = BindingChatValue.object(object[key]) {
                let value = selectedSurfaceID(in: nested)
                if value.isEmpty == false {
                    return value
                }
            }
        }
        return ""
    }

    private func refreshActiveToolChips(from surfaces: [ValueType]? = nil) {
        let sourceSurfaces = surfaces ?? BindingChatValue.list(BindingChatValue.nested("ui.componentSurfaces", in: cachedState)) ?? []
        let chips = sourceSurfaces.compactMap { item -> ValueType? in
            guard let surface = BindingChatValue.object(item),
                  BindingChatValue.string(surface["state"]) != "dismissed" else { return nil }
            return .object(activeToolChip(from: surface))
        }
        BindingChatValue.set(.list(chips), for: "ui.activeToolChips", in: &cachedState)
    }

    private func activeToolChip(from surface: Object) -> Object {
        let id = BindingChatValue.string(surface["id"]) ?? ""
        return [
            "id": .string(id),
            "kind": surface["kind"] ?? .string(""),
            "title": surface["title"] ?? .string(id),
            "state": surface["state"] ?? .string("open"),
            "summary": surface["summary"] ?? .string(""),
            "label": .string("Fjern"),
            "keypath": .string("chatHub.ui.dismissComponentSurface"),
            "payload": .object([
                "surfaceID": .string(id)
            ])
        ]
    }

    private func pinSurface(_ value: ValueType) -> ValueType {
        let id = BindingChatValue.string(BindingChatValue.object(value)?["surfaceID"])
            ?? BindingChatValue.string(BindingChatValue.object(value)?["id"])
            ?? ""
        var surfaces = BindingChatValue.list(BindingChatValue.nested("ui.componentSurfaces", in: cachedState)) ?? []
        surfaces = surfaces.map { item in
            guard var surface = BindingChatValue.object(item) else { return item }
            if id.isEmpty || BindingChatValue.string(surface["id"]) == id {
                surface["pinned"] = .bool(true)
            }
            return .object(surface)
        }
        BindingChatValue.set(.list(surfaces), for: "ui.componentSurfaces", in: &cachedState)
        return .object(["ok": .bool(true), "sideEffect": .bool(false)])
    }

    private func dismissSuggestion() -> ValueType {
        let empty = BindingChatIntentClassifier.classify(prompt: "").objectValue()
        BindingChatValue.set(.object(empty), for: "assistant.latestSuggestion", in: &cachedState)
        BindingChatValue.set(.list([]), for: "assistant.suggestions", in: &cachedState)
        BindingChatValue.set(.string("dismissed"), for: "assistant.status", in: &cachedState)
        return .object(["ok": .bool(true), "sideEffect": .bool(false)])
    }

    private func acceptSuggestion() -> ValueType {
        guard let suggestion = BindingChatValue.object(BindingChatValue.nested("assistant.latestSuggestion", in: cachedState)),
              let helper = BindingChatValue.string(suggestion["helperID"]),
              !helper.isEmpty,
              BindingChatValue.string(suggestion["status"]) != "low_confidence"
        else {
            return response(status: "blocked", message: "No suggestion to accept.")
        }

        switch helper {
        case "invite":
            return createInvite()
        case "poll":
            return createPoll()
        default:
            return createWorkbenchModule(kind: helper)
        }
    }

    private func queryResource(_ value: ValueType, requester: Identity) async -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        let prompt = BindingChatValue.string(payload["query"])
            ?? BindingChatValue.string(payload["text"])
            ?? BindingChatValue.string(payload["prompt"])
            ?? BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState))
            ?? ""
        let computedMatches = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? []
            : BindingChatIntentClassifier.resourceMatches(prompt: prompt)
        let cachedMatches = (BindingChatValue.list(BindingChatValue.nested("assistant.resourceMatches", in: cachedState)) ?? [])
            .compactMap { BindingChatValue.object($0) }
        let matches = computedMatches.isEmpty ? cachedMatches : computedMatches
        if matches.contains(where: { BindingChatValue.string($0["kind"]) == "agenda_context" }),
           let resolver = CellBase.defaultCellResolver as? CellResolver,
           let agenda = try? await resolver.cellAtEndpoint(endpoint: "cell:///PersonalAgendaContext", requester: requester) as? Meddle,
           let answer = try? await agenda.set(
                keypath: "agenda.answerQuery",
                value: .object([
                    "query": .string(prompt.isEmpty ? "Hva er på agendaen i dag?" : prompt)
                ]),
                requester: requester
           ) {
            BindingChatValue.set(answer, for: "assistant.lastResourceAnswer", in: &cachedState)
            return answer
        }
        if let resource = matches.first(where: { BindingChatValue.string($0["kind"]) == "cell_configuration" }) {
            let portholeUI = BindingChatIntentClassifier.libraryUIRequest(for: resource, autoOpen: true)
            return .object([
                "ok": .bool(true),
                "status": .string("library_open_requested"),
                "sideEffect": .bool(false),
                "resource": .object(resource),
                "portholeUI": .object(portholeUI),
                "resourceMatches": .list(matches.map(ValueType.object)),
                "message": .string("Library open request is staged for explicit user action.")
            ])
        }

        return .object([
            "ok": .bool(true),
            "status": .string("ready_for_explicit_query"),
            "sideEffect": .bool(false),
            "resourceMatches": .list(matches.map(ValueType.object)),
            "message": .string("RAG-query is staged only for an explicit user action.")
        ])
    }

    private func setComposer(_ value: ValueType) -> ValueType {
        let body: String
        if let object = BindingChatValue.object(value) {
            body = BindingChatValue.string(object["body"]) ?? BindingChatValue.string(object["text"]) ?? ""
        } else {
            body = text(from: value)
        }
        BindingChatValue.set(.string(body), for: "currentThread.composer.body", in: &cachedState)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)
        return response(status: "ok", message: "Composer draft updated.")
    }

    private func sendComposedMessage() -> ValueType {
        let body = BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState)) ?? ""
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return response(status: "blocked", message: "Write a message before sending.")
        }
        guard BindingChatValue.string(BindingChatValue.nested("inviteStatus", in: cachedState)) == "accepted" else {
            return response(status: "blocked", message: "Invite-only chat requires an accepted invitation before sending.")
        }
        guard (BindingChatValue.list(BindingChatValue.nested("blockedUsers", in: cachedState)) ?? []).isEmpty else {
            return response(status: "blocked", message: "Blocked chat participants cannot continue in this thread.")
        }
        var messages = BindingChatValue.list(BindingChatValue.nested("messages", in: cachedState)) ?? []
        messages.append(.object([
            "id": .string(UUID().uuidString),
            "authorDisplayName": .string("Deg"),
            "body": .string(body),
            "sentAt": .float(Date().timeIntervalSince1970)
        ]))
        BindingChatValue.set(.list(messages), for: "messages", in: &cachedState)
        BindingChatValue.set(.integer(messages.count), for: "messageCount", in: &cachedState)
        BindingChatValue.set(.string(""), for: "currentThread.composer.body", in: &cachedState)
        return response(status: "ok", message: "Message sent locally.")
    }

    private func setMeetingBridgeMetadata(_ value: ValueType) -> ValueType {
        var bridge = BindingChatValue.object(value) ?? [:]
        bridge["v1RenderMode"] = .string("placeholder")
        bridge["requiresCameraMicrophoneConsent"] = .bool(true)
        bridge["nativePermissionsRequested"] = .bool(false)
        BindingChatValue.set(.object(bridge), for: "meetingBridge", in: &cachedState)
        return .object([
            "ok": .bool(true),
            "meetingBridge": .object(bridge),
            "sideEffect": .bool(false)
        ])
    }

    private func createInvite() -> ValueType {
        var invites = BindingChatValue.list(BindingChatValue.nested("invites", in: cachedState)) ?? []
        let title = BindingChatValue.string(BindingChatValue.nested("inviteDraft.title", in: cachedState)) ?? "Ny invitasjon"
        invites.append(.object([
            "id": .string(UUID().uuidString),
            "title": .string(title),
            "status": .string("pending")
        ]))
        BindingChatValue.set(.list(invites), for: "invites", in: &cachedState)
        BindingChatValue.set(.integer(invites.count), for: "threadCount", in: &cachedState)
        return response(status: "ok", message: "Invite created after explicit confirmation.")
    }

    private func createPoll() -> ValueType {
        var polls = BindingChatValue.list(BindingChatValue.nested("polls", in: cachedState)) ?? []
        let question = BindingChatValue.string(BindingChatValue.nested("pollDraft.question", in: cachedState)) ?? "Ny avstemning"
        polls.append(.object([
            "id": .string(UUID().uuidString),
            "question": .string(question),
            "status": .string("open")
        ]))
        BindingChatValue.set(.list(polls), for: "polls", in: &cachedState)
        return response(status: "ok", message: "Poll created after explicit confirmation.")
    }

    private func createWorkbenchModule(kind: String) -> ValueType {
        let normalizedKind = workbenchKind(from: kind)
        var modules = BindingChatValue.list(BindingChatValue.nested("workbench.modules", in: cachedState)) ?? []
        modules.append(.object([
            "id": .string(UUID().uuidString),
            "title": .string(helperTitle(normalizedKind)),
            "kind": .string(normalizedKind),
            "status": .string(normalizedKind == "agent-review" ? "requires_signed_review" : "draft")
        ]))
        BindingChatValue.set(.list(modules), for: "workbench.modules", in: &cachedState)
        BindingChatValue.set(.integer(modules.count), for: "workbench.moduleCount", in: &cachedState)
        return response(status: "ok", message: "Workbench module created after explicit confirmation.")
    }

    private func submitCapabilityRequest(_ value: ValueType) -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        var draft = BindingChatValue.object(BindingChatValue.nested("workbench.capabilityRequestDraft", in: cachedState)) ?? [:]
        for field in ["title", "summary", "destination", "category"] {
            if let fieldValue = BindingChatValue.string(payload[field]) {
                draft[field] = .string(fieldValue)
            }
        }
        let title = BindingChatValue.string(draft["title"]) ?? "Nytt behov fra Co-Pilot Chat"
        let destination = BindingChatValue.string(draft["destination"]) ?? "local-review"
        let request: Object = [
            "id": .string(UUID().uuidString),
            "title": .string(title),
            "summary": draft["summary"] ?? .string(""),
            "destination": .string(destination),
            "category": draft["category"] ?? .string("cellprotocol"),
            "status": .string("submitted_after_explicit_click"),
            "auditEvent": .string("capability_request_submitted")
        ]
        var requests = BindingChatValue.list(BindingChatValue.nested("capabilityRequests", in: cachedState)) ?? []
        requests.append(.object(request))
        BindingChatValue.set(.list(requests), for: "capabilityRequests", in: &cachedState)
        _ = createWorkbenchModule(kind: "capability-request")
        return .object([
            "ok": .bool(true),
            "request": .object(request),
            "auditEvent": .string("capability_request_submitted"),
            "sideEffect": .bool(true)
        ])
    }

    private func workbenchKind(from actionOrHelper: String) -> String {
        switch actionOrHelper {
        case "meeting.schedule", "meeting":
            return "meeting"
        case "idea.capture", "idea", "idea-capture":
            return "idea-capture"
        case "todo.create", "todo":
            return "todo"
        case "project.create", "project":
            return "project"
        case "reminder.create", "reminder":
            return "reminder"
        case "agent.review.create", "agent.review.execute", "agent.reviewIntent", "agent-review", "agent-setup":
            return "agent-review"
        case "capabilityRequest.submit", "capability-request":
            return "capability-request"
        default:
            return actionOrHelper
        }
    }

    private func response(status: String, message: String) -> ValueType {
        cachedState["status"] = .string(message)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)
        return .object([
            "status": .string(status),
            "message": .string(message),
            "userMessage": .string(message),
            "retryable": .bool(status == "blocked"),
            "state": .object(cachedState)
        ])
    }

    private func candidateRows(for suggestion: BindingChatIntentClassification) -> [ValueType] {
        guard suggestion.helperID == "invite" else { return [] }
        let ambiguous = suggestion.status == "needs_candidate_selection"
        let rows: [Object] = ambiguous
            ? [
                ["id": .string("anna-kollega"), "displayName": .string("Anna Kollega"), "headline": .string("Kollega"), "summary": .string("Mulig treff fra granted profile descriptor.")],
                ["id": .string("anja-kollega"), "displayName": .string("Anja Kollega"), "headline": .string("Kollega"), "summary": .string("Mulig treff fra granted profile descriptor.")]
            ]
            : [
                ["id": .string("anna-kollega"), "displayName": .string("Anna Kollega"), "headline": .string("Naermeste kollega"), "summary": .string("Beste lokale treff i chat-scope.")]
            ]
        return rows.map(ValueType.object)
    }

    private func helperSurface(kind: String, source: String) -> Object {
        let id = kind
        return [
            "id": .string(id),
            "kind": .string(kind),
            "title": .string(helperTitle(kind)),
            "summary": .string("Apnet fra Co-Pilot Chat. Handling skjer bare etter eksplisitt brukerklikk."),
            "state": .string("open"),
            "grantStatus": .string("granted_in_chat_scope"),
            "source": .string(source),
            "sourcePromptPreview": BindingChatValue.nested("currentThread.composer.body", in: cachedState) ?? .string(""),
            "sideEffect": .bool(false),
            "motionHint": .string("appear"),
            "motionSourceRole": .string("personal-chat-helper"),
            "requiresUserApproval": .bool(true)
        ]
    }

    private func helperTitle(_ kind: String) -> String {
        switch kind {
        case "invite": return "Inviter person"
        case "poll": return "Lag avstemning"
        case "idea-capture": return "Lagre ide"
        case "todo": return "Oppgave"
        case "project": return "Prosjekt"
        case "reminder": return "Paaminnelse"
        case "meeting": return "Mote"
        case "voice-input": return "Tale til tekst"
        case "agent-review": return "Agent-review"
        case "agent-setup": return "Agent-oppsett"
        case "capability-request": return "Meld behov"
        case "contact-endpoint": return "Kontakt-endepunkt"
        case "resource-router": return "Finn verktøy"
        default: return "Hjelper"
        }
    }

    private func text(from value: ValueType) -> String {
        switch value {
        case let .string(text): return text
        case let .integer(number): return String(number)
        case let .float(number): return String(number)
        case let .bool(flag): return flag ? "true" : "false"
        case let .object(object):
            return BindingChatValue.string(object["value"])
                ?? BindingChatValue.string(object["text"])
                ?? BindingChatValue.string(object["id"])
                ?? ""
        default:
            return ""
        }
    }

    private func deduplicatedProviders(_ providers: [BindingChatProviderDescriptor]) -> [BindingChatProviderDescriptor] {
        var seen = Set<String>()
        return providers.filter { provider in
            seen.insert(provider.id).inserted
        }
    }

    nonisolated static func initialState() -> Object {
        return [
            "title": .string("Co-Pilot Chat"),
            "status": .string("Co-Pilot Chat is ready."),
            "threadCount": .integer(0),
            "messageCount": .integer(0),
            "inviteStatus": .string("not invited"),
            "blockedUsers": .list([]),
            "moderationStatus": .string("ready"),
            "currentThread": .object([
                "id": .string("local-copilot-thread"),
                "title": .string("Co-Pilot Chat"),
                "composer": .object([
                    "body": .string(""),
                    "contentType": .string("text/plain")
                ])
            ]),
            "threads": .list([]),
            "messages": .list([]),
            "invites": .list([]),
            "inviteDraft": .object([
                "title": .string(""),
                "profileID": .string(""),
                "userUUID": .string(""),
                "contactEndpoint": .null
            ]),
            "polls": .list([]),
            "pollDraft": .object([
                "question": .string(""),
                "optionsText": .string("")
            ]),
            "workbench": .object([
                "modules": .list([]),
                "moduleCount": .integer(0),
                "ideaDraft": .object([
                    "title": .string(""),
                    "content": .string(""),
                    "targetCellEndpoint": .string("cell:///Vault"),
                    "targetActionKeypath": .string("idea.capture")
                ]),
                "todoDraft": .object([
                    "title": .string(""),
                    "note": .string(""),
                    "dueAtText": .string(""),
                    "assigneeUUID": .string("")
                ]),
                "projectDraft": .object([
                    "title": .string(""),
                    "description": .string(""),
                    "membersText": .string("")
                ]),
                "reminderDraft": .object([
                    "title": .string(""),
                    "scheduledAtText": .string(""),
                    "scope": .string("me")
                ]),
                "meetingDraft": .object([
                    "title": .string(""),
                    "targetProfileID": .string(""),
                    "proposedTimesText": .string("")
                ]),
                "agentReviewDraft": .object([
                    "actionID": .string(""),
                    "reason": .string(""),
                    "argumentsText": .string("{}"),
                    "signatureBase64": .string("")
                ]),
                "capabilityRequestDraft": .object([
                    "title": .string(""),
                    "summary": .string(""),
                    "destination": .string("local-review"),
                    "category": .string("cellprotocol")
                ])
            ]),
            "capabilityRequests": .list([]),
            "entityExtension": .object(Self.initialEntityExtensionState()),
            "voice": .object(Self.initialVoiceState()),
            "drop": .object([
                "validationState": .string("idle"),
                "deniedReason": .string("")
            ]),
            "meetingBridge": .object([
                "provider": .string("jitsi"),
                "v1RenderMode": .string("placeholder"),
                "requiresCameraMicrophoneConsent": .bool(true),
                "nativePermissionsRequested": .bool(false),
                "joinURL": .string("")
            ]),
            "ui": .object([
                "activeTab": .string("samtale"),
                "activeMoreTab": .string("verktoy"),
                "activeHelper": .string("invite"),
                "activeComponentSurfaceID": .string(""),
                "combinedChatView": .bool(true),
                "showAdvanced": .bool(false),
                "learningStatus": .string("paused"),
                "capabilityDiscoveryEnabled": .bool(false),
                "capabilityDiscoveryStatus": .string("off"),
                "humanPresenceSummary": .string("Privat forslag forst; menneskechat oppdateres bare naar du sender eller inviterer."),
                "promptOnlyReason": .string("Co-piloten leser bare ditt aktive utkast naar du klikker Finn forslag."),
                "tabs": .list([
                    .object(["id": .string("samtale"), "title": .string("Samtale")]),
                    .object(["id": .string("aktivt"), "title": .string("Aktivt")]),
                    .object(["id": .string("mer"), "title": .string("Mer")])
                ]),
                "moreTabs": .list([
                    .object(["id": .string("verktoy"), "title": .string("Verktoy")]),
                    .object(["id": .string("hjelp"), "title": .string("Hjelp")]),
                    .object(["id": .string("ai"), "title": .string("AI")]),
                    .object(["id": .string("moderering"), "title": .string("Moderering")]),
                    .object(["id": .string("personvern"), "title": .string("Personvern")]),
                    .object(["id": .string("avansert"), "title": .string("Avansert")])
                ]),
                "helpers": .list([
                    .object(["id": .string("invite"), "title": .string("Inviter")]),
                    .object(["id": .string("poll"), "title": .string("Avstemning")]),
                    .object(["id": .string("idea-capture"), "title": .string("Fang ide")]),
                    .object(["id": .string("todo"), "title": .string("Oppgave")]),
                    .object(["id": .string("project"), "title": .string("Prosjekt")]),
                    .object(["id": .string("reminder"), "title": .string("Paaminnelse")]),
                    .object(["id": .string("meeting"), "title": .string("Mote")]),
                    .object(["id": .string("voice-input"), "title": .string("Tale")]),
                    .object(["id": .string("agent-review"), "title": .string("Agent-review")]),
                    .object(["id": .string("agent-setup"), "title": .string("Agent-oppsett")]),
                    .object(["id": .string("capability-request"), "title": .string("Meld behov")])
                ]),
                "componentSurfaces": .list([]),
                "activeToolChips": .list([]),
                "minimizedComponentSurfaces": .list([]),
                "absorbedChats": .list([]),
                "promptParticipants": .list([
                    .object([
                        "badge": .string("Privat"),
                        "title": .string("Ditt utkast"),
                        "summary": .string("Leses bare ved Finn forslag.")
                    ])
                ]),
                "lastMotionEvent": .object([
                    "hint": .string("none"),
                    "sourceRole": .string("")
                ])
            ]),
            "assistant": .object([
                "status": .string("idle"),
                "mode": .string("suggestion_first"),
                "intentEngine": .string("deterministic_with_optional_cell_scoped_provider"),
                "candidateQuery": .string(""),
                "pollPrerequisite": .string("Krever aktiv gruppechat med minst to aksepterte deltakere."),
                "latestSuggestion": .object(BindingChatIntentClassifier.classify(prompt: "").objectValue()),
                "suggestions": .list([]),
                "intentCandidates": .list([]),
                "priorityIntent": .null,
                "whySummary": .string("Skriv et utkast og trykk Finn forslag."),
                "assistantProviders": .list([.object(BindingChatProviderRouter.localRulesProvider().objectValue())]),
                "providerRecommendation": .object(BindingChatProviderRouter.localRulesProvider().objectValue()),
                "providerCount": .integer(1),
                "resourceMatches": .list([]),
                "resourceMatchCount": .integer(0),
                "requiresUserApproval": .bool(true),
                "sideEffectsRequireClick": .bool(true),
                "policy": .object([
                    "allEffectsRequireExplicitUserAction": .bool(true),
                    "analyzeHasNoSideEffects": .bool(true),
                    "openHelperHasNoSideEffects": .bool(true),
                    "providersMustBeScoped": .bool(true)
                ])
            ]),
            "privacy": .object([
                "learningEnabled": .bool(false),
                "contextPolicy": .string("draft + perspective summary + granted descriptors only")
            ]),
            "purposeWeights": .object([
                "directPurposeHit": .float(1.0),
                "interestHit": .float(0.6),
                "lexicalFallback": .float(0.25)
            ]),
            "purposeGoal": .object([
                "purposeRefs": .list([
                    .string("personal.chat.assist.invite"),
                    .string("personal.chat.assist.poll"),
                    .string("personal.chat.assist.meeting.video"),
                    .string("personal.chat.assist.meeting.schedule"),
                    .string("personal.chat.assist.project"),
                    .string("personal.chat.assist.todo"),
                    .string("personal.chat.assist.reminder"),
                    .string("personal.chat.assist.capability-request"),
                    .string("personal.chat.assist.entity-contact-request"),
                    .string("personal.chat.assist.moderation"),
                    .string("personal.chat.assist.resource-router")
                ])
            ]),
            "skeletonConfiguration": .object([
                "name": .string("Co-Pilot Chat"),
                "endpoint": .string("cell:///PersonalChatHub")
            ]),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Array where Element == String {
    var nilIfEmpty: [String]? {
        isEmpty ? nil : self
    }
}

private extension ValueType {
    var stringValueIfPossible: String? {
        guard case let .string(text) = self else { return nil }
        return text
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
private struct BindingAppleStructuredIntent {
    @Guide(description: "Intent kind such as invite_person, create_poll, idea_capture, todo, project, reminder, schedule_meeting, meeting_video, agent_action, or none.")
    var intentKind: String
    @Guide(description: "Canonical HAVEN purpose reference for the intent.")
    var purposeRef: String
    @Guide(description: "Short interest tags used for routing.")
    var interests: [String]
    @Guide(description: "Helper id such as invite, poll, idea-capture, todo, project, reminder, meeting, agent-review, or empty.")
    var helperID: String
    @Guide(description: "Confidence from 0.0 to 1.0.")
    var confidence: Double
    @Guide(description: "Always true for chat-originated helper or provider actions.")
    var requiresUserApproval: Bool
    @Guide(description: "Short human reason for the classification.")
    var reason: String
    @Guide(description: "Set to the forbidden intent when the user says not to do an action; otherwise empty.")
    var negativeIntent: String
    @Guide(description: "suggested, needs_candidate_selection, or low_confidence.")
    var status: String

    func classification(fallback: BindingChatIntentClassification) -> BindingChatIntentClassification {
        let cleanStatus = ["suggested", "needs_candidate_selection", "low_confidence"].contains(status) ? status : fallback.status
        let cleanKind = intentKind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback.intentKind : intentKind
        return BindingChatIntentClassification(
            intentKind: cleanKind,
            purposeRef: purposeRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback.purposeRef : purposeRef,
            interests: interests.isEmpty ? fallback.interests : interests,
            helperID: helperID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback.helperID : helperID,
            confidence: min(1.0, max(0.0, confidence)),
            requiresUserApproval: true,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback.reason : reason,
            negativeIntent: negativeIntent,
            status: cleanStatus
        )
    }
}
#endif
