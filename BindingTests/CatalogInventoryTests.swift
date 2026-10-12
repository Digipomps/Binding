import Foundation
import Testing
import CellBase
@testable import Binding

@Suite(.serialized)
@MainActor
struct CatalogInventoryTests {
    private let local = "cell:///ConfigurationCatalog"
    private let staging = "cell://staging.example/ConfigurationCatalog"
    private let unavailable = "cell://unavailable.example/ConfigurationCatalog"

    private func entry(_ index: Int, auth: Bool = true) -> ValueType {
        let configuration = CellConfiguration(name: "Surface \(index)")
        return .object([
            "id": .string("shared-id-\(index)"),
            "configuration": .cellConfiguration(configuration),
            "sourceCellEndpoint": .string("cell:///Surface\(index)"),
            "authRequired": .bool(auth),
            "supportedInsertionModes": .list([.string("root")])
        ])
    }

    @Test func successfulLocalCatalogDoesNotHideRemoteCatalogOrTruncateIt() async {
        let rows = (0..<109).map { entry($0) }
        var requested: [String] = []
        let model = FullLibraryViewModel(catalogEndpoints: [local, unavailable, staging, staging],
            queryContext: .init(editMode: false, selectedNodeKind: nil, insertionIntent: .unknown),
            fallbackFavorites: [], fallbackTemplates: [], catalogInventoryLoader: { endpoint in
                requested.append(endpoint)
                if endpoint == unavailable { throw URLError(.cannotConnectToHost) }
                return endpoint == local ? Array(rows.prefix(3)) : rows
            }, bootstrapRuntime: { _ in .ready })
        await model.loadInitial()
        #expect(requested == [local, unavailable, staging])
        #expect(model.results.count == 112)
        #expect(Set(model.results.map(\.id)).count == 112)
        #expect(model.results.filter { $0.origin == .catalog(endpoint: staging) }.count == 109)
        #expect(model.connectivity.onlineSources == 2)
        #expect(model.connectivity.offlineSources == 1)
        #expect(model.statusLine.contains("2/3"))
        #expect(model.statusLine.contains("ufullstendig"))
        #expect(!model.warningDetails.isEmpty)
    }

    @Test func cacheOnlyDoesNotContactRemoteScaffolds() async {
        var requested: [String] = []
        let row = entry(0)
        let model = FullLibraryViewModel(catalogEndpoints: [staging, local],
            queryContext: .init(editMode: false, selectedNodeKind: nil, insertionIntent: .unknown),
            fallbackFavorites: [], fallbackTemplates: [], catalogInventoryLoader: { endpoint in
                requested.append(endpoint)
                return [row]
            }, bootstrapRuntime: { _ in .ready })
        model.networkPolicy = .cacheOnly
        await model.loadInitial()
        #expect(requested == [local])
        #expect(model.results.count == 1)
    }

    @Test func booleanFacetsFilterInventoryInsteadOfBecomingTextQueries() async {
        let rows = [entry(1, auth: true), entry(2, auth: false)]
        let model = FullLibraryViewModel(catalogEndpoints: [local],
            queryContext: .init(editMode: false, selectedNodeKind: nil, insertionIntent: .unknown),
            fallbackFavorites: [], fallbackTemplates: [], catalogInventoryLoader: { _ in rows },
            bootstrapRuntime: { _ in .ready })
        model.selectedFacets = ["authRequired": ["false"]]
        await model.loadInitial()
        #expect(model.results.map(\.displayName) == ["Surface 2"])
    }

    @Test func emptyAuthorizedCatalogIsNotReportedAsAccessFailure() async {
        let model = FullLibraryViewModel(catalogEndpoints: [local],
            queryContext: .init(editMode: false, selectedNodeKind: nil, insertionIntent: .unknown),
            fallbackFavorites: [], fallbackTemplates: [], catalogInventoryLoader: { _ in [] },
            bootstrapRuntime: { _ in .ready })
        await model.loadInitial()
        #expect(model.results.isEmpty)
        #expect(model.connectivity.onlineSources == 1)
        #expect(model.connectivity.offlineSources == 0)
        #expect(model.catalogMode == .catalogInventory)
    }

    @Test func temporarySourceFailureRetainsClearlyLabeledCachedInventory() async {
        let row = entry(0)
        var fail = false
        let model = FullLibraryViewModel(catalogEndpoints: [local],
            queryContext: .init(editMode: false, selectedNodeKind: nil, insertionIntent: .unknown),
            fallbackFavorites: [], fallbackTemplates: [], catalogInventoryLoader: { _ in
                if fail { throw URLError(.cannotConnectToHost) }
                return [row]
            }, bootstrapRuntime: { _ in .ready })
        await model.loadInitial()
        fail = true
        await model.refreshNow()
        #expect(model.results.count == 1)
        #expect(model.statusLine.contains("Lagret katalogoversikt"))
        #expect(model.connectivity.onlineSources == 0)
        #expect(model.connectivity.degradedSources == 1)
    }

    @Test func desktopDevelopmentCatalogIsIndependentOfConferenceOptIn() {
        #if os(macOS) && DEBUG
        #expect(!BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled)
        #else
        #expect(BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled)
        #endif
        // The release allowlist itself remains strict in every build.
        #expect(!BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1(CellConfiguration(name: "Developer Workbench")))
    }
}
