//
//  BindingTests.swift
//  BindingTests
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import Testing
import CellBase
@testable import Binding

struct BindingTests {

    @Test func configurationCatalogQueryReturnsRankedResults() async throws {
        let owner = makeOwnerIdentity()
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
        let owner = makeOwnerIdentity()
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

    private func makeOwnerIdentity() -> Identity {
        Identity()
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
