// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  HavenSurfaceRelevance.swift
//  Binding
//
//  A surface the butler cannot find does not exist for the owner. This is
//  the one place that decides (a) how well a surface's own words match what
//  someone typed, and (b) whether those words are good enough to be found
//  at all. Pure functions, so the catalog, the butler and the tests agree.
//

import Foundation

/// What a surface says about itself. Built from a catalog entry here and, on
/// a scaffold, from the same fields there.
nonisolated struct HavenSurfaceDescriptor: Equatable, Sendable {
    var name: String
    var displayName: String?
    var purpose: String
    var purposeDescription: String?
    var summary: String?
    var tags: [String]
    var interests: [String]
    var sourceCellEndpoint: String

    var shownName: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? name : trimmed
    }
}

nonisolated struct HavenSurfaceMatch: Equatable, Sendable {
    var descriptor: HavenSurfaceDescriptor
    var score: Double
    var matchedTerms: [String]
}

nonisolated struct HavenSurfaceDescriptionIssue: Equatable, Sendable, CustomStringConvertible {
    enum Kind: String, Sendable {
        case missingPurposeDescription
        case purposeDescriptionTooShort
        case purposeDescriptionRestatesName
        case transliteratedNorwegian
        case tooFewInterests
        case missingSummary
        case missingEndpoint
    }
    var kind: Kind
    var detail: String
    var description: String { "\(kind.rawValue): \(detail)" }
}

nonisolated enum HavenSurfaceRelevance {

    // MARK: Text

    /// Words that carry no meaning for finding a surface. Norwegian and the
    /// English the catalog slips into.
    static let stopWords: Set<String> = [
        "og", "i", "på", "pa", "for", "til", "av", "med", "en", "et", "ei", "den", "det", "de", "som", "er", "kan",
        "skal", "vil", "jeg", "du", "vi", "meg", "deg", "oss", "min", "mitt", "mine", "din", "ditt", "har", "hva",
        "hvor", "hvordan", "hvem", "når", "nar", "om", "at", "fra", "uten", "eller", "ikke", "bare", "her", "der",
        "the", "a", "an", "and", "or", "of", "to", "in", "on", "for", "with", "my", "me", "you", "is", "are", "be",
        "vis", "åpne", "apne", "open", "show", "gi", "finn", "find", "se", "flate", "flaten", "surface", "cellconfiguration",
        "konfigurasjon", "configuration", "haven"
    ]

    /// Lowercase, Norwegian letters made plain, transliteration undone
    /// («haandter» → «handter», so it meets «håndter» halfway), punctuation
    /// gone. One representation for both sides.
    static func normalize(_ text: String) -> String {
        var value = text.lowercased()
        let replacements: [(String, String)] = [
            ("å", "a"), ("ä", "a"), ("á", "a"), ("à", "a"), ("â", "a"),
            ("ø", "o"), ("ö", "o"), ("ó", "o"), ("ô", "o"),
            ("æ", "ae"), ("é", "e"), ("è", "e"), ("ê", "e"), ("ü", "u"), ("ï", "i"), ("í", "i"), ("ñ", "n"), ("ç", "c")
        ]
        for (from, to) in replacements { value = value.replacingOccurrences(of: from, with: to) }
        // ASCII stand-ins for å and ø, as they appear in older catalog text.
        value = value.replacingOccurrences(of: "aa", with: "a")
        value = value.replacingOccurrences(of: "oe", with: "o")
        return value
    }

    /// Content tokens: normalized, stop words out, short things out, stems
    /// of five letters for anything longer so «relasjoner» meets «relasjon».
    static func tokens(_ text: String) -> [String] {
        normalize(text)
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
            .filter { $0.count >= 3 && !stopWords.contains($0) }
            .map(stem)
    }

    static func stem(_ token: String) -> String {
        token.count > 6 ? String(token.prefix(5)) : token
    }

    // MARK: Scoring

    /// How well the surface's own words answer the prompt. The name and the
    /// declared interests count most; the description is what catches the
    /// prompts nobody thought of. Normalized by prompt length so a long
    /// sentence does not outrank a short one by accident.
    static func score(prompt: String, descriptor: HavenSurfaceDescriptor) -> HavenSurfaceMatch {
        let promptTokens = Array(Set(tokens(prompt)))
        guard !promptTokens.isEmpty else {
            return HavenSurfaceMatch(descriptor: descriptor, score: 0, matchedTerms: [])
        }
        let nameTokens: Set<String> = Set(tokens(descriptor.name))
        let displayTokens: Set<String> = Set(tokens(descriptor.displayName ?? ""))
        let purposeTokens: Set<String> = Set(tokens(descriptor.purpose))
        var interestTokens: Set<String> = []
        for term in descriptor.tags + descriptor.interests { interestTokens.formUnion(tokens(term)) }
        let descriptionTokens: Set<String> = Set(tokens(descriptor.purposeDescription ?? ""))
        let summaryTokens: Set<String> = Set(tokens(descriptor.summary ?? ""))
        let fields: [(weight: Double, tokens: Set<String>)] = [
            (3.0, nameTokens), (3.0, displayTokens), (2.0, purposeTokens),
            (2.5, interestTokens), (1.5, descriptionTokens), (1.0, summaryTokens)
        ]
        var total = 0.0
        var matched = Set<String>()
        for token in promptTokens {
            var best = 0.0
            for field in fields where field.tokens.contains(token) {
                best = max(best, field.weight)
            }
            if best > 0 {
                total += best
                matched.insert(token)
            }
        }
        // Coverage: half the prompt matching a surface beats one strong word.
        let coverage = Double(matched.count) / Double(promptTokens.count)
        let score = (total / Double(promptTokens.count)) * (0.5 + 0.5 * coverage)
        return HavenSurfaceMatch(descriptor: descriptor, score: score, matchedTerms: matched.sorted())
    }

    /// Ranked, with everything below the floor left out. `0.6` is roughly
    /// «one weighty word matched» — below it the match is noise.
    static func rank(
        prompt: String,
        descriptors: [HavenSurfaceDescriptor],
        limit: Int = 5,
        floor: Double = 0.6
    ) -> [HavenSurfaceMatch] {
        var matches: [HavenSurfaceMatch] = []
        for descriptor in descriptors {
            let match = score(prompt: prompt, descriptor: descriptor)
            if match.score >= floor { matches.append(match) }
        }
        matches.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.descriptor.shownName < rhs.descriptor.shownName
        }
        if matches.count > limit { matches.removeSubrange(limit...) }
        return matches
    }

    // MARK: Audit

    static let minimumDescriptionLength = 60
    static let minimumInterests = 3

    /// The reasons a surface would be hard or impossible to find by asking
    /// for it in plain language. Empty means «describable enough».
    static func audit(_ descriptor: HavenSurfaceDescriptor) -> [HavenSurfaceDescriptionIssue] {
        var issues: [HavenSurfaceDescriptionIssue] = []
        let description = descriptor.purposeDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if description.isEmpty {
            issues.append(.init(kind: .missingPurposeDescription, detail: "\(descriptor.shownName) har ingen formålsbeskrivelse."))
        } else {
            if description.count < minimumDescriptionLength {
                issues.append(.init(
                    kind: .purposeDescriptionTooShort,
                    detail: "\(descriptor.shownName): «\(description)» er \(description.count) tegn; minst \(minimumDescriptionLength) trengs for å bli funnet på annet enn navnet."
                ))
            }
            let nameTokens = Set(tokens(descriptor.name) + tokens(descriptor.displayName ?? "") + tokens(descriptor.purpose))
            let descriptionTokens = Set(tokens(description))
            let novel = descriptionTokens.subtracting(nameTokens)
            if !descriptionTokens.isEmpty, novel.count < 3 {
                issues.append(.init(
                    kind: .purposeDescriptionRestatesName,
                    detail: "\(descriptor.shownName): beskrivelsen gjentar navnet og tilfører \(novel.count) nye ord — si hva flaten gjør, for hvem, når."
                ))
            }
            if let word = transliteratedWord(in: description) {
                issues.append(.init(
                    kind: .transliteratedNorwegian,
                    detail: "\(descriptor.shownName): «\(word)» — skriv å/ø/æ, ikke aa/oe/ae; ellers matcher ikke det folk skriver."
                ))
            }
        }
        if (descriptor.tags + descriptor.interests).filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).count < minimumInterests {
            issues.append(.init(kind: .tooFewInterests, detail: "\(descriptor.shownName): færre enn \(minimumInterests) interesser/tags."))
        }
        if (descriptor.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(kind: .missingSummary, detail: "\(descriptor.shownName): mangler sammendrag for bibliotek og butler."))
        }
        if descriptor.sourceCellEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(kind: .missingEndpoint, detail: "\(descriptor.shownName): ingen kilde-endepunkt."))
        }
        return issues
    }

    /// A word that reads as ASCII-transliterated Norwegian: «paa», «haandter»,
    /// «oppfoelging». Only reported when the text has no real å/ø at all,
    /// which is the signature of a file typed on the wrong keyboard.
    static func transliteratedWord(in text: String) -> String? {
        if text.contains(where: { "åøæÅØÆ".contains($0) }) { return nil }
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        let markers = ["aa", "oe"]
        let allowed: Set<String> = ["does", "goes", "toes", "shoes", "poem", "poet", "phoenix", "canoe", "aardvark", "baas"]
        for word in words where !allowed.contains(word) {
            if markers.contains(where: { word.contains($0) }) {
                return word
            }
        }
        return nil
    }

    /// The prompt the audit expects to find the surface by: its own
    /// description's content words, not its name. If that fails, the
    /// description does not describe.
    static func findabilityProbe(for descriptor: HavenSurfaceDescriptor) -> String {
        let nameTokens = Set(tokens(descriptor.name) + tokens(descriptor.displayName ?? ""))
        let words = normalize(descriptor.purposeDescription ?? "")
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
            .filter { $0.count >= 4 && !stopWords.contains($0) && !nameTokens.contains(stem($0)) }
        var seen = Set<String>()
        let unique = words.filter { seen.insert(stem($0)).inserted }
        return unique.prefix(6).joined(separator: " ")
    }
}
