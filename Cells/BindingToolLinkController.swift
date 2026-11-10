// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  BindingToolLinkController.swift
//  Binding
//
//  Lenker mellom eieren og verktøycellene i den lokale agenten (HavenAgentD).
//
//  Entitetslenken er den ene mekanismen (Kjetil 2026-09-24, B7 i HavenAgentD
//  Docs/PDD_testflyt-verktoycelle_20260923/BESLUTNINGER.md). En lenke kan startes fra
//  begge sider (B10): verktøyet ber og du svarer her, eller du tilbyr her og svaret gis
//  i HAVEN Agent. Begge ender viser hvem som startet, de fire ordene, og hva svaret ble,
//  hvem og når.
//
//  HAVEN sjekker selv det agenten legger fram før din nøkkel signerer noe: lenken er ment
//  for din nøkkel, verktøyets signatur holder, de kanoniske bytene er de samme som agenten
//  viser, og de fire ordene regnes ut her — ikke tatt på tro.
//

import Foundation
import CellBase
import CryptoKit

/// Samme dokument som agentens `AgentEntityLinkContract` og Sprouts `EntityLinkContract`.
nonisolated struct ToolLinkContract: Codable, Equatable, Sendable {
    nonisolated struct Revocation: Codable, Equatable, Sendable {
        var mode: String
    }

    nonisolated struct Signature: Codable, Equatable, Sendable {
        var by_pubkey: String
        var alg: String
        var sig: String
    }

    var contract_id: String
    var domain_a: String
    var pubkey_a: String
    var domain_b: String
    var pubkey_b: String
    var scope: String
    var created_at: String
    var revocation: Revocation
    var signatures: [Signature]

    /// JCS over alle felt unntatt `signatures` — de bytene begge sider signerer.
    func canonicalPayloadData() throws -> Data {
        try JCSCanonicalizer.canonicalizeRemovingTopLevelKeys(JSONEncoder().encode(self), keys: ["signatures"])
    }
}

/// Avslag fra den som svarer. JCS over alle felt unntatt `sig`.
nonisolated struct ToolLinkDecline: Codable, Equatable, Sendable {
    var contract_id: String
    var declined_at: String
    var reason: String
    var by_pubkey: String
    var alg: String
    var sig: String

    func canonicalPayloadData() throws -> Data {
        try JCSCanonicalizer.canonicalizeRemovingTopLevelKeys(JSONEncoder().encode(self), keys: ["sig"])
    }
}

/// Eierens tilbaketrekking. JCS over alle felt unntatt `sig`.
nonisolated struct ToolLinkRevocation: Codable, Equatable, Sendable {
    var contract_id: String
    var revoked_at: String
    var reason: String
    var by_pubkey: String
    var alg: String
    var sig: String

    func canonicalPayloadData() throws -> Data {
        try JCSCanonicalizer.canonicalizeRemovingTopLevelKeys(JSONEncoder().encode(self), keys: ["sig"])
    }
}

/// Fire ord fra SHA-256 av lenkens kanoniske bytes. Samme ordliste og samme regel som
/// CellBase `IdentityLinkSAS` (256 ord, ett ord per byte, de fire første bytene), som
/// agenten bruker. Kopiert fordi CellProtocol-versjonen HAVEN bygger mot ennå ikke har den;
/// `ToolLinkControllerTests` holder den lik agentens testvektor.
nonisolated enum ToolLinkSecurityWords {
    static let norwegian: [String] = [
        "aks","alm","and","ape","arm","ask","bad","bak","ball","bane","bark","bein","berg","bil","bjelle","blad",
        "blomst","bok","bolle","bord","borg","bro","brus","bukse","bunn","busk","by","bål","båt","damp","dans","dis",
        "dukke","dyr","dør","egg","eik","elg","elv","eng","eple","erle","esel","fane","fat","fe","fjell","fjær",
        "flagg","flis","flue","fly","fold","foss","frosk","frø","fugl","furu","gaffel","gard","gate","geit","gjerde","glass",
        "gran","gress","grop","gull","gutt","hage","hale","hals","hane","hatt","hav","hei","hest","hjul","hode","holme",
        "hop","horn","hule","hund","hus","hval","hylle","hytte","høne","høst","is","jakke","jord","juv","kake","kalv",
        "kam","kano","kappe","katt","kilde","kiste","kjele","klokke","knapp","kniv","kopp","korg","krok","krone","kule","kurv",
        "kvist","kyst","lam","lampe","land","laks","lue","lykt","lys","løk","løve","maur","melk","mose","mur","mus",
        "myr","måke","måne","nebb","nese","nett","nål","ord","orm","ost","ovn","panne","park","pels","penn","pil",
        "plog","pose","potte","pute","ravn","regn","reke","rev","ring","ripe","ro","rop","rose","rot","rype","rør",
        "sag","saks","salt","sand","seil","seks","sel","seng","sil","skap","ski","skje","skog","skål","sky","slott",
        "smør","snø","sol","spade","spor","stav","stein","stol","storm","strand","stue","sump","svane","sverd","sykkel","såpe",
        "tak","tann","tau","te","telt","tind","torv","trapp","tre","trost","trå","tue","tunge","tønne","ugle","ull",
        "ulv","ur","vann","vei","vind","vott","vår","øks","øy","ørn","åker","ås","hjort","kråke","lerke","spurv",
        "bjørk","hassel","lønn","osp","rogn","selje","einer","lyng","tang","tare","torsk","sild","ørret","sei","hyse","brosme",
        "hammer","hakke","fil","syl","meisel","høvel","bor","drill","skrue","spiker","lim","tråd","garn","vev","teppe","duk"
    ]

    static func words(forCanonical canonical: Data) -> [String] {
        Array(SHA256.hash(data: canonical)).prefix(4).map { norwegian[Int($0)] }
    }

    static func display(_ words: [String]) -> String {
        words.joined(separator: " · ")
    }
}

nonisolated enum ToolLinkCrypto {
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func fromBase64URL(_ text: String) -> Data? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }

    /// Algoritmenavnet agenten og Sprout forstår, ut fra nøkkellengden.
    static func algorithm(forPublicKeyBase64URL key: String) -> String? {
        switch fromBase64URL(key)?.count {
        case 32: return "Ed25519"
        case 33, 65: return "P256-ES256"
        default: return nil
        }
    }

    static func verify(alg: String, publicKeyBase64URL: String, signatureBase64URL: String, data: Data) -> Bool {
        guard let keyData = fromBase64URL(publicKeyBase64URL), let signature = fromBase64URL(signatureBase64URL) else { return false }
        switch alg.lowercased() {
        case "ed25519":
            guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else { return false }
            return key.isValidSignature(signature, for: data)
        case "es256", "p256-es256":
            let key: P256.Signing.PublicKey?
            switch keyData.count {
            case 65: key = try? P256.Signing.PublicKey(x963Representation: keyData)
            case 33: key = try? P256.Signing.PublicKey(compressedRepresentation: keyData)
            default: key = nil
            }
            guard let key else { return false }
            if let der = try? P256.Signing.ECDSASignature(derRepresentation: signature), key.isValidSignature(der, for: data) {
                return true
            }
            if signature.count == 64, let raw = try? P256.Signing.ECDSASignature(rawRepresentation: signature) {
                return key.isValidSignature(raw, for: data)
            }
            return false
        default:
            return false
        }
    }

    /// Kort visning av en nøkkel: de første 8 bytene av SHA-256, i fire grupper.
    static func fingerprint(of keyBase64URL: String) -> String {
        guard let data = fromBase64URL(keyBase64URL) else { return "ukjent" }
        let hex = SHA256.hash(data: data).prefix(8).map { String(format: "%02X", $0) }.joined()
        return stride(from: 0, to: hex.count, by: 4).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return String(hex[start..<hex.index(start, offsetBy: 4)])
        }.joined(separator: " ")
    }

    static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func parse(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        if let date = ISO8601DateFormatter().date(from: iso) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: iso)
    }

    /// «12:34» i dag, ellers «23. sep. 12:34».
    static func clock(_ iso: String?) -> String {
        guard let date = parse(iso) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "d. MMM HH:mm"
        return formatter.string(from: date)
    }
}

/// Eierens nøkkel slik lenkene trenger den: offentlig nøkkel, algoritmenavn og en signering.
/// I appen signerer identitetshvelvet (Touch ID); i testene en CryptoKit-nøkkel.
nonisolated struct ToolLinkSigner: Sendable {
    var publicKeyBase64URL: String
    var algorithm: String
    var sign: @Sendable (Data) async throws -> Data?

    init(publicKeyBase64URL: String, algorithm: String, sign: @escaping @Sendable (Data) async throws -> Data?) {
        self.publicKeyBase64URL = publicKeyBase64URL
        self.algorithm = algorithm
        self.sign = sign
    }

    /// Samme nøkkelform som paringen bruker (`publicSecureKey.compressedKey`, base64url).
    static func publicKey(of identity: Identity) -> String? {
        guard let key = identity.publicSecureKey?.compressedKey, key.isEmpty == false else { return nil }
        return ToolLinkCrypto.base64URL(key)
    }

    static func from(_ identity: Identity) -> ToolLinkSigner? {
        guard let key = publicKey(of: identity), let algorithm = ToolLinkCrypto.algorithm(forPublicKeyBase64URL: key) else {
            return nil
        }
        return ToolLinkSigner(publicKeyBase64URL: key, algorithm: algorithm) { data in
            try await identity.sign(data: data)
        }
    }
}

/// Kontrollen HAVEN gjør på verktøyets forespørsel før eieren får signere.
nonisolated enum ToolLinkReview {
    static let scope = "agent.tool.instruct"
    static let toolDomain = "haven.agent.test-flow"
    static let revocationMode = "owner-only"
    static let scopeLabel = "Sende testinstruksjoner til agenten min"

    nonisolated struct Checked: Sendable {
        var contract: ToolLinkContract
        var canonical: Data
        var words: [String]
        var label: String
    }

    nonisolated enum Problem: Error, Equatable, LocalizedError {
        case unreadable
        case notForThisOwner
        case wrongScope(String)
        case changedBytes
        case toolSignatureInvalid
        case wordsDiffer(agent: String, here: String)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "Lenken fra agenten kunne ikke leses."
            case .notForThisOwner:
                return "Lenken er ikke ment for nøkkelen i denne HAVEN-en."
            case .wrongScope(let scope):
                return "Lenken ber om noe annet enn testinstruksjoner (\(scope))."
            case .changedBytes:
                return "Bytene agenten viser er ikke de samme som i lenken. Ikke godkjenn."
            case .toolSignatureInvalid:
                return "Verktøyets signatur holder ikke. Ikke godkjenn."
            case .wordsDiffer(let agent, let here):
                return "Ordene er ikke like: agenten viser «\(agent)», HAVEN regner ut «\(here)». Ikke godkjenn."
            }
        }
    }

    /// Lenken i en rad fra agentens `links`, og de kanoniske bytene regnet ut her.
    static func contract(from item: [String: Any]) -> (contract: ToolLinkContract, canonical: Data)? {
        guard let object = item["contract"],
              JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let contract = try? JSONDecoder().decode(ToolLinkContract.self, from: data),
              let canonical = try? contract.canonicalPayloadData() else {
            return nil
        }
        return (contract, canonical)
    }

    /// Verktøyets forespørsel: én signatur (verktøyets), ment for eierens nøkkel, riktig
    /// omfang, samme bytes og samme fire ord som agenten viser.
    static func checkToolRequest(_ item: [String: Any], ownerKey: String) throws -> Checked {
        guard let parsed = Self.contract(from: item) else { throw Problem.unreadable }
        let contract = parsed.contract
        let canonical = parsed.canonical
        guard contract.pubkey_a == ownerKey else { throw Problem.notForThisOwner }
        guard contract.scope == scope, contract.domain_b == toolDomain, contract.revocation.mode == revocationMode else {
            throw Problem.wrongScope(contract.scope)
        }
        if let shown = item["canonicalPayloadBase64URL"] as? String, ToolLinkCrypto.fromBase64URL(shown) != canonical {
            throw Problem.changedBytes
        }
        guard contract.signatures.count == 1,
              let signature = contract.signatures.first,
              signature.by_pubkey == contract.pubkey_b,
              ToolLinkCrypto.verify(alg: signature.alg, publicKeyBase64URL: signature.by_pubkey, signatureBase64URL: signature.sig, data: canonical) else {
            throw Problem.toolSignatureInvalid
        }
        let words = ToolLinkSecurityWords.words(forCanonical: canonical)
        if let agentWords = item["securityWords"] as? [String], agentWords != words {
            throw Problem.wordsDiffer(agent: ToolLinkSecurityWords.display(agentWords), here: ToolLinkSecurityWords.display(words))
        }
        return Checked(contract: contract, canonical: canonical, words: words, label: item["label"] as? String ?? "Verktøyet")
    }
}

/// Adressen og tokenet til agentens kontrollbro.
nonisolated struct ToolLinkAgentEndpoint: Sendable, Equatable {
    var base: URL
    var accessToken: String?

    /// Det samme HAVEN allerede bruker mot agenten: `localControlBridge` i agentens config.json.
    static func fromAgentConfig() -> ToolLinkAgentEndpoint? {
        guard let endpoint = AgentLocalControlBridgeEndpointSupport.controlBridgeHTTPEndpoint() else { return nil }
        return ToolLinkAgentEndpoint(base: endpoint.base, accessToken: endpoint.accessToken)
    }
}

/// Snakker med agentens kontrollbro, holder det siste bildet av lenkene for skjelettet, og
/// lar eierens nøkkel signere når du trykker. Signerer aldri noe som ikke har bestått
/// `ToolLinkReview` her.
nonisolated final class BindingToolLinkController: @unchecked Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    typealias EndpointProvider = @Sendable () -> ToolLinkAgentEndpoint?
    /// Kontrakten «Ber om tilgang» skal markere, når HAVEN ble åpnet fra HAVEN Agent.
    typealias FocusProvider = @Sendable () -> String?

    /// Hvor en melding vises: under «Ber om tilgang», under «Gi tilgang», under «Koblede
    /// steder», eller under paringen.
    nonisolated enum MessageSlot: Hashable, Sendable {
        case answer
        case offer
        case linked
        case pairing
    }

    /// Svaret på det du sist trykket, og om det gikk.
    nonisolated struct Note: Sendable, Equatable {
        var text: String
        var ok: Bool
    }

    /// Om agenten er paret med nøkkelen som brukes her.
    nonisolated enum AgentPairing: String, Sendable {
        case unknown
        case here
        case elsewhere
    }

    nonisolated enum AgentError: Error, LocalizedError {
        case notConfigured
        case http(Int, String)
        case unreadable

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Fant ikke agentens kontrollbro i config.json. Er HAVEN Agent installert og paret med denne HAVEN-en?"
            case .http(let code, let reason):
                return "Agenten svarte \(code): \(reason)"
            case .unreadable:
                return "Agenten svarte med noe som ikke kunne leses."
            }
        }
    }

    private let endpointProvider: EndpointProvider
    private let transport: Transport
    private let focusProvider: FocusProvider
    private let lock = NSLock()

    private var incoming: [Object] = []
    private var outgoing: [Object] = []
    private var active: [Object] = []
    private var history: [Object] = []
    private var tools: [Object] = []
    private var incomingIDs: Set<String> = []
    private var activeIDs: Set<String> = []
    private var selectedToolID: String?
    private var ownerKeyAtAgent: String?
    private var scaffoldDomain: String?
    private var knownOwnerKey: String?
    private var summary = "Henter lenker fra agenten …"
    private var agentPairing: AgentPairing = .unknown
    private var agentProblem: String?
    private var agentMissing = false
    private var hasLoaded = false
    private var notes: [MessageSlot: Note] = [:]
    private var lastRefresh: Date?
    private var inflight: Task<Void, Never>?
    private var checked: [String: ToolLinkReview.Checked] = [:]
    private var problems: [String: String] = [:]

    init(
        endpoint: @escaping EndpointProvider = { ToolLinkAgentEndpoint.fromAgentConfig() },
        transport: @escaping Transport = { request in try await URLSession.shared.data(for: request) },
        focus: @escaping FocusProvider = { BindingAccessRequestFocus.shared.current() }
    ) {
        self.endpointProvider = endpoint
        self.transport = transport
        self.focusProvider = focus
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    // MARK: - Det skjelettet leser

    func stateFields() -> Object {
        locked {
            [
                // Flaten viser tre lister med rader av ulike slag (`kind`). En skjult rad tar
                // ingen plass, en tom liste gjør det, og synlighet med rot-scope virker ikke på
                // toppnivå (lesson.unresolvable-condition-is-invisible). Derfor bestemmer
                // radene her hva som vises, og hver del av flaten er én liste.
                "toolAgentRows": .list(agentRowsLocked().map(ValueType.object)),
                "toolLinkedRows": .list(linkedRowsLocked().map(ValueType.object)),
                "toolHistoryRows": .list(historyRowsLocked().map(ValueType.object)),
                "agentPairing": .string(agentPairing.rawValue),
                "toolSummary": .string(summary),
                "toolIncoming": .list(incoming.map(ValueType.object)),
                "toolIncomingCount": .integer(incoming.count),
                "toolOutgoing": .list(outgoing.map(ValueType.object)),
                "toolOutgoingCount": .integer(outgoing.count),
                "toolActive": .list(active.map(ValueType.object)),
                "toolActiveCount": .integer(active.count),
                "toolHistory": .list(history.map(ValueType.object)),
                "toolHistoryCount": .integer(history.count),
                "toolChoices": .list(tools.map(ValueType.object)),
                "toolScopeChoices": .list([
                    .object(["label": .string(ToolLinkReview.scopeLabel), "value": .string(ToolLinkReview.scope)])
                ]),
                "selectedToolID": selectedToolID.map(ValueType.string) ?? .null,
                "selectedScope": .string(ToolLinkReview.scope),
                "toolAnswerMessage": .string(notes[.answer]?.text ?? ""),
                "toolOfferMessage": .string(notes[.offer]?.text ?? ""),
                "toolLinkedMessage": .string(notes[.linked]?.text ?? ""),
                "toolPairingMessage": .string(notes[.pairing]?.text ?? "")
            ]
        }
    }

    /// Om agenten er paret med nøkkelen som brukes her, slik det så ut ved siste henting.
    func pairingState() -> AgentPairing {
        locked { agentPairing }
    }

    // MARK: - Radene flaten viser (kalles med låsen holdt)

    /// Kortet «HAVEN Agent på denne maskinen». Er agenten paret med en annen identitet,
    /// eller ikke paret, er paringen det eneste kortet tilbyr — ingen svarknapper og ingen
    /// «Tilby», fordi agenten ville avvist dem.
    private func agentRowsLocked() -> [Object] {
        if hasLoaded == false {
            return [Self.row("note", ["text": .string("Henter status fra HAVEN Agent …")])]
        }
        if agentMissing {
            #if os(macOS)
            // Sandkassen skjuler agentens config.json til eieren har gitt lov én gang. Uten en
            // knapp her var dette en blindvei: «Svar i HAVEN» landet på en setning og ingenting mer.
            var rows = [Self.row("agentAccess", [
                "title": .string("HAVEN ser ikke HAVEN Agent ennå"),
                "body": .string("HAVEN kjører i en sandkasse og får ikke lese agentens oppsett før du gir lov én gang. Trykk knappen, velg mappen «Application Support» og trykk «Gi tilgang». Er agenten ikke installert, hjelper ikke dette."),
            ])]
            if let note = notes[.pairing] { rows.append(Self.noteRow(note)) }
            return rows
            #else
            return [Self.row("note", ["text": .string("HAVEN Agent er ikke satt opp på denne maskinen.")])]
            #endif
        }
        if let agentProblem {
            return [Self.row("problem", ["text": .string(agentProblem)])]
        }
        if agentPairing == .elsewhere || ownerKeyAtAgent == nil {
            var rows = [agentPairing == .elsewhere
                ? Self.pairingRow(
                    title: "HAVEN Agent er paret med en annen identitet",
                    body: "Agenten på denne maskinen ble paret med en HAVEN-identitet du ikke bruker her. Par den med denne HAVEN-en, så kan du svare på forespørsler og gi tilgang herfra."
                )
                : Self.pairingRow(
                    title: "HAVEN Agent er ikke paret ennå",
                    body: "Par agenten på denne maskinen med denne HAVEN-en, så kan verktøy i agenten be om tilgang, og du kan gi tilgang herfra."
                )]
            if let note = notes[.pairing] { rows.append(Self.noteRow(note)) }
            return rows
        }
        var rows: [Object] = [Self.subheading("Ber om tilgang", withRefresh: true)]
        // Åpnet fra «Svar i HAVEN» i HAVEN Agent: marker den forespørselen. Markeringen
        // velger bare hva som vises; svaret gis fortsatt med knappene i raden.
        let focused = focusProvider()
        rows += incoming.map { request in
            var row = request
            let isFocused = focused != nil && HavenValue.string(request["contractID"]) == focused
            row["isFocused"] = .bool(isFocused)
            row["focusLine"] = .string(isFocused ? "Åpnet fra HAVEN Agent" : "")
            return Self.row("request", row)
        }
        if let focused, incoming.contains(where: { HavenValue.string($0["contractID"]) == focused }) == false {
            rows.append(Self.row("note", ["text": .string(
                "Forespørselen du åpnet fra HAVEN Agent venter ikke lenger her. Den kan være besvart, trukket tilbake eller utløpt."
            )]))
        } else if incoming.isEmpty {
            rows.append(Self.row("note", ["text": .string("Ingen verktøy ber om tilgang akkurat nå.")]))
        }
        if let note = notes[.answer] { rows.append(Self.noteRow(note)) }
        rows.append(Self.subheading("Gi tilgang", withRefresh: false))
        if tools.isEmpty {
            rows.append(Self.row("note", ["text": .string("Agenten har ingen verktøycelle å gi tilgang til.")]))
        } else if scaffoldDomain?.isEmpty ?? true {
            rows.append(Self.row("note", ["text": .string("Agenten er ikke forankret hos deg ennå, så den kan ikke ta imot et tilbud.")]))
        } else {
            rows.append(Self.row("offerForm", [:]))
        }
        rows += outgoing.map { Self.row("outgoing", $0) }
        // Et vellykket tilbud vises som raden over («venter på svar i HAVEN Agent»); bare
        // det som gikk galt trenger en egen linje.
        if let note = notes[.offer], note.ok == false { rows.append(Self.noteRow(note)) }
        return rows
    }

    /// Verktøyene som har tilgang nå, til «Koblede steder» — med «Trekk tilbake».
    private func linkedRowsLocked() -> [Object] {
        var rows = active.map { Self.row("tool", $0) }
        if let note = notes[.linked] { rows.append(Self.noteRow(note)) }
        return rows
    }

    /// De siste svarene, som spor i begge ender.
    private func historyRowsLocked() -> [Object] {
        guard history.isEmpty == false else { return [] }
        return [Self.subheading("Siste svar", withRefresh: false)] + history.map { Self.row("history", $0) }
    }

    private static func row(_ kind: String, _ fields: Object) -> Object {
        var row = fields
        row["kind"] = .string(kind)
        return row
    }

    private static func subheading(_ text: String, withRefresh: Bool) -> Object {
        row("subheading", ["text": .string(text), "hasRefresh": .bool(withRefresh)])
    }

    private static func noteRow(_ note: Note) -> Object {
        row(note.ok ? "success" : "failure", ["text": .string(note.text)])
    }

    private static func pairingRow(title: String, body: String) -> Object {
        row("pairing", [
            "title": .string(title),
            "body": .string(body),
            "footnote": .string("Du bekrefter med Touch ID. Agenten tar i bruk paringen når den starter på nytt.")
        ])
    }

    /// Nytt bilde når skjelettet leser tilstanden, høyst hvert femte sekund. Lesinger som
    /// kommer samtidig venter på den samme hentingen.
    func refreshForRead(ownerKey: String?) async {
        let task: Task<Void, Never>? = locked {
            if let ownerKey { knownOwnerKey = ownerKey }
            if let inflight { return inflight }
            if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 5 { return nil }
            let task = Task.detached { [self] in
                _ = await self.refresh(timeout: 3)
                self.locked { self.inflight = nil }
            }
            inflight = task
            return task
        }
        await task?.value
    }

    @discardableResult
    func refresh(ownerKey: String? = nil, timeout: TimeInterval = 10) async -> Object {
        let hereKey: String? = locked {
            if let ownerKey { knownOwnerKey = ownerKey }
            return knownOwnerKey
        }
        defer { locked { lastRefresh = Date() } }
        do {
            let toolsResponse = try await call("GET", "test-flow/tools", timeout: timeout)
            let approvals = try await call("GET", "test-flow/approvals", timeout: timeout)
            if let status = approvals["status"] as? String, status == "unavailable" {
                let message = approvals["message"] as? String ?? "Agenten har ingen godkjenningscelle ennå."
                locked {
                    summary = message
                    agentProblem = message
                    agentMissing = false
                    hasLoaded = true
                    agentPairing = .unknown
                }
                return HavenValue.error(code: "agent_unavailable", message: message)
            }
            let ownerAtAgent = toolsResponse["ownerPublicKeyBase64URL"] as? String
            let domain = toolsResponse["scaffoldDomain"] as? String
            let toolRows: [Object] = (toolsResponse["tools"] as? [[String: Any]] ?? []).compactMap { tool in
                guard let id = tool["identityUUID"] as? String, let label = tool["label"] as? String else { return nil }
                return [
                    "label": .string("\(label) (verktøycelle)"),
                    "value": .string(id),
                    "toolLabel": .string(label),
                    "publicKeyBase64URL": .string(tool["publicKeyBase64URL"] as? String ?? ""),
                    "fingerprint": .string(tool["fingerprint"] as? String ?? "")
                ]
            }
            let items = ((approvals["links"] as? [String: Any])?["items"] as? [[String: Any]]) ?? []
            let view = Self.rows(of: items, checkingAgainst: hereKey ?? ownerAtAgent)
            let line: String
            if let hereKey, let ownerAtAgent, hereKey != ownerAtAgent {
                line = "Agenten er paret med en annen HAVEN-identitet (nøkkel \(ToolLinkCrypto.fingerprint(of: ownerAtAgent))) enn den som brukes her (\(ToolLinkCrypto.fingerprint(of: hereKey))). Svar herfra blir avvist til agenten er paret med denne HAVEN-en."
            } else {
                line = "\(view.incoming.count) ber om tilgang · \(view.outgoing.count) venter på svar i HAVEN Agent · \(view.active.count) aktive"
            }
            locked {
                incoming = view.incoming
                outgoing = view.outgoing
                active = view.active
                history = view.history
                incomingIDs = Set(view.incoming.compactMap { HavenValue.string($0["contractID"]) })
                activeIDs = Set(view.active.compactMap { HavenValue.string($0["contractID"]) })
                checked = view.checked
                problems = view.problems
                tools = toolRows
                let toolIDs = toolRows.compactMap { HavenValue.string($0["value"]) }
                if selectedToolID == nil || toolIDs.contains(selectedToolID ?? "") == false {
                    selectedToolID = toolIDs.first
                }
                ownerKeyAtAgent = ownerAtAgent
                scaffoldDomain = domain
                summary = line
                agentProblem = nil
                agentMissing = false
                hasLoaded = true
                if let hereKey, let ownerAtAgent {
                    agentPairing = hereKey == ownerAtAgent ? .here : .elsewhere
                } else {
                    agentPairing = .unknown
                }
            }
            return HavenValue.ok(line, sideEffect: false)
        } catch AgentError.notConfigured {
            // Ingen agent på denne maskinen er ikke en feil; flaten sier det med én linje.
            let message = "HAVEN Agent er ikke satt opp på denne maskinen."
            locked {
                summary = message
                agentProblem = nil
                agentMissing = true
                hasLoaded = true
                agentPairing = .unknown
            }
            return HavenValue.error(code: "agent_not_configured", message: message)
        } catch {
            let message = "Fikk ikke kontakt med HAVEN Agent: \(error.localizedDescription)"
            locked {
                summary = message
                agentProblem = message
                agentMissing = false
                hasLoaded = true
                agentPairing = .unknown
            }
            return HavenValue.error(code: "agent_unreachable", message: message)
        }
    }

    // MARK: - Radene begge ender skal kunne lese likt

    nonisolated private struct Rows {
        var incoming: [Object] = []
        var outgoing: [Object] = []
        var active: [Object] = []
        var history: [Object] = []
        var checked: [String: ToolLinkReview.Checked] = [:]
        var problems: [String: String] = [:]
    }

    private static func rows(of items: [[String: Any]], checkingAgainst ownerKey: String?) -> Rows {
        var view = Rows()
        var finished: [(Date, Object)] = []
        for item in items {
            guard let contractID = item["contractID"] as? String, let state = item["state"] as? String else { continue }
            let label = item["label"] as? String ?? "Verktøyet"
            let created = ToolLinkCrypto.clock(item["createdAt"] as? String)
            let answered = ToolLinkCrypto.clock(item["answeredAt"] as? String)
            let answeredBy = item["answeredBy"] as? String
            let byAgent = answeredBy == "HAVEN Agent"
            let parsed = ToolLinkReview.contract(from: item)
            // Lenker til en annen identitet (en tidligere paring) er ikke dine: de vises ikke, og
            // du kan ikke trekke dem tilbake herfra. Forespørsler sjekkes for seg under.
            if state != "awaiting-owner", let ownerKey, let owner = parsed?.contract.pubkey_a, owner != ownerKey {
                continue
            }
            let localWords = parsed.map { ToolLinkSecurityWords.words(forCanonical: $0.canonical) }
            let words = localWords.map(ToolLinkSecurityWords.display) ?? (item["securityCode"] as? String ?? "")
            switch state {
            case "awaiting-owner":
                var row: Object = [
                    "contractID": .string(contractID),
                    // Ikke «label»: renderen bruker radens label som knappetekst, så begge svarknappene het «Losen».
                    "toolLabel": .string(label),
                    // Som i skissen v2: verktøyet og hva det ber om i halvfet.
                    "headline": .string("**\(label) — verktøycelle i agenten din** ber om å **sende testinstruksjoner til agenten din**"),
                    "title": .string("\(label) — verktøycelle i agenten din"),
                    "summaryLine": .string("ber om å sende testinstruksjoner til agenten din"),
                    "detailLine": .string(trimmed("omfang \(ToolLinkReview.scope) · nøkkel \(item["toolKeyFingerprint"] as? String ?? "?") · startet av verktøyet \(created)")),
                    "securityCode": .string(words),
                    "question": .string("Stemmer ordene med dem i HAVEN Agent?"),
                    "warning": .string(""),
                    "hasWarning": .bool(false),
                    "canAnswer": .bool(false)
                ]
                if let ownerKey {
                    do {
                        let result = try ToolLinkReview.checkToolRequest(item, ownerKey: ownerKey)
                        view.checked[contractID] = result
                        row["securityCode"] = .string(ToolLinkSecurityWords.display(result.words))
                        row["canAnswer"] = .bool(true)
                    } catch ToolLinkReview.Problem.notForThisOwner {
                        // Forespørselen gjelder en annen identitet enn den som brukes her. Den er
                        // ikke din å svare på, og vises ikke; er agenten paret et annet sted, er
                        // paringen det flaten tilbyr. Godkjenn og avvis sier fortsatt hvorfor.
                        view.problems[contractID] = ToolLinkReview.Problem.notForThisOwner.localizedDescription
                        continue
                    } catch {
                        view.problems[contractID] = error.localizedDescription
                        row["warning"] = .string("⚠︎ \(error.localizedDescription)")
                        row["hasWarning"] = .bool(true)
                    }
                } else {
                    view.problems[contractID] = "HAVEN vet ikke hvilken nøkkel agenten er paret med."
                    row["warning"] = .string("⚠︎ HAVEN vet ikke hvilken nøkkel agenten er paret med.")
                    row["hasWarning"] = .bool(true)
                }
                view.incoming.append(row)
            case "awaiting-tool":
                view.outgoing.append([
                    "contractID": .string(contractID),
                    "title": .string(trimmed("Tilbudt til \(label) \(created)")),
                    "securityCode": .string(words),
                    "statusLine": .string("venter på svar i HAVEN Agent"),
                    "tone": .string("warning")
                ])
            case "active":
                view.active.append([
                    "contractID": .string(contractID),
                    "title": .string("\(label) — sende testinstruksjoner"),
                    "statusLine": .string(trimmed(byAgent ? "✓ godtatt i HAVEN Agent \(answered)" : "✓ godkjent av deg \(answered)")),
                    "detailLine": .string(item["initiatorText"] as? String ?? ""),
                    "tone": .string("success")
                ])
            default:
                let line: String
                let tone: String
                let at: Date?
                switch state {
                case "declined":
                    line = trimmed(byAgent ? "✗ avvist i HAVEN Agent \(answered)" : "✗ avvist av deg \(answered)")
                    tone = "danger"
                    at = ToolLinkCrypto.parse(item["answeredAt"] as? String)
                case "revoked":
                    line = trimmed("trukket tilbake av deg \(ToolLinkCrypto.clock(item["revokedAt"] as? String))")
                    tone = "danger"
                    at = ToolLinkCrypto.parse(item["revokedAt"] as? String)
                case "expired":
                    line = answeredBy.map { "utløpt (\($0))" } ?? "utløpt uten svar"
                    tone = "warning"
                    at = ToolLinkCrypto.parse(item["expiresAt"] as? String)
                default:
                    line = item["stateText"] as? String ?? state
                    tone = "neutral"
                    at = nil
                }
                let when = at ?? ToolLinkCrypto.parse(item["createdAt"] as? String) ?? .distantPast
                finished.append((when, [
                    "contractID": .string(contractID),
                    "title": .string("\(label) — sende testinstruksjoner"),
                    "statusLine": .string(line),
                    // Sporet i «Koblede steder» er én linje: hva, og hva svaret ble.
                    "summaryLine": .string("\(label) — sende testinstruksjoner · \(line)"),
                    "tone": .string(tone),
                    "detailLine": .string(trimmed("\(item["initiatorText"] as? String ?? "") \(created)"))
                ]))
            }
        }
        view.history = finished.sorted { $0.0 > $1.0 }.prefix(5).map { $0.1 }
        return view
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Handlinger (eierens nøkkel signerer; i appen med Touch ID)

    /// A: verktøyet ba — du godkjenner. Legger din signatur til verktøyets.
    func approve(contractID: String, signer: ToolLinkSigner) async -> Object {
        await refresh(ownerKey: signer.publicKeyBase64URL)
        let state = locked { (checked[contractID], problems[contractID]) }
        guard let item = state.0 else {
            let message = state.1.map { "Ikke godkjent: \($0)" }
                ?? "Fant ikke forespørselen hos agenten. Den kan være besvart eller utløpt."
            return remember(HavenValue.error(code: "not_checked", message: message), in: .answer)
        }
        do {
            guard let signature = try await signer.sign(item.canonical) else {
                return remember(HavenValue.error(code: "signing_failed", message: "Signeringen ble avbrutt."), in: .answer)
            }
            var contract = item.contract
            contract.signatures.append(.init(
                by_pubkey: signer.publicKeyBase64URL,
                alg: signer.algorithm,
                sig: ToolLinkCrypto.base64URL(signature)
            ))
            let response = try await call("POST", "test-flow/approval", body: try JSONEncoder().encode(contract))
            let message = "Godkjent: \(item.label) kan sende testinstruksjoner. Ordene var \(ToolLinkSecurityWords.display(item.words)). HAVEN Agent viser at du godkjente."
            return remember(await outcome(response, success: "accepted", ownerKey: signer.publicKeyBase64URL, message: message), in: .answer)
        } catch {
            return remember(HavenValue.error(code: "approve_failed", message: error.localizedDescription), in: .answer)
        }
    }

    /// A: verktøyet ba — du avslår. Avslaget signeres, så agenten kan vise hvem som sa nei.
    func decline(contractID: String, signer: ToolLinkSigner) async -> Object {
        await refresh(ownerKey: signer.publicKeyBase64URL)
        let known = locked { (incomingIDs.contains(contractID), problems[contractID]) }
        guard known.0 else {
            let message = known.1.map { "Ikke avvist: \($0)" }
                ?? "Fant ikke forespørselen hos agenten. Den kan være besvart eller utløpt."
            return remember(HavenValue.error(code: "not_found", message: message), in: .answer)
        }
        var statement = ToolLinkDecline(
            contract_id: contractID,
            declined_at: ToolLinkCrypto.iso(Date()),
            reason: "Avvist i HAVEN",
            by_pubkey: signer.publicKeyBase64URL,
            alg: signer.algorithm,
            sig: ""
        )
        do {
            guard let signature = try await signer.sign(try statement.canonicalPayloadData()) else {
                return remember(HavenValue.error(code: "signing_failed", message: "Signeringen ble avbrutt."), in: .answer)
            }
            statement.sig = ToolLinkCrypto.base64URL(signature)
            let response = try await call("POST", "test-flow/decline", body: try JSONEncoder().encode(statement))
            let message = "Avvist. HAVEN Agent viser at du avslo, og verktøyet spør ikke igjen før noen ber på nytt."
            return remember(await outcome(response, success: "declined", ownerKey: signer.publicKeyBase64URL, message: message), in: .answer)
        } catch {
            return remember(HavenValue.error(code: "decline_failed", message: error.localizedDescription), in: .answer)
        }
    }

    /// Tar imot valget fra velgeren: `{selectedIndex, selected}` der `selected` er verktøyets
    /// id (`itemID`) eller hele raden (`item`), eller bare id-en.
    func selectTool(_ value: ValueType) -> Object {
        let payload = HavenValue.object(value)
        let selected = payload?["selected"]
        let id = HavenValue.string(selected)
            ?? HavenValue.string(HavenValue.object(selected)?["value"])
            ?? HavenValue.string(payload?["value"])
            ?? HavenValue.string(value)
        locked { if let id, id.isEmpty == false { selectedToolID = id } }
        return HavenValue.ok("Valgt.", sideEffect: false)
    }

    /// Det velgeren leser for å vise hva som er valgt (`selectionStateKeypath`).
    func toolSelection() -> Object {
        ["selected": locked { selectedToolID }.map(ValueType.string) ?? .null]
    }

    /// Bare ett omfang finnes ennå; valget er med så flaten viser hva som gis.
    func selectScope(_ value: ValueType) -> Object {
        HavenValue.ok("Tilgang: \(ToolLinkReview.scopeLabel).", sideEffect: false)
    }

    func scopeSelection() -> Object {
        ["selected": .string(ToolLinkReview.scope)]
    }

    /// B: du tilbyr. Lenken signeres av deg først; verktøyet signerer når du godtar i HAVEN Agent.
    func offer(signer: ToolLinkSigner) async -> Object {
        await refresh(ownerKey: signer.publicKeyBase64URL)
        let snapshot = locked { (tools, selectedToolID, scaffoldDomain, ownerKeyAtAgent) }
        guard let domain = snapshot.2, domain.isEmpty == false else {
            return remember(HavenValue.error(code: "no_anchor", message: "Agenten er ikke forankret hos deg ennå (paring og entitetslenke), så den kan ikke ta imot et tilbud."), in: .offer)
        }
        guard snapshot.3 == nil || snapshot.3 == signer.publicKeyBase64URL else {
            return remember(HavenValue.error(code: "wrong_owner", message: "Denne HAVEN-en har ikke nøkkelen agenten er paret med. Tilbudet ville blitt avvist."), in: .offer)
        }
        guard let tool = snapshot.0.first(where: { HavenValue.string($0["value"]) == snapshot.1 }) ?? snapshot.0.first,
              let toolKey = HavenValue.string(tool["publicKeyBase64URL"]), toolKey.isEmpty == false else {
            return remember(HavenValue.error(code: "no_tool", message: "Agenten har ingen verktøycelle å gi tilgang til."), in: .offer)
        }
        let createdAt = ToolLinkCrypto.iso(Date())
        let seed = "offer|\(ToolLinkReview.toolDomain)|\(signer.publicKeyBase64URL)|\(toolKey)|\(ToolLinkReview.scope)|\(createdAt)"
        var contract = ToolLinkContract(
            contract_id: "elc_tool_" + String(ToolLinkCrypto.base64URL(Data(SHA256.hash(data: Data(seed.utf8)))).prefix(16)),
            domain_a: domain,
            pubkey_a: signer.publicKeyBase64URL,
            domain_b: ToolLinkReview.toolDomain,
            pubkey_b: toolKey,
            scope: ToolLinkReview.scope,
            created_at: createdAt,
            revocation: .init(mode: ToolLinkReview.revocationMode),
            signatures: []
        )
        do {
            let canonical = try contract.canonicalPayloadData()
            guard let signature = try await signer.sign(canonical) else {
                return remember(HavenValue.error(code: "signing_failed", message: "Signeringen ble avbrutt."), in: .offer)
            }
            contract.signatures = [.init(by_pubkey: signer.publicKeyBase64URL, alg: signer.algorithm, sig: ToolLinkCrypto.base64URL(signature))]
            let words = ToolLinkSecurityWords.display(ToolLinkSecurityWords.words(forCanonical: canonical))
            let response = try await call("POST", "test-flow/offer", body: try JSONEncoder().encode(contract))
            let label = HavenValue.string(tool["toolLabel"]) ?? "verktøyet"
            let message = "Tilbudt til \(label). Sikkerhetsord: \(words). Svar i HAVEN Agent."
            return remember(await outcome(response, success: "offered", ownerKey: signer.publicKeyBase64URL, message: message), in: .offer)
        } catch {
            return remember(HavenValue.error(code: "offer_failed", message: error.localizedDescription), in: .offer)
        }
    }

    /// Trekk tilbake en aktiv lenke. Bare eieren kan; raden blir stående som spor i begge ender.
    func revoke(contractID: String, signer: ToolLinkSigner) async -> Object {
        await refresh(ownerKey: signer.publicKeyBase64URL)
        guard locked({ activeIDs.contains(contractID) }) else {
            return remember(HavenValue.error(code: "not_found", message: "Fant ingen aktiv lenke å trekke tilbake."), in: .linked)
        }
        var statement = ToolLinkRevocation(
            contract_id: contractID,
            revoked_at: ToolLinkCrypto.iso(Date()),
            reason: "Trukket tilbake i HAVEN",
            by_pubkey: signer.publicKeyBase64URL,
            alg: signer.algorithm,
            sig: ""
        )
        do {
            guard let signature = try await signer.sign(try statement.canonicalPayloadData()) else {
                return remember(HavenValue.error(code: "signing_failed", message: "Signeringen ble avbrutt."), in: .linked)
            }
            statement.sig = ToolLinkCrypto.base64URL(signature)
            let response = try await call("POST", "test-flow/revoke", body: try JSONEncoder().encode(statement))
            let message = "Trukket tilbake. HAVEN Agent viser at lenken ikke gjelder lenger."
            return remember(await outcome(response, success: "revoked", ownerKey: signer.publicKeyBase64URL, message: message), in: .linked)
        } catch {
            return remember(HavenValue.error(code: "revoke_failed", message: error.localizedDescription), in: .linked)
        }
    }

    // MARK: - Hjelpere

    /// For handlinger cellen gjør selv (paring), så svaret vises på samme sted.
    func note(_ result: Object, in slot: MessageSlot) -> Object {
        remember(result, in: slot)
    }

    private func remember(_ result: Object, in slot: MessageSlot) -> Object {
        let text = HavenValue.string(result["message"]) ?? ""
        let ok = HavenValue.string(result["status"]) == "ok"
        locked { notes[slot] = text.isEmpty ? nil : Note(text: text, ok: ok) }
        return result
    }

    private func outcome(_ response: [String: Any], success: String, ownerKey: String, message: String) async -> Object {
        let result = response["result"] as? [String: Any] ?? response
        let status = result["status"] as? String ?? "ukjent"
        await refresh(ownerKey: ownerKey)
        guard status == success else {
            let reason = result["message"] as? String ?? result["reason"] as? String ?? status
            return HavenValue.error(code: "agent_refused", message: "Agenten tok ikke imot: \(reason)")
        }
        return HavenValue.ok(message, sideEffect: true, extra: ["agentStatus": .string(status)])
    }

    private func call(_ method: String, _ path: String, body: Data? = nil, timeout: TimeInterval = 10) async throws -> [String: Any] {
        guard let endpoint = endpointProvider(),
              var components = URLComponents(url: endpoint.base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw AgentError.notConfigured
        }
        let token = endpoint.accessToken.flatMap { $0.isEmpty ? nil : $0 }
        // Agenten godtar token i query bare på lese-GET; alt annet krever Bearer (401 ellers).
        if let token, method == "GET" {
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        guard let url = components.url else { throw AgentError.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse else { throw AgentError.unreadable }
        guard (200..<300).contains(http.statusCode) else {
            throw AgentError.http(http.statusCode, Self.reason(from: data))
        }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AgentError.unreadable
        }
        return object
    }

    private static func reason(from data: Data) -> String {
        if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let reason = object["reason"] as? String {
            return reason
        }
        return String(decoding: data.prefix(300), as: UTF8.self)
    }
}
