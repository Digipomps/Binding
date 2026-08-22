// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  AddressBookCell.swift
//  Binding
//
//  Exposes the address book and the file picker to the skeleton world, and
//  routes what comes back into the right place: picked people go straight to
//  Relations, a picked file goes to ContactImport for review.
//
//  The ordering here is the product decision. "Velg noen" needs no permission
//  and is offered first; "les alle" is a separate button with the boundary
//  stated in the same sentence as the request.
//

import Foundation
import CellBase

final class BindingAddressBookCell: GeneralCell {
    static let endpoint = "cell:///AddressBook"
    static let sourceCellName = "BindingAddressBookCell"
    static let relationsEndpoint = "cell:///Relations"
    static let importEndpoint = "cell:///ContactImport"

    private enum CodingKeys: String, CodingKey {
        case lastResult
        case lastImportedCount
        case hasEverPicked
    }

    private let stateQueue = DispatchQueue(label: "Binding.BindingAddressBookCell.State")

    private nonisolated(unsafe) var lastResult: Object = [:]
    private nonisolated(unsafe) var lastImportedCount: Int = 0
    private nonisolated(unsafe) var hasEverPicked: Bool = false

    required init(owner: Identity) async {
        await super.init(owner: owner)
        stateQueue.sync {
            lastResult = HavenValue.ok("Klar til å hente kontakter.", sideEffect: false)
        }
        try? await ensureRuntimeReady()
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastResult = try container.decodeIfPresent(Object.self, forKey: .lastResult) ?? [:]
        lastImportedCount = try container.decodeIfPresent(Int.self, forKey: .lastImportedCount) ?? 0
        hasEverPicked = try container.decodeIfPresent(Bool.self, forKey: .hasEverPicked) ?? false
        try super.init(from: decoder)
    }

    override func installCellRuntimeBindingsForAccess() async throws {
        await setup(owner: storedOwnerIdentity)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync { (lastResult, lastImportedCount, hasEverPicked) }
        try container.encode(snapshot.0, forKey: .lastResult)
        try container.encode(snapshot.1, forKey: .lastImportedCount)
        try container.encode(snapshot.2, forKey: .hasEverPicked)
    }

    private func setup(owner: Identity) async {
        for key in readableKeys {
            agreementTemplate.addGrant("r---", for: key)
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                return await self.readValue(for: key)
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
            "addressBook.state",
            "addressBook.permission",
            "addressBook.lastResult",
            "providerDescriptor",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    private var writableKeys: [String] {
        [
            "addressBook.pickContacts",
            "addressBook.requestFullAccess",
            "addressBook.importAll",
            "addressBook.pickFile"
        ]
    }

    private func readValue(for key: String) async -> ValueType {
        switch key {
        case "state", "addressBook.state":
            return .object(await stateObject())
        case "addressBook.permission":
            return .object(await permissionObject())
        case "addressBook.lastResult":
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
        case "addressBook.pickContacts":
            return .object(await pickContacts(value, requester: requester))
        case "addressBook.requestFullAccess":
            return .object(await requestFullAccess())
        case "addressBook.importAll":
            return .object(await importAll(value, requester: requester))
        case "addressBook.pickFile":
            return .object(await pickFile(requester: requester))
        default:
            return .object(HavenValue.error(code: "unsupported_keypath", message: "Ukjent adressebok-handling."))
        }
    }

    // MARK: - Permission

    private func permissionObject() async -> Object {
        let state = await BindingContactSourceBridge.shared.accessState
        let supportsPicker = await BindingContactSourceBridge.shared.supportsPicker
        return [
            "state": .string(state.rawValue),
            "isReadable": .bool(state.isReadable),
            "explanation": .string(state.explanation),
            "supportsPicker": .bool(supportsPicker),
            "recommendedAction": .string(
                supportsPicker
                    ? "Velg enkeltpersoner — det krever ingen tillatelse i det hele tatt."
                    : (state.isReadable ? "Importer fra kontaktlisten." : "Gi kontakttilgang, eller importer en fil.")
            ),
            "fullAccessRequestLine": .string(
                "Full kontakttilgang lar meg lese hele listen for å foreslå hvem du kan invitere. Alt blir liggende på denne enheten, og du kan trekke det tilbake når som helst."
            )
        ]
    }

    private func stateObject() async -> Object {
        let permission = await permissionObject()
        let snapshot = stateQueue.sync { (lastResult, lastImportedCount, hasEverPicked) }
        return [
            "schema": .string("haven.addressBook.state.v1"),
            "permission": .object(permission),
            "summary": .string(
                snapshot.2
                    ? "Sist hentet: \(snapshot.1) kontakter."
                    : "Hent noen kontakter for å komme i gang. Du velger selv hvem."
            ),
            "lastImportedCount": .integer(snapshot.1),
            "hasEverPicked": .bool(snapshot.2),
            "lastResult": .object(snapshot.0),
            "privacyBoundary": .string("owner_local_picker_first"),
            "updatedAt": .string(HavenValue.iso(Date()))
        ]
    }

    private func requestFullAccess() async -> Object {
        let state = await BindingContactSourceBridge.shared.requestFullAccess()
        let result = HavenValue.ok(
            state.explanation,
            sideEffect: true,
            extra: ["permission": .object(await permissionObject())]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    // MARK: - Picking people

    private func pickContacts(_ value: ValueType, requester: Identity) async -> Object {
        let outcome = await BindingContactSourceBridge.shared.pickContacts()
        switch outcome {
        case .failure(let error):
            return fail(HavenValue.error(code: error.code, message: error.description))
        case .success(let candidates):
            guard !candidates.isEmpty else {
                let result = HavenValue.ok("Ingen kontakter valgt.", sideEffect: false)
                stateQueue.sync { lastResult = result }
                return result
            }
            return await store(
                candidates: candidates,
                sourceKind: .addressBookPicker,
                label: "Kontakter (valgt)",
                requester: requester
            )
        }
    }

    private func importAll(_ value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        let limit = HavenValue.int(payload["limit"]) ?? 5000

        var state = await BindingContactSourceBridge.shared.accessState
        if !state.isReadable {
            // Ask once, here, at the moment the user asked for the thing that
            // needs it — never earlier.
            state = await BindingContactSourceBridge.shared.requestFullAccess()
        }
        guard state.isReadable else {
            return fail(HavenValue.error(
                code: "not_authorized",
                message: state.explanation,
                extra: ["permission": .object(await permissionObject())]
            ))
        }

        switch await BindingContactSourceBridge.shared.fetchAllContacts(limit: limit) {
        case .failure(let error):
            return fail(HavenValue.error(code: error.code, message: error.description))
        case .success(let candidates):
            guard !candidates.isEmpty else {
                return fail(HavenValue.error(code: "empty", message: "Kontaktlisten er tom."))
            }
            return await store(
                candidates: candidates,
                sourceKind: .addressBookScan,
                label: "Kontakter",
                requester: requester
            )
        }
    }

    private func store(
        candidates: [BindingContactCandidate],
        sourceKind: HavenRelationSourceKind,
        label: String,
        requester: Identity
    ) async -> Object {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let relations = try? await resolver.cellAtEndpoint(
                endpoint: Self.relationsEndpoint,
                requester: requester
              ) as? Meddle else {
            return fail(HavenValue.error(
                code: "relations_unavailable",
                message: "Relasjonscellen er ikke tilgjengelig i denne kjøringen."
            ))
        }

        let batchID = "contacts-\(UUID().uuidString.prefix(8))"
        let contactValues = candidates.compactMap { HavenValue.value(fromJSONObject: $0.contactObject) }
        let payload: Object = [
            "contacts": .list(contactValues),
            "source": .object([
                "kind": .string(sourceKind.rawValue),
                "label": .string(label),
                "batchID": .string(batchID),
                "importedAt": .string(HavenValue.iso(Date()))
            ])
        ]

        guard let response = try? await relations.set(
            keypath: "relations.upsert",
            value: .object(payload),
            requester: requester
        ), let responseObject = HavenValue.object(response) else {
            return fail(HavenValue.error(code: "upsert_failed", message: "Relasjonscellen tok ikke imot kontaktene."))
        }

        stateQueue.sync {
            lastImportedCount = candidates.count
            hasEverPicked = true
        }
        let result = HavenValue.ok(
            HavenValue.string(responseObject["message"]) ?? "\(candidates.count) kontakter lagt inn.",
            sideEffect: true,
            extra: [
                "count": .integer(candidates.count),
                "batchID": .string(batchID),
                "relationsResponse": .object(responseObject),
                "undoHint": .string("Angre denne hentingen med relations.forgetBatch og batchID \(batchID).")
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    // MARK: - Picking a file

    private func pickFile(requester: Identity) async -> Object {
        switch await BindingContactSourceBridge.shared.pickContactFile() {
        case .failure(let error):
            return fail(HavenValue.error(code: error.code, message: error.description))
        case .success(let file):
            guard let resolver = CellBase.defaultCellResolver as? CellResolver,
                  let importer = try? await resolver.cellAtEndpoint(
                    endpoint: Self.importEndpoint,
                    requester: requester
                  ) as? Meddle else {
                return fail(HavenValue.error(
                    code: "import_unavailable",
                    message: "Importcellen er ikke tilgjengelig i denne kjøringen."
                ))
            }
            let payload: Object = [
                "filename": .string(file.filename),
                "mimeType": .string(file.mimeType ?? ""),
                "dataBase64": .string(file.data.base64EncodedString())
            ]
            guard let response = try? await importer.set(
                keypath: "import.ingest",
                value: .object(payload),
                requester: requester
            ), let responseObject = HavenValue.object(response) else {
                return fail(HavenValue.error(code: "ingest_failed", message: "Importcellen kunne ikke lese filen."))
            }
            stateQueue.sync { lastResult = responseObject }
            return responseObject
        }
    }

    private func fail(_ error: Object) -> Object {
        stateQueue.sync { lastResult = error }
        return error
    }

    // MARK: - Discovery

    private func providerDescriptor() -> Object {
        [
            "id": .string("binding.address-book"),
            "providerID": .string("binding.address-book"),
            "kind": .string("address_book"),
            "title": .string("Kontakter"),
            "summary": .string("Hent folk fra kontaktlisten eller en fil, inn i relasjonene dine."),
            "endpoint": .string(Self.endpoint),
            "sourceCellName": .string(Self.sourceCellName),
            "actionKeypath": .string("addressBook.pickContacts"),
            "purposeRefs": .list([
                .string("personal.relations.import"),
                .string("purpose://import-contacts")
            ]),
            "interests": .list([
                .string("contacts"),
                .string("address-book"),
                .string("relations"),
                .string("import"),
                .string("requires-user-approval")
            ]),
            "availability": .string("available_in_cell_scope"),
            "privacyLevel": .string("owner_local_picker_first"),
            "executionScope": .string("binding_local_cell"),
            "requiresUserApproval": .bool(true),
            "requiresNetwork": .bool(false),
            "canInvokeFromChat": .bool(true),
            "score": .float(0.9),
            "reason": .string("Å hente kontakter skal gå gjennom systemets velger før noen tillatelse spørres om.")
        ]
    }

    private func purposeGoal() -> Object {
        [
            "title": .string("Kontakter"),
            "summary": .string("Få relasjoner inn i entiteten med minst mulig tillatelse, og si tydelig hva hvert valg innebærer."),
            "purposeRefs": .list([.string("personal.relations.import")]),
            "interests": .list([.string("contacts"), .string("address-book"), .string("relations")])
        ]
    }

    // MARK: - Surface

    /// Fetching contacts is a step inside the relations surface, not a
    /// destination of its own. See `RelationsWorkbenchConfiguration.swift`.
    nonisolated static func menuConfiguration() -> CellConfiguration {
        HavenRelationsWorkbench.configuration()
    }
}
