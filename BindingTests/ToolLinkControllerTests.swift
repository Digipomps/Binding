// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CryptoKit
import CellBase
@testable import Binding

/// HavenAgentD sin side av samtalen, i minnet: svarer på de samme rutene som
/// kontrollbroen og husker hva HAVEN sendte.
private actor FakeAgent {
    private let tools: [String: Any]
    private let approvals: [String: Any]
    private let postStatus: [String: String]
    private var posts: [(path: String, body: Data)] = []
    private var tokens: [String] = []

    init(tools: [String: Any], items: [[String: Any]], postStatus: [String: String] = [:]) {
        self.tools = tools
        self.approvals = ["links": ["items": items], "status": ["ok": true]]
        self.postStatus = postStatus
    }

    func respond(to request: URLRequest) throws -> (Data, URLResponse) {
        guard let url = request.url else { throw URLError(.badURL) }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        tokens.append(query.first { $0.name == "token" }?.value ?? "")
        let object: [String: Any]
        switch (request.httpMethod ?? "GET", url.path) {
        case ("GET", "/test-flow/tools"):
            object = tools
        case ("GET", "/test-flow/approvals"):
            object = approvals
        case ("POST", let path):
            posts.append((path, request.httpBody ?? Data()))
            object = ["result": ["status": postStatus[path] ?? "rejected", "message": "ikke forventet i testen"]]
        default:
            object = ["error": true, "reason": "ukjent rute"]
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil) else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }

    func postedBodies() -> [(path: String, body: Data)] { posts }
    func seenTokens() -> [String] { tokens }
}

private actor SignCounter {
    private(set) var count = 0
    func bump() { count += 1 }
}

private struct Keys {
    let tool = Curve25519.Signing.PrivateKey()
    let owner = P256.Signing.PrivateKey()

    var toolPublic: String { ToolLinkCrypto.base64URL(tool.publicKey.rawRepresentation) }
    var ownerPublic: String { ToolLinkCrypto.base64URL(owner.publicKey.x963Representation) }

    func ownerSigner(counting counter: SignCounter? = nil) -> ToolLinkSigner {
        let owner = self.owner
        return ToolLinkSigner(publicKeyBase64URL: ownerPublic, algorithm: "P256-ES256") { data in
            await counter?.bump()
            return try owner.signature(for: data).derRepresentation
        }
    }
}

private let domainA = "staging.haven.digipomps.org"

/// Verktøyets forespørsel slik agenten lager den: signert av verktøyet først.
private func toolRequest(_ keys: Keys, id: String = "elc_tool_testrequest01", ownerPublic: String? = nil) throws -> (contract: ToolLinkContract, canonical: Data) {
    var contract = ToolLinkContract(
        contract_id: id,
        domain_a: domainA,
        pubkey_a: ownerPublic ?? keys.ownerPublic,
        domain_b: ToolLinkReview.toolDomain,
        pubkey_b: keys.toolPublic,
        scope: ToolLinkReview.scope,
        created_at: ToolLinkCrypto.iso(Date()),
        revocation: .init(mode: ToolLinkReview.revocationMode),
        signatures: []
    )
    let canonical = try contract.canonicalPayloadData()
    contract.signatures = [.init(
        by_pubkey: keys.toolPublic,
        alg: "Ed25519",
        sig: ToolLinkCrypto.base64URL(try keys.tool.signature(for: canonical))
    )]
    return (contract, canonical)
}

/// En rad fra agentens `GET /test-flow/approvals` (samme felt som `ToolCellApprovalCell.itemValue`).
private func agentItem(_ contract: ToolLinkContract, canonical: Data, state: String, extra: [String: Any] = [:]) throws -> [String: Any] {
    let words = ToolLinkSecurityWords.words(forCanonical: canonical)
    var item: [String: Any] = [
        "label": "Losen",
        "contractID": contract.contract_id,
        "state": state,
        "status": state,
        "initiatorText": "startet av verktøyet",
        "toolKeyFingerprint": "ed25519 3F9A 71C0 5B2E C21B",
        "securityWords": words,
        "securityCode": ToolLinkSecurityWords.display(words),
        "createdAt": contract.created_at,
        "canonicalPayloadBase64URL": ToolLinkCrypto.base64URL(canonical),
        "contract": try JSONSerialization.jsonObject(with: JSONEncoder().encode(contract))
    ]
    item.merge(extra) { _, new in new }
    return item
}

private func toolsResponse(_ keys: Keys, ownerPublic: String? = nil) -> [String: Any] {
    [
        "tools": [[
            "label": "Losen",
            "identityUUID": "tool-uuid-losen",
            "publicKeyBase64URL": keys.toolPublic,
            "fingerprint": "ed25519 3F9A 71C0 5B2E C21B",
            "scope": ToolLinkReview.scope,
            "scopeLabel": ToolLinkReview.scopeLabel,
            "domain": ToolLinkReview.toolDomain
        ]],
        "scaffoldDomain": domainA,
        "ownerPublicKeyBase64URL": ownerPublic ?? keys.ownerPublic,
        "revocationMode": ToolLinkReview.revocationMode
    ]
}

private func controller(for agent: FakeAgent) -> BindingToolLinkController {
    BindingToolLinkController(
        endpoint: { ToolLinkAgentEndpoint(base: URL(string: "http://127.0.0.1:43110")!, accessToken: "test-token") },
        transport: { request in try await agent.respond(to: request) }
    )
}

private func rows(_ state: Object, _ key: String) -> [Object] {
    (HavenValue.list(state[key]) ?? []).compactMap { HavenValue.object($0) }
}

private func lines(_ state: Object, _ key: String) -> [String] {
    rows(state, key).compactMap { HavenValue.string($0["statusLine"]) }
}

/// Hvilke slags rader en del av flaten viser, i rekkefølge.
private func kinds(_ state: Object, _ key: String) -> [String] {
    rows(state, key).compactMap { HavenValue.string($0["kind"]) }
}

@Suite struct ToolLinkControllerTests {
    /// Samme testvektor som agentens `TestFlowContractTests`: samme kanoniske bytes gir
    /// samme fire ord i HAVEN og i HAVEN Agent.
    @Test func securityWordsFollowTheAgentsTestVector() throws {
        let contract = ToolLinkContract(
            contract_id: "elc_tool_testvector0001",
            domain_a: "staging.haven.digipomps.org",
            pubkey_a: "AAAA",
            domain_b: "haven.agent.test-flow",
            pubkey_b: "BBBB",
            scope: "agent.tool.instruct",
            created_at: "2026-09-24T10:00:00Z",
            revocation: .init(mode: "owner-only"),
            signatures: [.init(by_pubkey: "BBBB", alg: "Ed25519", sig: "c2ln")]
        )
        let canonical = try contract.canonicalPayloadData()
        #expect(String(decoding: canonical, as: UTF8.self) == #"{"contract_id":"elc_tool_testvector0001","created_at":"2026-09-24T10:00:00Z","domain_a":"staging.haven.digipomps.org","domain_b":"haven.agent.test-flow","pubkey_a":"AAAA","pubkey_b":"BBBB","revocation":{"mode":"owner-only"},"scope":"agent.tool.instruct"}"#)
        let hex = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
        #expect(hex.hasPrefix("db5de536"))
        #expect(ToolLinkSecurityWords.words(forCanonical: canonical) == ["ås", "juv", "selje", "frosk"])
        #expect(ToolLinkSecurityWords.norwegian.count == 256)
        #expect(Set(ToolLinkSecurityWords.norwegian).count == 256)
    }

    @Test func havenChecksTheToolsRequestBeforeTheOwnerSigns() throws {
        let keys = Keys()
        let request = try toolRequest(keys)
        let good = try agentItem(request.contract, canonical: request.canonical, state: "awaiting-owner")
        let checked = try ToolLinkReview.checkToolRequest(good, ownerKey: keys.ownerPublic)
        #expect(checked.words == ToolLinkSecurityWords.words(forCanonical: request.canonical))
        #expect(checked.label == "Losen")

        #expect(throws: ToolLinkReview.Problem.notForThisOwner) {
            try ToolLinkReview.checkToolRequest(good, ownerKey: Keys().ownerPublic)
        }

        var otherBytes = good
        otherBytes["canonicalPayloadBase64URL"] = ToolLinkCrypto.base64URL(Data("noe annet".utf8))
        #expect(throws: ToolLinkReview.Problem.changedBytes) {
            try ToolLinkReview.checkToolRequest(otherBytes, ownerKey: keys.ownerPublic)
        }

        var otherWords = good
        otherWords["securityWords"] = ["aks", "alm", "and", "ape"]
        let here = ToolLinkSecurityWords.display(ToolLinkSecurityWords.words(forCanonical: request.canonical))
        #expect(throws: ToolLinkReview.Problem.wordsDiffer(agent: "aks · alm · and · ape", here: here)) {
            try ToolLinkReview.checkToolRequest(otherWords, ownerKey: keys.ownerPublic)
        }

        var forged = request.contract
        forged.signatures = [.init(
            by_pubkey: keys.toolPublic,
            alg: "Ed25519",
            sig: ToolLinkCrypto.base64URL(try Keys().tool.signature(for: request.canonical))
        )]
        let forgedItem = try agentItem(forged, canonical: request.canonical, state: "awaiting-owner")
        #expect(throws: ToolLinkReview.Problem.toolSignatureInvalid) {
            try ToolLinkReview.checkToolRequest(forgedItem, ownerKey: keys.ownerPublic)
        }
    }

    /// B10: begge ender forteller det samme — hvem som svarte, og hva svaret ble.
    @Test func bothEndsTellWhoAnsweredAndWhat() async throws {
        let keys = Keys()
        let asking = try toolRequest(keys, id: "elc_tool_asking000001")
        let offered = try toolRequest(keys, id: "elc_tool_offered00001")
        let acceptedInAgent = try toolRequest(keys, id: "elc_tool_accepted0001")
        let approvedHere = try toolRequest(keys, id: "elc_tool_approved0001")
        let declinedInAgent = try toolRequest(keys, id: "elc_tool_declined0001")
        let declinedHere = try toolRequest(keys, id: "elc_tool_declined0002")
        let revoked = try toolRequest(keys, id: "elc_tool_revoked00001")
        let expired = try toolRequest(keys, id: "elc_tool_expired00001")
        let now = ToolLinkCrypto.iso(Date())
        let items = [
            try agentItem(asking.contract, canonical: asking.canonical, state: "awaiting-owner"),
            try agentItem(offered.contract, canonical: offered.canonical, state: "awaiting-tool", extra: ["initiatorText": "tilbudt fra HAVEN"]),
            try agentItem(acceptedInAgent.contract, canonical: acceptedInAgent.canonical, state: "active", extra: ["answeredBy": "HAVEN Agent", "answeredAt": now]),
            try agentItem(approvedHere.contract, canonical: approvedHere.canonical, state: "active", extra: ["answeredBy": "Kjetil i HAVEN", "answeredAt": now]),
            try agentItem(declinedInAgent.contract, canonical: declinedInAgent.canonical, state: "declined", extra: ["answeredBy": "HAVEN Agent", "answeredAt": now]),
            try agentItem(declinedHere.contract, canonical: declinedHere.canonical, state: "declined", extra: ["answeredBy": "Kjetil i HAVEN", "answeredAt": now]),
            try agentItem(revoked.contract, canonical: revoked.canonical, state: "revoked", extra: ["revokedAt": now]),
            try agentItem(expired.contract, canonical: expired.canonical, state: "expired")
        ]
        let agent = FakeAgent(tools: toolsResponse(keys), items: items)
        let links = controller(for: agent)

        let result = await links.refresh(ownerKey: keys.ownerPublic)
        #expect(HavenValue.string(result["status"]) == "ok")
        let state = links.stateFields()

        #expect(HavenValue.string(state["toolSummary"]) == "1 ber om tilgang · 1 venter på svar i HAVEN Agent · 2 aktive")
        let incoming = try #require(rows(state, "toolIncoming").first)
        #expect(HavenValue.string(incoming["securityCode"]) == ToolLinkSecurityWords.display(ToolLinkSecurityWords.words(forCanonical: asking.canonical)))
        #expect(HavenValue.bool(incoming["hasWarning"]) == false)
        #expect(HavenValue.string(incoming["question"]) == "Stemmer ordene med dem i HAVEN Agent?")

        #expect(lines(state, "toolOutgoing") == ["venter på svar i HAVEN Agent"])
        let outgoing = try #require(rows(state, "toolOutgoing").first)
        #expect(HavenValue.string(outgoing["securityCode"]) == ToolLinkSecurityWords.display(ToolLinkSecurityWords.words(forCanonical: offered.canonical)))

        let active = lines(state, "toolActive")
        #expect(active.contains { $0.hasPrefix("✓ godtatt i HAVEN Agent") })
        #expect(active.contains { $0.hasPrefix("✓ godkjent av deg") })

        let history = lines(state, "toolHistory")
        #expect(history.contains { $0.hasPrefix("✗ avvist i HAVEN Agent") })
        #expect(history.contains { $0.hasPrefix("✗ avvist av deg") })
        #expect(history.contains { $0.hasPrefix("trukket tilbake av deg") })
        #expect(history.contains("utløpt uten svar"))
        // Hver rad i sporet har linjen flaten viser (ellers står det «Innholdet er ikke tilgjengelig»).
        #expect(rows(state, "toolHistory").allSatisfy { HavenValue.string($0["summaryLine"])?.hasPrefix("Losen — sende testinstruksjoner · ") == true })

        // Flaten: forespørselen og tilbudet i kortet for agenten, de aktive under «Koblede
        // steder», og svarene som spor.
        #expect(kinds(state, "toolAgentRows") == ["subheading", "request", "subheading", "offerForm", "outgoing"])
        #expect(kinds(state, "toolLinkedRows") == ["tool", "tool"])
        #expect(kinds(state, "toolHistoryRows") == ["subheading", "history", "history", "history", "history"])
        #expect(rows(state, "toolLinkedRows").compactMap { HavenValue.string($0["tone"]) } == ["success", "success"])

        #expect(await agent.seenTokens().allSatisfy { $0 == "test-token" })
        #expect(await agent.postedBodies().isEmpty)
    }

    /// A: HAVEN legger eierens signatur ved siden av verktøyets og sender lenken til agenten.
    @Test func approvingAddsTheOwnersSignatureNextToTheTools() async throws {
        let keys = Keys()
        let request = try toolRequest(keys)
        let agent = FakeAgent(
            tools: toolsResponse(keys),
            items: [try agentItem(request.contract, canonical: request.canonical, state: "awaiting-owner")],
            postStatus: ["/test-flow/approval": "accepted"]
        )
        let links = controller(for: agent)

        let result = await links.approve(contractID: request.contract.contract_id, signer: keys.ownerSigner())
        #expect(HavenValue.string(result["status"]) == "ok")
        #expect(HavenValue.string(links.stateFields()["toolAnswerMessage"])?.hasPrefix("Godkjent: Losen kan sende testinstruksjoner.") == true)
        let answered = rows(links.stateFields(), "toolAgentRows").first { HavenValue.string($0["kind"]) == "success" }
        #expect(HavenValue.string(answered?["text"])?.hasSuffix("HAVEN Agent viser at du godkjente.") == true)

        let posts = await agent.postedBodies()
        #expect(posts.map { $0.path } == ["/test-flow/approval"])
        let sent = try JSONDecoder().decode(ToolLinkContract.self, from: try #require(posts.first).body)
        #expect(try sent.canonicalPayloadData() == request.canonical)
        #expect(sent.signatures.count == 2)
        #expect(sent.signatures.first == request.contract.signatures.first)
        let owner = try #require(sent.signatures.last)
        #expect(owner.by_pubkey == keys.ownerPublic)
        #expect(owner.alg == "P256-ES256")
        #expect(ToolLinkCrypto.verify(alg: owner.alg, publicKeyBase64URL: owner.by_pubkey, signatureBase64URL: owner.sig, data: request.canonical))
    }

    /// Eierens nøkkel signerer aldri noe som ikke besto kontrollen i HAVEN.
    @Test func theOwnerNeverSignsWhatFailedTheCheck() async throws {
        let keys = Keys()
        let otherOwner = Keys().ownerPublic
        let tampered = try toolRequest(keys, id: "elc_tool_tampered0001")
        let foreign = try toolRequest(keys, id: "elc_tool_foreign00001", ownerPublic: otherOwner)
        let agent = FakeAgent(
            tools: toolsResponse(keys),
            items: [
                try agentItem(tampered.contract, canonical: tampered.canonical, state: "awaiting-owner", extra: ["securityWords": ["aks", "alm", "and", "ape"]]),
                try agentItem(foreign.contract, canonical: foreign.canonical, state: "awaiting-owner")
            ],
            postStatus: ["/test-flow/approval": "accepted"]
        )
        let links = controller(for: agent)
        let counter = SignCounter()

        let first = await links.approve(contractID: tampered.contract.contract_id, signer: keys.ownerSigner(counting: counter))
        let second = await links.approve(contractID: foreign.contract.contract_id, signer: keys.ownerSigner(counting: counter))
        #expect(HavenValue.string(first["status"]) == "error")
        #expect(HavenValue.string(second["status"]) == "error")
        #expect(HavenValue.string(first["message"])?.contains("Ordene er ikke like") == true)
        #expect(HavenValue.string(second["message"])?.contains("ikke ment for nøkkelen") == true)
        #expect(await counter.count == 0)
        #expect(await agent.postedBodies().isEmpty)

        // Den endrede vises med varsel og uten svarknapper; den til en annen identitet er ikke
        // din å svare på og vises ikke.
        let shown = rows(links.stateFields(), "toolIncoming")
        #expect(shown.compactMap { HavenValue.string($0["contractID"]) } == [tampered.contract.contract_id])
        #expect(shown.compactMap { HavenValue.bool($0["hasWarning"]) } == [true])
        #expect(shown.compactMap { HavenValue.bool($0["canAnswer"]) } == [false])
        let declined = await links.decline(contractID: foreign.contract.contract_id, signer: keys.ownerSigner(counting: counter))
        #expect(HavenValue.string(declined["message"])?.contains("ikke ment for nøkkelen") == true)
        #expect(await counter.count == 0)
    }

    /// B: tilbudet signeres av eieren først, for verktøyets nøkkel agenten oppga, og svaret gis i HAVEN Agent.
    @Test func offerIsSignedByTheOwnerFirstForTheToolTheAgentNamed() async throws {
        let keys = Keys()
        let agent = FakeAgent(tools: toolsResponse(keys), items: [], postStatus: ["/test-flow/offer": "offered"])
        let links = controller(for: agent)

        let result = await links.offer(signer: keys.ownerSigner())
        #expect(HavenValue.string(result["status"]) == "ok")

        let posts = await agent.postedBodies()
        #expect(posts.map { $0.path } == ["/test-flow/offer"])
        let sent = try JSONDecoder().decode(ToolLinkContract.self, from: try #require(posts.first).body)
        #expect(sent.pubkey_a == keys.ownerPublic)
        #expect(sent.pubkey_b == keys.toolPublic)
        #expect(sent.domain_a == domainA)
        #expect(sent.domain_b == ToolLinkReview.toolDomain)
        #expect(sent.scope == ToolLinkReview.scope)
        #expect(sent.revocation.mode == "owner-only")
        #expect(sent.contract_id.hasPrefix("elc_tool_") && sent.contract_id.count == 25)
        let canonical = try sent.canonicalPayloadData()
        let signature = try #require(sent.signatures.first)
        #expect(sent.signatures.count == 1)
        #expect(signature.by_pubkey == keys.ownerPublic)
        #expect(ToolLinkCrypto.verify(alg: signature.alg, publicKeyBase64URL: signature.by_pubkey, signatureBase64URL: signature.sig, data: canonical))
        let words = ToolLinkSecurityWords.display(ToolLinkSecurityWords.words(forCanonical: canonical))
        #expect(HavenValue.string(result["message"]) == "Tilbudt til Losen. Sikkerhetsord: \(words). Svar i HAVEN Agent.")
    }

    @Test func offerIsRefusedHereWhenThisHavenHoldsAnotherKey() async throws {
        let keys = Keys()
        let agent = FakeAgent(tools: toolsResponse(keys, ownerPublic: Keys().ownerPublic), items: [], postStatus: ["/test-flow/offer": "offered"])
        let links = controller(for: agent)
        let counter = SignCounter()

        let result = await links.offer(signer: keys.ownerSigner(counting: counter))
        #expect(HavenValue.string(result["code"]) == "wrong_owner")
        #expect(await counter.count == 0)
        #expect(await agent.postedBodies().isEmpty)
        #expect(HavenValue.string(links.stateFields()["toolSummary"])?.contains("Svar herfra blir avvist") == true)
    }

    /// Når nøkkelen ikke stemmer, tilbyr flaten bare paringen: ingen forespørsler, ingen
    /// svarknapper og ingen «Tilby». Det samme når agenten ikke er paret i det hele tatt.
    @Test func onlyPairingIsOfferedWhenTheKeyDiffers() async throws {
        let keys = Keys()
        let otherOwner = Keys()
        let foreign = try toolRequest(keys, ownerPublic: otherOwner.ownerPublic)
        let foreignActive = try toolRequest(keys, id: "elc_tool_foreignactive", ownerPublic: otherOwner.ownerPublic)
        let foreignExpired = try toolRequest(keys, id: "elc_tool_foreignexpire", ownerPublic: otherOwner.ownerPublic)
        let links = controller(for: FakeAgent(
            tools: toolsResponse(keys, ownerPublic: otherOwner.ownerPublic),
            items: [
                try agentItem(foreign.contract, canonical: foreign.canonical, state: "awaiting-owner"),
                try agentItem(foreignActive.contract, canonical: foreignActive.canonical, state: "active", extra: ["answeredBy": "HAVEN Agent", "answeredAt": ToolLinkCrypto.iso(Date())]),
                try agentItem(foreignExpired.contract, canonical: foreignExpired.canonical, state: "expired")
            ]
        ))
        await links.refresh(ownerKey: keys.ownerPublic)
        let state = links.stateFields()
        #expect(links.pairingState() == .elsewhere)
        #expect(kinds(state, "toolAgentRows") == ["pairing"])
        #expect(HavenValue.string(rows(state, "toolAgentRows").first?["title"]) == "HAVEN Agent er paret med en annen identitet")
        #expect(rows(state, "toolIncoming").isEmpty)
        // Lenkene til den andre identiteten er ikke dine: ingen «Trekk tilbake», ikke noe spor.
        #expect(rows(state, "toolLinkedRows").isEmpty)
        #expect(rows(state, "toolHistoryRows").isEmpty)

        // Svaret på paringen vises rett under paringen.
        _ = links.note(HavenValue.ok("Agenten er paret med denne HAVEN-en.", sideEffect: true), in: .pairing)
        #expect(kinds(links.stateFields(), "toolAgentRows") == ["pairing", "success"])

        // Ikke paret med noen: også bare paringen.
        var unpairedTools = toolsResponse(keys)
        unpairedTools.removeValue(forKey: "ownerPublicKeyBase64URL")
        let unpaired = controller(for: FakeAgent(tools: unpairedTools, items: []))
        await unpaired.refresh(ownerKey: keys.ownerPublic)
        #expect(kinds(unpaired.stateFields(), "toolAgentRows") == ["pairing"])
        #expect(HavenValue.string(rows(unpaired.stateFields(), "toolAgentRows").first?["title"]) == "HAVEN Agent er ikke paret ennå")

        // Samme nøkkel: forespørselen med svarknapper, og «Tilby»; paringen er borte.
        let own = try toolRequest(keys)
        let matching = controller(for: FakeAgent(
            tools: toolsResponse(keys),
            items: [try agentItem(own.contract, canonical: own.canonical, state: "awaiting-owner")]
        ))
        await matching.refresh(ownerKey: keys.ownerPublic)
        let ok = matching.stateFields()
        #expect(matching.pairingState() == .here)
        #expect(kinds(ok, "toolAgentRows") == ["subheading", "request", "subheading", "offerForm"])
        let card = rows(ok, "toolAgentRows")[1]
        #expect(HavenValue.bool(card["canAnswer"]) == true)
        #expect(HavenValue.string(card["headline"])?.hasPrefix("**Losen — verktøycelle i agenten din**") == true)
    }

    /// Uten agent på maskinen sier kortet det med én linje, ikke som en feil.
    @Test func withoutAgentTheCardSaysSoInOneLine() async throws {
        let links = BindingToolLinkController(endpoint: { nil }, transport: { _ in throw URLError(.cannotConnectToHost) })
        #expect(kinds(links.stateFields(), "toolAgentRows") == ["note"])
        await links.refresh(ownerKey: Keys().ownerPublic)
        let state = links.stateFields()
        #expect(kinds(state, "toolAgentRows") == ["note"])
        #expect(HavenValue.string(rows(state, "toolAgentRows").first?["text"]) == "HAVEN Agent er ikke satt opp på denne maskinen.")

        let unreachable = BindingToolLinkController(
            endpoint: { ToolLinkAgentEndpoint(base: URL(string: "http://127.0.0.1:43110")!, accessToken: nil) },
            transport: { _ in throw URLError(.cannotConnectToHost) }
        )
        await unreachable.refresh(ownerKey: Keys().ownerPublic)
        #expect(kinds(unreachable.stateFields(), "toolAgentRows") == ["problem"])
    }

    /// Velgeren i «Gi tilgang» leser `{selected}` og skriver `{selectedIndex, selected}` tilbake.
    @Test func pickerSelectionRoundTrips() async throws {
        let keys = Keys()
        let agent = FakeAgent(tools: toolsResponse(keys), items: [])
        let links = controller(for: agent)
        await links.refresh(ownerKey: keys.ownerPublic)
        #expect(HavenValue.string(links.toolSelection()["selected"]) == "tool-uuid-losen")
        let state = links.stateFields()
        #expect(kinds(state, "toolAgentRows") == ["subheading", "note", "subheading", "offerForm"])
        #expect(HavenValue.string(rows(state, "toolAgentRows")[1]["text"]) == "Ingen verktøy ber om tilgang akkurat nå.")
        #expect(rows(state, "toolHistoryRows").isEmpty)
        _ = links.selectTool(.object(["selectionMode": .string("single"), "trigger": .string("select"), "selectedIndex": .integer(0), "selected": .string("annet-verktoy")]))
        #expect(HavenValue.string(links.toolSelection()["selected"]) == "annet-verktoy")
        _ = links.selectTool(.object(["selectedIndex": .integer(0), "selected": .object(["value": .string("tool-uuid-losen")])]))
        #expect(HavenValue.string(links.toolSelection()["selected"]) == "tool-uuid-losen")
        #expect(HavenValue.string(links.scopeSelection()["selected"]) == ToolLinkReview.scope)
    }

    /// Avslag og tilbaketrekking er signerte utsagn agenten kan sjekke selv.
    @Test func declineAndRevokeAreSignedStatements() async throws {
        let keys = Keys()
        let asking = try toolRequest(keys, id: "elc_tool_asking000002")
        let active = try toolRequest(keys, id: "elc_tool_active000001")
        let agent = FakeAgent(
            tools: toolsResponse(keys),
            items: [
                try agentItem(asking.contract, canonical: asking.canonical, state: "awaiting-owner"),
                try agentItem(active.contract, canonical: active.canonical, state: "active", extra: ["answeredBy": "HAVEN Agent", "answeredAt": ToolLinkCrypto.iso(Date())])
            ],
            postStatus: ["/test-flow/decline": "declined", "/test-flow/revoke": "revoked"]
        )
        let links = controller(for: agent)

        let declined = await links.decline(contractID: asking.contract.contract_id, signer: keys.ownerSigner())
        let revoked = await links.revoke(contractID: active.contract.contract_id, signer: keys.ownerSigner())
        let unknown = await links.revoke(contractID: asking.contract.contract_id, signer: keys.ownerSigner())
        #expect(HavenValue.string(declined["status"]) == "ok")
        #expect(HavenValue.string(revoked["status"]) == "ok")
        #expect(HavenValue.string(unknown["code"]) == "not_found")
        // «Trekk tilbake» svarer under «Koblede steder»; den mislykkede sist gir feillinjen.
        #expect(kinds(links.stateFields(), "toolLinkedRows").last == "failure")

        let posts = await agent.postedBodies()
        #expect(posts.map { $0.path } == ["/test-flow/decline", "/test-flow/revoke"])
        let decline = try JSONDecoder().decode(ToolLinkDecline.self, from: posts[0].body)
        #expect(decline.contract_id == asking.contract.contract_id)
        #expect(decline.by_pubkey == keys.ownerPublic)
        #expect(ToolLinkCrypto.verify(alg: decline.alg, publicKeyBase64URL: decline.by_pubkey, signatureBase64URL: decline.sig, data: try decline.canonicalPayloadData()))
        let revocation = try JSONDecoder().decode(ToolLinkRevocation.self, from: posts[1].body)
        #expect(revocation.contract_id == active.contract.contract_id)
        #expect(ToolLinkCrypto.verify(alg: revocation.alg, publicKeyBase64URL: revocation.by_pubkey, signatureBase64URL: revocation.sig, data: try revocation.canonicalPayloadData()))
    }
}
