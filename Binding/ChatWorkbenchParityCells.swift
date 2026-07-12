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
            "explanation": .string(explanation),
            "targetPhrase": .string(helperID.isEmpty ? intentKind : helperID),
            "weightedScore": .float(confidence),
            "availability": .string(shouldSuggest ? "available_in_chat_scope" : "not_selected")
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
        case "work-item":
            return "Jeg kan apne feil/work-item-hjelperen som et utkast. Ingenting registreres for du bekrefter."
        case "docs-rag":
            return "Jeg kan apne docs/RAG-hjelperen. Kilder eller RAG spors ikke for du klikker eksplisitt."
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

struct BindingChatPurposeContext: Codable, Equatable {
    var purposeRefs: [String]
    var interests: [String]
    var weights: [String: Double]
    var source: String

    nonisolated static let empty = BindingChatPurposeContext(
        purposeRefs: [],
        interests: [],
        weights: [:],
        source: "none"
    )

    nonisolated var isEmpty: Bool {
        purposeRefs.isEmpty && interests.isEmpty
    }

    nonisolated func merging(_ other: BindingChatPurposeContext) -> BindingChatPurposeContext {
        guard other.isEmpty == false else { return self }
        guard isEmpty == false else { return other }
        var mergedWeights = weights
        for (key, value) in other.weights {
            mergedWeights[key] = max(mergedWeights[key] ?? 0, value)
        }
        let mergedSources = [source, other.source]
            .filter { $0.isEmpty == false && $0 != "none" }
        return BindingChatPurposeContext(
            purposeRefs: Array(Set(purposeRefs + other.purposeRefs)).sorted(),
            interests: Array(Set(interests + other.interests)).sorted(),
            weights: mergedWeights,
            source: mergedSources.isEmpty ? "none" : mergedSources.joined(separator: " + ")
        )
    }

    nonisolated func objectValue() -> Object {
        [
            "source": .string(source),
            "purposeRefs": .list(purposeRefs.map(ValueType.string)),
            "interests": .list(interests.map(ValueType.string)),
            "weights": .object(weights.reduce(into: Object()) { partial, pair in
                partial[pair.key] = .float(pair.value)
            }),
            "isEmpty": .bool(isEmpty)
        ]
    }

    nonisolated func matchesPurpose(_ needles: [String]) -> Bool {
        matches(values: purposeRefs, needles: needles)
    }

    nonisolated func matchesInterest(_ needles: [String]) -> Bool {
        matches(values: interests, needles: needles)
    }

    nonisolated func contextBoost(purposeRefs targetPurposeRefs: [String], interests targetInterests: [String]) -> Double {
        let purposeBoost = overlapScore(
            values: purposeRefs,
            targets: targetPurposeRefs,
            exactWeight: 0.16,
            tokenWeight: 0.05
        )
        let interestBoost = overlapScore(
            values: interests,
            targets: targetInterests,
            exactWeight: 0.07,
            tokenWeight: 0.03
        )
        return min(0.24, purposeBoost + interestBoost)
    }

    nonisolated static func from(value: ValueType?, source: String) -> BindingChatPurposeContext {
        guard let value else { return .empty }
        var builder = Builder()
        builder.collect(value, explicitHint: nil, inheritedWeight: nil)
        return builder.build(source: source)
    }

    nonisolated private func matches(values: [String], needles: [String]) -> Bool {
        let normalizedValues = values.map(Self.normalizedToken)
        return needles.contains { needle in
            let normalizedNeedle = Self.normalizedToken(needle)
            return normalizedValues.contains { value in
                value == normalizedNeedle
                    || value.contains(normalizedNeedle)
                    || normalizedNeedle.contains(value)
            }
        }
    }

    nonisolated private func overlapScore(
        values: [String],
        targets: [String],
        exactWeight: Double,
        tokenWeight: Double
    ) -> Double {
        let normalizedValues = values.map(Self.normalizedToken)
        let normalizedTargets = targets.map(Self.normalizedToken)
        var score = 0.0
        for target in normalizedTargets {
            if normalizedValues.contains(target) {
                score += exactWeight
            } else if normalizedValues.contains(where: { value in
                value.contains(target) || target.contains(value)
            }) {
                score += tokenWeight
            }
        }
        return score
    }

    nonisolated private static func normalizedToken(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum FieldHint {
        case purpose
        case interest
    }

    private struct Builder {
        var purposeRefs: Set<String> = []
        var interests: Set<String> = []
        var weights: [String: Double] = [:]

        mutating func collect(_ value: ValueType, explicitHint: FieldHint?, inheritedWeight: Double?) {
            switch value {
            case let .string(text):
                add(text, hint: explicitHint, weight: inheritedWeight)
            case let .list(values):
                for child in values {
                    collect(child, explicitHint: explicitHint, inheritedWeight: inheritedWeight)
                }
            case let .object(object):
                let localWeight = numeric(object["purposeWeight"])
                    ?? numeric(object["interestWeight"])
                    ?? numeric(object["weight"])
                    ?? inheritedWeight
                for (key, child) in object {
                    let hint = Self.hint(for: key)
                    if let hint {
                        collect(child, explicitHint: hint, inheritedWeight: localWeight)
                    } else if case .object = child {
                        collect(child, explicitHint: nil, inheritedWeight: localWeight)
                    } else if case .list = child {
                        collect(child, explicitHint: nil, inheritedWeight: localWeight)
                    }
                }
            default:
                break
            }
        }

        func build(source: String) -> BindingChatPurposeContext {
            BindingChatPurposeContext(
                purposeRefs: Array(purposeRefs).sorted(),
                interests: Array(interests).sorted(),
                weights: weights,
                source: source
            )
        }

        mutating private func add(_ text: String, hint: FieldHint?, weight: Double?) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return }
            switch hint {
            case .purpose:
                purposeRefs.insert(trimmed)
                if let weight {
                    weights[trimmed] = max(weights[trimmed] ?? 0, weight)
                }
            case .interest:
                interests.insert(trimmed)
                if let weight {
                    weights[trimmed] = max(weights[trimmed] ?? 0, weight)
                }
            case .none:
                break
            }
        }

        private func numeric(_ value: ValueType?) -> Double? {
            BindingChatValue.double(value)
        }

        private static func hint(for key: String) -> FieldHint? {
            let normalized = key
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")
            if [
                "purposeref",
                "portablepurposeref",
                "purposerefs",
                "activepurposes",
                "purposes"
            ].contains(normalized) {
                return .purpose
            }
            if [
                "interestref",
                "portableinterestref",
                "interestrefs",
                "activeinterests",
                "interests"
            ].contains(normalized) {
                return .interest
            }
            return nil
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
        let home = environment["HOME"] ?? defaultHomeDirectoryPath(fileManager: fileManager)
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
                "Åpne Agent Setup Workbench i HAVEN.",
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
                "Refresh starter-auth fra den parede HAVEN/agent-operator-flyten.",
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

    nonisolated private static func defaultHomeDirectoryPath(fileManager: FileManager) -> String {
        #if os(macOS)
        return fileManager.homeDirectoryForCurrentUser.path
        #else
        let fallbackHome = NSHomeDirectory().trimmingCharacters(in: .whitespacesAndNewlines)
        if fallbackHome.isEmpty == false {
            return fallbackHome
        }
        return fileManager.currentDirectoryPath
        #endif
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
        capabilityDiscoveryEnabled: Bool = false,
        scaffoldContextAvailable: Bool = false,
        perspectiveContext: BindingChatPurposeContext = .empty
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
        if isNegated(normalized, keywords: ["bug", "feil", "work item", "workitem"]) {
            return negative("work_item", reason: "Brukeren vil ikke registrere en feil eller et work item.")
        }
        if isNegated(normalized, keywords: ["onboarding", "onboard", "spørreskjema", "sporreundersokelse", "spørreundersøkelse"]) ||
            normalized.contains("gjorde onboarding") {
            return negative("guided_onboarding", reason: "Brukeren ber ikke om aa starte onboarding eller spørreskjema.")
        }
        if isNegated(normalized, keywords: ["finder", "agent", "script", "lukk"]) {
            return negative("agent_action", reason: "Brukeren vil ikke utfore agenthandlingen.")
        }
        if isNegated(normalized, keywords: ["codex", "start codex", "kodeassistent", "kode assistent", "prompt"]) {
            return negative("agent_codex_prompt", reason: "Brukeren vil ikke starte Codex-prompt.")
        }
        if isNegated(normalized, keywords: ["e-post", "epost", "email", "mail"]) {
            return negative("agent_email_draft", reason: "Brukeren vil ikke forberede e-post.")
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
        if looksLikeAgentEmailDraft(normalized) {
            return positive(
                kind: "agent_email_draft",
                purposeRef: "personal.agent.email.compose-draft",
                interests: ["agentd", "email", "e-post", "external-contact", "contact-fallback", "draft-only", "local-review", "requires-user-approval"],
                helperID: "agent-review",
                confidence: 0.84,
                reason: "Meldingen ber om aa forberede et e-postutkast via HAVENAgentD review, ikke sende direkte."
            )
        }
        if looksLikeAdminScaffoldLoad(normalized) {
            let hasExplicitScaffoldTarget = containsAny(normalized, ["staging", "scaffold"])
            guard scaffoldContextAvailable || hasExplicitScaffoldTarget else {
                return lowConfidence(reason: "Scaffold-kontekst mangler for aa velge riktig adminflate.")
            }
            if let resource = bestCellConfigurationResourceMatch(prompt: prompt) {
                return resourceMatchClassification(resource)
            }
        }
        if looksLikeWorkItem(normalized) {
            return positive(
                kind: "work_item",
                purposeRef: "personal.chat.assist.work-item.capture",
                interests: ["work-item", "bug-report", "work-item-capture", "requires-user-approval"],
                helperID: "work-item",
                confidence: 0.86,
                reason: "Meldingen beskriver en feil, observasjon eller oppgave som kan bli et work item etter eksplisitt brukerklikk."
            )
        }
        if looksLikeGuidedOnboarding(normalized) {
            return positive(
                kind: "guided_onboarding",
                purposeRef: "personal.chat.assist.guided-onboarding",
                interests: ["guided-onboarding", "guided-setup", "questionnaire", "requires-user-approval"],
                helperID: "onboarding",
                confidence: 0.88,
                reason: "Meldingen ber om veiledet oppsett/onboarding. Chatten kan aapne en trygg dialog uten aa skrive gjennom foer bruker bekrefter."
            )
        }
        if looksLikeExplicitRAGResourceQuery(normalized),
           let resource = bestKnowledgeResourceMatch(prompt: prompt) {
            return resourceMatchClassification(resource)
        }
        if looksLikeDocsRAG(normalized),
           let resource = bestKnowledgeResourceMatch(prompt: prompt) {
            return resourceMatchClassification(resource)
        }
        if looksLikeLocalResourceSurfaceRequest(normalized),
           let resource = bestCellConfigurationResourceMatch(prompt: prompt) {
            return resourceMatchClassification(resource)
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
        if looksLikeIdeaCapture(normalized) {
            return positive(
                kind: "idea_capture",
                purposeRef: "personal.chat.assist.idea.capture",
                interests: ["idea", "capture", "private"],
                helperID: "idea-capture",
                confidence: 0.86,
                reason: "Meldingen inneholder et nytt ideutkast."
            )
        }
        if looksLikeTodo(normalized) {
            return positive(
                kind: "todo",
                purposeRef: "personal.chat.assist.todo",
                interests: ["todo", "task", "private"],
                helperID: "todo",
                confidence: 0.86,
                reason: "Meldingen beskriver en oppgave."
            )
        }
        if looksLikeProject(normalized) {
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
        if let contextual = contextualPurposeClassification(
            normalized: normalized,
            perspectiveContext: perspectiveContext
        ) {
            return contextual
        }
        if let resource = bestCellConfigurationResourceMatch(prompt: prompt) {
            return resourceMatchClassification(resource)
        }

        return lowConfidence(reason: "Ingen trygg chat-helper traff med hoy nok sikkerhet.")
    }

    nonisolated private static func looksLikeWorkItem(_ normalized: String) -> Bool {
        containsAny(normalized, [
            "registrer feil",
            "rapporter feil",
            "bug",
            "feilrapport",
            "work item",
            "workitem",
            "regresjon",
            "repro",
            "forventet oppførsel",
            "forventet oppforsel",
            "det virker ikke",
            "går galt",
            "gar galt"
        ])
    }

    nonisolated private static func looksLikeGuidedOnboarding(_ normalized: String) -> Bool {
        if containsAny(normalized, ["vis", "hvilke", "status", "konfigurasjon", "konfigurasjonen"])
            && containsAny(normalized, ["aigateway", "ai gateway", "sprakmodeller", "språkmodeller", "modell"]) {
            return false
        }
        if containsAny(normalized, ["aigateway", "ai gateway", "modellgateway", "model gateway"])
            && containsAny(normalized, ["konfigurer", "konfigurere", "sett opp", "setup", "configure", "4o-mini", "api key", "api nøkkel"]) {
            return true
        }
        if containsAny(normalized, ["spørreskjema", "sporreundersokelse", "spørreundersøkelse", "brukerundersøkelse", "questionnaire", "survey", "betalingsvilje", "smertepunkter"])
            && containsAny(normalized, ["lag", "lage", "opprett", "bygg", "create", "make"]) {
            return true
        }
        return containsAny(normalized, ["onboard", "onboarding", "onboardes", "registrere meg", "konferanseprofil"])
            && containsAny(normalized, ["konferanse", "conference", "profil", "profile", "meg"])
    }

    nonisolated private static func looksLikeIdeaCapture(_ normalized: String) -> Bool {
        containsAny(normalized, [
            "jeg har en ide",
            "jeg har en idé",
            "jeg har en idea",
            "ide:",
            "idé:",
            "idea:",
            "ny ide",
            "ny idé",
            "fang ide",
            "fang idé",
            "fang idea",
            "lagre ide",
            "lagre idé",
            "skriv ned ide",
            "skriv ned idé",
            "noter ide",
            "noter idé",
            "ide jeg ma",
            "ide jeg maa",
            "idé jeg må",
            "idé jeg maa"
        ])
    }

    nonisolated private static func looksLikeTodo(_ normalized: String) -> Bool {
        normalized.hasPrefix("oppgave:")
            || containsAny(normalized, [
                "todo:",
                "task:",
                "oppgave:",
                "ny oppgave",
                "lag oppgave",
                "opprett oppgave",
                "legg til oppgave",
                "ma gjore",
                "maa gjore",
                "må gjøre",
                "gjøremål",
                "gjeremal",
                "to-do",
                "todo"
            ])
    }

    nonisolated private static func looksLikeProject(_ normalized: String) -> Bool {
        containsAny(normalized, [
            "lag prosjekt",
            "opprett prosjekt",
            "nytt prosjekt",
            "start prosjekt",
            "prosjekt for",
            "funksjonalitet for prosjekter",
            "oppgavehandtering",
            "oppgavehåndtering",
            "prosjekter og oppgave",
            "hvor prosjektet er",
            "utestaende",
            "utestående",
            "prosjektplan",
            "prosjekt plan",
            "prosjektstyring",
            "project management",
            "project plan"
        ])
    }

    nonisolated private static func looksLikeExplicitRAGResourceQuery(_ normalized: String) -> Bool {
        containsAny(normalized, ["rag"])
            && containsAny(normalized, ["anskaffelser", "innovasjon", "case", "korpus"])
    }

    nonisolated private static func looksLikeDocsRAG(_ normalized: String) -> Bool {
        containsAny(normalized, [
            "hva sier docs",
            "hva sier dokumentasjonen",
            "hva sier dokumentene",
            "rag",
            "kilde",
            "kilder",
            "dokumentasjon",
            "formålstre",
            "formaalstre",
            "interessetre",
            "purpose tree",
            "interest tree"
        ])
    }

    nonisolated private static func looksLikeLocalResourceSurfaceRequest(_ normalized: String) -> Bool {
        containsAny(normalized, [
            "vis",
            "apne",
            "åpne",
            "hent",
            "last",
            "load",
            "rendre",
            "render",
            "finn",
            "bruk"
        ]) && containsAny(normalized, [
            "vault",
            "obsidian",
            "graf",
            "graph",
            "knowledge graph",
            "flate",
            "surface",
            "bibliotek",
            "library"
        ])
    }

    nonisolated static func resourceMatches(
        prompt: String,
        grantRAG: Bool = true,
        grantContactEndpoint: Bool = true
    ) -> [Object] {
        let normalized = BindingChatValue.normalized(prompt)
        var matches: [Object] = []
        if looksLikeVaultIdeas(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:vault-ideas",
                title: "Vault / Ideas",
                summary: "Lokal Obsidian-lignende flate for ideer, prosjektnotater, markdown og knowledge graph.",
                sourceCellEndpoint: "cell:///Vault",
                sourceCellName: "VaultCell",
                purposeRef: "personal.vault.ideas.projects",
                interests: ["vault", "obsidian", "ideas", "projects", "notes", "markdown", "knowledge-graph", "resource-router"],
                score: 0.9
            ))
        }
        if looksLikeGraphIndex(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:graph-index",
                title: "Graph Index",
                summary: "Lokal grafindeks for Obsidian-lignende wiki-lenker, nabolag og inn-/utgående kanter.",
                sourceCellEndpoint: "cell:///GraphIndex",
                sourceCellName: "GraphIndexCell",
                purposeRef: "personal.knowledge.graph.index",
                interests: ["graph", "graf", "obsidian", "knowledge-graph", "relations", "vault", "resource-router"],
                score: 0.91
            ))
        }
        if looksLikeAIGatewayWorkspace(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:ai-agent-workspace",
                title: "AI Agent Workspace",
                summary: "AIGateway workspace for provider setup, språkmodeller og OpenAI-kompatible ruter.",
                sourceCellEndpoint: "cell:///AIGateway",
                sourceCellName: "AIGatewayCell",
                purposeRef: "personal.ai.gateway.configure",
                interests: ["ai", "aigateway", "gateway", "llm", "model", "provider", "configuration", "resource-router"],
                score: 0.91
            ))
        }
        if looksLikeCellConfigurationAuthoring(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:cell-configuration-architect",
                title: "Cell Configuration Architect",
                summary: "Bygg og iterer egne CellConfigurations og personlige dashboards.",
                sourceCellEndpoint: "cell:///ConfigurationCatalog",
                sourceCellName: "ConfigurationCatalogCell",
                purposeRef: "purpose://capability.construct-cellconfiguration",
                interests: ["cellconfiguration", "dashboard", "authoring", "skeleton", "configuration", "resource-router"],
                score: 0.88
            ))
        }
        if looksLikePersonalPagePublisher(normalized) {
            let company = containsAny(normalized, ["selskapet", "bedriften", "company", "landing"])
            matches.append(cellConfigurationResource(
                id: "configuration:personal-page-publisher",
                title: "Personal Page Publisher",
                summary: "Lag og publiser offentlige profil-, informasjons- og landingssider.",
                sourceCellEndpoint: "cell:///PersonalPagePublisher",
                sourceCellName: "PersonalPagePublisherCell",
                purposeRef: company ? "personal.public-presence.publish" : "personal.profile.page.create",
                interests: ["profile", "public", "page", "landing-page", "publishing", "personal-page", "resource-router"],
                score: 0.87
            ))
        }
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
        if looksLikeSpatialMap(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:spatial-map-workspace",
                title: "Spatial Map Workspace",
                summary: "Kartflate for steddata, spatial queries og geodata.",
                sourceCellEndpoint: "cell:///SpatialProjection",
                sourceCellName: "SpatialProjectionCell",
                purposeRef: "personal.chat.assist.spatial-query",
                interests: ["map", "kart", "spatial", "geodata", "location", "resource-router"],
                score: 0.9
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
        if looksLikeAdminScaffoldOperations(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:admin-copilot-workspace",
                title: "Admin Copilot Workspace",
                summary: "Read-only admin workspace for scaffold load, deployment and operations.",
                sourceCellEndpoint: "cell:///AdminOverview",
                sourceCellName: "AdminOverviewCell",
                purposeRef: "admin.scaffold-operations.observe",
                interests: ["admin", "scaffold", "operations", "load", "staging", "metrics", "resource-router"],
                score: 0.86
            ))
        }
        if looksLikeConferenceAgenda(normalized) {
            if normalized.contains("arendalsuka") {
                matches.append(cellConfigurationResource(
                    id: "configuration:arendalsuka-participant-program",
                    title: "Arendalsuka Participant Program",
                    summary: "Deltakerprogram fra staging med arrangementer, agenda og navigasjon for Arendalsuka.",
                    sourceCellEndpoint: "cell://staging.haven.digipomps.org/ArendalsukaParticipantProgram",
                    sourceCellName: "ArendalsukaParticipantProgramCell",
                    purposeRef: "conference.agenda.view",
                    interests: ["arendalsuka", "conference", "agenda", "participant", "sessions", "event-day", "resource-router"],
                    score: 0.96
                ))
            } else {
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
        }
        if looksLikeConferenceDemoStory(normalized) {
            matches.append(cellConfigurationResource(
                id: "configuration:conference-demo-story",
                title: "Conference Demo Story",
                summary: "Scenarioflaten for konferansedemo med participant, sponsor, exhibitor og organizer-løp.",
                sourceCellEndpoint: "cell:///ConferenceDemoStory",
                sourceCellName: "ConferenceDemoStoryCell",
                purposeRef: "conference.demo.story.run",
                interests: ["conference", "demo", "story", "participant", "sponsor", "exhibitor", "organizer", "resource-router"],
                score: 0.9
            ))
        }
        if looksLikePurposeInterestDocumentation(normalized) {
            matches.append([
                "kind": .string("documentation"),
                "id": .string("book:purpose-interests"),
                "title": .string("Chapter 09 — Purpose and Interests"),
                "configurationName": .string("CellProtocol Book"),
                "summary": .string("CellProtocol Book chapter about Purpose and Interests."),
                "sourceCellEndpoint": .string("cell:///MarkdownRenderer"),
                "sourceCellName": .string("MarkdownRendererCell"),
                "purposeRef": .string("cellprotocol.docs.lookup"),
                "purposeRefs": .list([
                    .string("cellprotocol.docs.lookup"),
                    .string("cellprotocol.book.purpose-interests")
                ]),
                "interests": .list(["documentation", "book", "cellprotocol", "purpose", "interests", "docs-rag"].map(ValueType.string)),
                "actionKeypath": .string("book.openDocument"),
                "score": .float(0.9),
                "requiresGrant": .bool(true),
                "requiresUserApproval": .bool(true)
            ])
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
        if looksLikeAgentEmailDraft(normalized),
           isNegated(normalized, keywords: ["e-post", "epost", "email", "mail"]) == false {
            matches.append([
                "kind": .string("agent_action"),
                "title": .string("E-postutkast via HAVENAgentD"),
                "summary": .string("Forbereder signert/reviewet intent til Mail.app-utkast for kontakter uten celle-endepunkt."),
                "sourceCellEndpoint": .string("cell:///agent/email/outbox"),
                "sourceCellName": .string("AgentMailDraftCell"),
                "purposeRef": .string("personal.agent.email.compose-draft"),
                "purposeRefs": .list([
                    .string("personal.agent.email.compose-draft"),
                    .string("personal.chat.assist.external-email-contact"),
                    .string("personal.chat.assist.entity-contact-request")
                ]),
                "interests": .list([
                    .string("agentd"),
                    .string("email"),
                    .string("e-post"),
                    .string("external-contact"),
                    .string("contact-fallback"),
                    .string("draft-only"),
                    .string("local-review"),
                    .string("requires-user-approval")
                ]),
                "actionKeypath": .string("draftIntent"),
                "requiresSignedIntent": .bool(true),
                "requiresLocalReview": .bool(true),
                "sideEffectUntilExplicitRequest": .bool(false)
            ])
        }
        if containsAny(normalized, ["tilgang", "enhet", "enheter", "sky", "capability", "kapabilitet", "tjeneste", "tjenester", "kva har jeg", "hva har jeg"]) {
            matches.append(contentsOf: [
                [
                    "kind": .string("cell_configuration"),
                    "title": .string("Co-Pilot"),
                    "summary": .string("Requester-visible Co-Pilot CellConfiguration i HAVEN."),
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
        if grantRAG, containsAny(normalized, ["rag", "dokument", "dokumentasjon", "kilde", "kilder", "anskaffelser", "formål", "formaal", "interesse"]) {
            matches.append([
                "kind": .string("rag_case"),
                "title": .string("Tilgjengelig RAG-case"),
                "configurationName": .string("RAG Gateway Workspace"),
                "caseID": .string("innovasjon"),
                "sourceCellEndpoint": .string("cell:///RAGGateway"),
                "sourceCellName": .string("RAGGatewayCell"),
                "purposeRef": .string("personal.chat.assist.rag-query"),
                "purposeRefs": .list([.string("personal.chat.assist.rag-query")]),
                "actionKeypath": .string("assistant.queryResource"),
                "requiresGrant": .bool(true)
            ])
        }
        return matches.map(normalizedResourceMatch)
    }

    nonisolated private static func normalizedResourceMatch(_ match: Object) -> Object {
        var resource = match
        let kind = BindingChatValue.string(resource["kind"]) ?? "resource"
        let title = BindingChatValue.string(resource["title"]) ?? kindLabel(forResourceKind: kind)
        let fallbackID = "\(kind):\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        let id = BindingChatValue.string(resource["id"])
            ?? BindingChatValue.string(resource["resourceID"])
            ?? BindingChatValue.string(resource["caseID"])
            ?? fallbackID
        let actionKeypath = resourceOpenActionKeypath(for: kind, resource: resource)
        let sourceCellEndpoint = BindingChatValue.string(resource["sourceCellEndpoint"])
            ?? BindingChatValue.string(resource["endpoint"])
            ?? "cell:///PersonalChatHub"
        let configurationName = BindingChatValue.string(resource["configurationName"])
            ?? BindingChatValue.string(resource["title"])
            ?? title

        resource["id"] = resource["id"] ?? .string(id)
        resource["resourceID"] = resource["resourceID"] ?? .string(id)
        resource["kindLabel"] = resource["kindLabel"] ?? .string(kindLabel(forResourceKind: kind))
        resource["matchBadge"] = resource["matchBadge"] ?? .string(matchBadge(forResourceKind: kind))
        resource["openLabel"] = resource["openLabel"] ?? .string(openLabel(forResourceKind: kind))
        resource["openHint"] = resource["openHint"] ?? .string(openHint(forResourceKind: kind))
        resource["openActionKeypath"] = resource["openActionKeypath"] ?? .string(actionKeypath)
        resource["riskLevel"] = resource["riskLevel"] ?? .string(riskLevel(forResourceKind: kind))
        resource["requiresUserApproval"] = resource["requiresUserApproval"] ?? .bool(true)
        resource["sideEffectUntilExplicitRequest"] = resource["sideEffectUntilExplicitRequest"] ?? .bool(false)
        resource["openPayload"] = resource["openPayload"] ?? .object([
            "kind": .string(kind),
            "id": .string(id),
            "resourceID": .string(id),
            "title": .string(title),
            "configurationName": .string(configurationName),
            "sourceCellEndpoint": .string(sourceCellEndpoint),
            "sourceCellName": resource["sourceCellName"] ?? .null,
            "caseID": resource["caseID"] ?? .null,
            "actionKeypath": resource["actionKeypath"] ?? .null,
            "openActionKeypath": .string(actionKeypath),
            "autoOpen": .bool(true),
            "sideEffect": .bool(false)
        ])
        return resource
    }

    nonisolated private static func kindLabel(forResourceKind kind: String) -> String {
        switch kind {
        case "cell_configuration": return "Flate"
        case "truth_source": return "Kilde"
        case "documentation": return "Dokument"
        case "rag_case": return "RAG-case"
        case "agent_action": return "Agent-review"
        case "contact_endpoint": return "Kontaktvei"
        case "agenda_context": return "Agenda"
        default: return "Ressurs"
        }
    }

    nonisolated private static func matchBadge(forResourceKind kind: String) -> String {
        switch kind {
        case "cell_configuration", "truth_source": return "Synlig flate"
        case "agent_action": return "Review"
        case "rag_case", "documentation": return "Kilde"
        default: return "Forslag"
        }
    }

    nonisolated private static func openLabel(forResourceKind kind: String) -> String {
        switch kind {
        case "cell_configuration", "truth_source": return "Åpne flate"
        case "documentation": return "Åpne dokument"
        case "rag_case": return "Spør RAG"
        case "agent_action": return "Opprett review"
        case "contact_endpoint": return "Åpne kontaktflyt"
        case "agenda_context": return "Spør agenda"
        default: return "Åpne"
        }
    }

    nonisolated private static func openHint(forResourceKind kind: String) -> String {
        switch kind {
        case "cell_configuration", "truth_source":
            "Åpner valgt flate via Library først etter eksplisitt klikk."
        case "documentation":
            "Åpner dokumentet som lesbar kilde uten å sende noe."
        case "rag_case":
            "Kan spørre RAG etter eksplisitt klikk og gyldig grant."
        case "agent_action":
            "Lager bare lokal review/signering, aldri direkte script-kjøring."
        case "contact_endpoint":
            "Forbereder kontaktflyt; sending krever signert intent og bekreftelse."
        case "agenda_context":
            "Leser bare owner-local agenda etter eksplisitt forespørsel."
        default:
            "Viser ressursen uten sideeffekt før du bekrefter."
        }
    }

    nonisolated private static func riskLevel(forResourceKind kind: String) -> String {
        switch kind {
        case "agent_action", "contact_endpoint": return "review"
        case "rag_case", "agenda_context": return "query"
        default: return "read"
        }
    }

    nonisolated private static func resourceOpenActionKeypath(for kind: String, resource: Object) -> String {
        if let explicit = BindingChatValue.string(resource["openActionKeypath"]), explicit.isEmpty == false {
            return explicit
        }
        switch kind {
        case "cell_configuration", "truth_source":
            return "chatHub.ui.openMatchedResourceLibrary"
        case "documentation":
            return "chatHub.docsRAG.openTopDocument"
        case "rag_case", "agenda_context":
            return "chatHub.assistant.queryResource"
        case "agent_action":
            return "chatHub.agent.review.create"
        case "contact_endpoint":
            return "chatHub.ui.openSuggestedHelper"
        default:
            return "chatHub.ui.openSuggestedHelper"
        }
    }

    nonisolated static func bestCellConfigurationResourceMatch(prompt: String) -> Object? {
        resourceMatches(prompt: prompt).filter {
            BindingChatValue.string($0["kind"]) == "cell_configuration"
        }.max {
            (BindingChatValue.double($0["score"]) ?? 0) < (BindingChatValue.double($1["score"]) ?? 0)
        }
    }

    nonisolated static func bestKnowledgeResourceMatch(prompt: String) -> Object? {
        resourceMatches(prompt: prompt).filter {
            let kind = BindingChatValue.string($0["kind"])
            return kind == "documentation" || kind == "rag_case"
        }.max {
            (BindingChatValue.double($0["score"]) ?? 0) < (BindingChatValue.double($1["score"]) ?? 0)
        }
    }

    nonisolated static func portholeUIRequest(for text: String) -> Object? {
        let normalized = BindingChatValue.normalized(text)
        let wantsConfigurationJSON = containsAny(normalized, ["json", "radata", "rådata"])
            && containsAny(normalized, ["cellconfiguration", "cell configuration", "konfigurasjon", "configuration"])
        let asksForPorthole = containsAny(normalized, [
            "porthole", "meny", "menu", "kant", "verktøylinje",
            "verktoylinje", "toolbar", "tool bar", "bibliotek", "library", "katalog"
        ]) || wantsConfigurationJSON
        let asksToShow = containsAny(normalized, [
            "vis", "apne", "åpne", "hent", "frem", "fram", "show", "open", "reveal",
            "skru pa", "skru på", "aktiver"
        ])
        let asksToHide = containsAny(normalized, [
            "skjul", "lukk", "ta bort", "fjern", "hide", "close", "collapse", "skru av"
        ])
        let asksToToggle = containsAny(normalized, [
            "toggle", "skru av og på", "skru av/på", "av og på", "bytt"
        ])
        let asksToConfigureMenus = containsAny(normalized, ["tilpass", "konfigurer", "configure", "settings", "innstillinger", "kriterier"])
        guard asksForPorthole && (asksToShow || asksToHide || asksToToggle || asksToConfigureMenus || wantsConfigurationJSON) else {
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
        let hidesProductChrome = asksToHide
            && wantsToolbar
            && wantsMenus == false
            && wantsLibrary == false
            && wantsConfigurationJSON == false
        return [
            "showProductChrome": .bool(hidesProductChrome == false),
            "hideProductChrome": .bool(hidesProductChrome),
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
            "openMenuSettings": .bool(asksToConfigureMenus),
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

    nonisolated private static func contextualPurposeClassification(
        normalized: String,
        perspectiveContext: BindingChatPurposeContext
    ) -> BindingChatIntentClassification? {
        guard perspectiveContext.isEmpty == false,
              looksLikeContextualFollowUp(normalized)
        else {
            return nil
        }

        let todoPurposeRefs = ["personal.chat.assist.todo", "personal.todo.manage", "personal.tasks.manage"]
        let todoInterests = ["todo", "task", "tasks", "oppgave", "gjoremal", "gjøremål"]
        if perspectiveContext.matchesPurpose(todoPurposeRefs) || perspectiveContext.matchesInterest(todoInterests) {
            let confidence = min(0.9, 0.7 + perspectiveContext.contextBoost(purposeRefs: todoPurposeRefs, interests: todoInterests))
            return positive(
                kind: "todo",
                purposeRef: "personal.chat.assist.todo",
                interests: ["todo", "task", "private", "perspective-context"],
                helperID: "todo",
                confidence: confidence,
                reason: "Aktiv Perspective peker paa oppgaver; jeg kan apne oppgave-hjelperen uten aa opprette noe for du bekrefter."
            )
        }

        let projectPurposeRefs = ["personal.chat.assist.project", "personal.vault.ideas.projects", "personal.project.manage"]
        let projectInterests = ["project", "projects", "prosjekt", "planning", "planlegging", "project-management"]
        if perspectiveContext.matchesPurpose(projectPurposeRefs) || perspectiveContext.matchesInterest(projectInterests) {
            let confidence = min(0.9, 0.7 + perspectiveContext.contextBoost(purposeRefs: projectPurposeRefs, interests: projectInterests))
            return positive(
                kind: "project",
                purposeRef: "personal.chat.assist.project",
                interests: ["project", "planning", "perspective-context"],
                helperID: "project",
                confidence: confidence,
                reason: "Aktiv Perspective peker paa prosjekt/planlegging; jeg kan apne prosjekt-hjelperen som et privat utkast."
            )
        }

        let graphPurposeRefs = ["personal.knowledge.graph.index", "personal.vault.ideas.projects"]
        let graphInterests = ["graph", "graf", "knowledge-graph", "obsidian"]
        if perspectiveContext.matchesPurpose(graphPurposeRefs) || perspectiveContext.matchesInterest(graphInterests) {
            let confidence = min(0.86, 0.68 + perspectiveContext.contextBoost(purposeRefs: graphPurposeRefs, interests: graphInterests))
            return positive(
                kind: "resource_match",
                purposeRef: "personal.knowledge.graph.index",
                interests: ["graph", "vault", "resource-router", "perspective-context", "requires-user-approval"],
                helperID: "resource-router",
                confidence: confidence,
                reason: "Aktiv Perspective peker paa graf/vault-kontekst; jeg kan foreslaa synlig flate uten aa laste den automatisk."
            )
        }

        let ideaPurposeRefs = ["personal.chat.assist.idea.capture", "personal.vault.ideas", "personal.idea.capture"]
        let ideaInterests = ["idea", "ideas", "ide", "ideer", "capture", "vault"]
        if perspectiveContext.matchesPurpose(ideaPurposeRefs) || perspectiveContext.matchesInterest(ideaInterests) {
            let confidence = min(0.88, 0.68 + perspectiveContext.contextBoost(purposeRefs: ideaPurposeRefs, interests: ideaInterests))
            return positive(
                kind: "idea_capture",
                purposeRef: "personal.chat.assist.idea.capture",
                interests: ["idea", "capture", "private", "perspective-context"],
                helperID: "idea-capture",
                confidence: confidence,
                reason: "Aktiv Perspective peker paa idefangst; jeg kan apne ide-hjelperen som et privat utkast."
            )
        }

        return nil
    }

    nonisolated private static func looksLikeContextualFollowUp(_ normalized: String) -> Bool {
        containsAny(normalized, [
            "legg dette inn",
            "legg inn dette",
            "legg til dette",
            "lagre dette",
            "ta vare pa dette",
            "ta vare paa dette",
            "bruk dette videre",
            "bruk denne videre",
            "som neste steg",
            "neste steg",
            "gjor dette til",
            "gjør dette til",
            "organiser dette",
            "koble dette",
            "sett dette opp",
            "ta dette videre"
        ])
    }

    nonisolated private static func resourceMatchClassification(_ resource: Object) -> BindingChatIntentClassification {
        let title = BindingChatValue.string(resource["title"]) ?? "synlig flate"
        let purposeRef = BindingChatValue.stringList(resource["purposeRefs"]).first
            ?? BindingChatValue.string(resource["purposeRef"])
            ?? "personal.chat.assist.resource-router"
        let helperID = directHelperID(forResource: resource)
        return BindingChatIntentClassification(
            intentKind: "resource_match",
            purposeRef: purposeRef,
            interests: Array(Set(BindingChatValue.stringList(resource["interests"]) + [
                "resource-router",
                "visible-cellconfiguration",
                "requires-user-approval"
            ])).sorted(),
            helperID: helperID,
            confidence: BindingChatValue.double(resource["score"]) ?? 0.78,
            requiresUserApproval: true,
            reason: "Fant en synlig CellConfiguration som matcher formaalet: \(title).",
            negativeIntent: "",
            status: "suggested"
        )
    }

    nonisolated private static func directHelperID(forResource resource: Object) -> String {
        let purposeRefs = Set(
            BindingChatValue.stringList(resource["purposeRefs"])
                + [BindingChatValue.string(resource["purposeRef"])].compactMap { $0 }
        )
        let interests = Set(BindingChatValue.stringList(resource["interests"]))
        let endpoint = BindingChatValue.string(resource["sourceCellEndpoint"]) ?? ""
        if purposeRefs.contains("personal.diagram.mermaid.render")
            || interests.contains("mermaid")
            || endpoint == "cell:///MermaidRenderer" {
            return "mermaid-diagram"
        }
        if purposeRefs.contains("personal.chat.assist.spatial-query")
            || interests.contains("spatial")
            || interests.contains("kart")
            || interests.contains("map")
            || endpoint == "cell:///SpatialProjection" {
            return "spatial-map"
        }
        let kind = BindingChatValue.string(resource["kind"]) ?? ""
        if kind == "documentation" || kind == "rag_case" {
            return "docs-rag"
        }
        return "resource-router"
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
                text.contains("\(negator) \(keyword)")
                    || text.contains("\(negator) lag \(keyword)")
                    || text.contains("\(negator) lage \(keyword)")
                    || text.contains("\(negator) lagre \(keyword)")
                    || text.contains("\(negator) opprett \(keyword)")
                    || text.contains("\(negator) registrer \(keyword)")
                    || text.contains("\(negator) rapporter \(keyword)")
                    || text.contains("\(negator) start \(keyword)")
                    || text.contains("\(negator) lukk")
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

    nonisolated private static func looksLikeAgentEmailDraft(_ text: String) -> Bool {
        containsAny(text, [
            "send e-post",
            "sende e-post",
            "send epost",
            "sende epost",
            "send email",
            "send mail",
            "skriv e-post",
            "skrive e-post",
            "skriv epost",
            "skrive epost",
            "lag e-post",
            "lage e-post",
            "lag epost",
            "mail til",
            "epost til",
            "e-post til",
            "email til",
            "email to"
        ])
        || (
            containsAny(text, ["e-post", "epost", "email", "mail"])
            && containsAny(text, ["send", "sende", "skriv", "skrive", "utkast", "draft", "kontakt", "foresporsel", "forespørsel"])
        )
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

    nonisolated private static func looksLikeAIGatewayWorkspace(_ text: String) -> Bool {
        containsAny(text, ["aigateway", "ai gateway", "sprakmodell", "språkmodell", "sprakmodeller", "språkmodeller", "llm", "4o-mini", "glm"])
            && containsAny(text, ["vis", "hvilke", "konfigurasjon", "konfigurer", "sett opp", "bruk", "velg", "modell", "provider", "gateway"])
    }

    nonisolated private static func looksLikeCellConfigurationAuthoring(_ text: String) -> Bool {
        containsAny(text, ["dashboard", "personlige dashboard", "personlig dashboard", "mitt eget"])
            && containsAny(text, ["lage", "lag", "bygge", "bygg", "eget", "personlig", "dashboard"])
    }

    nonisolated private static func looksLikePersonalPagePublisher(_ text: String) -> Bool {
        containsAny(text, ["profilside", "offentlig profil", "infoside", "informasjonsside", "side om meg", "side om selskapet", "selskapet mitt", "bedriften min", "landingsside", "landing"])
            && containsAny(text, ["lage", "lag", "bygge", "bygg", "trenger", "vil", "opprett"])
    }

    nonisolated private static func looksLikeSpatialMap(_ text: String) -> Bool {
        containsAny(text, ["kart", "map", "spatial", "geodata", "steddata"])
            && containsAny(text, ["vis", "apne", "åpne", "data", "workspace", "flate", "query"])
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
        containsAny(text, ["orphaned", "foreldrelos", "foreldreløs", "cleanup", "rydde", "livssyklus", "persistert", "persisted", "persistente", "plass", "storage"])
            && containsAny(text, ["cell", "celler", "staging", "admin"])
    }

    nonisolated private static func looksLikeAdminScaffoldLoad(_ text: String) -> Bool {
        containsAny(text, ["lasten", "load", "cpu", "memory", "minne", "metrics", "metrikker"])
            && containsAny(text, ["staging", "scaffold", "nå", "na", "naa", "now"])
    }

    nonisolated private static func looksLikeAdminScaffoldOperations(_ text: String) -> Bool {
        looksLikeAdminScaffoldLoad(text)
            || (containsAny(text, ["adminfunksjonalitet", "admin", "operations", "scaffold"]) && containsAny(text, ["vis", "apne", "åpne", "funksjonalitet", "workspace"]))
    }

    nonisolated private static func looksLikeConferenceAgenda(_ text: String) -> Bool {
        containsAny(text, ["konferanse", "conference", "arendalsuka"])
            && containsAny(text, ["agenda", "program", "sesjon", "session", "i dag", "today", "etter lunsj", "i morgen", "morgendagen", "hva skjer"])
    }

    nonisolated private static func looksLikeConferenceDemoStory(_ text: String) -> Bool {
        containsAny(text, ["demohistorie", "demo historie", "conference demo story", "konferanse demo", "konferansedemo"])
            && containsAny(text, ["konferanse", "conference", "participant", "deltager", "deltaker", "sponsor", "utstiller", "exhibitor", "arrangør", "arrangor", "organizer", "start", "kjør", "kjor", "vis"])
    }

    nonisolated private static func looksLikePurposeInterestDocumentation(_ text: String) -> Bool {
        containsAny(text, ["purpose and interests", "purpose og interests", "formål og interesser", "formaal og interesser", "purpose", "interests"])
            && containsAny(text, ["dokumentasjon", "documentation", "docs", "vis", "chapter", "kapittel"])
    }

    nonisolated private static func looksLikeVaultIdeas(_ text: String) -> Bool {
        containsAny(text, [
            "vault",
            "obsidian",
            "ide",
            "idea",
            "ideer",
            "ideas",
            "prosjekt",
            "project",
            "prosjektstyring",
            "project management",
            "markdown",
            "notat",
            "notater",
            "notes"
        ]) && containsAny(text, [
            "vis",
            "apne",
            "åpne",
            "last",
            "load",
            "render",
            "rendre",
            "organiser",
            "styring",
            "management",
            "finn",
            "fa",
            "få",
            "hent",
            "bruk",
            "graf",
            "graph",
            "knowledge"
        ])
    }

    nonisolated private static func looksLikeGraphIndex(_ text: String) -> Bool {
        containsAny(text, ["graf", "graph", "knowledge graph", "obsidian"])
            && containsAny(text, ["index", "indeks", "render", "rendre", "vis", "apne", "åpne", "nabo", "neighbors", "relations", "relasjoner"])
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

enum BindingGroundedActionPlanner {
    nonisolated static func plan(
        draft: String,
        suggestion: BindingChatIntentClassification,
        resourceMatches: [Object],
        providerRecommendation: BindingChatProviderDescriptor
    ) -> Object {
        let normalized = BindingChatValue.normalized(draft)
        if BindingChatIntentClassifier.portholeUIRequest(for: draft) != nil,
           isNegatedPortholeRequest(normalized) == false {
            return planObject(
                draft: draft,
                status: "drafted",
                intentKind: "porthole_ui_command",
                helperID: "porthole-ui",
                purposeRefs: ["personal.porthole.ui.configure"],
                target: [
                    "id": .string("porthole"),
                    "title": .string("Porthole"),
                    "kind": .string("porthole_ui"),
                    "configurationName": .string("Porthole"),
                    "sourceCellEndpoint": .string("cell:///Porthole"),
                    "actionKeypath": .string("porthole.ui.applyRequest"),
                    "helperID": .string("porthole-ui"),
                    "openLabel": .string("Bruk UI-valg"),
                    "openPayload": .object([
                        "sideEffect": .bool(false)
                    ])
                ],
                providerRecommendation: providerRecommendation,
                riskLevel: "draft",
                missing: [],
                requiresUserConfirmation: true,
                explanation: "Porthole kan oppdatere chrome eller menyer etter eksplisitt brukerhandling.",
                nextStep: "apply_porthole_ui_request"
            )
        }

        guard suggestion.shouldSuggest else {
            let missing = missingReasons(for: draft, suggestion: suggestion)
            return planObject(
                draft: draft,
                status: "no_safe_action",
                intentKind: "none",
                helperID: "",
                purposeRefs: [],
                target: [
                    "id": .null,
                    "title": .null,
                    "kind": .null,
                    "configurationName": .null,
                    "sourceCellEndpoint": .null,
                    "actionKeypath": .string(""),
                    "helperID": .string(""),
                    "openLabel": .null,
                    "openPayload": .null
                ],
                providerRecommendation: providerRecommendation,
                riskLevel: "none",
                missing: missing,
                requiresUserConfirmation: false,
                explanation: suggestion.reason,
                nextStep: "continue_chat"
            )
        }

        let targetResource: Object?
        if ["resource-router", "mermaid-diagram", "spatial-map"].contains(suggestion.helperID) {
            targetResource = resourceMatches.first(where: {
                let kind = BindingChatValue.string($0["kind"])
                return kind == "cell_configuration" || kind == "truth_source"
            }) ?? resourceMatches.first
        } else if suggestion.helperID == "docs-rag" {
            targetResource = resourceMatches.first(where: {
                let kind = BindingChatValue.string($0["kind"])
                return kind == "rag_case" || kind == "documentation"
            }) ?? resourceMatches.first
        } else {
            targetResource = nil
        }

        let planHelperID = groundedHelperID(for: suggestion.helperID, resource: targetResource)
        var actionKeypath = canonicalActionKeypath(for: planHelperID)
        if let openAction = targetResource.flatMap({ BindingChatValue.string($0["openActionKeypath"]) }),
           ["resource-router", "mermaid-diagram", "spatial-map", "docs-rag"].contains(suggestion.helperID),
           openAction.isEmpty == false {
            actionKeypath = canonicalActionKeypath(openAction)
        }
        if suggestion.helperID == "docs-rag",
           let explicit = targetResource.flatMap({ BindingChatValue.string($0["actionKeypath"]) }),
           explicit.isEmpty == false {
            actionKeypath = canonicalActionKeypath(explicit)
        }

        let targetID = targetResource.flatMap { BindingChatValue.string($0["id"]) }
        let targetTitle = targetResource.flatMap { BindingChatValue.string($0["title"]) }
        let targetKind = targetResource.flatMap { BindingChatValue.string($0["kind"]) }
        let targetConfigurationName = targetResource.flatMap {
            BindingChatValue.string($0["configurationName"]) ?? BindingChatValue.string($0["title"])
        }
        let targetEndpoint = targetResource.flatMap { BindingChatValue.string($0["sourceCellEndpoint"]) } ?? "cell:///PersonalChatHub"
        let targetOpenLabel = targetResource.flatMap { BindingChatValue.string($0["openLabel"]) }
        let targetOpenPayload = targetResource.flatMap { BindingChatValue.object($0["openPayload"]) }
        let targetObject: Object = [
            "id": targetID.map(ValueType.string) ?? .null,
            "title": targetTitle.map(ValueType.string) ?? .null,
            "kind": targetKind.map(ValueType.string) ?? .null,
            "configurationName": targetConfigurationName.map(ValueType.string) ?? .null,
            "sourceCellEndpoint": .string(targetEndpoint),
            "actionKeypath": .string(actionKeypath),
            "helperID": .string(planHelperID),
            "openLabel": targetOpenLabel.map(ValueType.string) ?? .null,
            "openPayload": targetOpenPayload.map(ValueType.object) ?? .null
        ]

        return planObject(
            draft: draft,
            status: "drafted",
            intentKind: groundedIntentKind(for: suggestion, resource: targetResource),
            helperID: planHelperID,
            purposeRefs: [suggestion.purposeRef].filter { $0.isEmpty == false },
            target: targetObject,
            providerRecommendation: providerRecommendation,
            riskLevel: riskLevel(for: planHelperID, resource: targetResource),
            missing: [],
            requiresUserConfirmation: true,
            explanation: suggestion.explanation,
            nextStep: "open_helper"
        )
    }

    nonisolated private static func planObject(
        draft: String,
        status: String,
        intentKind: String,
        helperID: String,
        purposeRefs: [String],
        target: Object,
        providerRecommendation: BindingChatProviderDescriptor,
        riskLevel: String,
        missing: [String],
        requiresUserConfirmation: Bool,
        explanation: String,
        nextStep: String
    ) -> Object {
        [
            "schema": .string("binding.grounded-action-plan.v0"),
            "status": .string(status),
            "intentKind": .string(intentKind),
            "helperID": .string(helperID),
            "purposeRefs": .list(purposeRefs.map(ValueType.string)),
            "target": .object(target),
            "provider": .object(providerRecommendation.objectValue()),
            "riskLevel": .string(riskLevel),
            "missing": .list(missing.map(ValueType.string)),
            "requiresUserConfirmation": .bool(requiresUserConfirmation),
            "requiresUserApproval": .bool(requiresUserConfirmation),
            "sideEffectBeforeUserAction": .bool(false),
            "nextStep": .string(nextStep),
            "explanation": .string(explanation),
            "draftPreview": .string(String(draft.prefix(180)))
        ]
    }

    nonisolated private static func canonicalActionKeypath(for helperID: String) -> String {
        switch helperID {
        case "invite", "poll":
            return "ui.openSuggestedHelper"
        case "idea-capture":
            return "idea.capture"
        case "work-item":
            return "workItem.capture"
        case "todo":
            return "todo.create"
        case "project":
            return "project.create"
        case "reminder":
            return "reminder.create"
        case "meeting":
            return "meeting.schedule"
        case "onboarding":
            return "onboarding.start"
        case "agent-review", "agent-setup":
            return "agent.review.create"
        case "docs-rag":
            return "assistant.queryResource"
        case "resource-router", "mermaid-diagram", "spatial-map":
            return "ui.openMatchedResourceLibrary"
        case "capability-request":
            return "capabilityRequest.submit"
        default:
            return ""
        }
    }

    nonisolated private static func groundedHelperID(for helperID: String, resource: Object?) -> String {
        if helperID == "mermaid-diagram" {
            return "resource-router"
        }
        return helperID
    }

    nonisolated private static func groundedIntentKind(
        for suggestion: BindingChatIntentClassification,
        resource: Object?
    ) -> String {
        guard suggestion.helperID == "docs-rag" else {
            return suggestion.intentKind
        }
        switch resource.flatMap({ BindingChatValue.string($0["kind"]) }) {
        case "rag_case":
            return "rag_query"
        case "documentation":
            return "documentation_lookup"
        default:
            return suggestion.intentKind
        }
    }

    nonisolated private static func canonicalActionKeypath(_ actionKeypath: String) -> String {
        switch actionKeypath {
        case "chatHub.ui.openMatchedResourceLibrary":
            return "ui.openMatchedResourceLibrary"
        case "chatHub.ui.openSuggestedHelper":
            return "ui.openSuggestedHelper"
        case "chatHub.docsRAG.askRAG", "chatHub.assistant.queryResource":
            return "assistant.queryResource"
        case "chatHub.docsRAG.openTopDocument":
            return "book.openDocument"
        case "chatHub.agent.review.create":
            return "agent.review.create"
        case "chatHub.capabilityRequest.submit":
            return "capabilityRequest.submit"
        case "chatHub.idea.capture":
            return "idea.capture"
        case "chatHub.workItem.capture":
            return "workItem.capture"
        case "chatHub.todo.create":
            return "todo.create"
        case "chatHub.project.create":
            return "project.create"
        case "chatHub.reminder.create":
            return "reminder.create"
        case "chatHub.meeting.schedule":
            return "meeting.schedule"
        case "chatHub.onboarding.start":
            return "onboarding.start"
        default:
            return actionKeypath
        }
    }

    nonisolated private static func riskLevel(for helperID: String, resource: Object?) -> String {
        if let resourceRisk = resource.flatMap({ BindingChatValue.string($0["riskLevel"]) }) {
            if helperID == "docs-rag", resourceRisk == "query" {
                return "read"
            }
            return resourceRisk
        }
        switch helperID {
        case "docs-rag", "resource-router", "mermaid-diagram", "spatial-map":
            return "read"
        case "agent-review", "agent-setup":
            return "local-agent"
        default:
            return "draft"
        }
    }

    nonisolated private static func missingReasons(
        for draft: String,
        suggestion: BindingChatIntentClassification
    ) -> [String] {
        let normalized = BindingChatValue.normalized(draft)
        let questionDiscussionOnly = normalized.contains("bare forklar")
            && normalized.contains("hvilke")
            && (normalized.contains("spør") || normalized.contains("spor"))
        let explanatoryOnly = questionDiscussionOnly
            || normalized.contains("jeg vil bare diskutere")
            || normalized.contains("bare diskuter")
        if normalized.contains("ikke")
            && explanatoryOnly == false {
            return ["negated-prompt"]
        }
        if normalized.contains("inviterte") || normalized.contains("gjorde onboarding") {
            return ["negated-prompt"]
        }
        if suggestion.negativeIntent.isEmpty == false,
           explanatoryOnly == false {
            return ["negated-prompt"]
        }
        if suggestion.status == "needs_clarification"
            || suggestion.reason.localizedCaseInsensitiveContains("mangler")
            || suggestion.reason.localizedCaseInsensitiveContains("provider-valg")
            || normalized.contains("fikse")
            || normalized.contains("kundeverktøy")
            || normalized.contains("kundeverktoy")
            || normalized.contains("skulle ønske")
            || normalized.contains("skulle onske") {
            return ["needs-clarification"]
        }
        return ["no-visible-capability"]
    }

    nonisolated private static func isNegatedPortholeRequest(_ normalized: String) -> Bool {
        (normalized.contains("ikke") || normalized.contains("aldri"))
            && (normalized.contains("porthole") || normalized.contains("meny") || normalized.contains("menu"))
    }
}

enum BindingGroundedActionVerifier {
    nonisolated static func availableSchemas(
        resourceMatches: [Object],
        providers: [BindingChatProviderDescriptor]
    ) -> [Object] {
        let helperSchemas: [Object] = [
            helperSchema("invite", actionKeypath: "chatHub.invite", purposeRef: "personal.chat.assist.invite", riskLevel: "draft"),
            helperSchema("poll", actionKeypath: "chatHub.poll.create", purposeRef: "personal.chat.assist.poll", riskLevel: "draft"),
            helperSchema("idea-capture", actionKeypath: "chatHub.idea.capture", purposeRef: "personal.chat.assist.idea", riskLevel: "draft"),
            helperSchema("work-item", actionKeypath: "chatHub.workItem.capture", purposeRef: "personal.chat.assist.work-item.capture", riskLevel: "draft"),
            helperSchema("todo", actionKeypath: "chatHub.todo.create", purposeRef: "personal.chat.assist.todo", riskLevel: "draft"),
            helperSchema("project", actionKeypath: "chatHub.project.create", purposeRef: "personal.chat.assist.project", riskLevel: "draft"),
            helperSchema("reminder", actionKeypath: "chatHub.reminder.create", purposeRef: "personal.chat.assist.reminder", riskLevel: "draft"),
            helperSchema("meeting", actionKeypath: "chatHub.meeting.schedule", purposeRef: "personal.chat.assist.meeting.schedule", riskLevel: "draft"),
            helperSchema("onboarding", actionKeypath: "chatHub.onboarding.start", purposeRef: "personal.chat.assist.guided-onboarding", riskLevel: "draft"),
            helperSchema("resource-router", actionKeypath: "chatHub.ui.openMatchedResourceLibrary", purposeRef: "personal.chat.assist.resource-router", riskLevel: "read"),
            helperSchema("spatial-map", actionKeypath: "chatHub.ui.openMatchedResourceLibrary", purposeRef: "personal.chat.assist.spatial-query", riskLevel: "read"),
            helperSchema("docs-rag", actionKeypath: "chatHub.docsRAG.askRAG", purposeRef: "personal.chat.assist.rag-query", riskLevel: "query"),
            helperSchema("agent-review", actionKeypath: "chatHub.agent.review.create", purposeRef: "personal.agent.local.gui.review", riskLevel: "review"),
            helperSchema("advisor-report", actionKeypath: "chatHub.advisorReport.prepare", purposeRef: "personal.chat.assist.advisory-report", riskLevel: "draft")
        ]
        let resourceSchemas: [Object] = resourceMatches.prefix(8).map { resource in
            let title = BindingChatValue.string(resource["title"]) ?? "Ressurs"
            let id = BindingChatValue.string(resource["id"]) ?? title
            let kindValue = BindingChatValue.string(resource["kind"]).map(ValueType.string) ?? .string("resource")
            let targetAction = BindingChatValue.string(resource["openActionKeypath"])
                ?? BindingChatValue.string(resource["actionKeypath"])
            let riskValue = BindingChatValue.string(resource["riskLevel"]).map(ValueType.string) ?? .string("read")
            let object: Object = [
                "schemaID": .string("resource:\(id)"),
                "kind": kindValue,
                "title": .string(title),
                "targetActionKeypath": targetAction.map(ValueType.string) ?? .null,
                "openPayload": resource["openPayload"] ?? .null,
                "purposeRefs": resource["purposeRefs"] ?? .list([]),
                "riskLevel": riskValue,
                "requiresUserApproval": .bool(true),
                "sideEffectBeforeUserAction": .bool(false)
            ]
            return object
        }
        let providerSchemas: [Object] = providers.prefix(4).map { provider in
            let object: Object = [
                "schemaID": .string("provider:\(provider.id)"),
                "kind": .string(provider.kind),
                "title": .string(provider.title),
                "targetActionKeypath": provider.actionKeypath.map(ValueType.string) ?? .null,
                "purposeRefs": .list(provider.purposeRefs.map(ValueType.string)),
                "privacyLevel": .string(provider.privacyLevel),
                "requiresNetwork": .bool(provider.requiresNetwork),
                "requiresUserApproval": .bool(provider.requiresUserApproval),
                "sideEffectBeforeUserAction": .bool(false)
            ]
            return object
        }
        return helperSchemas + resourceSchemas + providerSchemas
    }

    nonisolated static func verify(
        plan: Object,
        suggestion: BindingChatIntentClassification,
        resourceMatches: [Object],
        providerRecommendation: BindingChatProviderDescriptor
    ) -> Object {
        let target = BindingChatValue.object(plan["target"]) ?? [:]
        let actionKeypath = BindingChatValue.string(target["actionKeypath"]) ?? ""
        let targetResource = targetResource(for: suggestion, resourceMatches: resourceMatches)
        let targetVerified = suggestion.shouldSuggest && actionKeypath.isEmpty == false
        let resourceVisible = targetResource.map { resource in
            let availability = BindingChatValue.string(resource["availability"]) ?? "visible_resource"
            return availability.contains("visible") || availability.contains("requester") || availability.contains("granted")
        } ?? true
        let globalProviderUsed = providerRecommendation.executionScope == "global"
            || providerRecommendation.endpoint == "cell:///GlobalAIProvider"
        var missing: [String] = []
        if suggestion.negativeIntent.isEmpty == false {
            missing.append("negative_intent_blocks_action")
        }
        if suggestion.shouldSuggest == false {
            missing.append("safe_confidence_or_intent")
        }
        if actionKeypath.isEmpty && suggestion.shouldSuggest {
            missing.append("target_action")
        }
        if resourceVisible == false {
            missing.append("visible_resource_grant")
        }
        if globalProviderUsed {
            missing.append("cell_scoped_provider")
        }

        let allowed = missing.isEmpty
        let status: String
        if suggestion.negativeIntent.isEmpty == false {
            status = "blocked"
        } else if suggestion.shouldSuggest == false {
            status = "no_safe_action"
        } else if allowed {
            status = "verified"
        } else {
            status = "needs_user_action"
        }
        let riskLevel = targetResource.flatMap { BindingChatValue.string($0["riskLevel"]) }
            ?? riskLevel(for: suggestion.helperID)
        return [
            "schema": .string("binding.grounded-action-verification.v0"),
            "status": .string(status),
            "allowed": .bool(allowed),
            "targetVerified": .bool(targetVerified),
            "targetActionKeypath": .string(actionKeypath),
            "riskLevel": .string(riskLevel),
            "grantStatus": .string(resourceVisible ? "visible_or_not_required" : "missing_visible_grant"),
            "providerID": .string(providerRecommendation.id),
            "providerScope": .string(providerRecommendation.executionScope),
            "requiresUserConfirmation": .bool(true),
            "requiresSignedRemoteIntent": .bool(suggestion.helperID == "agent-review" || suggestion.helperID == "agent-setup" || riskLevel == "review" || riskLevel == "local-agent"),
            "requiresLocalReview": .bool(suggestion.helperID == "agent-review" || suggestion.helperID == "agent-setup" || riskLevel == "review" || riskLevel == "local-agent"),
            "sideEffectBeforeUserAction": .bool(false),
            "missing": .list(missing.map(ValueType.string)),
            "policyChecks": .object([
                "noGlobalProvider": .bool(globalProviderUsed == false),
                "providerIsCellScoped": .bool(globalProviderUsed == false),
                "explicitUserActionRequired": .bool(true),
                "resourceMustBeVisible": .bool(resourceVisible),
                "analysisIsSideEffectFree": .bool(true),
                "nativePrivateScopesExcluded": .list([
                    .string("contacts"),
                    .string("calendar"),
                    .string("microphone"),
                    .string("camera"),
                    .string("vault"),
                    .string("other_threads")
                ])
            ]),
            "targetResource": targetResource.map(ValueType.object) ?? .null,
            "reason": .string(reason(status: status, suggestion: suggestion, riskLevel: riskLevel))
        ]
    }

    nonisolated static func dryRun(
        plan: Object,
        verification: Object,
        resourceMatches: [Object]
    ) -> Object {
        let allowed = BindingChatValue.bool(verification["allowed"]) ?? false
        let target = BindingChatValue.object(plan["target"]) ?? [:]
        let actionKeypath = BindingChatValue.string(target["actionKeypath"]) ?? ""
        let topResource = resourceMatches.first
        let topResourceTitle = topResource.flatMap { BindingChatValue.string($0["title"]) }
        let wouldOpenSurface = actionKeypath == "chatHub.ui.openMatchedResourceLibrary"
            || actionKeypath == "ui.openMatchedResourceLibrary"
        let wouldQuery = actionKeypath.contains("queryResource") || actionKeypath.contains("askRAG")
        let wouldReview = actionKeypath.contains("agent.review")
        let summary: String
        if allowed == false {
            summary = "Ingen trygg handling er klar. Chatten venter på mer presis prompt eller eksplisitt valg."
        } else if let topResourceTitle, wouldOpenSurface {
            summary = "Neste klikk kan åpne \(topResourceTitle) som valgt flate uten å sende eller lagre noe."
        } else if wouldQuery {
            summary = "Neste klikk kan spørre en grantet ressurs; analysen har ikke gjort spørringen."
        } else if wouldReview {
            summary = "Neste klikk kan lage et lokalt review-utkast; agenten kjører ikke direkte."
        } else {
            summary = "Neste klikk kan åpne en trygg hjelper som privat utkast."
        }
        return [
            "schema": .string("binding.grounded-action-dry-run.v0"),
            "status": .string(allowed ? "ready" : "blocked"),
            "wouldOpenHelper": .bool(allowed),
            "wouldOpenSurface": .bool(allowed && wouldOpenSurface),
            "wouldMutateEntity": .bool(false),
            "wouldSendNetworkRequest": .bool(false),
            "wouldInvokeProvider": .bool(false),
            "wouldQueryResource": .bool(allowed && wouldQuery),
            "wouldCreateAgentReview": .bool(allowed && wouldReview),
            "targetActionKeypath": .string(actionKeypath),
            "summary": .string(summary),
            "sideEffectBeforeUserAction": .bool(false)
        ]
    }

    nonisolated static func alternatives(
        suggestion: BindingChatIntentClassification,
        resourceMatches: [Object]
    ) -> [Object] {
        resourceMatches.prefix(5).map { resource in
            [
                "title": BindingChatValue.string(resource["title"]).map(ValueType.string) ?? .string("Ressurs"),
                "kind": BindingChatValue.string(resource["kind"]).map(ValueType.string) ?? .string("resource"),
                "openLabel": BindingChatValue.string(resource["openLabel"]).map(ValueType.string) ?? .string("Åpne"),
                "openActionKeypath": BindingChatValue.string(resource["openActionKeypath"]).map(ValueType.string) ?? .null,
                "helperID": .string(suggestion.helperID),
                "requiresUserApproval": .bool(true),
                "sideEffectBeforeUserAction": .bool(false)
            ]
        }
    }

    nonisolated private static func helperSchema(
        _ helperID: String,
        actionKeypath: String,
        purposeRef: String,
        riskLevel: String
    ) -> Object {
        [
            "schemaID": .string("helper:\(helperID)"),
            "helperID": .string(helperID),
            "targetActionKeypath": .string(actionKeypath),
            "purposeRefs": .list([.string(purposeRef)]),
            "riskLevel": .string(riskLevel),
            "requiresUserApproval": .bool(true),
            "sideEffectBeforeUserAction": .bool(false)
        ]
    }

    nonisolated private static func targetResource(
        for suggestion: BindingChatIntentClassification,
        resourceMatches: [Object]
    ) -> Object? {
        if suggestion.helperID == "resource-router" || suggestion.helperID == "mermaid-diagram" || suggestion.helperID == "spatial-map" {
            return resourceMatches.first(where: {
                let kind = BindingChatValue.string($0["kind"])
                return kind == "cell_configuration" || kind == "truth_source"
            }) ?? resourceMatches.first
        }
        if suggestion.helperID == "docs-rag" {
            return resourceMatches.first(where: {
                let kind = BindingChatValue.string($0["kind"])
                return kind == "rag_case" || kind == "documentation"
            }) ?? resourceMatches.first
        }
        if suggestion.helperID == "agent-review" || suggestion.helperID == "agent-setup" {
            return resourceMatches.first(where: { BindingChatValue.string($0["kind"]) == "agent_action" })
        }
        return resourceMatches.first
    }

    nonisolated private static func riskLevel(for helperID: String) -> String {
        switch helperID {
        case "docs-rag": return "query"
        case "agent-review", "agent-setup": return "local-agent"
        case "resource-router", "mermaid-diagram", "spatial-map": return "read"
        default: return "draft"
        }
    }

    nonisolated private static func reason(
        status: String,
        suggestion: BindingChatIntentClassification,
        riskLevel: String
    ) -> String {
        switch status {
        case "verified":
            return "Forslaget er bundet til synlig scope og krever eksplisitt brukerhandling før \(riskLevel)-steget."
        case "blocked":
            return "Prompten inneholder negativ intent, så ingen hjelper eller flate åpnes."
        case "no_safe_action":
            return "Co-Pilot fant ikke en trygg nok handling fra denne prompten."
        default:
            return "Forslaget mangler en verifiserbar lokal målflate eller grant før det kan åpnes."
        }
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
                "personal.chat.assist.work-item.capture",
                "personal.chat.assist.guided-onboarding",
                "personal.chat.assist.rag-query",
                "personal.chat.assist.capability-request",
                "personal.chat.assist.entity-contact-request",
                "personal.chat.assist.resource-router",
                "personal.chat.assist.spatial-query",
                "personal.chat.assist.advisory-report",
                "personal.ai.gateway.configure",
                "personal.profile.page.create",
                "personal.public-presence.publish",
                "conference.agenda.view",
                "conference.demo.story.run",
                "admin.scaffold-operations.observe",
                "personal.diagram.mermaid.render"
            ],
            interests: ["chat-assistant", "invite-person", "poll", "todo-intent", "project-intent", "reminder-intent", "work-item", "guided-onboarding", "rag-query", "docs", "capability-gap", "contact-endpoint", "mermaid", "diagram", "spatial", "profile-page", "conference", "admin", "local", "no-network", "deterministic"],
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
        if normalized.contains("glm") || normalized.contains("gml") || normalized.contains("nanogpt") {
            if let glm = providers.first(where: { $0.id == "nanogpt.glm-5.2-thinking" && isAvailable($0) }) {
                return glm
            }
        }
        if suggestion.shouldSuggest,
           ["invite", "poll", "idea-capture", "work-item", "docs-rag", "todo", "project", "reminder", "meeting", "onboarding", "capability-request", "resource-router", "spatial-map"].contains(suggestion.helperID) {
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
            purposeRefs: [
                "personal.ai.provider.agent-bridge",
                "personal.chat.assist.local-agent-action",
                "personal.agent.email.compose-draft",
                "personal.chat.assist.external-email-contact"
            ],
            interests: ["agentd", "signed-intent", "local-review", "automation", "mcp", "phone-approval", "email", "contact-fallback"],
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
            "summary": .string("On-device Apple Foundation Models provider scoped to the current HAVEN requester and chat context."),
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
        let scaffoldContextAvailable = BindingChatValue.bool(payload["scaffoldContextAvailable"]) ?? false
        let fallback = BindingChatIntentClassifier.classify(
            prompt: draft,
            capabilityDiscoveryEnabled: capabilityDiscoveryEnabled,
            scaffoldContextAvailable: scaffoldContextAvailable
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
            "scaffoldContextAvailable": payload["scaffoldContextAvailable"] ?? .bool(false),
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
            "summary": .string("Small local LLM provider scoped to the current HAVEN requester and chat context."),
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
            capabilityDiscoveryEnabled: BindingChatValue.bool(payload["capabilityDiscoveryEnabled"]) ?? false,
            scaffoldContextAvailable: BindingChatValue.bool(payload["scaffoldContextAvailable"]) ?? false
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
            "scaffoldContextAvailable": payload["scaffoldContextAvailable"] ?? .bool(false),
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

        for key in ["publishEndpoint", "retireEndpoint", "contact.request", "ticket.status", "ticket.resolve", "ticket.respond", "expire"] {
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
        case "ticket.status":
            let ticketId = BindingContactEndpointContracts.string(BindingContactEndpointContracts.object(value)?["ticketId"])
                ?? BindingContactEndpointContracts.string(value)
                ?? ""
            return .object(ticketStatus(ticketId: ticketId, requester: requester))
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
                .string("ticket.status"),
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
        let requesterDomainBindingObject = BindingContactEndpointContracts.object(object["requesterDomainBinding"])
        let domainPolicyIsActive = endpoint.policy.allowedDomains.isEmpty == false
            || endpoint.policy.blockedDomains.isEmpty == false
        if domainPolicyIsActive {
            guard let requesterDomain,
                  let requesterDomainBindingObject else {
                return error(
                    "domain_binding_required",
                    "Requester domain policy requires a vault-issued identity-domain binding."
                )
            }
            guard case let .identity(requesterIdentity)? = object["requesterIdentity"],
                  let domainBinding = IdentityDomainBinding(object: requesterDomainBindingObject),
                  domainBinding.domain == requesterDomain,
                  domainBinding.matches(identity: requesterIdentity) else {
                return error(
                    "domain_binding_invalid",
                    "Requester identity-domain binding is invalid for the signed identity."
                )
            }
        } else if let requesterDomainBindingObject {
            guard let requesterDomain,
                  case let .identity(requesterIdentity)? = object["requesterIdentity"],
                  let domainBinding = IdentityDomainBinding(object: requesterDomainBindingObject),
                  domainBinding.domain == requesterDomain,
                  domainBinding.matches(identity: requesterIdentity) else {
                return error(
                    "domain_binding_invalid",
                    "Requester identity-domain binding is invalid for the signed identity."
                )
            }
        }
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

    private func ticketStatus(ticketId: String, requester: Identity) -> Object {
        let now = Date()
        let requesterIdentityHash = BindingContactEndpointContracts.hashRef(requester.uuid)
        let ticket: BindingContactTicketRecord? = stateQueue.sync {
            guard var record = ticketsByID[ticketId] else { return nil }
            if record.expiresAt < now,
               ["accepted", "declined", "blocked", "failed", "expired"].contains(record.status) == false {
                record.status = "expired"
                ticketsByID[ticketId] = record
            }
            return record
        }
        guard let ticket else {
            return error("ticket_not_found", "Ticket was not found.")
        }
        guard ticket.requesterIdentityHash == requesterIdentityHash else {
            return error("requester_mismatch", "Only the identity that signed the contact request can read its ticket status.")
        }
        return ticket.publicObject(includePayload: false)
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

final class BindingGraphIndexCell: GeneralCell {
    nonisolated(unsafe) private var notesByID: [String: String]
    nonisolated(unsafe) private var outgoing: [String: Set<String>]
    nonisolated(unsafe) private var incoming: [String: Set<String>]

    private enum CodingKeys: String, CodingKey {
        case notesByID
        case outgoing
        case incoming
        case generalCell
    }

    private struct GraphDocument {
        var id: String
        var content: String
    }

    private static let wikiLinkRegex = try? NSRegularExpression(
        pattern: #"\[\[([^\[\]\|#]+)(?:\|[^\]]*)?\]\]"#
    )

    required init(owner: Identity) async {
        self.notesByID = [:]
        self.outgoing = [:]
        self.incoming = [:]
        await super.init(owner: owner)
        await setup(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.notesByID = try container.decodeIfPresent([String: String].self, forKey: .notesByID) ?? [:]
        self.outgoing = try container.decodeIfPresent([String: Set<String>].self, forKey: .outgoing) ?? [:]
        self.incoming = try container.decodeIfPresent([String: Set<String>].self, forKey: .incoming) ?? [:]
        try super.init(from: decoder)

        Task {
            await setup(owner: self.storedOwnerIdentity)
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(notesByID, forKey: .notesByID)
        try container.encode(outgoing, forKey: .outgoing)
        try container.encode(incoming, forKey: .incoming)
    }

    private func setup(owner: Identity) async {
        agreementTemplate.addGrant("rw--", for: "graph")

        for key in ["graph.state", "state"] {
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                return await self.readState(requester: requester)
            }
        }

        for key in ["graph.state.node_count", "state.node_count"] {
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: "graph", for: requester) else { return .string("denied") }
                return .integer(self.notesByID.count)
            }
        }

        for key in ["graph.state.edge_count", "state.edge_count"] {
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: "graph", for: requester) else { return .string("denied") }
                return .integer(self.totalEdgeCount())
            }
        }

        for key in ["graph.state.operations", "state.operations"] {
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: "graph", for: requester) else { return .string("denied") }
                return .list(Self.operations.map(ValueType.string))
            }
        }

        for key in ["graph.reindex", "reindex"] {
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                return await self.handleReindex(value: value, requester: requester)
            }
        }

        for key in ["graph.outgoing", "outgoing"] {
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                return await self.handleOutgoing(value: value, requester: requester)
            }
        }

        for key in ["graph.incoming", "incoming"] {
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                return await self.handleIncoming(value: value, requester: requester)
            }
        }

        for key in ["graph.neighbors", "neighbors"] {
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                return await self.handleNeighbors(value: value, requester: requester)
            }
        }
    }

    private static let operations = [
        "graph.reindex",
        "graph.outgoing",
        "graph.incoming",
        "graph.neighbors"
    ]

    private func readState(requester: Identity) async -> ValueType {
        guard await validateAccess("r---", at: "graph", for: requester) else { return .string("denied") }
        return statePayload()
    }

    private func statePayload() -> ValueType {
        .object([
            "status": .string("ok"),
            "cell": .string("BindingGraphIndexCell"),
            "canonicalCell": .string("GraphIndexCell"),
            "node_count": .integer(notesByID.count),
            "edge_count": .integer(totalEdgeCount()),
            "operations": .list(Self.operations.map(ValueType.string))
        ])
    }

    private func handleReindex(value: ValueType, requester: Identity) async -> ValueType {
        let operation = "graph.reindex"
        guard await validateAccess("-w--", at: "graph", for: requester) else { return .string("denied") }
        guard let documents = parseDocuments(from: value) else {
            return error(
                operation: operation,
                code: "validation_error",
                message: "Expected payload with notes list",
                field: "notes"
            )
        }

        var notes: [String: String] = [:]
        var newOutgoing: [String: Set<String>] = [:]
        var newIncoming: [String: Set<String>] = [:]

        for document in documents {
            let id = document.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { continue }
            notes[id] = document.content
            newOutgoing[id] = []
            newIncoming[id] = []
        }

        let noteIDs = Set(notes.keys)
        for (id, content) in notes {
            for target in extractWikiLinks(from: content) where noteIDs.contains(target) {
                newOutgoing[id, default: []].insert(target)
                newIncoming[target, default: []].insert(id)
            }
        }

        notesByID = notes
        outgoing = newOutgoing
        incoming = newIncoming

        return success(
            operation: operation,
            payload: .object([
                "node_count": .integer(notesByID.count),
                "edge_count": .integer(totalEdgeCount())
            ])
        )
    }

    private func handleOutgoing(value: ValueType, requester: Identity) async -> ValueType {
        guard await validateAccess("-w--", at: "graph", for: requester) else { return .string("denied") }
        return nodeQuery(value: value, operation: "graph.outgoing") { id in
            Array(outgoing[id] ?? []).sorted()
        }
    }

    private func handleIncoming(value: ValueType, requester: Identity) async -> ValueType {
        guard await validateAccess("-w--", at: "graph", for: requester) else { return .string("denied") }
        return nodeQuery(value: value, operation: "graph.incoming") { id in
            Array(incoming[id] ?? []).sorted()
        }
    }

    private func handleNeighbors(value: ValueType, requester: Identity) async -> ValueType {
        let operation = "graph.neighbors"
        guard await validateAccess("-w--", at: "graph", for: requester) else { return .string("denied") }
        guard let id = parseNodeID(from: value), !id.isEmpty else {
            return error(operation: operation, code: "validation_error", message: "Missing node id", field: "id")
        }

        let neighbors = Array((outgoing[id] ?? []).union(incoming[id] ?? [])).sorted()
        return success(
            operation: operation,
            payload: .object([
                "id": .string(id),
                "count": .integer(neighbors.count),
                "neighbors": .list(neighbors.map(ValueType.string))
            ])
        )
    }

    private func nodeQuery(
        value: ValueType,
        operation: String,
        linksProvider: (String) -> [String]
    ) -> ValueType {
        guard let id = parseNodeID(from: value), !id.isEmpty else {
            return error(operation: operation, code: "validation_error", message: "Missing node id", field: "id")
        }

        let links = linksProvider(id)
        return success(
            operation: operation,
            payload: .object([
                "id": .string(id),
                "count": .integer(links.count),
                "links": .list(links.map(ValueType.string))
            ])
        )
    }

    private func parseDocuments(from value: ValueType) -> [GraphDocument]? {
        if case let .object(object) = value,
           let nested = object["notes"] {
            return parseDocumentList(from: nested)
        }
        return parseDocumentList(from: value)
    }

    private func parseDocumentList(from value: ValueType) -> [GraphDocument]? {
        guard case let .list(items) = value else { return nil }
        let documents = items.compactMap(parseDocument(from:))
        return documents.count == items.count ? documents : nil
    }

    private func parseDocument(from value: ValueType) -> GraphDocument? {
        guard case let .object(object) = value,
              let id = string(from: object["id"]),
              let content = string(from: object["content"]) else {
            return nil
        }
        return GraphDocument(id: id, content: content)
    }

    private func parseNodeID(from value: ValueType) -> String? {
        if let direct = string(from: value) { return direct }
        guard case let .object(object) = value else { return nil }
        return string(from: object["id"]) ?? string(from: object["note_id"])
    }

    private func extractWikiLinks(from markdown: String) -> [String] {
        guard let regex = Self.wikiLinkRegex else { return [] }
        let range = NSRange(location: 0, length: (markdown as NSString).length)
        return regex.matches(in: markdown, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let swiftRange = Range(match.range(at: 1), in: markdown) else {
                return nil
            }
            let token = markdown[swiftRange].trimmingCharacters(in: .whitespacesAndNewlines)
            return token.isEmpty ? nil : token
        }
    }

    private func totalEdgeCount() -> Int {
        outgoing.values.reduce(0) { partial, links in
            partial + links.count
        }
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        if case let .string(text) = value {
            return text
        }
        return nil
    }

    private func success(operation: String, payload: ValueType) -> ValueType {
        .object([
            "status": .string("ok"),
            "operation": .string(operation),
            "result": payload
        ])
    }

    private func error(operation: String, code: String, message: String, field: String) -> ValueType {
        .object([
            "status": .string("error"),
            "operation": .string(operation),
            "code": .string(code),
            "message": .string(message),
            "field_errors": .list([
                .object([
                    "field": .string(field),
                    "code": .string(code),
                    "message": .string(message)
                ])
            ])
        ])
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
            "docsRAG",
            "help",
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
            "prompt.submit",
            "docsRAG.setQuery",
            "docsRAG.search",
            "docsRAG.openTopDocument",
            "docsRAG.askRAG",
            "help.openContextual",
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
            "ui.setCurrentThread",
            "ui.openMatchedResourceLibrary",
            "ui.clearPromptHistory",
            "ui.clearComponentSurfaces",
            "ui.setActiveTab",
            "ui.setActiveHelper",
            "ui.setActiveMoreTab",
            "ui.setLearningEnabled",
            "ui.setCapabilityDiscoveryEnabled",
            "ui.setShowAdvanced",
            "invite",
            "invite.refreshStatuses",
            "contactInbox.refresh",
            "contactInbox.select",
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
            "workItem.title",
            "workItem.summary",
            "workItem.kind",
            "workItem.project",
            "workItem.repo",
            "workItem.cell",
            "workItem.surface",
            "workItem.severity",
            "workItem.priority",
            "workItem.currentBehavior",
            "workItem.expectedBehavior",
            "workItem.nextAction",
            "workItem.doneWhen",
            "workItem.capture",
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
        "state.assistant.groundedActionPlan.explanation",
        "state.assistant.groundedActionPlan.nextStep",
        "state.assistant.groundedActionPlan.status",
        "state.assistant.groundedPlan.status",
        "state.assistant.groundingAlternatives",
        "state.assistant.groundingDryRun.status",
        "state.assistant.groundingDryRun.summary",
        "state.assistant.groundingSchemas",
        "state.assistant.groundingVerification.allowed",
        "state.assistant.groundingVerification.reason",
        "state.assistant.groundingVerification.status",
        "state.assistant.groundingVerification.targetActionKeypath",
        "state.assistant.latestSuggestion.candidates",
        "state.assistant.latestSuggestion.confidence",
        "state.assistant.latestSuggestion.explanation",
        "state.assistant.latestSuggestion.kind",
        "state.assistant.latestSuggestion.purposeRef",
        "state.assistant.latestSuggestion.selectedCandidateProfileID",
        "state.assistant.latestSuggestion.targetPhrase",
        "state.assistant.promptUnderstanding.ambiguity",
        "state.assistant.promptUnderstanding.knowledgeNeed",
        "state.assistant.promptUnderstanding.negativeIntent",
        "state.assistant.promptUnderstanding.polarity",
        "state.assistant.promptUnderstanding.recommendedNextStep",
        "state.assistant.promptUnderstanding.speechAct",
        "state.assistant.promptUnderstanding.userGoal",
        "state.assistant.purposeContext.interestTreeExcerpt",
        "state.assistant.purposeContext.purposeTreeExcerpt",
        "state.assistant.purposeContext.responseGuidance",
        "state.assistant.purposeContext.summary",
        "state.assistant.providerRecommendation.executionScope",
        "state.assistant.providerRecommendation.kind",
        "state.assistant.providerRecommendation.reason",
        "state.assistant.providerRecommendation.title",
        "state.assistant.resourceMatches",
        "state.assistant.whySummary",
        "state.capabilityRequests",
        "state.composer.body",
        "state.currentThread.composer.body",
        "state.docsRAG.answer",
        "state.docsRAG.availableDocuments",
        "state.docsRAG.documentationMatchCount",
        "state.docsRAG.documentationMatches",
        "state.docsRAG",
        "state.docsRAG.query",
        "state.docsRAG.ragMatchCount",
        "state.docsRAG.ragMatches",
        "state.docsRAG.summary",
        "state.help.availableSources",
        "state.help.context",
        "state.help.question",
        "state.help.status",
        "state.help.summary",
        "state.help.suggestedPrompt",
        "state.inviteDraft.title",
        "state.invites",
        "state.contactInbox",
        "state.contactInbox.incomingInvites",
        "state.contactInbox.selectedTicketID",
        "state.messages",
        "state.pollDraft.optionsText",
        "state.pollDraft.question",
        "state.polls",
        "state.ui.activeMoreTab",
        "state.ui.activeTab",
        "state.ui.activeHelper",
        "state.ui.activeHelpers",
        "state.ui.activeHelperSummary",
        "state.ui.activeToolChips",
        "state.ui.componentSurfaces",
        "state.ui.hasActiveHelperSurface",
        "state.ui.hasPinnedComponentSurfaces",
        "state.ui.moreTabs",
        "state.ui.pinnedComponentSurfaces",
        "state.ui.promptMessages",
        "state.ui.tabs",
        "state.voice.finalTranscript",
        "state.voice.message",
        "state.workbench.agentReviewDraft.actionID",
        "state.workbench.capabilityRequestDraft",
        "state.workbench.agentReviewDraft.reason",
        "state.workbench.capabilityRequestDraft.summary",
        "state.workbench.capabilityRequestDraft.title",
        "state.workbench.ideaDraft.content",
        "state.workbench.ideaDraft.title",
        "state.workbench.meetingDraft.proposedTimesText",
        "state.workbench.meetingDraft.title",
        "state.workbench.modules",
        "state.workbench.projectDraft.description",
        "state.workbench.projectDraft.membersText",
        "state.workbench.projectDraft.title",
        "state.workbench.reminderDraft.scheduledAtText",
        "state.workbench.reminderDraft.title",
        "state.workbench.workItemDraft.cell",
        "state.workbench.workItemDraft.currentBehavior",
        "state.workbench.workItemDraft.doneWhen",
        "state.workbench.workItemDraft.expectedBehavior",
        "state.workbench.workItemDraft",
        "state.workbench.workItemDraft.kind",
        "state.workbench.workItemDraft.nextAction",
        "state.workbench.workItemDraft.priority",
        "state.workbench.workItemDraft.project",
        "state.workbench.workItemDraft.repo",
        "state.workbench.workItemDraft.severity",
        "state.workbench.workItemDraft.summary",
        "state.workbench.workItemDraft.surface",
        "state.workbench.workItemDraft.title",
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
        case "help":
            return BindingChatValue.nested("help", in: cachedState) ?? .object(Self.initialHelpState())
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
            BindingChatValue.set(.string(""), for: "composer.body", in: &cachedState)
            BindingChatValue.set(.bool(false), for: "ui.hasActionableSuggestion", in: &cachedState)
            BindingChatValue.set(.string(Self.defaultPrimaryActionHint), for: "ui.primaryActionHint", in: &cachedState)
            return response(status: "ok", message: "Composer cleared.")
        case "sendComposedMessage":
            return sendComposedMessage()
        case "prompt.submit":
            return await submitPrompt(value: value, requester: requester)
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
        case "ui.setCurrentThread":
            return setCurrentThread(value)
        case "ui.openMatchedResourceLibrary":
            return openMatchedResourceLibrary(value)
        case "ui.clearPromptHistory":
            BindingChatValue.set(.list([]), for: "ui.promptMessages", in: &cachedState)
            return .object(["ok": .bool(true), "sideEffect": .bool(false)])
        case "ui.clearComponentSurfaces":
            BindingChatValue.set(.list([]), for: "ui.componentSurfaces", in: &cachedState)
            BindingChatValue.set(.list([]), for: "ui.activeToolChips", in: &cachedState)
            BindingChatValue.set(.list([]), for: "ui.activeHelpers", in: &cachedState)
            BindingChatValue.set(.list([]), for: "ui.minimizedComponentSurfaces", in: &cachedState)
            BindingChatValue.set(.list([]), for: "ui.pinnedComponentSurfaces", in: &cachedState)
            BindingChatValue.set(.string(""), for: "ui.activeHelper", in: &cachedState)
            BindingChatValue.set(.string(""), for: "ui.activeHelperSummary", in: &cachedState)
            BindingChatValue.set(.bool(false), for: "ui.hasActiveHelperSurface", in: &cachedState)
            BindingChatValue.set(.bool(false), for: "ui.hasPinnedComponentSurfaces", in: &cachedState)
            BindingChatValue.set(.string(""), for: "ui.activeComponentSurfaceID", in: &cachedState)
            return .object(["ok": .bool(true), "sideEffect": .bool(false)])
        case "ui.setActiveTab":
            BindingChatValue.set(.string(text(from: value)), for: "ui.activeTab", in: &cachedState)
            return response(status: "ok", message: "Tab updated.")
        case "ui.setActiveHelper":
            let helper = BindingChatValue.string(BindingChatValue.object(value)?["activeHelper"]) ?? text(from: value)
            BindingChatValue.set(.string(helper), for: "ui.activeHelper", in: &cachedState)
            BindingChatValue.set(.string("samtale"), for: "ui.activeTab", in: &cachedState)
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
            return await acceptSuggestion(requester: requester)
        case "assistant.queryResource":
            return await queryResource(value, requester: requester)
        case "assistant.provider.register":
            return registerProvider(value)
        case "assistant.provider.recommend":
            return recommendProvider(value)
        case "docsRAG.setQuery":
            BindingChatValue.set(.string(text(from: value)), for: "docsRAG.query", in: &cachedState)
            return response(status: "ok", message: "Docs/RAG query updated.")
        case "docsRAG.search":
            return searchDocsRAG(value)
        case "docsRAG.openTopDocument":
            return openTopDocument(value)
        case "docsRAG.askRAG":
            return askRAG(value)
        case "help.openContextual":
            return openContextualHelp(value)
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
            return await createInvite(value: value, requester: requester)
        case "invite.refreshStatuses":
            return await refreshOutgoingInviteStatuses(value: value, requester: requester)
        case "contactInbox.refresh":
            return await refreshContactInbox(value: value, requester: requester)
        case "contactInbox.select":
            return selectIncomingInvite(value)
        case "acceptInvite":
            if shouldUseLegacyLocalInviteGate(value) {
                BindingChatValue.set(.string("accepted"), for: "inviteStatus", in: &cachedState)
                return response(status: "ok", message: "Lokal chat-tilgang er godtatt.")
            }
            return await respondToIncomingInvite(value: value, status: "accepted", requester: requester)
        case "declineInvite":
            if shouldUseLegacyLocalInviteGate(value) {
                BindingChatValue.set(.string("declined"), for: "inviteStatus", in: &cachedState)
                return response(status: "ok", message: "Lokal chat-tilgang er avslått.")
            }
            return await respondToIncomingInvite(value: value, status: "declined", requester: requester)
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
        case "workItem.title":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.title", in: &cachedState)
            return response(status: "ok", message: "Work item title updated.")
        case "workItem.summary":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.summary", in: &cachedState)
            return response(status: "ok", message: "Work item summary updated.")
        case "workItem.kind":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.kind", in: &cachedState)
            return response(status: "ok", message: "Work item kind updated.")
        case "workItem.project":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.project", in: &cachedState)
            return response(status: "ok", message: "Work item project updated.")
        case "workItem.repo":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.repo", in: &cachedState)
            return response(status: "ok", message: "Work item repo updated.")
        case "workItem.cell":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.cell", in: &cachedState)
            return response(status: "ok", message: "Work item cell updated.")
        case "workItem.surface":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.surface", in: &cachedState)
            return response(status: "ok", message: "Work item surface updated.")
        case "workItem.severity":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.severity", in: &cachedState)
            return response(status: "ok", message: "Work item severity updated.")
        case "workItem.priority":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.priority", in: &cachedState)
            return response(status: "ok", message: "Work item priority updated.")
        case "workItem.currentBehavior":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.currentBehavior", in: &cachedState)
            return response(status: "ok", message: "Work item current behavior updated.")
        case "workItem.expectedBehavior":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.expectedBehavior", in: &cachedState)
            return response(status: "ok", message: "Work item expected behavior updated.")
        case "workItem.nextAction":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.nextAction", in: &cachedState)
            return response(status: "ok", message: "Work item next action updated.")
        case "workItem.doneWhen":
            BindingChatValue.set(.string(text(from: value)), for: "workbench.workItemDraft.doneWhen", in: &cachedState)
            return response(status: "ok", message: "Work item done condition updated.")
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
        case "meeting.schedule", "idea.capture", "workItem.capture", "todo.create", "project.create", "reminder.create", "agent.review.create", "agent.review.execute", "agent.reviewIntent":
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
            ?? BindingChatValue.string(BindingChatValue.nested("composer.body", in: cachedState))
            ?? BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState))
            ?? ""
        let capabilityDiscoveryEnabled = BindingChatValue.bool(BindingChatValue.nested("ui.capabilityDiscoveryEnabled", in: cachedState)) ?? false
        let perspective = await perspectiveSummary(requester: requester)
        let perspectiveContext = BindingChatPurposeContext
            .from(value: .object(perspective), source: "Binding.PerspectiveCell.summary")
        let suggestion = BindingChatIntentClassifier.classify(
            prompt: draft,
            capabilityDiscoveryEnabled: capabilityDiscoveryEnabled,
            perspectiveContext: perspectiveContext
        )
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
        let purposeContext = purposeContextSummary(
            draft: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches,
            perspectiveSummary: perspective,
            perspectiveContext: perspectiveContext
        )
        let promptUnderstanding = promptUnderstandingFrame(
            draft: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches
        )
        let groundedActionPlan = groundedActionPlan(
            draft: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches,
            providerRecommendation: recommendation
        )
        let groundingSchemas = BindingGroundedActionVerifier.availableSchemas(
            resourceMatches: resourceMatches,
            providers: providers
        )
        let groundingVerification = BindingGroundedActionVerifier.verify(
            plan: groundedActionPlan,
            suggestion: suggestion,
            resourceMatches: resourceMatches,
            providerRecommendation: recommendation
        )
        let groundingDryRun = BindingGroundedActionVerifier.dryRun(
            plan: groundedActionPlan,
            verification: groundingVerification,
            resourceMatches: resourceMatches
        )
        let groundingAlternatives = BindingGroundedActionVerifier.alternatives(
            suggestion: suggestion,
            resourceMatches: resourceMatches
        )
        let contextPack: Object = [
            "draft": .string(draft),
            "capabilityDiscoveryEnabled": .bool(capabilityDiscoveryEnabled),
            "perspectiveSummary": .object(perspective),
            "perspectiveContext": .object(perspectiveContext.objectValue()),
            "purposeContext": .object(purposeContext),
            "promptUnderstanding": .object(promptUnderstanding),
            "groundedActionPlan": .object(groundedActionPlan),
            "groundingVerification": .object(groundingVerification),
            "groundingDryRun": .object(groundingDryRun),
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
        let matchedConfiguration = resourceMatches.first(where: { BindingChatValue.string($0["kind"]) == "cell_configuration" })
        let portholeUI = BindingChatIntentClassifier.portholeUIRequest(for: draft)
            ?? matchedConfiguration.map { BindingChatIntentClassifier.libraryUIRequest(for: $0, autoOpen: false) }
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
            "promptUnderstanding": .object(promptUnderstanding),
            "groundedActionPlan": .object(groundedActionPlan),
            "groundedPlan": .object(groundedActionPlan),
            "groundingVerification": .object(groundingVerification),
            "groundingDryRun": .object(groundingDryRun),
            "groundingSchemas": .list(groundingSchemas.map(ValueType.object)),
            "groundingAlternatives": .list(groundingAlternatives.map(ValueType.object)),
            "purposeContext": .object(purposeContext),
            "agentStatus": .object(agentStatusObject),
            "agentUseDecision": .object(agentUseDecisionObject),
            "priorityIntent": .object(suggestionObject),
            "lastContextPack": .object(contextPack),
            "lastAnalyzedDraft": .string(draft),
            "intentCandidates": .list(suggestion.shouldSuggest ? [.object(suggestionObject)] : []),
            "requiresUserApproval": .bool(true)
        ]
        if let portholeUI {
            assistantUpdates["portholeUI"] = .object(portholeUI)
        }
        for (key, update) in assistantUpdates {
            BindingChatValue.set(update, for: "assistant.\(key)", in: &cachedState)
        }
        BindingChatValue.set(.bool(suggestion.shouldSuggest), for: "ui.hasActionableSuggestion", in: &cachedState)
        BindingChatValue.set(.string(primaryActionHint(for: suggestion)), for: "ui.primaryActionHint", in: &cachedState)
        updateDraftsFromAnalysis(
            draft: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches
        )
        appendPromptMessage(
            draft: draft,
            suggestion: suggestion,
            groundedActionPlan: groundedActionPlan,
            resourceMatches: resourceMatches
        )
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
            "promptUnderstanding": .object(promptUnderstanding),
            "groundedActionPlan": .object(groundedActionPlan),
            "groundedPlan": .object(groundedActionPlan),
            "groundingVerification": .object(groundingVerification),
            "groundingDryRun": .object(groundingDryRun),
            "groundingSchemas": .list(groundingSchemas.map(ValueType.object)),
            "groundingAlternatives": .list(groundingAlternatives.map(ValueType.object)),
            "purposeContext": .object(purposeContext),
            "sideEffect": .bool(false)
        ]
        if let portholeUI {
            response["portholeUI"] = .object(portholeUI)
        }
        return .object(response)
    }

    private func submitPrompt(value: ValueType, requester: Identity) async -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        let prompt = BindingChatValue.string(value)
            ?? BindingChatValue.string(payload["text"])
            ?? BindingChatValue.string(payload["prompt"])
            ?? BindingChatValue.string(BindingChatValue.nested("composer.body", in: cachedState))
            ?? BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState))
            ?? ""
        let analyzed = await analyzeDraft(
            value: .object(["prompt": .string(prompt)]),
            requester: requester
        )
        clearComposerAfterPromptSubmission()
        if BindingChatValue.normalized(prompt).contains("arendalsuka"),
           let resource = currentCellConfigurationResource() {
            return openMatchedResourceLibrary(
                .object([
                    "resourceID": resource["id"] ?? .null,
                    "autoOpen": .bool(true)
                ])
            )
        }
        guard var response = BindingChatValue.object(analyzed) else { return analyzed }
        response["state"] = .object(cachedState)
        return .object(response)
    }

    private func promptUnderstandingFrame(
        draft: String,
        suggestion: BindingChatIntentClassification,
        resourceMatches: [Object]
    ) -> Object {
        let normalized = BindingChatValue.normalized(draft)
        let negative = suggestion.negativeIntent.isEmpty == false
        let knowledgeNeed = suggestion.helperID == "docs-rag"
            || resourceMatches.contains { BindingChatValue.string($0["kind"]) == "rag_case" }
        let resourceNeed = suggestion.helperID == "resource-router"
            || suggestion.helperID == "mermaid-diagram"
            || resourceMatches.contains { BindingChatValue.string($0["kind"]) == "cell_configuration" }
        let speechAct: String
        if normalized.contains("?") || normalized.contains("hva") || normalized.contains("kan du") {
            speechAct = knowledgeNeed ? "question" : "request"
        } else if normalized.contains("ikke") || normalized.contains("not ") {
            speechAct = "constraint"
        } else {
            speechAct = suggestion.shouldSuggest ? "request" : "statement"
        }
        return [
            "schema": .string("binding.prompt-understanding.v0"),
            "speechAct": .string(speechAct),
            "temporalFrame": .string(normalized.contains("i dag") || normalized.contains("today") ? "today" : "unspecified"),
            "polarity": .string(negative ? "negative" : "positive"),
            "activeSurfaceMode": .string("chat-first"),
            "explicitObjects": .list(explicitObjects(from: draft).map(ValueType.string)),
            "purposeCandidates": .list([
                .object([
                    "purposeRef": .string(suggestion.purposeRef),
                    "helperID": .string(suggestion.helperID),
                    "confidence": .float(suggestion.confidence),
                    "directPurposeHit": .bool(suggestion.shouldSuggest)
                ])
            ]),
            "knowledgeNeed": .bool(knowledgeNeed),
            "resourceNeed": .bool(resourceNeed),
            "ambiguity": .string(suggestion.status == "needs_candidate_selection" ? "needs_candidate_selection" : "low"),
            "negativeIntent": suggestion.negativeIntent.isEmpty ? .null : .string(suggestion.negativeIntent),
            "userGoal": .string(suggestion.shouldSuggest ? suggestion.explanation : "Ingen trygg handlende hjelper ble valgt."),
            "recommendedNextStep": .string(suggestion.shouldSuggest ? "open_helper_after_user_click" : "ask_clarifying_or_continue_chat")
        ]
    }

    private func purposeContextSummary(
        draft: String,
        suggestion: BindingChatIntentClassification,
        resourceMatches: [Object],
        perspectiveSummary: Object,
        perspectiveContext: BindingChatPurposeContext
    ) -> Object {
        let directPurposeRefs = Array(Set(([suggestion.purposeRef] + resourceMatches.flatMap { resource in
            BindingChatValue.stringList(resource["purposeRefs"]) + [BindingChatValue.string(resource["purposeRef"])].compactMap { $0 }
        }).filter { $0.isEmpty == false })).sorted()
        let directInterests = Array(Set((suggestion.interests + resourceMatches.flatMap {
            BindingChatValue.stringList($0["interests"])
        }).filter { $0.isEmpty == false })).sorted()
        let purposeRefs = Array(Set(directPurposeRefs + perspectiveContext.purposeRefs)).sorted()
        let interests = Array(Set(directInterests + perspectiveContext.interests)).sorted()
        let activeStatus = BindingChatValue.string(perspectiveSummary["status"]) ?? "unavailable"
        let compactPurposeText = purposeRefs.prefix(5).joined(separator: " -> ")
        let compactInterestText = interests.prefix(8).joined(separator: ", ")
        let summary: String
        if directPurposeRefs.isEmpty == false {
            summary = "Direkte purpose-hit: \(directPurposeRefs.prefix(5).joined(separator: " -> "))"
        } else if perspectiveContext.purposeRefs.isEmpty == false {
            summary = "Aktiv Perspective: \(perspectiveContext.purposeRefs.prefix(5).joined(separator: " -> "))"
        } else {
            summary = "Ingen direkte purpose-hit."
        }
        return [
            "schema": .string("haven.purpose-context-pack.v0.binding-preview"),
            "source": .string("PerspectiveCell + Binding deterministic classifier"),
            "status": .string(activeStatus),
            "summary": .string(summary),
            "purposeRefs": .list(purposeRefs.map(ValueType.string)),
            "interests": .list(interests.map(ValueType.string)),
            "directPurposeRefs": .list(directPurposeRefs.map(ValueType.string)),
            "directInterests": .list(directInterests.map(ValueType.string)),
            "activePerspectivePurposeRefs": .list(perspectiveContext.purposeRefs.map(ValueType.string)),
            "activePerspectiveInterests": .list(perspectiveContext.interests.map(ValueType.string)),
            "perspectiveContextSource": .string(perspectiveContext.source),
            "purposeTreeExcerpt": .string(compactPurposeText.isEmpty ? "purpose://prompt.unknown" : compactPurposeText),
            "interestTreeExcerpt": .string(compactInterestText.isEmpty ? "chat-assistant, requires-user-approval" : compactInterestText),
            "responseGuidance": .string("Svar med brukerord først, og vis formål bare som begrunnelse i avansert eller ved eksplisitt spørsmål."),
            "progressiveHydration": .object([
                "detail": .string("compact"),
                "focusPurposeRef": purposeRefs.first.map(ValueType.string) ?? .string("purpose://prompt.unknown"),
                "nextQuery": .string("purpose.context.pack")
            ]),
            "sideEffectFree": .bool(true),
            "mutatesPerspective": .bool(false),
            "mutatesEntity": .bool(false),
            "draftPreview": .string(String(draft.prefix(180)))
        ]
    }

    private func groundedActionPlan(
        draft: String,
        suggestion: BindingChatIntentClassification,
        resourceMatches: [Object],
        providerRecommendation: BindingChatProviderDescriptor
    ) -> Object {
        BindingGroundedActionPlanner.plan(
            draft: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches,
            providerRecommendation: providerRecommendation
        )
    }

    private func updateDraftsFromAnalysis(
        draft: String,
        suggestion: BindingChatIntentClassification,
        resourceMatches: [Object]
    ) {
        if suggestion.helperID == "docs-rag"
            || resourceMatches.contains(where: { BindingChatValue.string($0["kind"]) == "rag_case" }) {
            BindingChatValue.set(.string(draft), for: "docsRAG.query", in: &cachedState)
        }
        if suggestion.helperID == "work-item" {
            let title = String(draft.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
            BindingChatValue.set(.string(title.isEmpty ? "Nytt work item fra Co-Pilot" : title), for: "workbench.workItemDraft.title", in: &cachedState)
            BindingChatValue.set(.string(draft), for: "workbench.workItemDraft.summary", in: &cachedState)
            BindingChatValue.set(.string(draft.lowercased().contains("bug") || draft.lowercased().contains("feil") ? "bug" : "task"), for: "workbench.workItemDraft.kind", in: &cachedState)
            BindingChatValue.set(.string("Binding"), for: "workbench.workItemDraft.repo", in: &cachedState)
            BindingChatValue.set(.string("Co-Pilot"), for: "workbench.workItemDraft.surface", in: &cachedState)
            BindingChatValue.set(.string("Registrer etter review"), for: "workbench.workItemDraft.nextAction", in: &cachedState)
        }
    }

    private func appendPromptMessage(
        draft: String,
        suggestion: BindingChatIntentClassification,
        groundedActionPlan: Object,
        resourceMatches: [Object]
    ) {
        guard draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        var messages = BindingChatValue.list(BindingChatValue.nested("ui.promptMessages", in: cachedState)) ?? []
        let threadID = BindingChatValue.string(BindingChatValue.nested("currentThread.id", in: cachedState)) ?? "local-copilot-thread"
        let topResourceTitles = resourceMatches.compactMap { BindingChatValue.string($0["title"]) }
        let resourceSummary = topResourceTitles.isEmpty ? "" : " Treff: \(topResourceTitles.prefix(3).joined(separator: ", "))."
        let nextStep = BindingChatValue.string(groundedActionPlan["nextStep"]) ?? "continue_chat"
        let nextStepTitle = promptLogNextStepTitle(nextStep)
        let assistantStatus = suggestion.shouldSuggest
            ? "\(helperTitle(suggestion.helperID)) · \(nextStepTitle)"
            : nextStepTitle
        let userMessage: Object = [
            "id": .string(UUID().uuidString),
            "role": .string("user"),
            "speaker": .string("Du"),
            "body": .string(draft),
            "statusText": .string("Sendt"),
            "kind": .string("user_prompt"),
            "threadID": .string(threadID),
            "rowStyleClasses": .list(["chat-prompt-row", "chat-prompt-row-user"].map(ValueType.string))
        ]
        let assistantMessage: Object = [
            "id": .string(UUID().uuidString),
            "role": .string("assistant"),
            "speaker": .string("HAVEN Co-Pilot"),
            "body": .string("\(suggestion.explanation)\(resourceSummary)"),
            "statusText": .string(assistantStatus),
            "kind": .string("assistant_suggestion"),
            "helperID": .string(suggestion.helperID),
            "resourceMatchCount": .integer(resourceMatches.count),
            "resourceTitles": .list(topResourceTitles.prefix(5).map(ValueType.string)),
            "threadID": .string(threadID),
            "sideEffect": .bool(false),
            "rowStyleClasses": .list(["chat-prompt-row", "chat-prompt-row-assistant"].map(ValueType.string))
        ]
        messages.append(.object(userMessage))
        messages.append(.object(assistantMessage))
        BindingChatValue.set(.list(Array(messages.suffix(40))), for: "ui.promptMessages", in: &cachedState)
    }

    private func clearComposerAfterPromptSubmission() {
        BindingChatValue.set(.string(""), for: "composer.body", in: &cachedState)
        BindingChatValue.set(.string(""), for: "currentThread.composer.body", in: &cachedState)
    }

    private func promptLogNextStepTitle(_ nextStep: String) -> String {
        switch nextStep {
        case "open_helper":
            return "klar til å åpne hjelper"
        case "open_helper_after_user_click":
            return "åpnes bare etter ditt klikk"
        case "continue_chat", "ask_clarifying_or_continue_chat":
            return "fortsett som vanlig chat"
        case "query_resource":
            return "klar til å søke i valgt ressurs"
        case "review_signed_intent":
            return "krever review og signering"
        default:
            return nextStep.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func explicitObjects(from draft: String) -> [String] {
        draft
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                guard let first = token.first else { return false }
                return first.isUppercase || token.contains("://")
            }
            .prefix(8)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
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
                .string("activePurpose"),
                .string("perspective.state"),
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

        let activePurpose = try? await perspective.get(
            keypath: "activePurpose",
            requester: requester
        )
        let perspectiveState = try? await perspective.get(
            keypath: "perspective.state",
            requester: requester
        )
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
        summary["activePurpose"] = activePurpose ?? .null
        summary["perspectiveState"] = perspectiveState ?? .null
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
            "auditEvent": .object(auditEvent(type: "chat.entity-extension.scanned", subjectID: requester.uuid, summary: "Requester scanned owner-scoped HAVEN capabilities visible to this chat.")),
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
            "surface": .string("Co-Pilot"),
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
            "surface": .string("Co-Pilot"),
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
            "surface": .string("Co-Pilot"),
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
                "title": .string("Co-Pilot"),
                "summary": .string("HAVEN sin requester-visible chat workbench for PersonalChatHub."),
                "sourceCellEndpoint": .string("cell:///PersonalChatHub"),
                "sourceCellName": .string("BindingPersonalChatHubCell"),
                "configurationName": .string("Co-Pilot"),
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
            "configurationName": .string("Co-Pilot AI Provider"),
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
        guard let suggestion = openableSuggestionForHelper(),
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

        if helper == "resource-router",
           let resource = currentCellConfigurationResource() {
            var opened = BindingChatValue.object(openMatchedResourceLibrary(
                .object([
                    "resourceID": resource["id"] ?? .null,
                    "autoOpen": .bool(true)
                ])
            )) ?? [:]
            opened["helper"] = .string(helper)
            opened["suggestion"] = .object(suggestion)
            return .object(opened)
        }

        let surface = helperSurface(kind: helper, source: "suggestion")
        appendSurface(surface)
        BindingChatValue.set(.bool(false), for: "ui.hasActionableSuggestion", in: &cachedState)
        BindingChatValue.set(.string("\(helperTitle(helper)) er åpnet. Neste klikk inne i hjelperen bestemmer om noe lagres, sendes eller opprettes."), for: "ui.primaryActionHint", in: &cachedState)
        return .object([
            "ok": .bool(true),
            "helper": .string(helper),
            "surface": .object(surface),
            "suggestion": .object(suggestion),
            "ui": BindingChatValue.nested("ui", in: cachedState) ?? .null,
            "state": .object(cachedState),
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
            "ui": BindingChatValue.nested("ui", in: cachedState) ?? .null,
            "state": .object(cachedState),
            "sideEffect": .bool(false)
        ])
    }

    private func openableSuggestionForHelper() -> Object? {
        let draft = currentComposerDraft().trimmingCharacters(in: .whitespacesAndNewlines)
        let lastAnalyzedDraft = BindingChatValue.string(BindingChatValue.nested("assistant.lastAnalyzedDraft", in: cachedState))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if draft.isEmpty == false && draft != lastAnalyzedDraft {
            return stageDeterministicSuggestionFromComposer()
        }

        if let suggestion = BindingChatValue.object(BindingChatValue.nested("assistant.latestSuggestion", in: cachedState)),
           let helper = BindingChatValue.string(suggestion["helperID"]),
           !helper.isEmpty,
           BindingChatValue.string(suggestion["status"]) != "low_confidence" {
            return suggestion
        }

        return stageDeterministicSuggestionFromComposer()
    }

    private func stageDeterministicSuggestionFromComposer() -> Object? {
        let draft = currentComposerDraft()
        guard draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        let capabilityDiscoveryEnabled = BindingChatValue.bool(BindingChatValue.nested("ui.capabilityDiscoveryEnabled", in: cachedState)) ?? false
        let suggestion = BindingChatIntentClassifier.classify(
            prompt: draft,
            capabilityDiscoveryEnabled: capabilityDiscoveryEnabled
        )
        let resourceMatches = BindingChatIntentClassifier.resourceMatches(prompt: draft)
        let provider = BindingChatProviderRouter.localRulesProvider()
        let purposeContext = purposeContextSummary(
            draft: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches,
            perspectiveSummary: [
                "status": .string("not_queried"),
                "reason": .string("openSuggestedHelper used direct composer fallback")
            ],
            perspectiveContext: .empty
        )
        let promptUnderstanding = promptUnderstandingFrame(
            draft: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches
        )
        let groundedActionPlan = groundedActionPlan(
            draft: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches,
            providerRecommendation: provider
        )
        let groundingSchemas = BindingGroundedActionVerifier.availableSchemas(
            resourceMatches: resourceMatches,
            providers: [provider]
        )
        let groundingVerification = BindingGroundedActionVerifier.verify(
            plan: groundedActionPlan,
            suggestion: suggestion,
            resourceMatches: resourceMatches,
            providerRecommendation: provider
        )
        let groundingDryRun = BindingGroundedActionVerifier.dryRun(
            plan: groundedActionPlan,
            verification: groundingVerification,
            resourceMatches: resourceMatches
        )
        let groundingAlternatives = BindingGroundedActionVerifier.alternatives(
            suggestion: suggestion,
            resourceMatches: resourceMatches
        )
        let candidates = candidateRows(for: suggestion)
        var suggestionObject = suggestion.objectValue()
        suggestionObject["candidates"] = .list(candidates)
        suggestionObject["selectedCandidateProfileID"] = candidates.first.flatMap { BindingChatValue.string(BindingChatValue.object($0)?["id"]) }.map(ValueType.string) ?? .null

        BindingChatValue.set(.string(suggestion.shouldSuggest ? "suggested" : "low_confidence"), for: "assistant.status", in: &cachedState)
        BindingChatValue.set(.object(suggestionObject), for: "assistant.latestSuggestion", in: &cachedState)
        BindingChatValue.set(.list(suggestion.shouldSuggest ? [.object(suggestionObject)] : []), for: "assistant.suggestions", in: &cachedState)
        BindingChatValue.set(.object(suggestionObject), for: "assistant.priorityIntent", in: &cachedState)
        BindingChatValue.set(.list(suggestion.shouldSuggest ? [.object(suggestionObject)] : []), for: "assistant.intentCandidates", in: &cachedState)
        BindingChatValue.set(.string(suggestion.reason), for: "assistant.whySummary", in: &cachedState)
        BindingChatValue.set(.object(provider.objectValue()), for: "assistant.providerRecommendation", in: &cachedState)
        BindingChatValue.set(.list([.object(provider.objectValue())]), for: "assistant.assistantProviders", in: &cachedState)
        BindingChatValue.set(.list(resourceMatches.map(ValueType.object)), for: "assistant.resourceMatches", in: &cachedState)
        BindingChatValue.set(.integer(resourceMatches.count), for: "assistant.resourceMatchCount", in: &cachedState)
        BindingChatValue.set(.object(promptUnderstanding), for: "assistant.promptUnderstanding", in: &cachedState)
        BindingChatValue.set(.object(groundedActionPlan), for: "assistant.groundedActionPlan", in: &cachedState)
        BindingChatValue.set(.object(groundedActionPlan), for: "assistant.groundedPlan", in: &cachedState)
        BindingChatValue.set(.object(groundingVerification), for: "assistant.groundingVerification", in: &cachedState)
        BindingChatValue.set(.object(groundingDryRun), for: "assistant.groundingDryRun", in: &cachedState)
        BindingChatValue.set(.list(groundingSchemas.map(ValueType.object)), for: "assistant.groundingSchemas", in: &cachedState)
        BindingChatValue.set(.list(groundingAlternatives.map(ValueType.object)), for: "assistant.groundingAlternatives", in: &cachedState)
        BindingChatValue.set(.object(purposeContext), for: "assistant.purposeContext", in: &cachedState)
        BindingChatValue.set(.string(draft), for: "assistant.lastAnalyzedDraft", in: &cachedState)
        BindingChatValue.set(.bool(true), for: "assistant.requiresUserApproval", in: &cachedState)
        updateDraftsFromAnalysis(
            draft: draft,
            suggestion: suggestion,
            resourceMatches: resourceMatches
        )
        appendPromptMessage(
            draft: draft,
            suggestion: suggestion,
            groundedActionPlan: groundedActionPlan,
            resourceMatches: resourceMatches
        )
        clearComposerAfterPromptSubmission()
        BindingChatValue.set(.bool(false), for: "ui.hasActionableSuggestion", in: &cachedState)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)

        guard suggestion.shouldSuggest else { return nil }
        return suggestionObject
    }

    private func currentComposerDraft() -> String {
        BindingChatValue.string(BindingChatValue.nested("composer.body", in: cachedState))
            ?? BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState))
            ?? ""
    }

    private func appendSurface(_ surface: Object) {
        var surfaces = BindingChatValue.list(BindingChatValue.nested("ui.componentSurfaces", in: cachedState)) ?? []
        surfaces.removeAll { BindingChatValue.string(BindingChatValue.object($0)?["id"]) == BindingChatValue.string(surface["id"]) }
        let incomingKind = BindingChatValue.string(surface["kind"]) ?? ""
        if incomingKind == "resource-router" || incomingKind == "mermaid-diagram" {
            surfaces.removeAll {
                guard let existing = BindingChatValue.object($0) else { return false }
                return BindingChatValue.string(existing["kind"]) == "invite"
                    && BindingChatValue.bool(existing["pinned"]) != true
            }
        }
        surfaces.append(.object(surface))
        BindingChatValue.set(.list(surfaces), for: "ui.componentSurfaces", in: &cachedState)
        BindingChatValue.set(.string("samtale"), for: "ui.activeTab", in: &cachedState)
        if let kind = BindingChatValue.string(surface["kind"]) {
            BindingChatValue.set(.string(kind), for: "ui.activeHelper", in: &cachedState)
            BindingChatValue.set(.string("\(helperTitle(kind)) er åpnet som utkast. Handling krever eget klikk."), for: "ui.activeHelperSummary", in: &cachedState)
        }
        if let id = BindingChatValue.string(surface["id"]) {
            BindingChatValue.set(.string(id), for: "ui.activeComponentSurfaceID", in: &cachedState)
        }
        BindingChatValue.set(.object([
            "hint": .string("appear"),
            "sourceRole": .string("suggestion-card")
        ]), for: "ui.lastMotionEvent", in: &cachedState)
        refreshActiveToolState(from: surfaces)
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
        refreshActiveToolState(from: surfaces)
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

    private func setCurrentThread(_ value: ValueType) -> ValueType {
        let object = BindingChatValue.object(value)
        let threadID = BindingChatValue.string(value)
            ?? BindingChatValue.string(object?["threadID"])
            ?? BindingChatValue.string(object?["id"])
            ?? BindingChatValue.string(object?["value"])
            ?? BindingChatValue.string(object?["selected"])
            ?? BindingChatValue.string(object?["selectedValue"])
        guard let threadID, threadID.isEmpty == false else {
            return response(status: "blocked", message: "Velg en tråd først.")
        }
        let threads = BindingChatValue.list(BindingChatValue.nested("threads", in: cachedState)) ?? []
        guard let selected = threads.compactMap(BindingChatValue.object).first(where: {
            BindingChatValue.string($0["id"]) == threadID
        }) else {
            return response(status: "blocked", message: "Fant ikke den tråden i chat-scope.")
        }
        var currentThread = BindingChatValue.object(BindingChatValue.nested("currentThread", in: cachedState)) ?? [:]
        for key in ["id", "title", "kind", "lastMessagePreview", "messageCount", "statusText", "updatedAt"] {
            if let value = selected[key] {
                currentThread[key] = value
            }
        }
        if currentThread["composer"] == nil {
            currentThread["composer"] = .object([
                "body": .string(""),
                "contentType": .string("text/plain")
            ])
        }
        BindingChatValue.set(.object(currentThread), for: "currentThread", in: &cachedState)
        return .object([
            "ok": .bool(true),
            "status": .string("selected"),
            "threadID": .string(threadID),
            "sideEffect": .bool(false),
            "state": .object(cachedState)
        ])
    }

    private func refreshActiveToolState(from surfaces: [ValueType]? = nil) {
        let sourceSurfaces = surfaces ?? BindingChatValue.list(BindingChatValue.nested("ui.componentSurfaces", in: cachedState)) ?? []
        let visibleSurfaces = sourceSurfaces.filter {
            BindingChatValue.string(BindingChatValue.object($0)?["state"]) != "dismissed"
        }
        let chips = visibleSurfaces.compactMap { item -> ValueType? in
            guard let surface = BindingChatValue.object(item),
                  BindingChatValue.string(surface["state"]) != "dismissed" else { return nil }
            return .object(activeToolChip(from: surface))
        }
        let helpers = visibleSurfaces.compactMap { item -> ValueType? in
            guard let surface = BindingChatValue.object(item),
                  let kind = BindingChatValue.string(surface["kind"]) else { return nil }
            return .object([
                "id": .string(kind),
                "title": .string(helperTitle(kind)),
                "surfaceID": BindingChatValue.string(surface["id"]).map(ValueType.string) ?? .string(kind)
            ])
        }
        let pinned = visibleSurfaces.filter {
            BindingChatValue.bool(BindingChatValue.object($0)?["pinned"]) == true
        }
        BindingChatValue.set(.list(chips), for: "ui.activeToolChips", in: &cachedState)
        BindingChatValue.set(.list(helpers), for: "ui.activeHelpers", in: &cachedState)
        BindingChatValue.set(.bool(helpers.isEmpty == false), for: "ui.hasActiveHelperSurface", in: &cachedState)
        BindingChatValue.set(.list(pinned), for: "ui.pinnedComponentSurfaces", in: &cachedState)
        BindingChatValue.set(.bool(pinned.isEmpty == false), for: "ui.hasPinnedComponentSurfaces", in: &cachedState)
        let helperIDs = helpers.compactMap { BindingChatValue.string(BindingChatValue.object($0)?["id"]) }
        let currentActiveHelper = BindingChatValue.string(BindingChatValue.nested("ui.activeHelper", in: cachedState)) ?? ""
        if helperIDs.isEmpty {
            BindingChatValue.set(.string(""), for: "ui.activeHelper", in: &cachedState)
            BindingChatValue.set(.string(""), for: "ui.activeHelperSummary", in: &cachedState)
        } else if currentActiveHelper.isEmpty || helperIDs.contains(currentActiveHelper) == false,
                  let firstHelper = helperIDs.first {
            BindingChatValue.set(.string(firstHelper), for: "ui.activeHelper", in: &cachedState)
            BindingChatValue.set(.string("\(helperTitle(firstHelper)) er aktiv som privat hjelper."), for: "ui.activeHelperSummary", in: &cachedState)
        }
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
        refreshActiveToolState(from: surfaces)
        return .object(["ok": .bool(true), "sideEffect": .bool(false)])
    }

    private func dismissSuggestion() -> ValueType {
        let empty = BindingChatIntentClassifier.classify(prompt: "").objectValue()
        BindingChatValue.set(.object(empty), for: "assistant.latestSuggestion", in: &cachedState)
        BindingChatValue.set(.list([]), for: "assistant.suggestions", in: &cachedState)
        BindingChatValue.set(.string("dismissed"), for: "assistant.status", in: &cachedState)
        BindingChatValue.set(.bool(false), for: "ui.hasActionableSuggestion", in: &cachedState)
        BindingChatValue.set(.string(Self.defaultPrimaryActionHint), for: "ui.primaryActionHint", in: &cachedState)
        return .object(["ok": .bool(true), "sideEffect": .bool(false)])
    }

    private func acceptSuggestion(requester: Identity) async -> ValueType {
        guard let suggestion = BindingChatValue.object(BindingChatValue.nested("assistant.latestSuggestion", in: cachedState)),
              let helper = BindingChatValue.string(suggestion["helperID"]),
              !helper.isEmpty,
              BindingChatValue.string(suggestion["status"]) != "low_confidence"
        else {
            return response(status: "blocked", message: "No suggestion to accept.")
        }

        switch helper {
        case "invite":
            return await createInvite(value: .object([:]), requester: requester)
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

    private func searchDocsRAG(_ value: ValueType) -> ValueType {
        let query = docsRAGQuery(from: value)
        let matches = docsRAGMatches(for: query)
        BindingChatValue.set(.string(query), for: "docsRAG.query", in: &cachedState)
        BindingChatValue.set(.list(matches.documentation.map(ValueType.object)), for: "docsRAG.documentationMatches", in: &cachedState)
        BindingChatValue.set(.integer(matches.documentation.count), for: "docsRAG.documentationMatchCount", in: &cachedState)
        BindingChatValue.set(.list(matches.rag.map(ValueType.object)), for: "docsRAG.ragMatches", in: &cachedState)
        BindingChatValue.set(.integer(matches.rag.count), for: "docsRAG.ragMatchCount", in: &cachedState)
        BindingChatValue.set(.string(matches.summary), for: "docsRAG.summary", in: &cachedState)
        return .object([
            "ok": .bool(true),
            "status": .string("matched"),
            "query": .string(query),
            "documentationMatches": .list(matches.documentation.map(ValueType.object)),
            "ragMatches": .list(matches.rag.map(ValueType.object)),
            "summary": .string(matches.summary),
            "sideEffect": .bool(false)
        ])
    }

    private func openContextualHelp(_ value: ValueType) -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        let context = contextualHelpContext(from: payload)
        let prompt = contextualHelpPrompt(from: context)
        let summary = contextualHelpSummary(from: context)
        let availableSources = contextualHelpSources(from: context)

        BindingChatValue.set(.object(context), for: "help.context", in: &cachedState)
        BindingChatValue.set(.string(prompt), for: "help.question", in: &cachedState)
        BindingChatValue.set(.string(prompt), for: "help.suggestedPrompt", in: &cachedState)
        BindingChatValue.set(.string(summary), for: "help.summary", in: &cachedState)
        BindingChatValue.set(.string("context_staged"), for: "help.status", in: &cachedState)
        BindingChatValue.set(.list(availableSources.map(ValueType.object)), for: "help.availableSources", in: &cachedState)
        BindingChatValue.set(.string(prompt), for: "composer.body", in: &cachedState)
        BindingChatValue.set(.string(prompt), for: "currentThread.composer.body", in: &cachedState)
        BindingChatValue.set(.string(prompt), for: "docsRAG.query", in: &cachedState)
        BindingChatValue.set(.string("samtale"), for: "ui.activeTab", in: &cachedState)
        BindingChatValue.set(.string("hjelp"), for: "ui.activeMoreTab", in: &cachedState)
        BindingChatValue.set(.string("docs-rag"), for: "ui.activeHelper", in: &cachedState)
        BindingChatValue.set(.string("Hjelpekontekst er lagt i chatten. Finn forslag eller spør docs/RAG krever eget klikk."), for: "ui.primaryActionHint", in: &cachedState)
        appendHelpPromptMessage(prompt: prompt, summary: summary)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)

        return .object([
            "ok": .bool(true),
            "status": .string("context_staged"),
            "sideEffect": .bool(false),
            "context": .object(context),
            "prompt": .string(prompt),
            "availableSources": .list(availableSources.map(ValueType.object)),
            "state": .object(cachedState)
        ])
    }

    private func openTopDocument(_ value: ValueType) -> ValueType {
        let query = docsRAGQuery(from: value)
        let matches = docsRAGMatches(for: query)
        let document = matches.documentation.first ?? Self.defaultDocsRAGDocuments().first ?? [:]
        BindingChatValue.set(.object(document), for: "docsRAG.selectedDocument", in: &cachedState)
        return .object([
            "ok": .bool(true),
            "status": .string("document_selected"),
            "document": .object(document),
            "sideEffect": .bool(false)
        ])
    }

    private func askRAG(_ value: ValueType) -> ValueType {
        let query = docsRAGQuery(from: value)
        let matches = docsRAGMatches(for: query)
        let answer = matches.rag.first.flatMap { BindingChatValue.string($0["summary"]) }
            ?? "Ingen granted RAG-case ble funnet. Du kan bruke docs-treffene eller avklare spørsmålet."
        BindingChatValue.set(.string(answer), for: "docsRAG.answer", in: &cachedState)
        BindingChatValue.set(.string(query), for: "docsRAG.query", in: &cachedState)
        BindingChatValue.set(.list(matches.rag.map(ValueType.object)), for: "docsRAG.ragMatches", in: &cachedState)
        BindingChatValue.set(.integer(matches.rag.count), for: "docsRAG.ragMatchCount", in: &cachedState)
        return .object([
            "ok": .bool(true),
            "status": .string(matches.rag.isEmpty ? "no_granted_rag_case" : "answer_staged"),
            "answer": .string(answer),
            "sideEffect": .bool(false)
        ])
    }

    private func openMatchedResourceLibrary(_ value: ValueType) -> ValueType {
        let object = BindingChatValue.object(value) ?? [:]
        let autoOpen = BindingChatValue.bool(object["autoOpen"]) ?? true
        let resourceID = BindingChatValue.string(value)
            ?? BindingChatValue.string(object["resourceID"])
            ?? BindingChatValue.string(object["id"])
            ?? BindingChatValue.string(object["selectedValue"])
        let matches = (BindingChatValue.list(BindingChatValue.nested("assistant.resourceMatches", in: cachedState)) ?? [])
            .compactMap(BindingChatValue.object)
        let selected = resourceID.flatMap { id in
            matches.first {
                BindingChatValue.string($0["id"]) == id
                    || BindingChatValue.string($0["title"]) == id
                    || BindingChatValue.string($0["sourceCellEndpoint"]) == id
            }
        } ?? matches.first(where: { BindingChatValue.string($0["kind"]) == "cell_configuration" })
        let resource: Object
        if let selected {
            resource = selected
        } else {
            resource = [
                "id": object["resourceID"] ?? .string("configuration:copilot-chat"),
                "title": object["configurationName"] ?? .string("Co-Pilot"),
                "sourceCellEndpoint": object["sourceCellEndpoint"] ?? .string("cell:///PersonalChatHub")
            ]
        }
        let portholeUI = BindingChatIntentClassifier.libraryUIRequest(for: resource, autoOpen: autoOpen)
        let loadedConfiguration = autoOpen ? configurationForResource(resource) : nil
        if let loadedConfiguration {
            Task { @MainActor in
                BindingPortholeLoadBridge.post(configuration: loadedConfiguration)
            }
        }
        BindingChatValue.set(.object(portholeUI), for: "assistant.portholeUI", in: &cachedState)
        BindingChatValue.set(.object(resource), for: "assistant.selectedResourceMatch", in: &cachedState)
        if matches.isEmpty {
            BindingChatValue.set(.list([.object(resource)]), for: "assistant.resourceMatches", in: &cachedState)
            BindingChatValue.set(.integer(1), for: "assistant.resourceMatchCount", in: &cachedState)
        }
        var surface = helperSurface(kind: "resource-router", source: "matched-resource")
        surface["selectedResourceID"] = BindingChatValue.string(resource["id"]).map(ValueType.string) ?? .null
        surface["selectedResourceTitle"] = BindingChatValue.string(resource["title"]).map(ValueType.string) ?? .null
        surface["summary"] = .string(
            loadedConfiguration == nil
                ? "Valgt flate er klargjort i Library."
                : "Valgt CellConfiguration er lastet i HAVEN."
        )
        appendSurface(surface)
        BindingChatValue.set(.bool(false), for: "ui.hasActionableSuggestion", in: &cachedState)
        return .object([
            "ok": .bool(true),
            "status": .string("library_open_requested"),
            "resource": .object(resource),
            "portholeUI": .object(portholeUI),
            "ui": BindingChatValue.nested("ui", in: cachedState) ?? .null,
            "state": .object(cachedState),
            "configurationLoaded": .bool(loadedConfiguration != nil),
            "sideEffect": .bool(false)
        ])
    }

    private func currentCellConfigurationResource() -> Object? {
        (BindingChatValue.list(BindingChatValue.nested("assistant.resourceMatches", in: cachedState)) ?? [])
            .compactMap(BindingChatValue.object)
            .first { BindingChatValue.string($0["kind"]) == "cell_configuration" }
    }

    private func configurationForResource(_ resource: Object) -> CellConfiguration? {
        guard let configurationName = BindingChatValue.string(resource["configurationName"])
            ?? BindingChatValue.string(resource["title"]) else {
            return nil
        }
        return ConfigurationCatalogCell.stagingSurfaceTestingMenuConfigurations(
            includeAgentOperatorSurfaces: false
        ).first { $0.name == configurationName }
    }

    private func docsRAGQuery(from value: ValueType) -> String {
        let payload = BindingChatValue.object(value) ?? [:]
        return BindingChatValue.string(payload["query"])
            ?? BindingChatValue.string(payload["text"])
            ?? BindingChatValue.string(payload["prompt"])
            ?? BindingChatValue.string(value)
            ?? BindingChatValue.string(BindingChatValue.nested("docsRAG.query", in: cachedState))
            ?? BindingChatValue.string(BindingChatValue.nested("composer.body", in: cachedState))
            ?? BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState))
            ?? ""
    }

    private func docsRAGMatches(for query: String) -> (documentation: [Object], rag: [Object], summary: String) {
        let normalized = BindingChatValue.normalized(query)
        let documents = Self.defaultDocsRAGDocuments()
        let documentation = documents.filter { doc in
            let haystack = BindingChatValue.normalized(
                [
                    BindingChatValue.string(doc["title"]) ?? "",
                    BindingChatValue.string(doc["summary"]) ?? "",
                    BindingChatValue.string(doc["group"]) ?? ""
                ].joined(separator: " ")
            )
            return normalized.isEmpty
                || normalized.split(separator: " ").contains { haystack.contains($0) }
        }
        let rag: [Object] = BindingChatIntentClassifier.resourceMatches(prompt: query)
            .filter { BindingChatValue.string($0["kind"]) == "rag_case" }
        let filteredDocs = documentation.isEmpty ? documents : documentation
        let summary = rag.isEmpty
            ? "Fant \(filteredDocs.count) dokumenttreff. Ingen granted RAG-case blir spurt automatisk."
            : "Fant \(filteredDocs.count) dokumenttreff og \(rag.count) granted RAG-case. Spør RAG krever eget klikk."
        return (filteredDocs, rag, summary)
    }

    private func contextualHelpContext(from payload: Object) -> Object {
        let activeSurfaceName = contextualHelpString(
            payload,
            keys: ["activeSurfaceName", "surfaceName", "configurationName"],
            fallback: "Ukjent flate"
        )
        let surfaceDescription = contextualHelpString(
            payload,
            keys: ["surfaceDescription", "description", "purposeDescription"],
            fallback: ""
        )
        let editorMode = contextualHelpString(payload, keys: ["editorMode", "mode"], fallback: "view")
        let destination = contextualHelpString(payload, keys: ["destination", "visibleDestination"], fallback: "HAVEN")
        let sourceKind = contextualHelpString(payload, keys: ["sourceKind"], fallback: "local")
        let sourceEndpoint = contextualHelpString(payload, keys: ["sourceEndpoint", "sourceCellEndpoint"], fallback: "")
        let userContextSummary = contextualHelpString(
            payload,
            keys: ["userContextSummary", "userContext", "scopeSummary"],
            fallback: "Privat HAVEN/Personal Co-Pilot-scope."
        )
        let permissionSummary = contextualHelpString(
            payload,
            keys: ["permissionSummary", "permissionGateSummary"],
            fallback: "Ingen nye tillatelser gis av hjelpespørsmålet."
        )
        let sourceBacked = BindingChatValue.bool(payload["sourceBacked"])
            ?? BindingChatValue.bool(payload["isSourceBacked"])
            ?? false
        return [
            "schema": .string("binding.contextual-help.v0"),
            "activeSurfaceName": .string(activeSurfaceName),
            "surfaceDescription": surfaceDescription.isEmpty ? .null : .string(surfaceDescription),
            "editorMode": .string(editorMode),
            "destination": .string(destination),
            "sourceKind": .string(sourceKind),
            "sourceEndpoint": sourceEndpoint.isEmpty ? .null : .string(sourceEndpoint),
            "sourceBacked": .bool(sourceBacked),
            "userContextSummary": .string(userContextSummary),
            "permissionSummary": .string(permissionSummary),
            "ragPolicy": .string("Docs/RAG og andre kilder kan bare brukes etter eksplisitt brukerklikk og granted scope."),
            "sideEffectFree": .bool(true)
        ]
    }

    private func contextualHelpPrompt(from context: Object) -> String {
        let activeSurfaceName = BindingChatValue.string(context["activeSurfaceName"]) ?? "denne flaten"
        let surfaceDescription = BindingChatValue.string(context["surfaceDescription"]) ?? ""
        let editorMode = BindingChatValue.string(context["editorMode"]) ?? "view"
        let userContextSummary = BindingChatValue.string(context["userContextSummary"]) ?? "Privat HAVEN-scope."
        let permissionSummary = BindingChatValue.string(context["permissionSummary"]) ?? "Ingen nye tillatelser gis."
        var parts = [
            "Jeg trenger hjelp i HAVEN.",
            "Aktiv flate: \(activeSurfaceName).",
            "GUI-modus: \(editorMode)."
        ]
        if !surfaceDescription.isEmpty {
            parts.append("Hva flaten er til for: \(surfaceDescription).")
        }
        parts.append("Brukerkontekst: \(userContextSummary)")
        parts.append("Tillatelser: \(permissionSummary)")
        parts.append("Gi meg neste trygge steg i vanlig språk. Bruk docs/RAG eller andre granted kilder hvis det trengs, men ikke utfør sideeffekter uten eget klikk.")
        return parts.joined(separator: " ")
    }

    private func contextualHelpSummary(from context: Object) -> String {
        let activeSurfaceName = BindingChatValue.string(context["activeSurfaceName"]) ?? "aktiv flate"
        let editorMode = BindingChatValue.string(context["editorMode"]) ?? "view"
        return "Hjelp er klargjort for \(activeSurfaceName) i \(editorMode)-modus. Co-Pilot kan bruke GUI-kontekst, Perspective, docs og granted RAG etter eksplisitt klikk."
    }

    private func contextualHelpSources(from context: Object) -> [Object] {
        let activeSurfaceName = BindingChatValue.string(context["activeSurfaceName"]) ?? "aktiv flate"
        let sourceEndpoint = BindingChatValue.string(context["sourceEndpoint"])
        let ragSummary = sourceEndpoint.map { endpoint in
            "Kilder knyttet til \(endpoint) kan bare brukes hvis de er granted."
        } ?? "Bare RAG-cases synlige i chat-scope kan spørres."
        return [
            [
                "id": .string("gui-context"),
                "title": .string("GUI-kontekst"),
                "status": .string("staged"),
                "summary": .string("Aktiv flate, modus og brukerrettet beskrivelse for \(activeSurfaceName).")
            ],
            [
                "id": .string("perspective-context"),
                "title": .string("Perspective"),
                "status": .string("available_in_chat_scope"),
                "summary": .string("Aktive formål og interesser kan brukes til å tolke spørsmålet, men gir ikke nye grants.")
            ],
            [
                "id": .string("docs"),
                "title": .string("Dokumentasjon"),
                "status": .string("explicit_click_required"),
                "summary": .string("Docs/RAG-panelet kan finne relevante interne dokumenttreff.")
            ],
            [
                "id": .string("granted-rag"),
                "title": .string("Granted RAG"),
                "status": .string("explicit_click_required"),
                "summary": .string(ragSummary)
            ],
            [
                "id": .string("scoped-providers"),
                "title": .string("Scoped providers"),
                "status": .string("recommendation_only"),
                "summary": .string("Provider-valg er anbefaling, ikke automatisk modellkall.")
            ]
        ]
    }

    private func contextualHelpString(_ payload: Object, keys: [String], fallback: String) -> String {
        for key in keys {
            if let value = BindingChatValue.string(payload[key]) {
                return value
            }
        }
        return fallback
    }

    private func appendHelpPromptMessage(prompt: String, summary: String) {
        var messages = BindingChatValue.list(BindingChatValue.nested("ui.promptMessages", in: cachedState)) ?? []
        messages.append(.object([
            "id": .string(UUID().uuidString),
            "role": .string("assistant"),
            "speaker": .string("HAVEN Co-Pilot"),
            "body": .string(prompt),
            "statusText": .string(summary),
            "kind": .string("contextual_help"),
            "sideEffect": .bool(false),
            "rowStyleClasses": .list(["chat-prompt-row", "chat-prompt-row-assistant"].map(ValueType.string))
        ]))
        BindingChatValue.set(.list(Array(messages.suffix(40))), for: "ui.promptMessages", in: &cachedState)
    }

    nonisolated private static func defaultDocsRAGDocuments() -> [Object] {
        [
            [
                "id": .string("personal-copilot-v1-chat-assistant"),
                "title": .string("PersonalCopilotV1 Chat Assistant"),
                "summary": .string("CellScaffold-kontrakt for chat-first Co-Pilot, helperflater, provider-routing og sideeffektgrenser."),
                "group": .string("CellScaffold")
            ],
            [
                "id": .string("copilot-prompt-decomposition"),
                "title": .string("Co-Pilot Prompt Decomposition Strategy"),
                "summary": .string("Kompakt PromptUnderstandingFrame med formål, interesser, kunnskapsbehov og anbefalt neste steg."),
                "group": .string("PromptPurposeLab")
            ],
            [
                "id": .string("purpose-context-pack"),
                "title": .string("Purpose Context Pack"),
                "summary": .string("Kompakt purpose.context.pack med progressive hydration og brukerrettet response guidance."),
                "group": .string("CellProtocolDocuments")
            ]
        ]
    }

    private func setComposer(_ value: ValueType) -> ValueType {
        let body: String
        if let object = BindingChatValue.object(value) {
            body = BindingChatValue.string(object["body"]) ?? BindingChatValue.string(object["text"]) ?? ""
        } else {
            body = text(from: value)
        }
        BindingChatValue.set(.string(body), for: "composer.body", in: &cachedState)
        BindingChatValue.set(.string(body), for: "currentThread.composer.body", in: &cachedState)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)
        return response(status: "ok", message: "Composer draft updated.")
    }

    private func sendComposedMessage() -> ValueType {
        let body = BindingChatValue.string(BindingChatValue.nested("composer.body", in: cachedState))
            ?? BindingChatValue.string(BindingChatValue.nested("currentThread.composer.body", in: cachedState))
            ?? ""
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return response(status: "blocked", message: "Write a message before sending.")
        }
        guard BindingChatValue.string(BindingChatValue.nested("inviteStatus", in: cachedState)) == "accepted" else {
            return response(status: "blocked", message: "Invite-only chat requires an accepted invitation before sending.")
        }
        guard (BindingChatValue.list(BindingChatValue.nested("blockedUsers", in: cachedState)) ?? []).isEmpty else {
            return response(status: "blocked", message: "Blocked chat participants cannot continue in this thread.")
        }
        let sentAt = Date().timeIntervalSince1970
        let threadID = BindingChatValue.string(BindingChatValue.nested("currentThread.id", in: cachedState)) ?? "local-copilot-thread"
        let threadTitle = BindingChatValue.string(BindingChatValue.nested("currentThread.title", in: cachedState)) ?? "Co-Pilot"
        var messages = BindingChatValue.list(BindingChatValue.nested("messages", in: cachedState)) ?? []
        messages.append(.object([
            "id": .string(UUID().uuidString),
            "threadID": .string(threadID),
            "threadTitle": .string(threadTitle),
            "authorDisplayName": .string("Deg"),
            "body": .string(body),
            "sentAt": .float(sentAt),
            "statusText": .string("Sendt lokalt"),
            "kind": .string("chat_message")
        ]))
        BindingChatValue.set(.list(messages), for: "messages", in: &cachedState)
        BindingChatValue.set(.integer(messages.count), for: "messageCount", in: &cachedState)
        let threadMessageCount = messages.filter {
            BindingChatValue.string(BindingChatValue.object($0)?["threadID"]) == threadID
        }.count
        upsertCurrentThread(
            id: threadID,
            title: threadTitle,
            lastMessagePreview: body,
            messageCount: threadMessageCount,
            updatedAt: sentAt
        )
        BindingChatValue.set(.string(""), for: "currentThread.composer.body", in: &cachedState)
        BindingChatValue.set(.string(""), for: "composer.body", in: &cachedState)
        return response(status: "ok", message: "Message sent locally.")
    }

    private func upsertCurrentThread(
        id: String,
        title: String,
        lastMessagePreview: String,
        messageCount: Int,
        updatedAt: TimeInterval
    ) {
        let preview = String(lastMessagePreview.trimmingCharacters(in: .whitespacesAndNewlines).prefix(140))
        let statusText = messageCount == 1 ? "1 melding" : "\(messageCount) meldinger"
        let threadPatch: Object = [
            "id": .string(id),
            "title": .string(title),
            "kind": .string("copilot_chat"),
            "lastMessagePreview": .string(preview),
            "messageCount": .integer(messageCount),
            "statusText": .string(statusText),
            "updatedAt": .float(updatedAt)
        ]
        var threads = BindingChatValue.list(BindingChatValue.nested("threads", in: cachedState)) ?? []
        var replacedExistingThread = false
        threads = threads.map { item in
            guard var thread = BindingChatValue.object(item),
                  BindingChatValue.string(thread["id"]) == id else {
                return item
            }
            for (key, value) in threadPatch {
                thread[key] = value
            }
            replacedExistingThread = true
            return .object(thread)
        }
        if replacedExistingThread == false {
            threads.append(.object(threadPatch))
        }
        var currentThread = BindingChatValue.object(BindingChatValue.nested("currentThread", in: cachedState)) ?? [:]
        for (key, value) in threadPatch {
            currentThread[key] = value
        }
        if currentThread["composer"] == nil {
            currentThread["composer"] = .object([
                "body": .string(""),
                "contentType": .string("text/plain")
            ])
        }
        BindingChatValue.set(.list(threads), for: "threads", in: &cachedState)
        BindingChatValue.set(.integer(threads.count), for: "threadCount", in: &cachedState)
        BindingChatValue.set(.object(currentThread), for: "currentThread", in: &cachedState)
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

    private func createInvite(value: ValueType, requester: Identity) async -> ValueType {
        let submitted = BindingChatValue.object(value) ?? [:]
        var draft = BindingChatValue.object(BindingChatValue.nested("inviteDraft", in: cachedState)) ?? [:]
        for key in ["title", "profileID", "userUUID"] {
            if let submittedValue = submitted[key] {
                draft[key] = submittedValue
            }
        }
        if let submittedEndpoint = normalizedContactEndpoint(from: submitted) {
            draft["contactEndpoint"] = .object(submittedEndpoint)
        }
        BindingChatValue.set(.object(draft), for: "inviteDraft", in: &cachedState)

        var invites = BindingChatValue.list(BindingChatValue.nested("invites", in: cachedState)) ?? []
        let inviteID = UUID().uuidString.lowercased()
        let title = BindingChatValue.string(draft["title"])?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "Ny invitasjon"
        let profileID = BindingChatValue.string(draft["profileID"]) ?? ""
        let userUUID = BindingChatValue.string(draft["userUUID"]) ?? ""
        let contactEndpoint = BindingChatValue.object(draft["contactEndpoint"])
        var invite: Object = [
            "id": .string(inviteID),
            "title": .string(title),
            "profileID": .string(profileID),
            "userUUID": .string(userUUID),
            "status": .string("draft"),
            "contactDeliveryStatus": .string("not_attempted"),
            "createdAt": .float(Date().timeIntervalSince1970)
        ]
        invite["contactEndpoint"] = contactEndpoint.map(ValueType.object) ?? .null

        let delivery: Object
        if let contactEndpoint {
            delivery = await deliverInvite(
                inviteID: inviteID,
                title: title,
                profileID: profileID,
                contactEndpoint: contactEndpoint,
                requester: requester
            )
        } else {
            let bootstrapDraft = makeBootstrapDraft(
                inviteID: inviteID,
                title: title,
                profileID: profileID,
                requester: requester
            )
            delivery = [
                "ok": .bool(false),
                "status": .string("bootstrap_required"),
                "contactDeliveryStatus": .string("missing_contact_endpoint"),
                "message": .string("Et lokalt bootstrap-utkast er klargjort, men ingenting er sendt. Mottakeren må først opprette et HAVEN-kontaktendepunkt."),
                "bootstrapDraft": .object(bootstrapDraft)
            ]
        }

        let status = BindingChatValue.string(delivery["status"]) ?? "delivery_failed"
        let contactDeliveryStatus = BindingChatValue.string(delivery["contactDeliveryStatus"]) ?? "delivery_failed"
        let message = BindingChatValue.string(delivery["message"])
            ?? "Invitasjonen ble ikke levert. Kontaktendepunktet svarte ikke eller avviste forespørselen."
        invite["status"] = .string(status)
        invite["contactDeliveryStatus"] = .string(contactDeliveryStatus)
        invite["deliverySummary"] = .string(message)
        invite["ticketID"] = delivery["ticketID"] ?? .null
        invite["deliveryFailureReason"] = delivery["deliveryFailureReason"] ?? .null
        invite["bootstrapDraft"] = delivery["bootstrapDraft"] ?? .null
        invite["updatedAt"] = .float(Date().timeIntervalSince1970)
        invites.append(.object(invite))
        BindingChatValue.set(.list(invites), for: "invites", in: &cachedState)
        BindingChatValue.set(.string(status), for: "inviteStatus", in: &cachedState)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)

        var response: Object = [
            "ok": delivery["ok"] ?? .bool(false),
            "status": .string(status),
            "message": .string(message),
            "userMessage": .string(message),
            "sideEffect": .bool(true),
            "contactDeliveryStatus": .string(contactDeliveryStatus),
            "invite": .object(invite),
            "state": .object(cachedState)
        ]
        response["ticketID"] = delivery["ticketID"] ?? .null
        response["ticket"] = delivery["ticket"] ?? .null
        response["deliveryFailureReason"] = delivery["deliveryFailureReason"] ?? .null
        response["bootstrapDraft"] = delivery["bootstrapDraft"] ?? .null
        return .object(response)
    }

    private func makeBootstrapDraft(
        inviteID: String,
        title: String,
        profileID: String,
        requester: Identity
    ) -> Object {
        let now = Date()
        return [
            "schema": .string("haven.contact.bootstrap-draft.v1"),
            "bootstrapID": .string("bootstrap-\(UUID().uuidString.lowercased())"),
            "inviteID": .string(inviteID),
            "title": .string(title),
            "profileID": profileID.isEmpty ? .null : .string(profileID),
            "senderDisplayName": .string(requester.displayName),
            "purpose": .string("purpose://contact.introduction"),
            "createdAt": .float(now.timeIntervalSince1970),
            "expiresAt": .float(now.addingTimeInterval(7 * 24 * 60 * 60).timeIntervalSince1970),
            "deliveryState": .string("not_sent"),
            "authority": .bool(false),
            "requiresRecipientEnrollment": .bool(true),
            "requiresFreshSignedContactRequest": .bool(true),
            "handoffText": .string("Du er invitert til en privat HAVEN-samtale. Opprett eller åpne HAVEN, publiser et kontaktendepunkt og del bare den offentlige kontaktbeskrivelsen tilbake.")
        ]
    }

    private func refreshContactInbox(value: ValueType, requester: Identity) async -> ValueType {
        let submitted = BindingChatValue.object(value) ?? [:]
        let endpointCell = BindingChatValue.string(submitted["endpointCell"])
            ?? BindingChatValue.string(BindingChatValue.nested("contactInbox.endpointCell", in: cachedState))
            ?? BindingContactEndpointContracts.endpoint
        BindingChatValue.set(.string(endpointCell), for: "contactInbox.endpointCell", in: &cachedState)

        guard let resolver = CellBase.defaultCellResolver else {
            return response(status: "blocked", message: "Kontaktinnboksen er ikke tilgjengelig fordi HAVEN-rutingen mangler.")
        }
        do {
            guard let contactCell = try await resolver.cellAtEndpoint(
                endpoint: endpointCell,
                requester: requester
            ) as? Meddle else {
                return response(status: "blocked", message: "Kontaktinnboksen kan ikke åpnes i denne HAVEN-installasjonen.")
            }
            let privateState = try await contactCell.get(keypath: "privateState", requester: requester)
            guard let state = BindingChatValue.object(privateState) else {
                return response(status: "blocked", message: "Kontaktinnboksen svarte uten lesbar tilstand.")
            }
            let incomingInvites = (BindingChatValue.list(state["tickets"]) ?? []).compactMap(incomingInviteRow)
            let actionableStatuses = Set(["pending", "resolved"])
            let pendingCount = incomingInvites.filter {
                actionableStatuses.contains(BindingChatValue.string($0["status"]) ?? "")
            }.count
            let previousSelection = BindingChatValue.string(
                BindingChatValue.nested("contactInbox.selectedTicketID", in: cachedState)
            )
            let selectedTicketID = previousSelection.flatMap { selected in
                incomingInvites.contains { BindingChatValue.string($0["ticketID"]) == selected } ? selected : nil
            } ?? incomingInvites.first(where: {
                actionableStatuses.contains(BindingChatValue.string($0["status"]) ?? "")
            }).flatMap { BindingChatValue.string($0["ticketID"]) }
            let message = pendingCount == 0
                ? "Ingen nye kontaktinvitasjoner venter på svar."
                : "\(pendingCount) kontaktinvitasjon venter på et eksplisitt svar."
            let inbox: Object = [
                "status": .string("ready"),
                "message": .string(message),
                "endpointCell": .string(endpointCell),
                "pendingCount": .integer(pendingCount),
                "selectedTicketID": selectedTicketID.map(ValueType.string) ?? .null,
                "incomingInvites": .list(incomingInvites.map(ValueType.object)),
                "updatedAt": .float(Date().timeIntervalSince1970)
            ]
            BindingChatValue.set(.object(inbox), for: "contactInbox", in: &cachedState)
            cachedState["status"] = .string(message)
            cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)
            return .object([
                "ok": .bool(true),
                "status": .string("ready"),
                "message": .string(message),
                "userMessage": .string(message),
                "sideEffect": .bool(false),
                "contactInbox": .object(inbox),
                "state": .object(cachedState)
            ])
        } catch {
            return response(status: "blocked", message: "Kontaktinnboksen er midlertidig utilgjengelig.")
        }
    }

    private func incomingInviteRow(_ value: ValueType) -> Object? {
        guard let ticket = BindingChatValue.object(value),
              let ticketID = BindingChatValue.string(ticket["ticketId"]),
              BindingChatValue.string(ticket["requestTopic"]) == "contact.request",
              let requestPayload = BindingChatValue.object(ticket["requestPayload"]),
              let intro = BindingChatValue.object(requestPayload["payload"]),
              BindingChatValue.string(intro["introKind"]) == "chat.invitation" else {
            return nil
        }
        let status = BindingChatValue.string(ticket["status"]) ?? "pending"
        let sender = BindingChatValue.string(requestPayload["requesterDisplayName"]) ?? "En HAVEN-kontakt"
        let title = BindingChatValue.string(intro["introTitle"]) ?? "Privat chatinvitasjon"
        var row: Object = [
            "id": .string(ticketID),
            "ticketID": .string(ticketID),
            "inviteID": intro["introInviteID"] ?? .null,
            "title": .string(title),
            "senderDisplayName": .string(sender),
            "status": .string(status),
            "statusSummary": .string(incomingInviteSummary(status: status, sender: sender)),
            "createdAt": ticket["createdAt"] ?? .null,
            "expiresAt": ticket["expiresAt"] ?? .null
        ]
        row["result"] = ticket["result"] ?? .null
        return row
    }

    private func incomingInviteSummary(status: String, sender: String) -> String {
        switch status {
        case "resolved": return "Invitasjonen fra \(sender) er åpnet og venter på svaret ditt."
        case "accepted": return "Du har godtatt invitasjonen fra \(sender)."
        case "declined": return "Du har avslått invitasjonen fra \(sender)."
        case "blocked": return "Invitasjonen fra \(sender) er blokkert."
        case "expired": return "Invitasjonen fra \(sender) har utløpt."
        case "failed": return "Svaret på invitasjonen fra \(sender) kunne ikke fullføres."
        default: return "Ny privat chatinvitasjon fra \(sender)."
        }
    }

    private func selectIncomingInvite(_ value: ValueType) -> ValueType {
        guard let ticketID = selectedTicketID(from: value) else {
            return response(status: "blocked", message: "Velg en kontaktinvitasjon først.")
        }
        BindingChatValue.set(.string(ticketID), for: "contactInbox.selectedTicketID", in: &cachedState)
        return response(status: "ok", message: "Kontaktinvitasjonen er valgt.")
    }

    private func selectedTicketID(from value: ValueType) -> String? {
        if let direct = BindingChatValue.string(value) { return direct }
        guard let object = BindingChatValue.object(value) else { return nil }
        if let direct = BindingChatValue.string(object["ticketID"])
            ?? BindingChatValue.string(object["ticketId"])
            ?? BindingChatValue.string(object["selected"]) {
            return direct
        }
        if let selected = BindingChatValue.object(object["selected"]) {
            return BindingChatValue.string(selected["ticketID"])
                ?? BindingChatValue.string(selected["ticketId"])
                ?? BindingChatValue.string(selected["id"])
        }
        return nil
    }

    private func shouldUseLegacyLocalInviteGate(_ value: ValueType) -> Bool {
        guard selectedTicketID(from: value) == nil,
              BindingChatValue.string(BindingChatValue.nested("contactInbox.selectedTicketID", in: cachedState)) == nil else {
            return false
        }
        return BindingChatValue.string(BindingChatValue.nested("contactInbox.status", in: cachedState)) == "not_loaded"
    }

    private func respondToIncomingInvite(value: ValueType, status: String, requester: Identity) async -> ValueType {
        let actionableStatuses = Set(["pending", "resolved"])
        var ticketID = selectedTicketID(from: value)
            ?? BindingChatValue.string(BindingChatValue.nested("contactInbox.selectedTicketID", in: cachedState))
        if ticketID == nil {
            _ = await refreshContactInbox(value: .object([:]), requester: requester)
            ticketID = BindingChatValue.string(BindingChatValue.nested("contactInbox.selectedTicketID", in: cachedState))
        }
        guard let ticketID else {
            return response(status: "blocked", message: "Ingen kontaktinvitasjon venter på svar.")
        }
        let incoming = BindingChatValue.list(BindingChatValue.nested("contactInbox.incomingInvites", in: cachedState)) ?? []
        guard let selectedInvite = incoming.compactMap(BindingChatValue.object).first(where: {
            BindingChatValue.string($0["ticketID"]) == ticketID
        }), actionableStatuses.contains(BindingChatValue.string(selectedInvite["status"]) ?? "") else {
            return response(status: "blocked", message: "Den valgte kontaktinvitasjonen kan ikke besvares på nytt.")
        }
        guard let resolver = CellBase.defaultCellResolver else {
            return response(status: "blocked", message: "Svaret kunne ikke sendes fordi HAVEN-rutingen mangler.")
        }
        let endpointCell = BindingChatValue.string(BindingChatValue.nested("contactInbox.endpointCell", in: cachedState))
            ?? BindingContactEndpointContracts.endpoint
        let userMessage = status == "accepted"
            ? "Invitasjonen er godtatt. Avsenderen kan nå hente svaret fra kontaktendepunktet."
            : "Invitasjonen er avslått. Avsenderen kan nå hente svaret fra kontaktendepunktet."
        do {
            guard let contactCell = try await resolver.cellAtEndpoint(
                endpoint: endpointCell,
                requester: requester
            ) as? Meddle,
                  let responseValue = try await contactCell.set(
                    keypath: "ticket.respond",
                    value: .object([
                        "ticketId": .string(ticketID),
                        "status": .string(status),
                        "result": .object([
                            "schema": .string("haven.contact.invite-response.v1"),
                            "recipientDisplayName": .string(requester.displayName),
                            "message": .string(status == "accepted" ? "Invitasjonen er godtatt." : "Invitasjonen er avslått."),
                            "respondedAt": .float(Date().timeIntervalSince1970)
                        ])
                    ]),
                    requester: requester
                  ),
                  let responseObject = BindingChatValue.object(responseValue),
                  BindingChatValue.string(responseObject["status"]) == status else {
                return response(status: "blocked", message: "Kontaktendepunktet bekreftet ikke svaret.")
            }
            _ = await refreshContactInbox(value: .object(["endpointCell": .string(endpointCell)]), requester: requester)
            BindingChatValue.set(.string(status), for: "inviteStatus", in: &cachedState)
            cachedState["status"] = .string(userMessage)
            return .object([
                "ok": .bool(true),
                "status": .string(status),
                "message": .string(userMessage),
                "userMessage": .string(userMessage),
                "sideEffect": .bool(true),
                "ticket": .object(responseObject),
                "state": .object(cachedState)
            ])
        } catch {
            return response(status: "blocked", message: "Svaret kunne ikke leveres til kontaktendepunktet.")
        }
    }

    private func refreshOutgoingInviteStatuses(value: ValueType, requester: Identity) async -> ValueType {
        let requestedInviteID = BindingChatValue.string(BindingChatValue.object(value)?["inviteID"])
            ?? BindingChatValue.string(BindingChatValue.object(value)?["id"])
            ?? BindingChatValue.string(value)
        let currentInvites = BindingChatValue.list(BindingChatValue.nested("invites", in: cachedState)) ?? []
        var refreshedCount = 0
        var updatedInvites: [ValueType] = []
        for value in currentInvites {
            guard let invite = BindingChatValue.object(value) else {
                updatedInvites.append(value)
                continue
            }
            if let requestedInviteID, BindingChatValue.string(invite["id"]) != requestedInviteID {
                updatedInvites.append(value)
                continue
            }
            let refreshed = await refreshedOutgoingInvite(invite, requester: requester)
            if refreshed != invite { refreshedCount += 1 }
            updatedInvites.append(.object(refreshed))
        }
        BindingChatValue.set(.list(updatedInvites), for: "invites", in: &cachedState)
        if let latestStatus = updatedInvites.compactMap(BindingChatValue.object).last.flatMap({ BindingChatValue.string($0["status"]) }) {
            BindingChatValue.set(.string(latestStatus), for: "inviteStatus", in: &cachedState)
        }
        let message = refreshedCount == 0
            ? "Ingen leverte invitasjoner hadde et nytt svar."
            : "Invitasjonsstatus er oppdatert fra mottakerens kontaktendepunkt."
        cachedState["status"] = .string(message)
        cachedState["updatedAt"] = .float(Date().timeIntervalSince1970)
        return .object([
            "ok": .bool(true),
            "status": .string("ok"),
            "message": .string(message),
            "userMessage": .string(message),
            "sideEffect": .bool(false),
            "refreshedCount": .integer(refreshedCount),
            "state": .object(cachedState)
        ])
    }

    private func refreshedOutgoingInvite(_ invite: Object, requester: Identity) async -> Object {
        let terminalStatuses = Set(["accepted", "declined", "blocked", "failed", "expired"])
        guard terminalStatuses.contains(BindingChatValue.string(invite["status"]) ?? "") == false,
              let ticketID = BindingChatValue.string(invite["ticketID"]),
              let contactEndpoint = BindingChatValue.object(invite["contactEndpoint"]),
              let endpointCell = BindingChatValue.string(contactEndpoint["cell"])
                ?? BindingChatValue.string(contactEndpoint["endpointCell"]),
              let resolver = CellBase.defaultCellResolver else {
            return invite
        }
        do {
            guard let contactCell = try await resolver.cellAtEndpoint(
                endpoint: endpointCell,
                requester: requester
            ) as? Meddle,
                  let ticketValue = try await contactCell.set(
                    keypath: "ticket.status",
                    value: .object(["ticketId": .string(ticketID)]),
                    requester: requester
                  ),
                  let ticket = BindingChatValue.object(ticketValue),
                  let remoteStatus = BindingChatValue.string(ticket["status"]),
                  ["pending", "resolved", "accepted", "declined", "blocked", "failed", "expired"].contains(remoteStatus) else {
                return invite
            }
            var updated = invite
            let mapped = outgoingInvitePresentation(for: remoteStatus)
            updated["status"] = .string(mapped.status)
            updated["contactDeliveryStatus"] = .string(mapped.deliveryStatus)
            updated["deliverySummary"] = .string(mapped.summary)
            updated["remoteTicketStatus"] = .string(remoteStatus)
            updated["response"] = ticket["result"] ?? .null
            updated["updatedAt"] = .float(Date().timeIntervalSince1970)
            return updated
        } catch {
            return invite
        }
    }

    private func outgoingInvitePresentation(for remoteStatus: String) -> (status: String, deliveryStatus: String, summary: String) {
        switch remoteStatus {
        case "resolved":
            return ("seen", "delivered", "Mottakeren har åpnet invitasjonen og vurderer den.")
        case "accepted":
            return ("accepted", "responded", "Mottakeren har godtatt invitasjonen.")
        case "declined":
            return ("declined", "responded", "Mottakeren har avslått invitasjonen.")
        case "blocked":
            return ("blocked", "responded", "Mottakeren har blokkert kontaktforespørselen.")
        case "failed":
            return ("failed", "responded", "Mottakeren kunne ikke fullføre svaret på invitasjonen.")
        case "expired":
            return ("expired", "expired", "Invitasjonen utløp før mottakeren svarte.")
        default:
            return ("delivered", "delivered", "Kontaktforespørselen er levert og venter på mottakerens svar.")
        }
    }

    private func deliverInvite(
        inviteID: String,
        title: String,
        profileID: String,
        contactEndpoint: Object,
        requester: Identity
    ) async -> Object {
        guard let endpointID = BindingChatValue.string(contactEndpoint["endpointID"])
                ?? BindingChatValue.string(contactEndpoint["endpointId"]),
              endpointID.isEmpty == false,
              let endpointCell = BindingChatValue.string(contactEndpoint["cell"])
                ?? BindingChatValue.string(contactEndpoint["endpointCell"]),
              endpointCell.isEmpty == false else {
            return inviteDeliveryFailure(
                reason: "invalid_contact_endpoint",
                message: "Invitasjonen ble ikke levert fordi kontaktbeskrivelsen er ufullstendig."
            )
        }
        guard let resolver = CellBase.defaultCellResolver else {
            return inviteDeliveryFailure(
                reason: "resolver_unavailable",
                message: "Invitasjonen ble ikke levert fordi HAVEN-rutingen ikke er tilgjengelig."
            )
        }

        let endpointPolicy = BindingChatValue.object(contactEndpoint["policy"]) ?? [:]
        let domainPolicyIsActive = BindingChatValue.stringList(endpointPolicy["allowedDomains"]).isEmpty == false
            || BindingChatValue.stringList(endpointPolicy["blockedDomains"]).isEmpty == false
        let domainBinding = await canonicalDomainBinding(for: requester)
        if domainPolicyIsActive, domainBinding == nil {
            return inviteDeliveryFailure(
                reason: "identity_domain_binding_unavailable",
                message: "Invitasjonen ble ikke levert fordi den aktive identiteten mangler en entydig, vault-bekreftet domenebinding."
            )
        }

        let now = Date()
        var request: Object = [
            "schema": .string(BindingContactEndpointContracts.requestSchema),
            "endpointId": .string(endpointID),
            "nonce": .string(UUID().uuidString.lowercased()),
            "issuedAt": .float(now.timeIntervalSince1970),
            "expiresAt": .float(now.addingTimeInterval(5 * 60).timeIntervalSince1970),
            "requesterIdentity": .identity(requester),
            "topic": .string("contact.request"),
            "purpose": .string("purpose://contact.introduction"),
            "requestedAction": .string("contact.request.submit"),
            "payload": .object([
                "introKind": .string("chat.invitation"),
                "introInviteID": .string(inviteID),
                "introTitle": .string(title),
                "introProfileID": .string(profileID),
                "introThreadID": BindingChatValue.nested("currentThread.id", in: cachedState) ?? .string("local-copilot-thread")
            ])
        ]
        if let domainBinding {
            request["requesterDomain"] = .string(domainBinding.domain)
            request["requesterDomainBinding"] = .object(domainBinding.objectValue)
        }

        do {
            let canonical = try FlowCanonicalEncoder.canonicalData(for: .object(request))
            guard let signature = try await requester.sign(data: canonical) else {
                return inviteDeliveryFailure(
                    reason: "signing_unavailable",
                    message: "Invitasjonen ble ikke levert fordi den aktive identiteten ikke kunne signere forespørselen."
                )
            }
            request["signature"] = .data(signature)

            guard let contactCell = try await resolver.cellAtEndpoint(
                endpoint: endpointCell,
                requester: requester
            ) as? Meddle else {
                return inviteDeliveryFailure(
                    reason: "contact_endpoint_not_writable",
                    message: "Invitasjonen ble ikke levert fordi kontaktendepunktet ikke kan motta forespørsler."
                )
            }
            guard let result = try await contactCell.set(
                keypath: "contact.request",
                value: .object(request),
                requester: requester
            ), let ticket = BindingChatValue.object(result) else {
                return inviteDeliveryFailure(
                    reason: "empty_contact_response",
                    message: "Invitasjonen ble ikke levert fordi kontaktendepunktet ikke ga en kvittering."
                )
            }
            guard let ticketID = BindingChatValue.string(ticket["ticketId"])
                    ?? BindingChatValue.string(ticket["ticketID"]),
                  ticketID.isEmpty == false else {
                let reason = BindingChatValue.string(ticket["reason"])
                    ?? BindingChatValue.string(ticket["code"])
                    ?? BindingChatValue.string(ticket["status"])
                    ?? "endpoint_rejected"
                return inviteDeliveryFailure(
                    reason: reason,
                    message: "Invitasjonen ble ikke levert fordi kontaktendepunktet avviste forespørselen."
                )
            }
            return [
                "ok": .bool(true),
                "status": .string("delivered"),
                "contactDeliveryStatus": .string("delivered"),
                "ticketID": .string(ticketID),
                "ticket": .object(ticket),
                "message": .string("Kontaktforespørselen er levert til mottakerens HAVEN-endepunkt og venter på svar.")
            ]
        } catch {
            return inviteDeliveryFailure(
                reason: "contact_endpoint_unavailable",
                message: "Invitasjonen ble ikke levert fordi kontaktendepunktet ikke er tilgjengelig."
            )
        }
    }

    private func canonicalDomainBinding(for requester: Identity) async -> IdentityDomainBinding? {
        if let identityVault = requester.identityVault,
           let binding = await identityVault.identityDomainBinding(for: requester) {
            return binding
        }
        if let defaultVault = CellBase.defaultIdentityVault,
           let binding = await defaultVault.identityDomainBinding(for: requester) {
            return binding
        }
        return nil
    }

    private func inviteDeliveryFailure(reason: String, message: String) -> Object {
        [
            "ok": .bool(false),
            "status": .string("delivery_failed"),
            "contactDeliveryStatus": .string("delivery_failed"),
            "deliveryFailureReason": .string(reason),
            "message": .string(message)
        ]
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
        return .object([
            "status": .string("ok"),
            "message": .string("Poll created after explicit confirmation."),
            "userMessage": .string("Poll created after explicit confirmation."),
            "sideEffect": .bool(true),
            "state": .object(cachedState)
        ])
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
        return .object([
            "status": .string("ok"),
            "message": .string("Workbench module created after explicit confirmation."),
            "userMessage": .string("Workbench module created after explicit confirmation."),
            "sideEffect": .bool(true),
            "state": .object(cachedState)
        ])
    }

    private func submitCapabilityRequest(_ value: ValueType) -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        var draft = BindingChatValue.object(BindingChatValue.nested("workbench.capabilityRequestDraft", in: cachedState)) ?? [:]
        for field in ["title", "summary", "destination", "category"] {
            if let fieldValue = BindingChatValue.string(payload[field]) {
                draft[field] = .string(fieldValue)
            }
        }
        let title = BindingChatValue.string(draft["title"]) ?? "Nytt behov fra Co-Pilot"
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
        case "workItem.capture", "work-item", "work_item":
            return "work-item"
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
        case "mermaid-diagram":
            return "mermaid-diagram"
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
            "summary": .string("Apnet fra Co-Pilot. Handling skjer bare etter eksplisitt brukerklikk."),
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
        case "work-item": return "Feil / work item"
        case "docs-rag": return "Spør docs/RAG"
        case "todo": return "Oppgave"
        case "project": return "Prosjekt"
        case "reminder": return "Paaminnelse"
        case "meeting": return "Mote"
        case "onboarding": return "Onboarding"
        case "voice-input": return "Tale til tekst"
        case "agent-review": return "Agent-review"
        case "agent-setup": return "Agent-oppsett"
        case "advisor-report": return "Rådgiver-rapport"
        case "spatial-map": return "Kart"
        case "capability-request": return "Meld behov"
        case "contact-endpoint": return "Kontakt-endepunkt"
        case "mermaid-diagram": return "Mermaid diagram"
        case "resource-router": return "Finn verktøy"
        default: return "Hjelper"
        }
    }

    nonisolated private static let defaultPrimaryActionHint = "Trykk hovedknappen for at Co-Pilot skal lese bare dette utkastet og foreslå neste trygge steg. Ingenting sendes eller lagres."

    private func primaryActionHint(for suggestion: BindingChatIntentClassification) -> String {
        guard suggestion.shouldSuggest else {
            return "Jeg fant ikke en trygg hjelper ennå. Skriv litt mer, eller åpne Mer for verktøy og avanserte valg."
        }
        return "Trykk hovedknappen for å åpne \(helperTitle(suggestion.helperID)) som privat hjelper. Lagre, sende eller opprette skjer først etter et eget klikk der."
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

    nonisolated private static func initialHelpState() -> Object {
        [
            "status": .string("idle"),
            "summary": .string("Trykk hjelp fra en flate for aa legge GUI-kontekst inn i Co-Pilot Chat."),
            "question": .string(""),
            "suggestedPrompt": .string(""),
            "context": .object([
                "schema": .string("binding.contextual-help.v0"),
                "activeSurfaceName": .string("Ingen flate valgt"),
                "editorMode": .string("view"),
                "userContextSummary": .string("Privat HAVEN/Personal Co-Pilot-scope."),
                "ragPolicy": .string("Docs/RAG og andre kilder krever eksplisitt brukerklikk og granted scope."),
                "sideEffectFree": .bool(true)
            ]),
            "availableSources": .list([
                .object([
                    "id": .string("gui-context"),
                    "title": .string("GUI-kontekst"),
                    "status": .string("waiting_for_help_button")
                ]),
                .object([
                    "id": .string("docs"),
                    "title": .string("Dokumentasjon"),
                    "status": .string("explicit_click_required")
                ]),
                .object([
                    "id": .string("granted-rag"),
                    "title": .string("Granted RAG"),
                    "status": .string("explicit_click_required")
                ])
            ])
        ]
    }

    nonisolated static func initialState() -> Object {
        return [
            "title": .string("Co-Pilot"),
            "status": .string("Co-Pilot is ready."),
            "threadCount": .integer(0),
            "messageCount": .integer(0),
            "inviteStatus": .string("not invited"),
            "blockedUsers": .list([]),
            "moderationStatus": .string("ready"),
            "currentThread": .object([
                "id": .string("local-copilot-thread"),
                "title": .string("Co-Pilot"),
                "composer": .object([
                    "body": .string(""),
                    "contentType": .string("text/plain")
                ])
            ]),
            "composer": .object([
                "body": .string(""),
                "contentType": .string("text/plain")
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
            "contactInbox": .object([
                "status": .string("not_loaded"),
                "message": .string("Kontaktinnboksen er ikke hentet ennå."),
                "endpointCell": .string(BindingContactEndpointContracts.endpoint),
                "pendingCount": .integer(0),
                "selectedTicketID": .null,
                "incomingInvites": .list([])
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
                "workItemDraft": .object([
                    "title": .string(""),
                    "summary": .string(""),
                    "kind": .string("bug"),
                    "project": .string(""),
                    "repo": .string("Binding"),
                    "cell": .string("cell:///PersonalChatHub"),
                    "surface": .string("Co-Pilot"),
                    "severity": .string("medium"),
                    "priority": .string("normal"),
                    "currentBehavior": .string(""),
                    "expectedBehavior": .string(""),
                    "nextAction": .string(""),
                    "doneWhen": .string("")
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
            "docsRAG": .object([
                "query": .string(""),
                "summary": .string("Ingen docs/RAG-spørring ennå."),
                "documentationMatches": .list(Self.defaultDocsRAGDocuments().map(ValueType.object)),
                "documentationMatchCount": .integer(Self.defaultDocsRAGDocuments().count),
                "ragMatches": .list([]),
                "ragMatchCount": .integer(0),
                "answer": .string(""),
                "availableDocuments": .list(Self.defaultDocsRAGDocuments().map(ValueType.object)),
                "selectedDocument": .null
            ]),
            "help": .object(Self.initialHelpState()),
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
                "activeHelper": .string(""),
                "activeHelpers": .list([]),
                "activeHelperSummary": .string(""),
                "hasActionableSuggestion": .bool(false),
                "primaryActionHint": .string(Self.defaultPrimaryActionHint),
                "hasActiveHelperSurface": .bool(false),
                "activeComponentSurfaceID": .string(""),
                "combinedChatView": .bool(true),
                "showAdvanced": .bool(false),
                "learningStatus": .string("paused"),
                "capabilityDiscoveryEnabled": .bool(false),
                "capabilityDiscoveryStatus": .string("off"),
                "humanPresenceSummary": .string("Privat forslag forst; menneskechat oppdateres bare naar du sender eller inviterer."),
                "promptOnlyReason": .string("Co-piloten leser bare ditt aktive utkast naar du trykker hovedknappen."),
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
                    .object(["id": .string("resource-router"), "title": .string("Finn verktøy")]),
                    .object(["id": .string("mermaid-diagram"), "title": .string("Mermaid")]),
                    .object(["id": .string("docs-rag"), "title": .string("Docs/RAG")]),
                    .object(["id": .string("idea-capture"), "title": .string("Fang ide")]),
                    .object(["id": .string("work-item"), "title": .string("Work item")]),
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
                "pinnedComponentSurfaces": .list([]),
                "hasPinnedComponentSurfaces": .bool(false),
                "absorbedChats": .list([]),
                "promptMessages": .list([
                    .object([
                        "id": .string("welcome"),
                        "role": .string("assistant"),
                        "speaker": .string("HAVEN Co-Pilot"),
                        "body": .string("Hva vil du få gjort? Skriv én prompt, så finner jeg forslag uten å utføre sideeffekter."),
                        "statusText": .string("Klar"),
                        "kind": .string("assistant_welcome"),
                        "sideEffect": .bool(false),
                        "rowStyleClasses": .list(["chat-prompt-row", "chat-prompt-row-assistant"].map(ValueType.string))
                    ])
                ]),
                "promptParticipants": .list([
                    .object([
                        "badge": .string("Privat"),
                        "title": .string("Ditt utkast"),
                        "summary": .string("Leses bare når du trykker hovedknappen.")
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
                "whySummary": .string("Skriv et utkast og trykk hovedknappen."),
                "assistantProviders": .list([.object(BindingChatProviderRouter.localRulesProvider().objectValue())]),
                "providerRecommendation": .object(BindingChatProviderRouter.localRulesProvider().objectValue()),
                "providerCount": .integer(1),
                "resourceMatches": .list([]),
                "resourceMatchCount": .integer(0),
                "promptUnderstanding": .object([
                    "schema": .string("binding.prompt-understanding.v0"),
                    "speechAct": .string("none"),
                    "polarity": .string("neutral"),
                    "knowledgeNeed": .bool(false),
                    "resourceNeed": .bool(false),
                    "ambiguity": .string("none"),
                    "userGoal": .string("Skriv et utkast og trykk hovedknappen."),
                    "recommendedNextStep": .string("compose_prompt")
                ]),
                "groundedActionPlan": .object([
                    "schema": .string("binding.grounded-action-plan.v0"),
                    "status": .string("idle"),
                    "nextStep": .string("compose_prompt"),
                    "explanation": .string("Ingen prompt analysert ennå."),
                    "sideEffectBeforeUserAction": .bool(false)
                ]),
                "groundedPlan": .object([
                    "schema": .string("binding.grounded-action-plan.v0"),
                    "status": .string("idle"),
                    "nextStep": .string("compose_prompt"),
                    "explanation": .string("Ingen prompt analysert ennå."),
                    "sideEffectBeforeUserAction": .bool(false)
                ]),
                "groundingVerification": .object([
                    "schema": .string("binding.grounded-action-verification.v0"),
                    "status": .string("idle"),
                    "allowed": .bool(false),
                    "reason": .string("Ingen prompt analysert ennå."),
                    "sideEffectBeforeUserAction": .bool(false)
                ]),
                "groundingDryRun": .object([
                    "schema": .string("binding.grounded-action-dry-run.v0"),
                    "status": .string("idle"),
                    "summary": .string("Skriv et utkast og trykk hovedknappen."),
                    "wouldMutateEntity": .bool(false),
                    "wouldSendNetworkRequest": .bool(false),
                    "sideEffectBeforeUserAction": .bool(false)
                ]),
                "groundingSchemas": .list(BindingGroundedActionVerifier.availableSchemas(
                    resourceMatches: [],
                    providers: [BindingChatProviderRouter.localRulesProvider()]
                ).map(ValueType.object)),
                "groundingAlternatives": .list([]),
                "purposeContext": .object([
                    "schema": .string("haven.purpose-context-pack.v0.binding-preview"),
                    "source": .string("PerspectiveCell + Binding deterministic classifier"),
                    "status": .string("idle"),
                    "summary": .string("Ingen purpose-kontekst hentet ennå."),
                    "purposeTreeExcerpt": .string("purpose://prompt.unknown"),
                    "interestTreeExcerpt": .string("chat-assistant, requires-user-approval"),
                    "responseGuidance": .string("Svar med brukerord først; tekniske purpose-detaljer vises i Avansert."),
                    "sideEffectFree": .bool(true)
                ]),
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
                    .string("personal.chat.assist.work-item.capture"),
                    .string("personal.chat.assist.rag-query"),
                    .string("personal.chat.assist.provider-route"),
                    .string("personal.chat.assist.capability-request"),
                    .string("personal.chat.assist.entity-contact-request"),
                    .string("personal.chat.assist.moderation"),
                    .string("personal.chat.assist.resource-router")
                ])
            ]),
            "skeletonConfiguration": .object([
                "name": .string("Co-Pilot"),
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
