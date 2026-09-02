// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  HavenRelationKit.swift
//  Binding
//
//  Platform-neutral core for HAVEN relations: the record model, endpoint
//  normalisation, deterministic identity derivation, merge rules, table and
//  vCard parsing, a dependency-free XLSX reader and column inference.
//
//  Deliberately free of UIKit/AppKit/Contacts so this file can be promoted to
//  CellProtocol/CellBase unchanged. The only conditional dependency is
//  `Compression`, which is guarded and degrades to a precise error.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
#if canImport(Compression)
import Compression
#endif

// MARK: - Endpoints

/// How we can actually reach a person. `other` is kept so an import never
/// silently discards a column the user cared about.
nonisolated public enum HavenEndpointKind: String, Codable, CaseIterable, Sendable {
    case email
    case phone
    case handle
    case url
    case postal
    case other

    /// Whether an invitation can be delivered over this kind today.
    public var isReachable: Bool {
        switch self {
        case .email, .phone: return true
        case .handle, .url, .postal, .other: return false
        }
    }

    /// Higher wins when we pick the default invite channel.
    public var invitePriority: Int {
        switch self {
        case .email: return 100
        case .phone: return 90
        case .handle: return 40
        case .url: return 30
        case .postal: return 10
        case .other: return 0
        }
    }
}

nonisolated public struct HavenRelationEndpoint: Codable, Equatable, Sendable {
    /// Exactly as it appeared in the source. Never rewritten, so we can always
    /// show the user what their own data said.
    public var raw: String
    /// Canonical form used for matching and de-duplication.
    public var normalized: String
    public var kind: HavenEndpointKind
    /// "work", "home", "mobil" … whatever the source called it.
    public var label: String?
    /// True once the person themselves confirmed it (e.g. they accepted an
    /// invite sent here). Import never sets this.
    public var confirmed: Bool
    /// Truncated hash, safe to put in a beacon or an invite ticket audience
    /// binding without leaking the address itself.
    public var disclosureToken: String

    public init(
        raw: String,
        normalized: String,
        kind: HavenEndpointKind,
        label: String? = nil,
        confirmed: Bool = false,
        disclosureToken: String
    ) {
        self.raw = raw
        self.normalized = normalized
        self.kind = kind
        self.label = label
        self.confirmed = confirmed
        self.disclosureToken = disclosureToken
    }

    public var isReachable: Bool { kind.isReachable && !normalized.isEmpty }
}

// MARK: - Provenance

nonisolated public enum HavenRelationSourceKind: String, Codable, Sendable {
    case addressBookPicker
    case addressBookScan
    case fileImport
    case manual
    case nearby
    case inboundInvite
}

/// Where a relation came from. Kept per-source rather than collapsed, so
/// "forget everything that came from that spreadsheet" is answerable.
nonisolated public struct HavenRelationSource: Codable, Equatable, Sendable {
    public var kind: HavenRelationSourceKind
    /// Filename, address book identifier, scaffold endpoint …
    public var label: String
    /// Import batch this arrived in, so a whole import can be rolled back.
    public var batchID: String?
    /// Row number or record index inside the source.
    public var locator: String?
    public var importedAt: Date

    public init(
        kind: HavenRelationSourceKind,
        label: String,
        batchID: String? = nil,
        locator: String? = nil,
        importedAt: Date = Date()
    ) {
        self.kind = kind
        self.label = label
        self.batchID = batchID
        self.locator = locator
        self.importedAt = importedAt
    }
}

// MARK: - Invite lifecycle

nonisolated public enum HavenInviteState: String, Codable, Sendable {
    /// Not in HAVEN, never invited.
    case none
    /// Ticket minted, not yet handed to a channel.
    case prepared
    /// User actually pressed send.
    case sent
    /// Landing page reported the ticket was opened.
    case opened
    /// They have an entity now.
    case joined
    case declined
    /// Do not contact. Survives re-import.
    case blocked

    public var allowsNewInvite: Bool {
        switch self {
        case .none, .prepared, .declined: return true
        case .sent, .opened, .joined, .blocked: return false
        }
    }
}

/// What the person does in one of *my* contexts — the book project, a
/// conference, a network. One person, many contexts, each with its own role
/// and sub-group. This is what you sort on when deciding whom to invite.
nonisolated public struct HavenRelationContextRole: Codable, Equatable, Sendable {
    public var context: String
    public var role: String?
    public var group: String?

    public init(context: String, role: String? = nil, group: String? = nil) {
        self.context = context
        self.role = role
        self.group = group
    }
}

// MARK: - The record

nonisolated public struct HavenRelationRecord: Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var givenName: String?
    public var familyName: String?
    public var organization: String?
    public var jobTitle: String?
    public var endpoints: [HavenRelationEndpoint]
    /// Free tags harvested from the source (interests, segments, list names).
    public var contextTags: [String]
    /// Portable purpose references, when the source carried something we could
    /// map. Empty is the honest default — we do not invent purposes.
    public var purposeRefs: [String]
    public var notes: String?
    public var sources: [HavenRelationSource]
    /// Roles per context. Optional only so state persisted before the field
    /// existed still decodes; read it through `roles`.
    public var contextRoles: [HavenRelationContextRole]?
    /// Set once this person exists in HAVEN.
    public var entityRef: String?
    /// Pointer into our own EntityRepresentation graph.
    public var representationKeypath: String?
    public var inviteState: HavenInviteState
    public var lastInviteAt: Date?
    public var lastInviteChannel: String?
    public var lastInviteTicketID: String?
    /// 0…1. How sure we are that this record describes one real person.
    public var confidence: Double
    /// Ids of records that look like the same person but were not safe to
    /// auto-merge (name-only overlap).
    public var possibleDuplicateIDs: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        displayName: String,
        givenName: String? = nil,
        familyName: String? = nil,
        organization: String? = nil,
        jobTitle: String? = nil,
        endpoints: [HavenRelationEndpoint] = [],
        contextTags: [String] = [],
        purposeRefs: [String] = [],
        notes: String? = nil,
        sources: [HavenRelationSource] = [],
        contextRoles: [HavenRelationContextRole]? = nil,
        entityRef: String? = nil,
        representationKeypath: String? = nil,
        inviteState: HavenInviteState = .none,
        lastInviteAt: Date? = nil,
        lastInviteChannel: String? = nil,
        lastInviteTicketID: String? = nil,
        confidence: Double = 0.5,
        possibleDuplicateIDs: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.givenName = givenName
        self.familyName = familyName
        self.organization = organization
        self.jobTitle = jobTitle
        self.endpoints = endpoints
        self.contextTags = contextTags
        self.purposeRefs = purposeRefs
        self.notes = notes
        self.sources = sources
        self.contextRoles = contextRoles
        self.entityRef = entityRef
        self.representationKeypath = representationKeypath
        self.inviteState = inviteState
        self.lastInviteAt = lastInviteAt
        self.lastInviteChannel = lastInviteChannel
        self.lastInviteTicketID = lastInviteTicketID
        self.confidence = confidence
        self.possibleDuplicateIDs = possibleDuplicateIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var roles: [HavenRelationContextRole] {
        get { contextRoles ?? [] }
        set { contextRoles = newValue.isEmpty ? nil : newValue }
    }

    /// Already represented in HAVEN — nothing to invite.
    public var isInHaven: Bool {
        entityRef?.isEmpty == false || inviteState == .joined
    }

    public var reachableEndpoints: [HavenRelationEndpoint] {
        endpoints.filter { $0.isReachable }
            .sorted { $0.kind.invitePriority > $1.kind.invitePriority }
    }

    /// The three things that decide whether "inviter Vegar" can succeed.
    public var inviteReadiness: (canInvite: Bool, reason: String) {
        if inviteState == .blocked {
            return (false, "Denne kontakten er blokkert for invitasjoner.")
        }
        if isInHaven {
            return (false, "\(displayName) er allerede representert i HAVEN.")
        }
        guard !reachableEndpoints.isEmpty else {
            return (false, "Jeg har ingen e-post eller telefon å sende til for \(displayName).")
        }
        if !inviteState.allowsNewInvite {
            return (false, "Invitasjonen er allerede sendt til \(displayName).")
        }
        return (true, "Klar til å sende invitasjon.")
    }
}

// MARK: - Normalisation

nonisolated public enum HavenRelationNormalizer {

    /// Region used when a phone number has no country code. Norwegian numbers
    /// dominate the first cohort; callers can override per import.
    public static let defaultPhoneRegion = "NO"

    private static let regionDialCodes: [String: String] = [
        "NO": "47", "SE": "46", "DK": "45", "FI": "358", "IS": "354",
        "GB": "44", "US": "1", "CA": "1", "DE": "49", "FR": "33",
        "NL": "31", "ES": "34", "IT": "39", "PL": "48", "EE": "372",
        "LV": "371", "LT": "370", "IE": "353", "PT": "351", "BE": "32",
        "CH": "41", "AT": "43"
    ]

    /// National significant number lengths we consider plausible, per region.
    private static let regionNationalLengths: [String: Set<Int>] = [
        "NO": [8], "SE": [7, 8, 9], "DK": [8], "FI": [9, 10], "IS": [7],
        "GB": [10], "US": [10], "CA": [10], "DE": [10, 11], "FR": [9],
        "NL": [9], "ES": [9], "IT": [9, 10], "PL": [9], "EE": [7, 8],
        "LV": [8], "LT": [8], "IE": [9], "PT": [9], "BE": [9],
        "CH": [9], "AT": [10, 11]
    ]

    public static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func tokens(_ text: String) -> [String] {
        fold(text)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // MARK: Email

    /// Returns the canonical address, or nil when it is not an address at all.
    /// Deliberately conservative: we lowercase and strip surrounding display
    /// name syntax, but we do NOT strip dots or plus-tags, because for most
    /// providers those are different mailboxes and guessing would merge two
    /// real people.
    public static func normalizeEmail(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("mailto:") { value = String(value.dropFirst("mailto:".count)) }
        // "Ola Nordmann <ola@example.com>"
        if let open = value.lastIndex(of: "<"), let close = value.lastIndex(of: ">"), open < close {
            value = String(value[value.index(after: open)..<close])
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: " \"'<>,;"))
        guard let at = value.lastIndex(of: "@") else { return nil }
        let local = String(value[value.startIndex..<at])
        let domain = String(value[value.index(after: at)...]).lowercased()
        guard !local.isEmpty, !domain.isEmpty else { return nil }
        guard domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else { return nil }
        guard !domain.contains(" "), !local.contains(" ") else { return nil }
        guard domain.split(separator: ".").allSatisfy({ !$0.isEmpty }) else { return nil }
        // A TLD of at least two letters keeps "a@b.c" style noise out.
        guard let tld = domain.split(separator: ".").last, tld.count >= 2,
              tld.allSatisfy({ $0.isLetter }) else { return nil }
        return "\(local.lowercased())@\(domain)"
    }

    public static func looksLikeEmail(_ raw: String) -> Bool {
        normalizeEmail(raw) != nil
    }

    // MARK: Phone

    /// Best-effort E.164. Returns nil rather than guessing when the digits do
    /// not plausibly form a number for the given region — a wrong number in a
    /// contact list is worse than a missing one.
    public static func normalizePhone(_ raw: String, region: String = defaultPhoneRegion) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("tel:") {
            return normalizePhone(String(trimmed.dropFirst("tel:".count)), region: region)
        }
        // Reject things that are clearly not phone numbers before we start
        // throwing characters away.
        if trimmed.contains("@") { return nil }
        // A date survives every digit-based test below — "2026-01-01" strips to
        // eight digits and reads as a Norwegian landline. Spreadsheets are full
        // of date columns, so this has to be refused on shape, not on length.
        if looksLikeCalendarDate(trimmed) { return nil }
        let allowed = CharacterSet(charactersIn: "+0123456789 ()-./\u{00A0}\u{2010}\u{2013}")
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) { return nil }

        var digits = trimmed.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }

        var hasPlus = trimmed.hasPrefix("+")
        if !hasPlus, digits.hasPrefix("00") {
            digits = String(digits.dropFirst(2))
            hasPlus = true
        }

        if hasPlus {
            guard digits.count >= 8, digits.count <= 15 else { return nil }
            return "+\(digits)"
        }

        let dial = regionDialCodes[region.uppercased()] ?? regionDialCodes[defaultPhoneRegion]!
        // Some exports keep the country code but drop the plus.
        if digits.hasPrefix(dial) {
            let rest = String(digits.dropFirst(dial.count))
            if let lengths = regionNationalLengths[region.uppercased()], lengths.contains(rest.count) {
                return "+\(digits)"
            }
        }
        // National trunk prefix (not used in NO, common elsewhere).
        var national = digits
        if national.hasPrefix("0"), region.uppercased() != "NO" {
            national = String(national.drop(while: { $0 == "0" }))
        }
        if let lengths = regionNationalLengths[region.uppercased()], !lengths.contains(national.count) {
            // Unknown shape. Keep it only if it is long enough to be a real
            // international number that simply lost its plus.
            guard national.count >= 10, national.count <= 15 else { return nil }
            return "+\(national)"
        }
        guard national.count >= 5 else { return nil }
        return "+\(dial)\(national)"
    }

    public static func looksLikePhone(_ raw: String, region: String = defaultPhoneRegion) -> Bool {
        normalizePhone(raw, region: region) != nil
    }

    /// ISO dates and the two European written forms. Kept deliberately narrow:
    /// a real number is never written as one-or-two digits, separator, one-or-two
    /// digits, separator, a year — and `415-555-1234` does not match either.
    public static func looksLikeCalendarDate(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        let patterns = [
            "^\\d{4}[-/.]\\d{1,2}[-/.]\\d{1,2}$",
            "^\\d{1,2}[-/.]\\d{1,2}[-/.](\\d{2}|\\d{4})$"
        ]
        return patterns.contains { pattern in
            value.range(of: pattern, options: .regularExpression) != nil
        }
    }

    // MARK: URL / handle

    public static func normalizeURL(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(" ") else { return nil }
        if value.contains("@"), !value.contains("/") { return nil }
        if !value.contains("://") {
            let lowered = value.lowercased()
            guard lowered.hasPrefix("www.") || lowered.contains(".") else { return nil }
            guard let tld = lowered.split(separator: "/").first?.split(separator: ".").last,
                  tld.count >= 2, tld.allSatisfy({ $0.isLetter }) else { return nil }
            value = "https://\(value)"
        }
        guard let components = URLComponents(string: value),
              let host = components.host, host.contains("."),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        var normalized = "\(scheme)://\(host.lowercased())"
        let path = components.path
        if !path.isEmpty, path != "/" {
            normalized += path.hasSuffix("/") ? String(path.dropLast()) : path
        }
        return normalized
    }

    public static func normalizeHandle(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("@"), value.count > 1, !value.contains(" ") else { return nil }
        return value.lowercased()
    }

    // MARK: Endpoint construction

    /// Classifies a raw value and returns a normalised endpoint, or nil when
    /// the value is not a reachable identifier of any known kind.
    public static func endpoint(
        from raw: String,
        preferredKind: HavenEndpointKind? = nil,
        label: String? = nil,
        region: String = defaultPhoneRegion
    ) -> HavenRelationEndpoint? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        func make(_ kind: HavenEndpointKind, _ normalized: String) -> HavenRelationEndpoint {
            HavenRelationEndpoint(
                raw: trimmed,
                normalized: normalized,
                kind: kind,
                label: label,
                confirmed: false,
                disclosureToken: disclosureToken(kind: kind, normalized: normalized)
            )
        }

        // An explicit hint from a mapped column wins, but only if it parses.
        if let preferredKind {
            switch preferredKind {
            case .email:
                if let value = normalizeEmail(trimmed) { return make(.email, value) }
            case .phone:
                if let value = normalizePhone(trimmed, region: region) { return make(.phone, value) }
            case .url:
                if let value = normalizeURL(trimmed) { return make(.url, value) }
            case .handle:
                if let value = normalizeHandle(trimmed) { return make(.handle, value) }
            case .postal:
                return make(.postal, collapseWhitespace(trimmed).lowercased())
            case .other:
                return make(.other, fold(trimmed))
            }
        }

        if let value = normalizeEmail(trimmed) { return make(.email, value) }
        if let value = normalizeHandle(trimmed) { return make(.handle, value) }
        if let value = normalizePhone(trimmed, region: region) { return make(.phone, value) }
        if let value = normalizeURL(trimmed) { return make(.url, value) }
        return nil
    }

    /// A short, non-reversible token. Truncation is deliberate: it is enough to
    /// compare two endpoints that both parties already know, and too little to
    /// enumerate an address book from a broadcast.
    public static func disclosureToken(kind: HavenEndpointKind, normalized: String) -> String {
        sha256Hex("haven.endpoint.v1|\(kind.rawValue)|\(normalized)").prefix(16).description
    }

    public static func sha256Hex(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Identity of a record

    /// Deterministic id derived from the strongest identifier available, so
    /// re-importing the same spreadsheet twice does not create twins.
    public static func recordID(
        endpoints: [HavenRelationEndpoint],
        displayName: String,
        organization: String?
    ) -> String {
        let ranked = endpoints.sorted { lhs, rhs in
            if lhs.kind.invitePriority != rhs.kind.invitePriority {
                return lhs.kind.invitePriority > rhs.kind.invitePriority
            }
            return lhs.normalized < rhs.normalized
        }
        if let strongest = ranked.first(where: { $0.kind == .email })
            ?? ranked.first(where: { $0.kind == .phone })
            ?? ranked.first(where: { $0.kind == .handle }) {
            return "rel-" + sha256Hex("haven.relation.v1|\(strongest.kind.rawValue)|\(strongest.normalized)").prefix(20)
        }
        let name = fold(collapseWhitespace(displayName))
        let org = fold(collapseWhitespace(organization ?? ""))
        return "rel-" + sha256Hex("haven.relation.v1|name|\(name)|\(org)").prefix(20)
    }

    /// Builds a display name from whatever parts we have, without producing
    /// embarrassing output like a bare comma.
    public static func displayName(
        given: String?,
        family: String?,
        full: String?,
        organization: String?,
        fallbackEndpoint: HavenRelationEndpoint?
    ) -> String {
        if let full = full?.trimmingCharacters(in: .whitespacesAndNewlines), !full.isEmpty {
            return collapseWhitespace(full)
        }
        let parts = [given, family]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if let organization = organization?.trimmingCharacters(in: .whitespacesAndNewlines), !organization.isEmpty {
            return collapseWhitespace(organization)
        }
        if let endpoint = fallbackEndpoint {
            if endpoint.kind == .email, let local = endpoint.normalized.split(separator: "@").first {
                return String(local)
            }
            return endpoint.raw
        }
        return "Ukjent kontakt"
    }
}

// MARK: - Merge

nonisolated public enum HavenRelationMerger {

    /// Two records are the same person only when they share a strong
    /// identifier. Name collisions are recorded as *possible* duplicates and
    /// left for the user, because "Anne Hansen" is not an identifier.
    public static func sharesStrongIdentifier(_ lhs: HavenRelationRecord, _ rhs: HavenRelationRecord) -> Bool {
        let strongKinds: Set<HavenEndpointKind> = [.email, .phone, .handle]
        let left = Set(lhs.endpoints.filter { strongKinds.contains($0.kind) }.map { "\($0.kind.rawValue)|\($0.normalized)" })
        guard !left.isEmpty else { return false }
        for endpoint in rhs.endpoints where strongKinds.contains(endpoint.kind) {
            if left.contains("\(endpoint.kind.rawValue)|\(endpoint.normalized)") { return true }
        }
        return false
    }

    public static func looksLikeSamePerson(_ lhs: HavenRelationRecord, _ rhs: HavenRelationRecord) -> Bool {
        let leftName = HavenRelationNormalizer.fold(HavenRelationNormalizer.collapseWhitespace(lhs.displayName))
        let rightName = HavenRelationNormalizer.fold(HavenRelationNormalizer.collapseWhitespace(rhs.displayName))
        guard !leftName.isEmpty, leftName == rightName else { return false }
        let leftOrg = HavenRelationNormalizer.fold(lhs.organization ?? "")
        let rightOrg = HavenRelationNormalizer.fold(rhs.organization ?? "")
        if !leftOrg.isEmpty, !rightOrg.isEmpty { return leftOrg == rightOrg }
        return true
    }

    /// Merges `incoming` into `existing`. The existing record wins on anything
    /// the user or the person themselves established (invite state, confirmed
    /// endpoints, entityRef); the incoming record fills gaps and adds sources.
    public static func merge(
        existing: HavenRelationRecord,
        incoming: HavenRelationRecord,
        now: Date = Date()
    ) -> HavenRelationRecord {
        var merged = existing

        if merged.displayName.isEmpty || merged.displayName == "Ukjent kontakt" {
            merged.displayName = incoming.displayName
        }
        merged.givenName = merged.givenName ?? incoming.givenName
        merged.familyName = merged.familyName ?? incoming.familyName
        merged.organization = merged.organization ?? incoming.organization
        merged.jobTitle = merged.jobTitle ?? incoming.jobTitle
        merged.entityRef = merged.entityRef ?? incoming.entityRef
        merged.representationKeypath = merged.representationKeypath ?? incoming.representationKeypath

        // Endpoints: union by (kind, normalized). A confirmed endpoint never
        // gets downgraded by a later unconfirmed import.
        var byKey: [String: HavenRelationEndpoint] = [:]
        var order: [String] = []
        for endpoint in merged.endpoints + incoming.endpoints {
            let key = "\(endpoint.kind.rawValue)|\(endpoint.normalized)"
            if var current = byKey[key] {
                current.confirmed = current.confirmed || endpoint.confirmed
                current.label = current.label ?? endpoint.label
                byKey[key] = current
            } else {
                byKey[key] = endpoint
                order.append(key)
            }
        }
        merged.endpoints = order.compactMap { byKey[$0] }

        merged.contextTags = dedupePreservingOrder(merged.contextTags + incoming.contextTags)
        // Roles merge per context: a newer file can add a role or a group, but
        // never silently drop one the owner already knew about.
        var roles = merged.roles
        for role in incoming.roles {
            if let index = roles.firstIndex(where: { $0.context == role.context }) {
                roles[index].role = role.role ?? roles[index].role
                roles[index].group = role.group ?? roles[index].group
            } else {
                roles.append(role)
            }
        }
        merged.roles = roles
        merged.purposeRefs = dedupePreservingOrder(merged.purposeRefs + incoming.purposeRefs)

        if let incomingNotes = incoming.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !incomingNotes.isEmpty {
            if let existingNotes = merged.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !existingNotes.isEmpty {
                if !existingNotes.contains(incomingNotes) {
                    merged.notes = existingNotes + "\n" + incomingNotes
                }
            } else {
                merged.notes = incomingNotes
            }
        }

        // Provenance is append-only, deduplicated on the tuple that identifies
        // one actual import event.
        var seenSources = Set(merged.sources.map(sourceKey))
        for source in incoming.sources where !seenSources.contains(sourceKey(source)) {
            merged.sources.append(source)
            seenSources.insert(sourceKey(source))
        }

        // Never let a re-import resurrect a blocked contact or un-join someone.
        if merged.inviteState == .blocked || merged.inviteState == .joined {
            // keep
        } else if incoming.inviteState == .blocked || incoming.inviteState == .joined {
            merged.inviteState = incoming.inviteState
        }

        merged.confidence = min(1.0, max(merged.confidence, incoming.confidence) + 0.05)
        merged.possibleDuplicateIDs = dedupePreservingOrder(merged.possibleDuplicateIDs + incoming.possibleDuplicateIDs)
            .filter { $0 != merged.id }
        merged.updatedAt = now
        return merged
    }

    private static func sourceKey(_ source: HavenRelationSource) -> String {
        "\(source.kind.rawValue)|\(source.label)|\(source.batchID ?? "")|\(source.locator ?? "")"
    }

    public static func dedupePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = HavenRelationNormalizer.fold(trimmed)
            if seen.insert(key).inserted { result.append(trimmed) }
        }
        return result
    }
}

// MARK: - Search

nonisolated public struct HavenRelationMatch: Equatable, Sendable {
    public var record: HavenRelationRecord
    public var score: Double
    /// Why this record matched, in words we can show the user.
    public var reason: String

    public init(record: HavenRelationRecord, score: Double, reason: String) {
        self.record = record
        self.score = score
        self.reason = reason
    }
}

nonisolated public enum HavenRelationMatcher {

    /// Ranks relations against free text such as "vegar", "vegar i kommunen",
    /// "ola@example.com" or "+4790000000".
    ///
    /// Deterministic and explainable on purpose — this is the path a prompt
    /// like "inviter Vegar" runs through, and the user must be able to see why
    /// a given person came up.
    public static func search(
        query: String,
        in records: [HavenRelationRecord],
        limit: Int = 10,
        region: String = HavenRelationNormalizer.defaultPhoneRegion
    ) -> [HavenRelationMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return records
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(limit)
                .map { HavenRelationMatch(record: $0, score: 0.0, reason: "Nylig oppdatert.") }
        }

        // An exact endpoint in the query beats everything else.
        if let endpoint = HavenRelationNormalizer.endpoint(from: trimmed, region: region) {
            let exact = records.filter { record in
                record.endpoints.contains { $0.kind == endpoint.kind && $0.normalized == endpoint.normalized }
            }
            if !exact.isEmpty {
                return exact.map {
                    HavenRelationMatch(record: $0, score: 1.0, reason: "Eksakt treff på \(endpoint.kind.rawValue).")
                }
            }
        }

        let queryTokens = HavenRelationNormalizer.tokens(trimmed)
        guard !queryTokens.isEmpty else { return [] }

        var matches: [HavenRelationMatch] = []
        for record in records {
            var score = 0.0
            var reasons: [String] = []

            let nameTokens = HavenRelationNormalizer.tokens(record.displayName)
            let orgTokens = HavenRelationNormalizer.tokens(record.organization ?? "")
            let titleTokens = HavenRelationNormalizer.tokens(record.jobTitle ?? "")
            let tagTokens = record.contextTags.flatMap { HavenRelationNormalizer.tokens($0) }
            let endpointTokens = record.endpoints.flatMap { HavenRelationNormalizer.tokens($0.normalized) }

            var nameHits = 0
            for token in queryTokens {
                if nameTokens.contains(token) {
                    score += 0.45; nameHits += 1
                } else if nameTokens.contains(where: { $0.hasPrefix(token) && token.count >= 2 }) {
                    score += 0.30; nameHits += 1
                }
                if orgTokens.contains(token) { score += 0.18; reasons.append("organisasjon") }
                if titleTokens.contains(token) { score += 0.12; reasons.append("rolle") }
                if tagTokens.contains(token) { score += 0.12; reasons.append("merkelapp") }
                if endpointTokens.contains(token) { score += 0.20; reasons.append("endepunkt") }
            }
            guard score > 0 else { continue }

            if nameHits > 0 {
                reasons.insert(nameHits == queryTokens.count ? "hele navnet" : "navn", at: 0)
            }
            // Matching every query token is much stronger than matching one.
            let coverage = Double(nameHits) / Double(queryTokens.count)
            score += coverage * 0.25
            // Someone we can actually reach should sort above someone we cannot.
            if !record.reachableEndpoints.isEmpty { score += 0.05 }
            if record.isInHaven { score += 0.03 }

            matches.append(HavenRelationMatch(
                record: record,
                score: min(1.0, score),
                reason: "Treff på " + HavenRelationMerger.dedupePreservingOrder(reasons).joined(separator: ", ") + "."
            ))
        }

        return matches
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.0001 { return lhs.score > rhs.score }
                return lhs.record.displayName.localizedCaseInsensitiveCompare(rhs.record.displayName) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}
