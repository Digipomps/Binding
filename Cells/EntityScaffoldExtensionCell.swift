// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  EntityScaffoldExtensionCell.swift
//  Binding
//
//  Extending my own entity onto a new scaffold or device.
//
//  This deliberately reuses the enrollment primitives that already exist in
//  CellBase — `IdentityEnrollmentRequest`, `IdentityEnrollmentApproval`,
//  `IdentityLinkRecord`, `IdentityLinkRevocation` — rather than inventing a
//  second way to say the same thing. The cell is the choreography, not the
//  cryptography.
//
//  The shape is three moves:
//    1. the new place asks, signing with its own fresh key
//    2. somewhere I already control reviews and approves, signing over a hash
//       of the exact request it saw
//    3. the new place accepts, and both sides hold a link record
//
//  Because the approval covers the request hash, an intercepted request cannot
//  be re-pointed at a different key: changing anything invalidates the
//  approval that was issued for it.
//

import Foundation
import CellBase

final class BindingEntityScaffoldExtensionCell: GeneralCell {
    static let endpoint = "cell:///EntityScaffoldExtension"
    static let sourceCellName = "BindingEntityScaffoldExtensionCell"

    private enum CodingKeys: String, CodingKey {
        case links
        case outgoingRequests
        case lastResult
    }

    /// A request this device issued and is waiting to have approved.
    private struct OutgoingRequest: Codable, Equatable {
        var request: IdentityEnrollmentRequest
        var humanCode: String
        var createdAt: Date
        var approvedAt: Date?
        var linkID: String?
    }

    private let stateQueue = DispatchQueue(label: "Binding.BindingEntityScaffoldExtensionCell.State")

    private nonisolated(unsafe) var links: [IdentityLinkRecord] = []
    private nonisolated(unsafe) var outgoingRequests: [OutgoingRequest] = []
    private nonisolated(unsafe) var lastResult: Object = [:]

    required init(owner: Identity) async {
        await super.init(owner: owner)
        stateQueue.sync {
            lastResult = HavenValue.ok("Klar til å utvide entiteten til et nytt sted.", sideEffect: false)
        }
        try? await ensureRuntimeReady()
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        links = try container.decodeIfPresent([IdentityLinkRecord].self, forKey: .links) ?? []
        outgoingRequests = try container.decodeIfPresent([OutgoingRequest].self, forKey: .outgoingRequests) ?? []
        lastResult = try container.decodeIfPresent(Object.self, forKey: .lastResult) ?? [:]
        try super.init(from: decoder)
    }

    override func installCellRuntimeBindingsForAccess() async throws {
        await setup(owner: storedOwnerIdentity)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync { (links, outgoingRequests, lastResult) }
        try container.encode(snapshot.0, forKey: .links)
        try container.encode(snapshot.1, forKey: .outgoingRequests)
        try container.encode(snapshot.2, forKey: .lastResult)
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
            "extension.state",
            "extension.links",
            "extension.pending",
            "extension.defaultScopes",
            "extension.lastResult",
            "providerDescriptor",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    private var writableKeys: [String] {
        [
            "extension.beginRequest",
            "extension.reviewRequest",
            "extension.approveRequest",
            "extension.acceptApproval",
            "extension.revokeLink",
            "extension.clearPending"
        ]
    }

    private func readValue(for key: String) -> ValueType {
        switch key {
        case "state", "extension.state":
            return .object(stateObject())
        case "extension.links":
            return .list(linkRows().map(ValueType.object))
        case "extension.pending":
            return .list(pendingRows().map(ValueType.object))
        case "extension.defaultScopes":
            return .list(Self.defaultScopes.map { scope in
                .object([
                    "id": .string(scope.id),
                    "label": .string(scope.label),
                    "detail": .string(scope.detail),
                    "defaultOn": .bool(scope.defaultOn)
                ])
            })
        case "extension.lastResult":
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
        case "extension.beginRequest":
            return .object(await beginRequest(value))
        case "extension.reviewRequest":
            return .object(reviewRequest(value))
        case "extension.approveRequest":
            return .object(await approveRequest(value))
        case "extension.acceptApproval":
            return .object(acceptApproval(value))
        case "extension.revokeLink":
            return .object(await revokeLink(value))
        case "extension.clearPending":
            return .object(clearPending())
        default:
            return .object(HavenValue.error(code: "unsupported_keypath", message: "Ukjent utvidelses-handling."))
        }
    }

    // MARK: - Scopes

    struct ScopeOption {
        var id: String
        var label: String
        var detail: String
        var defaultOn: Bool
    }

    /// What a new place may do on my behalf. Kept short and readable, because
    /// this is the list a person actually has to understand before saying yes.
    static let defaultScopes: [ScopeOption] = [
        ScopeOption(
            id: "entity.read",
            label: "Lese entiteten min",
            detail: "Se relasjoner, formål og innstillinger.",
            defaultOn: true
        ),
        ScopeOption(
            id: "entity.write",
            label: "Endre entiteten min",
            detail: "Legge til og endre relasjoner og innstillinger.",
            defaultOn: true
        ),
        ScopeOption(
            id: "invite.issue",
            label: "Lage invitasjoner",
            detail: "Signere invitasjoner i mitt navn.",
            defaultOn: false
        ),
        ScopeOption(
            id: "agreement.sign",
            label: "Signere avtaler",
            detail: "Inngå avtaler i mitt navn. Gi bare dette til noe du stoler helt på.",
            defaultOn: false
        )
    ]

    private static var defaultOnScopes: [String] {
        defaultScopes.filter(\.defaultOn).map(\.id)
    }

    // MARK: - 1. Ask

    /// Run on the *new* place. Produces a signed request the existing entity
    /// can review.
    private func beginRequest(_ value: ValueType) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let audience = HavenValue.string(payload["audience"]) else {
            return fail(HavenValue.error(
                code: "missing_audience",
                message: "Si hvilket scaffold dette gjelder — `audience`, for eksempel https://staging.haven.digipomps.org."
            ))
        }
        guard let descriptor = IdentityPublicKeySignatureVerifier.descriptor(for: storedOwnerIdentity) else {
            return fail(HavenValue.error(
                code: "no_signing_identity",
                message: "Denne identiteten har ingen signeringsnøkkel, så den kan ikke be om å bli koblet."
            ))
        }

        let now = Date()
        let ttlMinutes = min(1440, max(2, HavenValue.int(payload["ttlMinutes"]) ?? 15))
        let requestID = "enr-\(UUID().uuidString.lowercased())"
        var nonceBytes = [UInt8](repeating: 0, count: 16)
        for index in nonceBytes.indices { nonceBytes[index] = UInt8.random(in: 0...255) }

        var request = IdentityEnrollmentRequest(
            requestID: requestID,
            entityBinding: EntityBindingDescriptor(
                mode: .localEntityAnchor,
                entityAnchorReference: storedOwnerIdentity.entityAnchorReference,
                audience: audience
            ),
            newIdentity: descriptor,
            requestedDomains: HavenValue.stringList(payload["requestedDomains"]).nilWhenEmpty ?? ["private"],
            requestedIdentityContexts: HavenValue.stringList(payload["requestedIdentityContexts"]).nilWhenEmpty ?? ["default"],
            requestedScopes: HavenValue.stringList(payload["requestedScopes"]).nilWhenEmpty ?? Self.defaultOnScopes,
            audience: audience,
            origin: HavenValue.string(payload["origin"]) ?? Self.endpoint,
            createdAt: HavenValue.iso(now),
            expiresAt: HavenValue.iso(now.addingTimeInterval(TimeInterval(ttlMinutes) * 60)),
            nonce: Data(nonceBytes),
            platform: Self.platformName,
            deviceLabel: HavenValue.string(payload["deviceLabel"]) ?? storedOwnerIdentity.displayName
        )

        guard let canonical = try? request.canonicalPayloadData(),
              let signature = try? await storedOwnerIdentity.sign(data: canonical) else {
            return fail(HavenValue.error(
                code: "signing_failed",
                message: "Kunne ikke signere forespørselen."
            ))
        }
        request.proof = IdentityEnrollmentRequestProof(
            byIdentityUUID: descriptor.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )

        let transport = Self.encode(request)
        let humanCode = HavenInviteLink.humanCode(from: requestID + audience)

        stateQueue.sync {
            outgoingRequests.removeAll { $0.request.requestID == requestID }
            outgoingRequests.insert(
                OutgoingRequest(request: request, humanCode: humanCode, createdAt: now),
                at: 0
            )
        }

        let result = HavenValue.ok(
            "Forespørselen er klar. Vis koden \(humanCode) eller send pakken til en enhet du allerede bruker, og godkjenn der.",
            sideEffect: true,
            extra: [
                "requestID": .string(requestID),
                "humanCode": .string(humanCode),
                "payload": .string(transport ?? ""),
                "expiresAt": .string(request.expiresAt),
                "expiresInMinutes": .integer(ttlMinutes),
                "requestedScopes": .list(request.requestedScopes.map(ValueType.string)),
                "audience": .string(audience),
                "nextStep": .string("Åpne HAVEN på en enhet du allerede bruker, og send pakken til extension.approveRequest der."),
                "warning": .string(
                    "Godkjenn aldri en forespørsel du ikke selv startet. Sjekk at koden på denne skjermen er den samme som på den andre."
                )
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    // MARK: - 2. Review and approve

    /// Read-only inspection on the approving side. Verifies the request's own
    /// signature and lays out exactly what is being asked for, so approval is a
    /// decision rather than a reflex.
    private func reviewRequest(_ value: ValueType) -> Object {
        guard let request = Self.decodeRequest(from: value) else {
            return HavenValue.error(code: "bad_payload", message: "Fant ingen gyldig forespørsel i det du sendte.")
        }
        let now = Date()
        let expiry = HavenValue.isoFormatter.date(from: request.expiresAt)
        let expired = expiry.map { now > $0 } ?? true

        var signatureValid = false
        if let proof = request.proof,
           let signature = proof.signature,
           proof.byIdentityUUID == request.newIdentity.uuid,
           let canonical = try? request.canonicalPayloadData() {
            signatureValid = IdentityPublicKeySignatureVerifier.verify(
                signature: signature,
                messageData: canonical,
                descriptor: request.newIdentity
            )
        }

        let alreadyLinked = stateQueue.sync {
            links.contains { $0.linkedIdentity.uuid == request.newIdentity.uuid && $0.status == .active }
        }

        let scopeRows: [ValueType] = request.requestedScopes.map { scope in
            let known = Self.defaultScopes.first { $0.id == scope }
            return .object([
                "id": .string(scope),
                "label": .string(known?.label ?? scope),
                "detail": .string(known?.detail ?? "Ukjent rettighet — vær ekstra forsiktig."),
                "recognised": .bool(known != nil)
            ])
        }
        let unknownScopes = request.requestedScopes.filter { scope in
            !Self.defaultScopes.contains { $0.id == scope }
        }

        return [
            "schema": .string("haven.entityExtension.review.v1"),
            "status": .string(signatureValid && !expired ? "reviewable" : "rejected"),
            "requestID": .string(request.requestID),
            "signatureValid": .bool(signatureValid),
            "expired": .bool(expired),
            "alreadyLinked": .bool(alreadyLinked),
            "audience": .string(request.audience),
            "deviceLabel": .string(request.deviceLabel ?? "ukjent enhet"),
            "platform": .string(request.platform ?? ""),
            "requestedScopes": .list(scopeRows),
            "unknownScopes": .list(unknownScopes.map(ValueType.string)),
            "requestedDomains": .list(request.requestedDomains.map(ValueType.string)),
            "expiresAt": .string(request.expiresAt),
            "humanCode": .string(HavenInviteLink.humanCode(from: request.requestID + request.audience)),
            "summaryText": .string(Self.reviewSummary(
                request: request,
                signatureValid: signatureValid,
                expired: expired,
                alreadyLinked: alreadyLinked
            )),
            "confirmationQuestion": .string(
                "Stemmer koden \(HavenInviteLink.humanCode(from: request.requestID + request.audience)) med det som står på den andre skjermen?"
            ),
            "sideEffect": .bool(false)
        ]
    }

    private static func reviewSummary(
        request: IdentityEnrollmentRequest,
        signatureValid: Bool,
        expired: Bool,
        alreadyLinked: Bool
    ) -> String {
        if !signatureValid {
            return "Signaturen på forespørselen stemmer ikke. Ikke godkjenn denne."
        }
        if expired {
            return "Forespørselen er utløpt. Start en ny på den andre enheten."
        }
        if alreadyLinked {
            return "Denne identiteten er allerede koblet til entiteten din."
        }
        let device = request.deviceLabel ?? "En ny enhet"
        return "\(device) ber om å bli en del av entiteten din på \(request.audience), med \(request.requestedScopes.count) rettighet(er)."
    }

    /// Signs an approval bound to the hash of the exact request we reviewed.
    private func approveRequest(_ value: ValueType) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let request = Self.decodeRequest(from: value) else {
            return fail(HavenValue.error(code: "bad_payload", message: "Fant ingen gyldig forespørsel i det du sendte."))
        }

        // Never approve something we would refuse to show.
        let review = reviewRequest(value)
        guard HavenValue.string(review["status"]) == "reviewable" else {
            return fail(HavenValue.error(
                code: "not_approvable",
                message: HavenValue.string(review["summaryText"]) ?? "Forespørselen kan ikke godkjennes.",
                extra: ["review": .object(review)]
            ))
        }

        guard let canonicalRequest = try? request.canonicalPayloadData() else {
            return fail(HavenValue.error(code: "bad_payload", message: "Forespørselen kunne ikke kanoniseres."))
        }
        guard let issuerDescriptor = IdentityPublicKeySignatureVerifier.descriptor(for: storedOwnerIdentity) else {
            return fail(HavenValue.error(
                code: "no_signing_identity",
                message: "Denne identiteten kan ikke signere en godkjenning."
            ))
        }

        // The approver decides the scopes; the request only asks.
        let requested = Set(request.requestedScopes)
        let granted = HavenValue.stringList(payload["approvedScopes"]).nilWhenEmpty
            ?? request.requestedScopes.filter { scope in
                Self.defaultScopes.contains { $0.id == scope }
            }
        let refused = requested.subtracting(granted).sorted()

        guard !granted.isEmpty else {
            return fail(HavenValue.error(
                code: "no_scopes",
                message: "Ingen rettigheter ble godkjent, så det er ikke noe å koble."
            ))
        }

        let now = Date()
        let ttlMinutes = min(1440, max(2, HavenValue.int(payload["ttlMinutes"]) ?? 15))
        var approval = IdentityEnrollmentApproval(
            approvalID: "apr-\(UUID().uuidString.lowercased())",
            requestHash: Data(HavenRelationNormalizer.sha256Hex(canonicalRequest.base64EncodedString()).utf8),
            entityBinding: request.entityBinding
                ?? EntityBindingDescriptor(mode: .localEntityAnchor, audience: request.audience),
            subjectIdentity: request.newIdentity,
            approvedDomains: HavenValue.stringList(payload["approvedDomains"]).nilWhenEmpty ?? request.requestedDomains,
            approvedIdentityContexts: request.requestedIdentityContexts,
            approvedScopes: granted,
            issuerIdentityUUID: issuerDescriptor.uuid,
            issuerType: .existingDevice,
            audience: request.audience,
            origin: Self.endpoint,
            createdAt: HavenValue.iso(now),
            expiresAt: HavenValue.iso(now.addingTimeInterval(TimeInterval(ttlMinutes) * 60)),
            jti: UUID().uuidString.lowercased(),
            freshAuthRequired: true,
            freshAuthMethod: HavenValue.string(payload["freshAuthMethod"]),
            freshAuthPerformedAt: HavenValue.string(payload["freshAuthMethod"]) == nil ? nil : HavenValue.iso(now)
        )

        guard let canonicalApproval = try? approval.canonicalPayloadData(),
              let signature = try? await storedOwnerIdentity.sign(data: canonicalApproval) else {
            return fail(HavenValue.error(code: "signing_failed", message: "Kunne ikke signere godkjenningen."))
        }
        approval.proof = IdentityEnrollmentApprovalProof(
            issuerIdentityUUID: issuerDescriptor.uuid,
            issuerType: .existingDevice,
            algorithm: issuerDescriptor.algorithm,
            curveType: issuerDescriptor.curveType,
            signature: signature
        )

        // The approving side records the link too, so revocation has something
        // to act on even if the other side never reports back.
        let record = IdentityLinkRecord(
            linkID: "lnk-\(UUID().uuidString.lowercased())",
            entityBinding: approval.entityBinding,
            linkedIdentity: request.newIdentity,
            approvedDomains: approval.approvedDomains,
            approvedIdentityContexts: approval.approvedIdentityContexts,
            approvedScopes: approval.approvedScopes,
            issuerIdentityUUID: issuerDescriptor.uuid,
            issuerType: .existingDevice,
            status: .active,
            linkedAt: HavenValue.iso(now)
        )
        stateQueue.sync {
            links.removeAll { $0.linkedIdentity.uuid == record.linkedIdentity.uuid && $0.status != .revoked }
            links.insert(record, at: 0)
        }

        var message = "Godkjent. \(request.deviceLabel ?? "Den nye enheten") får \(granted.count) rettighet(er)."
        if !refused.isEmpty {
            message += " Jeg holdt tilbake: \(refused.joined(separator: ", "))."
        }

        let result = HavenValue.ok(
            message,
            sideEffect: true,
            extra: [
                "approvalID": .string(approval.approvalID),
                "linkID": .string(record.linkID),
                "payload": .string(Self.encode(approval) ?? ""),
                "approvedScopes": .list(granted.map(ValueType.string)),
                "refusedScopes": .list(refused.map(ValueType.string)),
                "expiresAt": .string(approval.expiresAt),
                "nextStep": .string("Send denne pakken tilbake til den nye enheten og kjør extension.acceptApproval der."),
                "links": .list(linkRows().map(ValueType.object))
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    // MARK: - 3. Accept

    /// Run back on the new place. Checks that the approval really covers the
    /// request this device issued, then records the link.
    private func acceptApproval(_ value: ValueType) -> Object {
        guard let approval = Self.decodeApproval(from: value) else {
            return fail(HavenValue.error(code: "bad_payload", message: "Fant ingen gyldig godkjenning i det du sendte."))
        }

        guard let pending = stateQueue.sync(execute: {
            outgoingRequests.first { $0.request.newIdentity.uuid == approval.subjectIdentity.uuid }
        }) else {
            return fail(HavenValue.error(
                code: "no_matching_request",
                message: "Denne godkjenningen hører ikke til noen forespørsel denne enheten har sendt."
            ))
        }

        guard let canonicalRequest = try? pending.request.canonicalPayloadData() else {
            return fail(HavenValue.error(code: "bad_request", message: "Den lagrede forespørselen kunne ikke kanoniseres."))
        }
        let expectedHash = Data(HavenRelationNormalizer.sha256Hex(canonicalRequest.base64EncodedString()).utf8)
        guard approval.requestHash == expectedHash else {
            return fail(HavenValue.error(
                code: "request_hash_mismatch",
                message: "Godkjenningen gjelder en annen forespørsel enn den denne enheten sendte. Jeg kobler ingenting."
            ))
        }

        let now = Date()
        if let expiry = HavenValue.isoFormatter.date(from: approval.expiresAt), now > expiry {
            return fail(HavenValue.error(
                code: "expired",
                message: "Godkjenningen er utløpt. Start forespørselen på nytt."
            ))
        }

        // We can only check the issuer's signature when the approval carries a
        // descriptor we can use. It does not, by design — so say so plainly
        // rather than implying a check we did not perform.
        let signaturePresent = approval.proof?.signature != nil

        let record = IdentityLinkRecord(
            linkID: "lnk-\(UUID().uuidString.lowercased())",
            entityBinding: approval.entityBinding,
            linkedIdentity: approval.subjectIdentity,
            approvedDomains: approval.approvedDomains,
            approvedIdentityContexts: approval.approvedIdentityContexts,
            approvedScopes: approval.approvedScopes,
            issuerIdentityUUID: approval.issuerIdentityUUID,
            issuerType: approval.issuerType,
            status: .active,
            linkedAt: HavenValue.iso(now)
        )
        stateQueue.sync {
            links.removeAll { $0.linkedIdentity.uuid == record.linkedIdentity.uuid && $0.status != .revoked }
            links.insert(record, at: 0)
            if let index = outgoingRequests.firstIndex(where: { $0.request.requestID == pending.request.requestID }) {
                outgoingRequests[index].approvedAt = now
                outgoingRequests[index].linkID = record.linkID
            }
        }

        let result = HavenValue.ok(
            "Koblet. Dette stedet er nå en del av entiteten din, med \(approval.approvedScopes.count) rettighet(er).",
            sideEffect: true,
            extra: [
                "linkID": .string(record.linkID),
                "approvedScopes": .list(approval.approvedScopes.map(ValueType.string)),
                "issuerIdentityUUID": .string(approval.issuerIdentityUUID),
                "signaturePresent": .bool(signaturePresent),
                "signatureVerified": .bool(false),
                "verificationNote": .string(
                    "Forespørselens hash stemmer, og godkjenningen er signert, men denne enheten har ikke godkjennerens offentlige nøkkel og kan derfor ikke sjekke signaturen selv. Bekreft koden muntlig, eller hent nøkkelen fra scaffoldet."
                ),
                "links": .list(linkRows().map(ValueType.object))
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    // MARK: - Revocation

    private func revokeLink(_ value: ValueType) async -> Object {
        let payload = HavenValue.object(value) ?? [:]
        guard let linkID = HavenValue.string(payload["linkID"]) ?? HavenValue.string(value) else {
            return fail(HavenValue.error(code: "missing_id", message: "Mangler `linkID`."))
        }
        guard stateQueue.sync(execute: { links.contains { $0.linkID == linkID } }) else {
            return fail(HavenValue.error(code: "not_found", message: "Fant ingen kobling med id \(linkID)."))
        }

        let now = Date()
        let reason = HavenValue.string(payload["reason"]) ?? "Trukket tilbake av eier."
        var revocation = IdentityLinkRevocation(
            linkID: linkID,
            reason: reason,
            revokedAt: HavenValue.iso(now),
            revokedByIdentityUUID: storedOwnerIdentity.uuid,
            issuerType: .existingDevice
        )
        if let descriptor = IdentityPublicKeySignatureVerifier.descriptor(for: storedOwnerIdentity),
           let canonical = try? revocation.canonicalPayloadData(),
           let signature = try? await storedOwnerIdentity.sign(data: canonical) {
            revocation.proof = IdentityEnrollmentApprovalProof(
                issuerIdentityUUID: descriptor.uuid,
                issuerType: .existingDevice,
                algorithm: descriptor.algorithm,
                curveType: descriptor.curveType,
                signature: signature
            )
        }

        stateQueue.sync {
            if let index = links.firstIndex(where: { $0.linkID == linkID }) {
                links[index].status = .revoked
                links[index].revokedAt = HavenValue.iso(now)
                links[index].revocationReference = revocation.proof?.signature?.base64EncodedString()
            }
        }

        let result = HavenValue.ok(
            "Koblingen er trukket tilbake her. Merk at et scaffold som allerede har koblingen slutter å godta den først når det har sett tilbakekallingen.",
            sideEffect: true,
            extra: [
                "linkID": .string(linkID),
                "revocation": HavenValue.value(revocation),
                "payload": .string(Self.encode(revocation) ?? ""),
                "enforcement": .string("local_immediately_remote_on_receipt"),
                "links": .list(linkRows().map(ValueType.object))
            ]
        )
        stateQueue.sync { lastResult = result }
        return result
    }

    private func clearPending() -> Object {
        var removed = 0
        stateQueue.sync {
            let before = outgoingRequests.count
            let now = Date()
            outgoingRequests.removeAll { entry in
                guard entry.approvedAt == nil else { return true }
                guard let expiry = HavenValue.isoFormatter.date(from: entry.request.expiresAt) else { return true }
                return now > expiry
            }
            removed = before - outgoingRequests.count
        }
        return HavenValue.ok(
            "Ryddet \(removed) ferdige eller utløpte forespørsler.",
            sideEffect: removed > 0
        )
    }

    // MARK: - Presentation

    private func linkRows() -> [Object] {
        stateQueue.sync { links }.map { link in
            [
                "linkID": .string(link.linkID),
                "identityUUID": .string(link.linkedIdentity.uuid),
                "displayName": .string(link.linkedIdentity.displayName ?? link.linkedIdentity.uuid),
                "audience": .string(link.entityBinding.audience ?? ""),
                "status": .string(link.status.rawValue),
                "statusText": .string(Self.statusText(link.status)),
                "scopes": .list(link.approvedScopes.map(ValueType.string)),
                "scopeSummary": .string(link.approvedScopes.map { scope in
                    Self.defaultScopes.first { $0.id == scope }?.label ?? scope
                }.joined(separator: ", ")),
                "linkedAt": .string(link.linkedAt),
                "linkedAtText": .string(
                    HavenValue.isoFormatter.date(from: link.linkedAt).map(HavenValue.readable) ?? link.linkedAt
                ),
                "revokedAtText": .string(
                    link.revokedAt.flatMap { HavenValue.isoFormatter.date(from: $0) }.map(HavenValue.readable) ?? ""
                ),
                "summaryLine": .string(
                    "\(link.linkedIdentity.displayName ?? "Ukjent enhet") · \(Self.statusText(link.status))"
                )
            ]
        }
    }

    private static func statusText(_ status: IdentityLinkStatus) -> String {
        switch status {
        case .active: return "Aktiv"
        case .revoked: return "Trukket tilbake"
        case .expired: return "Utløpt"
        case .pending: return "Venter"
        }
    }

    private func pendingRows() -> [Object] {
        let now = Date()
        return stateQueue.sync { outgoingRequests }.map { entry in
            let expiry = HavenValue.isoFormatter.date(from: entry.request.expiresAt)
            let expired = expiry.map { now > $0 } ?? true
            return [
                "requestID": .string(entry.request.requestID),
                "humanCode": .string(entry.humanCode),
                "audience": .string(entry.request.audience),
                "deviceLabel": .string(entry.request.deviceLabel ?? ""),
                "createdAtText": .string(HavenValue.readable(entry.createdAt)),
                "expiresAt": .string(entry.request.expiresAt),
                "expired": .bool(expired),
                "approved": .bool(entry.approvedAt != nil),
                "linkID": .string(entry.linkID ?? ""),
                "statusLine": .string(
                    entry.approvedAt != nil
                        ? "Godkjent"
                        : (expired ? "Utløpt — start på nytt" : "Venter på godkjenning · kode \(entry.humanCode)")
                )
            ]
        }
    }

    private func stateObject() -> Object {
        let snapshot = stateQueue.sync { (links, outgoingRequests) }
        let active = snapshot.0.filter { $0.status == .active }.count
        let waiting = snapshot.1.filter { $0.approvedAt == nil }.count
        return [
            "schema": .string("haven.entityExtension.state.v1"),
            "summary": .string(
                active == 0 && waiting == 0
                    ? "Entiteten din finnes bare her. Du kan utvide den til et scaffold eller en annen enhet."
                    : "\(active) aktive koblinger" + (waiting > 0 ? ", \(waiting) venter på godkjenning." : ".")
            ),
            "activeLinkCount": .integer(active),
            "pendingCount": .integer(waiting),
            "links": .list(linkRows().map(ValueType.object)),
            "pending": .list(pendingRows().map(ValueType.object)),
            "safetyLine": .string(
                "Godkjenn bare en forespørsel du selv startet, og bare når koden er den samme på begge skjermene."
            ),
            "lastResult": .object(stateQueue.sync { lastResult }),
            "updatedAt": .string(HavenValue.iso(Date()))
        ]
    }

    private func fail(_ error: Object) -> Object {
        stateQueue.sync { lastResult = error }
        return error
    }

    // MARK: - Transport

    private static var platformName: String {
#if os(iOS)
        return "iOS"
#elseif os(macOS)
        return "macOS"
#elseif os(visionOS)
        return "visionOS"
#else
        return "unknown"
#endif
    }

    private static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return HavenInviteLink.base64URL(data)
    }

    private static func decodeRequest(from value: ValueType) -> IdentityEnrollmentRequest? {
        decodeTransport(IdentityEnrollmentRequest.self, from: value, key: "request")
    }

    private static func decodeApproval(from value: ValueType) -> IdentityEnrollmentApproval? {
        decodeTransport(IdentityEnrollmentApproval.self, from: value, key: "approval")
    }

    /// Accepts the packet as a base64url string, an embedded object, or the
    /// bare value — whichever the surface happened to send.
    private static func decodeTransport<T: Decodable>(_ type: T.Type, from value: ValueType, key: String) -> T? {
        let payload = HavenValue.object(value)
        if let text = HavenValue.string(payload?["payload"]) ?? HavenValue.string(value),
           let data = HavenInviteLink.dataFromBase64URL(text),
           let decoded = try? JSONDecoder().decode(type, from: data) {
            return decoded
        }
        if let embedded = payload?[key], let decoded = HavenValue.decode(type, from: embedded) {
            return decoded
        }
        return HavenValue.decode(type, from: value)
    }

    // MARK: - Discovery

    private func providerDescriptor() -> Object {
        [
            "id": .string("binding.entity-scaffold-extension"),
            "providerID": .string("binding.entity-scaffold-extension"),
            "kind": .string("entity_extension"),
            "title": .string("Utvid entiteten"),
            "summary": .string("Koble en ny enhet eller et nytt scaffold til entiteten din, med godkjenning fra et sted du allerede bruker."),
            "endpoint": .string(Self.endpoint),
            "sourceCellName": .string(Self.sourceCellName),
            "actionKeypath": .string("extension.beginRequest"),
            "purposeRefs": .list([
                .string("personal.entity.extend"),
                .string("purpose://extend-my-entity")
            ]),
            "interests": .list([
                .string("identity-linking"),
                .string("enrollment"),
                .string("scaffold"),
                .string("multi-device"),
                .string("requires-user-approval")
            ]),
            "availability": .string("available_in_cell_scope"),
            "privacyLevel": .string("owner_approved_identity_link"),
            "executionScope": .string("binding_local_cell"),
            "requiresUserApproval": .bool(true),
            "requiresNetwork": .bool(false),
            "canInvokeFromChat": .bool(true),
            "score": .float(0.87),
            "reason": .string("Å ta entiteten med til et nytt sted skal gå gjennom signert forespørsel og godkjenning, ikke gjennom kopiering av nøkler.")
        ]
    }

    private func purposeGoal() -> Object {
        [
            "title": .string("Utvid entiteten"),
            "summary": .string("Gjør det enkelt og trygt å ta entiteten med til en ny enhet eller et nytt scaffold, uten å flytte hemmeligheter."),
            "purposeRefs": .list([.string("personal.entity.extend")]),
            "interests": .list([.string("identity-linking"), .string("enrollment"), .string("multi-device")])
        ]
    }

    // MARK: - Surface

    nonisolated static func menuConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Utvid entiteten")
        configuration.description = "Ta entiteten din med til en ny enhet eller et nytt scaffold. Ny nøkkel der, godkjenning her — ingen hemmeligheter flyttes."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: sourceCellName,
            purpose: "Utvid entiteten til nye scaffolds og enheter",
            purposeDescription: "Bygger på CellBase' enrollment-primitiver: signert forespørsel fra det nye stedet, godkjenning bundet til forespørselens hash fra et sted du allerede bruker, og en koblingspost begge sider kan trekke tilbake.",
            interests: BindingPersonalCopilotV1Policy.discoveryInterests(
                [
                    "identity-linking",
                    "enrollment",
                    "scaffold",
                    "multi-device",
                    "purposeRef=personal.entity.extend"
                ],
                policyCategory: "identity-and-account"
            ),
            menuSlots: ["lowerRight"]
        )
        configuration.addReference(CellReference(endpoint: endpoint, subscribeFeed: false, label: "entityExtension"))

        var linkRow = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "displayName")),
            .Text(SkeletonText(keypath: "summaryLine")),
            .Text(SkeletonText(keypath: "scopeSummary")),
            .Text(SkeletonText(keypath: "linkedAtText")),
            .Button(SkeletonButton(
                keypath: "entityExtension.extension.revokeLink",
                label: "Trekk tilbake",
                payloadKeypath: "linkID"
            ))
        ], spacing: 4)
        linkRow.modifiers = SkeletonModifiers()
        linkRow.modifiers?.padding = 10
        linkRow.modifiers?.cornerRadius = 8
        linkRow.modifiers?.borderWidth = 1
        linkRow.modifiers?.borderColor = "#CBD5E1"

        var linkList = SkeletonList(
            topic: nil,
            keypath: "entityExtension.state.links",
            flowElementSkeleton: linkRow
        )
        linkList.modifiers = SkeletonModifiers()
        linkList.modifiers?.height = 260

        var pendingRow = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "audience")),
            .Text(SkeletonText(keypath: "statusLine")),
            .Text(SkeletonText(keypath: "createdAtText"))
        ], spacing: 3)
        pendingRow.modifiers = SkeletonModifiers()
        pendingRow.modifiers?.padding = 8

        var pendingList = SkeletonList(
            topic: nil,
            keypath: "entityExtension.state.pending",
            flowElementSkeleton: pendingRow
        )
        pendingList.modifiers = SkeletonModifiers()
        pendingList.modifiers?.height = 180

        configuration.skeleton = .ScrollView(SkeletonScrollView(elements: [
            .VStack(SkeletonVStack(elements: [
                .Text(SkeletonText(text: "Utvid entiteten")),
                .Text(SkeletonText(keypath: "entityExtension.state.summary")),
                .Text(SkeletonText(keypath: "entityExtension.state.safetyLine")),
                .TextField(SkeletonTextField(
                    targetKeypath: "entityExtension.extension.beginRequest",
                    placeholder: "Adressen til scaffoldet du vil utvide til"
                )),
                .Text(SkeletonText(keypath: "entityExtension.state.lastResult.message")),
                .Text(SkeletonText(keypath: "entityExtension.state.lastResult.humanCode")),
                .Text(SkeletonText(keypath: "entityExtension.state.lastResult.nextStep")),
                .Divider(SkeletonDivider()),
                .Text(SkeletonText(text: "Venter på godkjenning")),
                .List(pendingList),
                .Divider(SkeletonDivider()),
                .Text(SkeletonText(text: "Koblede steder")),
                .List(linkList)
            ], spacing: 12))
        ]))
        return configuration
    }
}

private extension Array where Element == String {
    var nilWhenEmpty: [String]? { isEmpty ? nil : self }
}
