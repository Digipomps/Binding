import Foundation
import CellBase

/// Local demonstration only. Its key holder and bridges never replace the app identity.
@MainActor enum WP8ArticleMenu {
    static let title = "Palazzo artikkel (lokal)"
    static var enabled: Bool {
#if DEBUG
        WP8LocalClient.enabled
#else
        false
#endif
    }
    static var placeholder: CellConfiguration {
        var configuration = CellConfiguration(name: title)
        configuration.description = "Lokalt forhåndsgodkjent testoppsett"
        return configuration
    }
#if DEBUG
    private static var client: WP8LocalClient?
    private static var preparedFor: String?
    private static var prepared: CellConfiguration?

    static func configuration(appIdentity: Identity) async throws -> CellConfiguration {
        if preparedFor == appIdentity.uuid, let prepared { return prepared }
        let client = try await WP8LocalClient.load()
        var configuration = try await client.configuration()
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else { throw WP8Failure("No app resolver") }
        let guest = try await client.bridge("PalazzoGuestShell")
        let entity = try await client.bridge("PalazzoEntity")
        let hash = FlowHasher.sha256Hex(Data("art-arancini".utf8))
        let reactionKey = "entity.article.reaction." + hash
        // Narrow, app-owned adapters retain the already authorized bridges. They do
        // not re-resolve remote references without pins, or expose the test vault.
        let articleAdapter = await GeneralCell(owner: appIdentity)
        await articleAdapter.addInterceptForGet(requester: appIdentity, key: "guest") { _, requester in
            guard requester.referencesSameSigningIdentity(as: appIdentity) else { throw WP8Failure("Wrong local requester") }
            return try await guest.get(keypath: "guest", requester: client.identity)
        }
        let entityAdapter = await GeneralCell(owner: appIdentity)
        await entityAdapter.addInterceptForGet(requester: appIdentity, key: "entity") { _, requester in
            guard requester.referencesSameSigningIdentity(as: appIdentity) else { throw WP8Failure("Wrong local requester") }
            let rows = try await entity.get(keypath: reactionKey, requester: client.identity)
            return .object(["article": .object(["reaction": .object([hash: rows])])])
        }
        await entityAdapter.addInterceptForGet(requester: appIdentity, key: reactionKey) { _, requester in
            guard requester.referencesSameSigningIdentity(as: appIdentity) else { throw WP8Failure("Wrong local requester") }
            return try await entity.get(keypath: reactionKey, requester: client.identity)
        }
        for key in ["entity.article.react", "entity.article.comment." + hash] {
            await entityAdapter.addInterceptForSet(requester: appIdentity, key: key) { _, value, requester in
                guard requester.referencesSameSigningIdentity(as: appIdentity) else { throw WP8Failure("Wrong local requester") }
                if key == "entity.article.react" {
                    guard case .object(let fields) = value, fields["articleID"] == .string("art-arancini") else { throw WP8Failure("Unprepared article") }
                }
                return try await entity.set(keypath: key, value: value, requester: client.identity)
            }
        }
        let articleName = "WP8Article-" + UUID().uuidString
        let entityName = "WP8Entity-" + UUID().uuidString
        try await resolver.registerNamedEmitCell(name: articleName, emitCell: articleAdapter, scope: .identityUnique, identity: appIdentity)
        try await resolver.registerNamedEmitCell(name: entityName, emitCell: entityAdapter, scope: .identityUnique, identity: appIdentity)
        configuration.cellReferences = configuration.cellReferences?.map { reference in
            var reference = reference
            reference.endpoint = "cell:///" + (reference.endpoint == "cell:///PalazzoGuestShell" ? articleName : entityName)
            return reference
        }
        configuration.discovery?.sourceCellEndpoint = "cell:///" + articleName
        configuration.name = title
        self.client = client
        preparedFor = appIdentity.uuid
        prepared = configuration
        return configuration
    }
#endif
}
