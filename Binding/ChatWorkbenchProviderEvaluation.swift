// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase

enum BindingChatPromptProviderUnderTest: String, CaseIterable {
    case deterministicLocalRules = "deterministic/local-rules"
    case appleIntelligence = "binding.apple-intelligence"
    case localLLM = "binding.local-llm"
}

enum BindingChatPromptEvaluationError: Error {
    case missingRequesterIdentity
}

struct BindingChatPromptEvaluationOutcome: Equatable {
    var caseID: String
    var providerID: String
    var classification: BindingChatIntentClassification
    var expectedShouldSuggest: Bool
    var expectedIntentKind: String?
    var expectedPurposeRef: String?
    var expectedHelperID: String?
    var expectedSuggestionStatus: String?
    var forbiddenIntentKind: String?
    var resourceExpectationMet: Bool
    var providerExpectationMet: Bool
    var portholeUIExpectationMet: Bool

    nonisolated var matchesExpected: Bool {
        let classificationMatches: Bool
        if expectedShouldSuggest {
            classificationMatches = classification.shouldSuggest
                && classification.intentKind == expectedIntentKind
                && classification.purposeRef == expectedPurposeRef
                && classification.helperID == expectedHelperID
                && (expectedSuggestionStatus == nil || classification.status == expectedSuggestionStatus)
        } else if let forbiddenIntentKind {
            classificationMatches = classification.intentKind != forbiddenIntentKind
                && classification.shouldSuggest == false
        } else {
            classificationMatches = classification.shouldSuggest == false
        }
        return classificationMatches
            && resourceExpectationMet
            && providerExpectationMet
            && portholeUIExpectationMet
    }
}

enum BindingChatPromptEvaluationRunner {
    static func evaluate(
        suiteData: Data,
        provider: BindingChatPromptProviderUnderTest,
        requester: Identity? = nil
    ) async throws -> [BindingChatPromptEvaluationOutcome] {
        let suite = try JSONDecoder().decode(BindingPromptEvaluationSuite.self, from: suiteData)
        let effectiveRequester: Identity
        if let requester {
            effectiveRequester = requester
        } else {
            effectiveRequester = try await signedEvaluationRequester()
        }
        return try await suite.cases.asyncMap { item in
            let classification = try await classify(
                item.prompt,
                provider: provider,
                requester: effectiveRequester,
                setup: item.setup
            )
            return BindingChatPromptEvaluationOutcome(
                caseID: item.id,
                providerID: provider.rawValue,
                classification: classification,
                expectedShouldSuggest: item.expected.shouldSuggest,
                expectedIntentKind: item.expected.intentKind,
                expectedPurposeRef: item.expected.purposeRef,
                expectedHelperID: item.expected.helperID,
                expectedSuggestionStatus: item.expected.suggestionStatus,
                forbiddenIntentKind: item.expected.forbiddenIntentKind,
                resourceExpectationMet: resourceExpectationMet(for: item, classification: classification),
                providerExpectationMet: providerExpectationMet(for: item, classification: classification),
                portholeUIExpectationMet: portholeUIExpectationMet(for: item)
            )
        }
    }

    private static func signedEvaluationRequester() async throws -> Identity {
        let vault = EphemeralIdentityVault()
        guard let requester = await vault.identity(
            for: "binding-chat-provider-eval-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ) else {
            throw BindingChatPromptEvaluationError.missingRequesterIdentity
        }
        return requester
    }

    private static func resourceExpectationMet(
        for item: BindingPromptEvaluationCase,
        classification: BindingChatIntentClassification
    ) -> Bool {
        let expected = item.expected
        guard expected.expectsResourceMatch
            || expected.resourceMatchKind != nil
            || expected.resourceMatchTitle != nil
            || expected.resourceSourceCellEndpoint != nil
            || expected.resourceActionKeypath != nil
            || expected.resourcePurposeRef != nil
        else {
            return true
        }
        let matches = BindingChatIntentClassifier.resourceMatches(prompt: item.prompt)
        return matches.contains { resourceMatch($0, satisfies: expected) }
    }

    private static func providerExpectationMet(
        for item: BindingPromptEvaluationCase,
        classification: BindingChatIntentClassification
    ) -> Bool {
        let expected = item.expected
        guard expected.providerRecommendationKind != nil
            || expected.providerRecommendationID != nil
            || expected.providerExecutionScope != nil
        else {
            return true
        }
        let matches = BindingChatIntentClassifier.resourceMatches(prompt: item.prompt)
        let recommendation = BindingChatProviderRouter.recommend(
            prompt: item.prompt,
            suggestion: classification,
            resourceMatches: matches,
            providers: scopedProviders(for: item.setup)
        )
        if let kind = expected.providerRecommendationKind, recommendation.kind != kind {
            return false
        }
        if let id = expected.providerRecommendationID {
            if id == "binding.apple.local" {
                guard recommendation.kind == "apple_intelligence", recommendation.requiresNetwork == false else {
                    return false
                }
            } else if recommendation.id != id {
                return false
            }
        }
        if let scope = expected.providerExecutionScope {
            if expected.providerRecommendationID == "binding.apple.local" {
                guard recommendation.executionScope.localizedCaseInsensitiveContains("binding")
                    || recommendation.executionScope.localizedCaseInsensitiveContains("local")
                    || recommendation.executionScope.localizedCaseInsensitiveContains("chat")
                else {
                    return false
                }
            } else if recommendation.executionScope != scope {
                return false
            }
        }
        return true
    }

    private static func portholeUIExpectationMet(for item: BindingPromptEvaluationCase) -> Bool {
        let expected = item.expected
        guard expected.portholeUI != nil || expected.minimumExpandedMenuCount != nil else {
            return true
        }
        guard let request = BindingChatIntentClassifier.portholeUIRequest(for: item.prompt) else {
            return false
        }
        if let expectedFlags = expected.portholeUI {
            for (key, value) in expectedFlags {
                guard BindingChatValue.bool(request[key]) == value else {
                    return false
                }
            }
        }
        if let minimum = expected.minimumExpandedMenuCount {
            let count = BindingChatValue.list(request["expandMenus"])?.count ?? 0
            guard count >= minimum else {
                return false
            }
        }
        return true
    }

    private static func resourceMatch(_ match: Object, satisfies expected: BindingPromptEvaluationExpected) -> Bool {
        if let kind = expected.resourceMatchKind, BindingChatValue.string(match["kind"]) != kind {
            return false
        }
        if let title = expected.resourceMatchTitle, BindingChatValue.string(match["title"]) != title {
            return false
        }
        if let endpoint = expected.resourceSourceCellEndpoint, BindingChatValue.string(match["sourceCellEndpoint"]) != endpoint {
            return false
        }
        if let actionKeypath = expected.resourceActionKeypath, BindingChatValue.string(match["actionKeypath"]) != actionKeypath {
            return false
        }
        if let purposeRef = expected.resourcePurposeRef {
            let purposeRefs = BindingChatValue.stringList(match["purposeRefs"])
            guard purposeRefs.contains(purposeRef) || BindingChatValue.string(match["purposeRef"]) == purposeRef else {
                return false
            }
        }
        return true
    }

    private static func scopedProviders(for setup: [String]) -> [BindingChatProviderDescriptor] {
        guard setup.contains("scoped-ai-providers") else { return [] }
        return [
            BindingChatProviderDescriptor(
                id: "binding.apple.local",
                kind: "apple_intelligence",
                title: "Binding Apple Intelligence",
                summary: "Local assistant provider declared by Binding inside this chat scope.",
                endpoint: "cell:///AppleIntelligence",
                sourceCellName: nil,
                actionKeypath: "ai.sendPrompt",
                purposeRefs: ["personal.ai.provider.apple-intelligence"],
                interests: ["apple", "lokal", "privat", "assistant"],
                availability: "available_in_chat_scope",
                privacyLevel: "local_device",
                executionScope: "binding_chat_scope",
                requiresUserApproval: true,
                requiresNetwork: false,
                canInvokeFromChat: false,
                score: 0.74,
                reason: "Provider declared in prompt evaluation setup."
            ),
            BindingChatProviderDescriptor(
                id: "openai.4o-mini",
                kind: "openai_compatible",
                title: "OpenAI 4o-mini",
                summary: "Network provider declared by the chat owner for comparison evals.",
                endpoint: "cell:///AIGateway",
                sourceCellName: nil,
                actionKeypath: "ai.invoke",
                purposeRefs: ["personal.ai.provider.4o-mini"],
                interests: ["openai", "4o-mini", "assistant"],
                availability: "available_in_chat_scope",
                privacyLevel: "network",
                executionScope: "chat_owner_network_provider",
                requiresUserApproval: true,
                requiresNetwork: true,
                canInvokeFromChat: false,
                score: 0.62,
                reason: "Provider declared in prompt evaluation setup."
            )
        ]
    }

    private static func classify(
        _ prompt: String,
        provider: BindingChatPromptProviderUnderTest,
        requester: Identity,
        setup: [String]
    ) async throws -> BindingChatIntentClassification {
        let capabilityDiscoveryEnabled = setup.contains("capability-discovery-enabled")
        switch provider {
        case .deterministicLocalRules:
            return BindingChatIntentClassifier.classify(
                prompt: prompt,
                capabilityDiscoveryEnabled: capabilityDiscoveryEnabled
            )
        case .appleIntelligence:
            let cell = await BindingAppleIntelligenceProviderCell(owner: requester)
            let value = try await cell.set(
                keypath: "ai.classifyIntent",
                value: .object([
                    "draft": .string(prompt),
                    "capabilityDiscoveryEnabled": .bool(capabilityDiscoveryEnabled),
                    "evaluationMode": .string("fixture")
                ]),
                requester: requester
            ) ?? .null
            return classification(from: value)
        case .localLLM:
            let cell = await BindingLocalLLMCell(owner: requester)
            let value = try await cell.set(
                keypath: "llm.classifyIntent",
                value: .object([
                    "draft": .string(prompt),
                    "capabilityDiscoveryEnabled": .bool(capabilityDiscoveryEnabled)
                ]),
                requester: requester
            ) ?? .null
            return classification(from: value)
        }
    }

    private static func classification(from value: ValueType) -> BindingChatIntentClassification {
        guard let object = BindingChatValue.object(value) else {
            return BindingChatIntentClassifier.classify(prompt: "")
        }
        return BindingChatIntentClassification(
            intentKind: BindingChatValue.string(object["intentKind"]) ?? BindingChatValue.string(object["kind"]) ?? "none",
            purposeRef: BindingChatValue.string(object["purposeRef"]) ?? "personal.chat.assist.resource-router",
            interests: BindingChatValue.stringList(object["interests"]),
            helperID: BindingChatValue.string(object["helperID"]) ?? "",
            confidence: BindingChatValue.double(object["confidence"]) ?? 0.0,
            requiresUserApproval: BindingChatValue.bool(object["requiresUserApproval"]) ?? true,
            reason: BindingChatValue.string(object["reason"]) ?? "",
            negativeIntent: BindingChatValue.string(object["negativeIntent"]) ?? "",
            status: BindingChatValue.string(object["status"]) ?? "low_confidence"
        )
    }
}

private struct BindingPromptEvaluationSuite: Decodable {
    var cases: [BindingPromptEvaluationCase]
}

private struct BindingPromptEvaluationCase: Decodable {
    var id: String
    var prompt: String
    var setup: [String]
    var expected: BindingPromptEvaluationExpected
}

private struct BindingPromptEvaluationExpected: Decodable {
    var shouldSuggest: Bool
    var intentKind: String?
    var purposeRef: String?
    var suggestionStatus: String?
    var helperID: String?
    var forbiddenIntentKind: String?
    var expectsResourceMatch: Bool
    var resourceMatchKind: String?
    var resourceMatchTitle: String?
    var resourceSourceCellEndpoint: String?
    var resourceActionKeypath: String?
    var resourcePurposeRef: String?
    var providerRecommendationKind: String?
    var providerRecommendationID: String?
    var providerExecutionScope: String?
    var portholeUI: [String: Bool]?
    var minimumExpandedMenuCount: Int?

    private enum CodingKeys: String, CodingKey {
        case shouldSuggest
        case intentKind
        case purposeRef
        case suggestionStatus
        case helperID
        case forbiddenIntentKind
        case expectsResourceMatch
        case resourceMatchKind
        case resourceMatchTitle
        case resourceSourceCellEndpoint
        case resourceActionKeypath
        case resourcePurposeRef
        case providerRecommendationKind
        case providerRecommendationID
        case providerExecutionScope
        case portholeUI
        case minimumExpandedMenuCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shouldSuggest = try container.decode(Bool.self, forKey: .shouldSuggest)
        intentKind = try container.decodeIfPresent(String.self, forKey: .intentKind)
        purposeRef = try container.decodeIfPresent(String.self, forKey: .purposeRef)
        suggestionStatus = try container.decodeIfPresent(String.self, forKey: .suggestionStatus)
        helperID = try container.decodeIfPresent(String.self, forKey: .helperID)
        forbiddenIntentKind = try container.decodeIfPresent(String.self, forKey: .forbiddenIntentKind)
        expectsResourceMatch = try container.decodeIfPresent(Bool.self, forKey: .expectsResourceMatch) ?? false
        resourceMatchKind = try container.decodeIfPresent(String.self, forKey: .resourceMatchKind)
        resourceMatchTitle = try container.decodeIfPresent(String.self, forKey: .resourceMatchTitle)
        resourceSourceCellEndpoint = try container.decodeIfPresent(String.self, forKey: .resourceSourceCellEndpoint)
        resourceActionKeypath = try container.decodeIfPresent(String.self, forKey: .resourceActionKeypath)
        resourcePurposeRef = try container.decodeIfPresent(String.self, forKey: .resourcePurposeRef)
        providerRecommendationKind = try container.decodeIfPresent(String.self, forKey: .providerRecommendationKind)
        providerRecommendationID = try container.decodeIfPresent(String.self, forKey: .providerRecommendationID)
        providerExecutionScope = try container.decodeIfPresent(String.self, forKey: .providerExecutionScope)
        portholeUI = try container.decodeIfPresent([String: Bool].self, forKey: .portholeUI)
        minimumExpandedMenuCount = try container.decodeIfPresent(Int.self, forKey: .minimumExpandedMenuCount)
    }
}

private extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        for element in self {
            let value = try await transform(element)
            values.append(value)
        }
        return values
    }
}
