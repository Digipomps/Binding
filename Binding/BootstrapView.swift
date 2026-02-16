import SwiftUI
import CellBase
import CellApple

struct BootstrapView<Content: View>: View {
    @State private var isReady = false
    let content: () -> Content

    var body: some View {
        Group {
            if isReady {
                content()
            } else {
                ProgressView("Starter opp…")
            }
        }
        .task {
            await AppInitializer.initialize()
//            ****** Register scaffold local resolves here ******
            
            let resolver = CellResolver.sharedInstance
            do {
                try await resolver.addCellResolve(name: "EventEmitter",         cellScope: .template,       identityDomain: "private", type: EventEmitterCell.self)
                try await resolver.addCellResolve(name: "FolderWatch",          cellScope: .template,       identityDomain: "private", type: FolderWatchCell.self)
                try await resolver.addCellResolve(name: "ConfigurationCatalog", cellScope: .scaffoldUnique, persistency: .persistant, identityDomain: "private", type: ConfigurationCatalogCell.self)
            } catch {
                print("Scaffold added cellResolve failed with error: \(error)")
            }
            isReady = true
        }
    }
}
