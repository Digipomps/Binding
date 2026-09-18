import XCTest
import CellBase
@testable import Binding

@MainActor
final class RelationsViewStateTests: XCTestCase {
    func testVisibilityRowsUseAuthorizedCellStateAndFollowImportChanges() async throws {
        let vault = EphemeralIdentityVault()
        let ownerValue = await vault.identity(for: "relations-view-owner", makeNewIfNotFound: true)
        let owner = try XCTUnwrap(ownerValue)
        let relations = await BindingRelationsCell(owner: owner)
        let importer = await BindingContactImportCell(owner: owner)
        let invitation = await BindingInvitationCell(owner: owner)
        for (label, cell) in [("relations", relations as GeneralCell),
                              ("contactImport", importer as GeneralCell),
                              ("invitation", invitation as GeneralCell)] {
            guard case let .list(rows) = try await cell.get(keypath: "viewState", requester: owner),
                  case let .object(row)? = rows.first,
                  case let .object(bound)? = row[label],
                  case .object? = bound["state"] else {
                XCTFail("Missing bound state for \(label)")
                continue
            }
            XCTAssertEqual(rows.count, 1)
        }
        let hasPending = SkeletonCondition(scope: .root,
            keypath: "contactImport.state.hasPending", equals: .bool(true))
        func row() async throws -> ValueType {
            guard case let .list(rows) = try await importer.get(keypath: "viewState", requester: owner),
                  let first = rows.first else { throw NSError(domain: "MissingViewState", code: 1) }
            return first
        }
        let before = try await row()
        XCTAssertFalse(hasPending.evaluate(root: before, item: before))
        _ = try await importer.set(keypath: "import.ingest", value: .object([
            "filename": .string("synthetic.csv"),
            "text": .string("Name,Email\nSynthetic Person,synthetic@example.invalid\n")
        ]), requester: owner)
        let pending = try await row()
        XCTAssertTrue(hasPending.evaluate(root: pending, item: pending))
        _ = try await importer.set(keypath: "import.discard", value: .object([:]), requester: owner)
        let discarded = try await row()
        XCTAssertFalse(hasPending.evaluate(root: discarded, item: discarded))
    }
}
