// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

/// The whole path the owner will actually take: the real participant file
/// goes into the import cell as bytes, the context is named, the commit
/// lands in the relations cell, and the roles are there to sort on
/// afterwards. The pure-inference tests prove the columns are read right;
/// this proves the cells hand them to each other.
///
/// The file holds 189 real people and is gitignored, so the test looks for
/// it and steps aside when it is not on this machine.
@Suite(.serialized)
struct BookProjectImportEndToEndTests {

    private static var fileURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".sprout/import/HAVEN_import_bokprosjekt.xlsx")
    }

    private func object(_ value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }
    private func string(_ value: ValueType?) -> String? {
        guard case let .string(text)? = value else { return nil }
        return text
    }
    private func int(_ value: ValueType?) -> Int? {
        switch value {
        case let .integer(number)?: return number
        case let .float(number)?: return Int(number)
        default: return nil
        }
    }
    private func list(_ value: ValueType?) -> [ValueType] {
        guard case let .list(items)? = value else { return [] }
        return items
    }

    @Test func theRealParticipantListGoesInThroughTheCellsAndKeepsItsRoles() async throws {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }

        let previousResolver = CellBase.defaultCellResolver
        let previousVault = CellBase.defaultIdentityVault
        defer {
            CellBase.defaultCellResolver = previousResolver
            CellBase.defaultIdentityVault = previousVault
        }

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        _ = await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        let resolver = CellResolver.sharedInstance
        let vault = try #require(CellBase.defaultIdentityVault)
        let owner = try #require(await vault.identity(
            for: "binding-book-import-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))

        let importCell = try #require(
            await resolver.cellAtEndpoint(endpoint: "cell:///ContactImport", requester: owner) as? Meddle
        )
        let relations = try #require(
            await resolver.cellAtEndpoint(endpoint: "cell:///Relations", requester: owner) as? Meddle
        )

        // 1. The file arrives the way the picker delivers it: name and bytes.
        let ingest = try #require(object(try await importCell.set(
            keypath: "import.ingest",
            value: .object([
                "filename": .string("HAVEN_import_bokprosjekt.xlsx"),
                "mimeType": .string("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
                "dataBase64": .string(data.base64EncodedString())
            ]),
            requester: owner
        )))
        #expect(string(ingest["status"]) != "error", "ingest: \(ingest)")

        let preview = try #require(object(try await importCell.get(keypath: "state", requester: owner))
            .flatMap { object($0["preview"]) })
        #expect(string(preview["status"]) == "ready", "preview: \(string(preview["summaryText"]) ?? "")")
        #expect(int(preview["proposedCount"]) == 189)
        #expect(int(preview["skippedRows"]) == 0)
        // Two rows carry the same phone number. They are different people, so
        // they stay apart — and the file gets told about it, because in a
        // hand-kept list one of the two numbers is nearly always a slip.
        let problems = list(preview["problems"]).compactMap { if case let .string(text) = $0 { return text } else { return nil } }
        #expect(problems.contains { $0.contains("Yngvar Ugland") && $0.contains("Bertil Johansen") },
                Comment(rawValue: "problems: \(problems)"))
        // Before the owner names it, the surface says the file name will stand in.
        #expect(string(preview["contextHint"])?.contains("HAVEN_import_bokprosjekt.xlsx") == true)

        // 2. The owner names what the list is.
        let context = "Bok: Rammebetingelser for innovasjon"
        _ = try await importCell.set(keypath: "import.setContext", value: .string(context), requester: owner)
        let named = try #require(object(try await importCell.get(keypath: "state", requester: owner))
            .flatMap { object($0["preview"]) })
        #expect(string(named["context"]) == context)
        #expect(string(named["contextHint"])?.contains(context) == true)

        // 3. Commit: the import cell hands them to the relations cell.
        let commit = try #require(object(try await importCell.set(
            keypath: "import.commit",
            value: .object([:]),
            requester: owner
        )))
        #expect(string(commit["status"]) == "ok", "commit: \(commit)")

        // 4. They are in relations, with the roles intact.
        let state = try #require(object(try await relations.get(keypath: "state", requester: owner)))
        let stats = try #require(object(state["stats"]))
        #expect(int(stats["total"]) == 189)

        let rows = list(state["records"]).compactMap { object($0) }
        #expect(rows.count == 189)
        let editor = try #require(rows.first { string($0["displayName"]) == "Sjur Dagestad" })
        let editorRoles = list(editor["roles"]).compactMap { object($0) }
        #expect(editorRoles.first?["context"] == .string(context))
        #expect(string(editorRoles.first?["role"]) == "Prosjektleder og redaktør")

        let withGroup = rows.filter { row in
            list(row["roles"]).compactMap { object($0) }.contains { string($0["group"])?.isEmpty == false }
        }
        #expect(withGroup.count == 181)

        // 5. Someone in the list can actually be reached — the point of importing.
        let reach = try #require(object(try await relations.set(
            keypath: "relations.reach",
            value: .object(["query": .string("Sjur Dagestad")]),
            requester: owner
        )))
        #expect(string(reach["status"]) == "reachable", "reach: \(reach)")
        let recommended = object(object(reach["reach"])?["recommended"])
        #expect(string(recommended?["action"]) == "send-invite")
        #expect(string(recommended?["channel"]) == "email")

        // Nothing was sent by importing.
        #expect(int(stats["invitesSent"]) == 0)
    }
}
