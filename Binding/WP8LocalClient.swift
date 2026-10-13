// WP8 test setup only. Not product bootstrap or receipt-based discovery.
import Foundation
@_spi(Testing) import CellBase
import CellVapor

nonisolated struct WP8Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// BridgeBase.getOwner is the local bridge owner. The remote description's
// public agreement is retained by CP; these Palazzo templates are cell-owner-bound.
nonisolated struct WP8RemoteAgreementOwner: Decodable {
    let owner: Identity
    static func read(_ bridge: BridgeBase) throws -> Identity {
        let snapshot = try bridge.agreementTemplate.publicDescriptorSnapshot()
        return try JSONDecoder().decode(Self.self, from: JSONEncoder().encode(snapshot)).owner
    }
}

nonisolated struct WP8Pins: Codable {
    struct Cell: Codable {
        let origin: String
        let domain: String
        let name: String
        let ownerIdentity: String
        let uuid: String
    }
    let schema: String
    let testIdentity: String
    let signingFingerprint: String
    let identityContext: String
    let cells: [Cell]
    static let origin = "ws://127.0.0.1:8091"
    static let names = ["PalazzoGuestShell", "PalazzoEntity", "EntityAnchor", "PalazzoContent", "PalazzoAccessContracts"]
    static func domain(for name: String) -> String { name == "EntityAnchor" ? "private" : "palazzo-comunale" }
    var scopes: [BridgeIdentityProofScope] {
        cells.map { .init(domain: $0.domain, resource: $0.uuid) }
    }
    func validate(identity: Identity) throws {
        guard schema == "haven.wp8.test-pins.v1", testIdentity == identity.uuid,
              signingFingerprint == identity.signingPublicKeyFingerprint,
              Set(cells.map(\.name)) == Set(Self.names), cells.count == Self.names.count,
              Set(cells.map(\.uuid)).count == cells.count else { throw WP8Failure("Invalid test pins or identity") }
        for cell in cells {
            guard cell.origin == Self.origin, cell.domain == Self.domain(for: cell.name),
                  UUID(uuidString: cell.uuid) != nil, UUID(uuidString: cell.ownerIdentity) != nil else {
                throw WP8Failure("Invalid exact cell pin")
            }
            if ["PalazzoGuestShell", "PalazzoEntity", "EntityAnchor"].contains(cell.name), cell.ownerIdentity != testIdentity {
                throw WP8Failure("Wrong personal cell owner")
            }
        }
    }
}

/// A dedicated resolver owns this transport; the app's normal ws registry is untouched.
nonisolated final class WP8LocalHeaderTransport: BridgeTransportProtocol {
    private var delegate: (any BridgeDelegateProtocol)?
    private var physical: VaporBridgeTransport?
    static func new() -> any BridgeTransportProtocol { WP8LocalHeaderTransport() }
    func setDelegate(_ delegate: any BridgeDelegateProtocol) { self.delegate = delegate }
    func setup(_ endpoint: URL, identity: Identity) async throws {
        let canonical = try BridgeChannelAuthentication.Endpoint(url: endpoint, domain: "bridge", allowInsecureLoopback: true)
        let parts = endpoint.path.split(separator: "/")
        guard canonical.origin == WP8Pins.origin, parts.count == 3, parts[0] == "bridgehead",
              UUID(uuidString: String(parts[2])) != nil,
              let token = ProcessInfo.processInfo.environment["PALAZZO_BRIDGEHEAD_TOKEN"], !token.isEmpty,
              !token.contains("\r"), !token.contains("\n"), let delegate else { throw WP8Failure("Unapproved test endpoint") }
        let resource = String(parts[1])
        if CommandLine.arguments.contains("prepare") {
            guard WP8Pins.names.contains(resource) else { throw WP8Failure("Unapproved preparation name") }
        } else {
            guard let path = ProcessInfo.processInfo.environment["HAVEN_PALAZZO_PINS"] else { throw WP8Failure("Missing pins") }
            let pins = try JSONDecoder().decode(WP8Pins.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            try pins.validate(identity: identity)
            guard pins.cells.contains(where: { $0.uuid == resource }) else { throw WP8Failure("Unapproved runtime UUID") }
        }
        let physical = VaporBridgeTransport(upgradeHeaders: ["Authorization": "Bearer " + token])
        self.physical = physical
        physical.setDelegate(delegate)
        try await physical.setup(endpoint, identity: identity)
    }
    func sendData(_ data: Data) async throws {
        guard let physical else { throw WP8Failure("No transport") }
        try await physical.sendData(data)
    }
    func close() async { await physical?.close() }
    func identityVault(for identity: Identity?) async -> any IdentityVaultProtocol { await VaporIdentityVault.shared }
}

#if DEBUG
nonisolated final class WP8LocalClient {
    let resolver = CellResolver.makeIsolatedForTesting()
    let identity: Identity
    let pins: WP8Pins
    private(set) var bridges: [String: BridgeBase] = [:]
    static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["HAVEN_PALAZZO_ARTICLE_ENDPOINT"] == WP8Pins.origin + "/bridgehead/PalazzoGuestShell"
            && !(env["PALAZZO_BRIDGEHEAD_TOKEN"] ?? "").isEmpty
            && !(env["HAVEN_PALAZZO_PINS"] ?? "").isEmpty
            && !(env["CELL_VAULT_DOCUMENT_ROOT"] ?? "").isEmpty
    }
    init(identity: Identity, pins: WP8Pins) throws {
        try pins.validate(identity: identity)
        self.identity = identity; self.pins = pins
    }
    static func load() async throws -> WP8LocalClient {
        guard enabled, let path = ProcessInfo.processInfo.environment["HAVEN_PALAZZO_PINS"] else { throw WP8Failure("Missing WP8 test environment") }
        let bytes = try Data(contentsOf: URL(fileURLWithPath: path))
        guard bytes.count < 65536 else { throw WP8Failure("Oversized pin file") }
        let pins = try JSONDecoder().decode(WP8Pins.self, from: bytes)
        let vault = await VaporIdentityVault.shared.initialize()
        guard let identity = await vault.identity(for: pins.identityContext, makeNewIfNotFound: false) else { throw WP8Failure("Prepared test identity missing; run preparation") }
        let client = try WP8LocalClient(identity: identity, pins: pins)
        try await client.resolver.registerTransport(WP8LocalHeaderTransport.self, for: "ws")
        return client
    }
    func bridge(_ name: String) async throws -> BridgeBase {
        if let bridge = bridges[name] { return bridge }
        guard let pin = pins.cells.first(where: { $0.name == name }),
              let bridge = try await resolver.cellAtEndpoint(endpoint: pin.origin + "/bridgehead/" + pin.uuid,
                requester: identity, identityProofScopes: pins.scopes) as? BridgeBase else { throw WP8Failure("Missing approved bridge") }
        // Resolver may return a bridge after deferred description. Require actual metadata.
        try await bridge.retrieveProxyRepresentation(for: identity)
        let owner = try WP8RemoteAgreementOwner.read(bridge)
        guard bridge.hasAuthenticatedChannel, bridge.uuid == pin.uuid,
              bridge.identityDomain == pin.domain, owner.uuid == pin.ownerIdentity else {
            await bridge.close(requester: identity)
            throw WP8Failure("Prepared cell changed; explicit preparation required")
        }
        bridges[name] = bridge
        return bridge
    }
    func configuration() async throws -> CellConfiguration {
        let guest = try await bridge("PalazzoGuestShell")
        let result = try await guest.get(keypath: "guest.article.configuration", requester: identity)
        guard case let .cellConfiguration(configuration) = result,
              Set((configuration.cellReferences ?? []).map { $0.endpoint + "#" + $0.label }) == Set(["cell:///PalazzoGuestShell#article", "cell:///PalazzoEntity#entity"]),
              configuration.cellReferences?.count == 2 else { throw WP8Failure("Article configuration unavailable") }
        return configuration
    }
}
#endif
