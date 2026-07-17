// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase
#if canImport(FoundationModels)
import FoundationModels
#endif

struct BindingApplePurposeCandidate: Equatable {
    var classification: BindingChatIntentClassification
    var title: String
    var summary: String
    var goalOutcome: String
    var resolverScore: Double
    var source: String

    var purposeRef: String { classification.purposeRef }

    func objectValue(verdict: String?) -> Object {
        [
            "purposeRef": .string(purposeRef),
            "intentKind": .string(classification.intentKind),
            "helperID": .string(classification.helperID),
            "title": .string(title),
            "summary": .string(summary),
            "goalOutcome": .string(goalOutcome),
            "resolverScore": .float(resolverScore),
            "source": .string(source),
            "verdict": verdict.map(ValueType.string) ?? .null
        ]
    }
}

struct BindingApplePurposeVerdictRecord: Equatable {
    var purposeRef: String
    var verdict: String
    var attempts: Int
}

struct BindingApplePurposeDecompositionOutcome: Equatable {
    var classification: BindingChatIntentClassification
    var candidates: [BindingApplePurposeCandidate]
    var verdicts: [BindingApplePurposeVerdictRecord]
    var acceptedPurposeRefs: [String]
    var source: String
    var status: String

    func objectValue() -> Object {
        let verdictByRef = verdicts.reduce(into: [String: String]()) { result, record in
            result[record.purposeRef] = record.verdict
        }
        return [
            "schema": .string(BindingApplePurposeDecompositionPipeline.schema),
            "status": .string(status),
            "source": .string(source),
            "gatePolicy": .object(BindingApplePurposeDecompositionPipeline.gatePolicyObject()),
            "candidatePurposeRefs": .list(candidates.map { .string($0.purposeRef) }),
            "candidates": .list(candidates.map { .object($0.objectValue(verdict: verdictByRef[$0.purposeRef])) }),
            "acceptedPurposeRefs": .list(acceptedPurposeRefs.map(ValueType.string)),
            "selectedPurposeRef": .string(classification.purposeRef),
            "unknownFallback": .bool(classification.purposeRef == BindingApplePurposeDecompositionPipeline.unknownPurposeRef),
            "modelErrorCount": .integer(verdicts.filter { $0.verdict == "error" }.count),
            "sideEffectFree": .bool(true),
            "mutatesPerspective": .bool(false),
            "mutatesEntity": .bool(false)
        ]
    }
}

enum BindingApplePurposeDecompositionPipeline {
    static let schema = "binding.apple-purpose-decomposition.v1"
    static let gatePolicyID = "binding.apple-purpose-gate.chat-v1"
    static let taxonomyVersion = "binding-chat-intents.2026-07-14"
    static let unknownPurposeRef = "purpose://prompt.unknown"
    private static let minimumResolverScoreBasisPoints = 6_800
    static let minimumResolverScore = 0.68
    static let maximumCandidateCount = 4

    private struct CandidateDefinition {
        var classification: BindingChatIntentClassification
        var title: String
        var summary: String
        var goalOutcome: String
        var strongPhrases: [String]
        var tokens: [String]
    }

    static func gatePolicyObject() -> Object {
        [
            "schema": .string("binding.apple-purpose-gate-policy.v1"),
            "policyID": .string(gatePolicyID),
            "taxonomyVersion": .string(taxonomyVersion),
            "minimumResolverScore": .float(minimumResolverScore),
            "maximumCandidateCount": .integer(maximumCandidateCount),
            "calibrationStatus": .string("provisional_existing_binding_threshold"),
            "unknownPurposeRef": .string(unknownPurposeRef),
            "modelMayInventPurposeRefs": .bool(false)
        ]
    }

    static func shortlist(
        prompt: String,
        fallback: BindingChatIntentClassification
    ) -> [BindingApplePurposeCandidate] {
        guard fallback.negativeIntent.isEmpty else { return [] }

        let normalized = BindingChatValue.normalized(prompt)
        var candidates: [BindingApplePurposeCandidate] = []
        if fallback.shouldSuggest {
            candidates.append(candidate(from: fallback, source: "binding_deterministic_classifier"))
        }

        for definition in candidateDefinitions {
            guard definition.classification.purposeRef != fallback.purposeRef else { continue }
            let strongHits = definition.strongPhrases.filter { normalized.contains($0) }.count
            let tokenHits = definition.tokens.filter { normalized.contains($0) }.count
            guard strongHits > 0 || tokenHits > 0 else { continue }

            let scoreBasisPoints = min(
                9_000,
                5_000 + (strongHits * 1_800) + (tokenHits * 600)
            )
            guard scoreBasisPoints >= minimumResolverScoreBasisPoints else { continue }
            let score = Double(scoreBasisPoints) / 10_000
            var classification = definition.classification
            classification.confidence = score
            candidates.append(BindingApplePurposeCandidate(
                classification: classification,
                title: definition.title,
                summary: definition.summary,
                goalOutcome: definition.goalOutcome,
                resolverScore: score,
                source: "binding_helper_candidate_index"
            ))
        }

        for resource in BindingChatIntentClassifier.resourceMatches(prompt: prompt).prefix(2) {
            guard let resourceCandidate = candidate(fromResource: resource),
                  resourceCandidate.purposeRef != fallback.purposeRef else { continue }
            candidates.append(resourceCandidate)
        }

        var bestByRef: [String: BindingApplePurposeCandidate] = [:]
        for candidate in candidates where candidate.purposeRef.isEmpty == false {
            if let existing = bestByRef[candidate.purposeRef],
               existing.resolverScore >= candidate.resolverScore {
                continue
            }
            bestByRef[candidate.purposeRef] = candidate
        }
        return bestByRef.values
            .sorted { left, right in
                if left.resolverScore == right.resolverScore {
                    if left.purposeRef == fallback.purposeRef { return true }
                    if right.purposeRef == fallback.purposeRef { return false }
                    return left.purposeRef < right.purposeRef
                }
                return left.resolverScore > right.resolverScore
            }
            .prefix(maximumCandidateCount)
            .map { $0 }
    }

    static func deterministicOutcome(
        fallback: BindingChatIntentClassification,
        candidates: [BindingApplePurposeCandidate],
        source: String = "deterministic_fallback"
    ) -> BindingApplePurposeDecompositionOutcome {
        let status: String
        if fallback.negativeIntent.isEmpty == false {
            status = "negative_intent"
        } else if fallback.shouldSuggest {
            status = "deterministic_selection"
        } else {
            status = "unknown"
        }
        return BindingApplePurposeDecompositionOutcome(
            classification: fallback,
            candidates: candidates,
            verdicts: [],
            acceptedPurposeRefs: fallback.shouldSuggest ? [fallback.purposeRef] : [],
            source: source,
            status: status
        )
    }

    static func resolve(
        fallback: BindingChatIntentClassification,
        candidates: [BindingApplePurposeCandidate],
        verdicts: [BindingApplePurposeVerdictRecord]
    ) -> BindingApplePurposeDecompositionOutcome {
        guard fallback.negativeIntent.isEmpty else {
            return deterministicOutcome(
                fallback: fallback,
                candidates: [],
                source: "negative_intent_guard"
            )
        }

        let candidateRefs = Set(candidates.map(\.purposeRef))
        let verdictByRef = verdicts.reduce(into: [String: String]()) { result, record in
            guard candidateRefs.contains(record.purposeRef) else { return }
            result[record.purposeRef] = record.verdict
        }
        let accepted = candidates.filter {
            verdictByRef[$0.purposeRef] == "yes" && passesGate($0.resolverScore)
        }.sorted { left, right in
            if left.resolverScore == right.resolverScore {
                if left.purposeRef == fallback.purposeRef { return true }
                if right.purposeRef == fallback.purposeRef { return false }
                return left.purposeRef < right.purposeRef
            }
            return left.resolverScore > right.resolverScore
        }

        guard let selected = accepted.first else {
            return BindingApplePurposeDecompositionOutcome(
                classification: unknownClassification(reason: unknownReason(verdictByRef: verdictByRef)),
                candidates: candidates,
                verdicts: verdicts.filter { candidateRefs.contains($0.purposeRef) },
                acceptedPurposeRefs: [],
                source: "apple_guided_candidate_verdicts",
                status: "unknown"
            )
        }

        var classification = selected.classification
        classification.confidence = selected.resolverScore
        classification.requiresUserApproval = true
        if accepted.count > 1,
           let second = accepted.dropFirst().first,
           selected.resolverScore - second.resolverScore < 0.05 {
            classification.status = "needs_candidate_selection"
        }
        return BindingApplePurposeDecompositionOutcome(
            classification: classification,
            candidates: candidates,
            verdicts: verdicts.filter { candidateRefs.contains($0.purposeRef) },
            acceptedPurposeRefs: accepted.map(\.purposeRef),
            source: "apple_guided_candidate_verdicts",
            status: classification.status == "needs_candidate_selection" ? "ambiguous" : "selected"
        )
    }

    private static func unknownReason(verdictByRef: [String: String]) -> String {
        if verdictByRef.values.contains("unsure") {
            return "Apple Intelligence var usikker, og ingen kandidat passerte den deterministiske porten."
        }
        if verdictByRef.values.contains("error") {
            return "Apple Intelligence kunne ikke vurdere kandidatene; ingen fri formålsreferanse ble godtatt."
        }
        return "Ingen kandidat ble bekreftet av både Apple Intelligence og den deterministiske porten."
    }

    private static func passesGate(_ score: Double) -> Bool {
        Int((score * 10_000).rounded()) >= minimumResolverScoreBasisPoints
    }

    private static func unknownClassification(reason: String) -> BindingChatIntentClassification {
        BindingChatIntentClassification(
            intentKind: "none",
            purposeRef: unknownPurposeRef,
            interests: [],
            helperID: "",
            confidence: 0,
            requiresUserApproval: true,
            reason: reason,
            negativeIntent: "",
            status: "low_confidence"
        )
    }

    private static func candidate(
        from classification: BindingChatIntentClassification,
        source: String
    ) -> BindingApplePurposeCandidate {
        let metadata = metadataForClassification(classification)
        return BindingApplePurposeCandidate(
            classification: classification,
            title: metadata.title,
            summary: metadata.summary,
            goalOutcome: metadata.goalOutcome,
            resolverScore: classification.confidence,
            source: source
        )
    }

    private static func candidate(fromResource resource: Object) -> BindingApplePurposeCandidate? {
        guard let purposeRef = BindingChatValue.stringList(resource["purposeRefs"]).first
                ?? BindingChatValue.string(resource["purposeRef"]),
              let title = BindingChatValue.string(resource["title"]) else {
            return nil
        }
        let kind = BindingChatValue.string(resource["kind"]) ?? "resource_match"
        let helperID: String
        if kind == "documentation" || kind == "rag_case" {
            helperID = "docs-rag"
        } else {
            helperID = "resource-router"
        }
        let score = BindingChatValue.double(resource["score"]) ?? 0
        guard passesGate(score) else { return nil }
        let classification = BindingChatIntentClassification(
            intentKind: "resource_match",
            purposeRef: purposeRef,
            interests: BindingChatValue.stringList(resource["interests"]),
            helperID: helperID,
            confidence: score,
            requiresUserApproval: true,
            reason: "Fant en synlig, grant-avhengig ressurskandidat: \(title).",
            negativeIntent: "",
            status: "suggested"
        )
        return BindingApplePurposeCandidate(
            classification: classification,
            title: title,
            summary: BindingChatValue.string(resource["summary"]) ?? "Visible HAVEN resource candidate.",
            goalOutcome: "Offer the matching visible resource for explicit user review; do not open or invoke it automatically.",
            resolverScore: score,
            source: "binding_visible_resource_index"
        )
    }

    private static func metadataForClassification(
        _ classification: BindingChatIntentClassification
    ) -> (title: String, summary: String, goalOutcome: String) {
        if let definition = candidateDefinitions.first(where: {
            $0.classification.purposeRef == classification.purposeRef
        }) {
            return (definition.title, definition.summary, definition.goalOutcome)
        }
        let title = classification.helperID.isEmpty ? classification.intentKind : classification.helperID
        return (
            title,
            classification.reason,
            "Offer only this known Binding helper or resource for explicit user review; perform no side effect."
        )
    }

    private static let candidateDefinitions: [CandidateDefinition] = [
        definition(
            kind: "invite_person",
            purposeRef: "personal.chat.assist.invite",
            interests: ["invite-person", "chat", "requires-user-approval"],
            helperID: "invite",
            title: "Invite a person",
            summary: "Prepare the existing invite helper for a user-selected person.",
            goalOutcome: "Open an invite draft; do not select a person or send before explicit confirmation.",
            strongPhrases: ["inviter ", "invite ", "send invitasjon"],
            tokens: ["invitasjon"]
        ),
        definition(
            kind: "create_poll",
            purposeRef: "personal.chat.assist.poll",
            interests: ["poll", "group-decision", "requires-user-approval"],
            helperID: "poll",
            title: "Create a poll draft",
            summary: "Prepare the existing poll helper for a group decision.",
            goalOutcome: "Open a poll draft; create nothing before explicit confirmation.",
            strongPhrases: ["lag avstemning", "opprett avstemning", "create poll", "stemme over"],
            tokens: ["avstemning", "poll"]
        ),
        definition(
            kind: "idea_capture",
            purposeRef: "personal.chat.assist.idea.capture",
            interests: ["idea", "capture", "private"],
            helperID: "idea-capture",
            title: "Capture an idea",
            summary: "Prepare the private idea-capture helper.",
            goalOutcome: "Open a private idea draft; persist nothing before explicit confirmation.",
            strongPhrases: ["jeg har en ide", "jeg har en idé", "lagre ide", "lagre idé", "ny ide", "ny idé"],
            tokens: ["ide:", "idé:", "idea:"]
        ),
        definition(
            kind: "todo",
            purposeRef: "personal.chat.assist.todo",
            interests: ["todo", "task", "private"],
            helperID: "todo",
            title: "Create a task draft",
            summary: "Prepare the existing to-do helper.",
            goalOutcome: "Open a task draft; create no task before explicit confirmation.",
            strongPhrases: ["lag oppgave", "opprett oppgave", "legg til oppgave", "ny oppgave", "må gjøre", "maa gjore"],
            tokens: ["oppgave:", "todo:", "task:"]
        ),
        definition(
            kind: "project",
            purposeRef: "personal.chat.assist.project",
            interests: ["project", "planning"],
            helperID: "project",
            title: "Structure a project",
            summary: "Prepare the existing project helper.",
            goalOutcome: "Open a private project draft; create no project before explicit confirmation.",
            strongPhrases: ["lag prosjekt", "opprett prosjekt", "nytt prosjekt", "prosjektplan", "project plan"],
            tokens: ["prosjektstyring", "project management"]
        ),
        definition(
            kind: "reminder",
            purposeRef: "personal.chat.assist.reminder",
            interests: ["reminder", "time", "requires-user-approval"],
            helperID: "reminder",
            title: "Prepare a reminder",
            summary: "Prepare the existing reminder helper.",
            goalOutcome: "Open a reminder draft; create no system reminder before explicit confirmation.",
            strongPhrases: ["minn meg", "remind me", "lag påminnelse", "lag paaminnelse"],
            tokens: ["påminn", "paaminn", "reminder"]
        ),
        definition(
            kind: "schedule_meeting",
            purposeRef: "personal.chat.assist.meeting.schedule",
            interests: ["meeting", "calendar-intent", "requires-user-approval"],
            helperID: "meeting",
            title: "Prepare a meeting",
            summary: "Prepare the existing meeting helper without accessing Calendar.",
            goalOutcome: "Open a meeting draft; do not access Calendar or send invitations before explicit capability approval.",
            strongPhrases: ["sett opp møte", "sett opp mote", "møte med", "mote med", "schedule meeting"],
            tokens: ["møte", "meeting"]
        ),
        definition(
            kind: "meeting_video",
            purposeRef: "personal.chat.assist.meeting.video",
            interests: ["meeting", "video", "requires-user-approval"],
            helperID: "meeting",
            title: "Prepare a video meeting",
            summary: "Prepare the existing meeting helper without camera or microphone access.",
            goalOutcome: "Open a video-meeting draft; do not use camera, microphone or Calendar before explicit capability approval.",
            strongPhrases: ["videochat", "video chat", "videomøte", "video meeting"],
            tokens: ["teams-møte", "zoom-møte"]
        ),
        definition(
            kind: "work_item",
            purposeRef: "personal.chat.assist.work-item.capture",
            interests: ["work-item", "bug-report", "requires-user-approval"],
            helperID: "work-item",
            title: "Capture a work item",
            summary: "Prepare the existing work-item helper for a bug, regression or task.",
            goalOutcome: "Open a work-item draft; register nothing before explicit review and confirmation.",
            strongPhrases: ["registrer feil", "rapporter feil", "work item", "feilrapport"],
            tokens: ["bug", "regresjon", "repro"]
        ),
        definition(
            kind: "capability_request",
            purposeRef: "personal.chat.assist.capability-request",
            interests: ["capability-gap", "feature-request", "requires-user-approval"],
            helperID: "capability-request",
            title: "Capture a capability gap",
            summary: "Prepare the existing capability-request helper.",
            goalOutcome: "Open a local request draft; submit nothing before explicit user confirmation.",
            strongPhrases: ["feature request", "meld behov", "skulle ønske", "skulle onske"],
            tokens: ["savner", "mangler"]
        )
    ]

    private static func definition(
        kind: String,
        purposeRef: String,
        interests: [String],
        helperID: String,
        title: String,
        summary: String,
        goalOutcome: String,
        strongPhrases: [String],
        tokens: [String]
    ) -> CandidateDefinition {
        CandidateDefinition(
            classification: BindingChatIntentClassification(
                intentKind: kind,
                purposeRef: purposeRef,
                interests: interests,
                helperID: helperID,
                confidence: minimumResolverScore,
                requiresUserApproval: true,
                reason: summary,
                negativeIntent: "",
                status: "suggested"
            ),
            title: title,
            summary: summary,
            goalOutcome: goalOutcome,
            strongPhrases: strongPhrases,
            tokens: tokens
        )
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
enum BindingApplePurposeVerdict: String {
    case yes
    case no
    case unsure
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct BindingApplePurposeMicroAnswer {
    @Guide(description: "yes if the request requires this purpose, no if it does not, unsure only when genuinely unclear")
    var verdict: BindingApplePurposeVerdict
}
#endif
