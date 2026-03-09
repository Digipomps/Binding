//
//  BindingTests.swift
//  BindingTests
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import Foundation
import Testing
import CellBase
import CellApple
@testable import Binding

@Suite(.serialized)
struct BindingTests {

    @Test func configurationCatalogSeedsRichLibrary() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        _ = try await cell.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: owner)
        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        #expect(items.count >= 12)
    }

    @Test func configurationCatalogQueryReturnsRankedResults() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let payload = makeCatalogPayload(
            name: "Prosessmonitor",
            endpoint: "cell:///AdminProcesses",
            insertionMode: "component"
        )
        _ = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)

        let queryPayload: Object = [
            "requestId": .string("query-test-1"),
            "q": .string("monitor prosesser"),
            "filters": .object([
                "sourceRefs": .list([.string("cell:///AdminProcesses")])
            ]),
            "context": .object([
                "editMode": .bool(true),
                "insertionIntent": .string("component")
            ]),
            "constraints": .object([
                "maxResults": .integer(5),
                "maxSources": .integer(3),
                "latencyBudgetMs": .integer(300)
            ])
        ]
        let response = try await cell.set(keypath: "query", value: .object(queryPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra query")
            return
        }

        #expect(result["status"] == .string("ok"))
        if case let .list(results)? = result["results"] {
            #expect(!results.isEmpty)
        } else {
            Issue.record("Mangler results-list i query-respons")
        }
    }

    @Test func configurationCatalogFacetCountsIncludesInsertionModes() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let payload = makeCatalogPayload(
            name: "Prosesskort",
            endpoint: "cell:///AdminProcesses",
            insertionMode: "component"
        )
        _ = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)

        let facetPayload: Object = [
            "requestId": .string("facet-test-1"),
            "baseQuery": .object([
                "q": .string("prosess"),
                "constraints": .object([
                    "maxSources": .integer(3)
                ])
            ]),
            "facetKeys": .list([.string("supportedInsertionModes")]),
            "maxBucketsPerFacet": .integer(10)
        ]

        let response = try await cell.set(keypath: "facetCounts", value: .object(facetPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra facetCounts")
            return
        }
        #expect(result["status"] == .string("ok"))

        guard case let .object(facets)? = result["facets"],
              case let .list(modeBuckets)? = facets["supportedInsertionModes"] else {
            Issue.record("Mangler supportedInsertionModes-facet")
            return
        }

        let hasComponent = modeBuckets.contains { value in
            guard case let .object(bucket) = value else { return false }
            return bucket["value"] == .string("component")
        }
        #expect(hasComponent)
    }

    @Test func portholeAbsorbsCatalogReference() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Missing CellResolver")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }

        // Binding registers this in BootstrapView, tests need explicit registration.
        try? await resolver.addCellResolve(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: identity) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        porthole.detachAll(requester: identity)

        var config = CellConfiguration(name: "Catalog Absorb Test")
        config.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))

        _ = try await resolver.loadCell(from: config, into: porthole, requester: identity)

        let status = try await porthole.attachedStatus(for: "catalog", requester: identity)
        #expect(status.name == "catalog")
        #expect(status.active)

        let stateValue = try await porthole.get(keypath: "catalog.state", requester: identity)
        guard case .object = stateValue else {
            Issue.record("Expected object from catalog.state, got \(stateValue)")
            return
        }
    }

    @Test func configurationCatalogRemovesBlockedReferencesWhenOtherReferencesExist() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        var configuration = CellConfiguration(name: "Mixed References")
        configuration.addReference(CellReference(endpoint: "cell:///EventEmitter", label: "signals"))
        configuration.addReference(CellReference(endpoint: "cell:///Chat", label: "chat"))

        let payload: Object = [
            "sourceCellEndpoint": .string("cell:///EventEmitter"),
            "sourceCellName": .string("MixedCell"),
            "purpose": .string("Test blocked filtering"),
            "interests": .list([.string("chat")]),
            "menuSlots": .list([.string("upperLeft")]),
            "configuration": .cellConfiguration(configuration),
            "goal": .cellConfiguration(configuration)
        ]

        _ = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)

        let entriesValue = try await cell.get(keypath: "catalogEntries", requester: owner)
        guard case let .list(entries) = entriesValue,
              let match = entries.first(where: { value in
                  guard case let .object(object) = value,
                        case let .cellConfiguration(configuration)? = object["configuration"] else {
                      return false
                  }
                  return configuration.name == "Mixed References"
              }),
              case let .object(object) = match,
              case let .cellConfiguration(storedConfiguration)? = object["configuration"],
              let references = storedConfiguration.cellReferences
        else {
            Issue.record("Expected stored catalog entry with configuration references")
            return
        }

        #expect(references.contains(where: { $0.endpoint == "cell:///Chat" }))
        #expect(!references.contains(where: { $0.endpoint.lowercased().contains("eventemitter") }))
    }

    @Test func configurationCatalogRejectsConfigurationsWithOnlyBlockedReferences() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        var configuration = CellConfiguration(name: "Only Blocked")
        configuration.addReference(CellReference(endpoint: "cell:///TimesWrapper", label: "times"))

        let payload: Object = [
            "sourceCellEndpoint": .string("cell:///TimesWrapper"),
            "sourceCellName": .string("TimesOnlyCell"),
            "purpose": .string("Should be rejected"),
            "interests": .list([.string("time")]),
            "menuSlots": .list([.string("upperLeft")]),
            "configuration": .cellConfiguration(configuration),
            "goal": .cellConfiguration(configuration)
        ]

        let response = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)
        #expect(response == .string("error: invalid payload for addConfiguration"))
    }

    private func makeOwnerIdentity() async -> Identity {
        CellBase.defaultIdentityVault = Self.testIdentityVault
        return await Self.testIdentityVault.identity(for: "private", makeNewIfNotFound: true)!
    }

    private func makeCatalogPayload(name: String, endpoint: String, insertionMode: String) -> Object {
        var configuration = CellConfiguration(name: name)
        configuration.description = "Testkonfig for query/facet"
        var reference = CellReference(endpoint: endpoint, label: "source")
        reference.setKeysAndValues = [KeyValue(key: "adminProcesses.query", value: .string("top"))]
        configuration.addReference(reference)

        return [
            "sourceCellEndpoint": .string(endpoint),
            "sourceCellName": .string("AdminProcessesCell"),
            "purpose": .string("System monitorering"),
            "purposeDescription": .string("Overvåkning av systemprosesser"),
            "interests": .list([.string("process"), .string("alerts")]),
            "menuSlots": .list([.string("lowerMid")]),
            "categoryPath": .list([.string("ops"), .string("monitoring")]),
            "tags": .list([.string("ops"), .string("monitoring")]),
            "supportedInsertionModes": .list([.string(insertionMode)]),
            "flowDriven": .bool(true),
            "editable": .bool(true),
            "configuration": .cellConfiguration(configuration),
            "goal": .cellConfiguration(configuration)
        ]
    }

}

private actor BindingTestIdentityVault: IdentityVaultProtocol {
    private var identitiesByContext: [String: Identity] = [:]
    private var idCounter = 1

    func initialize() async -> IdentityVaultProtocol {
        self
    }

    func addIdentity(identity: inout Identity, for identityContext: String) async {
        identity.identityVault = self
        identitiesByContext[identityContext] = identity
    }

    func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? {
        if let existing = identitiesByContext[identityContext] {
            return existing
        }
        guard makeNewIfNotFound else { return nil }

        let suffix = String(format: "%012d", idCounter)
        idCounter += 1
        let uuidString = "00000000-0000-0000-0000-\(suffix)"
        let identity = Identity(uuidString, displayName: identityContext, identityVault: self)
        identitiesByContext[identityContext] = identity
        return identity
    }

    func saveIdentity(_ identity: Identity) async {
        identitiesByContext[identity.displayName] = identity
    }

    func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        messageData + identity.uuid.data(using: .utf8, allowLossyConversion: false)!
    }

    func verifySignature(signature: Data, messageData: Data, for identity: Identity) async throws -> Bool {
        let expected = messageData + identity.uuid.data(using: .utf8, allowLossyConversion: false)!
        return signature == expected
    }

    func randomBytes64() async -> Data? {
        Data(repeating: 0xAB, count: 64)
    }

    func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) {
        ("binding-test-key-\(tag)", "binding-test-iv-\(tag)")
    }
}

private extension BindingTests {
    static let testIdentityVault = BindingTestIdentityVault()
}
