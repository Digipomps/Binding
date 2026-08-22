// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  EntityResidencyCell.swift
//  Binding
//
//  Decides and records where the entity's data lives.
//
//  Data starts wherever it was imported. From there the owner can move it to
//  somewhere with better availability, lower latency, a better price, or a
//  jurisdiction they trust — weighted the way *they* weight it, not the way we
//  guess. One location is authoritative at a time; the rest are caches and
//  backups with a stated staleness. Every move produces a signed receipt.
//

import Foundation
import CellBase

final class BindingEntityResidencyCell: GeneralCell {
    static let endpoint = "cell:///EntityResidency"
    static let sourceCellName = "BindingEntityResidencyCell"

    private enum CodingKeys: String, CodingKey {
        case locations
        case datasets
        case placements
        case preferences
        case receipts
        case lastPlan
        case lastResult
    }

    private let stateQueue = DispatchQueue(label: "Binding.BindingEntityResidencyCell.State")

    private nonisolated(unsafe) var locations: [HavenResidencyLocation] = []
    private nonisolated(unsafe) var datasets: [HavenResidencyDataset] = [.relations]
    private nonisolated(unsafe) var placements: [HavenResidencyPlacement] = []
    private nonisolated(unsafe) var preferences = HavenResidencyPreferences()
    private nonisolated(unsafe) var receipts: [HavenResidencyReceipt] = []
    private nonisolated(unsafe) var lastPlan: Object = [:]
    private nonisolated(unsafe) var lastResult: Object = [:]

    required init(owner: Identity) async {
        await super.init(owner: owner)
        stateQueue.sync {
            if locations.isEmpty { locations = [Self.deviceLocation()] }
            if placements.isEmpty {
                placements = datasets.map {
                    HavenResidencyPlacement(datasetID: $0.id, authoritativeLocationID: Self.deviceLocationID)
                }
            }
            lastResult = HavenValue.ok("Entitetsdataene ligger på denne enheten.", sideEffect: false)
        }
        try? await ensureRuntimeReady()
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        locations = try container.decodeIfPresent([HavenResidencyLocation].self, forKey: .locations) ?? []
        datasets = try container.decodeIfPresent([HavenResidencyDataset].self, forKey: .datasets) ?? [.relations]
        placements = try container.decodeIfPresent([HavenResidencyPlacement].self, forKey: .placements) ?? []
        preferences = try container.decodeIfPresent(HavenResidencyPreferences.self, forKey: .preferences) ?? HavenResidencyPreferences()
        receipts = try container.decodeIfPresent([HavenResidencyReceipt].self, forKey: .receipts) ?? []
        lastPlan = try container.decodeIfPresent(Object.self, forKey: .lastPlan) ?? [:]
        lastResult = try container.decodeIfPresent(Object.self, forKey: .lastResult) ?? [:]
        try super.init(from: decoder)
    }

    override func installCellRuntimeBindingsForAccess() async throws {
        await setup(owner: storedOwnerIdentity)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync {
            (locations, datasets, placements, preferences, receipts, lastPlan, lastResult)
        }
        try container.encode(snapshot.0, forKey: .locations)
        try container.encode(snapshot.1, forKey: .datasets)
        try container.encode(snapshot.2, forKey: .placements)
        try container.encode(snapshot.3, forKey: .preferences)
        try container.encode(snapshot.4, forKey: .receipts)
        try container.encode(snapshot.5, forKey: .lastPlan)
        try container.encode(snapshot.6, forKey: .lastResult)
    }

    private func setup(owner: Identity) async {
        for key in readableKeys {
            agreementTemplate.addGrant("r---", for: key)
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                return self.readValue(for: key)
            }
        }
        for key in writableKeys {
            agreementTemplate.addGrant("rw--", for: key)
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
                return await self.writeValue(for: key, value: value, requester: requester)
            }
        }
    }

    /// Every read is served under both names. A skeleton that references this
    /// cell under the label `residency` binds `residency.criteria`, which asks
    /// this cell for the bare key `criteria` — the label supplies the first
    /// segment. The prefixed form stays for callers that address the cell
    /// directly. `state` was already served both ways; the rest were not, which
    /// is why the criteria list read back notFound.
    private var readableKeys: [String] {
        [
            "state",
            "locations",
            "placements",
            "preferences",
            "criteria",
            "recommendations",
            "receipts",
            "lastPlan",
            "lastResult",
            "residency.state",
            "residency.locations",
            "residency.placements",
            "residency.preferences",
            "residency.criteria",
            "residency.recommendations",
            "residency.receipts",
            "residency.lastPlan",
            "residency.lastResult",
            "providerDescriptor",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    private var writableKeys: [String] {
        [
            "residency.registerLocation",
            "residency.removeLocation",
            "residency.setPreferences",
            "residency.setWeight",
            "residency.plan",
            "residency.move",
            "residency.acknowledgeTransfer",
            "residency.verify",
            "residency.addReplica",
            "residency.removeReplica"
        ]
    }

    private func readValue(for key: String) -> ValueType {
        switch key {
        case "state", "residency.state":
            return .object(stateObject())
        case "locations", "residency.locations":
            return .list(locationRows().map(ValueType.object))
        case "placements", "residency.placements":
            return .list(placementRows().map(ValueType.object))
        case "preferences", "residency.preferences":
            return .object(preferencesObject())
        case "criteria", "residency.criteria":
            return .list(HavenResidencyCriterion.allCases.map { criterion in
                .object([
                    "id": .string(criterion.rawValue),
                    "label": .string(criterion.displayName),
                    "question": .string(criterion.question),
                    "weight": .float(stateQueue.sync { preferences.weight(criterion) })
                ])
            })
        case "recommendations", "residency.recommendations":
            return .list(recommendationRows().map(ValueType.object))
        case "receipts", "residency.receipts":
            return .list(receiptRows().map(ValueType.object))
        case "lastPlan", "residency.lastPlan":
            return .object(stateQueue.sync { lastPlan })
        case "lastResult", "residency.lastResult":
            return .object(stateQueue.sync { lastResult })
        case "providerDescriptor":
            return .object(providerDescriptor())
        case "purposeGoal":
            return .object(purposeGoal())
        case "skeletonConfiguration":
            return .cellConfiguration(Self.menuConfiguration())
        default:
            return .null
        }
    }

    private func writeValue(for key: String, value: ValueType, requester: Identity) async -> ValueType {
        switch key {
        case "residency.registerLocation":
            return .object(registerLocation(value))
        case "residency.removeLocation":
            return .object(removeLocation(value))
        case "residency.setPreferences":
            return .object(setPreferences(value))
        case "residency.setWeight":
            return .object(setWeight(value))
        case "residency.plan":
            return .object(await plan(value, requester: requester))
        case "residency.move":
            return .object(await move(value, requester: requester))
        case "residency.acknowledgeTransfer":
            return .object(acknowledgeTransfer(value))
        case "residency.verify":
            return .object(await verify(value, requester: requester))
        case "residency.addReplica":
            return .object(addReplica(value))
        case "residency.removeReplica":
            return .object(removeReplica(value))
        default:
            return .object(HavenValue.error(code: "unsupported_keypath", message: "Ukjent lokasjons-handling."))
        }
    }

    // MARK: - Locations

    static let deviceLocationID = "device-local"

    private static func deviceLocation() -> HavenResidencyLocation {
        HavenResidencyLocation(
            id: deviceLocationID,
            label: "Denne enheten",
            kind: .deviceLocal,
            endpoint: "file://app-container",
            custodian: "Deg",
            jurisdiction: Locale.current.region?.identifier ?? "",
            availabilityClass: 0.95,
            latencyMsP50: 1,
            pricePerGiBMonth: 0,
            encryptedAtRest: true,
            independence: 1.0,
            notes: "Raskest og helt din, men borte hvis enheten blir borte."
        )
    }

    private func registerLocation(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let label = HavenValue.string(payload["label"]),
              let kindText = HavenValue.string(payload["kind"]),
              let kind = HavenResidencyKind(rawValue: kindText),
              let endpoint = HavenValue.string(payload["endpoint"]) else {
            return HavenValue.error(
                code: "bad_request",
                message: "Trenger `label`, `kind` (deviceLocal, userFolder eller scaffold) og `endpoint`."
            )
        }
        let id = HavenValue.string(payload["id"])
            ?? "loc-\(HavenRelationNormalizer.sha256Hex(kindText + endpoint).prefix(12))"

        let location = HavenResidencyLocation(
            id: id,
            label: label,
            kind: kind,
            endpoint: endpoint,
            custodian: HavenValue.string(payload["custodian"]) ?? "Ukjent",
            jurisdiction: HavenValue.string(payload["jurisdiction"]) ?? "",
            availabilityClass: HavenValue.double(payload["availabilityClass"]) ?? 0.99,
            latencyMsP50: HavenValue.double(payload["latencyMsP50"]) ?? 50,
            pricePerGiBMonth: HavenValue.double(payload["pricePerGiBMonth"]) ?? 0,
            encryptedAtRest: HavenValue.bool(payload["encryptedAtRest"]) ?? true,
            independence: HavenValue.double(payload["independence"]) ?? 0.5,
            notes: HavenValue.string(payload["notes"]),
            lastVerifiedAt: nil
        )
        stateQueue.sync {
            locations.removeAll { $0.id == id }
            locations.append(location)
        }
        let result = HavenValue.ok(
            "\(label) er lagt til som mulig lokasjon.",
            sideEffect: true,
            extra: [
                "locationID": .string(id),
                "canWriteDirectly": .bool(kind.supportsDirectWrite),
                "note": .string(
                    kind.supportsDirectWrite
                        ? ""
                        : "Jeg kan ikke skrive dit selv. En flytting hit lager en eksportpakke og venter på at scaffoldet bekrefter."
                ),
                "recommendations": .list(recommendationRows().map(ValueType.object))
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    private func removeLocation(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let id = HavenValue.string(payload["locationID"]) ?? HavenValue.string(value) else {
            return HavenValue.error(code: "missing_id", message: "Mangler `locationID`.")
        }
        let inUse = stateQueue.sync {
            placements.contains { $0.authoritativeLocationID == id }
        }
        guard !inUse else {
            return HavenValue.error(
                code: "location_in_use",
                message: "Den lokasjonen holder autoritative data. Flytt dem et annet sted først."
            )
        }
        var removed = 0
        stateQueue.sync {
            let before = locations.count
            locations.removeAll { $0.id == id }
            removed = before - locations.count
            for index in placements.indices {
                placements[index].replicas.removeAll { $0.locationID == id }
            }
        }
        return HavenValue.ok(
            removed > 0 ? "Lokasjonen er fjernet." : "Fant ingen lokasjon med den id-en.",
            sideEffect: removed > 0
        )
    }

    // MARK: - Preferences

    private func setPreferences(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        stateQueue.sync {
            if let weights = HavenValue.object(payload["weights"]) {
                for (key, raw) in weights {
                    guard HavenResidencyCriterion(rawValue: key) != nil,
                          let weight = HavenValue.double(raw) else { continue }
                    preferences.weights[key] = max(0, min(1, weight))
                }
            }
            if payload["jurisdictionAllowList"] != nil {
                preferences.jurisdictionAllowList = HavenValue
                    .stringList(payload["jurisdictionAllowList"])
                    .map { $0.uppercased() }
            }
            if let requireEncryption = HavenValue.bool(payload["requireEncryptionAtRest"]) {
                preferences.requireEncryptionAtRest = requireEncryption
            }
        }
        let result = HavenValue.ok(
            preferenceSentence(),
            sideEffect: true,
            extra: [
                "preferences": .object(preferencesObject()),
                "recommendations": .list(recommendationRows().map(ValueType.object))
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    private func setWeight(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let key = HavenValue.string(payload["criterion"]),
              HavenResidencyCriterion(rawValue: key) != nil,
              let weight = HavenValue.double(payload["weight"]) else {
            return HavenValue.error(
                code: "bad_request",
                message: "Trenger `criterion` (\(HavenResidencyCriterion.allCases.map(\.rawValue).joined(separator: ", "))) og `weight` mellom 0 og 1."
            )
        }
        stateQueue.sync { preferences.weights[key] = max(0, min(1, weight)) }
        return HavenValue.ok(
            preferenceSentence(),
            sideEffect: true,
            extra: [
                "preferences": .object(preferencesObject()),
                "recommendations": .list(recommendationRows().map(ValueType.object))
            ]
        )
    }

    private func preferenceSentence() -> String {
        let current = stateQueue.sync { preferences }
        guard current.totalWeight > 0 else {
            return "Alle vektene står på null, så jeg kan ikke rangere lokasjoner. Si hva som betyr noe for deg."
        }
        let ranked = HavenResidencyCriterion.allCases
            .map { ($0, current.weight($0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        let top = ranked.prefix(2).map { $0.0.displayName.lowercased() }.joined(separator: " og ")
        var sentence = "Jeg vekter \(top) høyest når jeg foreslår hvor dataene skal ligge."
        if !current.jurisdictionAllowList.isEmpty {
            sentence += " Bare \(current.jurisdictionAllowList.joined(separator: ", ")) er aktuelt."
        }
        return sentence
    }

    private func preferencesObject() -> Object {
        let current = stateQueue.sync { preferences }
        var weights: Object = [:]
        for criterion in HavenResidencyCriterion.allCases {
            weights[criterion.rawValue] = .float(current.weight(criterion))
        }
        return [
            "weights": .object(weights),
            "jurisdictionAllowList": .list(current.jurisdictionAllowList.map(ValueType.string)),
            "requireEncryptionAtRest": .bool(current.requireEncryptionAtRest),
            "summaryText": .string(preferenceSentence()),
            "hasOpinion": .bool(current.totalWeight > 0)
        ]
    }

    // MARK: - Ranking

    private func recommendationRows() -> [Object] {
        let snapshot = stateQueue.sync { (locations, preferences, placements) }
        let scores = HavenResidencyRanker.rank(locations: snapshot.0, preferences: snapshot.1)
        let currentAuthoritative = Set(snapshot.2.map(\.authoritativeLocationID))
        return scores.enumerated().map { index, score in
            var contributions: Object = [:]
            for (key, contribution) in score.contributions {
                contributions[key] = .float(contribution)
            }
            return [
                "rank": .integer(index + 1),
                "locationID": .string(score.location.id),
                "label": .string(score.location.label),
                "kind": .string(score.location.kind.rawValue),
                "kindText": .string(score.location.kind.displayName),
                "custodian": .string(score.location.custodian),
                "jurisdiction": .string(score.location.jurisdiction),
                "score": .float(score.total),
                "scorePercent": .integer(Int((score.total * 100).rounded())),
                "excluded": .bool(score.excluded),
                "isCurrentHome": .bool(currentAuthoritative.contains(score.location.id)),
                "contributions": .object(contributions),
                "explanation": .string(score.explanation),
                "canWriteDirectly": .bool(score.location.kind.supportsDirectWrite),
                "summaryLine": .string("\(score.location.label) — \(Int((score.total * 100).rounded()))%. \(score.explanation)")
            ]
        }
    }

    private func locationRows() -> [Object] {
        stateQueue.sync { locations }.map { location in
            [
                "id": .string(location.id),
                "label": .string(location.label),
                "kind": .string(location.kind.rawValue),
                "kindText": .string(location.kind.displayName),
                "endpoint": .string(location.endpoint),
                "custodian": .string(location.custodian),
                "jurisdiction": .string(location.jurisdiction),
                "availabilityClass": .float(location.availabilityClass),
                "latencyMsP50": .float(location.latencyMsP50),
                "pricePerGiBMonth": .float(location.pricePerGiBMonth),
                "encryptedAtRest": .bool(location.encryptedAtRest),
                "independence": .float(location.independence),
                "notes": .string(location.notes ?? ""),
                "canWriteDirectly": .bool(location.kind.supportsDirectWrite),
                "detailLine": .string(
                    "\(location.kind.displayName) · \(location.custodian)"
                        + (location.jurisdiction.isEmpty ? "" : " · \(location.jurisdiction)")
                )
            ]
        }
    }

    private func placementRows() -> [Object] {
        let snapshot = stateQueue.sync { (placements, locations, datasets) }
        let now = Date()
        return snapshot.0.map { placement in
            let home = snapshot.1.first { $0.id == placement.authoritativeLocationID }
            let dataset = snapshot.2.first { $0.id == placement.datasetID }
            let replicaRows: [ValueType] = placement.replicas.map { replica in
                let location = snapshot.1.first { $0.id == replica.locationID }
                let stale = replica.isStale(now: now)
                return .object([
                    "locationID": .string(replica.locationID),
                    "label": .string(location?.label ?? replica.locationID),
                    "role": .string(replica.role.rawValue),
                    "roleText": .string(replica.role == .cache ? "Hurtigkopi" : "Sikkerhetskopi"),
                    "stale": .bool(stale),
                    "lastSyncedAtText": .string(replica.lastSyncedAt.map(HavenValue.readable) ?? "aldri"),
                    "statusLine": .string(
                        stale
                            ? "Foreldet — les ikke fra denne uten å synke først"
                            : "Oppdatert \(replica.lastSyncedAt.map(HavenValue.readable) ?? "")"
                    )
                ])
            }
            return [
                "datasetID": .string(placement.datasetID),
                "datasetLabel": .string(dataset?.label ?? placement.datasetID),
                "authoritativeLocationID": .string(placement.authoritativeLocationID),
                "homeLabel": .string(home?.label ?? placement.authoritativeLocationID),
                "since": .string(HavenValue.iso(placement.since)),
                "sinceText": .string(HavenValue.readable(placement.since)),
                "byteSize": .integer(placement.byteSize),
                "sizeText": .string(Self.readableSize(placement.byteSize)),
                "contentHash": .string(placement.lastContentHash ?? ""),
                "lastVerifiedAtText": .string(placement.lastVerifiedAt.map(HavenValue.readable) ?? "ikke verifisert"),
                "replicas": .list(replicaRows),
                "replicaCount": .integer(placement.replicas.count),
                "summaryLine": .string(
                    "\(dataset?.label ?? placement.datasetID) bor på \(home?.label ?? "ukjent sted")"
                        + (placement.replicas.isEmpty ? " uten kopier." : " med \(placement.replicas.count) kopi(er).")
                )
            ]
        }
    }

    private static func readableSize(_ bytes: Int) -> String {
        guard bytes > 0 else { return "tom" }
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f kB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }

    // MARK: - Plan and move

    private func plan(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let datasetID = HavenValue.string(payload["datasetID"]) ?? HavenResidencyDataset.relations.id
        guard let dataset = stateQueue.sync(execute: { datasets.first { $0.id == datasetID } }) else {
            return HavenValue.error(code: "unknown_dataset", message: "Kjenner ikke datasettet «\(datasetID)».")
        }
        guard let placement = stateQueue.sync(execute: { placements.first { $0.datasetID == datasetID } }) else {
            return HavenValue.error(code: "no_placement", message: "Datasettet har ingen registrert plassering.")
        }

        // Destination: explicit, or the top-ranked location that is not home.
        let destinationID = HavenValue.string(payload["toLocationID"])
            ?? recommendationRows()
                .first { HavenValue.bool($0["excluded"]) != true && HavenValue.string($0["locationID"]) != placement.authoritativeLocationID }
                .flatMap { HavenValue.string($0["locationID"]) }

        guard let destinationID,
              let destination = stateQueue.sync(execute: { locations.first { $0.id == destinationID } }) else {
            return HavenValue.error(
                code: "no_destination",
                message: "Ingen aktuell destinasjon. Registrer en lokasjon først."
            )
        }
        let origin = stateQueue.sync { locations.first { $0.id == placement.authoritativeLocationID } }

        // Measure what would actually move.
        var byteSize = placement.byteSize
        var contentHash = placement.lastContentHash ?? ""
        if let snapshot = await snapshotData(for: dataset, requester: requester) {
            byteSize = snapshot.count
            contentHash = HavenResidencyLocalStore.hash(snapshot)
        }

        let steps: [ValueType] = [
            .object([
                "order": .integer(1),
                "title": .string("Les nåværende innhold"),
                "detail": .string("\(dataset.label) leses fra \(origin?.label ?? "nåværende sted") og hashes.")
            ]),
            .object([
                "order": .integer(2),
                "title": .string(destination.kind.supportsDirectWrite ? "Skriv til \(destination.label)" : "Lag eksportpakke"),
                "detail": .string(
                    destination.kind.supportsDirectWrite
                        ? "Innholdet skrives, leses tilbake, og hashene må stemme før noe annet skjer."
                        : "Jeg kan ikke skrive til et scaffold selv. Jeg lager en signert eksportpakke og en manifest, og venter på bekreftelse derfra."
                )
            ]),
            .object([
                "order": .integer(3),
                "title": .string("Flytt pekeren"),
                "detail": .string("\(destination.label) blir autoritativ. \(origin?.label ?? "Forrige sted") beholdes som hurtigkopi i 30 dager.")
            ]),
            .object([
                "order": .integer(4),
                "title": .string("Signer kvittering"),
                "detail": .string("Hva som flyttet, hvorfra, hvorhen, med hvilken hash — signert med identiteten din.")
            ])
        ]

        // Built key by key rather than as one literal: nineteen entries with
        // string interpolation and a ternary inside is more than the type
        // checker will solve in reasonable time.
        let isNoOp = destination.id == placement.authoritativeLocationID
        let originLabel: String = origin?.label ?? placement.authoritativeLocationID
        let summaryText: String = isNoOp
            ? "\(dataset.label) ligger allerede på \(destination.label)."
            : "Flytter \(Self.readableSize(byteSize)) \(dataset.label.lowercased()) fra \(origin?.label ?? "nåværende sted") til \(destination.label)."
        let reversibilityNote = "Forrige sted beholdes som kopi, så en flytting kan rulles tilbake så lenge kopien ikke er ryddet bort."

        var planObject = Object()
        planObject["schema"] = ValueType.string("haven.residency.plan.v1")
        planObject["datasetID"] = ValueType.string(dataset.id)
        planObject["datasetLabel"] = ValueType.string(dataset.label)
        planObject["fromLocationID"] = ValueType.string(placement.authoritativeLocationID)
        planObject["fromLabel"] = ValueType.string(originLabel)
        planObject["toLocationID"] = ValueType.string(destination.id)
        planObject["toLabel"] = ValueType.string(destination.label)
        planObject["byteSize"] = ValueType.integer(byteSize)
        planObject["sizeText"] = ValueType.string(Self.readableSize(byteSize))
        planObject["contentHash"] = ValueType.string(contentHash)
        planObject["canWriteDirectly"] = ValueType.bool(destination.kind.supportsDirectWrite)
        planObject["reversible"] = ValueType.bool(true)
        planObject["reversibilityNote"] = ValueType.string(reversibilityNote)
        planObject["steps"] = ValueType.list(steps)
        planObject["isNoOp"] = ValueType.bool(isNoOp)
        planObject["summaryText"] = ValueType.string(summaryText)
        planObject["sideEffect"] = ValueType.bool(false)

        stateQueue.sync { lastPlan = planObject }
        return planObject
    }

    private func move(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let datasetID = HavenValue.string(payload["datasetID"]) ?? HavenResidencyDataset.relations.id

        guard let dataset = stateQueue.sync(execute: { datasets.first { $0.id == datasetID } }),
              let placementIndex = stateQueue.sync(execute: { placements.firstIndex { $0.datasetID == datasetID } }) else {
            return fail(HavenValue.error(code: "unknown_dataset", message: "Kjenner ikke datasettet «\(datasetID)»."))
        }
        let placement = stateQueue.sync { placements[placementIndex] }

        guard let destinationID = HavenValue.string(payload["toLocationID"]),
              let destination = stateQueue.sync(execute: { locations.first { $0.id == destinationID } }) else {
            return fail(HavenValue.error(code: "missing_destination", message: "Mangler `toLocationID`."))
        }
        guard destinationID != placement.authoritativeLocationID else {
            return fail(HavenValue.error(
                code: "already_there",
                message: "\(dataset.label) ligger allerede på \(destination.label)."
            ))
        }

        guard let snapshot = await snapshotData(for: dataset, requester: requester) else {
            return fail(HavenValue.error(
                code: "snapshot_failed",
                message: "Klarte ikke å lese \(dataset.label) fra \(dataset.cellEndpoint)."
            ))
        }
        let contentHash = HavenResidencyLocalStore.hash(snapshot)
        let now = Date()

        var readbackVerified = false
        var transferState = "completed"
        var note: String?
        var manifest: Object?

        if destination.kind.supportsDirectWrite {
            do {
                let url = try HavenResidencyLocalStore.write(
                    snapshot,
                    datasetID: dataset.id,
                    to: destination,
                    expectedHash: contentHash
                )
                readbackVerified = true
                note = "Skrevet og lest tilbake fra \(url.lastPathComponent)."
            } catch let failure as HavenResidencyLocalStore.Failure {
                // A move that cannot be verified is a move that did not happen.
                return fail(HavenValue.error(
                    code: "move_failed",
                    message: failure.description,
                    extra: ["datasetID": .string(dataset.id), "toLocationID": .string(destination.id)]
                ))
            } catch {
                return fail(HavenValue.error(code: "move_failed", message: String(describing: error)))
            }
        } else {
            // Scaffold: we produce the bundle and wait to be told it landed.
            transferState = "pendingAcknowledgement"
            note = "Eksportpakken er klar. \(destination.label) blir ikke autoritativ før scaffoldet bekrefter med residency.acknowledgeTransfer."
            manifest = [
                "schema": .string("haven.residency.transferManifest.v1"),
                "datasetID": .string(dataset.id),
                "toEndpoint": .string(destination.endpoint),
                "contentHash": .string(contentHash),
                "byteSize": .integer(snapshot.count),
                "payloadBase64": .string(snapshot.base64EncodedString()),
                "createdAt": .string(HavenValue.iso(now))
            ]
        }

        var receipt = HavenResidencyReceipt(
            receiptID: "rcpt-\(UUID().uuidString.lowercased())",
            datasetID: dataset.id,
            fromLocationID: placement.authoritativeLocationID,
            toLocationID: destination.id,
            contentHash: contentHash,
            byteSize: snapshot.count,
            movedAt: HavenValue.iso(now),
            readbackVerified: readbackVerified,
            transferState: transferState,
            sourceRetainedAs: HavenReplicaRole.cache.rawValue,
            note: note
        )
        if let payloadData = try? receipt.canonicalPayloadData(),
           let descriptor = IdentityPublicKeySignatureVerifier.descriptor(for: storedOwnerIdentity),
           let signature = try? await storedOwnerIdentity.sign(data: payloadData) {
            receipt.proof = HavenSignatureProof(
                byIdentityUUID: descriptor.uuid,
                algorithm: descriptor.algorithm,
                curveType: descriptor.curveType,
                signature: signature
            )
        }

        stateQueue.sync {
            receipts.insert(receipt, at: 0)
            if transferState == "completed" {
                let previousHome = placements[placementIndex].authoritativeLocationID
                placements[placementIndex].authoritativeLocationID = destination.id
                placements[placementIndex].lastContentHash = contentHash
                placements[placementIndex].byteSize = snapshot.count
                placements[placementIndex].since = now
                placements[placementIndex].lastVerifiedAt = now
                placements[placementIndex].replicas.removeAll { $0.locationID == destination.id }
                placements[placementIndex].replicas.append(
                    HavenResidencyReplica(
                        locationID: previousHome,
                        role: .cache,
                        staleAfterSeconds: 30 * 86_400,
                        lastSyncedAt: now,
                        lastContentHash: contentHash
                    )
                )
            }
        }

        var extra: Object = [
            "receipt": HavenValue.value(receipt),
            "receiptID": .string(receipt.receiptID),
            "datasetID": .string(dataset.id),
            "fromLocationID": .string(placement.authoritativeLocationID),
            "toLocationID": .string(destination.id),
            "contentHash": .string(contentHash),
            "byteSize": .integer(snapshot.count),
            "readbackVerified": .bool(readbackVerified),
            "transferState": .string(transferState),
            "placements": .list(placementRows().map(ValueType.object))
        ]
        if let manifest { extra["transferManifest"] = .object(manifest) }

        let result = HavenValue.ok(
            transferState == "completed"
                ? "\(dataset.label) bor nå på \(destination.label). Lest tilbake og verifisert, forrige sted beholdes som kopi i 30 dager."
                : note ?? "Eksportpakken er klar.",
            sideEffect: true,
            extra: extra
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    /// Confirmation from a destination that could not be written to directly.
    /// Only now does it become authoritative.
    private func acknowledgeTransfer(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let receiptID = HavenValue.string(payload["receiptID"]) else {
            return HavenValue.error(code: "missing_receipt", message: "Mangler `receiptID`.")
        }
        guard let confirmedHash = HavenValue.string(payload["contentHash"]) else {
            return HavenValue.error(
                code: "missing_hash",
                message: "Destinasjonen må oppgi `contentHash` for det den faktisk mottok."
            )
        }
        var outcome: Object?
        stateQueue.sync {
            guard let receiptIndex = receipts.firstIndex(where: { $0.receiptID == receiptID }) else {
                outcome = HavenValue.error(code: "not_found", message: "Fant ingen kvittering med id \(receiptID).")
                return
            }
            let receipt = receipts[receiptIndex]
            guard receipt.contentHash == confirmedHash else {
                outcome = HavenValue.error(
                    code: "hash_mismatch",
                    message: "Hashen destinasjonen bekrefter stemmer ikke med det jeg sendte. Pekeren står urørt."
                )
                return
            }
            guard let placementIndex = placements.firstIndex(where: { $0.datasetID == receipt.datasetID }) else {
                outcome = HavenValue.error(code: "no_placement", message: "Datasettet har ingen plassering lenger.")
                return
            }
            let now = Date()
            let previousHome = placements[placementIndex].authoritativeLocationID
            receipts[receiptIndex].transferState = "completed"
            receipts[receiptIndex].readbackVerified = true
            placements[placementIndex].authoritativeLocationID = receipt.toLocationID
            placements[placementIndex].lastContentHash = receipt.contentHash
            placements[placementIndex].byteSize = receipt.byteSize
            placements[placementIndex].since = now
            placements[placementIndex].lastVerifiedAt = now
            placements[placementIndex].replicas.removeAll { $0.locationID == receipt.toLocationID }
            placements[placementIndex].replicas.append(
                HavenResidencyReplica(
                    locationID: previousHome,
                    role: .cache,
                    staleAfterSeconds: 30 * 86_400,
                    lastSyncedAt: now,
                    lastContentHash: receipt.contentHash
                )
            )
        }
        if let outcome {
            stateQueue.sync { lastResult = outcome }
            return outcome
        }
        let result = HavenValue.ok(
            "Bekreftet. Datasettet er nå autoritativt på det nye stedet.",
            sideEffect: true,
            extra: ["placements": .list(placementRows().map(ValueType.object))]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    /// Reads the authoritative copy back and compares it with what we last
    /// wrote, so silent drift becomes visible instead of being discovered on a
    /// bad day.
    private func verify(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let datasetID = HavenValue.string(payload["datasetID"]) ?? HavenResidencyDataset.relations.id
        guard let dataset = stateQueue.sync(execute: { datasets.first { $0.id == datasetID } }),
              let placement = stateQueue.sync(execute: { placements.first { $0.datasetID == datasetID } }),
              let home = stateQueue.sync(execute: { locations.first { $0.id == placement.authoritativeLocationID } }) else {
            return HavenValue.error(code: "unknown_dataset", message: "Kjenner ikke datasettet «\(datasetID)».")
        }

        // The live cell is the truth while the data still lives on this device.
        guard let live = await snapshotData(for: dataset, requester: requester) else {
            return HavenValue.error(code: "snapshot_failed", message: "Klarte ikke å lese datasettet.")
        }
        let liveHash = HavenResidencyLocalStore.hash(live)

        var storedHash: String?
        var storedError: String?
        if home.kind.supportsDirectWrite && home.id != Self.deviceLocationID {
            do {
                storedHash = HavenResidencyLocalStore.hash(
                    try HavenResidencyLocalStore.read(datasetID: dataset.id, from: home)
                )
            } catch {
                storedError = String(describing: error)
            }
        }

        let matches = storedHash == nil ? true : storedHash == liveHash
        stateQueue.sync {
            if let index = placements.firstIndex(where: { $0.datasetID == datasetID }) {
                placements[index].lastVerifiedAt = Date()
                placements[index].lastContentHash = liveHash
                placements[index].byteSize = live.count
            }
        }

        return [
            "schema": .string("haven.residency.verification.v1"),
            "status": .string(matches ? "consistent" : "drift"),
            "datasetID": .string(dataset.id),
            "homeLabel": .string(home.label),
            "liveHash": .string(liveHash),
            "storedHash": .string(storedHash ?? ""),
            "storedError": .string(storedError ?? ""),
            "byteSize": .integer(live.count),
            "sizeText": .string(Self.readableSize(live.count)),
            "summaryText": .string(
                storedError != nil
                    ? "Fikk ikke lest kopien på \(home.label): \(storedError!)"
                    : (matches
                        ? "\(dataset.label) på \(home.label) stemmer med det jeg har her (\(Self.readableSize(live.count)))."
                        : "Kopien på \(home.label) har drevet fra det jeg har her. Flytt på nytt for å rette det opp.")
            ),
            "sideEffect": .bool(false)
        ]
    }

    // MARK: - Replicas

    private func addReplica(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let datasetID = HavenValue.string(payload["datasetID"]) ?? HavenResidencyDataset.relations.id
        guard let locationID = HavenValue.string(payload["locationID"]) else {
            return HavenValue.error(code: "missing_id", message: "Mangler `locationID`.")
        }
        let role = HavenValue.string(payload["role"]).flatMap(HavenReplicaRole.init(rawValue:)) ?? .backup
        var outcome: Object?
        stateQueue.sync {
            guard locations.contains(where: { $0.id == locationID }) else {
                outcome = HavenValue.error(code: "unknown_location", message: "Kjenner ikke lokasjonen \(locationID).")
                return
            }
            guard let index = placements.firstIndex(where: { $0.datasetID == datasetID }) else {
                outcome = HavenValue.error(code: "no_placement", message: "Datasettet har ingen plassering.")
                return
            }
            guard placements[index].authoritativeLocationID != locationID else {
                outcome = HavenValue.error(
                    code: "is_authoritative",
                    message: "Den lokasjonen er allerede den autoritative. Den kan ikke også være en kopi."
                )
                return
            }
            placements[index].replicas.removeAll { $0.locationID == locationID }
            placements[index].replicas.append(HavenResidencyReplica(
                locationID: locationID,
                role: role,
                staleAfterSeconds: HavenValue.int(payload["staleAfterSeconds"]) ?? 86_400
            ))
        }
        if let outcome { return outcome }
        return HavenValue.ok(
            "Lagt til som \(role == .cache ? "hurtigkopi" : "sikkerhetskopi"). Den er merket foreldet til den er synket.",
            sideEffect: true,
            extra: ["placements": .list(placementRows().map(ValueType.object))]
        )
    }

    private func removeReplica(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let datasetID = HavenValue.string(payload["datasetID"]) ?? HavenResidencyDataset.relations.id
        guard let locationID = HavenValue.string(payload["locationID"]) else {
            return HavenValue.error(code: "missing_id", message: "Mangler `locationID`.")
        }
        stateQueue.sync {
            if let index = placements.firstIndex(where: { $0.datasetID == datasetID }) {
                placements[index].replicas.removeAll { $0.locationID == locationID }
            }
        }
        return HavenValue.ok("Kopien er fjernet fra oversikten.", sideEffect: true)
    }

    // MARK: - Snapshot plumbing

    private func snapshotData(for dataset: HavenResidencyDataset, requester: Identity) async -> Data? {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let cell = try? await resolver.cellAtEndpoint(
                endpoint: dataset.cellEndpoint,
                requester: requester
              ) as? Meddle,
              let value = try? await cell.get(keypath: dataset.snapshotKeypath, requester: requester) else {
            return nil
        }
        return try? HavenValue.encoder().encode(value)
    }

    private func receiptRows() -> [Object] {
        stateQueue.sync { receipts }.prefix(50).map { receipt in
            [
                "receiptID": .string(receipt.receiptID),
                "datasetID": .string(receipt.datasetID),
                "fromLocationID": .string(receipt.fromLocationID),
                "toLocationID": .string(receipt.toLocationID),
                "contentHash": .string(receipt.contentHash),
                "shortHash": .string(String(receipt.contentHash.prefix(12))),
                "byteSize": .integer(receipt.byteSize),
                "sizeText": .string(Self.readableSize(receipt.byteSize)),
                "movedAt": .string(receipt.movedAt),
                "movedAtText": .string(
                    HavenValue.isoFormatter.date(from: receipt.movedAt).map(HavenValue.readable) ?? receipt.movedAt
                ),
                "readbackVerified": .bool(receipt.readbackVerified),
                "transferState": .string(receipt.transferState),
                "signed": .bool(receipt.proof?.signature != nil),
                "note": .string(receipt.note ?? ""),
                "summaryLine": .string(
                    "\(Self.readableSize(receipt.byteSize)) fra \(receipt.fromLocationID) til \(receipt.toLocationID)"
                        + (receipt.readbackVerified ? " · verifisert" : " · venter på bekreftelse")
                )
            ]
        }
    }

    private func stateObject() -> Object {
        let snapshot = stateQueue.sync { (placements, locations, datasets) }
        let homes = snapshot.0.compactMap { placement in
            snapshot.1.first { $0.id == placement.authoritativeLocationID }?.label
        }
        return [
            "schema": .string("haven.residency.state.v1"),
            "summary": .string(
                homes.isEmpty
                    ? "Ingen plassering registrert ennå."
                    : "Entitetsdataene dine bor på \(Array(Set(homes)).sorted().joined(separator: ", "))."
            ),
            "singleSourceOfTruthRule": .string(
                "Ett sted er autoritativt per datasett. Alt annet er hurtigkopi eller sikkerhetskopi, med en tydelig grense for når det regnes som foreldet."
            ),
            "placements": .list(placementRows().map(ValueType.object)),
            "locations": .list(locationRows().map(ValueType.object)),
            "recommendations": .list(recommendationRows().map(ValueType.object)),
            "preferences": .object(preferencesObject()),
            "receipts": .list(receiptRows().map(ValueType.object)),
            "lastPlan": .object(stateQueue.sync { lastPlan }),
            "lastResult": .object(stateQueue.sync { lastResult }),
            "datasetCount": .integer(snapshot.2.count),
            "updatedAt": .string(HavenValue.iso(Date()))
        ]
    }

    private func fail(_ error: Object) -> Object {
        stateQueue.sync { lastResult = error }
        return error
    }

    // MARK: - Discovery

    private func providerDescriptor() -> Object {
        [
            "id": .string("binding.entity-residency"),
            "providerID": .string("binding.entity-residency"),
            "kind": .string("entity_residency"),
            "title": .string("Datalokasjon"),
            "summary": .string("Hvor entitetsdataene dine bor, og hvordan du flytter dem dit du selv mener de hører hjemme."),
            "endpoint": .string(Self.endpoint),
            "sourceCellName": .string(Self.sourceCellName),
            "actionKeypath": .string("residency.plan"),
            "purposeRefs": .list([
                .string("personal.entity.residency"),
                .string("purpose://control-my-data-location")
            ]),
            "interests": .list([
                .string("data-residency"),
                .string("storage"),
                .string("backup"),
                .string("sovereignty"),
                .string("latency"),
                .string("cost")
            ]),
            "availability": .string("available_in_cell_scope"),
            "privacyLevel": .string("owner_controlled_placement"),
            "executionScope": .string("binding_local_cell"),
            "requiresUserApproval": .bool(true),
            "requiresNetwork": .bool(false),
            "canInvokeFromChat": .bool(true),
            "score": .float(0.85),
            "reason": .string("Spørsmål om hvor dataene ligger, hva det koster og hvordan de flyttes hører hjemme her.")
        ]
    }

    private func purposeGoal() -> Object {
        [
            "title": .string("Datalokasjon"),
            "summary": .string("La eieren bestemme hvor entitetsdataene bor, ut fra vektene hun selv setter, og bevise hver flytting."),
            "purposeRefs": .list([.string("personal.entity.residency")]),
            "interests": .list([.string("data-residency"), .string("storage"), .string("sovereignty")])
        ]
    }

    // MARK: - Surface

    nonisolated static func menuConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Datalokasjon")
        configuration.description = "Se hvor entitetsdataene dine ligger, vekt det du bryr deg om, og flytt dem med kvittering."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: sourceCellName,
            purpose: "Styr hvor entitetsdataene bor",
            purposeDescription: "Én autoritativ lokasjon per datasett, kopier med tydelig foreldelse, forklarbar rangering etter eierens egne vekter, og signert kvittering for hver flytting.",
            interests: BindingPersonalCopilotV1Policy.discoveryInterests(
                [
                    "data-residency",
                    "storage",
                    "backup",
                    "sovereignty",
                    "purposeRef=personal.entity.residency"
                ],
                policyCategory: "data-residency"
            ),
            menuSlots: ["lowerRight"]
        )
        configuration.addReference(CellReference(endpoint: endpoint, subscribeFeed: false, label: "residency"))

        var placementRow = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "datasetLabel")),
            .Text(SkeletonText(keypath: "summaryLine")),
            .Text(SkeletonText(keypath: "sizeText")),
            .Text(SkeletonText(keypath: "lastVerifiedAtText"))
        ], spacing: 3)
        placementRow.modifiers = SkeletonModifiers()
        placementRow.modifiers?.padding = 10
        placementRow.modifiers?.cornerRadius = 8
        placementRow.modifiers?.borderWidth = 1
        placementRow.modifiers?.borderColor = "#CBD5E1"

        var placementList = SkeletonList(
            topic: nil,
            keypath: "residency.state.placements",
            flowElementSkeleton: placementRow
        )
        placementList.modifiers = SkeletonModifiers()
        placementList.modifiers?.height = 200

        var criterionRow = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "label")),
            .Text(SkeletonText(keypath: "question"))
        ], spacing: 3)
        criterionRow.modifiers = SkeletonModifiers()
        criterionRow.modifiers?.padding = 8

        var criteria = SkeletonList(
            topic: nil,
            keypath: "residency.criteria",
            flowElementSkeleton: criterionRow
        )
        criteria.modifiers = SkeletonModifiers()
        criteria.modifiers?.height = 220

        var recommendationRow = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "summaryLine")),
            .Text(SkeletonText(keypath: "kindText")),
            .Button(SkeletonButton(
                keypath: "residency.residency.plan",
                label: "Lag flytteplan",
                payloadKeypath: "locationID"
            ))
        ], spacing: 4)
        recommendationRow.modifiers = SkeletonModifiers()
        recommendationRow.modifiers?.padding = 10
        recommendationRow.modifiers?.cornerRadius = 8

        var recommendations = SkeletonList(
            topic: nil,
            keypath: "residency.state.recommendations",
            flowElementSkeleton: recommendationRow
        )
        recommendations.modifiers = SkeletonModifiers()
        recommendations.modifiers?.height = 260

        var receiptRow = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "movedAtText")),
            .Text(SkeletonText(keypath: "summaryLine")),
            .Text(SkeletonText(keypath: "shortHash"))
        ], spacing: 3)
        receiptRow.modifiers = SkeletonModifiers()
        receiptRow.modifiers?.padding = 8

        var receiptList = SkeletonList(
            topic: nil,
            keypath: "residency.state.receipts",
            flowElementSkeleton: receiptRow
        )
        receiptList.modifiers = SkeletonModifiers()
        receiptList.modifiers?.height = 200

        configuration.skeleton = .ScrollView(SkeletonScrollView(elements: [
            .VStack(SkeletonVStack(elements: [
                .Text(SkeletonText(text: "Datalokasjon")),
                .Text(SkeletonText(keypath: "residency.state.summary")),
                .Text(SkeletonText(keypath: "residency.state.singleSourceOfTruthRule")),
                .List(placementList),
                .Divider(SkeletonDivider()),
                .Text(SkeletonText(text: "Hva betyr noe for deg?")),
                .Text(SkeletonText(keypath: "residency.state.preferences.summaryText")),
                .List(criteria),
                .Divider(SkeletonDivider()),
                .Text(SkeletonText(text: "Rangering")),
                .List(recommendations),
                .Text(SkeletonText(keypath: "residency.state.lastPlan.summaryText")),
                .Button(SkeletonButton(
                    keypath: "residency.residency.verify",
                    label: "Verifiser at alt stemmer",
                    payload: .object([:])
                )),
                .Divider(SkeletonDivider()),
                .Text(SkeletonText(text: "Kvitteringer")),
                .List(receiptList),
                .Text(SkeletonText(keypath: "residency.state.lastResult.message"))
            ], spacing: 12))
        ]))
        return configuration
    }
}
