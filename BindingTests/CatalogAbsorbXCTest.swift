import XCTest
import CellBase
import CellApple
@testable import Binding

final class CatalogAbsorbXCTest: XCTestCase {
    func testPortholeAbsorbsConfigurationCatalogAsCatalogLabel() async throws {
        await AppInitializer.initialize()

        // XCTest process may not always inherit default resolver wiring from app bootstrap.
        let resolver: CellResolver
        if let existing = CellBase.defaultCellResolver as? CellResolver {
            resolver = existing
        } else {
            resolver = CellResolver.sharedInstance
            CellBase.defaultCellResolver = resolver
        }

        if CellBase.defaultIdentityVault == nil {
            CellBase.defaultIdentityVault = IdentityVault.shared
            _ = await IdentityVault.shared.initialize()
        }

        guard let identity = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            XCTFail("Missing private identity")
            return
        }

        // Binding registers this in BootstrapView; tests need explicit registration.
        try? await resolver.addCellResolve(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self
        )
        try? await resolver.addCellResolve(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: identity) as? OrchestratorCell else {
            XCTFail("Could not resolve Porthole")
            return
        }

        guard let catalog = try await resolver.cellAtEndpoint(endpoint: "cell:///ConfigurationCatalog", requester: identity) as? ConfigurationCatalogCell else {
            XCTFail("Could not resolve ConfigurationCatalogCell")
            return
        }

        let owner = try await catalog.getOwner(requester: identity)
        XCTAssertEqual(owner.uuid, identity.uuid, "ConfigurationCatalog should resolve with the active private identity as owner")

        let directState = try await catalog.get(keypath: "state", requester: identity)
        if case .object = directState {
            // verified
        } else {
            XCTFail("Expected object for direct catalog.state, got \(directState)")
        }

        _ = try await catalog.flow(requester: identity)

        porthole.detachAll(requester: identity)

        var config = CellConfiguration(name: "Catalog Absorb XCTest")
        config.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))

        _ = try await resolver.loadCell(from: config, into: porthole, requester: identity)

        let status = try await porthole.attachedStatus(for: "catalog", requester: identity)
        XCTAssertEqual(status.name, "catalog")
        XCTAssertTrue(status.active)

        let value = try await porthole.get(keypath: "catalog.state", requester: identity)
        if case .object = value {
            // verified
        } else {
            XCTFail("Expected object for catalog.state, got \(value)")
        }
    }
}
