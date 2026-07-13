// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

@Suite(.serialized)
struct DecodedHostedCellReadinessTests {
    @Test func publishedHostedCellsAreReadyForConcurrentImmediateReadAndSafeAction() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        let previousVault = CellBase.defaultIdentityVault
        let vault = EphemeralIdentityVault()
        let owner = try #require(await vault.identity(
            for: "binding-hosted-readiness-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        CellBase.debugValidateAccessForEverything = false
        CellBase.defaultIdentityVault = vault
        defer {
            CellBase.debugValidateAccessForEverything = previousDebugAccess
            CellBase.defaultIdentityVault = previousVault
        }

        let freshEnrollment = await AgentEnrollmentCell(owner: owner)
        let enrollment = try roundTrip(freshEnrollment, as: AgentEnrollmentCell.self)
        let freshProvisioning = await AgentProvisioningCell(owner: owner)
        let provisioning = try roundTrip(freshProvisioning, as: AgentProvisioningCell.self)
        let freshFolderWatch = await FolderWatchCell(owner: owner)
        let folderWatch = try roundTrip(freshFolderWatch, as: FolderWatchCell.self)
        let freshAgenda = await PersonalAgendaContextCell(owner: owner)
        let agenda = try roundTrip(freshAgenda, as: PersonalAgendaContextCell.self)
        let freshWorkflow = await WorkflowStudioCell(owner: owner)
        let workflow = try roundTrip(freshWorkflow, as: WorkflowStudioCell.self)

        let reads: [(GeneralCell, String)] = [
            (enrollment, "enrollment.state"),
            (provisioning, "agent.setup.state"),
            (folderWatch, "state"),
            (agenda, "agenda.state"),
            (workflow, "state")
        ]
        let grantContractsBefore = reads.map { cell, _ in grantContracts(for: cell) }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (cell, keypath) in reads {
                for _ in 0..<12 {
                    group.addTask {
                        let value = try await cell.get(keypath: keypath, requester: owner)
                        guard case .object = value else {
                            Issue.record("Expected object state for \(keypath), got \(value)")
                            return
                        }
                    }
                }
            }
            try await group.waitForAll()
        }

        for (index, entry) in reads.enumerated() {
            let contracts = grantContracts(for: entry.0)
            #expect(contracts == grantContractsBefore[index])
            #expect(contracts.count == entry.0.agreementTemplate.grants.count)
            #expect(try await entry.0.keys(requester: owner).contains(entry.1))
        }

        #expect(readinessObject(try await enrollment.set(
            keypath: "enrollment.refresh",
            value: .object([:]),
            requester: owner
        )) != nil)
        #expect(try await provisioning.set(
            keypath: "agent.setup.purpose.name",
            value: .string("Decoded readiness purpose"),
            requester: owner
        ) == .string("Decoded readiness purpose"))
        #expect(readinessObject(try await folderWatch.set(
            keypath: "configure",
            value: .object(["topic": .string("filesystem.readiness")]),
            requester: owner
        )) != nil)
        #expect(readinessObject(try await agenda.set(
            keypath: "agenda.clearCache",
            value: .object([:]),
            requester: owner
        )) != nil)
        #expect(readinessObject(try await workflow.set(
            keypath: "workflow.setRunInputText",
            value: .string("Decoded workflow input"),
            requester: owner
        )) != nil)

        let workflowState = try #require(readinessObject(try await workflow.get(
            keypath: "state",
            requester: owner
        )))
        #expect(readinessString(workflowState["runInputText"]) == "Decoded workflow input")
        #expect(readinessBool(workflowState["canEdit"]) == true)
    }

    private func roundTrip<Cell: GeneralCell & Codable>(
        _ cell: Cell,
        as type: Cell.Type
    ) throws -> Cell {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(cell))
    }

    private func grantContracts(for cell: GeneralCell) -> Set<String> {
        Set(cell.agreementTemplate.grants.map {
            "\($0.keypath)\u{0}\($0.permission.permissionString)"
        })
    }
}

private func readinessObject(_ value: ValueType?) -> Object? {
    guard case let .object(object)? = value else { return nil }
    return object
}

private func readinessString(_ value: ValueType?) -> String? {
    guard case let .string(string)? = value else { return nil }
    return string
}

private func readinessBool(_ value: ValueType?) -> Bool? {
    guard case let .bool(value)? = value else { return nil }
    return value
}
