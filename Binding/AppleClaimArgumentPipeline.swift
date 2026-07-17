// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase
#if canImport(FoundationModels)
import FoundationModels
#endif

struct BindingAppleClaimCandidate: Equatable {
    var claimID: String
    var quote: String
    var startCharacter: Int
    var endCharacter: Int
    var strength: ClaimStrength
    var sourceRefs: [String]

    func objectValue(verdict: BindingAppleClaimVerdictRecord?) -> Object {
        [
            "claimID": .string(claimID),
            "quote": .string(quote),
            "startCharacter": .integer(startCharacter),
            "endCharacter": .integer(endCharacter),
            "strength": .string(strength.rawValue),
            "sourceRefs": .list(sourceRefs.map(ValueType.string)),
            "verdict": verdict.map { .string($0.verdict) } ?? .null,
            "claimType": verdict?.claimType.map(ValueType.string) ?? .null,
            "attempts": verdict.map { .integer($0.attempts) } ?? .integer(0)
        ]
    }
}

struct BindingAppleClaimVerdictRecord: Equatable {
    var claimID: String
    var verdict: String
    var claimType: String?
    var attempts: Int
}

struct BindingAppleAcceptedClaim: Equatable {
    var definition: ClaimDefinition
    var sourceAuditStatus: ClaimSourceAuditStatus

    func objectValue() -> Object {
        [
            "schema": .string(definition.schema),
            "claimID": .string(definition.claimID),
            "statement": .string(definition.statement),
            "claimType": .string(definition.claimType.rawValue),
            "strength": .string(definition.strength.rawValue),
            "quote": definition.quote.map(ValueType.string) ?? .null,
            "isInferred": .bool(definition.isInferred),
            "sourceRefs": .list(definition.sourceRefs.map(ValueType.string)),
            "sourceAuditStatus": .string(sourceAuditStatus.rawValue),
            "purposeRef": definition.purposeRef.map(ValueType.string) ?? .null,
            "goalID": definition.goalID.map(ValueType.string) ?? .null,
            "supports": .list([]),
            "composition": .null,
            "tags": .list(definition.tags.map(ValueType.string))
        ]
    }
}

struct BindingAppleClaimAnalysisOutcome: Equatable {
    var candidates: [BindingAppleClaimCandidate]
    var verdicts: [BindingAppleClaimVerdictRecord]
    var acceptedClaims: [BindingAppleAcceptedClaim]
    var source: String
    var status: String

    func objectValue() -> Object {
        let verdictByID = verdicts.reduce(into: [String: BindingAppleClaimVerdictRecord]()) {
            result, record in
            result[record.claimID] = record
        }
        return [
            "schema": .string(BindingAppleClaimArgumentPipeline.schema),
            "claimSchema": .string(ClaimDefinition.schemaID),
            "status": .string(status),
            "source": .string(source),
            "candidateClaims": .list(candidates.map {
                .object($0.objectValue(verdict: verdictByID[$0.claimID]))
            }),
            "acceptedClaimIDs": .list(acceptedClaims.map { .string($0.definition.claimID) }),
            "claimLedger": .list(acceptedClaims.map { .object($0.objectValue()) }),
            "modelErrorCount": .integer(verdicts.filter {
                $0.verdict == "error" || $0.claimType == "error"
            }.count),
            "modelMayInventClaimIDs": .bool(false),
            "modelMayInventClaimText": .bool(false),
            "quotesAreExactInputAnchors": .bool(true),
            "sourceAuditPerformed": .bool(false),
            "argumentCompositionPerformed": .bool(false),
            "sideEffectFree": .bool(true),
            "mutatesPerspective": .bool(false),
            "mutatesEntity": .bool(false)
        ]
    }
}

enum BindingAppleClaimArgumentPipeline {
    static let schema = "binding.apple-claim-analysis.v1"
    static let maximumCandidateCount = 6

    static func analyze(
        text: String,
        purposeRef: String?,
        allowFoundationModels: Bool
    ) async -> BindingAppleClaimAnalysisOutcome {
        let boundedCandidates = candidates(in: text)
        guard allowFoundationModels else {
            return deterministicOutcome(
                candidates: boundedCandidates,
                purposeRef: purposeRef,
                source: "fixture_deterministic_claim_heuristics"
            )
        }

#if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *),
           SystemLanguageModel.default.isAvailable {
            var verdicts: [BindingAppleClaimVerdictRecord] = []
            for candidate in boundedCandidates {
                let presence = await guidedPresenceVerdict(for: candidate)
                var claimType: String?
                var attempts = presence.attempts
                if presence.verdict == "yes" {
                    let typeResult = await guidedClaimType(for: candidate)
                    claimType = typeResult.claimType
                    attempts += typeResult.attempts
                }
                verdicts.append(BindingAppleClaimVerdictRecord(
                    claimID: candidate.claimID,
                    verdict: presence.verdict,
                    claimType: claimType,
                    attempts: attempts
                ))
            }
            return resolve(
                candidates: boundedCandidates,
                verdicts: verdicts,
                purposeRef: purposeRef,
                source: "apple_guided_claim_microtasks"
            )
        }
#endif

        return deterministicOutcome(
            candidates: boundedCandidates,
            purposeRef: purposeRef,
            source: "foundation_models_unavailable_claim_fallback"
        )
    }

    static func candidates(in text: String) -> [BindingAppleClaimCandidate] {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return []
        }

        var rawRanges: [Range<String.Index>] = []
        var segmentStart = text.startIndex
        for index in text.indices {
            let character = text[index]
            let isSentenceBoundary: Bool
            if character == "." {
                let next = text.index(after: index)
                isSentenceBoundary = next == text.endIndex || text[next].isWhitespace
            } else {
                isSentenceBoundary = character == "!" || character == "?" || character == "\n"
            }
            guard isSentenceBoundary else {
                continue
            }
            let end = text.index(after: index)
            rawRanges.append(segmentStart..<end)
            segmentStart = end
        }
        if segmentStart < text.endIndex {
            rawRanges.append(segmentStart..<text.endIndex)
        }

        var seenIDs: Set<String> = []
        var result: [BindingAppleClaimCandidate] = []
        for rawRange in rawRanges {
            let raw = text[rawRange]
            guard let first = raw.firstIndex(where: { $0.isWhitespace == false }),
                  let last = raw.lastIndex(where: { $0.isWhitespace == false }) else {
                continue
            }
            let end = text.index(after: last)
            let quote = String(text[first..<end])
            let wordCount = quote.split(whereSeparator: { $0.isWhitespace }).count
            guard wordCount >= 3,
                  quote.hasPrefix("#") == false else {
                continue
            }

            let startCharacter = text.distance(from: text.startIndex, to: first)
            let endCharacter = text.distance(from: text.startIndex, to: end)
            let claimID = stableClaimID(quote: quote, startCharacter: startCharacter)
            guard seenIDs.insert(claimID).inserted else { continue }
            result.append(BindingAppleClaimCandidate(
                claimID: claimID,
                quote: quote,
                startCharacter: startCharacter,
                endCharacter: endCharacter,
                strength: strength(for: quote),
                sourceRefs: sourceRefs(in: quote)
            ))
            if result.count == maximumCandidateCount { break }
        }
        return result
    }

    static func deterministicOutcome(
        candidates: [BindingAppleClaimCandidate],
        purposeRef: String?,
        source: String
    ) -> BindingAppleClaimAnalysisOutcome {
        let verdicts = candidates.map { candidate in
            let accepted = looksLikeClaim(candidate.quote)
            return BindingAppleClaimVerdictRecord(
                claimID: candidate.claimID,
                verdict: accepted ? "yes" : "no",
                claimType: accepted ? heuristicClaimType(candidate.quote).rawValue : nil,
                attempts: 0
            )
        }
        return resolve(
            candidates: candidates,
            verdicts: verdicts,
            purposeRef: purposeRef,
            source: source
        )
    }

    static func resolve(
        candidates: [BindingAppleClaimCandidate],
        verdicts: [BindingAppleClaimVerdictRecord],
        purposeRef: String?,
        source: String = "apple_guided_claim_microtasks"
    ) -> BindingAppleClaimAnalysisOutcome {
        let candidateIDs = Set(candidates.map(\.claimID))
        let boundedVerdicts = verdicts.filter { candidateIDs.contains($0.claimID) }
        let verdictByID = boundedVerdicts.reduce(into: [String: BindingAppleClaimVerdictRecord]()) {
            result, record in
            result[record.claimID] = record
        }
        let accepted = candidates.compactMap { candidate -> BindingAppleAcceptedClaim? in
            guard let verdict = verdictByID[candidate.claimID],
                  verdict.verdict == "yes",
                  let rawType = verdict.claimType,
                  let claimType = ClaimType(rawValue: rawType) else {
                return nil
            }
            let sourceAuditStatus: ClaimSourceAuditStatus = candidate.sourceRefs.isEmpty
                ? .sourceMissing
                : .needsExternalSourceAudit
            let definition = ClaimDefinition(
                claimID: candidate.claimID,
                statement: candidate.quote,
                claimType: claimType,
                strength: candidate.strength,
                quote: candidate.quote,
                isInferred: false,
                sourceRefs: candidate.sourceRefs,
                purposeRef: purposeRef,
                supports: [],
                composition: nil,
                tags: [
                    "binding-apple-extracted",
                    "source-audit:\(sourceAuditStatus.rawValue)"
                ]
            )
            return BindingAppleAcceptedClaim(
                definition: definition,
                sourceAuditStatus: sourceAuditStatus
            )
        }
        let status: String
        if candidates.isEmpty {
            status = "no_candidates"
        } else if accepted.isEmpty {
            status = "no_accepted_claims"
        } else {
            status = "claim_ledger_ready"
        }
        return BindingAppleClaimAnalysisOutcome(
            candidates: candidates,
            verdicts: boundedVerdicts,
            acceptedClaims: accepted,
            source: source,
            status: status
        )
    }

    private static func stableClaimID(quote: String, startCharacter: Int) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in "\(startCharacter):\(quote)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(format: "claim.binding.%016llx", hash)
    }

    private static func sourceRefs(in quote: String) -> [String] {
        var refs: [String] = []
        let trimming = CharacterSet(charactersIn: "()[]{}<>,.;:\"'")
        for token in quote.split(whereSeparator: { $0.isWhitespace }) {
            let candidate = String(token).trimmingCharacters(in: trimming)
            guard candidate.hasPrefix("https://") || candidate.hasPrefix("http://") else {
                continue
            }
            if refs.contains(candidate) == false {
                refs.append(candidate)
            }
        }
        return refs
    }

    private static func strength(for quote: String) -> ClaimStrength {
        let normalized = paddedNormalized(quote)
        if containsAny(normalized, [" kanskje ", " muligens ", " trolig ", " sannsynligvis ", " possibly ", " perhaps "]) {
            return .speculative
        }
        if containsAny(normalized, [" kan ", " ofte ", " vanligvis ", " delvis ", " may ", " often "]) {
            return .moderated
        }
        return .assertive
    }

    private static func looksLikeClaim(_ quote: String) -> Bool {
        let normalized = paddedNormalized(quote)
        if quote.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") {
            return false
        }
        if containsAny(normalized, [" hvem ", " hva ", " hvor ", " hvorfor ", " hvordan ", " when ", " where ", " why ", " how "]) {
            return false
        }
        return quote.split(whereSeparator: { $0.isWhitespace }).count >= 3
    }

    private static func heuristicClaimType(_ quote: String) -> ClaimType {
        let normalized = paddedNormalized(quote)
        if quote.contains("%")
            || quote.rangeOfCharacter(from: .decimalDigits) != nil
            || containsAny(normalized, [" prosent ", " percent ", " gjennomsnitt ", " average "]) {
            return .statistical
        }
        if containsAny(normalized, [" fordi ", " fører til ", " forer til ", " skyldes ", " derfor ", " causes ", " because "]) {
            return .causal
        }
        if containsAny(normalized, [" bør ", " bor ", " må ", " skal ", " ought ", " should ", " must "]) {
            return .normative
        }
        if containsAny(normalized, [" vil ", " kommer til ", " forventes ", " will ", " expected to "]) {
            return .predictive
        }
        if containsAny(normalized, [" støtter ", " stotter ", " implementert ", " kan levere ", " supports ", " implemented "]) {
            return .projectCapability
        }
        return .factual
    }

    private static func paddedNormalized(_ text: String) -> String {
        " \(BindingChatValue.normalized(text)) "
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains(where: text.contains)
    }

#if canImport(FoundationModels)
    @available(macOS 26.0, iOS 26.0, *)
    private static func guidedPresenceVerdict(
        for candidate: BindingAppleClaimCandidate
    ) async -> (verdict: String, attempts: Int) {
        var attempts = 0
        while attempts < 3 {
            attempts += 1
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(
                    generating: BindingAppleClaimPresenceAnswer.self,
                    includeSchemaInPrompt: true,
                    options: GenerationOptions(sampling: .greedy)
                ) {
                    """
                    Decide whether this exact quote contains an assertion that can be represented as a claim. A claim may be factual, causal, normative, predictive, statistical, or about a project's capability. Questions, headings, fragments, and pure commands are not claims. Do not rewrite or add text.

                    Exact quote: "\(candidate.quote)"
                    """
                }
                return (response.content.verdict.rawValue, attempts)
            } catch {
                continue
            }
        }
        return ("error", attempts)
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func guidedClaimType(
        for candidate: BindingAppleClaimCandidate
    ) async -> (claimType: String, attempts: Int) {
        var attempts = 0
        while attempts < 3 {
            attempts += 1
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(
                    generating: BindingAppleClaimTypeAnswer.self,
                    includeSchemaInPrompt: true,
                    options: GenerationOptions(sampling: .greedy)
                ) {
                    """
                    Classify the exact quote into one allowed claim type. Use project_capability only for assertions about what a project, product, system, or implementation can do. Do not rewrite the quote and do not add evidence.

                    Exact quote: "\(candidate.quote)"
                    """
                }
                return (response.content.claimType.rawValue, attempts)
            } catch {
                continue
            }
        }
        return ("error", attempts)
    }
#endif
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
struct BindingAppleClaimPresenceAnswer {
    @Guide(description: "yes if the exact quote contains a claim, no if it does not, unsure only when genuinely unclear")
    var verdict: BindingApplePurposeVerdict
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
enum BindingAppleGuidedClaimType: String {
    case factual
    case causal
    case normative
    case predictive
    case statistical
    case projectCapability = "project_capability"
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct BindingAppleClaimTypeAnswer {
    @Guide(description: "one bounded claim type for the exact quote")
    var claimType: BindingAppleGuidedClaimType
}
#endif
