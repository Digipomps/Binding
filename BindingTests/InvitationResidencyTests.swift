// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

// MARK: - Ticket shape and links

@Suite struct HavenInviteLinkTests {

    private func descriptor() -> IdentityPublicKeyDescriptor {
        IdentityPublicKeyDescriptor(
            uuid: "issuer-uuid",
            displayName: "Kjetil",
            publicKey: Data(repeating: 7, count: 33),
            algorithm: .ECDSA,
            curveType: .P256
        )
    }

    private func unsignedTicket() -> HavenInviteTicket {
        let now = Int(Date().timeIntervalSince1970)
        return HavenInviteTicket(
            ticketID: "inv-test-1",
            issuer: descriptor(),
            issuerDisplayName: "Kjetil",
            issuerContactEndpoint: "ep-1",
            audienceToken: "abcdef0123456789",
            audienceKind: "email",
            humanCode: "ABC234",
            createdAt: now,
            expiresAt: now + 3600,
            nonce: Data(repeating: 3, count: 12)
        )
    }

    @Test func aTicketSurvivesTheRoundTripThroughALink() throws {
        let ticket = unsignedTicket()
        #expect(try HavenInviteLink.decode(try HavenInviteLink.encode(ticket)) == ticket)
    }

    @Test func theTokenCanBeRecoveredFromEveryLinkShape() throws {
        let ticket = unsignedTicket()
        let token = try HavenInviteLink.encode(ticket)
        let base = "https://haven.digipomps.org"

        let universal = try #require(try HavenInviteLink.universalLink(for: ticket, landingBase: base))
        #expect(try HavenInviteLink.token(fromLink: universal) == token)
        #expect(try HavenInviteLink.token(fromLink: try HavenInviteLink.appLink(for: ticket)) == token)
        #expect(try HavenInviteLink.token(fromLink: token) == token)
    }

    /// Mail gateways rewrite links. The token still sits at the end.
    @Test func aRewrittenMailGatewayLinkStillYieldsTheToken() throws {
        let ticket = unsignedTicket()
        let token = try HavenInviteLink.encode(ticket)
        let rewritten = "https://eur01.safelinks.example.com/redirect/i/\(token)"
        #expect(try HavenInviteLink.token(fromLink: rewritten) == token)
    }

    @Test func withoutAScaffoldThereIsNoUniversalLinkAndWeSaySoRatherThanFakeOne() throws {
        let ticket = unsignedTicket()
        #expect(try HavenInviteLink.universalLink(for: ticket, landingBase: "") == nil)
        #expect(try HavenInviteLink.appLink(for: ticket).hasPrefix("haven://invite/"))
    }

    @Test func humanCodesAreStableReadableAndFreeOfLookalikeCharacters() {
        let code = HavenInviteLink.humanCode(from: "inv-test-1|token")
        #expect(code.count == 6)
        #expect(code == HavenInviteLink.humanCode(from: "inv-test-1|token"))
        for lookalike in ["0", "O", "1", "I", "L"] {
            #expect(!code.contains(lookalike))
        }
        #expect(HavenInviteLink.looksLikeHumanCode(code))
        #expect(!HavenInviteLink.looksLikeHumanCode("abcdef"))
    }

    /// The compact wire format is the reason SMS is even conceivable. If a
    /// field name creeps back in, this catches it before a user does.
    @Test func theWireFormatStaysCompact() throws {
        let encoded = try JSONEncoder().encode(unsignedTicket())
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(json.contains("\"t\":"))
        #expect(!json.contains("\"ticketID\""))
        #expect(!json.contains("\"landingBase\""))
        // The default capability set is implied, not carried.
        #expect(!json.contains("create_own_entity"))
    }

    @Test func aTicketWithoutAContactEndpointDoesNotPromiseAReply() {
        var ticket = unsignedTicket()
        ticket.issuerContactEndpoint = nil
        #expect(!ticket.canReceiveContactRequest)
        #expect(HavenInviteCopy.boundary(for: ticket) == HavenInviteCopy.boundaryLineWithoutReply)

        ticket.issuerContactEndpoint = "ep-1"
        #expect(ticket.canReceiveContactRequest)
        #expect(HavenInviteCopy.boundary(for: ticket) == HavenInviteCopy.boundaryLine)
    }

    @Test func rubbishIsRejectedRatherThanHalfDecoded() {
        #expect(throws: (any Error).self) {
            try HavenInviteLink.decode("dette-er-ikke-en-billett")
        }
    }
}

// MARK: - Signing and verification

@Suite(.serialized) struct HavenInviteVerifierTests {

    /// One vault per test, not one per identity. `EphemeralIdentityVault`
    /// numbers identities from 1 within itself, so two vaults hand out the same
    /// UUID and every "is this a different person?" check silently collapses.
    private let vault = EphemeralIdentityVault()

    private func makeOwner() async throws -> Identity {
        return try #require(await vault.identity(
            for: "haven-invite-test-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
    }

    private func signedTicket(
        owner: Identity,
        audienceToken: String = "abcdef0123456789",
        expiresIn: TimeInterval = 3600
    ) async throws -> HavenInviteTicket {
        let descriptor = try #require(IdentityPublicKeySignatureVerifier.descriptor(for: owner))
        let now = Int(Date().timeIntervalSince1970)
        var ticket = HavenInviteTicket(
            ticketID: "inv-\(UUID().uuidString.lowercased())",
            issuer: descriptor,
            issuerDisplayName: owner.displayName,
            issuerContactEndpoint: "ep-1",
            audienceToken: audienceToken,
            audienceKind: "email",
            humanCode: "ABC234",
            createdAt: now,
            expiresAt: now + Int(expiresIn),
            nonce: Data(repeating: 9, count: 12)
        )
        let signature = try #require(try await owner.sign(data: try ticket.canonicalPayloadData()))
        ticket.proof = HavenSignatureProof(
            byIdentityUUID: descriptor.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )
        return ticket
    }

    @Test func aFreshlySignedTicketVerifies() async throws {
        let ticket = try await signedTicket(owner: try await makeOwner())
        let verdict = HavenInviteVerifier.verify(ticket: ticket)
        #expect(verdict.signatureValid)
        #expect(verdict.isValid)
        #expect(verdict.code == "valid")
    }

    /// The whole point of signing: changing one word must break it.
    @Test func editingTheTicketBreaksTheSignature() async throws {
        var ticket = try await signedTicket(owner: try await makeOwner())
        ticket.note = "…og du får full tilgang til alt mitt"
        let verdict = HavenInviteVerifier.verify(ticket: ticket)
        #expect(!verdict.signatureValid)
        #expect(verdict.code == "bad_signature")
    }

    @Test func swappingTheIssuerNameBreaksItToo() async throws {
        var ticket = try await signedTicket(owner: try await makeOwner())
        ticket.issuerDisplayName = "Noen andre"
        #expect(!HavenInviteVerifier.verify(ticket: ticket).signatureValid)
    }

    @Test func anExpiredTicketIsRefusedWithAReadableReason() async throws {
        let ticket = try await signedTicket(owner: try await makeOwner(), expiresIn: -60)
        let verdict = HavenInviteVerifier.verify(ticket: ticket)
        #expect(verdict.signatureValid)
        #expect(verdict.expired)
        #expect(!verdict.isValid)
        #expect(verdict.code == "expired")
    }

    @Test func aRevokedTicketIsRefused() async throws {
        let ticket = try await signedTicket(owner: try await makeOwner())
        let verdict = HavenInviteVerifier.verify(ticket: ticket, revokedTicketIDs: [ticket.ticketID])
        #expect(verdict.revoked)
        #expect(verdict.code == "revoked")
    }

    @Test func aTicketAddressedElsewhereIsRefusedWhenWeKnowWhoItShouldBe() async throws {
        let ticket = try await signedTicket(owner: try await makeOwner(), audienceToken: "1111111111111111")
        let verdict = HavenInviteVerifier.verify(ticket: ticket, expectedAudienceToken: "2222222222222222")
        #expect(verdict.audienceMatches == false)
        #expect(verdict.code == "wrong_audience")
    }

    /// The landing page never knows who the ticket was for, so it must not
    /// claim a mismatch it cannot see.
    @Test func anUnknownAudienceIsNilRatherThanFalse() async throws {
        let ticket = try await signedTicket(owner: try await makeOwner())
        #expect(HavenInviteVerifier.verify(ticket: ticket).audienceMatches == nil)
    }

    @Test func aProofPointingAtAnotherIdentityIsRefusedEvenIfItVerifies() async throws {
        var ticket = try await signedTicket(owner: try await makeOwner())
        ticket.proof?.byIdentityUUID = "someone-else"
        #expect(HavenInviteVerifier.verify(ticket: ticket).code == "issuer_mismatch")
    }

    @Test func aSignedTicketStillVerifiesAfterATripThroughALink() async throws {
        let ticket = try await signedTicket(owner: try await makeOwner())
        let link = try #require(try HavenInviteLink.universalLink(for: ticket, landingBase: "https://haven.digipomps.org"))
        let recovered = try HavenInviteLink.decode(try HavenInviteLink.token(fromLink: link))
        #expect(HavenInviteVerifier.verify(ticket: recovered).isValid)
    }

    /// Binding and the landing page must say the same thing about the same
    /// ticket. One shared serialisation is how that stays true.
    @Test func theVerdictPayloadIsTheSharedContract() async throws {
        let ticket = try await signedTicket(owner: try await makeOwner())
        let payload = HavenInviteVerifier.payload(
            for: HavenInviteVerifier.verify(ticket: ticket),
            ticket: ticket
        )
        for key in [
            "schema", "status", "isValid", "signatureValid", "expired", "revoked",
            "audienceMatches", "reason", "code", "ticketID", "issuerDisplayName",
            "issuerIdentityUUID", "capabilities", "canReceiveContactRequest",
            "grantsAccess", "boundaryStatement", "humanCode", "expiresAt"
        ] {
            #expect(payload[key] != nil, "verdict payload is missing \(key)")
        }
        #expect(HavenValue.bool(payload["grantsAccess"]) == false)
        #expect(HavenValue.string(payload["schema"]) == HavenInviteVerifier.schema)
    }
}

// MARK: - Publication envelopes

@Suite(.serialized) struct HavenInvitePublicationTests {

    /// Shared on purpose — see the note in `HavenInviteVerifierTests`. Two
    /// vaults would give issuer and invitee the same UUID, and the contact
    /// request would be refused for impersonating the issuer.
    private let vault = EphemeralIdentityVault()

    private func makeOwner(_ label: String = "publisher") async throws -> Identity {
        return try #require(await vault.identity(
            for: "haven-publication-\(label)-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
    }

    private func signedTicket(owner: Identity) async throws -> HavenInviteTicket {
        let descriptor = try #require(IdentityPublicKeySignatureVerifier.descriptor(for: owner))
        let now = Int(Date().timeIntervalSince1970)
        var ticket = HavenInviteTicket(
            ticketID: "inv-\(UUID().uuidString.lowercased())",
            issuer: descriptor,
            issuerDisplayName: owner.displayName,
            issuerContactEndpoint: "ep-1",
            audienceToken: "aaaabbbbccccdddd",
            audienceKind: "email",
            humanCode: HavenInviteLink.humanCode(from: UUID().uuidString),
            createdAt: now,
            expiresAt: now + 86_400,
            nonce: Data(repeating: 1, count: 12)
        )
        let signature = try #require(try await owner.sign(data: try ticket.canonicalPayloadData()))
        ticket.proof = HavenSignatureProof(
            byIdentityUUID: descriptor.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )
        return ticket
    }

    private func signedPublication(owner: Identity, ticket: HavenInviteTicket) async throws -> HavenInvitePublication {
        let descriptor = try #require(IdentityPublicKeySignatureVerifier.descriptor(for: owner))
        var publication = HavenInvitePublication(
            ticketID: ticket.ticketID,
            humanCode: ticket.humanCode,
            ticketToken: try HavenInviteLink.encode(ticket),
            audienceToken: ticket.audienceToken,
            issuerIdentityUUID: descriptor.uuid,
            expiresAt: ticket.expiresAt,
            publishedAt: Int(Date().timeIntervalSince1970),
            statusKey: HavenInvitePublication.makeStatusKey()
        )
        let signature = try #require(try await owner.sign(data: try publication.canonicalPayloadData()))
        publication.proof = HavenSignatureProof(
            byIdentityUUID: descriptor.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )
        return publication
    }

    @Test func aGenuinePublicationVerifies() async throws {
        let owner = try await makeOwner()
        let ticket = try await signedTicket(owner: owner)
        let publication = try await signedPublication(owner: owner, ticket: ticket)
        let recovered = try HavenInvitePublicationVerifier.verifyPublication(publication)
        #expect(recovered.ticketID == ticket.ticketID)
    }

    /// Someone who intercepted a link must not be able to re-publish it under
    /// a code they control.
    @Test func republishingUnderADifferentCodeIsRefused() async throws {
        let owner = try await makeOwner()
        let ticket = try await signedTicket(owner: owner)
        var publication = try await signedPublication(owner: owner, ticket: ticket)
        publication.humanCode = "ZZZZ99"
        #expect(throws: (any Error).self) {
            try HavenInvitePublicationVerifier.verifyPublication(publication)
        }
    }

    @Test func aPublicationSignedBySomebodyElseIsRefused() async throws {
        let owner = try await makeOwner("a")
        let stranger = try await makeOwner("b")
        let ticket = try await signedTicket(owner: owner)
        var publication = try await signedPublication(owner: owner, ticket: ticket)

        let strangerDescriptor = try #require(IdentityPublicKeySignatureVerifier.descriptor(for: stranger))
        let signature = try #require(try await stranger.sign(data: try publication.canonicalPayloadData()))
        publication.proof = HavenSignatureProof(
            byIdentityUUID: strangerDescriptor.uuid,
            algorithm: strangerDescriptor.algorithm,
            curveType: strangerDescriptor.curveType,
            signature: signature
        )
        #expect(throws: (any Error).self) {
            try HavenInvitePublicationVerifier.verifyPublication(publication)
        }
    }

    @Test func aRevocationFromAStrangerIsRefused() async throws {
        let owner = try await makeOwner("a")
        let stranger = try await makeOwner("b")
        let ticket = try await signedTicket(owner: owner)
        let descriptor = try #require(IdentityPublicKeySignatureVerifier.descriptor(for: stranger))
        var notice = HavenInviteRevocationNotice(
            ticketID: ticket.ticketID,
            reason: "ikke min",
            revokedAt: Int(Date().timeIntervalSince1970),
            issuerIdentityUUID: descriptor.uuid
        )
        let signature = try #require(try await stranger.sign(data: try notice.canonicalPayloadData()))
        notice.proof = HavenSignatureProof(
            byIdentityUUID: descriptor.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )
        #expect(throws: (any Error).self) {
            try HavenInvitePublicationVerifier.verifyRevocation(notice, againstIssuerOf: ticket)
        }
    }

    @Test func aContactRequestVerifiesAgainstItsOwnKeyAndItsTicket() async throws {
        let issuer = try await makeOwner("issuer")
        let invitee = try await makeOwner("invitee")
        let ticket = try await signedTicket(owner: issuer)
        let inviteeDescriptor = try #require(IdentityPublicKeySignatureVerifier.descriptor(for: invitee))
        let now = Int(Date().timeIntervalSince1970)

        var request = HavenInviteContactRequest(
            requestID: "req-\(UUID().uuidString.lowercased())",
            ticketID: ticket.ticketID,
            issuerEndpointID: "ep-1",
            sender: inviteeDescriptor,
            senderDisplayName: "Vegar Hansen",
            message: "Hei! Ja, jeg er nysgjerrig.",
            createdAt: now,
            expiresAt: now + 3600,
            nonce: Data(repeating: 5, count: 12)
        )
        let signature = try #require(try await invitee.sign(data: try request.canonicalPayloadData()))
        request.proof = HavenSignatureProof(
            byIdentityUUID: inviteeDescriptor.uuid,
            algorithm: inviteeDescriptor.algorithm,
            curveType: inviteeDescriptor.curveType,
            signature: signature
        )

        try HavenInvitePublicationVerifier.verifyContactRequest(request, forTicket: ticket)

        // …and maps onto the contract the ContactEndpoint cell already speaks.
        let payload = request.contactEndpointPayload()
        #expect(HavenValue.string(payload["schema"]) == "cellprotocol.contact.request.v1")
        #expect(HavenValue.string(payload["endpointId"]) == "ep-1")
        #expect(HavenValue.string(payload["topic"]) == "contact.request")
    }

    @Test func aContactRequestForAnotherTicketIsRefused() async throws {
        let issuer = try await makeOwner("issuer")
        let invitee = try await makeOwner("invitee")
        let ticket = try await signedTicket(owner: issuer)
        let descriptor = try #require(IdentityPublicKeySignatureVerifier.descriptor(for: invitee))
        let now = Int(Date().timeIntervalSince1970)
        var request = HavenInviteContactRequest(
            requestID: "req-x",
            ticketID: "inv-some-other-ticket",
            issuerEndpointID: "ep-1",
            sender: descriptor,
            senderDisplayName: "Vegar",
            createdAt: now,
            expiresAt: now + 3600,
            nonce: Data()
        )
        let signature = try #require(try await invitee.sign(data: try request.canonicalPayloadData()))
        request.proof = HavenSignatureProof(
            byIdentityUUID: descriptor.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )
        #expect(throws: (any Error).self) {
            try HavenInvitePublicationVerifier.verifyContactRequest(request, forTicket: ticket)
        }
    }

    @Test func statusKeysAreLongEnoughThatGuessingIsNotAStrategy() {
        let first = HavenInvitePublication.makeStatusKey()
        #expect(first.count >= 40)
        #expect(first != HavenInvitePublication.makeStatusKey())
    }
}

// MARK: - Composed messages

@Suite struct HavenInviteCopyTests {

    private var ticket: HavenInviteTicket {
        let now = Int(Date().timeIntervalSince1970)
        return HavenInviteTicket(
            ticketID: "inv-1",
            issuer: IdentityPublicKeyDescriptor(
                uuid: "u", publicKey: Data(repeating: 1, count: 33),
                algorithm: .ECDSA, curveType: .P256
            ),
            issuerDisplayName: "Kjetil",
            issuerContactEndpoint: "ep-1",
            audienceToken: "t",
            audienceKind: "email",
            humanCode: "ABC234",
            createdAt: now,
            expiresAt: now + 86_400,
            nonce: Data()
        )
    }

    @Test func theEmailGreetsByFirstNameAndCarriesTheBoundaryLine() {
        let message = HavenInviteCopy.compose(
            ticket: ticket,
            recipientDisplayName: "Vegar Hansen",
            recipientEndpoint: "vegar@example.no",
            link: "https://haven.digipomps.org/i/ABC234",
            channel: "email",
            senderNote: nil
        )
        #expect(message.body.hasPrefix("Hei Vegar,"))
        #expect(message.body.contains(HavenInviteCopy.boundaryLine))
        #expect(message.body.contains("ABC234"))
        #expect(message.subject.contains("Kjetil"))
    }

    @Test func theMailtoHandoffIsProperlyEncoded() throws {
        let message = HavenInviteCopy.compose(
            ticket: ticket,
            recipientDisplayName: "Vegar Hansen",
            recipientEndpoint: "vegar@example.no",
            link: "https://haven.digipomps.org/i/ABC234",
            channel: "email",
            senderNote: "Vi snakket om dette på Arendalsuka."
        )
        let handoff = try #require(message.handoffURL)
        #expect(handoff.hasPrefix("mailto:vegar%40example.no?"))
        #expect(!handoff.contains(" "))
        #expect(handoff.contains("subject="))
        #expect(handoff.contains("body="))
    }

    /// The SMS must stay in one or two segments. It only ever carries a short
    /// link, so this is a real bound, not an aspiration.
    @Test func theSmsStaysShort() throws {
        let message = HavenInviteCopy.compose(
            ticket: ticket,
            recipientDisplayName: "Vegar Hansen",
            recipientEndpoint: "+4790000000",
            link: "https://haven.digipomps.org/i/ABC234",
            channel: "sms",
            senderNote: nil
        )
        #expect(message.body.count < 160)
        let handoff = try #require(message.handoffURL)
        #expect(handoff.hasPrefix("sms:"))
        #expect(handoff.contains("&body="))
    }

    @Test func aMissingLinkIsSaidOutLoudRatherThanLeftBlank() {
        let message = HavenInviteCopy.compose(
            ticket: ticket,
            recipientDisplayName: "Vegar",
            recipientEndpoint: "vegar@example.no",
            link: nil,
            channel: "email",
            senderNote: nil
        )
        #expect(message.body.contains("ingen lenke"))
    }
}

// MARK: - Relation salience for the perspective

@Suite struct HavenRelationProjectionTests {

    private func record(
        name: String,
        email: String? = nil,
        tags: [String] = [],
        inviteState: HavenInviteState = .none,
        entityRef: String? = nil
    ) -> HavenRelationRecord {
        let endpoint = email.flatMap { HavenRelationNormalizer.endpoint(from: $0, preferredKind: .email) }
        return HavenRelationRecord(
            id: HavenRelationNormalizer.recordID(
                endpoints: endpoint.map { [$0] } ?? [],
                displayName: name,
                organization: nil
            ),
            displayName: name,
            endpoints: endpoint.map { [$0] } ?? [],
            contextTags: tags,
            entityRef: entityRef,
            inviteState: inviteState
        )
    }

    /// Salience is about the relationship, not about how sure we are that two
    /// spreadsheet rows were the same person.
    @Test func someoneInHavenOutweighsAColdImport() {
        let cold = record(name: "Kald Kontakt", email: "kald@example.no")
        let joined = record(name: "Varm Kontakt", email: "varm@example.no", inviteState: .joined, entityRef: "cell:///Entity/1")
        #expect(BindingRelationsCell.relationSalience(joined) > BindingRelationsCell.relationSalience(cold))
    }

    @Test func aBlockedRelationCarriesNoWeightAtAll() {
        let blocked = record(name: "Blokkert", email: "b@example.no", inviteState: .blocked)
        #expect(BindingRelationsCell.relationSalience(blocked) == 0.0)
    }

    @Test func knowingWhatSomeoneCaresAboutCountsForSomething() {
        let bare = record(name: "Uten merkelapper", email: "a@example.no")
        let tagged = record(name: "Med merkelapper", email: "b@example.no", tags: ["arendalsuka", "personvern"])
        #expect(BindingRelationsCell.relationSalience(tagged) > BindingRelationsCell.relationSalience(bare))
    }

    /// An entity with no interests matches nothing, so a projection of bare
    /// names would make the graph bigger without making it smarter.
    @Test func tagsBecomeInterestsInTheCanonicalWeightShape() throws {
        let tagged = record(name: "Vegar", email: "v@example.no", tags: ["arendalsuka", "personvern"])
        let interests = BindingRelationsCell.interestWeights(for: tagged)
        #expect(interests.count == 2)
        let first = try #require(HavenValue.object(interests.first))
        #expect(first["weight"] != nil)
        // `value`, not `object` — the earlier draft used the wrong key and the
        // projection would have been accepted and silently emptied.
        let value = try #require(HavenValue.object(first["value"]))
        #expect(HavenValue.string(value["name"]) == "arendalsuka")
    }

    /// Two people with the same name must not collide, and the same person
    /// must keep their reference across restarts.
    @Test func opaqueReferencesAreStableAndDistinct() {
        let salt = "test-salt"
        let anneA = record(name: "Anne Hansen", email: "anne@a.no")
        let anneB = record(name: "Anne Hansen", email: "anne@b.no")

        let referenceA = BindingRelationsCell.opaqueReference(for: anneA, salt: salt)
        #expect(referenceA == BindingRelationsCell.opaqueReference(for: anneA, salt: salt))
        #expect(referenceA != BindingRelationsCell.opaqueReference(for: anneB, salt: salt))
        // …and the name itself never appears in it.
        #expect(!referenceA.lowercased().contains("anne"))
        // A different entity's salt gives a different reference for the same
        // person, so two perspectives cannot be joined on it.
        #expect(referenceA != BindingRelationsCell.opaqueReference(for: anneA, salt: "another-salt"))
    }
}

// MARK: - Residency ranking

@Suite struct HavenResidencyRankerTests {

    private var locations: [HavenResidencyLocation] {
        [
            HavenResidencyLocation(
                id: "device", label: "Denne enheten", kind: .deviceLocal,
                endpoint: "file://app-container", custodian: "Deg", jurisdiction: "NO",
                availabilityClass: 0.90, latencyMsP50: 1, pricePerGiBMonth: 0, independence: 1.0
            ),
            HavenResidencyLocation(
                id: "scaffold-no", label: "Scaffold i Norge", kind: .scaffold,
                endpoint: "https://no.example.org", custodian: "Digipomps", jurisdiction: "NO",
                availabilityClass: 0.999, latencyMsP50: 30, pricePerGiBMonth: 12, independence: 0.6
            ),
            HavenResidencyLocation(
                id: "scaffold-us", label: "Billig scaffold i USA", kind: .scaffold,
                endpoint: "https://us.example.org", custodian: "Stor Leverandør", jurisdiction: "US",
                availabilityClass: 0.9999, latencyMsP50: 180, pricePerGiBMonth: 2, independence: 0.2
            )
        ]
    }

    private func weights(_ pairs: [HavenResidencyCriterion: Double]) -> HavenResidencyPreferences {
        var weights: [String: Double] = [:]
        for criterion in HavenResidencyCriterion.allCases { weights[criterion.rawValue] = 0 }
        for (criterion, weight) in pairs { weights[criterion.rawValue] = weight }
        return HavenResidencyPreferences(weights: weights)
    }

    @Test func caringOnlyAboutLatencyPicksTheLocalOne() {
        #expect(HavenResidencyRanker.rank(locations: locations, preferences: weights([.latency: 1.0])).first?.location.id == "device")
    }

    @Test func caringOnlyAboutAvailabilityPicksTheMostAvailable() {
        #expect(HavenResidencyRanker.rank(locations: locations, preferences: weights([.availability: 1.0])).first?.location.id == "scaffold-us")
    }

    @Test func caringOnlyAboutCostPicksTheFreeOne() {
        #expect(HavenResidencyRanker.rank(locations: locations, preferences: weights([.cost: 1.0])).first?.location.id == "device")
    }

    @Test func caringOnlyAboutIndependencePicksTheOneYouControl() {
        #expect(HavenResidencyRanker.rank(locations: locations, preferences: weights([.independence: 1.0])).first?.location.id == "device")
    }

    @Test func aJurisdictionListExcludesRatherThanDeprioritises() throws {
        var preferences = weights([.availability: 1.0])
        preferences.jurisdictionAllowList = ["NO"]
        let ranked = HavenResidencyRanker.rank(locations: locations, preferences: preferences)
        let us = try #require(ranked.first { $0.location.id == "scaffold-us" })
        #expect(us.excluded)
        #expect(us.explanation.contains("US"))
        #expect(ranked.first?.location.id != "scaffold-us")
    }

    @Test func requiringEncryptionExcludesAPlaceWithout() throws {
        var candidates = locations
        candidates.append(HavenResidencyLocation(
            id: "plaintext", label: "Uten kryptering", kind: .scaffold,
            endpoint: "https://plain.example.org", custodian: "Noen",
            jurisdiction: "NO", encryptedAtRest: false
        ))
        let ranked = HavenResidencyRanker.rank(locations: candidates, preferences: weights([.availability: 1.0]))
        let plaintext = try #require(ranked.first { $0.location.id == "plaintext" })
        #expect(plaintext.excluded)
        #expect(plaintext.explanation.contains("krypterer ikke"))
    }

    @Test func noWeightsMeansNoOpinionAndItSaysSo() throws {
        let ranked = HavenResidencyRanker.rank(
            locations: locations,
            preferences: HavenResidencyPreferences(weights: [:])
        )
        let first = try #require(ranked.first)
        #expect(first.total == 0)
        #expect(first.explanation.contains("ikke sagt hva som betyr noe"))
    }

    @Test func everyRankedPlaceExplainsItself() {
        let ranked = HavenResidencyRanker.rank(locations: locations, preferences: HavenResidencyPreferences())
        #expect(ranked.count == 3)
        for score in ranked {
            #expect(!score.explanation.isEmpty)
            #expect(score.contributions.count == HavenResidencyCriterion.allCases.count)
        }
    }
}

// MARK: - Residency storage

@Suite struct HavenResidencyLocalStoreTests {

    private func temporaryLocation() -> HavenResidencyLocation {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("haven-residency-test-\(UUID().uuidString)", isDirectory: true)
        return HavenResidencyLocation(
            id: "tmp", label: "Midlertidig mappe", kind: .userFolder,
            endpoint: directory.path, custodian: "Test"
        )
    }

    @Test func writingVerifiesTheReadbackBeforeReportingSuccess() throws {
        let location = temporaryLocation()
        defer {
            if let directory = HavenResidencyLocalStore.directory(for: location) {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let payload = Data("{\"records\":[]}".utf8)
        let hash = HavenResidencyLocalStore.hash(payload)
        let url = try HavenResidencyLocalStore.write(payload, datasetID: "relations", to: location, expectedHash: hash)
        #expect(FileManager.default.fileExists(atPath: url.path))

        let readBack = try HavenResidencyLocalStore.read(datasetID: "relations", from: location)
        #expect(readBack == payload)
        #expect(HavenResidencyLocalStore.hash(readBack) == hash)
    }

    /// A move we cannot verify must fail loudly, not quietly succeed.
    @Test func aWrongExpectedHashFailsTheWrite() throws {
        let location = temporaryLocation()
        defer {
            if let directory = HavenResidencyLocalStore.directory(for: location) {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        #expect(throws: (any Error).self) {
            try HavenResidencyLocalStore.write(
                Data("noe".utf8), datasetID: "relations", to: location, expectedHash: "definitivt-feil-hash"
            )
        }
    }

    @Test func hashingIsStableAndSensitive() {
        let first = HavenResidencyLocalStore.hash(Data("abc".utf8))
        #expect(first == HavenResidencyLocalStore.hash(Data("abc".utf8)))
        #expect(first != HavenResidencyLocalStore.hash(Data("abd".utf8)))
    }

    @Test func aScaffoldHasNoLocalPathBecauseWeCannotWriteThereOurselves() {
        let scaffold = HavenResidencyLocation(
            id: "s", label: "Scaffold", kind: .scaffold,
            endpoint: "https://example.org", custodian: "Noen"
        )
        #expect(HavenResidencyLocalStore.directory(for: scaffold) == nil)
        #expect(!scaffold.kind.supportsDirectWrite)
    }

    @Test func replicasAreStaleUntilProvenFresh() {
        #expect(HavenResidencyReplica(locationID: "x", role: .backup).isStale())
        #expect(!HavenResidencyReplica(locationID: "x", role: .cache, staleAfterSeconds: 3600, lastSyncedAt: Date()).isStale())
        #expect(HavenResidencyReplica(locationID: "x", role: .cache, staleAfterSeconds: 60, lastSyncedAt: Date().addingTimeInterval(-3600)).isStale())
    }
}
