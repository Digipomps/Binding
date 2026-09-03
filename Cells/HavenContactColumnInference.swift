// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  HavenContactColumnInference.swift
//  Binding
//
//  Works out what each column of an arbitrary spreadsheet actually contains.
//  Two independent signals are combined: what the header says (Norwegian,
//  Danish, Swedish and English synonyms) and what the values look like. Either
//  one alone is enough — a column headed "Mobil" full of blanks still maps, and
//  a header-less column full of +47 numbers still maps.
//
//  The result is always a proposal, never an action: the import surface shows
//  the mapping and its confidence and lets the user correct it before anything
//  is written into their entity.
//

import Foundation

// MARK: - Fields

nonisolated public enum HavenContactField: String, Codable, CaseIterable, Sendable {
    case fullName
    case givenName
    case familyName
    case email
    case phone
    case organization
    case jobTitle
    /// What the person does *in this particular list* — «Oppgave i nettverket»,
    /// «verv», «rolle i prosjektet». Distinct from `jobTitle`, which is what
    /// they do for a living. A project roster usually carries both, and
    /// conflating them loses the thing you actually sort on when inviting.
    case projectRole
    /// The sub-community inside the list — a working group, a track, a table.
    /// Becomes a declared interest *and* the group on the person's role.
    case group
    case url
    case handle
    case notes
    case tags
    case purpose
    case city
    case country
    case entityRef
    case ignore

    /// Several columns may feed these; the rest take at most one column.
    public var isMultiValued: Bool {
        switch self {
        case .email, .phone, .url, .handle, .notes, .tags, .purpose: return true
        default: return false
        }
    }

    public var endpointKind: HavenEndpointKind? {
        switch self {
        case .email: return .email
        case .phone: return .phone
        case .url: return .url
        case .handle: return .handle
        default: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .fullName: return "Navn"
        case .givenName: return "Fornavn"
        case .familyName: return "Etternavn"
        case .email: return "E-post"
        case .phone: return "Telefon"
        case .organization: return "Organisasjon"
        case .jobTitle: return "Rolle/tittel"
        case .projectRole: return "Oppgave i prosjektet"
        case .group: return "Gruppe"
        case .url: return "Nettadresse"
        case .handle: return "Brukernavn"
        case .notes: return "Notat"
        case .tags: return "Merkelapper"
        case .purpose: return "Formål"
        case .city: return "Sted"
        case .country: return "Land"
        case .entityRef: return "HAVEN-entitet"
        case .ignore: return "Ikke i bruk"
        }
    }
}

// MARK: - Assessment

nonisolated public struct HavenColumnAssessment: Codable, Equatable, Sendable {
    public var columnIndex: Int
    public var header: String
    public var field: HavenContactField
    /// 0…1 overall.
    public var confidence: Double
    public var headerConfidence: Double
    public var valueConfidence: Double
    public var filledFraction: Double
    public var sampleValues: [String]
    /// Plain-language reason, shown next to the mapping in the UI.
    public var reason: String

    public init(
        columnIndex: Int,
        header: String,
        field: HavenContactField,
        confidence: Double,
        headerConfidence: Double,
        valueConfidence: Double,
        filledFraction: Double,
        sampleValues: [String],
        reason: String
    ) {
        self.columnIndex = columnIndex
        self.header = header
        self.field = field
        self.confidence = confidence
        self.headerConfidence = headerConfidence
        self.valueConfidence = valueConfidence
        self.filledFraction = filledFraction
        self.sampleValues = sampleValues
        self.reason = reason
    }
}

nonisolated public struct HavenColumnMapping: Codable, Equatable, Sendable {
    public var assignments: [Int: HavenContactField]
    public var region: String

    public init(assignments: [Int: HavenContactField] = [:], region: String = HavenRelationNormalizer.defaultPhoneRegion) {
        self.assignments = assignments
        self.region = region
    }

    public func columns(for field: HavenContactField) -> [Int] {
        assignments.filter { $0.value == field }.keys.sorted()
    }

    /// A mapping is usable when it can produce at least a name or one endpoint.
    public var isUsable: Bool {
        let identifying: Set<HavenContactField> = [.fullName, .givenName, .familyName, .email, .phone, .handle]
        return assignments.values.contains { identifying.contains($0) }
    }
}

// MARK: - Inference

nonisolated public enum HavenContactColumnInference {

    /// Header synonyms. Matched after diacritic folding and lowercasing, so
    /// "E-post", "e post" and "EPOST" all land on the same entry.
    private static let headerSynonyms: [HavenContactField: [String]] = [
        .fullName: ["navn", "fullt navn", "name", "full name", "display name", "visningsnavn", "kontakt", "contact", "person", "kontaktperson", "namn"],
        .givenName: ["fornavn", "first name", "firstname", "given name", "given", "fornamn", "forname", "dopenavn"],
        .familyName: ["etternavn", "last name", "lastname", "surname", "family name", "efternamn", "slektsnavn"],
        .email: ["e post", "epost", "e mail", "email", "mail", "e postadresse", "epostadresse", "email address", "mailadresse", "e mail address", "primary email", "jobbepost", "privat epost"],
        .phone: ["telefon", "telefonnummer", "mobil", "mobilnummer", "mobile", "phone", "phone number", "tlf", "tel", "cell", "cellphone", "mobiltelefon", "nummer", "msisdn", "sms"],
        .organization: ["organisasjon", "organization", "organisation", "firma", "selskap", "bedrift", "company", "employer", "arbeidsgiver", "virksomhet", "org", "kunde", "account"],
        .jobTitle: ["tittel", "title", "stilling", "rolle", "role", "job title", "jobbtittel", "position", "funksjon"],
        .group: ["gruppe", "arbeidsgruppe", "group", "working group", "team", "track", "spor", "workshop", "bord", "table", "undergruppe"],
        .projectRole: ["oppgave", "oppgave i nettverket", "oppgave i prosjektet", "rolle i nettverket", "rolle i prosjektet", "verv", "ansvar", "bidrag", "deltakerrolle", "prosjektrolle", "network role", "project role", "assignment", "responsibility"],
        .url: ["nettside", "nettadresse", "url", "website", "web", "hjemmeside", "link", "lenke", "linkedin", "profil", "profile"],
        .handle: ["brukernavn", "username", "handle", "alias", "konto", "account name", "social", "instagram", "x", "mastodon", "signal"],
        .notes: ["notat", "notater", "note", "notes", "kommentar", "comment", "comments", "merknad", "beskrivelse", "description", "bakgrunn", "context", "kontekst"],
        .tags: ["merkelapp", "merkelapper", "tag", "tags", "kategori", "kategorier", "category", "categories", "liste", "list", "segment", "interesser", "interests", "stikkord", "emneord", "labels"],
        .purpose: ["formal", "formaal", "purpose", "hensikt", "hvorfor", "anledning", "onske", "behov", "mal", "goal"],
        .city: ["sted", "by", "city", "poststed", "town", "lokasjon", "location", "kommune"],
        .country: ["land", "country", "nasjon", "nation"],
        .entityRef: ["haven", "entitet", "entity", "entityref", "haven id", "haven entity", "cell", "endpoint"]
    ]

    /// How strongly the *values* of a column indicate a field.
    private static func valueScore(for field: HavenContactField, values: [String], region: String) -> Double {
        let filled = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !filled.isEmpty else { return 0 }
        let total = Double(filled.count)

        func fraction(_ predicate: (String) -> Bool) -> Double {
            Double(filled.filter(predicate).count) / total
        }

        switch field {
        case .email:
            return fraction { HavenRelationNormalizer.looksLikeEmail($0) }
        case .phone:
            return fraction { HavenRelationNormalizer.looksLikePhone($0, region: region) }
        case .url:
            // Exclude e-mail so a mail column never reads as a link column.
            return fraction {
                !HavenRelationNormalizer.looksLikeEmail($0) && HavenRelationNormalizer.normalizeURL($0) != nil
            }
        case .handle:
            return fraction { HavenRelationNormalizer.normalizeHandle($0) != nil }
        case .fullName:
            // Two or three capitalised words, no digits, no identifiers.
            return fraction { value in
                guard !HavenRelationNormalizer.looksLikeEmail(value),
                      !HavenRelationNormalizer.looksLikePhone(value, region: region),
                      !value.contains(where: \.isNumber) else { return false }
                let words = value.split(whereSeparator: { $0.isWhitespace })
                guard words.count >= 2, words.count <= 4 else { return false }
                return words.allSatisfy { $0.first?.isUppercase == true }
            } * 0.8
        case .givenName, .familyName:
            // A single capitalised word. Weak on its own — the header decides.
            return fraction { value in
                guard !value.contains(where: \.isNumber), !value.contains("@") else { return false }
                let words = value.split(whereSeparator: { $0.isWhitespace })
                return words.count == 1 && words[0].first?.isUppercase == true && words[0].count >= 2
            } * 0.35
        case .country:
            let known: Set<String> = ["norge", "norway", "no", "sverige", "sweden", "se", "danmark", "denmark", "dk", "finland", "fi", "island", "iceland", "is", "tyskland", "germany", "de", "uk", "united kingdom", "usa", "united states", "nederland", "netherlands", "nl", "frankrike", "france", "fr"]
            return fraction { known.contains(HavenRelationNormalizer.fold($0)) }
        case .notes:
            // Long free text.
            return fraction { $0.count > 60 } * 0.6
        case .tags:
            // Short comma/semicolon separated lists.
            return fraction { value in
                let separators = value.filter { $0 == "," || $0 == ";" || $0 == "|" }.count
                return separators >= 1 && value.count < 120 && !value.contains("@")
            } * 0.5
        case .entityRef:
            return fraction { $0.hasPrefix("cell://") || $0.hasPrefix("haven://") }
        case .organization, .jobTitle, .projectRole, .group, .purpose, .city, .ignore:
            return 0
        }
    }

    private static func headerScore(for field: HavenContactField, header: String) -> Double {
        let normalized = normalizeHeader(header)
        guard !normalized.isEmpty else { return 0 }
        guard let synonyms = headerSynonyms[field] else { return 0 }
        if synonyms.contains(normalized) { return 1.0 }
        // Whole-word containment, so "mobil" matches "mobil (privat)" but
        // "no" does not match "notat".
        let headerTokens = Set(normalized.split(separator: " ").map(String.init))
        for synonym in synonyms {
            let synonymTokens = synonym.split(separator: " ").map(String.init)
            if synonymTokens.allSatisfy({ headerTokens.contains($0) }) {
                return synonymTokens.count > 1 ? 0.92 : 0.80
            }
        }
        for synonym in synonyms where synonym.count >= 5 && normalized.contains(synonym) {
            return 0.66
        }
        return 0
    }

    private static func normalizeHeader(_ header: String) -> String {
        let folded = HavenRelationNormalizer.fold(header)
        let cleaned = folded.map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(cleaned)
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Produces one assessment per column plus the mapping that follows from
    /// them. Greedy by score, so the strongest evidence claims its field first.
    public static func infer(
        document: HavenTabularDocument,
        region: String = HavenRelationNormalizer.defaultPhoneRegion,
        sampleLimit: Int = 200
    ) -> (mapping: HavenColumnMapping, assessments: [HavenColumnAssessment]) {

        let columnCount = max(document.headers.count, document.rows.map(\.count).max() ?? 0)
        guard columnCount > 0 else {
            return (HavenColumnMapping(region: region), [])
        }

        let sample = Array(document.rows.prefix(sampleLimit))

        struct Candidate {
            var column: Int
            var field: HavenContactField
            var score: Double
            var headerScore: Double
            var valueScore: Double
        }

        var candidates: [Candidate] = []
        var columnValues: [[String]] = []
        var filledFractions: [Double] = []

        for column in 0..<columnCount {
            let values = sample.map { row -> String in
                column < row.count ? row[column] : ""
            }
            columnValues.append(values)
            let filled = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            filledFractions.append(values.isEmpty ? 0 : Double(filled.count) / Double(values.count))

            let header = column < document.headers.count ? document.headers[column] : ""
            for field in HavenContactField.allCases where field != .ignore {
                let headerScore = document.headersWereSynthesised ? 0 : Self.headerScore(for: field, header: header)
                let valueScore = Self.valueScore(for: field, values: values, region: region)
                guard headerScore > 0 || valueScore > 0 else { continue }

                // Header and values reinforce each other; either alone can carry
                // a column, but agreement is what produces high confidence.
                let combined: Double
                if headerScore > 0 && valueScore > 0 {
                    combined = min(1.0, headerScore * 0.6 + valueScore * 0.4 + 0.1)
                } else if headerScore > 0 {
                    combined = headerScore * 0.85
                } else {
                    combined = valueScore * 0.75
                }
                candidates.append(Candidate(
                    column: column,
                    field: field,
                    score: combined,
                    headerScore: headerScore,
                    valueScore: valueScore
                ))
            }
        }

        candidates.sort { lhs, rhs in
            if abs(lhs.score - rhs.score) > 0.0001 { return lhs.score > rhs.score }
            if lhs.column != rhs.column { return lhs.column < rhs.column }
            return lhs.field.rawValue < rhs.field.rawValue
        }

        let threshold = 0.34
        var mapping = HavenColumnMapping(region: region)
        var takenColumns = Set<Int>()
        var takenFields = Set<HavenContactField>()
        var chosen: [Int: Candidate] = [:]

        for candidate in candidates where candidate.score >= threshold {
            guard !takenColumns.contains(candidate.column) else { continue }
            if !candidate.field.isMultiValued && takenFields.contains(candidate.field) { continue }
            mapping.assignments[candidate.column] = candidate.field
            chosen[candidate.column] = candidate
            takenColumns.insert(candidate.column)
            takenFields.insert(candidate.field)
        }

        // A full name column plus separate given/family columns is redundant;
        // prefer the split pair, which carries more information.
        if !mapping.columns(for: .givenName).isEmpty,
           !mapping.columns(for: .familyName).isEmpty,
           let fullNameColumn = mapping.columns(for: .fullName).first,
           (chosen[fullNameColumn]?.headerScore ?? 0) < 0.9 {
            mapping.assignments[fullNameColumn] = .ignore
        }

        var assessments: [HavenColumnAssessment] = []
        for column in 0..<columnCount {
            let header = column < document.headers.count ? document.headers[column] : "Kolonne \(column + 1)"
            let field = mapping.assignments[column] ?? .ignore
            let candidate = chosen[column]
            let nonEmptyValues: [String] = columnValues[column]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let samples: [String] = Array(nonEmptyValues.prefix(3))
            assessments.append(HavenColumnAssessment(
                columnIndex: column,
                header: header,
                field: field,
                confidence: candidate?.score ?? 0,
                headerConfidence: candidate?.headerScore ?? 0,
                valueConfidence: candidate?.valueScore ?? 0,
                filledFraction: filledFractions[column],
                sampleValues: samples,
                reason: reason(
                    field: field,
                    headerScore: candidate?.headerScore ?? 0,
                    valueScore: candidate?.valueScore ?? 0
                )
            ))
        }

        return (mapping, assessments)
    }

    private static func reason(
        field: HavenContactField,
        headerScore: Double,
        valueScore: Double
    ) -> String {
        guard field != .ignore else {
            return "Ingen tydelig match — kolonnen står over med mindre du velger den selv."
        }
        switch (headerScore > 0, valueScore > 0.2) {
        case (true, true):
            return "Overskriften sier \(field.displayName.lowercased()), og verdiene ser slik ut."
        case (true, false):
            return "Overskriften sier \(field.displayName.lowercased())."
        case (false, true):
            return "Verdiene ser ut som \(field.displayName.lowercased()), selv om overskriften ikke sier det."
        case (false, false):
            return "Ingen tydelig match."
        }
    }

    // MARK: Building records

    public struct BuildResult {
        public var records: [HavenRelationRecord]
        /// Row-level problems, kept so the user can see exactly what was
        /// skipped and why rather than a bare count.
        public var problems: [String]
        public var skippedRows: Int
    }

    /// Turns a mapped table into relation records. Rows that yield neither a
    /// name nor a single parseable endpoint are skipped and reported.
    public static func buildRecords(
        document: HavenTabularDocument,
        mapping: HavenColumnMapping,
        source: HavenRelationSource,
        context: String? = nil,
        now: Date = Date()
    ) -> BuildResult {
        // The context a role belongs to is the list itself unless the owner
        // named it. «deltakere.xlsx» is a poor context name, but an honest one.
        let trimmedContext = context?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let roleContext = trimmedContext.isEmpty ? source.label : trimmedContext
        var records: [HavenRelationRecord] = []
        var problems: [String] = []
        var skipped = 0

        let region = mapping.region

        for (offset, row) in document.rows.enumerated() {
            let rowNumber = offset + (document.headersWereSynthesised ? 1 : 2)

            func values(_ field: HavenContactField) -> [String] {
                mapping.columns(for: field).compactMap { index -> String? in
                    guard index < row.count else { return nil }
                    let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : value
                }
            }

            func first(_ field: HavenContactField) -> String? {
                values(field).first
            }

            var endpoints: [HavenRelationEndpoint] = []
            var unparsed: [String] = []

            for field in [HavenContactField.email, .phone, .url, .handle] {
                guard let kind = field.endpointKind else { continue }
                for index in mapping.columns(for: field) {
                    guard index < row.count else { continue }
                    let cell = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cell.isEmpty else { continue }
                    let label = index < document.headers.count ? document.headers[index] : nil
                    // One cell may hold several addresses.
                    for piece in splitMultiValue(cell) {
                        if let endpoint = HavenRelationNormalizer.endpoint(
                            from: piece,
                            preferredKind: kind,
                            label: label,
                            region: region
                        ) {
                            endpoints.append(endpoint)
                        } else {
                            unparsed.append(piece)
                        }
                    }
                }
            }

            let fullName = first(.fullName)
            let givenName = first(.givenName)
            let familyName = first(.familyName)
            let organization = first(.organization)

            let displayName = HavenRelationNormalizer.displayName(
                given: givenName,
                family: familyName,
                full: fullName,
                organization: organization,
                fallbackEndpoint: endpoints.first
            )

            let hasName = fullName != nil || givenName != nil || familyName != nil
            guard hasName || !endpoints.isEmpty else {
                skipped += 1
                if problems.count < 25 {
                    problems.append("Rad \(rowNumber): verken navn eller et endepunkt jeg kunne tolke.")
                }
                continue
            }

            if !unparsed.isEmpty, problems.count < 25 {
                problems.append("Rad \(rowNumber): kunne ikke tolke \(unparsed.prefix(2).joined(separator: ", ")).")
            }

            var tags = values(.tags).flatMap { splitMultiValue($0) }
            tags.append(contentsOf: values(.purpose).flatMap { splitMultiValue($0) })
            if let city = first(.city) { tags.append(city) }
            if let country = first(.country) { tags.append(country) }

            // The role in the project is the thing you sort on when deciding
            // who to invite, so it goes in the tags, not only the note.
            let projectRoles = values(.projectRole).flatMap { splitMultiValue($0) }
            tags.append(contentsOf: projectRoles)
            let groups = values(.group).flatMap { splitMultiValue($0) }
            tags.append(contentsOf: groups)

            // One role per context; the first role and the first group of the
            // row. Extra values are still in the tags, nothing is lost.
            var contextRoles: [HavenRelationContextRole] = []
            if projectRoles.first != nil || groups.first != nil {
                contextRoles.append(HavenRelationContextRole(
                    context: roleContext,
                    role: projectRoles.first,
                    group: groups.first
                ))
            }

            var noteParts = values(.notes)
            if let projectRole = projectRoles.first {
                noteParts.insert(projectRole, at: 0)
            }
            if let jobTitle = first(.jobTitle), let organization {
                noteParts.insert("\(jobTitle), \(organization)", at: 0)
            }

            var record = HavenRelationRecord(
                id: HavenRelationNormalizer.recordID(
                    endpoints: endpoints,
                    displayName: displayName,
                    organization: organization
                ),
                displayName: displayName,
                givenName: givenName,
                familyName: familyName,
                organization: organization,
                jobTitle: first(.jobTitle),
                endpoints: dedupeEndpoints(endpoints),
                contextTags: HavenRelationMerger.dedupePreservingOrder(tags),
                purposeRefs: [],
                notes: noteParts.isEmpty ? nil : noteParts.joined(separator: "\n"),
                sources: [
                    HavenRelationSource(
                        kind: source.kind,
                        label: source.label,
                        batchID: source.batchID,
                        locator: "rad \(rowNumber)",
                        importedAt: source.importedAt
                    )
                ],
                contextRoles: contextRoles.isEmpty ? nil : contextRoles,
                entityRef: first(.entityRef),
                confidence: confidence(hasName: hasName, endpoints: endpoints),
                createdAt: now,
                updatedAt: now
            )
            if record.entityRef?.isEmpty == true { record.entityRef = nil }
            records.append(record)
        }

        problems.append(contentsOf: sharedEndpointProblems(in: records))
        return BuildResult(records: records, problems: problems, skippedRows: skipped)
    }

    /// Rows that share a phone number but disagree on who they are. HAVEN
    /// keeps them apart — a shared line is not the same person — but the
    /// owner should hear about it, because in a hand-maintained list it
    /// almost always means one of the two numbers was typed into the wrong
    /// row. Reported against the file, where it can still be corrected.
    static func sharedEndpointProblems(in records: [HavenRelationRecord]) -> [String] {
        var byPhone: [String: [HavenRelationRecord]] = [:]
        for record in records {
            for endpoint in record.endpoints where endpoint.kind == .phone {
                byPhone[endpoint.normalized, default: []].append(record)
            }
        }
        var problems: [String] = []
        for (number, sharing) in byPhone.sorted(by: { $0.key < $1.key }) where sharing.count > 1 {
            var distinct: [HavenRelationRecord] = []
            for record in sharing where !distinct.contains(where: { HavenRelationMerger.looksLikeSamePerson($0, record) }) {
                distinct.append(record)
            }
            guard distinct.count > 1 else { continue }
            let names = distinct.map { record -> String in
                let organization = record.organization?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return organization.isEmpty ? record.displayName : "\(record.displayName) (\(organization))"
            }
            problems.append(
                "\(names.joined(separator: " og ")) står med samme telefonnummer \(number). "
                    + "Jeg legger dem inn som forskjellige personer — sjekk om ett av numrene skal være et annet."
            )
        }
        return problems
    }

    /// vCard has richer structure than a table, so it gets its own path rather
    /// than being flattened into columns first.
    public static func buildRecords(
        cards: [HavenVCardParser.Card],
        source: HavenRelationSource,
        region: String = HavenRelationNormalizer.defaultPhoneRegion,
        now: Date = Date()
    ) -> BuildResult {
        var records: [HavenRelationRecord] = []
        var problems: [String] = []
        var skipped = 0

        for (offset, card) in cards.enumerated() {
            var endpoints: [HavenRelationEndpoint] = []
            for entry in card.endpoints {
                if let endpoint = HavenRelationNormalizer.endpoint(
                    from: entry.value,
                    preferredKind: entry.kind,
                    label: entry.label,
                    region: region
                ) {
                    endpoints.append(endpoint)
                }
            }
            let displayName = HavenRelationNormalizer.displayName(
                given: card.givenName,
                family: card.familyName,
                full: card.fullName,
                organization: card.organization,
                fallbackEndpoint: endpoints.first
            )
            let hasName = card.fullName != nil || card.givenName != nil || card.familyName != nil
            guard hasName || !endpoints.isEmpty else {
                skipped += 1
                if problems.count < 25 {
                    problems.append("vCard \(offset + 1): verken navn eller endepunkt.")
                }
                continue
            }
            records.append(HavenRelationRecord(
                id: HavenRelationNormalizer.recordID(
                    endpoints: endpoints,
                    displayName: displayName,
                    organization: card.organization
                ),
                displayName: displayName,
                givenName: card.givenName,
                familyName: card.familyName,
                organization: card.organization,
                jobTitle: card.jobTitle,
                endpoints: dedupeEndpoints(endpoints),
                contextTags: HavenRelationMerger.dedupePreservingOrder(card.categories),
                notes: card.notes,
                sources: [
                    HavenRelationSource(
                        kind: source.kind,
                        label: source.label,
                        batchID: source.batchID,
                        locator: "vCard \(offset + 1)",
                        importedAt: source.importedAt
                    )
                ],
                confidence: confidence(hasName: hasName, endpoints: endpoints),
                createdAt: now,
                updatedAt: now
            ))
        }
        return BuildResult(records: records, problems: problems, skippedRows: skipped)
    }

    private static func confidence(hasName: Bool, endpoints: [HavenRelationEndpoint]) -> Double {
        var value = 0.3
        if hasName { value += 0.3 }
        if endpoints.contains(where: { $0.kind == .email }) { value += 0.25 }
        if endpoints.contains(where: { $0.kind == .phone }) { value += 0.15 }
        return min(1.0, value)
    }

    public static func dedupeEndpoints(_ endpoints: [HavenRelationEndpoint]) -> [HavenRelationEndpoint] {
        var seen = Set<String>()
        var result: [HavenRelationEndpoint] = []
        for endpoint in endpoints {
            let key = "\(endpoint.kind.rawValue)|\(endpoint.normalized)"
            if seen.insert(key).inserted { result.append(endpoint) }
        }
        return result
    }

    /// Splits "a@b.no; c@d.no" or "sales, marketing" into pieces, while leaving
    /// a value that merely contains a comma inside a quoted phrase alone.
    public static func splitMultiValue(_ value: String) -> [String] {
        let separators: Set<Character> = [";", ",", "|", "\n"]
        guard value.contains(where: { separators.contains($0) }) else { return [value] }
        return value
            .split(whereSeparator: { separators.contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
