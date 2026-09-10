// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  HavenResidencyKit.swift
//  Binding
//
//  Where my entity data lives, and how I decide where it should live instead.
//
//  The model is deliberately plain: exactly one location per dataset is
//  authoritative, everything else is a cache or a backup with a stated
//  staleness, and the user's own weighting over availability, latency, cost,
//  jurisdiction and independence produces a ranking they can read and argue
//  with. No hidden scoring, no "optimal" answer handed down.
//

import Foundation
import CellBase

// MARK: - Locations

nonisolated public enum HavenResidencyKind: String, Codable, Sendable, CaseIterable {
    /// Inside the app container on this device.
    case deviceLocal
    /// A folder the user picked — iCloud Drive, a NAS mount, a synced folder.
    case userFolder
    /// A CellScaffold that holds the data on the user's behalf.
    case scaffold

    public var displayName: String {
        switch self {
        case .deviceLocal: return "Denne enheten"
        case .userFolder: return "Mappe du har valgt"
        case .scaffold: return "Scaffold"
        }
    }

    /// Whether this runtime can actually move bytes there by itself.
    public var supportsDirectWrite: Bool {
        switch self {
        case .deviceLocal, .userFolder: return true
        case .scaffold: return false
        }
    }
}

nonisolated public struct HavenResidencyLocation: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var kind: HavenResidencyKind
    /// `cell://`, `https://` or a file path, depending on kind.
    public var endpoint: String
    /// Who operates it. "Meg selv" is a legitimate and important answer.
    public var custodian: String
    /// ISO country code, or empty when it genuinely does not apply.
    public var jurisdiction: String
    /// Declared uptime as a fraction, e.g. 0.999.
    public var availabilityClass: Double
    /// Round-trip median in milliseconds, measured or declared.
    public var latencyMsP50: Double
    /// Currency-neutral monthly cost per GiB. 0 for somewhere you already own.
    public var pricePerGiBMonth: Double
    public var encryptedAtRest: Bool
    /// Can I take the data and leave without asking anyone? 0…1.
    public var independence: Double
    public var notes: String?
    public var lastVerifiedAt: Date?

    public init(
        id: String,
        label: String,
        kind: HavenResidencyKind,
        endpoint: String,
        custodian: String,
        jurisdiction: String = "",
        availabilityClass: Double = 0.99,
        latencyMsP50: Double = 50,
        pricePerGiBMonth: Double = 0,
        encryptedAtRest: Bool = true,
        independence: Double = 1.0,
        notes: String? = nil,
        lastVerifiedAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.endpoint = endpoint
        self.custodian = custodian
        self.jurisdiction = jurisdiction
        self.availabilityClass = availabilityClass
        self.latencyMsP50 = latencyMsP50
        self.pricePerGiBMonth = pricePerGiBMonth
        self.encryptedAtRest = encryptedAtRest
        self.independence = independence
        self.notes = notes
        self.lastVerifiedAt = lastVerifiedAt
    }
}

// MARK: - What the user cares about

nonisolated public enum HavenResidencyCriterion: String, Codable, Sendable, CaseIterable {
    case availability
    case latency
    case cost
    case jurisdiction
    case independence

    public var displayName: String {
        switch self {
        case .availability: return "Tilgjengelighet"
        case .latency: return "Svartid"
        case .cost: return "Pris"
        case .jurisdiction: return "Jurisdiksjon"
        case .independence: return "Uavhengighet"
        }
    }

    public var question: String {
        switch self {
        case .availability: return "Hvor viktig er det at dataene alltid svarer?"
        case .latency: return "Hvor viktig er det at de svarer raskt?"
        case .cost: return "Hvor viktig er det at det er billig?"
        case .jurisdiction: return "Hvor viktig er det hvilket land de ligger i?"
        case .independence: return "Hvor viktig er det at du kan flytte dem uten å spørre noen?"
        }
    }
}

nonisolated public struct HavenResidencyPreferences: Codable, Equatable, Sendable {
    /// 0…1 per criterion. Everything at 0 means "I have no opinion", and the
    /// ranking says so rather than inventing one.
    public var weights: [String: Double]
    /// When non-empty, only these jurisdictions are acceptable at all.
    public var jurisdictionAllowList: [String]
    /// Refuse to recommend anywhere without encryption at rest.
    public var requireEncryptionAtRest: Bool

    public init(
        weights: [String: Double] = HavenResidencyPreferences.defaultWeights,
        jurisdictionAllowList: [String] = [],
        requireEncryptionAtRest: Bool = true
    ) {
        self.weights = weights
        self.jurisdictionAllowList = jurisdictionAllowList
        self.requireEncryptionAtRest = requireEncryptionAtRest
    }

    /// A starting point, not a recommendation: availability and independence
    /// lead because losing access to your own entity is the worst outcome.
    public static let defaultWeights: [String: Double] = [
        HavenResidencyCriterion.availability.rawValue: 0.8,
        HavenResidencyCriterion.latency.rawValue: 0.5,
        HavenResidencyCriterion.cost.rawValue: 0.4,
        HavenResidencyCriterion.jurisdiction.rawValue: 0.6,
        HavenResidencyCriterion.independence.rawValue: 0.9
    ]

    public func weight(_ criterion: HavenResidencyCriterion) -> Double {
        max(0, min(1, weights[criterion.rawValue] ?? 0))
    }

    public var totalWeight: Double {
        HavenResidencyCriterion.allCases.reduce(0) { $0 + weight($1) }
    }
}

// MARK: - Placement

nonisolated public enum HavenReplicaRole: String, Codable, Sendable {
    /// Fast local copy. May be stale; never authoritative.
    case cache
    /// Kept for recovery. Read only when the authoritative copy is gone.
    case backup
}

nonisolated public struct HavenResidencyReplica: Codable, Equatable, Sendable {
    public var locationID: String
    public var role: HavenReplicaRole
    /// After this many seconds without a sync, treat the copy as stale and say
    /// so rather than serving it silently.
    public var staleAfterSeconds: Int
    public var lastSyncedAt: Date?
    public var lastContentHash: String?

    public init(
        locationID: String,
        role: HavenReplicaRole,
        staleAfterSeconds: Int = 86_400,
        lastSyncedAt: Date? = nil,
        lastContentHash: String? = nil
    ) {
        self.locationID = locationID
        self.role = role
        self.staleAfterSeconds = staleAfterSeconds
        self.lastSyncedAt = lastSyncedAt
        self.lastContentHash = lastContentHash
    }

    public func isStale(now: Date = Date()) -> Bool {
        guard let lastSyncedAt else { return true }
        return now.timeIntervalSince(lastSyncedAt) > TimeInterval(staleAfterSeconds)
    }
}

/// One movable body of entity data, and the keypaths that let us read and
/// restore it. Adding a dataset means naming its snapshot pair — nothing else.
nonisolated public struct HavenResidencyDataset: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var cellEndpoint: String
    public var snapshotKeypath: String
    public var restoreKeypath: String

    public init(
        id: String,
        label: String,
        cellEndpoint: String,
        snapshotKeypath: String,
        restoreKeypath: String
    ) {
        self.id = id
        self.label = label
        self.cellEndpoint = cellEndpoint
        self.snapshotKeypath = snapshotKeypath
        self.restoreKeypath = restoreKeypath
    }

    public static let relations = HavenResidencyDataset(
        id: "relations",
        label: "Relasjoner",
        cellEndpoint: "cell:///Relations",
        snapshotKeypath: "relations.snapshot",
        restoreKeypath: "relations.restoreSnapshot"
    )
}

nonisolated public struct HavenResidencyPlacement: Codable, Equatable, Sendable {
    public var datasetID: String
    /// Exactly one. This is the single source of truth.
    public var authoritativeLocationID: String
    public var replicas: [HavenResidencyReplica]
    public var lastContentHash: String?
    public var byteSize: Int
    public var since: Date
    public var lastVerifiedAt: Date?

    public init(
        datasetID: String,
        authoritativeLocationID: String,
        replicas: [HavenResidencyReplica] = [],
        lastContentHash: String? = nil,
        byteSize: Int = 0,
        since: Date = Date(),
        lastVerifiedAt: Date? = nil
    ) {
        self.datasetID = datasetID
        self.authoritativeLocationID = authoritativeLocationID
        self.replicas = replicas
        self.lastContentHash = lastContentHash
        self.byteSize = byteSize
        self.since = since
        self.lastVerifiedAt = lastVerifiedAt
    }
}

// MARK: - Ranking

nonisolated public struct HavenResidencyScore: Equatable, Sendable {
    public var location: HavenResidencyLocation
    public var total: Double
    /// Per-criterion contribution, so the ranking can be read line by line.
    public var contributions: [String: Double]
    public var rawValues: [String: Double]
    public var excluded: Bool
    public var explanation: String
}

nonisolated public enum HavenResidencyRanker {

    /// Min-max normalises each criterion across the candidate set, weights it,
    /// and returns a total plus the per-criterion breakdown.
    ///
    /// Normalising across candidates rather than against absolutes is the
    /// honest choice: "cheapest of these three" is a claim we can support,
    /// "cheap" is not.
    public static func rank(
        locations: [HavenResidencyLocation],
        preferences: HavenResidencyPreferences
    ) -> [HavenResidencyScore] {
        guard !locations.isEmpty else { return [] }

        func normalised(
            _ value: (HavenResidencyLocation) -> Double,
            higherIsBetter: Bool
        ) -> [String: Double] {
            let values = locations.map { ($0.id, value($0)) }
            let numbers = values.map(\.1)
            let low = numbers.min() ?? 0
            let high = numbers.max() ?? 0
            let span = high - low
            var result: [String: Double] = [:]
            for (id, raw) in values {
                // No spread means the criterion cannot discriminate here.
                let scaled = span <= 0.000001 ? 0.5 : (raw - low) / span
                result[id] = higherIsBetter ? scaled : 1 - scaled
            }
            return result
        }

        let availability = normalised({ $0.availabilityClass }, higherIsBetter: true)
        let latency = normalised({ $0.latencyMsP50 }, higherIsBetter: false)
        let cost = normalised({ $0.pricePerGiBMonth }, higherIsBetter: false)
        let independence = normalised({ $0.independence }, higherIsBetter: true)

        let allowList = Set(preferences.jurisdictionAllowList.map { $0.uppercased() })
        let totalWeight = preferences.totalWeight

        return locations.map { location in
            var excluded = false
            var exclusionReasons: [String] = []
            if !allowList.isEmpty {
                let jurisdiction = location.jurisdiction.uppercased()
                if jurisdiction.isEmpty || !allowList.contains(jurisdiction) {
                    excluded = true
                    exclusionReasons.append(
                        jurisdiction.isEmpty
                            ? "vet ikke hvilket land dette er i"
                            : "ligger i \(jurisdiction), som ikke er på listen din"
                    )
                }
            }
            if preferences.requireEncryptionAtRest && !location.encryptedAtRest {
                excluded = true
                exclusionReasons.append("krypterer ikke data i hvile")
            }

            // Jurisdiction scores as a match against the allow list; with no
            // list, everywhere is equally acceptable and it contributes nothing.
            let jurisdictionScore: Double = allowList.isEmpty
                ? 0.5
                : (allowList.contains(location.jurisdiction.uppercased()) ? 1.0 : 0.0)

            let raw: [String: Double] = [
                HavenResidencyCriterion.availability.rawValue: availability[location.id] ?? 0.5,
                HavenResidencyCriterion.latency.rawValue: latency[location.id] ?? 0.5,
                HavenResidencyCriterion.cost.rawValue: cost[location.id] ?? 0.5,
                HavenResidencyCriterion.jurisdiction.rawValue: jurisdictionScore,
                HavenResidencyCriterion.independence.rawValue: independence[location.id] ?? 0.5
            ]

            var contributions: [String: Double] = [:]
            var total = 0.0
            for criterion in HavenResidencyCriterion.allCases {
                let weight = preferences.weight(criterion)
                let contribution = weight * (raw[criterion.rawValue] ?? 0)
                contributions[criterion.rawValue] = contribution
                total += contribution
            }
            if totalWeight > 0 { total /= totalWeight }

            return HavenResidencyScore(
                location: location,
                total: excluded ? 0 : total,
                contributions: contributions,
                rawValues: raw,
                excluded: excluded,
                explanation: excluded
                    ? "Utelukket: \(exclusionReasons.joined(separator: ", "))."
                    : explanation(for: location, contributions: contributions, preferences: preferences)
            )
        }
        .sorted { lhs, rhs in
            if lhs.excluded != rhs.excluded { return !lhs.excluded }
            if abs(lhs.total - rhs.total) > 0.0001 { return lhs.total > rhs.total }
            return lhs.location.label.localizedCaseInsensitiveCompare(rhs.location.label) == .orderedAscending
        }
    }

    /// Names the two criteria that actually decided it, rather than reciting
    /// all five.
    private static func explanation(
        for location: HavenResidencyLocation,
        contributions: [String: Double],
        preferences: HavenResidencyPreferences
    ) -> String {
        guard preferences.totalWeight > 0 else {
            return "Du har ikke sagt hva som betyr noe for deg ennå, så jeg kan ikke rangere dette."
        }
        let ranked = HavenResidencyCriterion.allCases
            .map { ($0, contributions[$0.rawValue] ?? 0) }
            .filter { preferences.weight($0.0) > 0 }
            .sorted { $0.1 > $1.1 }
        guard let best = ranked.first else { return "Ingen kriterier å gå etter." }
        var sentence = "Sterkest på \(best.0.displayName.lowercased())"
        if let weakest = ranked.last, weakest.0 != best.0 {
            sentence += ", svakest på \(weakest.0.displayName.lowercased())"
        }
        let detail: String
        switch location.kind {
        case .deviceLocal:
            detail = "Ligger på enheten: raskest, men borte hvis enheten er borte."
        case .userFolder:
            detail = "Ligger i en mappe du styrer selv."
        case .scaffold:
            detail = "Driftes av \(location.custodian)."
        }
        return sentence + ". " + detail
    }
}

// MARK: - Receipts

/// What happened, signed. The point is that a move is never something the user
/// has to take our word for.
nonisolated public struct HavenResidencyReceipt: Codable, Equatable, Sendable, CanonicalPayloadSignable {
    public var version: Int
    public var receiptID: String
    public var datasetID: String
    public var fromLocationID: String
    public var toLocationID: String
    public var contentHash: String
    public var byteSize: Int
    public var movedAt: String
    /// Did we read the data back from the destination and get the same hash?
    public var readbackVerified: Bool
    /// `completed`, or `pendingAcknowledgement` when the destination has to
    /// confirm before we will call it authoritative.
    public var transferState: String
    public var sourceRetainedAs: String?
    public var note: String?
    public var proof: HavenSignatureProof?

    public init(
        version: Int = 1,
        receiptID: String,
        datasetID: String,
        fromLocationID: String,
        toLocationID: String,
        contentHash: String,
        byteSize: Int,
        movedAt: String,
        readbackVerified: Bool,
        transferState: String,
        sourceRetainedAs: String? = nil,
        note: String? = nil,
        proof: HavenSignatureProof? = nil
    ) {
        self.version = version
        self.receiptID = receiptID
        self.datasetID = datasetID
        self.fromLocationID = fromLocationID
        self.toLocationID = toLocationID
        self.contentHash = contentHash
        self.byteSize = byteSize
        self.movedAt = movedAt
        self.readbackVerified = readbackVerified
        self.transferState = transferState
        self.sourceRetainedAs = sourceRetainedAs
        self.note = note
        self.proof = proof
    }

    public func canonicalPayloadData() throws -> Data {
        try CanonicalPayloadEncoder.data(for: self, excludingTopLevelKeys: ["proof"])
    }
}

// MARK: - Local store

/// Writes and reads dataset snapshots for the locations this runtime can reach
/// directly. Scaffold destinations do not go through here — they get an export
/// bundle and a manifest instead.
nonisolated public enum HavenResidencyLocalStore {

    public enum Failure: Error, CustomStringConvertible {
        case unwritable(String)
        case unreadable(String)
        case hashMismatch

        public var description: String {
            switch self {
            case .unwritable(let detail): return "Kunne ikke skrive til destinasjonen: \(detail)"
            case .unreadable(let detail): return "Kunne ikke lese tilbake fra destinasjonen: \(detail)"
            case .hashMismatch: return "Dataene som kom tilbake fra destinasjonen stemte ikke med det jeg skrev. Flyttingen ble avbrutt."
            }
        }
    }

    public static func directory(for location: HavenResidencyLocation) -> URL? {
        switch location.kind {
        case .deviceLocal:
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            return base.appendingPathComponent("HAVEN/Entity", isDirectory: true)
        case .userFolder:
            let trimmed = location.endpoint.hasPrefix("file://")
                ? String(location.endpoint.dropFirst("file://".count))
                : location.endpoint
            guard !trimmed.isEmpty else { return nil }
            return URL(fileURLWithPath: trimmed, isDirectory: true)
        case .scaffold:
            return nil
        }
    }

    public static func fileURL(for datasetID: String, at location: HavenResidencyLocation) -> URL? {
        directory(for: location)?.appendingPathComponent("\(datasetID).haven.json", isDirectory: false)
    }

    /// Writes, then reads back and compares hashes before reporting success.
    /// A move that cannot be verified is a move that did not happen.
    @discardableResult
    public static func write(
        _ payload: Data,
        datasetID: String,
        to location: HavenResidencyLocation,
        expectedHash: String
    ) throws -> URL {
        guard let directory = directory(for: location),
              let url = fileURL(for: datasetID, at: location) else {
            throw Failure.unwritable("ingen filsti for \(location.label)")
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try payload.write(to: url, options: [.atomic])
        } catch {
            throw Failure.unwritable(error.localizedDescription)
        }
        let readBack: Data
        do {
            readBack = try Data(contentsOf: url)
        } catch {
            throw Failure.unreadable(error.localizedDescription)
        }
        guard hash(readBack) == expectedHash else { throw Failure.hashMismatch }
        return url
    }

    public static func read(datasetID: String, from location: HavenResidencyLocation) throws -> Data {
        guard let url = fileURL(for: datasetID, at: location) else {
            throw Failure.unreadable("ingen filsti for \(location.label)")
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw Failure.unreadable(error.localizedDescription)
        }
    }

    public static func remove(datasetID: String, from location: HavenResidencyLocation) {
        guard let url = fileURL(for: datasetID, at: location) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    public static func hash(_ data: Data) -> String {
        HavenRelationNormalizer.sha256Hex(data.base64EncodedString())
    }
}
