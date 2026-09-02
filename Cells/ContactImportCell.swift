// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  ContactImportCell.swift
//  Binding
//
//  Takes a spreadsheet, CSV or vCard file and works out what is in it, then
//  shows the user its proposal *before* anything reaches their entity.
//
//  The two-step shape is deliberate. An address book is not a payload to be
//  swallowed; it is a set of claims about other people. Preview, correct,
//  then commit — and every committed record carries the batch it came from so
//  the whole import can be withdrawn later.
//

import Foundation
import CellBase

final class BindingContactImportCell: GeneralCell {
    static let endpoint = "cell:///ContactImport"
    static let sourceCellName = "BindingContactImportCell"
    static let relationsEndpoint = "cell:///Relations"

    private enum CodingKeys: String, CodingKey {
        case pendingTableData
        case pendingCardsData
        case previewMeta
        case mapping
        case lastResult
    }

    private let stateQueue = DispatchQueue(label: "Binding.BindingContactImportCell.State")

    /// The parsed document waiting for confirmation. Encoded as JSON so the
    /// cell survives a restart mid-import rather than losing the user's work.
    private nonisolated(unsafe) var pendingTable: HavenTabularDocument?
    private nonisolated(unsafe) var pendingCards: [HavenVCardParser.Card]?
    private nonisolated(unsafe) var previewMeta: Object = [:]
    private nonisolated(unsafe) var mapping = HavenColumnMapping()
    private nonisolated(unsafe) var lastResult: Object = [:]

    required init(owner: Identity) async {
        await super.init(owner: owner)
        stateQueue.sync {
            lastResult = HavenValue.ok("Klar til å ta imot en kontaktfil.", sideEffect: false)
        }
        try? await ensureRuntimeReady()
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let data = try container.decodeIfPresent(Data.self, forKey: .pendingTableData) {
            pendingTable = try? HavenValue.decoder().decode(StoredTable.self, from: data).document
        }
        if let data = try container.decodeIfPresent(Data.self, forKey: .pendingCardsData) {
            pendingCards = try? HavenValue.decoder().decode(StoredCards.self, from: data).cards
        }
        previewMeta = try container.decodeIfPresent(Object.self, forKey: .previewMeta) ?? [:]
        mapping = try container.decodeIfPresent(HavenColumnMapping.self, forKey: .mapping) ?? HavenColumnMapping()
        lastResult = try container.decodeIfPresent(Object.self, forKey: .lastResult) ?? [:]
        try super.init(from: decoder)
    }

    override func installCellRuntimeBindingsForAccess() async throws {
        await setup(owner: storedOwnerIdentity)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync { (pendingTable, pendingCards, previewMeta, mapping, lastResult) }
        if let table = snapshot.0,
           let data = try? HavenValue.encoder().encode(StoredTable(document: table)) {
            try container.encode(data, forKey: .pendingTableData)
        }
        if let cards = snapshot.1,
           let data = try? HavenValue.encoder().encode(StoredCards(cards: cards)) {
            try container.encode(data, forKey: .pendingCardsData)
        }
        try container.encode(snapshot.2, forKey: .previewMeta)
        try container.encode(snapshot.3, forKey: .mapping)
        try container.encode(snapshot.4, forKey: .lastResult)
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

    private var readableKeys: [String] {
        [
            "state",
            "import.state",
            "import.preview",
            "import.assessments",
            "import.fields",
            "import.supportedFormats",
            "import.lastResult",
            "providerDescriptor",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    private var writableKeys: [String] {
        [
            "import.ingest",
            "import.setMapping",
            "import.setRegion",
            "import.commit",
            "import.discard"
        ]
    }

    private func readValue(for key: String) -> ValueType {
        switch key {
        case "state", "import.state":
            return .object(stateObject())
        case "import.preview":
            return .object(previewObject())
        case "import.assessments":
            return .list(assessmentRows().map(ValueType.object))
        case "import.fields":
            return .list(HavenContactField.allCases.map { field in
                .object([
                    "id": .string(field.rawValue),
                    "label": .string(field.displayName),
                    "multiValued": .bool(field.isMultiValued)
                ])
            })
        case "import.supportedFormats":
            return .list(Self.supportedFormats().map(ValueType.object))
        case "import.lastResult":
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
        case "import.ingest":
            return .object(ingest(value))
        case "import.setMapping":
            return .object(setMapping(value))
        case "import.setRegion":
            return .object(setRegion(value))
        case "import.commit":
            return .object(await commit(value, requester: requester))
        case "import.discard":
            return .object(discard())
        default:
            return .object(HavenValue.error(code: "unsupported_keypath", message: "Ukjent import-handling."))
        }
    }

    // MARK: - Ingest

    /// Accepts the file as raw text, base64 bytes, or an attachment payload
    /// from a `FileUpload` element, whichever the surface can provide.
    private func ingest(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]

        let attachment = HavenValue.object(payload["attachment"])
        let attachmentMetadata = HavenValue.object(attachment?["metadata"])

        let filename = HavenValue.string(payload["filename"])
            ?? HavenValue.string(payload["name"])
            ?? HavenValue.string(attachment?["displayName"])
        let mimeType = HavenValue.string(payload["mimeType"])
            ?? HavenValue.string(attachment?["mimeType"])

        var data: Data?
        if let text = HavenValue.string(payload["text"]) ?? HavenValue.string(attachmentMetadata?["text"]) {
            data = Data(text.utf8)
        } else if let bytes = HavenValue.data(payload["dataBase64"])
            ?? HavenValue.data(payload["data"])
            ?? HavenValue.data(attachmentMetadata?["dataBase64"]) {
            data = bytes
        }

        guard let data, !data.isEmpty else {
            return fail(HavenValue.error(
                code: "no_payload",
                message: "Send innholdet som `text` (ren tekst) eller `dataBase64` (base64-kodede byte).",
                extra: ["expects": .list([.string("text"), .string("dataBase64"), .string("attachment")])]
            ))
        }

        let sizeLimit = 20 * 1024 * 1024
        guard data.count <= sizeLimit else {
            return fail(HavenValue.error(
                code: "too_large",
                message: "Filen er \(data.count / (1024 * 1024)) MB. Grensen er 20 MB — del den opp, eller eksporter et utvalg."
            ))
        }

        let loaded: HavenContactDocumentLoader.Loaded
        do {
            loaded = try HavenContactDocumentLoader.load(filename: filename, mimeType: mimeType, data: data)
        } catch let error as HavenContactDocumentError {
            var extra: Object = ["filename": .string(filename ?? "")]
            if case .numbersPackage = error {
                extra["remedy"] = .string("Åpne i Numbers → Arkiv → Eksporter til → CSV")
                extra["remedyCode"] = .string("export_from_numbers")
            }
            return fail(HavenValue.error(code: "unreadable", message: error.description, extra: extra))
        } catch {
            return fail(HavenValue.error(code: "unreadable", message: "Filen kunne ikke leses: \(error)"))
        }

        let batchID = "import-\(UUID().uuidString.prefix(8))"
        let currentRegion = stateQueue.sync { mapping.region }

        if let table = loaded.table {
            let inferred = HavenContactColumnInference.infer(document: table, region: currentRegion)
            stateQueue.sync {
                pendingTable = table
                pendingCards = nil
                mapping = inferred.mapping
                previewMeta = Self.meta(
                    batchID: batchID,
                    filename: filename,
                    loaded: loaded,
                    rowCount: table.rows.count,
                    assessments: inferred.assessments
                )
            }
        } else if let cards = loaded.cards {
            stateQueue.sync {
                pendingTable = nil
                pendingCards = cards
                mapping = HavenColumnMapping(region: currentRegion)
                previewMeta = Self.meta(
                    batchID: batchID,
                    filename: filename,
                    loaded: loaded,
                    rowCount: cards.count,
                    assessments: []
                )
            }
        } else {
            return fail(HavenValue.error(code: "empty", message: "Fant ingen rader i filen."))
        }

        let preview = previewObject()
        let result = HavenValue.ok(
            HavenValue.string(preview["summaryText"]) ?? "Filen er lest.",
            sideEffect: false,
            extra: [
                "preview": .object(preview),
                "batchID": .string(batchID),
                "requiresConfirmation": .bool(true)
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    private func fail(_ error: Object) -> Object {
        stateQueue.sync { lastResult = error }
        return error
    }

    private static func meta(
        batchID: String,
        filename: String?,
        loaded: HavenContactDocumentLoader.Loaded,
        rowCount: Int,
        assessments: [HavenColumnAssessment]
    ) -> Object {
        [
            "batchID": .string(batchID),
            "filename": .string(filename ?? "uten navn"),
            "format": .string(loaded.format.rawValue),
            "formatText": .string(loaded.format.displayName),
            "encoding": .string(loaded.encodingName ?? ""),
            "rowCount": .integer(rowCount),
            "notes": .list(loaded.notes.map(ValueType.string)),
            "assessments": HavenValue.value(assessments),
            "ingestedAt": .string(HavenValue.iso(Date()))
        ]
    }

    // MARK: - Mapping

    /// Accepts either one correction (`columnIndex` + `field`) or a whole map.
    private func setMapping(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard stateQueue.sync(execute: { pendingTable != nil }) else {
            return HavenValue.error(
                code: "no_pending_table",
                message: "Det ligger ingen tabell til godkjenning. Send en fil først."
            )
        }

        // The surface sends the whole selected option object, so accept
        // `{columnIndex, field}` and the packed `"3:email"` form alike rather
        // than making the renderer take a shape it does not naturally produce.
        var columnIndex = HavenValue.int(payload["columnIndex"])
        var fieldName = HavenValue.string(payload["field"])
        if columnIndex == nil || fieldName == nil,
           let packed = HavenValue.string(payload["value"]) ?? HavenValue.string(value) {
            let parts = packed.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                columnIndex = Int(parts[0])
                fieldName = parts[1]
            }
        }

        var changed = 0
        stateQueue.sync {
            if let index = columnIndex,
               let fieldName,
               let field = HavenContactField(rawValue: fieldName) {
                // Taking a single-valued field away from another column keeps
                // the map consistent instead of silently dropping one of them.
                if !field.isMultiValued, field != .ignore {
                    for (existing, assigned) in mapping.assignments where assigned == field && existing != index {
                        mapping.assignments[existing] = .ignore
                    }
                }
                mapping.assignments[index] = field
                changed += 1
            }
            if let assignments = HavenValue.object(payload["assignments"]) {
                for (key, raw) in assignments {
                    guard let index = Int(key),
                          let fieldName = HavenValue.string(raw),
                          let field = HavenContactField(rawValue: fieldName) else { continue }
                    mapping.assignments[index] = field
                    changed += 1
                }
            }
        }

        guard changed > 0 else {
            return HavenValue.error(
                code: "bad_request",
                message: "Send `columnIndex` og `field`, eller et `assignments`-objekt."
            )
        }
        let preview = previewObject()
        let result = HavenValue.ok(
            "Kartleggingen er oppdatert. " + (HavenValue.string(preview["summaryText"]) ?? ""),
            sideEffect: false,
            extra: ["preview": .object(preview)]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    private func setRegion(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let candidate = HavenValue.string(payload["region"]) ?? HavenValue.string(value),
              candidate.count == 2 else {
            return HavenValue.error(code: "bad_region", message: "Oppgi en tobokstavs landkode, for eksempel NO.")
        }
        stateQueue.sync { mapping.region = candidate.uppercased() }
        return HavenValue.ok(
            "Telefonnumre uten landkode tolkes som \(candidate.uppercased()).",
            sideEffect: false,
            extra: ["preview": .object(previewObject())]
        )
    }

    // MARK: - Preview

    private func buildResult() -> HavenContactColumnInference.BuildResult? {
        let snapshot = stateQueue.sync { (pendingTable, pendingCards, mapping, previewMeta) }
        let source = HavenRelationSource(
            kind: .fileImport,
            label: HavenValue.string(snapshot.3["filename"]) ?? "Filimport",
            batchID: HavenValue.string(snapshot.3["batchID"]),
            importedAt: Date()
        )
        if let table = snapshot.0 {
            return HavenContactColumnInference.buildRecords(
                document: table,
                mapping: snapshot.2,
                source: source,
                context: HavenValue.string(snapshot.3["context"])
            )
        }
        if let cards = snapshot.1 {
            return HavenContactColumnInference.buildRecords(
                cards: cards,
                source: source,
                region: snapshot.2.region
            )
        }
        return nil
    }

    private func previewObject() -> Object {
        let snapshot = stateQueue.sync { (pendingTable, pendingCards, mapping, previewMeta) }
        guard snapshot.0 != nil || snapshot.1 != nil else {
            return [
                "schema": .string("haven.contactImport.preview.v1"),
                "status": .string("idle"),
                "hasPending": .bool(false),
                "summaryText": .string("Ingen fil til godkjenning. Slipp inn en CSV, XLSX eller vCard."),
                "rows": .list([]),
                "assessments": .list([]),
                "problems": .list([])
            ]
        }

        guard let build = buildResult() else {
            return [
                "schema": .string("haven.contactImport.preview.v1"),
                "status": .string("error"),
                "hasPending": .bool(true),
                "summaryText": .string("Klarte ikke å bygge et forhåndsbilde av filen.")
            ]
        }

        let usable = snapshot.1 != nil || snapshot.2.isUsable
        let previewRows = build.records.prefix(12).map { record -> ValueType in
            var row = HavenRelationPresenter.row(for: record)
            row["willInvite"] = .bool(record.inviteReadiness.canInvite)
            return .object(row)
        }

        var object: Object = snapshot.3
        object["schema"] = .string("haven.contactImport.preview.v1")
        object["status"] = .string(usable ? "ready" : "needsMapping")
        object["hasPending"] = .bool(true)
        object["region"] = .string(snapshot.2.region)
        object["proposedCount"] = .integer(build.records.count)
        object["reachableCount"] = .integer(build.records.filter { !$0.reachableEndpoints.isEmpty }.count)
        object["skippedRows"] = .integer(build.skippedRows)
        object["problems"] = .list(build.problems.map(ValueType.string))
        object["rows"] = .list(previewRows)
        object["assessments"] = .list(assessmentRows().map(ValueType.object))
        object["reviewColumns"] = .list(reviewColumns().map(ValueType.object))
        object["uncertainSummary"] = .string(uncertainSummary())
        object["canCommit"] = .bool(usable && !build.records.isEmpty)
        object["summaryText"] = .string(previewSummary(build: build, usable: usable, meta: snapshot.3))
        object["consentLine"] = .string(
            "Dette er andres kontaktopplysninger. De blir liggende i din egen entitet på denne enheten, og ingenting sendes noe sted før du selv trykker send på en invitasjon."
        )
        return object
    }

    private func previewSummary(
        build: HavenContactColumnInference.BuildResult,
        usable: Bool,
        meta: Object
    ) -> String {
        let filename = HavenValue.string(meta["filename"]) ?? "filen"
        let format = HavenValue.string(meta["formatText"]) ?? ""
        guard usable else {
            return "Jeg leste \(filename) (\(format)), men fant ingen kolonne som gir navn eller kontaktinfo. Velg kolonnene selv, så tar jeg det derfra."
        }
        let reachable = build.records.filter { !$0.reachableEndpoints.isEmpty }.count
        var sentence = "\(filename): \(build.records.count) kontakter, \(reachable) med e-post eller telefon"
        if build.skippedRows > 0 { sentence += ", \(build.skippedRows) rader hoppet over" }
        return sentence + ". Se over kartleggingen før du legger dem inn."
    }

    /// One row per column, ready to render: the header, what we think it is,
    /// two sample values, and the full option list for the picker.
    ///
    /// The column index never appears as a label — it is carried inside each
    /// option's value so a selection can identify itself, and nowhere else.
    /// Uncertain columns sort first, because those are the ones worth a look.
    private func reviewColumns() -> [Object] {
        assessmentRows()
            .map { row -> Object in
                var enriched = row
                let index = HavenValue.int(row["columnIndex"]) ?? 0
                enriched["fieldOptions"] = .list(HavenContactField.allCases.map { field in
                    .object([
                        "label": .string(field.displayName),
                        "value": .string("\(index):\(field.rawValue)"),
                        "columnIndex": .integer(index),
                        "field": .string(field.rawValue)
                    ])
                })
                return enriched
            }
            .sorted { lhs, rhs in
                let left = HavenValue.double(lhs["confidence"]) ?? 0
                let right = HavenValue.double(rhs["confidence"]) ?? 0
                if abs(left - right) > 0.0001 { return left < right }
                return (HavenValue.int(lhs["columnIndex"]) ?? 0) < (HavenValue.int(rhs["columnIndex"]) ?? 0)
            }
    }

    private func uncertainSummary() -> String {
        let uncertain = assessmentRows().filter { (HavenValue.double($0["confidence"]) ?? 0) < 0.6 }
        guard !uncertain.isEmpty else { return "" }
        let names = uncertain.prefix(3).compactMap { HavenValue.string($0["header"]) }
        if uncertain.count == 1 {
            return "Jeg er usikker på «\(names.first ?? "")». Sjekk den før du legger dem inn."
        }
        return "Jeg er usikker på \(uncertain.count) kolonner: \(names.joined(separator: ", ")). Sjekk dem før du legger dem inn."
    }

    private func assessmentRows() -> [Object] {
        let snapshot = stateQueue.sync { (previewMeta, mapping) }
        guard let stored = snapshot.0["assessments"],
              let assessments = HavenValue.decode([HavenColumnAssessment].self, from: stored) else {
            return []
        }
        return assessments.map { assessment in
            let current = snapshot.1.assignments[assessment.columnIndex] ?? .ignore
            return [
                "columnIndex": .integer(assessment.columnIndex),
                "header": .string(assessment.header),
                "field": .string(current.rawValue),
                "fieldLabel": .string(current.displayName),
                "suggestedField": .string(assessment.field.rawValue),
                "wasCorrected": .bool(current != assessment.field),
                "confidence": .float(assessment.confidence),
                "confidenceText": .string(Self.confidenceText(assessment.confidence)),
                "filledPercent": .integer(Int((assessment.filledFraction * 100).rounded())),
                "sampleValues": .list(assessment.sampleValues.map(ValueType.string)),
                "sampleText": .string(assessment.sampleValues.prefix(2).joined(separator: " · ")),
                "reason": .string(assessment.reason)
            ]
        }
    }

    private static func confidenceText(_ value: Double) -> String {
        switch value {
        case 0.85...: return "sikker"
        case 0.6..<0.85: return "ganske sikker"
        case 0.34..<0.6: return "usikker"
        default: return "ingen match"
        }
    }

    // MARK: - Commit

    private func commit(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        // The owner can name the context the roles belong to («Bok:
        // Rammebetingelser for innovasjon») at the moment of commit. Without
        // it, the file name is the context.
        if let context = HavenValue.string(payload["context"])?.trimmingCharacters(in: .whitespacesAndNewlines),
           !context.isEmpty {
            stateQueue.sync { previewMeta["context"] = .string(context) }
        }
        guard let build = buildResult() else {
            return HavenValue.error(code: "no_pending", message: "Ingenting å legge inn — send en fil først.")
        }
        guard !build.records.isEmpty else {
            return HavenValue.error(
                code: "nothing_usable",
                message: "Ingen av radene ga navn eller et endepunkt jeg kunne tolke. Sjekk kolonnevalgene."
            )
        }

        // Optional narrowing: commit only the rows the user ticked.
        let selected = Set(HavenValue.stringList(payload["relationIDs"]))
        let records = selected.isEmpty ? build.records : build.records.filter { selected.contains($0.id) }
        guard !records.isEmpty else {
            return HavenValue.error(code: "nothing_selected", message: "Ingen av de valgte radene fantes i forhåndsbildet.")
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let relations = try? await resolver.cellAtEndpoint(
                endpoint: Self.relationsEndpoint,
                requester: requester
              ) as? Meddle else {
            return HavenValue.error(
                code: "relations_unavailable",
                message: "Relasjonscellen er ikke tilgjengelig i denne kjøringen."
            )
        }

        let snapshot = stateQueue.sync { previewMeta }
        let upsertPayload: Object = [
            "records": HavenValue.value(records),
            "region": .string(stateQueue.sync { mapping.region }),
            "source": .object([
                "kind": .string(HavenRelationSourceKind.fileImport.rawValue),
                "label": .string(HavenValue.string(snapshot["filename"]) ?? "Filimport"),
                "batchID": .string(HavenValue.string(snapshot["batchID"]) ?? "import"),
                "importedAt": .string(HavenValue.iso(Date()))
            ])
        ]

        guard let response = try? await relations.set(
            keypath: "relations.upsert",
            value: .object(upsertPayload),
            requester: requester
        ) else {
            return HavenValue.error(code: "upsert_failed", message: "Relasjonscellen tok ikke imot importen.")
        }

        let responseObject = HavenValue.object(response) ?? [:]
        stateQueue.sync {
            pendingTable = nil
            pendingCards = nil
            previewMeta = [:]
            mapping = HavenColumnMapping(region: mapping.region)
        }

        let result = HavenValue.ok(
            HavenValue.string(responseObject["message"]) ?? "Importen er lagt inn.",
            sideEffect: true,
            extra: [
                "committed": .integer(records.count),
                "batchID": .string(HavenValue.string(snapshot["batchID"]) ?? ""),
                "relationsResponse": .object(responseObject),
                "undoHint": .string("Angre alt fra denne filen med relations.forgetBatch og samme batchID.")
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    private func discard() -> Object {
        stateQueue.sync {
            pendingTable = nil
            pendingCards = nil
            previewMeta = [:]
            mapping = HavenColumnMapping(region: mapping.region)
            lastResult = HavenValue.ok("Filen er forkastet. Ingenting ble lagt inn.", sideEffect: false)
        }
        return stateQueue.sync { lastResult }
    }

    // MARK: - State

    private func stateObject() -> Object {
        let preview = previewObject()
        return [
            "schema": .string("haven.contactImport.state.v1"),
            "hasPending": preview["hasPending"] ?? .bool(false),
            "summary": preview["summaryText"] ?? .string(""),
            "preview": .object(preview),
            "assessments": preview["assessments"] ?? .list([]),
            "supportedFormats": .list(Self.supportedFormats().map(ValueType.object)),
            "lastResult": .object(stateQueue.sync { lastResult }),
            "privacyBoundary": .string("owner_entity_local_no_network"),
            "updatedAt": .string(HavenValue.iso(Date()))
        ]
    }

    private static func supportedFormats() -> [Object] {
        [
            [
                "id": .string("csv"),
                "label": .string("CSV / TSV"),
                "detail": .string("Semikolon, komma, tab eller loddrett strek. UTF-8, UTF-16 og ISO-8859-1."),
                "supported": .bool(true)
            ],
            [
                "id": .string("xlsx"),
                "label": .string("Excel (.xlsx)"),
                "detail": .string("Leses direkte. Første ark, med mindre du sier noe annet."),
                "supported": .bool(true)
            ],
            [
                "id": .string("vcard"),
                "label": .string("vCard (.vcf)"),
                "detail": .string("Eksport fra Kontakter, Google Contacts og lignende."),
                "supported": .bool(true)
            ],
            [
                "id": .string("numbers"),
                "label": .string("Numbers (.numbers)"),
                "detail": .string("Kjennes igjen, men kan ikke leses: Numbers lagrer i et lukket format. Eksporter til CSV eller Excel først."),
                "supported": .bool(false)
            ]
        ]
    }

    // MARK: - Storage shims

    private struct StoredTable: Codable {
        var headers: [String]
        var rows: [[String]]
        var sheetName: String?
        var headersWereSynthesised: Bool
        var notes: [String]

        init(document: HavenTabularDocument) {
            headers = document.headers
            rows = document.rows
            sheetName = document.sheetName
            headersWereSynthesised = document.headersWereSynthesised
            notes = document.notes
        }

        var document: HavenTabularDocument {
            HavenTabularDocument(
                headers: headers,
                rows: rows,
                sheetName: sheetName,
                headersWereSynthesised: headersWereSynthesised,
                notes: notes
            )
        }
    }

    private struct StoredCards: Codable {
        struct StoredEndpoint: Codable {
            var value: String
            var kind: String
            var label: String?
        }
        struct StoredCard: Codable {
            var fullName: String?
            var givenName: String?
            var familyName: String?
            var organization: String?
            var jobTitle: String?
            var notes: String?
            var categories: [String]
            var endpoints: [StoredEndpoint]
        }
        var storedCards: [StoredCard]

        init(cards: [HavenVCardParser.Card]) {
            storedCards = cards.map { card in
                StoredCard(
                    fullName: card.fullName,
                    givenName: card.givenName,
                    familyName: card.familyName,
                    organization: card.organization,
                    jobTitle: card.jobTitle,
                    notes: card.notes,
                    categories: card.categories,
                    endpoints: card.endpoints.map {
                        StoredEndpoint(value: $0.value, kind: $0.kind.rawValue, label: $0.label)
                    }
                )
            }
        }

        var cards: [HavenVCardParser.Card] {
            storedCards.map { stored in
                HavenVCardParser.Card(
                    fullName: stored.fullName,
                    givenName: stored.givenName,
                    familyName: stored.familyName,
                    organization: stored.organization,
                    jobTitle: stored.jobTitle,
                    notes: stored.notes,
                    categories: stored.categories,
                    endpoints: stored.endpoints.map {
                        ($0.value, HavenEndpointKind(rawValue: $0.kind) ?? .other, $0.label)
                    }
                )
            }
        }
    }

    // MARK: - Discovery

    private func providerDescriptor() -> Object {
        [
            "id": .string("binding.contact-import"),
            "providerID": .string("binding.contact-import"),
            "kind": .string("contact_import"),
            "title": .string("Kontaktimport"),
            "summary": .string("Les CSV, Excel eller vCard, gjenkjenn kolonnene, og legg dem inn etter godkjenning."),
            "endpoint": .string(Self.endpoint),
            "sourceCellName": .string(Self.sourceCellName),
            "actionKeypath": .string("import.ingest"),
            "purposeRefs": .list([
                .string("personal.relations.import"),
                .string("purpose://import-contacts")
            ]),
            "interests": .list([
                .string("contacts"),
                .string("import"),
                .string("spreadsheet"),
                .string("csv"),
                .string("vcard"),
                .string("relations")
            ]),
            "availability": .string("available_in_cell_scope"),
            "privacyLevel": .string("owner_entity_local"),
            "executionScope": .string("binding_local_cell"),
            "requiresUserApproval": .bool(true),
            "requiresNetwork": .bool(false),
            "canInvokeFromChat": .bool(true),
            "score": .float(0.88),
            "reason": .string("Filer med kontaktdata skal gjennom forhåndsvisning før noe havner i entiteten.")
        ]
    }

    private func purposeGoal() -> Object {
        [
            "title": .string("Kontaktimport"),
            "summary": .string("Finn ut hva som står i filen, vis det til eieren, og legg det inn først når hun sier ja."),
            "purposeRefs": .list([.string("personal.relations.import")]),
            "interests": .list([.string("contacts"), .string("import"), .string("relations")])
        ]
    }

    // MARK: - Surface

    /// Import is a step inside the relations surface, not a destination of its
    /// own. See `RelationsWorkbenchConfiguration.swift`.
    nonisolated static func menuConfiguration() -> CellConfiguration {
        HavenRelationsWorkbench.configuration()
    }
}
