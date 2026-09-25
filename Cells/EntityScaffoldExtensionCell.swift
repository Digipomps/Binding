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
//  Verktøylenker (B10, 2026-09-24): «Ber om tilgang», «Gi tilgang» og verktøyene under
//  «Koblede steder» er entitetslenker mellom deg og verktøycellene i HAVEN Agent. Lenken
//  kan startes fra begge sider, og begge ender viser hvem som svarte og når. Logikken ligger
//  i BindingToolLinkController.swift; her er bare nøklene og flaten.
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

    /// Lenker mellom deg og verktøycellene i den lokale agenten.
    nonisolated let toolLinks = BindingToolLinkController()
    nonisolated private static let toolLinkReadKeys: Set<String> = ["state", "extension.state", "extension.toolLinks"]

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
                if Self.toolLinkReadKeys.contains(key) {
                    await self.toolLinks.refreshForRead(ownerKey: ToolLinkSigner.publicKey(of: self.toolLinkIdentity(requester)))
                }
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
            "extension.toolLinks",
            "extension.toolLinks.selection",
            "extension.toolLinks.scopeSelection",
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
            "extension.clearPending",
            "extension.toolLinks.refresh",
            "extension.toolLinks.approve",
            "extension.toolLinks.decline",
            "extension.toolLinks.offer",
            "extension.toolLinks.revoke",
            "extension.toolLinks.selectTool",
            "extension.toolLinks.selectScope",
            "extension.toolLinks.selection",
            "extension.toolLinks.scopeSelection",
            "extension.toolLinks.pairAgent"
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
        case "extension.toolLinks":
            return .object(toolLinks.stateFields())
        case "extension.toolLinks.selection":
            return .object(toolLinks.toolSelection())
        case "extension.toolLinks.scopeSelection":
            return .object(toolLinks.scopeSelection())
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
        case "extension.toolLinks.refresh":
            return .object(await toolLinks.refresh(ownerKey: ToolLinkSigner.publicKey(of: toolLinkIdentity(requester))))
        case "extension.toolLinks.approve", "extension.toolLinks.decline", "extension.toolLinks.revoke":
            return .object(await answerToolLink(key, value: value, requester: requester))
        case "extension.toolLinks.offer":
            guard let signer = ToolLinkSigner.from(toolLinkIdentity(requester)) else {
                return .object(HavenValue.error(code: "no_key", message: "Denne HAVEN-en har ingen nøkkel som kan signere."))
            }
            return .object(await toolLinks.offer(signer: signer))
        case "extension.toolLinks.selectTool", "extension.toolLinks.selection":
            return .object(toolLinks.selectTool(value))
        case "extension.toolLinks.selectScope", "extension.toolLinks.scopeSelection":
            return .object(toolLinks.selectScope(value))
        case "extension.toolLinks.pairAgent":
            return .object(await pairAgentHere(requester: requester))
        default:
            return .object(HavenValue.error(code: "unsupported_keypath", message: "Ukjent utvidelses-handling."))
        }
    }

    // MARK: - Verktøylenker

    /// Samme valg som paringen gjør (AgentEnrollmentCell): den som trykker, når den har navn
    /// og nøkkel; ellers eieren av cellen. Agenten avviser en annen nøkkel enn den den er
    /// paret med, og flaten sier fra før du trykker.
    private func toolLinkIdentity(_ requester: Identity) -> Identity {
        if requester.displayName.isEmpty == false, ToolLinkSigner.publicKey(of: requester) != nil {
            return requester
        }
        return storedOwnerIdentity
    }

    private func answerToolLink(_ key: String, value: ValueType, requester: Identity) async -> Object {
        let payload = HavenValue.object(value)
        guard let contractID = HavenValue.string(payload?["contractID"]) ?? HavenValue.string(value),
              contractID.isEmpty == false else {
            return HavenValue.error(code: "missing_id", message: "Mangler `contractID`.")
        }
        guard let signer = ToolLinkSigner.from(toolLinkIdentity(requester)) else {
            return HavenValue.error(code: "no_key", message: "Denne HAVEN-en har ingen nøkkel som kan signere.")
        }
        switch key {
        case "extension.toolLinks.approve":
            return await toolLinks.approve(contractID: contractID, signer: signer)
        case "extension.toolLinks.decline":
            return await toolLinks.decline(contractID: contractID, signer: signer)
        default:
            return await toolLinks.revoke(contractID: contractID, signer: signer)
        }
    }

    /// Parer agenten med identiteten som brukes her — samme handling som «Opprett paring» i
    /// agentoppsettet (`AgentEnrollmentCell`, `enrollment.createPairingArtifact`): agenten
    /// attesterer, du signerer med Touch ID, og paringen og entitetslenken skrives der agenten
    /// leser dem. Rører ikke agentens config eller oppstart. Agenten tar i bruk den nye
    /// forankringen ved neste oppstart.
    private func pairAgentHere(requester: Identity) async -> Object {
        let identity = toolLinkIdentity(requester)
        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let enrollment = try? await resolver.cellAtEndpoint(endpoint: "cell:///AgentEnrollment", requester: identity) as? Meddle else {
            return toolLinks.note(HavenValue.error(
                code: "enrollment_unavailable",
                message: "Paring med agenten er ikke slått på i denne HAVEN-en (agentoppsettet)."
            ), in: .pairing)
        }
        let response: ValueType? = try? await enrollment.set(
            keypath: "enrollment.createPairingArtifact",
            value: .bool(true),
            requester: identity
        )
        let status = HavenValue.object(HavenValue.object(response)?["status"])
        if response == nil {
            return toolLinks.note(HavenValue.error(code: "pairing_failed", message: "Paringen fikk ikke svar fra agentoppsettet."), in: .pairing)
        }
        if let lastError = HavenValue.string(status?["lastError"]) {
            return toolLinks.note(HavenValue.error(code: "pairing_failed", message: "Paringen feilet: \(lastError)"), in: .pairing)
        }
        let key = ToolLinkSigner.publicKey(of: identity).map { ToolLinkCrypto.fingerprint(of: $0) } ?? "?"
        return toolLinks.note(HavenValue.ok(
            "Agenten er paret med denne HAVEN-en (nøkkel \(key)). Den bruker den nye paringen etter neste omstart; trykk Oppdater etterpå.",
            sideEffect: true
        ), in: .pairing)
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
        // Tekstfeltet på flaten sender adressen som ren tekst; chat og andre kallere sender
        // `{audience: …}`.
        let typed = (HavenValue.string(payload["audience"]) ?? HavenValue.string(value))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let audience = typed, audience.isEmpty == false else {
            return fail(HavenValue.error(
                code: "missing_audience",
                message: "Skriv adressen til scaffoldet du vil utvide til, for eksempel https://staging.haven.digipomps.org."
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
        let snapshot = stateQueue.sync { (links, outgoingRequests, lastResult) }
        let active = snapshot.0.filter { $0.status == .active }.count
        let waiting = snapshot.1.filter { $0.approvedAt == nil }.count
        let toolFields = toolLinks.stateFields()
        var state: Object = [
            "schema": .string("haven.entityExtension.state.v1"),
            "summary": .string(Self.summaryLine(
                active: active,
                waiting: waiting,
                agentHere: toolLinks.pairingState() == .here
            )),
            "activeLinkCount": .integer(active),
            "pendingCount": .integer(waiting),
            "links": .list(linkRows().map(ValueType.object)),
            "pending": .list(pendingRows().map(ValueType.object)),
            "safetyLine": .string(
                "Godkjenn bare en forespørsel du selv startet, og bare når koden er den samme på begge skjermene."
            ),
            "lastResult": .object(snapshot.2),
            // Radene i «Koblede steder» og «Nytt sted». Hver del av flaten er én liste; se
            // kommentaren over `surfacePage`.
            "linkedRows": .list(linkedPlaceRows(
                toolRows: HavenValue.list(toolFields["toolLinkedRows"]) ?? [],
                historyRows: HavenValue.list(toolFields["toolHistoryRows"]) ?? []
            ).map(ValueType.object)),
            "newPlaceRows": .list(newPlaceRows(lastResult: snapshot.2).map(ValueType.object)),
            "updatedAt": .string(HavenValue.iso(Date()))
        ]
        state.merge(toolFields) { current, _ in current }
        return state
    }

    /// Hvor entiteten finnes: her, i HAVEN Agent på denne maskinen når den er paret her, og på
    /// stedene den er utvidet til.
    private static func summaryLine(active: Int, waiting: Int, agentHere: Bool) -> String {
        let elsewhere = active == 1 ? "ett annet sted" : "\(active) andre steder"
        var line: String
        switch (agentHere, active) {
        case (true, 0):
            line = "Entiteten din finnes her og i HAVEN Agent på denne maskinen."
        case (true, _):
            line = "Entiteten din finnes her, i HAVEN Agent på denne maskinen og på \(elsewhere)."
        case (false, 0):
            line = "Entiteten din finnes bare her."
        case (false, _):
            line = "Entiteten din finnes her og på \(elsewhere)."
        }
        if waiting > 0 {
            line += waiting == 1 ? " Én forespørsel venter på godkjenning." : " \(waiting) forespørsler venter på godkjenning."
        }
        return line
    }

    /// «Koblede steder»: verktøyene i agenten som har tilgang, stedene entiteten er utvidet til,
    /// og de siste svarene.
    private func linkedPlaceRows(toolRows: [ValueType], historyRows: [ValueType]) -> [Object] {
        var rows = toolRows.compactMap { HavenValue.object($0) }
        let hasTools = rows.contains { HavenValue.string($0["kind"]) == "tool" }
        let devices: [Object] = linkRows().map { link in
            var row = link
            row["kind"] = .string("device")
            switch HavenValue.string(link["status"]) {
            case "active": row["tone"] = .string("success")
            case "revoked": row["tone"] = .string("danger")
            default: row["tone"] = .string("warning")
            }
            let scopes = HavenValue.string(link["scopeSummary"]).map { "Rettigheter: \($0)" }
            let linked = HavenValue.string(link["linkedAtText"]).map { "koblet \($0)" }
            row["detailLine"] = .string([scopes, linked].compactMap { $0 }.joined(separator: " · "))
            return row
        }
        rows += devices
        if hasTools == false && devices.isEmpty {
            rows.insert(["kind": .string("note"), "text": .string("Ingen koblede steder ennå.")], at: 0)
        }
        rows += historyRows.compactMap { HavenValue.object($0) }
        return rows
    }

    /// «Nytt sted»: svaret på det du sist gjorde her, og forespørslene som venter på godkjenning.
    private func newPlaceRows(lastResult: Object) -> [Object] {
        var rows: [Object] = []
        let failed = HavenValue.string(lastResult["status"]) == "error"
        let acted = HavenValue.bool(lastResult["sideEffect"]) == true
        if let message = HavenValue.string(lastResult["message"]), failed || acted {
            rows.append(["kind": .string(failed ? "failure" : "success"), "text": .string(message)])
            if let code = HavenValue.string(lastResult["humanCode"]) {
                rows.append([
                    "kind": .string("code"),
                    "text": .string("Koden du skal se på den andre skjermen:"),
                    "code": .string(code)
                ])
            }
        }
        let pending = pendingRows()
        if pending.isEmpty == false {
            rows.append(["kind": .string("subheading"), "text": .string("Venter på godkjenning"), "hasRefresh": .bool(false)])
            rows += pending.map { entry in
                var row = entry
                row["kind"] = .string("pending")
                return row
            }
        }
        return rows
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

        configuration.skeleton = surfacePage()
        return configuration
    }

    // MARK: - Flaten
    //
    // Godkjent skisse: G1-GUI v2 (HavenAgentD Docs/PDD_testflyt-verktoycelle_20260923/images/
    // haven-lenke-begge-veier-v2.png), i HAVENs designsystem (BindingPersonalCopilotDesignSystem):
    // kort, ekte knapper, ordene som merkelapp.
    //
    // Hvert kort har én liste der cellen bestemmer radene (`kind`). En skjult rad tar ingen plass,
    // men en tom liste gjør det, og synlighet med rot-scope virker ikke på toppnivå — der finnes
    // ingen verdi å sjekke mot (lesson.unresolvable-condition-is-invisible). Inne i en rad virker
    // `scope: .item`. Merkelapper står på egen linje i en HStack med `wrap`, som legger dem etter
    // hverandre fra venstre i sin egen bredde; knapper står i en vanlig HStack, som kan krympe
    // dem. Tekst står aldri på samme linje som en knapp eller merkelapp, fordi `wrap`
    // toppstiller elementene.

    private typealias Style = BindingPersonalCopilotDesignSystem

    nonisolated private static func surfacePage() -> SkeletonElement {
        var hero = SkeletonVStack(elements: [
            .Text(Style.headingText("Utvid entiteten")),
            boundText("entityExtension.state.summary", color: Style.textPrimary),
            boundText("entityExtension.state.safetyLine", color: Style.textTertiary, size: 12)
        ], spacing: 6)
        hero.modifiers = Style.compactHeroPanel()

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .VStack(agentCard()),
            .VStack(linkedPlacesCard()),
            .VStack(newPlaceCard())
        ], spacing: 12)
        root.modifiers = Style.pageCard()

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        var scrollModifiers = SkeletonModifiers()
        scrollModifiers.padding = 6
        scrollModifiers.background = Style.canvas
        scrollModifiers.maxWidthInfinity = true
        scroll.modifiers = scrollModifiers
        return .ScrollView(scroll)
    }

    /// «HAVEN Agent på denne maskinen»: A (verktøyet ber, du svarer her) og B (du tilbyr her,
    /// svaret gis i HAVEN Agent). Er agenten paret med en annen identitet, er paringen alt kortet
    /// viser. Radene: `BindingToolLinkController.agentRowsLocked`.
    nonisolated private static func agentCard() -> SkeletonVStack {
        card("HAVEN Agent på denne maskinen", [
            rowList("entityExtension.state.toolAgentRows", [
                pairingRow(),
                problemRow(),
                subheadingRow(),
                requestRow(),
                offerFormRow(),
                outgoingRow(),
                messageRow("note", color: Style.textSecondary),
                messageRow("success", color: Style.success),
                messageRow("failure", color: Style.danger)
            ])
        ])
    }

    /// «Koblede steder»: verktøyene som har tilgang, stedene entiteten er utvidet til, og de
    /// siste svarene som spor. Radene: `linkedPlaceRows`.
    nonisolated private static func linkedPlacesCard() -> SkeletonVStack {
        card("Koblede steder", [
            rowList("entityExtension.state.linkedRows", [
                toolLinkRow(),
                deviceLinkRow(),
                subheadingRow(),
                historyRow(),
                messageRow("note", color: Style.textSecondary),
                messageRow("success", color: Style.success),
                messageRow("failure", color: Style.danger)
            ])
        ])
    }

    /// «Nytt sted»: be om å bli koblet til entiteten fra et nytt scaffold. Radene: `newPlaceRows`.
    nonisolated private static func newPlaceCard() -> SkeletonVStack {
        card("Nytt sted", [
            staticText("Skriv adressen til scaffoldet du vil utvide til, og trykk Enter. Du får en kode og en pakke du godkjenner fra et sted du allerede bruker. Ingen hemmeligheter flyttes."),
            .TextField(SkeletonTextField(
                targetKeypath: "entityExtension.extension.beginRequest",
                placeholder: "Adressen til scaffoldet, for eksempel https://staging.haven.digipomps.org"
            )),
            rowList("entityExtension.state.newPlaceRows", [
                codeRow(),
                subheadingRow(),
                pendingRow(),
                messageRow("note", color: Style.textSecondary),
                messageRow("success", color: Style.success),
                messageRow("failure", color: Style.danger)
            ])
        ])
    }

    // MARK: Radene

    nonisolated private static func pairingRow() -> SkeletonElement {
        var modifiers = SkeletonModifiers()
        modifiers.padding = 12
        modifiers.background = Style.warningSoft
        modifiers.cornerRadius = 14
        modifiers.borderWidth = 1
        modifiers.borderColor = Style.warning
        return kind("pairing", [
            boundText("title", color: Style.textPrimary, size: 15, weight: "semibold"),
            boundText("body"),
            buttonRow([
                button("Par agenten med denne HAVEN-en", "entityExtension.extension.toolLinks.pairAgent", primary: true),
                button("Oppdater", "entityExtension.extension.toolLinks.refresh", primary: false)
            ]),
            boundText("footnote", color: Style.textTertiary, size: 12)
        ], spacing: 8, modifiers: modifiers)
    }

    nonisolated private static func problemRow() -> SkeletonElement {
        kind("problem", [
            boundText("text", color: Style.warning),
            buttonRow([button("Prøv igjen", "entityExtension.extension.toolLinks.refresh", primary: false)])
        ], spacing: 8)
    }

    /// Overskrift i et kort; «Oppdater» til høyre når raden ber om det.
    nonisolated private static func subheadingRow() -> SkeletonElement {
        let line = SkeletonHStack(elements: [
            boundText("text", color: Style.textPrimary, size: 15, weight: "semibold"),
            button("Oppdater", "entityExtension.extension.toolLinks.refresh", primary: false, visibleWhen: ("hasRefresh", .bool(true)))
        ], spacing: 8)
        return kind("subheading", [.HStack(line)], spacing: 0)
    }

    /// A: verktøyet ber — du svarer her. Knappene finnes bare når HAVEN har sjekket forespørselen.
    nonisolated private static func requestRow() -> SkeletonElement {
        var modifiers = SkeletonModifiers()
        modifiers.padding = 12
        modifiers.background = Style.surface
        modifiers.cornerRadius = 14
        modifiers.borderWidth = 1
        modifiers.borderColor = Style.brandPrimary
        return kind("request", [
            boundText("headline", color: Style.textPrimary, size: 15, markdown: true),
            boundText("detailLine", color: Style.textTertiary, size: 12),
            inline([chip("securityCode", tone: "words")]),
            boundText("question", color: Style.textPrimary, visibleWhen: ("canAnswer", .bool(true))),
            boundText("warning", color: Style.danger, visibleWhen: ("hasWarning", .bool(true))),
            buttonRow([
                button("Godkjenn", "entityExtension.extension.toolLinks.approve", payload: "contractID", primary: true),
                button("Avvis", "entityExtension.extension.toolLinks.decline", payload: "contractID", primary: false)
            ], visibleWhen: ("canAnswer", .bool(true)))
        ], spacing: 8, modifiers: modifiers)
    }

    /// B: du tilbyr her — svaret gis i HAVEN Agent.
    nonisolated private static func offerFormRow() -> SkeletonElement {
        kind("offerForm", [
            staticText("Gi et verktøy i agenten din tilgang. Du signerer først; svaret gis i HAVEN Agent."),
            picker("Verktøy", options: "entityExtension.state.toolChoices", selection: "entityExtension.extension.toolLinks.selection"),
            picker("Tilgang", options: "entityExtension.state.toolScopeChoices", selection: "entityExtension.extension.toolLinks.scopeSelection"),
            buttonRow([button("Tilby", "entityExtension.extension.toolLinks.offer", primary: true)])
        ], spacing: 8)
    }

    nonisolated private static func outgoingRow() -> SkeletonElement {
        kind("outgoing", [
            boundText("title", color: Style.textPrimary),
            inline([chip("securityCode", tone: "words"), chip("statusLine", tone: "warning")])
        ], spacing: 6)
    }

    /// Etter svaret: verktøyet som har tilgang, hvem som svarte og når, og «Trekk tilbake».
    nonisolated private static func toolLinkRow() -> SkeletonElement {
        kind("tool", [
            boundText("title", color: Style.textPrimary, weight: "semibold"),
            inline([
                chip("statusLine", tone: "success"),
                button("Trekk tilbake", "entityExtension.extension.toolLinks.revoke", payload: "contractID", primary: false)
            ]),
            boundText("detailLine", color: Style.textTertiary, size: 12)
        ], spacing: 6)
    }

    nonisolated private static func deviceLinkRow() -> SkeletonElement {
        kind("device", [
            boundText("displayName", color: Style.textPrimary, weight: "semibold"),
            inline([
                chip("statusText", tone: "success", whenTone: "success"),
                chip("statusText", tone: "danger", whenTone: "danger"),
                chip("statusText", tone: "warning", whenTone: "warning"),
                button("Trekk tilbake", "entityExtension.extension.revokeLink", payload: "linkID", primary: false, visibleWhen: ("status", .string("active")))
            ]),
            boundText("detailLine", color: Style.textTertiary, size: 12)
        ], spacing: 6)
    }

    /// Et svar som spor: én linje, farget etter hva svaret ble.
    nonisolated private static func historyRow() -> SkeletonElement {
        kind("history", [
            boundText("summaryLine", color: Style.success, size: 13, visibleWhen: ("tone", .string("success"))),
            boundText("summaryLine", color: Style.danger, size: 13, visibleWhen: ("tone", .string("danger"))),
            boundText("summaryLine", color: Style.warning, size: 13, visibleWhen: ("tone", .string("warning"))),
            boundText("summaryLine", color: Style.textSecondary, size: 13, visibleWhen: ("tone", .string("neutral")))
        ], spacing: 0)
    }

    nonisolated private static func codeRow() -> SkeletonElement {
        kind("code", [
            boundText("text", color: Style.textPrimary),
            inline([chip("code", tone: "words")])
        ], spacing: 6)
    }

    nonisolated private static func pendingRow() -> SkeletonElement {
        kind("pending", [
            boundText("audience", color: Style.textPrimary, weight: "semibold"),
            boundText("statusLine"),
            boundText("createdAtText", color: Style.textTertiary, size: 12)
        ], spacing: 4)
    }

    nonisolated private static func messageRow(_ name: String, color: String) -> SkeletonElement {
        kind(name, [boundText("text", color: color)], spacing: 0)
    }

    // MARK: Byggesteiner

    nonisolated private static func card(_ title: String, _ elements: SkeletonElementList) -> SkeletonVStack {
        var card = SkeletonVStack(elements: [.Text(Style.headingText(title))] + elements, spacing: 8)
        card.modifiers = Style.sectionCard()
        return card
    }

    /// Én liste med rader av ulike slag. Radens `kind` velger hvilken del som vises.
    nonisolated private static func rowList(_ keypath: String, _ kinds: SkeletonElementList) -> SkeletonElement {
        .List(SkeletonList(topic: nil, keypath: keypath, flowElementSkeleton: SkeletonVStack(elements: kinds, spacing: 0)))
    }

    nonisolated private static func kind(
        _ name: String,
        _ elements: SkeletonElementList,
        spacing: Double,
        modifiers: SkeletonModifiers = SkeletonModifiers()
    ) -> SkeletonElement {
        var stack = SkeletonVStack(elements: elements, spacing: spacing)
        var stackModifiers = modifiers
        stackModifiers.visibility = whenItem("kind", equals: .string(name))
        stack.modifiers = stackModifiers
        return .VStack(stack)
    }

    nonisolated private static func whenItem(_ keypath: String, equals value: ValueType) -> SkeletonVisibilityRule {
        SkeletonVisibilityRule(when: SkeletonCondition(scope: .item, keypath: keypath, equals: value))
    }

    nonisolated private static func boundText(
        _ keypath: String,
        color: String = Style.textSecondary,
        size: Double = 14,
        weight: String? = nil,
        markdown: Bool = false,
        visibleWhen: (String, ValueType)? = nil
    ) -> SkeletonElement {
        var text = SkeletonText(keypath: keypath)
        text.modifiers = textModifiers(color: color, size: size, weight: weight, markdown: markdown, visibleWhen: visibleWhen)
        return .Text(text)
    }

    nonisolated private static func staticText(_ value: String, color: String = Style.textSecondary, size: Double = 14) -> SkeletonElement {
        var text = SkeletonText(text: value)
        text.modifiers = textModifiers(color: color, size: size, weight: nil, markdown: false, visibleWhen: nil)
        return .Text(text)
    }

    nonisolated private static func textModifiers(
        color: String,
        size: Double,
        weight: String?,
        markdown: Bool,
        visibleWhen: (String, ValueType)?
    ) -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        modifiers.foregroundColor = color
        modifiers.fontSize = size
        modifiers.fontWeight = weight
        modifiers.multilineTextAlignment = "leading"
        if markdown { modifiers.styleRole = "markdown" }
        if let visibleWhen { modifiers.visibility = whenItem(visibleWhen.0, equals: visibleWhen.1) }
        return modifiers
    }

    /// Merkelapper (og en kort knapp ved siden av) etter hverandre fra venstre, i sin egen
    /// bredde. `wrap` gir hvert element dets ideelle bredde, så bare korte ting hører hjemme her.
    nonisolated private static func inline(_ elements: SkeletonElementList, visibleWhen: (String, ValueType)? = nil) -> SkeletonElement {
        var row = SkeletonHStack(elements: elements, spacing: 8)
        var modifiers = SkeletonModifiers()
        modifiers.wrap = true
        if let visibleWhen { modifiers.visibility = whenItem(visibleWhen.0, equals: visibleWhen.1) }
        row.modifiers = modifiers
        return .HStack(row)
    }

    /// Knapper på én linje. En vanlig HStack kan krympe knappene og bryte en lang tekst, i
    /// stedet for å la dem gå ut over kortet slik `wrap` gjør.
    nonisolated private static func buttonRow(_ buttons: SkeletonElementList, visibleWhen: (String, ValueType)? = nil) -> SkeletonElement {
        var row = SkeletonHStack(elements: buttons, spacing: 8)
        if let visibleWhen {
            var modifiers = SkeletonModifiers()
            modifiers.visibility = whenItem(visibleWhen.0, equals: visibleWhen.1)
            row.modifiers = modifiers
        }
        return .HStack(row)
    }

    nonisolated private static func button(
        _ label: String,
        _ keypath: String,
        payload: String? = nil,
        primary: Bool,
        visibleWhen: (String, ValueType)? = nil
    ) -> SkeletonElement {
        var button = SkeletonButton(keypath: keypath, label: label, payloadKeypath: payload)
        var modifiers = primary ? Style.primaryButton() : Style.secondaryButton()
        modifiers.padding = 8
        modifiers.fontSize = 14
        modifiers.fontWeight = primary ? "semibold" : "medium"
        if let visibleWhen { modifiers.visibility = whenItem(visibleWhen.0, equals: visibleWhen.1) }
        button.modifiers = modifiers
        return .Button(button)
    }

    /// Merkelapp: ordene (lilla), eller et svar (grønn, rød, gul).
    nonisolated private static func chip(_ keypath: String, tone: String, whenTone: String? = nil) -> SkeletonElement {
        let colors: (background: String, text: String)
        switch tone {
        case "success": colors = (Style.successSoft, Style.success)
        case "danger": colors = (Style.dangerSoft, Style.danger)
        case "warning": colors = (Style.warningSoft, Style.warning)
        default: colors = (Style.brandSubtle, Style.brandStrong)
        }
        var text = SkeletonText(keypath: keypath)
        var modifiers = Style.badgeModifier(background: colors.background, borderColor: colors.background, foregroundColor: colors.text)
        modifiers.cornerRadius = 8
        modifiers.fontSize = tone == "words" ? 15 : 13
        modifiers.fontWeight = tone == "words" ? "semibold" : "medium"
        if let whenTone { modifiers.visibility = whenItem("tone", equals: .string(whenTone)) }
        text.modifiers = modifiers
        return .Text(text)
    }

    /// Velger som viser valget sitt ved siden av navnet («Verktøy: Losen (verktøycelle)»).
    /// `selectionStateKeypath` leses og skrives (lesson.picker-state-keypath-is-read-and-written).
    nonisolated private static func picker(_ name: String, options: String, selection: String) -> SkeletonElement {
        let picker = SkeletonPicker(
            label: nil,
            placeholder: name,
            keypath: options,
            optionLabelKeypath: "label",
            selectionValueKeypath: "value",
            selectionStateKeypath: selection,
            selectionPayloadMode: .itemID
        )
        return .Picker(picker)
    }
}

private extension Array where Element == String {
    var nilWhenEmpty: [String]? { isEmpty ? nil : self }
}
