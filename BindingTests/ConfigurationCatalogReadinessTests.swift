// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

@Suite(.serialized)
struct ConfigurationCatalogReadinessTests {
    @Test func decodedCatalogIsReadyForImmediateConcurrentStateAndAction() async throws {
        let vault = BindingStartupIdentityVault.shared
        _ = await vault.initialize()
        let previousVault = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault
        defer { CellBase.defaultIdentityVault = previousVault }

        let owner = try #require(await vault.identity(
            for: "binding-catalog-readiness-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        let source = await ConfigurationCatalogCell(owner: owner)
        let encoded = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ConfigurationCatalogCell.self, from: encoded)
        let grantContractsBefore = Set(decoded.agreementTemplate.grants.map {
            "\($0.keypath)\u{0}\($0.permission.permissionString)"
        })

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<12 {
                group.addTask {
                    try await decoded.ensureRuntimeBindings()
                }
            }
            try await group.waitForAll()
        }

        let configurations = try await decoded.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Expected decoded catalog configurations immediately after readiness")
            return
        }
        #expect(items.isEmpty == false)

        let actionResult = try await decoded.set(
            keypath: "matching.promptText",
            value: .string("Finn en konferanseflate"),
            requester: owner
        )
        #expect(actionResult == .string("Finn en konferanseflate"))
        let grantContractsAfter = Set(decoded.agreementTemplate.grants.map {
            "\($0.keypath)\u{0}\($0.permission.permissionString)"
        })
        #expect(decoded.agreementTemplate.grants.count == grantContractsBefore.count)
        #expect(grantContractsAfter == grantContractsBefore)
    }
}
